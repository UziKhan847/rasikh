import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../data/mushaf.dart';
import 'follow_debug.dart';
import 'follow_model.dart';
import 'follow_worker.dart';

/// Every word of the muṣḥaf in reading order (the āyah markers left out):
/// following's word index is a place in this list.
class FollowWords {
  final List<String> text;
  final Int32List ayahOf;
  final Int16List word0Of;
  final Uint8List surahOf;

  /// Each āyah's first word here.
  final Int32List firstOfAyah;
  FollowWords._(this.text, this.ayahOf, this.word0Of, this.surahOf, this.firstOfAyah);

  static FollowWords? _built;

  /// Built once from the muṣḥaf's own text ('uthmani': the Madani scripts
  /// and both prints share its words).
  static Future<FollowWords> load() async {
    if (_built case final w?) return w;
    await MushafRepo.ensure('uthmani');
    final n = MushafRepo.tokenCount('uthmani');
    final toks = MushafRepo.tokensSync('uthmani');
    final text = <String>[], ayah = <int>[], word0 = <int>[];
    final first = Int32List(6236);
    var lastAyah = -1;
    for (var t = 0; t < n; t++) {
      final (g, w) = MushafRepo.tokenAt('uthmani', t);
      if (w < 0) continue;
      if (g != lastAyah) {
        first[g] = text.length;
        lastAyah = g;
      }
      text.add(toks[t]);
      ayah.add(g);
      word0.add(w);
    }
    final surahs = Uint8List(text.length);
    for (var i = 0; i < text.length; i++) {
      surahs[i] = MushafRepo.surahAyahOf(ayah[i]).$1;
    }
    return _built = FollowWords._(text, Int32List.fromList(ayah), Int16List.fromList(word0), surahs, first);
  }

  int get length => text.length;

  /// The word at āyah [g], muṣḥaf word [word0] (clamped to the āyah).
  int indexOf(int g, int word0) {
    final first = firstOfAyah[g];
    final next = g + 1 < firstOfAyah.length ? firstOfAyah[g + 1] : length;
    return (first + word0).clamp(first, next - 1);
  }
}

/// Whether following can run here: it needs the app's folders and the
/// native speech engine, which a browser hasn't.
const bool kFollowSupported = !kIsWeb;

enum FollowStatus { off, starting, listening, searching, paused, failed }

/// What does the work: the mic and the model ([SherpaFollowEngine]), or a
/// stand-in in tests.
abstract class FollowEngine {
  /// ('progress' | 'jump' | 'lost', word).
  Stream<(String, int)> get events;
  Stream<FollowHeard> get heard;

  /// How loud each moment of the microphone is, 0..1 (its peak), a few
  /// times a second.
  Stream<double> get levels;

  /// Starts listening from [fromWord]; false if the mic was refused.
  Future<bool> start(int fromWord);
  void setPosition(int word);

  /// The pages in view, best first (word ranges): see FollowAligner.setView.
  void setView(List<(int, int)> ranges);
  Future<void> stop();
  Future<void> dispose();
}

/// Following, app-wide: one at a time, kept across the muṣḥaf and the
/// Verses view as audio is. It only keeps your place — it doesn't judge the
/// recitation: no mistakes, no tajwīd.
class FollowSession {
  FollowSession._();
  static final FollowSession instance = FollowSession._();

  /// Tests: the engine used, in place of the model's.
  @visibleForTesting
  static Future<FollowEngine> Function(FollowWords words, ({String dir, FollowTier tier}) model)?
      debugEngine;

  final status = ValueNotifier<FollowStatus>(FollowStatus.off);

  /// The word they're on (an index into [words]); -1 before any.
  final word = ValueNotifier<int>(-1);

  /// Bumped when they started somewhere else (the screen goes there).
  final jumps = ValueNotifier<int>(0);

  /// The last transcript and how long it took, for "Show what's heard".
  final heard = ValueNotifier<FollowHeard?>(null);

  /// Why it couldn't start ('mic', or the error).
  String? failure;

