import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../ui/tajwid_colors.dart';
import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/marks/card_align.dart';
import '../core/marks/marks_model.dart';
import '../core/marks/marks_store.dart';
import '../core/marks/word_ref.dart';
import '../core/reader_size.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import '../ui/mark_style.dart';
import '../ui/ornaments/ornaments.dart';
import '../ui/qiraah_ornaments.dart';
import 'marks/marking.dart';
import 'marks/marking_bar.dart';
import 'marks/word_marks_sheet.dart';
import 'mushaf/mushaf_index_sheet.dart';
import 'mushaf_screen.dart';

export 'quran_list_screen.dart' show SurahListScreen, openSurah;

/// 📗 Qur'an Reader — whole Qur'an, both scripts, word-by-word with adjustable
/// gaps / grouping (1–6 words per card) / one card per line, tajwīd colours,
/// ḥarakāt toggle, tap-to-hear words (Markaz Tafsir) and verse recitation —
/// both downloadable for offline use. Laid out to the redesign: a hideable
/// header, the illuminated sūrah banner, a tajwīd key, āyah cards or a word
/// grid, and a player that can be pinned, minimised, floated or hidden.

/// Tajwīd rule colours, by rule index (see `QuranRepo.tajwid`): the
/// redesign's light set, or its night set on the dark themes.
List<Color> tajwidColorsFor(Palette p) => tajwidColorsForDark(p.isDark);

/// The face the reader renders [script] with — fixed per script, not a user
/// choice. Both are DigitalKhatt faces: DigitalKhattIndoPak for Indo-Pak,
/// DigitalKhattV2 for Madani (UthmanicHafs briefly sat alongside it as a
/// picker; DigitalKhatt simply read better, so the choice was dropped rather
/// than kept as a worse second option — see `QuranRepo.ayahs`).
String readerFont(AppSettings s, [String? script]) =>
    (script ?? s.quranScript) == 'indopak' ? s.fontIndopak : 'DigitalKhattV2';

/// The largest reader size for this layout: on desktop it grows with the
/// window (at least 120); 64 on a phone.
double readerMaxPx(BuildContext context) => useDesktop(context)
    ? readerMaxDesktopFor(MediaQuery.sizeOf(context).width)
    : kReaderMaxMobile;

TextStyle quranStyle(BuildContext context,
    {Color? color,
    double base = kReaderBase,
    FontWeight weight = FontWeight.w400,
    Color? background}) {
  final s = SettingsScope.of(context);
  final family = readerFont(s);
  return TextStyle(
    fontFamily: family,
    fontSize: math.min(base * s.quranFontScale, readerMaxPx(context)),
    // Both reader faces are DigitalKhatt (see [readerFont]), whose declared
    // metrics need [MushafRepo.khattLineHeight] — see that constant for
    // where 2.2 and its margin come from.
    height: MushafRepo.khattLineHeight,
    fontWeight: weight,
    backgroundColor: background,
    color: color ?? readingInk(context),
  );
}

/// Arabic-Indic digits for an āyah number.
String arabicIndic(int n) => [
      for (final d in '$n'.runes) String.fromCharCode(0x0660 + d - 0x30),
    ].join();

/// The reader's āyah markers: the muṣḥaf's marker choice ('font' draws
/// the star and ring).
String _markerArt(BuildContext context) {
  final s = SettingsScope.of(context);
  return s.mushafLook(s.quranScript, focus: false).marker;
}

/// The āyah marker's stroke: gold with ornaments on, else the accent.
Color ayahMarkerStroke(BuildContext context) {
  final p = pal(context);
  if (!SettingsScope.of(context).useOrnate) return p.acc;
  return switch (p.theme) {
    AppTheme.mono => const Color(0xFF9A9A9A),
    AppTheme.light => const Color(0xFFC9A253),
    _ => const Color(0xFFCFAE62),
  };
}

// ───────────────────────────── Reader ─────────────────────────────

