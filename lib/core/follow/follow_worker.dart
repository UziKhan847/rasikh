import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import 'follow_aligner.dart';
import 'follow_text.dart';

const kFollowSampleRate = 16000;

/// What the worker needs: the model's files, and the muṣḥaf's words.
class FollowWorkerConfig {
  final String modelPath, tokensPath, vadPath;

  /// The muṣḥaf's words in reading order, as written, one per line (the
  /// worker brings them down to bare letters itself).
  final String wordsText;

  /// Each word's sūrah.
  final Uint8List surahOf;

  /// Seconds of audio transcribed each pass.
  final double windowSeconds;

  /// The shortest gap between two passes; a slow device waits twice as long
  /// as its last pass took, so it decodes less often rather than falling
  /// behind or running hot.
  final int minIntervalMs;
  final int numThreads;

  /// Passes go on this long after speech stops (the phrase's last word).
  final int hangoverMs;

  /// After this much silence the window starts afresh.
  final int resetAfterSilenceMs;

  const FollowWorkerConfig({
    required this.modelPath,
    required this.tokensPath,
    required this.vadPath,
    required this.wordsText,
    required this.surahOf,
    this.windowSeconds = 4,
    this.minIntervalMs = 400,
    this.numThreads = 2,
    this.hangoverMs = 700,
    this.resetAfterSilenceMs = 2500,
  });
}

// ── messages ──

class FollowAudio {
  /// 16-bit little-endian mono PCM at 16 kHz, moved without a copy.
  final TransferableTypedData pcm16;
  FollowAudio(this.pcm16);
}

class FollowSetPosition {
  final int word;
  const FollowSetPosition(this.word);
}

/// The pages in view, best first: pairs of first and last word.
class FollowSetView {
  final Int32List ranges;
  const FollowSetView(this.ranges);
}

class FollowClearPosition {
  final int? surah;
  const FollowClearPosition(this.surah);
}

class FollowResetAudio {
  const FollowResetAudio();
}

class FollowShutdown {
  const FollowShutdown();
}

class FollowReady {
  const FollowReady();
}

class FollowFailed {
  final String message;
  const FollowFailed(this.message);
}

/// One pass, for "Show what's heard": the transcript and how long it took.
class FollowHeard {
  final String text;
  final int decodeMs;
  final double seconds;
  const FollowHeard(this.text, this.decodeMs, this.seconds);
}

/// The worker's entry: `[SendPort toMain, FollowWorkerConfig]`. Its first
/// message back is its own SendPort, then [FollowReady] or [FollowFailed].
Future<void> followWorkerMain(List<Object> args) async {
  final toMain = args[0] as SendPort;
  final cfg = args[1] as FollowWorkerConfig;
  final inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  final _Worker w;
  try {
    // FFI bindings are per isolate.
    so.initBindings();
    w = _Worker(cfg, toMain);
  } catch (e) {
    toMain.send(FollowFailed('$e'));
    inbox.close();
    return;
  }
  toMain.send(const FollowReady());
  inbox.listen((msg) {
    try {
      switch (msg) {
        case FollowAudio(:final pcm16):
          w.onAudio(pcm16.materialize().asUint8List());
        case FollowSetPosition(:final word):
          w.aligner.setPosition(word);
          w.resetAudio();
        case FollowSetView(:final ranges):
          w.aligner.setView([
            for (var i = 0; i + 1 < ranges.length; i += 2) (ranges[i], ranges[i + 1]),
          ]);
        case FollowClearPosition(:final surah):
          w.aligner.clearPosition(surah: surah);
          w.resetAudio();
        case FollowResetAudio():
          w.resetAudio();
        case FollowShutdown():
          w.free();
          inbox.close();
      }
    } catch (e) {
      toMain.send(FollowFailed('$e'));
    }
  });
}

class _Worker {
  final FollowWorkerConfig cfg;
  final SendPort toMain;
  final _Ring ring;
  late final FollowAligner aligner;
  late final so.OfflineRecognizer recognizer;
  late final so.VoiceActivityDetector vad;

  static const _vadWindow = 512; // Silero's at 16 kHz
  final _vadBuf = Float32List(_vadWindow);
  int _vadFill = 0;
  int? _oddByte; // a chunk can end half-way through a sample

  final _clock = Stopwatch()..start();
  int _audioMs = 0;
  int _lastSpeechMs = -1 << 30;
  int _lastPassAt = -1 << 30;
  int _lastPassMs = 0;
  bool _scheduled = false, _freed = false;
  bool _flushed = true, _cleared = true;

