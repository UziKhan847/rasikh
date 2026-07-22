import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 🔊 Word-by-word recitation audio.
///
/// Recordings courtesy of **Markaz Tafsir**, served via QuranCDN:
///   https://audio.qurancdn.com/wbw/{sss}_{vvv}_{www}.mp3
/// Playback is local-first: if the word was downloaded it plays from disk,
/// otherwise it streams. `downloadSurah` fetches every word of a surah for
/// fully offline use.
class WbwAudio {
  WbwAudio._();
  static final WbwAudio instance = WbwAudio._();

  final AudioPlayer _player = AudioPlayer();
  PlaybackHandle? _active;

  static String fileName(int s, int v, int w) =>
      '${s.toString().padLeft(3, '0')}_${v.toString().padLeft(3, '0')}_${w.toString().padLeft(3, '0')}.mp3';

  static String url(int s, int v, int w) =>
      'https://audio.qurancdn.com/wbw/${fileName(s, v, w)}';

  Future<Directory?> _localDir() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/noor_quran/wbw');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null; // web: no local storage — stream instead
    }
  }

  Future<File?> localFile(int s, int v, int w) async {
    final dir = await _localDir();
    if (dir == null) return null;
    final f = File('${dir.path}/${fileName(s, v, w)}');
    return await f.exists() ? f : null;
  }

  /// Play a single word; cancels anything currently playing.
  Future<void> playWord(int s, int v, int w) async {
    _active?.cancel();
    await _player.stop();
    final f = await localFile(s, v, w);
    await _player
        .play(f != null ? DeviceFileSource(f.path) : UrlSource(url(s, v, w)));
  }

  Future<void> _playToEnd(int s, int v, int w) async {
    final done = Completer<void>();
    late final StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    }, onError: (Object e) {
      debugPrint('[WbwAudio] player error: $e');
      if (!done.isCompleted) done.complete(); // skip word, keep the sequence
    });
    try {
      await _player.stop();
      final f = await localFile(s, v, w);
      await _player.play(
          f != null ? DeviceFileSource(f.path) : UrlSource(url(s, v, w)));
      await done.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      // skip unplayable word and continue the sequence
    } finally {
      await sub.cancel();
    }
  }

  /// Play an ayah word-by-word, in order. [onWord] reports the 0-based
  /// index of the word now playing (or -1 when finished/cancelled).
  PlaybackHandle playAyah(
          int surah, int ayah, int wordCount, void Function(int) onWord) =>
      playWords(surah, ayah, 1, wordCount, onWord);

  /// Play a RANGE of words [firstWord..lastWord] (1-based, inclusive) —
  /// used by grouped word-by-word segments.
  PlaybackHandle playWords(int surah, int ayah, int firstWord, int lastWord,
      void Function(int) onWord) {
    _active?.cancel();
    final handle = PlaybackHandle();
    _active = handle;
    () async {
      for (var w = firstWord; w <= lastWord; w++) {
        if (handle.cancelled) break;
        onWord(w - 1);
        await _playToEnd(surah, ayah, w);
      }
      if (!handle.cancelled) onWord(-1);
    }();
    return handle;
  }

  Future<void> stop() async {
    _active?.cancel();
    await _player.stop();
  }

  /// Download every word of a surah for offline playback.
  /// Reports (done, total). Returns false on platforms without local
  /// storage (web) or when the network fails entirely.
  Future<bool> downloadSurah(int surah, List<int> wordsPerAyah,
      void Function(int done, int total) onProgress,
      {PlaybackHandle? handle}) async {
    final dir = await _localDir();
    if (dir == null) return false;
    final total = wordsPerAyah.fold(0, (a, b) => a + b);
    var done = 0;
    for (var v = 1; v <= wordsPerAyah.length; v++) {
      for (var w = 1; w <= wordsPerAyah[v - 1]; w++) {
        if (handle?.cancelled ?? false) return false;
        final f = File('${dir.path}/${fileName(surah, v, w)}');
        if (!await f.exists()) {
          try {
            final res = await http
                .get(Uri.parse(url(surah, v, w)))
                .timeout(const Duration(seconds: 20));
            if (res.statusCode == 200) {
              await f.writeAsBytes(res.bodyBytes, flush: false);
            }
          } catch (_) {}
        }
        done++;
        onProgress(done, total);
      }
    }
    return true;
  }
}

