import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show State, StatefulWidget;

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Quran Foundation's terms for offline-caching their API/CDN content
/// require cached data to be refreshed at least weekly. This tracks when
/// each quran.com-family file (timings, word-by-word audio, and verse audio
/// actually served from quran.com/quranicaudio.com rather than EveryAyah)
/// was last fetched, so [refreshStaleQuranCache] can silently refetch
/// anything older than 7 days. EveryAyah-origin files are deliberately never
/// recorded here — a different provider, with no such requirement confirmed.
///
/// Manifest: `{appDocs}/noor_quran/fetch_log.json`, `{key: isoTimestamp}`.
/// Key formats: `timings:{rid}:{surah}`, `wbw:{s}:{v}:{w}`,
/// `verse:{reciter}:{s}:{v}`.
class _FetchLog {
  static const _maxAge = Duration(days: 7);
  static File? _file;
  static Map<String, dynamic>? _mem;

  static Future<File?> _resolveFile() async {
    if (_file != null) return _file;
    try {
      final b = await getApplicationDocumentsDirectory();
      final dir = Directory('${b.path}/noor_quran');
      await dir.create(recursive: true);
      return _file = File('${dir.path}/fetch_log.json');
    } catch (_) {
      return null; // web: no local storage
    }
  }

  static Future<Map<String, dynamic>> _load() async {
    if (_mem != null) return _mem!;
    final f = await _resolveFile();
    if (f == null) return _mem = {};
    try {
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is Map<String, dynamic>) return _mem = decoded;
      }
    } catch (_) {}
    return _mem = {};
  }

  static Future<void> _save() async {
    final f = await _resolveFile();
    if (f == null || _mem == null) return;
    try {
      await f.writeAsString(jsonEncode(_mem));
    } catch (_) {}
  }

  static Future<void> record(String key) async {
    final m = await _load();
    m[key] = DateTime.now().toIso8601String();
    await _save();
  }

  /// Keys whose last fetch is more than 7 days old. Keys never recorded
  /// (nothing downloaded yet) are not "stale" — there's nothing to refresh.
  static Future<List<String>> staleKeys() async {
    final m = await _load();
    final now = DateTime.now();
    return [
      for (final e in m.entries)
        if (DateTime.tryParse(e.value as String? ?? '') case final t?)
          if (now.difference(t) > _maxAge) e.key,
    ];
  }
}

/// True for hosts actually reachable through the Quran Foundation API/CDN
/// (verses.quran.com, and the quranicaudio.com mirror it sometimes returns
/// for reciters quran.com doesn't host directly) — as opposed to EveryAyah,
/// which this app also uses but which nothing here tracks for refresh.
@visibleForTesting
bool isQuranFoundationOrigin(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'verses.quran.com' ||
      host == 'quranicaudio.com' ||
      host.endsWith('.quranicaudio.com');
}

/// Every host this app is allowed to fetch or play Qur'anic audio from. A
/// verse-timings response can hand back a host-qualified URL (see the
/// "some reciters return a host-qualified path" comment in `_versesFor`) —
/// this is the fixed allowlist that URL is checked against before it is
/// ever fetched or played, so a change in the upstream API's response shape
/// can't silently redirect playback/downloads to an arbitrary host. This is
/// broader than [isQuranFoundationOrigin] (which exists only to decide the
/// weekly-refresh bookkeeping and deliberately excludes EveryAyah).
@visibleForTesting
bool isKnownAudioHost(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'everyayah.com' ||
      host == 'audio.qurancdn.com' ||
      isQuranFoundationOrigin(url);
}

