import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/marks/marks_model.dart';
import '../core/marks/marks_store.dart';
import '../core/marks/qc_words.dart';
import '../core/marks/word_ref.dart';
import '../core/perf_log.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/tap_longpress.dart';
import '../core/theme.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import '../ui/mark_style.dart';
import '../ui/qiraah_ornaments.dart';
import 'marks/marking.dart';
import 'marks/marking_bar.dart';
import 'marks/word_marks_sheet.dart';
import 'shell/app_shell.dart';

/// 📖 True 15-line Muṣḥaf — page-for-page and line-for-line with the printed
/// QUL/DigitalKhatt layout, in Madani (Uthmānī) *and* Indo-Pak scripts.
/// • Tap a word → hear that word.  • Tap the āyah number → recite the āyah.
/// • Long-press a word → its meaning.  Verse-by-verse or continuous playback
/// (auto page-turn). Pages turn right-to-left like the physical book.
///
/// Chrome: on a phone, a top bar (close, title, landscape, settings) and a
/// bottom bar (page colour, page turns, index, recite) that a tap on the page
/// hides and shows; on its side, floating round buttons; on desktop, a 64px
/// bar with page chips, Recite this page, page colour, the three view modes
/// (spread, single at 1.6×, fill width) and Focus.
class MushafPageScreen extends StatefulWidget with DesktopAware {
  final int startPage;
  final String? script; // 'uthmani' | 'indopak'; null → current setting
  /// Open in marking mode (the session sheet shows on open).
  final bool startMarking;
  const MushafPageScreen(
      {super.key, this.startPage = 1, this.script, this.startMarking = false});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

/// Arabic-Indic digits for page numbers on the page and in the chips.
String _ar(int n) => [
      for (final d in '$n'.runes) String.fromCharCode(0x0660 + d - 0x30),
    ].join();

/// The paper's display name.
String _paperName(BuildContext context, String id) => switch (id) {
      'white' => context.l10n.paperWhite,
      'mono' => context.l10n.themeMono,
      'night' => context.l10n.themeNight,
      'oled' => context.l10n.themeOled,
      _ => context.l10n.paperCream,
    };

const _kTopBar = 60.0;
const _kBottomBar = 74.0;

class _MushafPageScreenState extends State<MushafPageScreen>
    with RecitationPositionMixin<MushafPageScreen> {
  @override
  bool get isReciting => _reciting;
  // Recitation timings number words the quran.com way; _playWord is kept in
  // muṣḥaf numbering (they differ in 3 āyahs, see qc_words.dart).
  @override
  int get recitedWord =>
      _playWord < 0 ? _playWord : qcWordOf(_playAyah, _playWord);
  @override
  set recitedWord(int word) =>
      _playWord = word < 0 ? word : mushafWordOfQc(_playAyah, word);

  PageController? _ctrl;
  String _script = 'uthmani';
  int _page = 1;
  int _total = 604;
  int _curSurah = 1;
  Map<int, String> _names = {};
  Map<int, String> _tnames = {};
  bool _ready = false;
  bool _booted = false;

  AppSettings? _settingsRef;

  /// The settings' muṣḥaf script as last seen. The page follows CHANGES to
  /// the setting (e.g. from the Settings screen) but an explicit
  /// `widget.script` isn't overridden by the setting merely differing.
  String? _seenSetting;

  /// The bars are showing (a tap on the page, Focus or Esc toggles them).
  bool _chrome = true;
  bool? _wasDesktop;
  bool _orientationLocked = false;
  ShellScope? _shell;
  DateTime _lastWordTap = DateTime(0);

  /// Desktop page turn: which way the last turn went (+1 forward), for the
  /// slide direction.
  int _turnDir = 1;

  /// Page shown in the bottom bar while the progress line is dragged.
  int? _dragPage;

  // ── audio state ──
  int _playAyah = -1; // global ayah index highlighted (-1 none)
  int _playWord = -1; // word index within _playAyah (-1 none)
  bool _reciting = false; // true = full-verse recitation (tints the verse)
  bool _warnedFallback = false;
  StreamSubscription<void>? _doneSub;

  // ── marking ──
  final _marking = MarkingController();
  final _recognizers = _WordRecognizers();

  @override
  void initState() {
    super.initState();
    initRecitationTracking();
    _doneSub = AyahAudio.instance.onComplete.listen(_onVerseDone);
    _marking.addListener(_onMarking);
    PerfLog.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shell = ShellScope.maybeOf(context);
    _settingsRef = SettingsScope.of(context);
    if (_booted) return;
    _booted = true;
    _seenSetting = SettingsScope.of(context).mushafScript;
    _script = widget.script ?? _seenSetting!;
    _page = widget.startPage < 1 ? 1 : widget.startPage;
    _ctrl = PageController(initialPage: _page - 1);
    _load();
  }

  Future<void> _load() async {
    await MushafRepo.ensure(_script);
    final total = MushafRepo.pageCountSync(_script);
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    if (_page > total) _page = total;
    final v = MushafRepo.firstVerseOfPage(_script, _page);
    setState(() {
      _total = total;
      _names = {for (final m in metas) m.n: m.name};
      _tnames = {for (final m in metas) m.n: m.tname};
      _curSurah = v.$1;
      _ready = true;
    });
    _prewarm(_page);
    if (widget.startMarking && !_marking.active && !_startedMarking) {
      _startedMarking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleMarking();
      });
    }
  }

  bool _startedMarking = false;

  void _onMarking() {
    if (mounted) setState(() {});
  }

  /// Pen button: start (or resume) a session, or end the current one.
  Future<void> _toggleMarking() async {
    if (_marking.active) {
      await _marking.end(context);
      return;
    }
    _stopAudio();
    final ok = await _marking.start(context, script: _script);
    if (!ok || !mounted) return;
    _notePage(_page);
    _setChrome(true);
  }

  /// Widens the session's range to every āyah printed on [page].
  void _notePage(int page) {
    if (!_marking.active) return;
    final lines = MushafRepo.pageSync(_script, page);
    if (lines == null) return;
    var lo = 1 << 30, hi = -1;
    for (final ln in lines) {
      for (final w in ln.words) {
        if (w.ayah < lo) lo = w.ayah;
        if (w.ayah > hi) hi = w.ayah;
      }
    }
    if (hi >= 0) _marking.noteRange(lo, hi);
  }

  void _markWord(MushafWord wd) {
    _lastWordTap = DateTime.now();
    _marking.apply(context, WordRef.fromGlobal(wd.ayah, wd.wordIdx));
  }

  /// A tap on ۝ while marking marks the whole āyah (e.g. skipped).
  void _markAyah(int global) {
    _lastWordTap = DateTime.now();
    final (s, a) = surahAyahFromGlobal(global);
    _marking.apply(context, WordRef(s, a, 0));
  }

  @override
  void dispose() {
    disposeRecitationTracking();
    _doneSub?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    _ctrl?.dispose();
    _marking.removeListener(_onMarking);
    _marking.dispose();
    _recognizers.dispose();
    final n = _shell?.focus;
    if (n != null && n.value) n.value = false;
    if (!_chrome) _restoreSystemBars();
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(const []).catchError((_) {});
    }
    super.dispose();
  }

  // ── pages ──────────────────────────────────────────────────────────────

  bool get _desktop => useDesktop(context);
  String _view(AppSettings s) => _desktop ? s.mushafView : 'single';

  /// Desktop spreads pair pages like the open book: 1|2, 3|4 … with the
  /// lower page on the right.
  int _spreadStart(int p) => ((p - 1) >> 1) * 2 + 1;

  void _settle(int page) {
    final sw = kMushafPerf ? (Stopwatch()..start()) : null;
    PerfLog.where = 'page $page';
    _page = page;
    _curSurah = MushafRepo.firstVerseOfPage(_script, page).$1;
    ProgressScope.read(context).setLastMushafPage(page);
    _notePage(page);
    _recognizers.trim(page);
    _prewarm(page);
    if (sw != null) {
      PerfLog.log('→ page $page (bookkeeping ${sw.elapsedMicroseconds} µs)');
    }
  }

  /// Measures the pages either side of [page] in idle time, one page per
  /// idle slot, so the swipe that reaches them doesn't pay for it.
  void _prewarm(int page) {
    final script = _script;
    for (final p in [page + 1, page - 1, page + 2, page - 2]) {
      if (p < 1 || p > _total) continue;
      SchedulerBinding.instance.scheduleTask(() {
        if (!mounted || script != _script) return;
        final lines = MushafRepo.pageSync(script, p);
        if (lines != null && lines.isNotEmpty) {
          final sw = kMushafPerf ? (Stopwatch()..start()) : null;
          MushafGeometry.widestEm(script, p, lines);
          _ayahsOn(p);
          if (sw != null && sw.elapsedMicroseconds > 50) {
            PerfLog.log('prewarmed page $p in idle time '
                '(${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms)');
          }
        }
      }, Priority.idle);
    }
  }

  /// Shows [p] — the PageView on a phone, a fade-and-slide turn on desktop.
  void _jump(int p, {bool animate = false}) {
    final t = p < 1 ? 1 : (p > _total ? _total : p);
    if (_desktop) {
      setState(() {
        _turnDir = t >= _page ? 1 : -1;
        _settle(t);
      });
      return;
    }
    final c = _ctrl;
    if (c == null || !c.hasClients || c.page?.round() == t - 1) {
      setState(() => _settle(t));
      return;
    }
    if (animate) {
      c.animateToPage(t - 1,
          duration: const Duration(milliseconds: 380),
          curve: const Cubic(.2, .8, .2, 1));
    } else {
      c.jumpToPage(t - 1);
    }
  }

  /// One step forward (+1) or back (−1): a spread at a time in spread view.
  void _turn(int dir) {
    final s = SettingsScope.of(context);
    if (_desktop && _view(s) == 'spread') {
      _jump(_spreadStart(_page) + 2 * dir);
    } else {
      _jump(_page + dir, animate: true);
    }
  }

  void _onPage(int i) => setState(() => _settle(i + 1));

  Future<void> _switchScript(String v) async {
    if (v == _script) return;
    if (!kIndopakMushafAvailable && v == 'indopak') {
      comingSoon(context, context.l10n.indoPak);
      return;
    }
    _stopAudio();
    final keepSurah = _curSurah;
    setState(() {
      _ready = false;
      _script = v;
    });
    final st = SettingsScope.of(context);
    // The muṣḥaf keeps its own script preference, independent of the card
    // reader's quranScript: reading a page of the muṣḥaf in one script is not
    // a statement about which script you want the reader in, and the two
    // surfaces are navigated separately.
    st.update(() => st.mushafScript = v);
    await MushafRepo.ensure(v);
    final p = await MushafRepo.pageForSurah(v, keepSurah);
    if (!mounted) return;
    _page = p;
    _ctrl?.dispose();
    _ctrl = PageController(initialPage: p - 1);
    await _load();
  }

  // ── chrome ─────────────────────────────────────────────────────────────

  void _setChrome(bool on) {
    if (on == _chrome) return;
    setState(() => _chrome = on);
    if (_desktop) {
      ShellScope.setFocus(context, !on);
    } else if (on) {
      _restoreSystemBars();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
          .catchError((_) {});
    }
  }

  void _restoreSystemBars() {
    // Via the saved reference: this also runs from dispose(), when the
    // context can no longer look up its ancestors.
    final immersive = _settingsRef?.immersive ?? false;
    SystemChrome.setEnabledSystemUIMode(
            immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge)
        .catchError((_) {});
  }

  /// A tap on the page toggles the bars — unless it landed on a word or an
  /// āyah number, whose own recognisers fire first on the same pointer-up.
  void _onPageTap() {
    if (DateTime.now().difference(_lastWordTap).inMilliseconds < 250) return;
    // While marking, the pen bar stays put: a near-miss on a word must not
    // hide it.
    if (_marking.active) return;
    _setChrome(!_chrome);
  }

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.maybePop();
    } else {
      ShellScope.goTo(context, AppSection.today);
    }
  }

  void _rotate(bool landscape) {
    _orientationLocked = true;
    SystemChrome.setPreferredOrientations(landscape
            ? const [DeviceOrientation.portraitUp]
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ])
        .catchError((_) {});
  }

  /// Cream → white → mono → night → oled, setting the app theme as it goes
  /// (cream and white are both the light theme).
  void _cyclePaper(AppSettings s) {
    const order = ['cream', 'white', 'mono', 'night', 'oled'];
    final cur = mushafPaperOf(s).id;
    final next = order[(order.indexOf(cur) + 1) % order.length];
    s.update(() {
      if (next == 'cream' || next == 'white') {
        s.appTheme = 'light';
        s.mushafPaper = next;
      } else {
        s.appTheme = next;
      }
    });
  }

  // ── audio ──────────────────────────────────────────────────────────────
  void _onVerseDone(void _) {
    if (!mounted || !_reciting) return;
    final flow = SettingsScope.of(context).reciteFlow;
    if (flow == 'repeat') {
      _playVerse(_playAyah, userTap: false);
      return;
    }
    if (flow == 'auto') {
      final next = _playAyah + 1;
      if (next <= MushafRepo.lastGlobalAyah) {
        _advanceTo(next);
        return;
      }
    }
    setState(() {
      _playAyah = -1;
      _playWord = -1;
      _reciting = false;
    });
  }

  void _advanceTo(int global) {
    final pg = MushafRepo.pageForGlobalAyah(_script, global);
    final s = SettingsScope.of(context);
    final shown = _desktop && _view(s) == 'spread'
        ? _spreadStart(pg) == _spreadStart(_page)
        : pg == _page;
    if (!shown) {
      _jump(pg, animate: true);
    } else if (pg != _page) {
      setState(() => _settle(pg)); // moved within the open spread
    }
    _playVerse(global, userTap: false);
  }

  void _stopAudio() {
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    setState(() {
      _playAyah = -1;
      _playWord = -1;
      _reciting = false;
    });
  }

  Future<void> _playVerse(int global, {bool userTap = true}) async {
    if (userTap) _lastWordTap = DateTime.now();
    if (userTap && _reciting && _playAyah == global) {
      _stopAudio();
      return;
    }
    WbwAudio.instance.stop();
    final s = SettingsScope.of(context);
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(global);
    setState(() {
      _reciting = true;
      _playAyah = global;
      _playWord = -1;
    });
    AyahAudio.instance.setRate(s.playbackSpeed);
    final err =
        await AyahAudio.instance.play(surah, ayahInSurah, reciter: s.reciter);
    if (!mounted) return;
    if (err != null) {
      _stopAudio();
      showQToast(context, err);
    } else if (AyahAudio.instance.fellBack && !_warnedFallback) {
      _warnedFallback = true;
      showQToast(context, context.l10n.wordHighlightingNeedsInternetVerse);
    }
  }

  void _playWordAudio(MushafWord wd) {
    _lastWordTap = DateTime.now();
    AyahAudio.instance.stop();
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(wd.ayah);
    setState(() {
      _reciting = false;
      _playAyah = wd.ayah;
      _playWord = wd.wordIdx;
    });
    final qc = qcWordOf(wd.ayah, wd.wordIdx) + 1;
    WbwAudio.instance.playWords(surah, ayahInSurah, qc, qc, (idx) {
      if (!mounted) return;
      setState(() {
        _playWord = idx < 0 ? idx : wd.wordIdx;
        if (idx == -1) _playAyah = -1;
      });
    });
  }

  void _togglePlay() {
    if (_reciting) {
      if (AyahAudio.instance.playing.value) {
        AyahAudio.instance.pause();
      } else {
        AyahAudio.instance.resume();
      }
    } else {
      final fv = MushafRepo.firstVerseOfPage(_script, _page);
      _playVerse(MushafRepo.globalAyahOf(fv.$1, fv.$2), userTap: false);
    }
  }

  // ── sheets ─────────────────────────────────────────────────────────────

  void _showWord(MushafWord wd) {
    _lastWordTap = DateTime.now();
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(wd.ayah);
    final hasMarks = MarksScope.maybeOf(context) != null;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: hasMarks,
      builder: (sheet) {
        final p = pal(sheet);
        Widget body(ScrollController? scroll) => SafeArea(
          child: ListView(
            controller: scroll,
            shrinkWrap: scroll == null,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            children: [
              Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(wd.text,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: MushafRepo.fontFamily(_script),
                        fontSize: 44,
                        color: p.ink)),
                const SizedBox(height: 6),
                Text(
                    context.l10n.wordN(_tnames[surah] ?? '',
                        '$surah:$ayahInSurah', wd.wordIdx + 1),
                    style: uiStyle(sheet,
                        size: 13, weight: FontWeight.w600, color: p.ink3)),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  QPrimaryButton(context.l10n.playWord,
                      icon: AppIcons.volume, onTap: () {
                    Navigator.pop(sheet);
                    _playWordAudio(wd);
                  }),
                  QOutlineButton(context.l10n.reciteFromHere,
                      icon: AppIcons.recite, onTap: () {
                    Navigator.pop(sheet);
                    _playVerse(wd.ayah, userTap: false);
                  }),
                ]),
              ],
            ),
              if (hasMarks)
                WordMarksPanel(
                  ref: WordRef.fromGlobal(wd.ayah, wd.wordIdx),
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

  /// Go to page, or to the start of a sūrah.
  void _showIndex() {
    final field = TextEditingController();
    void go(BuildContext sheet) {
      final n = int.tryParse(field.text.trim());
      if (n == null) return;
      Navigator.pop(sheet);
      _jump(n);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .94,
        builder: (sheet, scroll) {
          final p = pal(sheet);
          return ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: 115,
            itemBuilder: (sheet, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.goToPage,
                          style: displayStyle(sheet, size: 24)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: field,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.go,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onSubmitted: (_) => go(sheet),
                            decoration: InputDecoration(
                                hintText: context.l10n.pageNumberHint(_total)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        QPrimaryButton(context.l10n.go,
                            onTap: () => go(sheet)),
                      ]),
                      QSectionLabel(context.l10n.surahsTab),
                    ],
                  ),
                );
              }
              final n = i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: QCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  radius: 16,
                  onTap: () async {
                    final pg = await MushafRepo.pageForSurah(_script, n);
                    if (!sheet.mounted) return;
                    Navigator.pop(sheet);
                    _jump(pg);
                  },
                  child: Row(children: [
                    SizedBox(
                      width: 34,
                      child: Text('$n',
                          style: uiStyle(sheet,
                              size: 13,
                              weight: FontWeight.w700,
                              color: p.accInk)),
                    ),
                    Expanded(
                      child: Text(_tnames[n] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiStyle(sheet,
                              size: 15, weight: FontWeight.w700)),
                    ),
                    Text(_names[n] ?? '',
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(sheet, size: 20, color: p.ink)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    ).whenComplete(field.dispose);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .94,
        builder: (sheet, scroll) => _MushafSettingsSheet(
          controller: scroll,
          script: _script,
          onScript: (v) {
            Navigator.pop(sheet);
            _switchScript(v);
          },
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (_booted && _ready && s.mushafScript != _seenSetting) {
      _seenSetting = s.mushafScript;
      if (s.mushafScript != _script) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && s.mushafScript != _script) {
            _switchScript(s.mushafScript);
          }
        });
      }
    }
    final desktop = _desktop;
    if (_wasDesktop != null && _wasDesktop != desktop) {
      // The window crossed the desktop breakpoint: the phone PageView comes
      // back at the current page.
      _ctrl?.dispose();
      _ctrl = PageController(initialPage: _page - 1);
    }
    _wasDesktop = desktop;
    final paper = mushafPaperOf(s);
    return PopScope(
      canPop: _chrome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_chrome) _setChrome(true);
      },
      child: Scaffold(
        backgroundColor: paper.bg,
        body: !_ready
            ? Center(child: CircularProgressIndicator(color: paper.acc))
            : desktop
                ? _desktopBody(context, s, paper)
                : LayoutBuilder(builder: (context, c) {
                    // A phone on its side: short and wide. The page then uses
                    // the full width and scrolls vertically.
                    final landscape =
                        c.maxWidth > c.maxHeight && c.maxHeight < 520;
                    return landscape
                        ? _landscapeBody(context, s, paper)
                        : _portraitBody(context, s, paper);
                  }),
      ),
    );
  }

  Widget _pageView(int page, AppSettings s, MushafPaper paper,
          {bool fitWidth = false,
          EdgeInsets margin = EdgeInsets.zero,
          String? spine}) =>
      _memoPage(
        page: page,
        paper: paper,
        s: s,
        fitWidth: fitWidth,
        margin: margin,
        spine: spine,
      );

  // ── page widgets, memoised ──
  //
  // A page widget is rebuilt only when something it shows changes: returning
  // the identical instance lets Flutter skip the page entirely. Each page is
  // handed the recitation state only if the playing āyah is on it, so a word
  // tick on one page of a spread doesn't rebuild the other.
  final Map<String, (List<Object?>, Widget)> _pageMemo = {};
  final Map<String, (int, int)> _pageAyahs = {};

  /// First and last global āyah printed on [page] (−1, −1 if none).
  (int, int) _ayahsOn(int page) {
    final key = '$_script/$page';
    final cached = _pageAyahs[key];
    if (cached != null) return cached;
    var lo = -1, hi = -1;
    for (final ln in MushafRepo.pageSync(_script, page) ?? const <MushafLine>[]) {
      for (final w in ln.words) {
        if (lo < 0 || w.ayah < lo) lo = w.ayah;
        if (w.ayah > hi) hi = w.ayah;
      }
    }
    return _pageAyahs[key] = (lo, hi);
  }

  void _onTapVerse(int g) => _marking.active ? _markAyah(g) : _playVerse(g);

  Widget _memoPage({
    required int page,
    required MushafPaper paper,
    required AppSettings s,
    required bool fitWidth,
    required EdgeInsets margin,
    required String? spine,
  }) {
    _recognizers
      ..onTapWord = _marking.active ? _markWord : _playWordAudio
      ..onLongPressWord = _showWord
      ..onTapVerse = _onTapVerse;
    final (lo, hi) = _ayahsOn(page);
    final mine = _playAyah >= 0 && _playAyah >= lo && _playAyah <= hi;
    final marks = _visuals(s);
    final markPal = markPaletteForPaper(paper);
    final inputs = <Object?>[
      _script, paper, s.ornate, fitWidth, s.mushafHeader, margin, spine,
      _names, mine ? _playAyah : -1, mine ? _playWord : -1,
      mine && _reciting, marks, markPal,
    ];
    final key = '$page/${spine ?? ''}';
    final memo = _pageMemo[key];
    if (memo != null && _sameInputs(memo.$1, inputs)) return memo.$2;
    final w = _MushafPageView(
      page: page,
      script: _script,
      names: _names,
      paper: paper,
      ornate: s.ornate,
      wideLayout: fitWidth,
      showHeader: s.mushafHeader,
      margin: margin,
      spine: spine,
      playAyah: mine ? _playAyah : -1,
      playWord: mine ? _playWord : -1,
      reciting: mine && _reciting,
      marks: marks,
      markPal: markPal,
      recognizers: _recognizers,
      onTapVerse: _onTapVerse,
    );
    if (_pageMemo.length > 12) _pageMemo.clear();
    _pageMemo[key] = (inputs, w);
    return w;
  }

  static bool _sameInputs(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
    }
    return true;
  }

  /// The active mark book's marks, as drawn on the page.
  Map<int, MarkVisual> _visuals(AppSettings s) {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready || !s.showMarks) return const {};
    final book = store.activeBookId;
    if (book == null) return const {};
    return store.visuals(book, showFixed: s.showFixedMarks);
  }

  /// The pen button for the bars (starts or ends marking).
  Widget? _penButton(BuildContext context, MushafPaper paper,
      {double size = 40, bool shadow = false}) {
    if (MarksScope.maybeOf(context) == null) return null;
    return _PaperButton(
        paper: paper,
        icon: _marking.active ? AppIcons.check : AppIcons.pen,
        size: size,
        shadow: shadow,
        active: _marking.active,
        tooltip: _marking.active
            ? context.l10n.mkEnd
            : context.l10n.mkMarkRecitation,
        onTap: _toggleMarking);
  }

  Widget _markingBar(MushafPaper paper, {bool floating = false}) => MarkingBar(
        controller: _marking,
        pal: markPaletteForPaper(paper),
        bg: paper.chrome,
        ink: paper.ink,
        sub: paper.sub,
        line: paper.line,
        accent: paper.id == 'mono' ? paper.ink : paper.acc,
        floating: floating,
        onUndo: () => _marking.undo(context),
        onEnd: _toggleMarking,
      );

  Widget _pager(AppSettings s, MushafPaper paper,
          {required bool fitWidth, required EdgeInsets margin}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onPageTap,
        child: PageView.builder(
          key: ValueKey(_script),
          controller: _ctrl,
          reverse: true, // right-to-left page turning
          // Pre-builds the adjacent page instead of Flutter's default
          // zero-length cache extent, so a page's first-visit layout cost
          // lands before the swipe reaches it, not mid-gesture.
          allowImplicitScrolling: true,
          itemCount: _total,
          onPageChanged: _onPage,
          itemBuilder: (context, i) {
            final page =
                _pageView(i + 1, s, paper, fitWidth: fitWidth, margin: margin);
            if (fitWidth) return page;
            // Portrait: the page takes the width its text needs (see
            // MushafGeometry) and the full height between the bars — on a
            // phone, spare height spreads the lines rather than leaving
            // empty bands above and below the page.
            return LayoutBuilder(builder: (context, c) {
              final b = MushafGeometry.pageBox(
                  Size(c.maxWidth - margin.horizontal,
                      c.maxHeight - margin.vertical),
                  _script,
                  ornate: s.ornate,
                  header: s.mushafHeader);
              return Center(
                child: SizedBox(
                    width: b.width + margin.horizontal,
                    height: c.maxHeight,
                    child: page),
              );
            });
          },
        ),
      );

  /// Fades a bar in and out with the chrome (250ms), and stops it catching
  /// taps while hidden.
  Widget _fade(Widget child) => IgnorePointer(
        ignoring: !_chrome,
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: child,
        ),
      );

  // ── phone, portrait ──

  Widget _portraitBody(BuildContext context, AppSettings s, MushafPaper paper) {
    final pad = MediaQuery.paddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(
            top: _chrome ? pad.top + _kTopBar : pad.top,
            bottom: _chrome ? pad.bottom + _kBottomBar : pad.bottom,
          ),
          child: _pager(s, paper,
              fitWidth: false, margin: const EdgeInsets.fromLTRB(8, 8, 8, 8)),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: _fade(Container(
          padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, 9),
          decoration: BoxDecoration(
            color: paper.chrome,
            border: Border(bottom: BorderSide(color: paper.line)),
          ),
          child: SizedBox(
            height: _kTopBar - 17,
            child: Row(children: [
              _PaperButton(
                  paper: paper,
                  icon: AppIcons.close,
                  tooltip: context.l10n.closeMushaf,
                  onTap: _close),
              const SizedBox(width: 8),
              Expanded(child: _titleBlock(context, paper, center: true)),
              const SizedBox(width: 8),
              if (!isDesktopPlatform()) ...[
                _PaperButton(
                    paper: paper,
                    icon: AppIcons.rotate,
                    tooltip: context.l10n.landscape,
                    onTap: () => _rotate(false)),
                const SizedBox(width: 8),
              ],
              if (_penButton(context, paper) case final pen?) ...[
                pen,
                const SizedBox(width: 8),
              ],
              _PaperButton(
                  paper: paper,
                  icon: AppIcons.tune,
                  tooltip: context.l10n.mushafSettings,
                  onTap: _showSettings),
            ]),
          ),
        )),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _fade(Container(
          padding: EdgeInsets.fromLTRB(12, 0, 12, pad.bottom + 10),
          decoration: BoxDecoration(
            color: paper.chrome,
            border: Border(top: BorderSide(color: paper.line)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _progressLine(paper),
            const SizedBox(height: 2),
            if (_marking.active)
              _markingBar(paper)
            else
            // The page turns are book controls, fixed in every language: the
            // left arrow is the next page.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                _PaperButton(
                    paper: paper,
                    icon: AppIcons.pageColour,
                    tooltip: context.l10n.pageColour,
                    onTap: () => _cyclePaper(s)),
                if (!narrow) ...[
                  const SizedBox(width: 6),
                  _PaperButton(
                      paper: paper,
                      icon: AppIcons.chevronLeft,
                      tooltip: context.l10n.nextPage,
                      border: false,
                      onTap: _page < _total ? () => _turn(1) : null),
                ],
                Expanded(child: _pageLabel(context, s, paper)),
                if (!narrow) ...[
                  _PaperButton(
                      paper: paper,
                      icon: AppIcons.chevronRight,
                      tooltip: context.l10n.previousPage,
                      border: false,
                      onTap: _page > 1 ? () => _turn(-1) : null),
                  const SizedBox(width: 6),
                ],
                _PaperButton(
                    paper: paper,
                    icon: AppIcons.indexList,
                    tooltip: context.l10n.goToPage,
                    onTap: _showIndex),
                const SizedBox(width: 8),
                _reciteButton(context, paper, size: 44),
              ]),
            ),
          ]),
        )),
      ),
    ]);
  }

  Widget _titleBlock(BuildContext context, MushafPaper paper,
      {bool center = false, String? subtitle}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(_tnames[_curSurah] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context,
                size: 15, weight: FontWeight.w700, color: paper.ink)),
        Text(
            subtitle ??
                (_script == 'indopak'
                    ? context.l10n.mushafIndoPakTitle
                    : context.l10n.mushafMadaniTitle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 12, color: paper.sub)),
      ],
    );
  }

  Widget _pageLabel(BuildContext context, AppSettings s, MushafPaper paper) {
    final page = _dragPage ?? _page;
    final juz = MushafRepo.juzOfPage(_script, page);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(context.l10n.pageJuz(page, juz),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: uiStyle(context,
              size: 13, weight: FontWeight.w700, color: paper.ink)),
      Text(_paperName(context, paper.id),
          maxLines: 1,
          style: uiStyle(context, size: 11.5, color: paper.sub)),
    ]);
  }

  /// The page progress line, right to left like the book; tap or drag it to
  /// move through the muṣḥaf.
  Widget _progressLine(MushafPaper paper) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int pageAt(double dx) {
        final f = (1 - dx / w).clamp(0.0, 1.0);
        return (f * _total).ceil().clamp(1, _total);
      }

      final shown = _dragPage ?? _page;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _jump(pageAt(d.localPosition.dx)),
        onHorizontalDragUpdate: (d) =>
            setState(() => _dragPage = pageAt(d.localPosition.dx)),
        onHorizontalDragEnd: (_) {
          final p = _dragPage;
          setState(() => _dragPage = null);
          if (p != null) _jump(p);
        },
        onHorizontalDragCancel: () => setState(() => _dragPage = null),
        child: SizedBox(
          height: 18,
          child: Center(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: paper.line,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: shown / _total,
                child: Container(
                  decoration: BoxDecoration(
                    color: paper.acc,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _reciteButton(BuildContext context, MushafPaper paper,
      {double size = 44, bool pill = false}) {
    return ValueListenableBuilder<bool>(
      valueListenable: AyahAudio.instance.playing,
      builder: (context, playing, _) {
        final on = _reciting && playing;
        final label = _reciting
            ? (playing ? context.l10n.pause : context.l10n.resume)
            : context.l10n.recitePage;
        final icon = on ? AppIcons.pause : AppIcons.play;
        final fill = paper.id == 'mono' ? paper.ink : paper.acc;
        final fg = paper.dark ? paper.paper : Colors.white;
        Widget btn;
        if (pill) {
          btn = Material(
            color: fill,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _togglePlay,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(label,
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w700, color: fg)),
                ]),
              ),
            ),
          );
        } else {
          btn = Tooltip(
            message: label,
            child: Material(
              color: fill,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _togglePlay,
                child: SizedBox.square(
                    dimension: size, child: Icon(icon, size: 20, color: fg)),
              ),
            ),
          );
        }
        if (!_reciting) return btn;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _PaperButton(
              paper: paper,
              icon: AppIcons.stop,
              tooltip: context.l10n.stop,
              border: false,
              onTap: _stopAudio),
          const SizedBox(width: 4),
          btn,
        ]);
      },
    );
  }

  // ── phone, landscape ──

  Widget _landscapeBody(
      BuildContext context, AppSettings s, MushafPaper paper) {
    final pad = MediaQuery.paddingOf(context);
    return Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(
              left: pad.left, right: pad.right, top: pad.top, bottom: 0),
          child: _pager(s, paper,
              fitWidth: true, margin: const EdgeInsets.fromLTRB(68, 10, 72, 0)),
        ),
      ),
      PositionedDirectional(
        top: pad.top + 14,
        start: pad.left + 12,
        child: _fade(_PaperButton(
            paper: paper,
            icon: AppIcons.close,
            size: 46,
            shadow: true,
            tooltip: context.l10n.closeMushaf,
            onTap: _close)),
      ),
      Positioned(
        top: pad.top + 14,
        right: pad.right + 16,
        child: _fade(Column(children: [
          _PaperButton(
              paper: paper,
              icon: AppIcons.rotate,
              size: 46,
              shadow: true,
              tooltip: context.l10n.exitLandscape,
              onTap: () => _rotate(true)),
          const SizedBox(height: 8),
          _PaperButton(
              paper: paper,
              icon: AppIcons.pageColour,
              size: 46,
              shadow: true,
              tooltip: context.l10n.pageColour,
              onTap: () => _cyclePaper(s)),
          const SizedBox(height: 8),
          if (_penButton(context, paper, size: 46, shadow: true)
              case final pen?) ...[
            pen,
            const SizedBox(height: 8),
          ],
          _reciteButton(context, paper, size: 46),
        ])),
      ),
      if (_marking.active)
        Positioned(
          bottom: pad.bottom + 10,
          left: 0,
          right: 0,
          child: Center(child: _markingBar(paper, floating: true)),
        )
      else
      Positioned(
        bottom: pad.bottom + 12,
        left: 0,
        right: 0,
        child: Center(
          child: _fade(Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: paper.chrome,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: paper.line),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                      spreadRadius: -10),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _PaperButton(
                    paper: paper,
                    icon: AppIcons.chevronLeft,
                    size: 38,
                    border: false,
                    tooltip: context.l10n.nextPage,
                    onTap: _page < _total ? () => _turn(1) : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                      context.l10n.pageJuz(
                          _page, MushafRepo.juzOfPage(_script, _page)),
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w700, color: paper.ink)),
                ),
                _PaperButton(
                    paper: paper,
                    icon: AppIcons.chevronRight,
                    size: 38,
                    border: false,
                    tooltip: context.l10n.previousPage,
                    onTap: _page > 1 ? () => _turn(-1) : null),
              ]),
            ),
          )),
        ),
      ),
    ]);
  }

  // ── desktop ──

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (e is KeyDownEvent && _marking.active) {
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      final i = digits.indexOf(k);
      if (i >= 0) {
        _marking.setPen(MarkPen.values[i]);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyZ &&
          (keys.isControlPressed || keys.isMetaPressed)) {
        _marking.undo(context);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        _toggleMarking();
        return KeyEventResult.handled;
      }
    }
    if (e is KeyDownEvent &&
        k == LogicalKeyboardKey.keyM &&
        MarksScope.maybeOf(context) != null) {
      _toggleMarking();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      _turn(1); // the book reads right to left: ← is forward
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _turn(-1);
    } else if (k == LogicalKeyboardKey.space && e is KeyDownEvent) {
      _togglePlay();
    } else if (k == LogicalKeyboardKey.escape && e is KeyDownEvent) {
      if (!_chrome) {
        _setChrome(true);
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _desktopBody(BuildContext context, AppSettings s, MushafPaper paper) {
    final view = _view(s);
    final first = view == 'spread' ? _spreadStart(_page) : _page;
    final juz = MushafRepo.juzOfPage(_script, first);
    final sub = view == 'spread' && first < _total
        ? context.l10n.pagesJuz(first, first + 1, juz)
        : context.l10n.pageJuz(_page, juz);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: _chrome ? 64 : 0,
          decoration: BoxDecoration(
            color: paper.chrome,
            border: _chrome
                ? Border(bottom: BorderSide(color: paper.line))
                : null,
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 64,
              maxHeight: 64,
              child: _desktopBar(context, s, paper, view, first,
                  '$sub · ${context.l10n.mushafKeysHint}'),
            ),
          ),
        ),
        // Hover effects and tooltips in the bar mustn't repaint the pages.
        Expanded(
            child: RepaintBoundary(
                child: _stage(context, s, paper, view, first))),
      ]),
    );
  }

  Widget _desktopBar(BuildContext context, AppSettings s, MushafPaper paper,
      String view, int first, String subtitle) {
    final chips = [
      for (var p = first - 2; p <= first + 3; p++)
        if (p >= 1 && p <= _total) p
    ];
    final shown = view == 'spread' ? {first, first + 1} : {_page};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _PaperButton(
            paper: paper,
            icon: AppIcons.close,
            tooltip: context.l10n.closeMushaf,
            onTap: _close),
        const SizedBox(width: 10),
        Flexible(
          flex: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: _titleBlock(context, paper, subtitle: subtitle),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(children: [
                for (final p in chips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PageChip(
                      label: _ar(p),
                      on: shown.contains(p),
                      paper: paper,
                      tooltip: context.l10n.pageN(p),
                      onTap: () => _jump(p),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _reciteButton(context, paper, pill: true),
        const SizedBox(width: 10),
        _PaperButton(
            paper: paper,
            icon: AppIcons.pageColour,
            tooltip: context.l10n.pageColour,
            onTap: () => _cyclePaper(s)),
        const SizedBox(width: 10),
        _ViewModes(
          paper: paper,
          value: view,
          onChanged: (v) {
            s.update(() => s.mushafView = v);
            setState(() {});
          },
        ),
        const SizedBox(width: 10),
        _PaperButton(
            paper: paper,
            icon: AppIcons.indexList,
            tooltip: context.l10n.goToPage,
            onTap: _showIndex),
        const SizedBox(width: 10),
        if (_penButton(context, paper) case final pen?) ...[
          pen,
          const SizedBox(width: 10),
        ],
        _PaperButton(
            paper: paper,
            icon: AppIcons.tune,
            tooltip: context.l10n.mushafSettings,
            onTap: _showSettings),
        const SizedBox(width: 10),
        _PaperButton(
            paper: paper,
            icon: AppIcons.focus,
            tooltip: context.l10n.focusHideMenus,
            onTap: () => _setChrome(false)),
      ]),
    );
  }

  Widget _stage(BuildContext context, AppSettings s, MushafPaper paper,
      String view, int first) {
    final pad = _chrome ? 24.0 : 14.0;
    final arrows = _chrome ? 60.0 : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paper.bg,
        gradient: s.gradients
            ? RadialGradient(
                radius: .9,
                colors: [paper.paper.withValues(alpha: .13), paper.bg])
            : null,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final availW = (c.maxWidth - 2 * pad - 2 * arrows).clamp(200.0, 1e9);
        final availH = (c.maxHeight - 2 * pad).clamp(200.0, 1e9);
        // Pages are sized from the text (MushafGeometry): every page of the
        // view shares one box, so turning pages never changes its shape.
        Size box(Size avail, {double? heightBudget, bool byWidthOnly = false}) =>
            MushafGeometry.pageBox(avail, _script,
                ornate: s.ornate,
                header: s.mushafHeader,
                heightBudget: heightBudget,
                byWidthOnly: byWidthOnly);
        Widget content;
        if (view == 'spread') {
          final b = box(Size(availW / 2, availH));
          final w = b.width, h = b.height;
          final left = first + 1;
          content = Container(
            key: ValueKey('spread-$first-$_script'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                // Soft but cheap: a 60px blur was costly to repaint on weak
                // GPUs for little visible difference.
                BoxShadow(
                    color: Color(0x5C281E0A),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                    spreadRadius: -10),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: w,
                height: h,
                child: left <= _total
                    ? _pageView(left, s, paper, spine: 'left')
                    : const SizedBox(),
              ),
              SizedBox(
                  width: w,
                  height: h,
                  child: _pageView(first, s, paper, spine: 'right')),
            ]),
          );
        } else {
          final b = view == 'fill'
              ? box(Size(availW, availH), byWidthOnly: true)
              : box(Size(availW, availH), heightBudget: availH * 1.6);
          final w = b.width, h = b.height;
          // A new scroll view per page: each turn starts at the top.
          content = ClipRRect(
            key: ValueKey('$view-$_page-$_script'),
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: w,
              height: availH,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    }),
                child: SingleChildScrollView(
                  child: SizedBox(
                      width: w,
                      height: h,
                      child: _pageView(_page, s, paper)),
                ),
              ),
            ),
          );
        }
        final step = view == 'spread' ? 2 : 1;
        return Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  reverseDuration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) {
                    // Forward pages arrive from the left (the book reads
                    // right to left). Transitions, not a rebuilding
                    // AnimatedBuilder: the spread itself isn't rebuilt per
                    // frame of the turn.
                    final dx = -16.0 * _turnDir;
                    return FadeTransition(
                      opacity: anim,
                      child: AnimatedBuilder(
                        animation: anim,
                        builder: (context, child) => Transform.translate(
                            offset: Offset(dx * (1 - anim.value), 0),
                            child: child),
                        child: child,
                      ),
                    );
                  },
                  child: content,
                ),
              ),
            ),
          ),
          if (_marking.active)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: _markingBar(paper, floating: true)),
            ),
          if (_chrome) ...[
            Positioned(
              left: pad,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PaperButton(
                    paper: paper,
                    icon: AppIcons.chevronLeft,
                    size: 44,
                    shadow: true,
                    tooltip: context.l10n.nextPage,
                    onTap: first + step <= _total ? () => _turn(1) : null),
              ),
            ),
            Positioned(
              right: pad,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PaperButton(
                    paper: paper,
                    icon: AppIcons.chevronRight,
                    size: 44,
                    shadow: true,
                    tooltip: context.l10n.previousPage,
                    onTap: first > 1 ? () => _turn(-1) : null),
              ),
            ),
          ] else
            Positioned(
              top: 14,
              right: 16,
              child: _PaperButton(
                  paper: paper,
                  icon: AppIcons.focusExit,
                  size: 40,
                  shadow: true,
                  tooltip: context.l10n.showHeader,
                  onTap: () => _setChrome(true)),
            ),
        ]);
      }),
    );
  }
}