class PlaybackHandle {
  bool cancelled = false;
  void cancel() => cancelled = true;
}


/// 🎙 Verse-by-verse recitation — Shaykh Khalifah Al-Tunaiji,
/// streamed from EveryAyah ({sss}{vvv}.mp3) with local-first playback and
/// per-surah downloads, exactly like the word-by-word audio.
/// 🔊 Verse-by-verse recitation.
///
/// Every reciter plays **one mp3 per āyah** (EveryAyah / quran.com verse CDN).
/// Nothing is ever seeked into a chapter-length file, so the verse you ask for
/// is always the verse you hear, and the file ending *is* the verse ending.
///
/// For the timed reciters (Al-ʿAfāsī, Al-Ḥuṣarī) quran.com also publishes
/// per-verse **word segments**; those drive the read-along highlight. The
/// segments belong to the very file being played, so they can't drift. If the
/// timings can't be fetched the verse still plays — only the word highlight is
/// skipped.
class AyahAudio {
  AyahAudio._();
  static final AyahAudio instance = AyahAudio._();

  /// EveryAyah folder per reciter (per-verse mp3s: `002255.mp3`).
  static const Map<String, String> _folders = {
    'tunaiji': 'khalefa_al_tunaiji_64kbps',
    'alafasy': 'Alafasy_128kbps',
    'husary': 'Husary_128kbps',
  };
  static const _everyAyah = 'https://everyayah.com/data';

  /// Reciters with word-level timings, keyed by quran.com **ayah-by-ayah
  /// recitation id** (`/resources/recitations`). These ids are NOT the same as
  /// the chapter-reciter ids — the verse endpoint below expects these.
  static const Map<String, int> timedReciters = {
    'alafasy': 7, // Mishary Rashid Al-ʿAfāsī
    'husary': 6, // Maḥmūd Khalīl Al-Ḥuṣarī
  };
  static const _v4 = 'https://api.quran.com/api/v4';
  static const _verseCdn = 'https://verses.quran.com';

  final AudioPlayer _player = AudioPlayer();

  // ── observable playback state (drives the reader's player bar) ──
  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<Duration> pos = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> dur = ValueNotifier(Duration.zero);

  /// Word timings for the verse now playing, relative to the verse's own file:
  /// [wordIndex0, startMs, endMs]. Null when the reciter has no timing data.
  List<List<int>>? segments;

  /// True when a timed reciter was asked for but no word timings were
  /// available (offline / API down). The verse still plays — the read-along
  /// highlight is simply skipped, and the UI shows a one-time notice.
  bool fellBack = false;

  final StreamController<void> _doneCtl = StreamController.broadcast();
  Stream<void> get onComplete => _doneCtl.stream;

  static String fileName(int s, int v) =>
      '${s.toString().padLeft(3, '0')}${v.toString().padLeft(3, '0')}.mp3';

  static String folderFor(String reciter) =>
      _folders[reciter] ?? _folders['tunaiji']!;

  String urlFor(int s, int v, {String reciter = 'tunaiji'}) =>
      '$_everyAyah/${folderFor(reciter)}/${fileName(s, v)}';

  Future<Directory?> _localDir(String reciter) async {
    try {
      final b = await getApplicationDocumentsDirectory();
      final dir = Directory('${b.path}/noor_quran/$reciter');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null; // web: no local storage — stream instead
    }
  }

  Future<File?> _localFile(String reciter, int s, int v) async {
    final dir = await _localDir(reciter);
    if (dir == null) return null;
    final f = File('${dir.path}/${fileName(s, v)}');
    return await f.exists() ? f : null;
  }