/// Silently re-fetches any quran.com-sourced cached audio/timings older than
/// 7 days, per Quran Foundation's offline-caching terms. Safe to call
/// opportunistically and often — a failed request is retried the next call,
/// which is itself the offline signal, so there's no separate connectivity
/// check.
Future<void> refreshStaleQuranCache() async {
  await AyahAudio.instance.refreshStaleCache();
  await WbwAudio.instance.refreshStaleWords();
}

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

  /// Download every word of a surah for offline playback. Reports
  /// (done, total) — `done` always advances so the progress UI reaches
  /// 100%, but the returned bool is true only if every word file ends up
  /// present (previously this always returned true regardless of how many
  /// downloads actually failed). Returns false on platforms without local
  /// storage (web) or if the handle is cancelled mid-download.
  Future<bool> downloadSurah(int surah, List<int> wordsPerAyah,
      void Function(int done, int total) onProgress,
      {PlaybackHandle? handle}) async {
    final dir = await _localDir();
    if (dir == null) return false;
    final total = wordsPerAyah.fold(0, (a, b) => a + b);
    var done = 0;
    var allPresent = true;
    for (var v = 1; v <= wordsPerAyah.length; v++) {
      for (var w = 1; w <= wordsPerAyah[v - 1]; w++) {
        if (handle?.cancelled ?? false) return false;
        final f = File('${dir.path}/${fileName(surah, v, w)}');
        var exists = await f.exists();
        if (!exists) {
          try {
            final res = await http
                .get(Uri.parse(url(surah, v, w)))
                .timeout(const Duration(seconds: 20));
            if (res.statusCode == 200) {
              await f.writeAsBytes(res.bodyBytes, flush: false);
              exists = true;
              await _FetchLog.record('wbw:$surah:$v:$w'); // always quran.com-origin
            }
          } catch (_) {}
        }
        if (!exists) allPresent = false;
        done++;
        onProgress(done, total);
      }
    }
    return allPresent;
  }

  /// Per-surah downloaded-file counts, from a single directory listing —
  /// same approach as [AyahAudio.downloadedCounts].
  Future<Map<int, int>> downloadedCounts() async {
    final dir = await _localDir();
    if (dir == null || !await dir.exists()) return {};
    final counts = <int, int>{};
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final surah = int.tryParse(e.uri.pathSegments.last.split('_').first);
      if (surah == null) continue;
      counts[surah] = (counts[surah] ?? 0) + 1;
    }
    return counts;
  }

  /// Total bytes on disk for downloaded word-by-word audio.
  Future<int> bytesUsed() async {
    final dir = await _localDir();
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Deletes downloaded word-by-word audio for one sūrah.
  Future<void> deleteSurah(int surah) async {
    final dir = await _localDir();
    if (dir == null) return;
    final prefix = '${surah.toString().padLeft(3, '0')}_';
    await for (final e in dir.list()) {
      if (e is File && e.uri.pathSegments.last.startsWith(prefix)) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

  /// Deletes every downloaded word-by-word audio file.
  Future<void> deleteAll() async {
    final dir = await _localDir();
    if (dir == null || !await dir.exists()) return;
    await for (final e in dir.list()) {
      if (e is File) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

  /// Re-fetches word-by-word files older than 7 days. See
  /// AyahAudio.refreshStaleCache / [refreshStaleQuranCache].
  Future<void> refreshStaleWords() async {
    final dir = await _localDir();
    if (dir == null) return;
    for (final key in await _FetchLog.staleKeys()) {
      final parts = key.split(':');
      if (parts.length != 4 || parts[0] != 'wbw') continue;
      try {
        final s = int.parse(parts[1]);
        final v = int.parse(parts[2]);
        final w = int.parse(parts[3]);
        final res = await http
            .get(Uri.parse(url(s, v, w)))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          await File('${dir.path}/${fileName(s, v, w)}')
              .writeAsBytes(res.bodyBytes, flush: false);
          await _FetchLog.record(key);
        }
      } catch (_) {}
    }
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
  /// none — the last word whose start has been reached.
  ///
  /// A word stays lit until the next one begins rather than going dark at its
  /// own end time: reciters leave real silence between words (Ḥuṣarī pauses
  /// 1.2 s inside 2:2), and the final word has to hold through the trailing
  /// silence, which is also what absorbs the ~200 ms position-poll interval.
  int wordAt(Duration p) => wordAtIn(segments, p);

  /// Pure form of [wordAt], over an explicit segment list.
  @visibleForTesting
  static int wordAtIn(List<List<int>>? seg, Duration p) {
    if (seg == null) return -1;
    final ms = p.inMilliseconds;
    var word = -1, bestStart = -1;
    for (final s in seg) {
      if (s[1] <= ms && s[1] > bestStart) {
        bestStart = s[1];
        word = s[0];
      }
    }
    return word;
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

  /// Normalise one verse's segment rows to *this verse file's* timeline.
  ///
  ///  • quran.com rows are `[segmentIdx0, wordPos1Based, startMs, endMs]`.
  ///    The **segment index is not the word index**: when a reciter runs two
  ///    words together the two diverge (2:20 has a row `[5, 7, …]` and no
  ///    segment 6), so the 1-based word position is the only field that maps
  ///    onto our token list. Stored 0-based.
  ///  • start/end are forced verse-relative: when the first word claims to
  ///    begin implausibly deep into a file that only contains this verse, the
  ///    times are chapter offsets — rebase them to the verse start. (Real
  ///    payloads are already verse-relative; this is a defensive guard.)
  @visibleForTesting
  static List<List<int>>? normaliseSegments(List raw) {
    final segs = <List<int>>[];
    for (final e in raw) {
      if (e is! List || e.length < 3) continue; // legacy rows like [0]
      final n = e.map((x) => (x is num) ? x.toInt() : -1).toList();
      final (word, start, end) =
          n.length >= 4 ? (n[1], n[2], n[3]) : (n[0], n[1], n[2]);
      if (word < 1 || end <= start) continue;
      segs.add([word - 1, start, end]);
    }
    if (segs.isEmpty) return null;
    final base = segs.first[1] > 5000 ? segs.first[1] : 0;
    if (base == 0) return segs;
    return [
      for (final s in segs) [s[0], s[1] - base, s[2] - base],
    ];
  }

  Future<Map<int, _VerseAudio>?> _versesFor(int rid, int surah,
      {bool force = false}) async {
    final key = '$rid:$surah';
    final cached = _timings[key];
    if (cached != null && !force) return cached;
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
        await _FetchLog.record('timings:$rid:$surah');
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
        out[v] =
            _VerseAudio(url, normaliseSegments(m['segments'] as List? ?? const []));
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
        if (va != null && isKnownAudioHost(va.url)) {
          segments = va.segments;
          url = va.url;
          // Right verse, right reciter — but no word timings to highlight with.
          if (va.segments == null) fellBack = true;
          debugPrint(
              '[AyahAudio] $reciter $s:$v → ${va.url} (${va.segments?.length ?? 0} word segments)');
        } else {
          // Either no timings at all, or the API handed back a URL whose
          // host isn't on the fixed allowlist — either way, fall through to
          // urlFor()'s hardcoded template below rather than trust it.
          fellBack = true;
          debugPrint(va == null
              ? '[AyahAudio] $reciter $s:$v timings unavailable'
              : '[AyahAudio] $reciter $s:$v timings URL host not allow-listed: ${va.url}');
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
  /// timings for timed reciters. Reports (done, total) — `done` always
  /// advances so the progress UI reaches 100%, but the returned bool
  /// reflects reality: true only if every āyah file ends up present, false
  /// if any download failed (previously this always returned true, so
  /// "Sūrah audio saved" could appear after a total network failure).
  /// Returns false immediately on platforms without local storage (web).
  Future<bool> downloadSurah(int surah, int ayahs,
      void Function(int done, int total) onProgress,
      {String reciter = 'tunaiji'}) async {
    final dir = await _localDir(reciter);
    if (dir == null) return false;
    // Cache the timings JSON first so read-along works offline too.
    final rid = timedReciters[reciter];
    final verses = rid == null ? null : await _versesFor(rid, surah);
    var done = 0;
    var allPresent = true;
    for (var v = 1; v <= ayahs; v++) {
      final f = File('${dir.path}/${fileName(surah, v)}');
      var exists = await f.exists();
      if (!exists) {
        try {
          final timedUrl = verses?[v]?.url;
          final src = (timedUrl != null && isKnownAudioHost(timedUrl))
              ? timedUrl
              : urlFor(surah, v, reciter: reciter);
          final res = await http
              .get(Uri.parse(src))
              .timeout(const Duration(seconds: 25));
          if (res.statusCode == 200) {
            await f.writeAsBytes(res.bodyBytes, flush: false);
            exists = true;
            // Only quran.com/quranicaudio.com-sourced files are covered by
            // the weekly-refresh requirement — see _FetchLog.
            if (isQuranFoundationOrigin(src)) {
              await _FetchLog.record('verse:$reciter:$surah:$v');
            }
          }
        } catch (_) {}
      }
      if (!exists) allPresent = false;
      done++;
      onProgress(done, ayahs);
    }
    return allPresent;
  }

  /// Per-surah downloaded-file counts for [reciter], built from a single
  /// directory listing rather than probing every expected filename — cheap
  /// even across the whole muṣḥaf. Powers the Downloads screen's "what's
  /// already on disk" view; there is no separate persisted manifest.
  Future<Map<int, int>> downloadedCounts(String reciter) async {
    final dir = await _localDir(reciter);
    if (dir == null || !await dir.exists()) return {};
    final counts = <int, int>{};
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (name.length < 6) continue;
      final surah = int.tryParse(name.substring(0, 3));
      if (surah == null) continue;
      counts[surah] = (counts[surah] ?? 0) + 1;
    }
    return counts;
  }

  /// Total bytes on disk for [reciter]'s downloaded verse audio.
  Future<int> bytesUsed(String reciter) async {
    final dir = await _localDir(reciter);
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Deletes [reciter]'s downloaded verse audio for one sūrah.
  Future<void> deleteSurah(String reciter, int surah) async {
    final dir = await _localDir(reciter);
    if (dir == null) return;
    final prefix = surah.toString().padLeft(3, '0');
    await for (final e in dir.list()) {
      if (e is File && e.uri.pathSegments.last.startsWith(prefix)) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

  /// Deletes every downloaded verse audio file for [reciter].
  Future<void> deleteAll(String reciter) async {
    final dir = await _localDir(reciter);
    if (dir == null || !await dir.exists()) return;
    await for (final e in dir.list()) {
      if (e is File) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

  /// Re-fetches this reciter's quran.com-sourced timings/verse audio older
  /// than 7 days. Called from [refreshStaleQuranCache]; not meant to be
  /// awaited by UI code — it's a silent background pass.
  Future<void> refreshStaleCache() async {
    for (final key in await _FetchLog.staleKeys()) {
      final parts = key.split(':');
      try {
        if (parts.length == 3 && parts[0] == 'timings') {
          final rid = int.parse(parts[1]);
          final surah = int.parse(parts[2]);
          await _versesFor(rid, surah, force: true);
        } else if (parts.length == 4 && parts[0] == 'verse') {
          await _refetchVerse(parts[1], int.parse(parts[2]), int.parse(parts[3]));
        }
      } catch (_) {}
    }
  }

  Future<void> _refetchVerse(String reciter, int s, int v) async {
    final dir = await _localDir(reciter);
    if (dir == null) return;
    final rid = timedReciters[reciter];
    final verses = rid == null ? null : await _versesFor(rid, s, force: true);
    final url = verses?[v]?.url;
    // If this verse no longer resolves to a quran.com-family URL, leave the
    // existing file alone — refreshing it isn't this cache's job anymore.
    if (url == null || !isQuranFoundationOrigin(url)) return;
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      await File('${dir.path}/${fileName(s, v)}')
          .writeAsBytes(res.bodyBytes, flush: false);
      await _FetchLog.record('verse:$reciter:$s:$v');
    }
  }
}

/// Shared word-highlight tracking for screens that show live recitation
/// progress (the Qur'an reader and the Muṣḥaf page view both do this the
/// same way — they just differ in how playback itself starts/stops/repeats,
/// which is why only this shared slice is pulled out rather than the whole
/// playback state machine).
mixin RecitationPositionMixin<T extends StatefulWidget> on State<T> {
  /// True while a verse recitation (not a single-word tap) is active.
  bool get isReciting;

  /// The word index currently highlighted (-1 = none) — backed by whatever
  /// field the screen already uses, so other code paths that set it directly
  /// (e.g. word-by-word playback) stay in sync automatically.
  int get recitedWord;
  set recitedWord(int word);

  void _onRecitePos() {
    if (!mounted || !isReciting) return;
    final w = AyahAudio.instance.wordAt(AyahAudio.instance.pos.value);
    if (w != recitedWord) setState(() => recitedWord = w);
  }

  void initRecitationTracking() =>
      AyahAudio.instance.pos.addListener(_onRecitePos);

  void disposeRecitationTracking() =>
      AyahAudio.instance.pos.removeListener(_onRecitePos);
}

class _VerseAudio {
  final String url;
  final List<List<int>>? segments; // verse-relative [word0, startMs, endMs]
  const _VerseAudio(this.url, this.segments);
}