class SurahReaderScreen extends StatefulWidget with DesktopAware {
  final SurahMeta meta;
  final int? startAyah; // open scrolled to this āyah (1-based)
  const SurahReaderScreen({super.key, required this.meta, this.startAyah});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen>
    with RecitationPositionMixin<SurahReaderScreen> {
  @override
  bool get isReciting => recitingAyah;
  @override
  int get recitedWord => playingWord;
  @override
  set recitedWord(int word) => playingWord = word;

  // A recitation word tick rebuilds only the playing āyah's card and the
  // player's "now" line — not every visible card of the list.
  final _wordTick = ValueNotifier<int>(0);
  final Map<int, ValueNotifier<int>> _ayahTicks = {};
  ValueNotifier<int> _tickFor(int ayahIdx) =>
      _ayahTicks.putIfAbsent(ayahIdx, () => ValueNotifier<int>(0));

  @override
  void onRecitedWordChanged(int word) {
    final a = playingAyah;
    if (a < 0) {
      super.onRecitedWordChanged(word);
      return;
    }
    playingWord = word;
    _tickFor(a).value++;
    _wordTick.value++;
  }

  List<String>? ayahs; // raw ayah strings (current script)
  List<List<String>>? words; // tokens per ayah
  List<TajwidAyah>? tajwid; // char spans for the loaded tajwid script
  String _tajwidScript = ''; // which script the spans were built for
  bool _tajwidLoading = false; // guards the build()-triggered fetch below
  bool get wbwMode => SettingsScope.of(context).wordByWord;

  /// `'<script>/<font>'` — the face is part of it because the two Madani
  /// faces need differently transcoded text (see [QuranRepo.ayahs]), so
  /// switching typeface has to reload, not just repaint.
  String _loadedKey = '';

  int playingAyah = -1;
  int playingWord = -1;
  bool recitingAyah = false; // verse recitation active
  bool _wholeSurah = false; // "recite whole sūrah" — overrides reciteFlow
  PlaybackHandle? _handle;

  /// Where the player starts from when nothing is playing (0-based āyah).
  int _cursor = 0;

  /// The player's mode: 'recite' (verse recitation) or 'wbw' (word by word).
  String _mode = 'recite';

  bool downloading = false;
  bool _warnedFallback = false;
  final Map<int, GlobalKey> _ayahKeys = {};
  int dlDone = 0;
  int dlTotal = 1;

  bool _quickOpen = false; // phone: the "Aa" quick-adjust row
  bool _keyOpen = false; // the tajwīd colour key
  bool _startScrolled = false;

  StreamSubscription<void>? _doneSub;

  // ── marking ──
  final _marking = MarkingController();
  Map<int, MarkVisual> _marks = const {};
  MarkPalette? _markPal;

  void _onMarking() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleMarking() async {
    if (_marking.active) {
      await _marking.end(context);
      return;
    }
    _stopAll();
    final s = SettingsScope.of(context);
    final ok = await _marking.start(context, script: s.quranScript);
    if (!ok || !mounted) return;
    final top = _topVisibleAyah();
    if (top >= 0) {
      final g = globalAyahIndex(widget.meta.n, top + 1);
      _marking.noteRange(g, g);
    }
  }

  /// The muṣḥaf word a card word stands for (its first, if it covers two).
  WordRef _refOf(int ayahIdx, int w) {
    final g = globalAyahIndex(widget.meta.n, ayahIdx + 1);
    final (first, _) =
        cardToMushaf(SettingsScope.of(context).quranScript, g, w);
    return WordRef(widget.meta.n, ayahIdx + 1, first + 1);
  }

  void _markCardWord(int ayahIdx, int w) =>
      _marking.apply(context, _refOf(ayahIdx, w));

  void _markAyah(int ayahIdx) =>
      _marking.apply(context, WordRef(widget.meta.n, ayahIdx + 1, 0));

  /// How card word [w] should look: the most serious open mark among the
  /// muṣḥaf words it covers, else fixed.
  MarkVisual? _visualOf(String script, int ayahIdx, int w) {
    if (_marks.isEmpty) return null;
    final g = globalAyahIndex(widget.meta.n, ayahIdx + 1);
    final (first, last) = cardToMushaf(script, g, w);
    MarkVisual? best;
    for (var k = first; k <= last; k++) {
      final v = _marks[WordRef(widget.meta.n, ayahIdx + 1, k + 1).key];
      if (v == null) continue;
      best = best == null ? v : _worse(best, v);
    }
    return best;
  }

  MarkVisual? _ayahVisual(int ayahIdx) =>
      _marks[WordRef(widget.meta.n, ayahIdx + 1, 0).key];

  static MarkVisual _worse(MarkVisual a, MarkVisual b) {
    int rank(MarkVisual v) =>
        v.open == null ? 99 : MarkVisual.priority.indexOf(v.open!);
    return rank(b) < rank(a) ? b : a;
  }

  @override
  void initState() {
    super.initState();
    _marking.addListener(_onMarking);
    initRecitationTracking();
    // Fire-and-forget: opening the reader is also a good moment to silently
    // top up any quran.com-sourced cache older than 7 days (Quran
    // Foundation's offline-caching condition) — see refreshStaleQuranCache.
    refreshStaleQuranCache();
    if (widget.startAyah != null) _cursor = widget.startAyah! - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = SettingsScope.of(context);
      AyahAudio.instance.setRate(s.playbackSpeed);
      WbwAudio.instance.setRate(s.playbackSpeed);
      ProgressScope.read(context)
          .setLastRead(widget.meta.n, widget.startAyah ?? 1);
    });
    _doneSub = AyahAudio.instance.onComplete.listen((_) {
      if (!mounted || !recitingAyah) return;
      final s = SettingsScope.of(context);
      // Whole-sūrah playback overrides the persisted "after a verse" setting
      // until it reaches the last āyah.
      if (_wholeSurah) {
        if (playingAyah >= 0 && words != null && playingAyah < words!.length - 1) {
          _playRecitation(playingAyah + 1, userTap: false);
          return;
        }
        setState(() {
          _wholeSurah = false;
          playingAyah = -1;
          playingWord = -1;
          recitingAyah = false;
        });
        return;
      }
      if (s.reciteFlow == 'repeat' && playingAyah >= 0) {
        _playRecitation(playingAyah, userTap: false);
        return;
      }
      if (s.reciteFlow == 'auto' &&
          playingAyah >= 0 &&
          words != null &&
          playingAyah < words!.length - 1) {
        _playRecitation(playingAyah + 1, userTap: false);
        return;
      }
      setState(() {
        playingAyah = -1;
        playingWord = -1;
        recitingAyah = false;
      });
    });
  }

  void _scrollToAyah(int i) {
    if (!SettingsScope.of(context).followAlong) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _ayahKeys[i]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: motion(context, const Duration(milliseconds: 350)),
            alignment: .08,
            curve: Curves.easeOut);
      } else {
        _anchorScroll(i);
      }
    });
  }

  /// The āyah whose card is currently topmost in the viewport.
  int _topVisibleAyah() {
    RenderObject? viewport;
    var bestTop = double.infinity;
    var best = -1;
    for (final e in _ayahKeys.entries) {
      final ctx = e.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      viewport ??= Scrollable.maybeOf(ctx)?.context.findRenderObject();
      if (viewport == null) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + box.size.height <= 8) continue; // fully scrolled past
      if (top < bestTop) {
        bestTop = top;
        best = e.key;
      }
    }
    return best;
  }

  /// After a layout-changing toggle, bring [anchor] back to the top so the
  /// reader stays on the same verse instead of landing wherever the old
  /// scroll offset happens to fall under the new item heights.
  void _anchorScroll(int anchor, [int tries = 0]) {
    if (anchor < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tries > 30) return;
      final ctx = _ayahKeys[anchor]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: .04,
            duration: motion(context, const Duration(milliseconds: 150)),
            curve: Curves.easeOut);
        return;
      }
      // The anchor isn't laid out under the new extents — hop toward it,
      // using the nearest built āyah as a compass, then look again.
      ScrollableState? sc;
      int? near;
      for (final e in _ayahKeys.entries) {
        final c = e.value.currentContext;
        if (c == null) continue;
        sc ??= Scrollable.maybeOf(c);
        if (near == null || (e.key - anchor).abs() < (near - anchor).abs()) {
          near = e.key;
        }
      }
      final pos = sc?.position;
      if (pos == null || near == null || near == anchor) return;
      final dir = anchor > near ? 1 : -1;
      pos.jumpTo((pos.pixels + dir * pos.viewportDimension * 2)
          .clamp(0.0, pos.maxScrollExtent));
      _anchorScroll(anchor, tries + 1);
    });
  }

  /// Applies a display toggle while keeping the reader on the same verse.
  void _keepPlace(VoidCallback change) {
    final anchor = _topVisibleAyah();
    change();
    setState(() {});
    _anchorScroll(anchor);
  }

  @override
  void dispose() {
    _wordTick.dispose();
    for (final t in _ayahTicks.values) {
      t.dispose();
    }
    _marking.removeListener(_onMarking);
    _marking.dispose();
    disposeRecitationTracking();
    _doneSub?.cancel();
    _handle?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    super.dispose();
  }

  Future<void> _ensureLoaded(String script, String font) async {
    final key = '$script/$font';
    if (_loadedKey == key && words != null) return;
    _loadedKey = key;
    final a = await QuranRepo.ayahs(widget.meta.n, script, font: font);
    final w = await QuranRepo.words(widget.meta.n, script, font: font);
    if (!mounted) return;
    setState(() {
      ayahs = a;
      words = w;
    });
    if (!_startScrolled && widget.startAyah != null && widget.startAyah! > 1) {
      _startScrolled = true;
      _anchorScroll(widget.startAyah! - 1);
    }
  }

  void _stopAll() {
    _handle?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    setState(() {
      playingAyah = -1;
      playingWord = -1;
      recitingAyah = false;
      _wholeSurah = false;
    });
  }

  /// Toggles continuous recitation of the whole sūrah, start to finish —
  /// independent of the persisted "after a verse" setting.
  void _toggleWholeSurah() {
    if (_wholeSurah) {
      _stopAll();
      return;
    }
    if (words == null || words!.isEmpty) return;
    setState(() {
      _wholeSurah = true;
      _mode = 'recite';
    });
    _playRecitation(0, userTap: false);
  }

  void _playGroup(int ayahIdx, int firstWord, int lastWord) {
    // While this āyah is being recited with word timings, tapping a word
    // jumps the recitation to that word's timestamp. Only when the stream is
    // actually seekable (duration known) — seeking an unbuffered stream
    // restarts it at 0:00, which sounds like "the verse just repeats".
    // Otherwise the recitation stops and the tapped word itself plays.
    if (recitingAyah && playingAyah == ayahIdx) {
      if (_seekToWord(firstWord)) return;
    }
    _handle?.cancel();
    AyahAudio.instance.stop();
    final whole = firstWord == 0 && lastWord == words![ayahIdx].length - 1;
    setState(() {
      recitingAyah = false;
      playingAyah = ayahIdx;
      _cursor = ayahIdx;
    });
    _handle = WbwAudio.instance.playWords(
      widget.meta.n, ayahIdx + 1, firstWord + 1, lastWord + 1,
      (w) {
        if (!mounted) return;
        if (w == -1 && whole && _mode == 'wbw') {
          // A whole āyah played word by word follows "after an āyah".
          final flow = SettingsScope.of(context).reciteFlow;
          if (flow == 'repeat') {
            _playAyahWbw(ayahIdx, force: true);
            return;
          }
          if (flow == 'auto' && ayahIdx < words!.length - 1) {
            _scrollToAyah(ayahIdx + 1);
            _playAyahWbw(ayahIdx + 1, force: true);
            return;
          }
        }
        setState(() {
          playingWord = w;
          if (w == -1) playingAyah = -1;
        });
      },
    );
  }

  /// Seeks the recitation to [word] if its timing is known; true on success.
  bool _seekToWord(int word) {
    final segs = AyahAudio.instance.segments;
    final dur = AyahAudio.instance.dur.value;
    if (segs == null || dur <= Duration.zero) return false;
    // Nearest segment at/after the word — timing data occasionally merges
    // adjacent words, so an exact index may not exist.
    for (final seg in segs) {
      if (seg[0] >= word) {
        final t = Duration(milliseconds: seg[1]);
        if (t < dur) {
          AyahAudio.instance.seek(t);
          AyahAudio.instance.resume();
          return true;
        }
        break;
      }
    }
    return false;
  }

  void _playAyahWbw(int ayahIdx, {bool force = false}) {
    if (!force &&
        playingAyah == ayahIdx &&
        !recitingAyah &&
        _handle != null &&
        !_handle!.cancelled) {
      _stopAll();
      return;
    }
    _mode = 'wbw';
    _playGroup(ayahIdx, 0, words![ayahIdx].length - 1);
  }

  Future<void> _playRecitation(int ayahIdx, {bool userTap = true}) async {
    if (userTap && recitingAyah && playingAyah == ayahIdx) {
      _stopAll();
      return;
    }
    _handle?.cancel();
    setState(() {
      playingAyah = ayahIdx;
      playingWord = -1;
      recitingAyah = true;
      _cursor = ayahIdx;
      _mode = 'recite';
      // A deliberate tap on one āyah's own play control means "just this
      // verse" — even mid whole-sūrah playback.
      if (userTap) _wholeSurah = false;
    });
    ProgressScope.read(context).setLastRead(widget.meta.n, ayahIdx + 1);
    if (!userTap) _scrollToAyah(ayahIdx);
    final err = await AyahAudio.instance.play(widget.meta.n, ayahIdx + 1,
        reciter: SettingsScope.of(context).reciter);
    if (!mounted) return;
    if (err == null && AyahAudio.instance.fellBack && !_warnedFallback) {
      _warnedFallback = true;
      showQToast(context, context.l10n.highlightOffline);
    }
    if (err != null) {
      setState(() {
        playingAyah = -1;
        recitingAyah = false;
      });
      showQToast(context, err);
    }
  }

  Future<void> _download(bool recitation) async {
    if (downloading || words == null) return;
    setState(() {
      downloading = true;
      dlDone = 0;
      dlTotal = recitation
          ? widget.meta.ayahs
          : words!.fold(0, (a, w) => a + w.length);
    });
    final ok = recitation
        ? await AyahAudio.instance.downloadSurah(
            widget.meta.n,
            widget.meta.ayahs,
            (d, t) => mounted ? setState(() => dlDone = d) : null,
            reciter: SettingsScope.of(context).reciter)
        : await WbwAudio.instance.downloadSurah(
            widget.meta.n, [for (final w in words!) w.length],
            (d, t) => mounted ? setState(() => dlDone = d) : null);
    if (!mounted) return;
    setState(() => downloading = false);
    showQToast(
        context,
        ok
            ? context.l10n.surahAudioSaved(widget.meta.tname)
            : context.l10n.downloadsNeedApp);
  }

  // ── the player's controls ──

  bool get _playing =>
      (recitingAyah && AyahAudio.instance.playing.value) ||
      (!recitingAyah && playingAyah >= 0 && _handle != null && !_handle!.cancelled);

  void _playPause() {
    if (words == null) return;
    if (recitingAyah) {
      AyahAudio.instance.playing.value
          ? AyahAudio.instance.pause()
          : AyahAudio.instance.resume();
      return;
    }
    if (playingAyah >= 0) {
      _stopAll();
      return;
    }
    final from = _cursor.clamp(0, words!.length - 1);
    _mode == 'wbw'
        ? _playAyahWbw(from, force: true)
        : _playRecitation(from, userTap: false);
  }

  void _step(int delta) {
    if (words == null) return;
    final from = playingAyah >= 0 ? playingAyah : _cursor;
    final to = (from + delta).clamp(0, words!.length - 1);
    if (recitingAyah) {
      _playRecitation(to, userTap: false);
    } else if (playingAyah >= 0) {
      _scrollToAyah(to);
      _playAyahWbw(to, force: true);
    } else {
      setState(() => _cursor = to);
      _anchorScroll(to);
    }
  }

  void _setMode(String m) {
    if (m == _mode) return;
    final wasPlaying = playingAyah >= 0;
    final at = playingAyah >= 0 ? playingAyah : _cursor;
    if (wasPlaying) _stopAll();
    setState(() => _mode = m);
    if (wasPlaying) {
      m == 'wbw' ? _playAyahWbw(at, force: true) : _playRecitation(at, userTap: false);
    }
  }

  void _cycleSpeed() {
    final s = SettingsScope.of(context);
    const speeds = [0.75, 1.0, 1.25];
    final i = speeds.indexOf(s.playbackSpeed);
    final next = speeds[(i + 1) % speeds.length];
    s.update(() => s.playbackSpeed = next);
    AyahAudio.instance.setRate(next);
    WbwAudio.instance.setRate(next);
  }

  void _cycleAfter() {
    final s = SettingsScope.of(context);
    const order = ['auto', 'single', 'repeat'];
    final i = order.indexOf(s.reciteFlow);
    s.update(() => s.reciteFlow = order[(i + 1) % order.length]);
  }

  /// The 15-line muṣḥaf, at the page of the āyah being read. It takes the
  /// reader's place (its own toggle comes back here), so closing either
  /// returns to where the reader was opened from.
  Future<void> _openMushaf() async {
    final script = SettingsScope.of(context).mushafScript;
    final last = ProgressScope.read(context).lastRead;
    await MushafRepo.ensure(script);
    if (!mounted) return;
    final p = last != null && last.$1 == widget.meta.n
        ? MushafRepo.pageForGlobalAyah(
            script,
            MushafRepo.globalAyahOf(last.$1, last.$2),
          )
        : await MushafRepo.pageForSurah(script, widget.meta.n);
    if (!mounted) return;
    final nav = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (_) => MushafPageScreen(startPage: p, script: script),
    );
    nav.canPop() ? nav.pushReplacement(route) : nav.push(route);
  }

  /// The index (sūrahs, juzʼ, pages… and search), from inside the reader:
  /// a pick opens the reader there, in this one's place.
  Future<void> _openIndex() async {
    final script = SettingsScope.of(context).mushafScript;
    await MushafRepo.ensure(script);
    final metas = await QuranRepo.meta();
    final here = await MushafRepo.pageForSurah(script, widget.meta.n);
    if (!mounted) return;
    (int, int)? to;
    await showMushafIndex(
      context,
      script: script,
      currentPage: here,
      onPage: (pg) => to = MushafRepo.firstVerseOfPage(script, pg),
      onStart: (t) => to = MushafRepo.surahAyahOf(MushafRepo.tokenAt(script, t).$1),
    );
    final (su, ay) = to ?? (0, 0);
    if (su == 0 || !mounted) return;
    final nav = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      builder: (_) => SurahReaderScreen(meta: metas[su - 1], startAyah: ay),
    );
    nav.canPop() ? nav.pushReplacement(route) : nav.push(route);
  }

  void _toggleTajwid() {
    final s = SettingsScope.of(context);
    s.update(() {
      s.tajwidColors = !s.tajwidColors;
      if (s.tajwidColors) s.stripTashkil = false;
    });
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    _ensureLoaded(s.quranScript, readerFont(s));
    if (s.tajwidColors &&
        _tajwidScript != s.quranScript &&
        words != null &&
        !_tajwidLoading) {
      _tajwidLoading = true;
      QuranRepo.tajwid(widget.meta.n, s.quranScript).then((t) {
        if (mounted) {
          setState(() {
            tajwid = t;
            _tajwidScript = s.quranScript;
            _tajwidLoading = false;
          });
        } else {
          _tajwidLoading = false;
        }
      });
    }
    final p = pal(context);
    final store = MarksScope.maybeOf(context);
    final markBook = store?.ready == true ? store!.activeBookId : null;
    _marks = markBook == null || !s.showMarks
        ? const {}
        : store!.visuals(markBook, showFixed: s.showFixedMarks);
    _markPal = markPaletteFor(p, mono: s.appTheme == 'mono');
    final desktop = useDesktop(context);
    // The reading measure: the window's width on desktop (word grid, verse
    // cards), full width on phones.
    // Past the old 120 cap, the measure widens with the text so a huge size
    // isn't squeezed into the same column.
    final maxW = math.max(contentMaxWidth(context, ContentKind.reading),
        readerPx(s).clamp(kReaderMinPx, readerMaxPx(context)) * 9);
    final hidden = s.readerHeaderCollapsed;
    return Scaffold(
      backgroundColor: p.bg,
      body: DecoratedBox(
        decoration: screenDecoration(context),
        child: SafeArea(
          bottom: false,
          child: Stack(children: [
            Column(children: [
              AnimatedSize(
                duration: motion(context, const Duration(milliseconds: 220)),
                curve: Curves.easeOut,
                child: hidden
                    ? const SizedBox(width: double.infinity, height: 0)
                    : Column(children: [
                        _header(context, s, desktop),
                        if (!desktop && _quickOpen) _quickRow(context, s),
                      ]),
              ),
              Expanded(
                child: words == null
                    ? Center(child: CircularProgressIndicator(color: p.acc))
                    : _list(context, s, maxW, hidden),
              ),
              if (_marking.active)
                Container(
                  padding: EdgeInsets.fromLTRB(
                      8, 6, 8, 6 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border(top: BorderSide(color: p.line2)),
                  ),
                  child: MarkingBar(
                    controller: _marking,
                    pal: _markPal!,
                    bg: p.card,
                    ink: p.ink,
                    sub: p.ink3,
                    line: p.line2,
                    accent: p.accInk,
                    onUndo: () => _marking.undo(context),
                    onEnd: _toggleMarking,
                  ),
                )
              else if (s.playerDock == 'pinned' && words != null)
                _ReaderPlayer(state: this, floating: false),
            ]),
            if (hidden)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: _Pill(
                    width: 48,
                    height: 28,
                    tooltip: context.l10n.showHeader,
                    onTap: () => s.update(() => s.readerHeaderCollapsed = false),
                    child: Icon(AppIcons.chevronDown, size: 18, color: p.ink2),
                  ),
                ),
              ),
            if (s.playerDock == 'floating' &&
                words != null &&
                !_marking.active)
              Positioned.fill(child: _FloatingPlayer(state: this)),
            if (s.playerDock == 'hidden' && words != null && !_marking.active)
              PositionedDirectional(
                end: 24,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: _HiddenPlayerButton(state: this),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppSettings s, bool desktop) {
    final p = pal(context);
    final m = widget.meta;
    final juz = MushafRepo.juzOfAyah(m.n, playingAyah >= 0 ? playingAyah + 1 : _cursor + 1);
    final sub =
        '${context.l10n.juzN(juz)} · ${context.l10n.typeAyat(m.type == 'meccan' ? context.l10n.meccan : context.l10n.medinan, m.ayahs)}';
    final px = readerPx(s).clamp(kReaderMinPx, readerMaxPx(context));
    final grid = s.wordByWord && s.readerLayout != 'mushaf';
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final title = Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.tname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 16, weight: FontWeight.w700)),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 12, color: p.ink3)),
      ]),
    );
    final gap = const SizedBox(width: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(children: [
        if (Navigator.of(context).canPop()) ...[
          QIconButton(
            icon: AppIcons.back,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
        ],
        title,
        gap,
        QIconButton(
            icon: AppIcons.indexList,
            tooltip: context.l10n.idxIndex,
            onTap: _openIndex),
        gap,
        if (desktop) ...[
          _sizeStepper(context, s, px, 40),
          if (grid) ...[gap, _gapStepper(context, s, 40)],
          gap,
          QIconButton(
              icon: AppIcons.mushaf,
              tooltip: context.l10n.k15LineMushaf,
              onTap: _openMushaf),
          gap,
          QIconButton(
              icon: AppIcons.tajweed,
              tooltip: context.l10n.tajwidColors,
              active: s.tajwidColors,
              onTap: _toggleTajwid),
          gap,
          _downloadButton(context),
          if (MarksScope.maybeOf(context) != null) ...[
            gap,
            _penButton(context),
          ],
        ] else ...[
          QIconButton(
              icon: AppIcons.mushaf,
              tooltip: context.l10n.k15LineMushaf,
              onTap: _openMushaf),
          if (!narrow) ...[
            gap,
            QIconButton(
                icon: AppIcons.tajweed,
                tooltip: context.l10n.tajwidColors,
                active: s.tajwidColors,
                onTap: _toggleTajwid),
          ],
          if (!narrow && MarksScope.maybeOf(context) != null) ...[
            gap,
            _penButton(context),
          ],
          gap,
          _AaButton(
              active: _quickOpen,
              onTap: () => setState(() => _quickOpen = !_quickOpen)),
        ],
        gap,
        QIconButton(
            icon: AppIcons.tune,
            tooltip: context.l10n.readerOptions,
            onTap: () => _openSettings(context)),
        gap,
        QIconButton(
            icon: AppIcons.chevronUp,
            tooltip: context.l10n.hideHeader,
            onTap: () => s.update(() => s.readerHeaderCollapsed = true)),
      ]),
    );
  }

  Widget _penButton(BuildContext context, {double size = 40}) => QIconButton(
      size: size,
      icon: _marking.active ? AppIcons.check : AppIcons.pen,
      tooltip: _marking.active
          ? context.l10n.mkEnd
          : context.l10n.mkMarkRecitation,
      active: _marking.active,
      onTap: _toggleMarking);

  Widget _sizeStepper(BuildContext context, AppSettings s, double px, double h) =>
      QStepper(
        height: h,
        label: '${px.round()}',
        minusTooltip: context.l10n.smallerText,
        plusTooltip: context.l10n.largerText,
        minusChild: Text('A−', style: uiStyle(context, size: 13, weight: FontWeight.w700)),
        plusChild: Text('A+', style: uiStyle(context, size: 15, weight: FontWeight.w700)),
        onMinus: px <= kReaderMinPx
            ? null
            : () => _keepPlace(() => setReaderPx(s, readerStepDown(px))),
        onPlus: px >= readerMaxPx(context)
            ? null
            : () => _keepPlace(
                () => setReaderPx(s, readerStepUp(px, readerMaxPx(context)))),
      );

  Widget _gapStepper(BuildContext context, AppSettings s, double h) {
    final p = pal(context);
    return QStepper(
      height: h,
      label: '${s.wbwGap.round()}',
      minusTooltip: context.l10n.lessGap,
      plusTooltip: context.l10n.moreGap,
      minusChild: Icon(AppIcons.gapDecrease, size: 18, color: p.ink),
      plusChild: Icon(AppIcons.gapIncrease, size: 18, color: p.ink),
      onMinus: s.wbwGap <= 0
          ? null
          : () => s.update(() => s.wbwGap = (s.wbwGap - 4).clamp(0, 64)),
      onPlus: s.wbwGap >= 64
          ? null
          : () => s.update(() => s.wbwGap = (s.wbwGap + 4).clamp(0, 64)),
    );
  }

  /// Phone: the quick-adjust row the "Aa" button opens.
  Widget _quickRow(BuildContext context, AppSettings s) {
    final px = readerPx(s).clamp(kReaderMinPx, readerMaxPx(context));
    final grid = s.wordByWord && s.readerLayout != 'mushaf';
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _sizeStepper(context, s, px, 44),
          if (grid) _gapStepper(context, s, 44),
          if (narrow) ...[
            QIconButton(
                size: 44,
                icon: AppIcons.tajweed,
                tooltip: context.l10n.tajwidColors,
                active: s.tajwidColors,
                onTap: _toggleTajwid),
            if (MarksScope.maybeOf(context) != null)
              _penButton(context, size: 44),
          ],
          _downloadButton(context, size: 44),
        ],
      ),
    );
  }

  Widget _downloadButton(BuildContext context, {double size = 40}) {
    final p = pal(context);
    if (downloading) {
      return SizedBox.square(
        dimension: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.square(
            dimension: size - 8,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, value: dlDone / dlTotal, color: p.acc),
          ),
          Text('${(100 * dlDone / dlTotal).floor()}',
              style: uiStyle(context, size: 10, weight: FontWeight.w700)),
        ]),
      );
    }
    return PopupMenuButton<int>(
      tooltip: context.l10n.download,
      onSelected: (v) => _download(v == 1),
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, child: Text(context.l10n.downloadWbw)),
        PopupMenuItem(value: 1, child: Text(context.l10n.downloadRecitation)),
      ],
      child: IgnorePointer(
        child: QIconButton(icon: AppIcons.download, size: size, onTap: () {}),
      ),
    );
  }

  Widget _list(BuildContext context, AppSettings s, double maxW, bool hidden) {
    final floating = s.playerDock == 'floating';
    final flow = s.readerLayout == 'mushaf';
    final n = words!.length;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        final top = _topVisibleAyah();
        if (top >= 0) {
          ProgressScope.read(context).setLastRead(widget.meta.n, top + 1);
          if (playingAyah < 0) _cursor = top;
        }
        return false;
      },
      child: ListView.builder(
        key: PageStorageKey('reader-${widget.meta.n}-${flow ? 'flow' : 'cards'}'),
        padding: EdgeInsets.fromLTRB(16, hidden ? 44 : 4, 16, floating ? 280 : 24),
        itemCount: n + 3,
        itemBuilder: (context, i) {
          Widget child;
          if (i == 0) {
            child = _Banner(
                meta: widget.meta,
                reciting: _wholeSurah,
                onRecite: _toggleWholeSurah);
          } else if (i == 1) {
            child = s.tajwidColors
                ? _TajwidKey(
                    open: _keyOpen,
                    onToggle: () => setState(() => _keyOpen = !_keyOpen))
                : const SizedBox.shrink();
          } else if (i == n + 2) {
            child = _credit(context);
          } else {
            final a = i - 2;
            child = KeyedSubtree(
                key: _ayahKeys.putIfAbsent(a, GlobalKey.new),
                child: ValueListenableBuilder<int>(
                  valueListenable: _tickFor(a),
                  builder: (context, _, _) => flow
                      ? _flowAyah(context, s, a)
                      : _ayahCard(context, s, a),
                ));
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ── āyah card (cards and word grid) ──

  Widget _ayahCard(BuildContext context, AppSettings s, int i) {
    final p = pal(context);
    final isActive = playingAyah == i;
    final tokens = words![i];
    final tj = s.tajwidColors && tajwid != null && i < tajwid!.length
        ? tajwid![i]
        : null;
    final grid = wbwMode;
    final n = grid ? s.wbwGroup : 1;
    final segments = <(int, int)>[
      for (var w = 0; w < tokens.length; w += n)
        (w, (w + n - 1).clamp(0, tokens.length - 1)),
    ];
    final segWidgets = [
      for (final (a, b) in segments) _segment(context, s, i, a, b, tokens, tj),
    ];
    final gap = grid ? s.wbwGap : 0.0;
    final center = grid && s.wbwAlign == 'center';
    final Widget text = grid && s.wbwNewline
        ? Column(
            crossAxisAlignment:
                center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              for (final w in segWidgets)
                Padding(padding: EdgeInsets.only(bottom: gap), child: w),
            ],
          )
        : Wrap(
            spacing: grid ? gap : 0,
            runSpacing: grid ? gap : 0,
            alignment: center ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: segWidgets,
          );
    return QCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      color: s.paperMode ? p.paper : null,
      borderColor: isActive ? p.acc : p.line2,
      borderWidth: isActive ? 1.5 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Directionality(textDirection: TextDirection.rtl, child: text),
        const SizedBox(height: 8),
        Divider(height: 1, color: p.line2),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          // Narrow cards drop the "2:255" text first (the marker already
          // shows the āyah), and only the narrowest lose the pill labels.
          final showRef = c.maxWidth >= 370;
          final compact = c.maxWidth < 330;
          return Row(children: [
          GestureDetector(
            onTap: _marking.active ? () => _markAyah(i) : null,
            child: AyahMarker(
              numeralAr: arabicIndic(i + 1),
              size: 30,
              stroke: ayahMarkerStroke(context),
              art: _markerArt(context),
              fill: isActive ? p.hl : _ayahFill(i, p.card),
              textColor: p.ink,
            ),
          ),
          if (showRef) ...[
            const SizedBox(width: 8),
            Text('${widget.meta.n}:${i + 1}',
                style: uiStyle(context,
                    size: 12.5, weight: FontWeight.w600, color: p.ink3)),
          ],
          const Spacer(),
          _BookmarkButton(surah: widget.meta.n, ayah: i + 1),
          _MiniPill(
            icon: isActive && !recitingAyah ? AppIcons.pause : AppIcons.wordByWord,
            label: context.l10n.wordsPill,
            compact: compact,
            active: isActive && !recitingAyah,
            onTap: () => _playAyahWbw(i),
          ),
          const SizedBox(width: 6),
          _MiniPill(
            icon: isActive && recitingAyah ? AppIcons.pause : AppIcons.recite,
            label: context.l10n.recite,
            compact: compact,
            active: isActive && recitingAyah,
            onTap: () => _playRecitation(i),
          ),
        ]);
        }),
      ]),
    );
  }

  /// The āyah marker's fill: tinted when the whole āyah is marked.
  Color _ayahFill(int i, Color base) {
    final v = _ayahVisual(i);
    final mp = _markPal;
    if (v == null || mp == null) return base;
    final c = mp.colorFor(v);
    return Color.alphaBlend(c.withValues(alpha: mp.tintAlpha + .1), base);
  }

  /// Continuous flow (the reader's "muṣḥaf flow" layout): each āyah's words
  /// run together, ending on its marker.
  Widget _flowAyah(BuildContext context, AppSettings s, int i) {
    final p = pal(context);
    final tokens = words![i];
    final tj = (s.tajwidColors && tajwid != null && i < tajwid!.length)
        ? tajwid![i]
        : null;
    final size = math.min(kReaderBase * s.quranFontScale, readerMaxPx(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var w = 0; w < tokens.length; w++)
              _segment(context, s, i, w, w, tokens, tj),
            GestureDetector(
              onTap: () =>
                  _marking.active ? _markAyah(i) : _playRecitation(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AyahMarker(
                  numeralAr: arabicIndic(i + 1),
                  size: size * 1.2,
                  stroke: ayahMarkerStroke(context),
                  art: _markerArt(context),
                  fill: recitingAyah && playingAyah == i
                      ? p.hl
                      : _ayahFill(i, p.card),
                  textColor: p.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One segment = [first..last] words rendered together (a word-grid card,
  /// or a bare word). Tapping plays it and opens the word sheet.
  Widget _segment(BuildContext context, AppSettings s, int ayahIdx, int first,
      int last, List<String> tokens, TajwidAyah? tj) {
    final p = pal(context);
    final active =
        playingAyah == ayahIdx && playingWord >= first && playingWord <= last;
    final grid = wbwMode && s.readerLayout != 'mushaf';

    final marking = _marking.active;
    final mp = _markPal;
    MarkVisual? segVisual;
    // Looked up once per segment, not per word / tajwīd piece.
    final qs = quranStyle(context);
    final tjColors = tj == null ? null : tajwidColorsFor(p);

    InlineSpan wordSpan(int w) {
      var text = tokens[w];
      if (s.stripTashkil) text = stripTashkil(text);
      final on = playingAyah == ayahIdx && playingWord == w;
      // Grouped segments take taps per word while marking: the recognizer
      // has to sit on the leaf spans, which are the ones hit-tested.
      final rec = marking && first != last
          ? (TapGestureRecognizer()..onTap = () => _markCardWord(ayahIdx, w))
          : null;
      final mv = _visualOf(s.quranScript, ayahIdx, w);
      if (mv != null) segVisual = segVisual == null ? mv : _worse(segVisual!, mv);
      final InlineSpan inner;
      if (tj != null && !on && !s.stripTashkil) {
        inner = _tajwidWordSpan(ayahIdx, w, text, tj, qs, tjColors!,
            recognizer: rec);
      } else {
        inner = TextSpan(text: text, style: qs, recognizer: rec);
      }
      if (mv == null || mp == null) return inner;
      // The tint rides on a parent span; the leaves inherit it (their own
      // styles leave backgroundColor unset).
      return TextSpan(
          style: markSpanStyle(const TextStyle(), mv, mp), children: [inner]);
    }

    final spans = <InlineSpan>[];
    for (var w = first; w <= last; w++) {
      spans.add(wordSpan(w));
      if (w != last) spans.add(const TextSpan(text: ' '));
    }
    final Widget textWidget = CustomPaint(
      // The pattern line goes at the foot of the box, below the kasrahs (a
      // text decoration would cut through them).
      foregroundPainter: segVisual == null || mp == null
          ? null
          : _SegmentMarkPainter(segVisual!, mp),
      child:
          Text.rich(TextSpan(children: spans), textDirection: TextDirection.rtl),
    );

    // Reading: a tap plays the word (or jumps the recitation to it);
    // holding it plays it and opens its sheet. Marking: a tap steps the
    // word's mark through the types; holding it opens the sheet to fix,
    // comment, reply or delete.
    void onTap() {
      if (marking) {
        _markCardWord(ayahIdx, first);
        return;
      }
      if (recitingAyah && playingAyah == ayahIdx && _seekToWord(first)) return;
      _playGroup(ayahIdx, first, last);
    }

    // While marking, a grouped segment's taps go to its words (see above).
    final tap = marking && first != last ? null : onTap;
    void longPress() {
      if (!marking) _playGroup(ayahIdx, first, last);
      _showWord(ayahIdx, first);
    }
    if (!grid) {
      // A bare word: highlight by background while it is being said.
      // Plain Container, not AnimatedContainer: one animation controller per
      // word of the sūrah was a lot of objects for a 150 ms colour fade.
      return GestureDetector(
        onTap: tap,
        onLongPress: longPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? p.hl : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: textWidget,
        ),
      );
    }
    return GestureDetector(
      onTap: tap,
      onLongPress: longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active ? p.hl : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? p.acc : p.line2, width: 1.5),
        ),
        child: textWidget,
      ),
    );
  }

  /// Char-accurate tajwīd coloring for a single word (either script).
  InlineSpan _tajwidWordSpan(int ayahIdx, int w, String displayText,
      TajwidAyah tj, TextStyle qs, List<Color> colors,
      {GestureRecognizer? recognizer}) {
    final raw = ayahs![ayahIdx];
    final ranges = _wordRanges(raw);
    if (w >= ranges.length) {
      return TextSpan(text: displayText, style: qs, recognizer: recognizer);
    }
    final (wa, wb) = ranges[w];
    final cuts = <(int, int, int)>[]; // local start, end, rule
    for (final sp in tj.spans) {
      final a = sp[0].clamp(wa, wb), b = sp[1].clamp(wa, wb);
      if (b > a) cuts.add((a - wa, b - wa, sp[2]));
    }
    cuts.sort((x, y) => x.$1.compareTo(y.$1));
    final word = raw.substring(wa, wb);
    final children = <TextSpan>[];
    var pos = 0;
    for (final (a, b, r) in cuts) {
      if (a < pos) continue; // skip overlaps
      if (a > pos) {
        children.add(TextSpan(
            text: word.substring(pos, a), style: qs, recognizer: recognizer));
      }
      children.add(TextSpan(
          text: word.substring(a, b),
          style: qs.copyWith(color: colors[r]),
          recognizer: recognizer));
      pos = b;
    }
    if (pos < word.length) {
      children.add(TextSpan(
          text: word.substring(pos), style: qs, recognizer: recognizer));
    }
    return TextSpan(children: children);
  }

  // Word ranges per āyah string, computed once (they were recomputed for
  // every word, rescanning the whole āyah each time).
  final Map<String, List<(int, int)>> _rangesCache = {};
  List<(int, int)> _wordRanges(String raw) =>
      _rangesCache.putIfAbsent(raw, () => QuranRepo.wordRanges(raw));

  // ── sheets ──

  void _showWord(int ayahIdx, int w) {
    final s = SettingsScope.of(context);
    final word = words![ayahIdx][w];
    final hasMarks = MarksScope.maybeOf(context) != null;
    final ref = _refOf(ayahIdx, w);
    showModalBottomSheet(
      context: context,
      isScrollControlled: hasMarks,
      showDragHandle: hasMarks,
      builder: (sheet) {
        final p = pal(sheet);
        Widget body(ScrollController? scroll) => SafeArea(
          child: ListView(
            controller: scroll,
            shrinkWrap: scroll == null,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [Column(mainAxisSize: MainAxisSize.min, children: [
              Text(s.stripTashkil ? stripTashkil(word) : word,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: readerFont(s),
                      fontSize: 44,
                      height: MushafRepo.khattLineHeight,
                      color: p.ink)),
              Text(
                  context.l10n.wordN(widget.meta.tname,
                      '${widget.meta.n}:${ayahIdx + 1}', w + 1),
                  style: uiStyle(sheet, size: 13, weight: FontWeight.w600, color: p.ink3)),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                QOutlineButton(context.l10n.playWord,
                    icon: AppIcons.volume,
                    onTap: () => WbwAudio.instance
                        .playWord(widget.meta.n, ayahIdx + 1, w + 1)),
                QPrimaryButton(context.l10n.reciteFromHere,
                    icon: AppIcons.recite, height: 44, onTap: () async {
                  Navigator.pop(sheet);
                  await _playRecitation(ayahIdx, userTap: false);
                  // Jump to the word once the verse's timings are known.
                  for (var t = 0; t < 20 && mounted; t++) {
                    if (_seekToWord(w)) break;
                    await Future<void>.delayed(const Duration(milliseconds: 150));
                  }
                }),
              ]),
            ]),
              if (hasMarks)
                WordMarksPanel(
                  ref: ref,
                  sessionId: _marking.active ? _marking.sessionId : null,
                ),
            ],
          ),
        );
        if (!hasMarks) return body(null);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .94,
          builder: (_, scroll) => body(scroll),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .94,
        builder: (sheet, scroll) => _ReaderSettingsSheet(
          controller: scroll,
          keepPlace: _keepPlace,
          onMushaf: () {
            Navigator.pop(sheet);
            _openMushaf();
          },
          onDownload: (rec) {
            Navigator.pop(sheet);
            _download(rec);
          },
        ),
      ),
    );
  }

  Widget _credit(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Text(
            context.l10n.wordWordRecitationCourtesyMarkaz,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 12, color: pal(context).ink3),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.textTanzilUthmaniMadaniIndopak,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 12, color: pal(context).ink3),
          ),
        ]),
      );
}