  /// Whose tool it is (the muṣḥaf, the Verses view): a screen that lets
  /// its tool go stops it only if it's its own.
  Object? owner;

  /// The microphone to listen with (an input's id; null: the system's).
  String? micId;

  /// Keep what's heard on this device, to tune following by.
  bool keepRecordings = false;

  /// How loud the microphone is now, 0..1.
  final level = ValueNotifier<double>(0);

  /// What's wrong with what the microphone gives: 'silent' (nothing at
  /// all: a muted or unplugged input), 'quiet' (too faint to follow), or
  /// null.
  final micProblem = ValueNotifier<String?>(null);

  StreamSubscription<double>? _levelSub;
  Timer? _micCheck;
  final _sinceSound = Stopwatch(), _sinceVoice = Stopwatch();

  /// Nothing at all for this long: it says so.
  static const silentAfter = Duration(seconds: 3);

  /// Never louder than [voiceLevel] for this long: too faint.
  static const quietAfter = Duration(seconds: 6);
  static const voiceLevel = .008;

  void _onLevel(double v) {
    level.value = v;
    if (v > 0) _sinceSound.reset();
    if (v >= voiceLevel) _sinceVoice.reset();
  }

  void _checkMic() {
    if (status.value != FollowStatus.listening && status.value != FollowStatus.searching) {
      micProblem.value = null;
      return;
    }
    micProblem.value = _sinceSound.elapsed >= silentAfter
        ? 'silent'
        : _sinceVoice.elapsed >= quietAfter
            ? 'quiet'
            : null;
  }

  void _watchMic() {
    _sinceSound
      ..reset()
      ..start();
    _sinceVoice
      ..reset()
      ..start();
    micProblem.value = null;
    _micCheck?.cancel();
    _micCheck = Timer.periodic(const Duration(milliseconds: 500), (_) => _checkMic());
  }

  /// The microphone changed: listening again from where they are.
  Future<void> restartMic() async {
    final e = _engine;
    if (e == null || status.value == FollowStatus.paused || !active) return;
    await e.stop();
    if (!await e.start(word.value + 1)) {
      failure = 'mic';
      await _teardown(FollowStatus.failed);
      return;
    }
    _watchMic();
  }

  FollowWords? words;
  FollowEngine? _engine;
  StreamSubscription<(String, int)>? _sub;
  StreamSubscription<FollowHeard>? _heardSub;
  Timer? _searching;

  bool get active => status.value != FollowStatus.off;

  // ── the app away: the mic off, back on its return (wherever it was started) ──

  late final _lifecycle = _FollowLifecycle(this);
  bool _pausedAway = false;

  void _watchLifecycle(bool on) {
    if (on) {
      WidgetsBinding.instance.removeObserver(_lifecycle);
      WidgetsBinding.instance.addObserver(_lifecycle);
    } else {
      WidgetsBinding.instance.removeObserver(_lifecycle);
      _pausedAway = false;
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (status.value == FollowStatus.listening || status.value == FollowStatus.searching) {
        _pausedAway = true;
        pause();
      }
    } else if (state == AppLifecycleState.resumed && _pausedAway) {
      _pausedAway = false;
      resume();
    }
  }

  /// Tests: as if the app went away (or came back).
  @visibleForTesting
  void debugLifecycle(AppLifecycleState state) => _onLifecycle(state);

  /// The word's (global āyah, muṣḥaf word0), or null.
  (int, int)? get place {
    final w = words, i = word.value;
    if (w == null || i < 0 || i >= w.length) return null;
    return (w.ayahOf[i], w.word0Of[i]);
  }