  bool _hooked = false;
  void _hook() {
    if (_hooked) return;
    _hooked = true;
    // A native playback error is delivered as an error event on EVERY derived
    // stream; a subscription without onError turns it into an unhandled
    // exception that crashes the app. So every listener gets a handler, and
    // the first one to see the error also unsticks the UI.
    void onErr(Object e) {
      debugPrint('[AyahAudio] player error: $e');
      playing.value = false;
      if (!_doneCtl.isClosed) _doneCtl.add(null); // let auto-flow move on
    }

    _player.onLog
        .listen((m) => debugPrint('[AyahAudio] player: $m'), onError: onErr);
    _player.onPositionChanged
        .listen((raw) => pos.value = raw, onError: (Object e) {});
    _player.onDurationChanged
        .listen((d) => dur.value = d, onError: (Object e) {});
    _player.onPlayerStateChanged.listen(
        (st) => playing.value = st == PlayerState.playing,
        onError: (Object e) {});
    _player.onPlayerComplete.listen((_) {
      playing.value = false;
      pos.value = Duration.zero;
      _doneCtl.add(null);
    }, onError: (Object e) {});
  }

  /// Word index (0-based) highlighted at verse-relative position [p], -1 if
  /// none.
  int wordAt(Duration p) {
    final seg = segments;
    if (seg == null) return -1;
    final ms = p.inMilliseconds;
    for (final s in seg) {
      if (ms >= s[1] && ms < s[2]) return s[0];
    }
    return -1;
  }

  // ── per-verse timings + urls from quran.com ──
  final Map<String, Map<int, _VerseAudio>> _timings = {};