// ───────────────────────────── pieces ─────────────────────────────

/// An āyah's bookmark toggle. Its own widget so that only it — not the
/// whole reader — listens to progress changes.
class _BookmarkButton extends StatelessWidget {
  final int surah, ayah;
  const _BookmarkButton({required this.surah, required this.ayah});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final marked = ProgressScope.of(context).isBookmarked(surah, ayah);
    return IconButton(
      tooltip: marked ? context.l10n.removeBookmark : context.l10n.bookmark,
      visualDensity: VisualDensity.compact,
      onPressed: () => ProgressScope.read(context).toggleBookmark(surah, ayah),
      icon: Icon(marked ? AppIcons.bookmarkFilled : AppIcons.bookmark,
          size: 19, color: marked ? p.gold : p.ink3),
    );
  }
}

/// A marked word's pattern line, along the foot of its segment box.
class _SegmentMarkPainter extends CustomPainter {
  final MarkVisual v;
  final MarkPalette pal;
  _SegmentMarkPainter(this.v, this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    const t = 1.8;
    paintMarkLine(canvas, Offset(2, size.height - t), size.width - 4, v, pal,
        thickness: t);
  }

  @override
  bool shouldRepaint(_SegmentMarkPainter old) => old.v != v || old.pal != pal;
}