  /// Starts following from āyah [g], word [word0], with [model].
  Future<void> start(({String dir, FollowTier tier}) model, int g, int word0) async {
    if (active) await stop();
    status.value = FollowStatus.starting;
    failure = null;
    try {
      final w = words = await FollowWords.load();
      final from = w.indexOf(g, word0);
      final e = _engine = await (debugEngine ?? SherpaFollowEngine.spawn)(w, model);
      if (status.value != FollowStatus.starting) {
        // Stopped while it was getting ready.
        await e.dispose();
        return;
      }
      _sub = e.events.listen(_onEvent);
      _heardSub = e.heard.listen((h) => heard.value = h);
      _levelSub = e.levels.listen(_onLevel);
      word.value = from - 1;
      if (_view.isNotEmpty) e.setView(_view);
      if (!await e.start(from)) {
        failure = 'mic';
        await _teardown(FollowStatus.failed);
        return;
      }
      status.value = FollowStatus.listening;
      _watchMic();
      _watchLifecycle(true);
    } catch (e) {
      failure = '$e';
      debugPrint('follow: $e');
      await _teardown(FollowStatus.failed);
    }
  }

  void _onEvent((String, int) e) {
    final (kind, w) = e;
    // Fed a recording (desktop, for checking): what it follows, logged.
    FollowDebug.log(() {
      final ws = words;
      if (ws == null || w < 0) return 'follow: $kind';
      final (su, ay) = MushafRepo.surahAyahOf(ws.ayahOf[w]);
      return 'follow: $kind $su:$ay:${ws.word0Of[w] + 1}';
    });
    switch (kind) {
      case 'lost':
        // Said only if nothing's found for a moment: a long pause is not lost.
        _searching ??= Timer(const Duration(milliseconds: 1500), () {
          if (status.value == FollowStatus.listening) status.value = FollowStatus.searching;
        });
      default:
        _searching?.cancel();
        _searching = null;
        if (status.value == FollowStatus.searching) status.value = FollowStatus.listening;
        word.value = w;
        if (kind == 'jump') jumps.value++;
    }
  }

  /// They'll recite from āyah [g], word [word0] (a word tapped, a page
  /// turned by hand).
  void setPosition(int g, int word0) {
    final w = words, e = _engine;
    if (w == null || e == null) return;
    final i = w.indexOf(g, word0);
    word.value = i - 1;
    e.setPosition(i);
  }

  /// The pages in view, best first, as word ranges ([viewOf] makes them):
  /// a phrase that comes in several places is taken on the page in view,
  /// then the next, then the one before, before anywhere else.
  void setView(List<(int, int)> ranges) {
    _view = ranges;
    _engine?.setView(ranges);
  }

  List<(int, int)> _view = const [];

  /// The words of [script]'s tokens [first]..[end) (end exclusive), as a
  /// range of [words]; null if none are words.
  (int, int)? wordsOfTokens(String script, int first, int end) {
    final w = words;
    if (w == null) return null;
    int? a, b;
    for (var t = first; t < end; t++) {
      final (g, i) = MushafRepo.tokenAt(script, t);
      if (i < 0) continue;
      final x = w.indexOf(g, i);
      a ??= x;
      b = x;
    }
    return a == null ? null : (a, b!);
  }

  /// [script]'s pages [first]..[last] in view: those, then the next page,
  /// then the one before.
  List<(int, int)> viewOf(String script, int first, int last) {
    final pages = MushafRepo.pageCountSync(script);
    (int, int)? of(int p) {
      if (p < 1 || p > pages) return null;
      final (a, b) = MushafRepo.pageTokens(script, p);
      return wordsOfTokens(script, a, b);
    }
    (int, int)? span(int p, int q) {
      final x = of(p), y = of(q);
      return x == null || y == null ? x ?? y : (x.$1, y.$2);
    }
    return [?span(first, last), ?of(last + 1), ?of(first - 1)];
  }

  /// The mic off for a while (the model stays ready).
  Future<void> pause() async {
    if (status.value != FollowStatus.listening && status.value != FollowStatus.searching) return;
    await _engine?.stop();
    status.value = FollowStatus.paused;
    _micCheck?.cancel();
    micProblem.value = null;
    level.value = 0;
  }

  Future<void> resume() async {
    final e = _engine;
    if (e == null || status.value != FollowStatus.paused) return;
    if (!await e.start(word.value + 1)) {
      failure = 'mic';
      await _teardown(FollowStatus.failed);
      return;
    }
    status.value = FollowStatus.listening;
    _watchMic();
  }