/// A round button drawn in the muṣḥaf paper's colours (the bars sit on the
/// paper, not on the app theme).
class _PaperButton extends StatelessWidget {
  final MushafPaper paper;
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool border;
  final bool shadow;

  /// Toggled on (e.g. marking): filled with the accent.
  final bool active;
  const _PaperButton({
    required this.paper,
    required this.icon,
    this.tooltip,
    this.onTap,
    this.size = 40,
    this.border = true,
    this.shadow = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadow
            ? const [
                BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -8),
              ]
            : null,
      ),
      child: Material(
        color: active
            ? (paper.id == 'mono' ? paper.ink : paper.acc)
            : border || shadow
                ? paper.paper
                : Colors.transparent,
        shape: CircleBorder(
            side: border || shadow
                ? BorderSide(color: paper.line)
                : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon,
                size: 20,
                color: active
                    ? (paper.dark ? paper.paper : Colors.white)
                    : onTap == null
                        ? paper.sub.withValues(alpha: .5)
                        : paper.ink),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// The marks' pattern lines under a muṣḥaf line, a little below the
/// baseline — under the kasrahs, which a text decoration would cut through.
class _MarkLinePainter extends CustomPainter {
  final List<(double left, double right, MarkVisual v)> lines;
  final MarkPalette pal;
  final double dx, baseline, fontSize;
  _MarkLinePainter(
      {required this.lines,
      required this.pal,
      required this.dx,
      required this.baseline,
      required this.fontSize});

  @override
  void paint(Canvas canvas, Size size) {
    final t = (fontSize * .065).clamp(1.2, 3.0);
    // Kasrahs reach ~0.35 em below the baseline; the next line's tallest
    // marks start ~0.3–0.5 em further down.
    final y = baseline + fontSize * .42;
    for (final (left, right, v) in lines) {
      // Inset a little so neighbouring marked words read as separate.
      final inset = ((right - left) * .06).clamp(1.0, 4.0);
      paintMarkLine(canvas, Offset(dx + left + inset, y),
          right - left - inset * 2, v, pal,
          thickness: t);
    }
  }

  @override
  bool shouldRepaint(_MarkLinePainter old) =>
      old.pal != pal ||
      old.dx != dx ||
      old.baseline != baseline ||
      old.fontSize != fontSize ||
      old.lines.length != lines.length ||
      !_sameLines(old.lines, lines);

  static bool _sameLines(List<(double, double, MarkVisual)> a,
      List<(double, double, MarkVisual)> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The muṣḥaf's word and āyah-marker recognizers, kept across rebuilds
/// (a page used to mint ~150 new, never-disposed recognizers on every
/// build). Taps go to whatever handlers the screen set last; recognizers of
/// pages far from the one shown are disposed.
class _WordRecognizers {
  void Function(MushafWord)? onTapWord;
  void Function(MushafWord)? onLongPressWord;
  void Function(int globalAyah)? onTapVerse;

  final Map<int, Map<int, TapAndLongPressGestureRecognizer>> _byPage = {};

  TapAndLongPressGestureRecognizer of(int page, MushafWord wd) {
    final key = wd.ayah * 1000 + (wd.isMarker ? 999 : wd.wordIdx);
    return (_byPage[page] ??= {})[key] ??= wd.isMarker
        ? TapAndLongPressGestureRecognizer(
            onTap: () => onTapVerse?.call(wd.ayah),
            onLongPress: () => onTapVerse?.call(wd.ayah),
          )
        : TapAndLongPressGestureRecognizer(
            onTap: () => onTapWord?.call(wd),
            onLongPress: () => onLongPressWord?.call(wd),
          );
  }

  /// Disposes recognizers of pages more than [keep] away from [page] (those
  /// pages are no longer mounted).
  void trim(int page, {int keep = 4}) {
    _byPage.removeWhere((p, m) {
      if ((p - page).abs() <= keep) return false;
      for (final r in m.values) {
        r.dispose();
      }
      return true;
    });
  }

  void dispose() {
    for (final m in _byPage.values) {
      for (final r in m.values) {
        r.dispose();
      }
    }
    _byPage.clear();
  }
}

/// A page number chip in the desktop bar.
class _PageChip extends StatelessWidget {
  final String label;
  final bool on;
  final MushafPaper paper;
  final String tooltip;
  final VoidCallback onTap;
  const _PageChip({
    required this.label,
    required this.on,
    required this.paper,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = paper.id == 'mono' ? paper.ink : paper.acc;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? fill : paper.paper,
        shape: StadiumBorder(side: BorderSide(color: on ? fill : paper.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 32,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Text(label,
                style: arabicStyle(context,
                    size: 15,
                    height: 1,
                    color: on
                        ? (paper.dark ? paper.paper : Colors.white)
                        : paper.ink)),
          ),
        ),
      ),
    );
  }
}

/// Spread · Single · Fill width — 34px icon segments, the selected one filled.
class _ViewModes extends StatelessWidget {
  final MushafPaper paper;
  final String value;
  final ValueChanged<String> onChanged;
  const _ViewModes(
      {required this.paper, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final fill = paper.id == 'mono' ? paper.ink : paper.acc;
    Widget seg(String id, IconData icon, String tip) {
      final on = id == value;
      return Tooltip(
        message: tip,
        child: Semantics(
          selected: on,
          button: true,
          label: tip,
          child: Material(
            color: on ? fill : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(id),
              child: SizedBox.square(
                dimension: 34,
                child: Icon(icon,
                    size: 18,
                    color: on
                        ? (paper.dark ? paper.paper : Colors.white)
                        : paper.ink),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: paper.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paper.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('spread', AppIcons.viewSpread, context.l10n.twoPageSpread),
        const SizedBox(width: 2),
        seg('single', AppIcons.viewSingle, context.l10n.singlePageZoomed),
        const SizedBox(width: 2),
        seg('fill', AppIcons.fitWidth, context.l10n.fillWidthScroll),
      ]),
    );
  }
}

/// Script, recitation and page options for the muṣḥaf.
class _MushafSettingsSheet extends StatelessWidget {
  final ScrollController controller;
  final String script;
  final ValueChanged<String> onScript;
  const _MushafSettingsSheet(
      {required this.controller, required this.script, required this.onScript});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Text(context.l10n.mushafSettings, style: displayStyle(context, size: 24)),
        QSectionLabel(context.l10n.reading),
        QGroup(children: [
          QRow(
            title: context.l10n.arabicScript,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('uthmani', context.l10n.madani, null),
                ('indopak', context.l10n.indoPak, null),
              ],
              value: script,
              onChanged: onScript,
            ),
          ),
          QRow(
            title: context.l10n.pageHeader,
            control: QSwitch(
                value: s.mushafHeader,
                onChanged: (v) => s.update(() => s.mushafHeader = v)),
          ),
          QRow(
            title: context.l10n.ornateBorders,
            subtitle: context.l10n.ornateBordersSub,
            control: QSwitch(
                value: s.ornate, onChanged: (v) => s.update(() => s.ornate = v)),
          ),
          if (!isDesktopPlatform())
            QRow(
              title: context.l10n.immersiveHideSystemBars,
              control: QSwitch(
                  value: s.immersive,
                  onChanged: (v) => s.update(() => s.immersive = v)),
            ),
        ]),
        if (MarksScope.maybeOf(context) case final store?) ...[
          QSectionLabel(context.l10n.mkMarks),
          QGroup(children: [
            QRow(
              title: context.l10n.mkShowMarks,
              control: QSwitch(
                  value: s.showMarks,
                  onChanged: (v) => s.update(() => s.showMarks = v)),
            ),
            QRow(
              title: context.l10n.mkShowFixed,
              subtitle: context.l10n.mkShowFixedSub,
              control: QSwitch(
                  value: s.showFixedMarks,
                  onChanged: (v) => s.update(() => s.showFixedMarks = v)),
            ),
            if (store.books.length > 1)
              for (final b in store.books)
                QRadioRow(
                  title: b.name,
                  subtitle: context.l10n.mkMarkBook,
                  selected: b.id == store.activeBookId,
                  onTap: () => store.setActiveBook(b.id),
                ),
          ]),
        ],
        QSectionLabel(context.l10n.recitation),
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
              options: const [
                (0.75, '0.75×', null),
                (1.0, '1×', null),
                (1.25, '1.25×', null)
              ],
              value: s.playbackSpeed,
              onChanged: (v) {
                s.update(() => s.playbackSpeed = v);
                AyahAudio.instance.setRate(v);
                WbwAudio.instance.setRate(v);
              },
            ),
          ),
        ]),
      ],
    );
  }
}