class _AaButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AaButton({required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Tooltip(
      message: context.l10n.quickAdjust,
      child: Material(
        color: active ? p.accBg : p.card,
        shape: CircleBorder(side: active ? BorderSide.none : BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: Text('Aa',
                  style: uiStyle(context,
                      size: 14,
                      weight: FontWeight.w700,
                      color: active ? Colors.white : p.ink2)),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Icon only (the label becomes the tooltip) — for narrow cards.
  final bool compact;
  const _MiniPill(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap,
      this.compact = false});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final pill = Material(
      color: active ? p.accSoft : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: active ? p.accSoft : p.line3)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: active ? p.accInk : p.ink2),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: uiStyle(context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: active ? p.accInk : p.ink2)),
            ],
          ]),
        ),
      ),
    );
    return compact
        ? Tooltip(message: label, child: Semantics(label: label, child: pill))
        : pill;
  }
}

class _Pill extends StatelessWidget {
  final double width, height;
  final String? tooltip;
  final VoidCallback onTap;
  final Widget child;
  const _Pill(
      {required this.width,
      required this.height,
      this.tooltip,
      required this.onTap,
      required this.child});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final w = Material(
      color: p.card,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: width, height: height, child: Center(child: child)),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

/// The sūrah banner: the name in a pill between two rosettes (Ornate borders
/// on) or a plain card, the Meccan/Medinan line, the basmala, and a button to
/// recite the whole sūrah.
class _Banner extends StatelessWidget {
  final SurahMeta meta;
  final bool reciting;
  final VoidCallback onRecite;
  const _Banner(
      {required this.meta, required this.reciting, required this.onRecite});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    // The reader's banner follows the muṣḥaf's sūrah header choice.
    final kind = s.mushafLook(s.quranScript, focus: false).header;
    final ornate = kind == 'rosette';
    final gold = ayahMarkerStroke(context);
    final name = Text('سورة ${meta.name}',
        textDirection: TextDirection.rtl,
        maxLines: 1,
        style: TextStyle(
            fontFamily: 'UthmanicHafs', fontSize: 26, height: 1.7, color: p.acc));
    final band = kind != 'plain' && !ornate
        ? MushafSurahHeader(
            kind: kind,
            lineHeight: 64,
            title: name,
            plainTitle: '',
            frame: gold,
            paper: p.card,
            soft: p.card,
            ink: p.acc,
          )
        : ornate
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withValues(alpha: .6)),
              gradient: LinearGradient(colors: [
                gold.withValues(alpha: .12),
                Colors.transparent,
                Colors.transparent,
                gold.withValues(alpha: .12),
              ], stops: const [0, .22, .78, 1]),
            ),
            child: Row(children: [
              Rosette(size: 22, color: gold, background: p.card),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.fromLTRB(56, 2, 56, 4),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: p.card,
                    shape: StadiumBorder(side: BorderSide(color: gold)),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: name),
                ),
              ),
              Rosette(size: 22, color: gold, background: p.card),
            ]),
          )
        : Center(child: name);
    final basmala = meta.n != 1 && meta.n != 9;
    return QCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(children: [
        band,
        const SizedBox(height: 10),
        Text(
            context.l10n.typeAyat(
                meta.type == 'meccan' ? context.l10n.meccan : context.l10n.medinan,
                meta.ayahs),
            style: uiStyle(context, size: 12.5, weight: FontWeight.w600, color: p.ink3)),
        if (basmala) ...[
          const SizedBox(height: 6),
          Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'UthmanicHafs', fontSize: 24, height: 1.8, color: p.ink)),
        ],
        const SizedBox(height: 10),
        QOutlineButton(
          reciting ? context.l10n.stop : context.l10n.reciteSurah,
          icon: reciting ? AppIcons.pause : AppIcons.recite,
          height: 40,
          onTap: onRecite,
        ),
      ]),
    );
  }
}