  Future<Directory?> _timingsDir() async {
    try {
      final b = await getApplicationDocumentsDirectory();
      final dir = Directory('${b.path}/noor_quran/timings');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Normalise one verse's segment triplets to *this verse file's* timeline.
  ///
  ///  • Word positions are **1-based** (quran.com convention) → stored
  ///    0-based. Some files carry a leading index-0 stub for the pre-roll
  ///    silence; dropping it (instead of treating it as "the minimum index")
  ///    is what keeps the highlight from running one word ahead of the
  ///    reciter.
  ///  • start/end are forced verse-relative: when the first word claims to
  ///    begin implausibly deep into a file that only contains this verse, the
  ///    times are chapter offsets — rebase them to the verse start.
  List<List<int>>? _normalise(List raw) {
    final segs = <List<int>>[];
    for (final e in raw) {
      if (e is! List || e.length < 3) continue; // legacy rows like [0]
      final n = e.map((x) => (x is num) ? x.toInt() : -1).toList();
      if (n[0] < 1 || n[2] <= n[1]) continue; // index-0 pre-roll stub etc.
      segs.add([n[0] - 1, n[1], n[2]]);
    }
    if (segs.isEmpty) return null;
    final base = segs.first[1] > 5000 ? segs.first[1] : 0;
    if (base == 0) return segs;
    return [
      for (final s in segs) [s[0], s[1] - base, s[2] - base],
    ];
  }

  Future<Map<int, _VerseAudio>?> _versesFor(int rid, int surah) async {
    final key = '$rid:$surah';
    final cached = _timings[key];
    if (cached != null) return cached;
    final dir = await _timingsDir();
    final jf = dir == null ? null : File('${dir.path}/$rid-$surah.json');

    String? body;
    try {
      final r = await http
          .get(Uri.parse(
              '$_v4/recitations/$rid/by_chapter/$surah?fields=segments&per_page=300'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        body = r.body;
        try {
          await jf?.writeAsString(body); // offline read-along
        } catch (_) {}
      }
    } catch (_) {}
    if (body == null && jf != null && await jf.exists()) {
      body = await jf.readAsString();
    }
    if (body == null) return null;

    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final files = j['audio_files'] as List?;
      if (files == null || files.isEmpty) return null;
      final out = <int, _VerseAudio>{};
      for (final e in files) {
        final m = e as Map<String, dynamic>;
        final vk = (m['verse_key'] ?? '') as String;
        final v = int.tryParse(vk.split(':').last) ?? -1;
        if (v < 1) continue;
        var url = (m['url'] ?? m['audio_url'] ?? '') as String;
        if (url.isEmpty) continue;
        if (!url.startsWith('http')) {
          final rel = url.replaceFirst(RegExp(r'^/+'), '');
          // Some reciters (e.g. Ḥuṣarī) return a HOST-QUALIFIED path like
          // "mirrors.quranicaudio.com/everyayah/…" instead of a
          // verses.quran.com-relative one. A dot in the first segment means
          // it's a hostname — prefixing the verses CDN onto it would 404.
          final firstSeg = rel.split('/').first;
          url = firstSeg.contains('.') ? 'https://$rel' : '$_verseCdn/$rel';
        }
        out[v] = _VerseAudio(url, _normalise(m['segments'] as List? ?? const []));
      }
      if (out.isEmpty) return null;
      _timings[key] = out;
      return out;
    } catch (e) {
      debugPrint('[AyahAudio] timings parse failed: $e');
      return null;
    }
  }

  /// Plays verse [s]:[v]. Returns null on success or a short reason on
  /// failure. [reciter]: 'tunaiji' | 'alafasy' | 'husary' — the latter two
  /// also carry word segments for the read-along highlight.
  Future<String?> play(int s, int v, {String reciter = 'tunaiji'}) async {
    _hook();
    try {
      await WbwAudio.instance.stop();
      segments = null;
      fellBack = false;
      pos.value = Duration.zero;
      dur.value = Duration.zero;

      String? url;
      final rid = timedReciters[reciter];
      if (rid != null) {
        final verses = await _versesFor(rid, s);
        final va = verses?[v];
        if (va != null) {
          segments = va.segments;
          url = va.url;
          // Right verse, right reciter — but no word timings to highlight with.
          if (va.segments == null) fellBack = true;
          debugPrint(
              '[AyahAudio] $reciter $s:$v → ${va.url} (${va.segments?.length ?? 0} word segments)');
        } else {
          // Timings unavailable: still play the right verse, just no highlight.
          fellBack = true;
          debugPrint('[AyahAudio] $reciter $s:$v timings unavailable');
        }
      }
      url ??= urlFor(s, v, reciter: reciter);

      await _player.stop();
      final f = await _localFile(reciter, s, v);
      await _player.play(f != null ? DeviceFileSource(f.path) : UrlSource(url));
      return null;
    } catch (e) {
      debugPrint('[AyahAudio] play error: $e');
      return 'Audio failed: $e';
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();

  /// Seek within the verse now playing (verse-relative, same timeline as
  /// [segments]).
  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> stop() async {
    segments = null;
    await _player.stop();
  }

  /// Download every āyah of a sūrah for offline playback, plus the word
  /// timings for timed reciters. Reports (done, total). Returns false on
  /// platforms without local storage (web).
  Future<bool> downloadSurah(int surah, int ayahs,
      void Function(int done, int total) onProgress,
      {String reciter = 'tunaiji'}) async {
    final dir = await _localDir(reciter);
    if (dir == null) return false;
    // Cache the timings JSON first so read-along works offline too.
    final rid = timedReciters[reciter];
    final verses = rid == null ? null : await _versesFor(rid, surah);
    var done = 0;
    for (var v = 1; v <= ayahs; v++) {
      final f = File('${dir.path}/${fileName(surah, v)}');
      if (!await f.exists()) {
        try {
          final src = verses?[v]?.url ?? urlFor(surah, v, reciter: reciter);
          final res = await http
              .get(Uri.parse(src))
              .timeout(const Duration(seconds: 25));
          if (res.statusCode == 200) {
            await f.writeAsBytes(res.bodyBytes, flush: false);
          }
        } catch (_) {}
      }
      done++;
      onProgress(done, ayahs);
    }
    return true;
  }
}

class _VerseAudio {
  final String url;
  final List<List<int>>? segments; // verse-relative [word0, startMs, endMs]
  const _VerseAudio(this.url, this.segments);
}