  /// Off, the model freed.
  Future<void> stop() => _teardown(FollowStatus.off);

  Future<void> _teardown(FollowStatus to) async {
    _searching?.cancel();
    _searching = null;
    _micCheck?.cancel();
    _micCheck = null;
    await _sub?.cancel();
    await _heardSub?.cancel();
    await _levelSub?.cancel();
    _sub = null;
    _heardSub = null;
    _levelSub = null;
    level.value = 0;
    micProblem.value = null;
    _watchLifecycle(false);
    final e = _engine;
    _engine = null;
    status.value = to;
    word.value = -1;
    heard.value = null;
    _view = const [];
    await e?.dispose();
  }
}

/// The real engine: the mic, streamed to the worker isolate (the model, the
/// voice detector and the aligner); only small events come back.
class SherpaFollowEngine implements FollowEngine {
  final Isolate _isolate;
  final SendPort _to;
  final ReceivePort _port;
  final StreamSubscription<dynamic> _portSub;
  final _events = StreamController<(String, int)>.broadcast();
  final _heard = StreamController<FollowHeard>.broadcast();
  final _levels = StreamController<double>.broadcast();
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _mic;
  bool _disposed = false;

  /// What's heard, kept for tuning (see [FollowSession.keepRecordings]).
  IOSink? _keep;

  /// The loudest sample since the level was last said, and when that was.
  double _peak = 0;
  final _levelClock = Stopwatch()..start();

  SherpaFollowEngine._(this._isolate, this._to, this._port, this._portSub);

  static Future<FollowEngine> spawn(FollowWords words, ({String dir, FollowTier tier}) model) async {
    final port = ReceivePort();
    final ready = Completer<SendPort>();
    SendPort? to;
    late SherpaFollowEngine engine;
    var made = false;
    final sub = port.listen((msg) {
      switch (msg) {
        case SendPort p:
          to = p;
        case FollowReady():
          ready.complete(to!);
        case FollowFailed(:final message):
          if (!ready.isCompleted) {
            ready.completeError(StateError(message));
          } else if (made) {
            engine._events.addError(StateError(message));
          }
        case FollowHeard h:
          if (made) engine._heard.add(h);
        case (String kind, int word):
          if (made) engine._events.add((kind, word));
      }
    });
    final low = model.tier == FollowTier.low;
    final isolate = await Isolate.spawn(followWorkerMain, <Object>[
      port.sendPort,
      FollowWorkerConfig(
        modelPath: '${model.dir}/${FollowModel.model}',
        tokensPath: '${model.dir}/${FollowModel.tokens}',
        vadPath: '${model.dir}/${FollowModel.vad}',
        wordsText: words.text.join('\n'),
        surahOf: words.surahOf,
        windowSeconds: low ? 3 : 4,
      ),
    ], debugName: 'follow');
    final SendPort sendTo;
    try {
      sendTo = await ready.future;
    } catch (_) {
      await sub.cancel();
      port.close();
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    }
    engine = SherpaFollowEngine._(isolate, sendTo, port, sub);
    made = true;
    return engine;
  }