/// The collapsible tajwīd colour key.
class _TajwidKey extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  const _TajwidKey({required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final c = tajwidColorsFor(p);
    final rules = <(String, Color)>[
      (context.l10n.tjKeyMadd, c[8]),
      (context.l10n.tjKeyMaddLong, c[9]),
      (context.l10n.tjKeyMaddLazim, c[11]),
      (context.l10n.tjKeyGhunnah, c[0]),
      (context.l10n.tjKeyIkhfa, c[4]),
      (context.l10n.tjKeyIqlab, c[3]),
      (context.l10n.tjKeyQalqalah, c[7]),
      (context.l10n.tjKeySilent, c[13]),
    ];
    return QCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onToggle,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                for (final i in const [8, 11, 13, 7, 0])
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(color: c[i], shape: BoxShape.circle),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.l10n.tajwidKey,
                      style: uiStyle(context, size: 13.5, weight: FontWeight.w700)),
                ),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(AppIcons.chevronDown, size: 18, color: p.ink3),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion(context, const Duration(milliseconds: 200)),
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (label, color) in rules)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: .4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(label,
                              style: uiStyle(context,
                                  size: 12, weight: FontWeight.w600, color: color)),
                        ]),
                      ),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

// ───────────────────────────── the player ─────────────────────────────