class _MushafPageView extends StatelessWidget {
  final int page;
  final String script;
  final Map<int, String> names;
  final MushafPaper paper;
  final bool ornate;
  final bool wideLayout;
  final bool showHeader;
  final EdgeInsets margin;

  /// On a desktop spread: which side of this page is the spine ('left' or
  /// 'right'), whose corners stay square.
  final String? spine;
  final int playAyah;
  final int playWord;
  final bool reciting;

  /// Word marks to draw, by [WordRef.key] (word 0 = the āyah's ۝).
  final Map<int, MarkVisual> marks;
  final MarkPalette? markPal;
  final _WordRecognizers recognizers;
  final void Function(int globalAyah) onTapVerse;
  const _MushafPageView({
    required this.page,
    required this.script,
    required this.names,
    required this.paper,
    required this.ornate,
    required this.wideLayout,
    required this.showHeader,
    this.margin = EdgeInsets.zero,
    this.spine,
    required this.playAyah,
    required this.playWord,
    required this.reciting,
    this.marks = const {},
    this.markPal,
    required this.recognizers,
    required this.onTapVerse,
  });

  @override
  Widget build(BuildContext context) {
    final page = _page(context);
    return kMushafPerf ? PerfLayoutTimer(page: this.page, child: page) : page;
  }