  @override
  Stream<(String, int)> get events => _events.stream;
  @override
  Stream<FollowHeard> get heard => _heard.stream;
  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<bool> start(int fromWord) async {
    if (_disposed) return false;
    setPosition(fromWord);
    if (_mic != null) return true;
    final Stream<Uint8List> stream;
    if (FollowDebug.feedFile case final f?) {
      stream = _fileStream(f);
    } else {
      if (!await _recorder.hasPermission()) return false;
      final id = FollowSession.instance.micId;
      stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kFollowSampleRate,
        numChannels: 1,
        device: id == null ? null : InputDevice(id: id, label: id),
        // A phone's noise suppression can smear long vowels.
        noiseSuppress: false,
        echoCancel: false,
      ));
    }
    if (FollowSession.instance.keepRecordings) await _openKeep();
    _mic = stream.listen((bytes) {
      _keep?.add(bytes);
      _measure(bytes);
      _to.send(FollowAudio(TransferableTypedData.fromList([bytes])));
    }, onError: (Object e) => _events.addError(e));
    return true;
  }

  /// The chunk's loudest sample; said about eight times a second.
  void _measure(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    var peak = 0;
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final v = bd.getInt16(i, Endian.little).abs();
      if (v > peak) peak = v;
    }
    final p = peak / 32768;
    if (p > _peak) _peak = p;
    if (_levelClock.elapsedMilliseconds >= 120) {
      _levels.add(_peak);
      _peak = 0;
      _levelClock.reset();
    }
  }

  /// [path] in 100 ms pieces, at the pace it was spoken.
  Stream<Uint8List> _fileStream(String path) {
    var data = File(path).readAsBytesSync();
    if (path.endsWith('.wav') && data.length > 44) data = Uint8List.sublistView(data, 44);
    const chunk = kFollowSampleRate * 2 ~/ 10;
    var at = 0;
    late final StreamController<Uint8List> c;
    Timer? t;
    c = StreamController<Uint8List>(
      onListen: () => t = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (at >= data.length) {
          // The recording over: silence after it.
          c.add(Uint8List(chunk));
          return;
        }
        final end = at + chunk < data.length ? at + chunk : data.length;
        c.add(Uint8List.sublistView(data, at, end));
        at = end;
      }),
      onCancel: () => t?.cancel(),
    );
    return c.stream;
  }

  /// A new file for what's heard: `<app support>/follow/recordings/<time>.pcm`.
  Future<void> _openKeep() async {
    try {
      final dir = await FollowRecordings.dir();
      await dir.create(recursive: true);
      await FollowRecordings.prune();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      _keep = File('${dir.path}/$stamp.pcm').openWrite();
    } catch (e) {
      debugPrint('follow: no recording kept: $e');
    }
  }

  @override
  void setPosition(int word) => _to.send(FollowSetPosition(word));

  @override
  void setView(List<(int, int)> ranges) => _to.send(FollowSetView(Int32List.fromList([
        for (final (a, b) in ranges) ...[a, b],
      ])));

  @override
  Future<void> stop() async {
    await _mic?.cancel();
    _mic = null;
    await _keep?.close();
    _keep = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    _to.send(const FollowResetAudio());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _recorder.dispose();
    _to.send(const FollowShutdown());
    // A moment to free the model, then make sure it's gone.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _isolate.kill(priority: Isolate.beforeNextEvent);
    await _portSub.cancel();
    _port.close();
    await _events.close();
    await _heard.close();
    await _levels.close();
  }
}

class _FollowLifecycle with WidgetsBindingObserver {
  final FollowSession session;
  _FollowLifecycle(this.session);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => session._onLifecycle(state);
}

/// What "Keep recordings for tuning" has saved: raw 16 kHz audio, about
/// 115 MB an hour — kept to [cap], the oldest going first, and deleted at a
/// tap.
abstract final class FollowRecordings {
  static const cap = 500 * 1024 * 1024;

  /// Tests: the folder, in place of the app's.
  @visibleForTesting
  static String? debugDir;

  static Future<Directory> dir() async => Directory(
      debugDir ?? '${(await getApplicationSupportDirectory()).path}/follow/recordings');

  static Future<List<File>> _files() async {
    final d = await dir();
    if (!d.existsSync()) return const [];
    return [for (final f in d.listSync()) if (f is File && f.path.endsWith('.pcm')) f]
      ..sort((a, b) => a.path.compareTo(b.path)); // named by time: oldest first
  }

  /// How much is kept, in bytes.
  static Future<int> size() async {
    var n = 0;
    for (final f in await _files()) {
      n += f.lengthSync();
    }
    return n;
  }

  /// The oldest removed until what's kept is under [cap].
  static Future<void> prune() async {
    final files = await _files();
    var n = 0;
    for (final f in files) {
      n += f.lengthSync();
    }
    for (final f in files) {
      if (n <= cap) break;
      n -= f.lengthSync();
      f.deleteSync();
    }
  }

  static Future<void> deleteAll() async {
    for (final f in await _files()) {
      f.deleteSync();
    }
  }
}