/// The reader's audio player: Recitation | Word by word, the current word,
/// After-āyah, previous, play, next and speed. Pinned (docked at the bottom)
/// or inside the floating card. Minimised, it is one 40px row.
class _ReaderPlayer extends StatelessWidget {
  final _SurahReaderScreenState state;
  final bool floating;
  const _ReaderPlayer({required this.state, required this.floating});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final min = s.playerMinimised;
    final body = AnimatedSize(
      duration: motion(context, const Duration(milliseconds: 220)),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: min ? _minimised(context) : _expanded(context),
    );
    final progress = _Progress(state: state);
    if (floating) {
      return Column(mainAxisSize: MainAxisSize.min, children: [progress, body]);
    }
    // The dock tab sits on the player's top edge. Its upper half used to
    // hang outside the player's bounds, where taps aren't delivered to it —
    // they reached the words behind instead (tapping "float", "collapse" or
    // "close" played a word). The player now reserves that strip, so the
    // whole tab is inside it.
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: const EdgeInsets.only(top: _kDockTabOverhang),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: p.line2)),
          boxShadow: qShadows(context, const [
            BoxShadow(color: Color(0x1F14201C), blurRadius: 24, offset: Offset(0, -6))
          ]),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              progress,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    // The docked player spans the content; its controls
                    // stay together, centred.
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: body,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Center(child: _DockTab(state: state)),
      ),
    ]);
  }

  static const _kDockTabOverhang = 14.0;

  Widget _expanded(BuildContext context) {
    final p = pal(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      QSegmented<String>(
        height: 34,
        options: [
          ('recite', context.l10n.recitationMode, AppIcons.recite),
          ('wbw', context.l10n.wordByWord, AppIcons.wordByWord),
        ],
        value: state._mode,
        onChanged: state._setMode,
      ),
      const SizedBox(height: 10),
      _NowLine(state: state, big: true),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _AfterButton(state: state),
          ),
        ),
        _round(context, AppIcons.skipPrevious, () => state._step(-1),
            context.l10n.previousAyah),
        const SizedBox(width: 10),
        _PlayButton(state: state, size: 60),
        const SizedBox(width: 10),
        _round(context, AppIcons.skipNext, () => state._step(1), context.l10n.nextAyah),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _SpeedButton(state: state),
          ),
        ),
      ]),
      if (p.isDark) const SizedBox(height: 2),
    ]);
  }

  Widget _minimised(BuildContext context) => SizedBox(
        height: 40,
        child: Row(children: [
          _PlayButton(state: state, size: 40),
          const SizedBox(width: 10),
          Expanded(child: _NowLine(state: state, big: false)),
          _round(context, AppIcons.skipPrevious, () => state._step(-1),
              context.l10n.previousAyah, size: 36),
          _round(context, AppIcons.skipNext, () => state._step(1),
              context.l10n.nextAyah, size: 36),
          _SpeedButton(state: state),
        ]),
      );

  Widget _round(BuildContext context, IconData icon, VoidCallback onTap, String tip,
          {double size = 44}) =>
      QIconButton(
          icon: icon,
          size: size,
          iconSize: size * .45,
          border: false,
          color: Colors.transparent,
          tooltip: tip,
          onTap: onTap);
}