  Widget _page(BuildContext context) {
    final lines = MushafRepo.pageSync(script, page);
    if (lines == null || lines.isEmpty) {
      return Center(child: CircularProgressIndicator(color: paper.acc));
    }
    const r = Radius.circular(10);
    final radius = switch (spine) {
      'left' => const BorderRadius.horizontal(left: r),
      'right' => const BorderRadius.horizontal(right: r),
      _ => const BorderRadius.all(r),
    };
    final frame = paper.frame.withValues(alpha: .6);
    // The thin page frame: 1px frame colour at 60%, with a second rule 3px
    // outside it when ornate borders are on.
    Widget framed(Widget child) {
      final inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: frame),
          borderRadius: BorderRadius.circular(ornate ? 4 : 6),
        ),
        child: child,
      );
      if (!ornate) return inner;
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: frame),
          borderRadius: BorderRadius.circular(6),
        ),
        child: inner,
      );
    }

    return LayoutBuilder(builder: (context, outer) {
      final roomy = outer.maxWidth > 520;
      final spineShade = spine == null
          ? null
          : LinearGradient(
              begin: spine == 'left'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              end: spine == 'left'
                  ? const Alignment(-.85, 0)
                  : const Alignment(.85, 0),
              colors: [
                Colors.black.withValues(alpha: paper.dark ? .35 : .08),
                Colors.transparent,
              ],
            );
      return Padding(
        padding: margin,
        child: Container(
          decoration: BoxDecoration(
            color: paper.paper,
            borderRadius: radius,
            border: Border.all(color: paper.line),
          ),
          foregroundDecoration: spineShade == null
              ? null
              : BoxDecoration(borderRadius: radius, gradient: spineShade),
          padding: roomy
              ? const EdgeInsets.fromLTRB(22, 18, 22, 10)
              : const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Column(
            children: [
              Expanded(
                child: framed(Column(
                  children: [
                    if (showHeader) _pageHeader(context),
                    Expanded(
                      // Isolates the word grid's paint layer from the page
                      // frame above: every recitation word-highlight tick
                      // repaints this subtree, and without this boundary the
                      // frame would be redrawn on every tick even though its
                      // own inputs never change.
                      child: RepaintBoundary(
                        child: LayoutBuilder(
                          builder: (context, c) =>
                              _grid(context, lines, c.maxWidth, c.maxHeight),
                        ),
                      ),
                    ),
                  ],
                )),
              ),
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(_ar(page),
                      textDirection: TextDirection.rtl,
                      style: arabicStyle(context,
                          size: 13, height: 1.3, color: paper.sub)),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Traditional muṣḥaf running head: sūrah on the left, juzʼ on the right
  /// (the page number sits under the page).
  Widget _pageHeader(BuildContext context) {
    final v = MushafRepo.firstVerseOfPage(script, page);
    final juz = MushafRepo.juzOfPage(script, page);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: paper.line)),
      ),
      // The running head is part of the PAGE, not the UI chrome: sūrah left,
      // juzʼ right, exactly as it is printed. A bare Row would follow the
      // app language and mirror it in Arabic/Urdu, so the direction is
      // pinned here.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Text(names[v.$1] ?? '',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: quranicStyle(context,
                      size: 14, height: 1.5, color: paper.acc)),
            ),
            Text(context.l10n.juzOnly(juz),
                style: uiStyle(context,
                    size: 11.5, weight: FontWeight.w600, color: paper.sub)),
          ],
        ),
      ),
    );
  }

  // Font size and line slot for a page depend only on (script, page,
  // viewport, layout mode) — never on playback state, so recitation ticks
  // don't recompute them. See [MushafGeometry] for the sizing rule.
  static final Map<String, (double, double, double)> _scaleCache = {};

  // Rounds a viewport dimension to the nearest 4px before it goes into a
  // cache key: an interactive window resize would otherwise mint one entry
  // per pixel of drag, since the caches are never evicted.
  static double _roundPx(double x) => (x / 4).round() * 4.0;

  Widget _grid(
      BuildContext context, List<MushafLine> lines, double vw, double vh) {
    final ink = paper.ink;
    final fam = MushafRepo.fontFamily(script);
    final n = lines.isEmpty ? 1 : lines.length;

    // A short-and-wide viewport (phone landscape) lays the page out to the
    // FULL width and lets it run taller than the viewport — the page then
    // scrolls vertically instead of being squeezed down to fit the short side.
    final fitWidth = wideLayout;
    final targetW = vw;

    final cacheKey =
        '$script/$page/${_roundPx(targetW)}/${_roundPx(vh)}/$fitWidth';
    final double fs;
    final double slotH;
    final double contentH;
    final cached = _scaleCache[cacheKey];
    if (cached != null) {
      (fs, slotH, contentH) = cached;
    } else {
      // The page's widest line fills the width; lines sit about
      // MushafGeometry.pitch apart (never tighter than minPitch, which caps
      // the font on pages with short lines).
      final sw = kMushafPerf ? (Stopwatch()..start()) : null;
      final widest = MushafGeometry.widestEm(script, page, lines);
      if (sw != null && sw.elapsedMicroseconds > 50) {
        PerfLog.measured(page, 'widest-pass lines',
            sw, lines.where((l) => l.isText).length);
      }
      final byWidth = targetW / widest;
      if (fitWidth) {
        fs = byWidth.clamp(8.0, 200.0);
        slotH = fs * MushafGeometry.pitch;
      } else {
        slotH = vh / n;
        final byHeight = slotH / MushafGeometry.minPitch;
        // Rounded DOWN to 0.5 px: neighbouring pages then share font sizes,
        // and the renderer's glyph cache (kept per size) is reused instead
        // of rasterising every glyph anew on each page. Rounding down keeps
        // the text inside the line; justification absorbs the difference.
        final raw = (byWidth < byHeight ? byWidth : byHeight).clamp(8.0, 200.0);
        fs = (raw * 2).floorToDouble() / 2;
      }
      contentH = fitWidth ? slotH * n : vh;
      _scaleCache[cacheKey] = (fs, slotH, contentH);
    }
    final base = TextStyle(
        fontFamily: fam,
        fontSize: fs,
        color: ink,
        height: slotH / fs,
        leadingDistribution: TextLeadingDistribution.even);

    final pageBody = SizedBox(
      height: contentH,
      width: targetW,
      child: Column(
        children: [
          for (final l in lines)
            Expanded(
                child: Center(
                    child: _slot(context, l, base, targetW, slotH, ink))),
        ],
      ),
    );
    if (!fitWidth) return pageBody;

    // Flutter desktop only drags scrollables with touch by default — extend
    // that to mouse and trackpad so the tall page can be panned with a
    // pointer too.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      }),
      child: SingleChildScrollView(child: pageBody),
    );
  }

  Widget _slot(BuildContext context, MushafLine l, TextStyle base,
      double targetW, double slotH, Color ink) {
    if (l.isHeader) {
      final glyph = (l.surah >= 1 && l.surah <= surahGlyphCodes.length)
          ? surahGlyphCodes[l.surah - 1]
          : null;
      return SizedBox(
        width: targetW,
        child: SurahHeader(
          title: glyph == null
              ? (names[l.surah] ?? '')
              : String.fromCharCodes([glyph, 0xe903]),
          ornate: ornate,
          lineHeight: slotH,
          frame: paper.frame,
          paper: paper.paper,
          soft: paper.soft,
          accent: paper.acc,
          textStyle: glyph == null
              ? quranicStyle(context, size: slotH * .5)
              : TextStyle(fontFamily: 'SurahNames', fontSize: slotH * .62),
        ),
      );
    }
    if (l.isBasmala) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(MushafRepo.bismillahChar,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: 'Bismillah',
                fontSize: slotH * 0.62,
                color: ink)),
      );
    }
    return _textLine(context, l, base, targetW, slotH, ink);
  }

  // Per-line geometry depends only on the line's text, font size and target
  // width — never on which word is highlighted — so recitation ticks and
  // marking reuse it. Keyed on the MushafLine's identity (pageSync returns
  // the same line objects every call) plus width and font size.
  static final Map<String, double> _lineGeomCache = {};

  /// The justified line laid out once more: its size, baseline and every
  /// token's horizontal extent. Only built for lines that need it — those
  /// with an āyah marker (enlarged hit targets) or a marked word (pattern
  /// lines).
  static final Map<String,
      (double tpW, double tpH, double baseline, List<(double, double)> boxes)>
      _lineBoxCache = {};

  /// Whether [token] holds characters that bidi treats as numbers — the
  /// āyah marker ۝ and its digits, or the disputed-end sign U+08E2 some
  /// Indo-Pak words carry — and so splits off a run of its own.
  static bool _numberRun(String token) {
    for (final c in token.codeUnits) {
      if (c == 0x06DD || c == 0x08E2 || (c >= 0x0660 && c <= 0x0669) ||
          (c >= 0x06F0 && c <= 0x06F9)) {
        return true;
      }
    }
    return false;
  }

  Widget _textLine(BuildContext context, MushafLine l, TextStyle base,
      double targetW, double slotH, Color ink) {
    final strongBg = paper.hl2;
    final verseBg = paper.hl;

    // Natural width of the line with plain spaces (colours and marks don't
    // change it).
    final geomKey =
        '${identityHashCode(l)}_${_roundPx(targetW)}_${base.fontSize!.toStringAsFixed(2)}';
    var natural = _lineGeomCache[geomKey];
    // Usually known already: the page's sizing pass shaped every line once.
    final em = MushafGeometry.lineEm(l);
    if (natural == null && em != null) {
      natural = em * base.fontSize!;
      _lineGeomCache[geomKey] = natural;
    }
    if (natural == null) {
      final sw = kMushafPerf ? (Stopwatch()..start()) : null;
      final measure = TextPainter(
          text: TextSpan(
              text: l.words.map((w) => w.text).join(' '), style: base),
          textDirection: TextDirection.rtl,
          maxLines: 1)
        ..layout();
      natural = measure.width;
      measure.dispose();
      _lineGeomCache[geomKey] = natural;
      if (sw != null) PerfLog.measured(page, 'width-pass', sw, 1);
    }

    // Justify by widening each space (the paragraph's wordSpacing; Skia
    // ignores letterSpacing on these runs, and wordSpacing on a child span).
    final spaces = l.words.length - 1;
    final justified = natural >= targetW * 0.45 && spaces > 0;
    final gapExtra =
        justified ? ((targetW - natural) / spaces).clamp(0.0, 1e6) : 0.0;
    final rootStyle =
        gapExtra > 0 ? base.copyWith(wordSpacing: gapExtra) : base;

    final spans = <InlineSpan>[];
    // Character range of every token, and which are āyah markers (enlarged
    // hit targets) or carry a mark (pattern line under the word).
    final ranges = <(int start, int end)>[];
    final markers = <(int token, int ayah)>[];
    final marked = <(int token, MarkVisual v)>[];
    var chars = 0;
    for (var i = 0; i < l.words.length; i++) {
      final wd = l.words[i];
      final onVerse = reciting && wd.ayah == playAyah;
      final active = wd.ayah == playAyah &&
          !wd.isMarker &&
          playWord >= 0 &&
          qcWordOf(wd.ayah, wd.wordIdx) == qcWordOf(wd.ayah, playWord);
      final mp = markPal;
      final mv = marks.isEmpty || mp == null
          ? null
          : marks[WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx)
              .key];
      final over = active ? strongBg : (onVerse ? verseBg : null);
      final style = mv == null
          ? base.copyWith(
              color: active ? paper.acc : ink, backgroundColor: over)
          : markSpanStyle(
              base.copyWith(color: active ? paper.acc : ink), mv, mp!,
              overBg: over);
      ranges.add((chars, chars + wd.text.length));
      if (wd.isMarker) markers.add((i, wd.ayah));
      if (mv != null) marked.add((i, mv));
      spans.add(TextSpan(
        text: wd.text,
        style: style,
        // Both branches use the SAME recognizer: it invokes onTap straight
        // from the pointer-up, instead of waiting to win the gesture arena
        // the way a plain TapGestureRecognizer does. That arena wait is what
        // swallowed clicks on the āyah circles with a mouse, while the words
        // beside them (already on this recognizer) kept working.
        mouseCursor: SystemMouseCursors.click,
        recognizer: recognizers.of(page, wd),
      ));
      chars += wd.text.length;
      if (i != spaces) {
        // An āyah marker (۝ + digits) is a run of its own, and Skia never
        // widens the spaces at the edges of the runs around it — those lines
        // came out short, the circle touching its neighbours. A
        // right-to-left mark between the space and the marker keeps the
        // space inside the word's run, where it widens like any other.
        final gap = _numberRun(wd.text)
            ? (_numberRun(l.words[i + 1].text) ? '\u200f \u200f' : '\u200f ')
            : (_numberRun(l.words[i + 1].text) ? ' \u200f' : ' ');
        spans.add(TextSpan(text: gap, style: base));
        chars += gap.length;
      }
    }

    // NOTE textScaler.noScaling: the page sizes its own text to fit the
    // printed geometry, but Text.rich would additionally inherit the SYSTEM
    // font scale that TextPainter above knows nothing about.
    final text = Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      softWrap: false,
      maxLines: 1,
      // Tall stacks of marks reach past the line box into the gap between
      // lines, as in print; they must not be clipped.
      overflow: TextOverflow.visible,
      style: rootStyle,
    );

    if (markers.isEmpty && marked.isEmpty) {
      return justified
          ? SizedBox(width: targetW, child: text)
          : Center(child: text);
    }

    var lb = _lineBoxCache[geomKey];
    if (lb == null) {
      final sw = kMushafPerf ? (Stopwatch()..start()) : null;
      final tp = TextPainter(
          text: TextSpan(children: spans, style: rootStyle),
          textDirection: TextDirection.rtl,
          maxLines: 1)
        ..layout();
      final boxes = <(double, double)>[];
      for (final r in ranges) {
        final bs = tp.getBoxesForSelection(
            TextSelection(baseOffset: r.$1, extentOffset: r.$2));
        if (bs.isEmpty) {
          boxes.add((0, 0));
          continue;
        }
        var left = bs.first.left, right = bs.first.right;
        for (final b in bs) {
          if (b.left < left) left = b.left;
          if (b.right > right) right = b.right;
        }
        boxes.add((left, right));
      }
      lb = (
        tp.width,
        tp.height,
        tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        boxes
      );
      tp.dispose();
      _lineBoxCache[geomKey] = lb;
      if (sw != null) PerfLog.measured(page, 'box-pass', sw, 1);
    }

    final tpWidth = lb.$1, tpHeight = lb.$2;
    final lineW = justified ? targetW : tpWidth;
    final extra = slotH - tpHeight;
    final vPad = extra > 0 ? (extra / 2).clamp(0.0, 14.0) : 0.0;
    final boxH = tpHeight + vPad * 2;
    final hPad = (8.0 + gapExtra / 2).clamp(8.0, 26.0);
    final xOff = (lineW - tpWidth) / 2;

    final hits = <Positioned>[];
    for (final (token, ayah) in markers) {
      final (left, right) = lb.$4[token];
      if (right <= left) continue;
      hits.add(Positioned(
        left: (xOff + left - hPad).clamp(0.0, lineW),
        top: 0,
        width: (right - left) + hPad * 2,
        height: boxH,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTapVerse(ayah),
          ),
        ),
      ));
    }

    final stack = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: lineW, height: boxH),
        text,
        if (marked.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MarkLinePainter(
                  lines: [
                    for (final (token, v) in marked)
                      if (lb.$4[token].$2 > lb.$4[token].$1)
                        (lb.$4[token].$1, lb.$4[token].$2, v)
                  ],
                  pal: markPal!,
                  dx: xOff,
                  baseline: (boxH - tpHeight) / 2 + lb.$3,
                  fontSize: base.fontSize!,
                ),
              ),
            ),
          ),
        ...hits,
      ],
    );
    return justified ? stack : Center(child: stack);
  }
}