  _Worker(this.cfg, this.toMain)
      : ring = _Ring((cfg.windowSeconds * kFollowSampleRate).round()) {
    final raw = cfg.wordsText.split('\n');
    aligner = FollowAligner([for (final w in raw) FollowText.word(w)], cfg.surahOf);
    recognizer = so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        zipformerCtc: so.OfflineZipformerCtcModelConfig(model: cfg.modelPath),
        tokens: cfg.tokensPath,
        numThreads: cfg.numThreads,
        debug: false,
      ),
    ));
    vad = so.VoiceActivityDetector(
      config: so.VadModelConfig(
        sileroVad: so.SileroVadModelConfig(
          model: cfg.vadPath,
          threshold: .5,
          minSilenceDuration: .3,
          minSpeechDuration: .15,
          windowSize: _vadWindow,
          // Only isDetected() is used: no splits mid-phrase.
          maxSpeechDuration: 30,
        ),
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 40,
    );
  }

  /// The recent loudest sample, decaying (half in [_gainHalfLife] s): a
  /// quiet microphone is raised to a steady level before anything hears it
  /// — the voice detector misses faint speech, and the model hears it worse.
  double _recentPeak = 0;
  static const _target = .5, _maxGain = 30.0, _gainHalfLife = 1.5;

  void _level(Float32List x) {
    var peak = 0.0;
    for (final v in x) {
      final a = v < 0 ? -v : v;
      if (a > peak) peak = a;
    }
    final decay = math.pow(.5, x.length / kFollowSampleRate / _gainHalfLife).toDouble();
    _recentPeak = math.max(peak, _recentPeak * decay);
    final gain = (_target / math.max(_recentPeak, 1e-4)).clamp(1.0, _maxGain);
    if (gain <= 1.01) return;
    for (var i = 0; i < x.length; i++) {
      x[i] = (x[i] * gain).clamp(-1.0, 1.0);
    }
  }

  void onAudio(Uint8List bytes) {
    final samples = _toFloat(bytes);
    if (samples.isEmpty) return;
    _level(samples);
    ring.add(samples);
    _audioMs += samples.length * 1000 ~/ kFollowSampleRate;
    var i = 0;
    while (i < samples.length) {
      final take = (_vadWindow - _vadFill).clamp(0, samples.length - i);
      _vadBuf.setRange(_vadFill, _vadFill + take, samples, i);
      _vadFill += take;
      i += take;
      if (_vadFill == _vadWindow) {
        vad.acceptWaveform(_vadBuf);
        _vadFill = 0;
        if (vad.isDetected()) _lastSpeechMs = _audioMs;
        // Its segments aren't used: don't let them pile up.
        while (!vad.isEmpty()) {
          vad.pop();
        }
      }
    }
    final silence = _audioMs - _lastSpeechMs;
    if (silence < cfg.hangoverMs) {
      _flushed = false;
      _cleared = false;
      final gap = _lastPassMs * 2 > cfg.minIntervalMs ? _lastPassMs * 2 : cfg.minIntervalMs;
      if (_clock.elapsedMilliseconds - _lastPassAt >= gap) _schedule();
    } else if (!_flushed) {
      // One last pass as they pause.
      _flushed = true;
      _schedule();
    } else if (!_cleared && silence >= cfg.resetAfterSilenceMs) {
      _cleared = true;
      ring.clear();
    }
  }

  // Deferred, so audio that queued during a pass is taken in first: each
  // pass sees the newest audio, never a stale backlog.
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    Timer.run(() {
      _scheduled = false;
      if (!_freed) _pass();
    });
  }

  void _pass() {
    _lastPassAt = _clock.elapsedMilliseconds;
    final audio = ring.snapshot();
    if (audio.length < kFollowSampleRate * .3) return;
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: audio, sampleRate: kFollowSampleRate);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text;
      _lastPassMs = _clock.elapsedMilliseconds - _lastPassAt;
      for (final e in aligner.update(FollowText.words(text))) {
        toMain.send(switch (e) {
          FollowProgress(:final word) => ('progress', word),
          FollowJump(:final word) => ('jump', word),
          FollowLost() => ('lost', -1),
        });
      }
      toMain.send(FollowHeard(text, _lastPassMs, audio.length / kFollowSampleRate));
    } finally {
      stream.free();
    }
  }

  void resetAudio() {
    ring.clear();
    _vadFill = 0;
    _oddByte = null;
    vad.reset();
    _lastSpeechMs = -1 << 30;
    _flushed = true;
    _cleared = true;
  }

  void free() {
    _freed = true;
    vad.free();
    recognizer.free();
  }

  Float32List _toFloat(Uint8List bytes) {
    var data = bytes;
    if (_oddByte != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = _oddByte!
        ..setRange(1, bytes.length + 1, bytes);
      _oddByte = null;
    }
    final n = data.length ~/ 2;
    if (data.length.isOdd) _oddByte = data[data.length - 1];
    final bd = ByteData.sublistView(data);
    final out = Float32List(n);
    for (var k = 0; k < n; k++) {
      out[k] = bd.getInt16(k * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}

/// The newest [capacity] samples.
class _Ring {
  final Float32List _buf;
  int _write = 0, _filled = 0;
  _Ring(int capacity) : _buf = Float32List(capacity);

  void add(Float32List x) {
    final cap = _buf.length;
    var src = x;
    if (src.length >= cap) src = Float32List.sublistView(src, src.length - cap);
    final first = (cap - _write).clamp(0, src.length);
    _buf.setRange(_write, _write + first, src);
    if (first < src.length) _buf.setRange(0, src.length - first, src, first);
    _write = (_write + src.length) % cap;
    _filled = (_filled + src.length).clamp(0, cap);
  }

  Float32List snapshot() {
    final cap = _buf.length;
    final out = Float32List(_filled);
    final start = (_write - _filled + cap) % cap;
    final first = (cap - start).clamp(0, _filled);
    out.setRange(0, first, _buf, start);
    if (first < _filled) out.setRange(first, _filled, _buf);
    return out;
  }

  void clear() {
    _write = 0;
    _filled = 0;
  }
}