/// The 3px progress line along the player's top edge.
class _Progress extends StatelessWidget {
  final _SurahReaderScreenState state;
  const _Progress({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final a = AyahAudio.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([a.pos, a.dur]),
      builder: (context, _) {
        double v;
        if (state.recitingAyah && a.dur.value.inMilliseconds > 0) {
          v = a.pos.value.inMilliseconds / a.dur.value.inMilliseconds;
        } else {
          final n = state.words?.length ?? 1;
          final at = state.playingAyah >= 0 ? state.playingAyah : state._cursor;
          v = (at + 1) / n;
        }
        return QProgressBar(value: v, height: 3, track: p.line2);
      },
    );
  }
}

class _NowLine extends StatelessWidget {
  final _SurahReaderScreenState state;
  final bool big;
  const _NowLine({required this.state, required this.big});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: state._wordTick,
      builder: (context, _, _) => _build(context));

  Widget _build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final words = state.words;
    final at = state.playingAyah >= 0 ? state.playingAyah : state._cursor;
    final w = state.playingWord;
    final ref = '${state.widget.meta.n}:${at + 1}';
    final who = switch (s.reciter) {
      'alafasy' => context.l10n.afasyName,
      'husary' => context.l10n.husaryName,
      _ => context.l10n.alTunaiji,
    };
    final word = words != null && w >= 0 && at < words.length && w < words[at].length
        ? words[at][w]
        : null;
    final label = state._mode == 'recite'
        ? context.l10n.ayahByReciter(ref, who)
        : context.l10n.ayahRef(ref);
    if (!big) {
      return Row(children: [
        if (word != null) ...[
          Text(word,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: readerFont(s), fontSize: 20, height: 1.4, color: p.ink)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiStyle(context, size: 12.5, weight: FontWeight.w600, color: p.ink2)),
        ),
      ]);
    }
    return Column(children: [
      SizedBox(
        height: 52,
        child: Center(
          child: word == null
              ? Text(state.widget.meta.tname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(context, size: 22))
              : Text(word,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: readerFont(s),
                      fontSize: 28,
                      height: 1.6,
                      color: p.ink)),
        ),
      ),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: uiStyle(context, size: 12.5, color: p.ink3)),
    ]);
  }
}

class _PlayButton extends StatelessWidget {
  final _SurahReaderScreenState state;
  final double size;
  const _PlayButton({required this.state, required this.size});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ValueListenableBuilder<bool>(
      valueListenable: AyahAudio.instance.playing,
      builder: (context, _, _) {
        final playing = state._playing;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: size >= 56
                ? qShadows(context, [
                    BoxShadow(
                        color: p.accBg.withValues(alpha: .55),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -8)
                  ])
                : null,
          ),
          child: Material(
            color: p.accBg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: state._playPause,
              child: SizedBox.square(
                dimension: size,
                child: Icon(playing ? AppIcons.pause : AppIcons.play,
                    size: size * .42, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AfterButton extends StatelessWidget {
  final _SurahReaderScreenState state;
  const _AfterButton({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final flow = SettingsScope.of(context).reciteFlow;
    final (icon, label) = switch (flow) {
      'repeat' => (AppIcons.repeat, context.l10n.flowRepeat),
      'single' => (AppIcons.stop, context.l10n.flowStop),
      _ => (AppIcons.skipNext, context.l10n.flowContinue),
    };
    return Tooltip(
      message: context.l10n.afterVerse,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state._cycleAfter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: p.ink2),
            Text(label,
                style: uiStyle(context, size: 10.5, weight: FontWeight.w700, color: p.ink2)),
          ]),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final _SurahReaderScreenState state;
  const _SpeedButton({required this.state});
  @override
  Widget build(BuildContext context) {
    final sp = SettingsScope.of(context).playbackSpeed;
    final label = sp == 1 ? '1×' : '${sp.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')}×';
    return Tooltip(
      message: context.l10n.playbackSpeed,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state._cycleSpeed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(label,
              style: uiStyle(context, size: 13.5, weight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// The pill on the docked player's top edge: Unpin · Minimise · Hide.
class _DockTab extends StatelessWidget {
  final _SurahReaderScreenState state;
  const _DockTab({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    Widget seg(IconData icon, String tip, VoidCallback onTap, {double turns = 0}) =>
        Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 24,
              child: AnimatedRotation(
                turns: turns,
                duration: const Duration(milliseconds: 200),
                child: Icon(icon, size: 15, color: p.ink2),
              ),
            ),
          ),
        );
    return Material(
      color: p.card,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(AppIcons.unpin, context.l10n.unpinPlayer,
            () => s.update(() => s.playerDock = 'floating')),
        seg(AppIcons.chevronDown, context.l10n.collapsePlayer,
            () => s.update(() => s.playerMinimised = !s.playerMinimised),
            turns: s.playerMinimised ? .5 : 0),
        seg(AppIcons.close, context.l10n.hidePlayer,
            () => s.update(() => s.playerDock = 'hidden')),
      ]),
    );
  }
}

/// The floating player: a card dragged anywhere inside the reader.
class _FloatingPlayer extends StatefulWidget {
  final _SurahReaderScreenState state;
  const _FloatingPlayer({required this.state});
  @override
  State<_FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends State<_FloatingPlayer> {
  static Offset? _remembered; // kept for the session
  final ValueNotifier<Offset?> _pos = ValueNotifier(_remembered);

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = math.min(620.0, c.maxWidth - 32);
      final card = Container(
        width: w,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.line2),
          boxShadow: qShadows(context, const [
            BoxShadow(
                color: Color(0x7314201C),
                blurRadius: 50,
                offset: Offset(0, 24),
                spreadRadius: -20)
          ]),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(children: [
              Icon(AppIcons.dragHandle, size: 16, color: p.ink3),
              const SizedBox(width: 6),
              Text(context.l10n.playerLabel.toUpperCase(),
                  style: labelStyle(context, size: 11)),
              const Spacer(),
              _small(context, AppIcons.dock, context.l10n.pinPlayer,
                  () => s.update(() => s.playerDock = 'pinned')),
              _small(context, AppIcons.chevronDown, context.l10n.collapsePlayer,
                  () => s.update(() => s.playerMinimised = !s.playerMinimised)),
              _small(context, AppIcons.close, context.l10n.hidePlayer,
                  () => s.update(() => s.playerDock = 'hidden')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _ReaderPlayer(state: widget.state, floating: true),
          ),
        ]),
      );
      return ValueListenableBuilder<Offset?>(
        valueListenable: _pos,
        builder: (context, pos, child) {
          final h = s.playerMinimised ? 110.0 : 250.0;
          Offset clamp(Offset o) => Offset(
                o.dx.clamp(8.0, math.max(8.0, c.maxWidth - w - 8)),
                o.dy.clamp(8.0, math.max(8.0, c.maxHeight - h - 8)),
              );
          final at = clamp(pos ?? Offset((c.maxWidth - w) / 2, c.maxHeight - h - 24));
          return Stack(children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  _pos.value = clamp((_pos.value ?? at) + d.delta);
                  _remembered = _pos.value;
                },
                child: child,
              ),
            ),
          ]);
        },
        child: card,
      );
    });
  }

  Widget _small(BuildContext context, IconData icon, String tip, VoidCallback onTap) =>
      QIconButton(
          icon: icon,
          size: 32,
          iconSize: 16,
          border: false,
          color: Colors.transparent,
          tooltip: tip,
          onTap: onTap);
}

/// With the player hidden: a 52px round button that brings it back — filled
/// with the accent while audio is playing.
class _HiddenPlayerButton extends StatelessWidget {
  final _SurahReaderScreenState state;
  const _HiddenPlayerButton({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: AyahAudio.instance.playing,
      builder: (context, _, _) {
        final on = state._playing;
        return Tooltip(
          message: context.l10n.showPlayer,
          child: Material(
            color: on ? p.accBg : p.card,
            shape: CircleBorder(side: on ? BorderSide.none : BorderSide(color: p.line)),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => s.update(() => s.playerDock = 'pinned'),
              child: SizedBox.square(
                dimension: 52,
                child: Icon(AppIcons.recite,
                    size: 22, color: on ? Colors.white : p.ink2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────── reader settings sheet ─────────────────────────────

class _ReaderSettingsSheet extends StatelessWidget {
  final ScrollController controller;
  final void Function(VoidCallback) keepPlace;
  final VoidCallback onMushaf;
  final void Function(bool recitation) onDownload;
  const _ReaderSettingsSheet({
    required this.controller,
    required this.keepPlace,
    required this.onMushaf,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    final layout = s.readerLayout == 'mushaf'
        ? 'flow'
        : (s.wordByWord ? 'grid' : 'cards');
    final px = readerPx(s).clamp(kReaderMinPx, readerMaxPx(context));
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Text(context.l10n.readerOptions, style: displayStyle(context, size: 24)),
        QSectionLabel(context.l10n.rsText),
        QGroup(children: [
          QRow(
            title: context.l10n.arabicScript,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('uthmani', context.l10n.madani, null),
                ('indopak', context.l10n.indoPak, null),
              ],
              value: s.quranScript,
              onChanged: (v) => s.update(() => s.quranScript = v),
            ),
          ),
          QRow(
            title: context.l10n.arabicTextSize,
            control: QStepper(
              label: '${px.round()}',
              minusChild: Text('A−', style: uiStyle(context, size: 13, weight: FontWeight.w700)),
              plusChild: Text('A+', style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              onMinus: px <= kReaderMinPx
                  ? null
                  : () => keepPlace(() => setReaderPx(s, readerStepDown(px))),
              onPlus: px >= readerMaxPx(context)
                  ? null
                  : () => keepPlace(
                      () => setReaderPx(s, readerStepUp(px, readerMaxPx(context)))),
            ),
          ),
          QRow(
            title: context.l10n.tajwidColors,
            subtitle: context.l10n.tajwidNeeds,
            control: QSwitch(
                value: s.tajwidColors,
                onChanged: (v) => s.update(() {
                      s.tajwidColors = v;
                      if (v) s.stripTashkil = false;
                    })),
          ),
          QRow(
            title: context.l10n.hideTashkil,
            control: QSwitch(
                value: s.stripTashkil,
                onChanged: (v) => s.update(() {
                      s.stripTashkil = v;
                      if (v) s.tajwidColors = false;
                    })),
          ),
        ]),
        QSectionLabel(context.l10n.layout),
        QGroup(children: [
          QRow(
            title: context.l10n.readerLayout,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('cards', context.l10n.layoutAyahCards, null),
                ('grid', context.l10n.layoutWordGrid, null),
                ('flow', context.l10n.mushafFlow, null),
              ],
              value: layout,
              onChanged: (v) => keepPlace(() => s.update(() {
                    s.readerLayout = v == 'flow' ? 'mushaf' : 'cards';
                    s.wordByWord = v == 'grid';
                  })),
            ),
          ),
          if (layout == 'grid')
            QRow(
              title: context.l10n.wordsPerCard,
              control: QSegmented<int>(
                expand: false,
                options: [for (var i = 1; i <= 6; i++) (i, '$i', null)],
                value: s.wbwGroup,
                onChanged: (v) => keepPlace(() => s.update(() => s.wbwGroup = v)),
              ),
            ),
          if (layout == 'grid')
            QRow(
              title: context.l10n.verseAlign,
              control: QSegmented<String>(
                expand: false,
                options: [
                  ('right', context.l10n.alignRight, null),
                  ('center', context.l10n.alignCenter, null),
                ],
                value: s.wbwAlign,
                onChanged: (v) => keepPlace(() => s.update(() => s.wbwAlign = v)),
              ),
            ),
        ]),
        QSectionLabel(context.l10n.audio),
        QGroup(children: [
          for (final (id, name) in [
            ('tunaiji', context.l10n.alTunaiji),
            ('alafasy', context.l10n.afasyName),
            ('husary', context.l10n.husaryName),
          ])
            QRadioRow(
              title: name,
              subtitle: id == 'tunaiji' ? null : context.l10n.wordHighlighting,
              selected: s.reciter == id,
              onTap: () => s.update(() => s.reciter = id),
            ),
          QRow(
            title: context.l10n.afterVerse,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('single', context.l10n.flowStop, null),
                ('auto', context.l10n.flowContinue, null),
                ('repeat', context.l10n.flowRepeat, null),
              ],
              value: s.reciteFlow,
              onChanged: (v) => s.update(() => s.reciteFlow = v),
            ),
          ),
          QRow(
            title: context.l10n.playbackSpeed,
            control: QSegmented<double>(
              expand: false,
              options: const [(0.75, '0.75×', null), (1.0, '1×', null), (1.25, '1.25×', null)],
              value: s.playbackSpeed,
              onChanged: (v) {
                s.update(() => s.playbackSpeed = v);
                AyahAudio.instance.setRate(v);
                WbwAudio.instance.setRate(v);
              },
            ),
          ),
          QRow(
            title: context.l10n.followAlong,
            control: QSwitch(
                value: s.followAlong,
                onChanged: (v) => s.update(() => s.followAlong = v)),
          ),
        ]),
        // The rarely changed (the theme is Settings').
        _More(children: [
          QRow(
            title: context.l10n.audioPlayer,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('pinned', context.l10n.playerPinned, null),
                ('floating', context.l10n.playerFloating, null),
                ('hidden', context.l10n.playerHidden, null),
              ],
              value: s.playerDock,
              onChanged: (v) => s.update(() => s.playerDock = v),
            ),
          ),
          if (layout == 'grid') ...[
            QRow(
              title: context.l10n.eachCardOwnLine,
              control: QSwitch(
                  value: s.wbwNewline,
                  onChanged: (v) => keepPlace(() => s.update(() => s.wbwNewline = v))),
            ),
            QRow(
              title: context.l10n.gapBetweenCards,
              control: QStepper(
                label: '${s.wbwGap.round()}',
                minusChild: Icon(AppIcons.gapDecrease, size: 18, color: p.ink),
                plusChild: Icon(AppIcons.gapIncrease, size: 18, color: p.ink),
                onMinus: s.wbwGap <= 0
                    ? null
                    : () => s.update(() => s.wbwGap = (s.wbwGap - 4).clamp(0, 64)),
                onPlus: s.wbwGap >= 64
                    ? null
                    : () => s.update(() => s.wbwGap = (s.wbwGap + 4).clamp(0, 64)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          QPrimaryButton(context.l10n.k15LineMushaf,
              icon: AppIcons.mushaf, height: 44, onTap: onMushaf),
          QOutlineButton(context.l10n.downloadWbw,
              icon: AppIcons.download, onTap: () => onDownload(false)),
          QOutlineButton(context.l10n.downloadRecitation,
              icon: AppIcons.download, onTap: () => onDownload(true)),
        ]),
      ],
    );
  }
}

/// The reader sheet's "More": its rarely changed rows, folded away.
class _More extends StatefulWidget {
  final List<Widget> children;
  const _More({required this.children});

  @override
  State<_More> createState() => _MoreState();
}

class _MoreState extends State<_More> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: QGroup(children: [
        QRow(
          title: context.l10n.rsMore,
          control: Icon(_open ? AppIcons.chevronUp : AppIcons.chevronDown, color: p.ink3),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open) ...widget.children,
      ]),
    );
  }
}
