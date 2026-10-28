import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
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
import '../core/theme.dart';
import '../data/mushaf_atlas.dart';
import 'mushaf/mushaf_style_screen.dart';
import 'mushaf/trackpad_pager.dart';
import 'mushaf/mushaf_index_sheet.dart';
import 'quran_screen.dart';
import '../core/memorize.dart';
import '../core/recite_back.dart';
import 'mushaf/memorize_bar.dart';
import 'mushaf/memorize_cards_screen.dart';
import '../core/marks/review.dart';
import 'marks/review_bar.dart';
import 'marks/review_cards_screen.dart';
import '../ui/ornaments/ornaments.dart';
import '../ui/tajwid_colors.dart';
import '../data/divisions.dart' show Division, divisionCount, manzilOf, rukuCountOf;
import '../data/page_details.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import '../ui/mark_style.dart';
import '../ui/tool_popover.dart';
import '../ui/adaptive_sheet.dart';
import 'marks/marking.dart';
import 'marks/marking_bar.dart';
import 'marks/report_pdf.dart' show showReportSheet;
import 'marks/mutashabihat_screen.dart';
import 'marks/word_marks_sheet.dart';
import 'mushaf/mushaf_line.dart';
import 'mushaf/mushaf_marks_layer.dart';
import 'mushaf/hifz_dock.dart';
import 'mushaf/hifz_layout.dart';
import 'mushaf/page_rail.dart';
import 'profiles_sheet.dart';
import '../core/profiles.dart';
import '../core/display_rotation.dart';
import 'shell/app_mode.dart' show openSection, showModeSheet;
import 'shell/app_shell.dart';

part 'mushaf/hifz_chrome.dart';

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

  /// The script [startPage] is numbered in, when it may not be the one shown
  /// (the last page read, saved in the other script): the page is mapped
  /// over. Null → [startPage] is already in the shown script's numbering.
  final String? pageScript;

  /// Open in marking mode (the session sheet shows on open).
  final bool startMarking;

  /// A word to show in focus (outlined) on opening.
  final WordRef? focus;

  /// A review to carry on with (started from the Hifz screen or the verse
  /// cards): its bar shows, and its current mark is in focus.
  final ReviewController? review;

  /// Memorizing to carry on with (from the memorize verse cards).
  final MemorizeController? memorize;

  /// The app's home (Hifẓ mode): nothing to close back to; the Hifẓ
  /// toolbar (see [_hifzBody]).
  final bool home;
  const MushafPageScreen(
      {super.key,
      this.home = false,
      this.startPage = 1,
      this.script,
      this.pageScript,
      this.startMarking = false,
      this.focus,
      this.review,
      this.memorize});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

/// Arabic-Indic digits for page numbers on the page and in the chips.
String _ar(int n) => [
      for (final d in '$n'.runes) String.fromCharCode(0x0660 + d - 0x30),
    ].join();

/// The paper's display name.
String mushafPaperName(BuildContext context, String id) => switch (id) {
      'white' => context.l10n.paperWhite,
      'madani' => context.l10n.paperMadani,
      'tile1' => context.l10n.paperTile1,
      'tile2' => context.l10n.paperTile2,
      'tile3' => context.l10n.paperTile3,
      'mono' => context.l10n.themeMono,
      'night' => context.l10n.themeNight,
      'oled' => context.l10n.themeOled,
      'night_mono' => '${context.l10n.themeNight} · ${context.l10n.paperMono}',
      'oled_mono' => '${context.l10n.themeOled} · ${context.l10n.paperMono}',
      _ => context.l10n.paperCream,
    };

const _kTopBar = 60.0;
const _kBottomBar = 74.0;

class _MushafPageScreenState extends State<MushafPageScreen>
    with RecitationPositionMixin<MushafPageScreen>, WidgetsBindingObserver {
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
  // Phone on its side with two facing pages: the pager turns spreads.
  PageController? _spreadCtrl;
  bool _phoneSpread = false;
  // A phone on its side: the status bar stays hidden (more page height).
  bool _landscape = false;
  String _script = 'uthmani';
  int _page = 1;

  /// Hifẓ mode's word tool (comment, eraser, audio), when one is on.
  _HifzTool _hifzTool = _HifzTool.none;

  /// The Hifẓ home on its side: the dock on the left (camera on the right),
  /// and the window size it was worked out for.
  bool _dockLeft = false;
  Size? _rotationFor;

  /// setState, for the Hifẓ chrome (an extension: see hifz_chrome.dart).
  void _update(VoidCallback f) => setState(f);
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

  // ── review ──
  ReviewController? _review;

  /// The word in focus: the reviewed mark, or a word an index count led to.
  WordRef? _focus;

  bool get _reviewing => _review?.active ?? false;

  /// Mutashābih link mode: the mark whose likenesses are being tapped —
  /// words and ۝ on any page — until Done.
  Mark? _linking;

  // ── memorize ──
  MemorizeController? _memo;
  bool get _memorizing => _memo != null;
  bool _warnedTimings = false;
  final _handlers = MushafTapHandlers();

  /// The page the pager moved to mid-swipe, settled once the swipe ends.
  int? _pendingPage;

  /// The settled page, for the bars that show it (see [_settle]).
  final _pageN = ValueNotifier<int>(1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A turn from one side straight to the other: the window keeps its size,
    // only this says so.
    displayRotationChanges.addListener(_rotationChanged);
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
    final r = widget.review;
    if (r != null) {
      _attachReview(r, go: false);
    } else {
      _focus = widget.focus;
    }
    _memo = widget.memorize
      ?..addListener(_onMemo)
      ..screenOf = _screenOf;
    _load();
  }

  Future<void> _load() async {
    await MushafRepo.ensure(_script);
    final from = widget.pageScript;
    if (!_mappedStart && from != null && from != _script) {
      _mappedStart = true;
      await MushafRepo.ensure(from);
      if (!mounted) return;
      _page = MushafRepo.matchingPage(from, _page, _script);
      _ctrl?.dispose();
      _ctrl = PageController(initialPage: _page - 1);
      if (_spreadCtrl != null) {
        _spreadCtrl!.dispose();
        _spreadCtrl =
            PageController(initialPage: (_spreadStart(_page) - 1) ~/ 2);
      }
    }
    _mappedStart = true;
    // The glyph atlas (usually loaded at startup already). Until it's ready
    // the page is shaped as text; when it arrives the lines switch to it.
    if (MushafAtlas.of(_script) == null) {
      final script = _script;
      MushafAtlas.load(script, MushafRepo.tokensSync(script)).then((a) {
        if (a != null && mounted && script == _script) {
          setState(_pageMemo.clear);
        }
      });
    }
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

    // Saved with its script: after a switch, or a page mapped over from
    // the other script, the number is in this script's pages.
    ProgressScope.read(context).setLastMushafPage(_page, _script);
    _pageN.value = _page;
    _prewarm(_page);
    // Focus mode: the page opens bare (a tap brings the bars back).
    if (!_focusApplied && SettingsScope.of(context).focusMode) {
      _focusApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setChrome(false);
      });
    }
    if (widget.startMarking && !_marking.active && !_startedMarking) {
      _startedMarking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleMarking();
      });
    }
  }

  bool _startedMarking = false;

  /// [MushafPageScreen.pageScript] has been applied (only on first load).
  bool _mappedStart = false;

  /// Focus mode's bare start has been applied (on first load only).
  bool _focusApplied = false;

  void _onMarking() {
    if (mounted) setState(() {});
  }

  /// Takes [r] on: its bar shows, its current mark is in focus (turning to
  /// its page when [go]), and marking stops.
  void _attachReview(ReviewController r, {bool go = true}) {
    if (_marking.active) _marking.stop();
    _review?.removeListener(_onReview);
    _review = r..addListener(_onReview);
    _focus = r.current?.ref;
    if (go && _focus != null) _goToWord(_focus!);
    if (mounted) setState(() {});
  }

  void _onReview() {
    final r = _review;
    if (r == null || !mounted) return;
    if (!r.active) {
      r.removeListener(_onReview);
      setState(() {
        _review = null;
        _focus = null;
      });
      return;
    }
    final f = r.current?.ref;
    if (f != _focus) {
      _focus = f;
      if (f != null) _goToWord(f);
    }
    setState(() {});
  }

  /// [w]'s page in this script.
  int _pageOfWord(WordRef w) => MushafRepo.pageOfWord(
      _script, w.globalAyah, w.word <= 0 ? 0 : w.word - 1);

  /// Turns to the page (or spread) holding [w], unless it's showing.
  void _goToWord(WordRef w) => _showPage(_pageOfWord(w));

  /// Turns to [pg] (or its spread), unless it's showing.
  void _showPage(int pg) {
    final s = SettingsScope.of(context);
    final shown = (_desktop && _view(s) == 'spread') || _phoneSpread
        ? _spreadStart(pg) == _spreadStart(_page)
        : pg == _page;
    if (!shown) {
      _jump(pg, animate: true);
    } else if (pg != _page) {
      setState(() => _settle(pg));
    }
  }

  /// A count in the index: that mark's word, in focus.
  void _focusWord(WordRef w) {
    setState(() => _focus = w);
    _goToWord(w);
  }

  /// Memorize: everything from the page in view (the spread's first page)
  /// — or from [token], a chosen start — on is hidden, and revealed word by
  /// word.
  void _startMemorize({int? token}) {
    _stopAudio();
    if (_marking.active) _marking.stop();
    _review?.end();
    final s = SettingsScope.of(context);
    final spread = (_desktop && _view(s) == 'spread') || _phoneSpread;
    final page = _pendingPage ?? _page;
    _memo = (token != null
        ? MemorizeController.startAtToken(_script, token)
        : MemorizeController.startAt(
            _script, spread ? _spreadStart(page) : page))
      ..addListener(_onMemo)
      ..screenOf = _screenOf;
    if (token != null) _showPage(_memo!.viewPage);
    // Focus mode keeps the page bare: its small floating bar is enough.
    if (!s.focusMode) _setChrome(true);
    setState(() {});
  }

  /// Memorize from a sūrah, juzʼ, page… chosen in the index.
  Future<void> _memorizeFrom() async {
    final t = await chooseMemorizeStart(context,
        script: _script, currentPage: _pendingPage ?? _page);
    if (t == null || !mounted) return;
    if (_memorizing) _endMemorize();
    _startMemorize(token: t);
  }

  /// Memorize as verse cards: from the page in view (or carrying on from
  /// where the page view is), in large writing. Ending there ends it here.
  Future<void> _memorizeAsCards() async {
    if (_memo == null) _startMemorize();
    final m = _memo;
    if (m == null) return;
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => MemorizeCardsScreen(controller: m, fromMushaf: true)));
    if (r == 'end' && mounted) _endMemorize();
  }

  void _onMemo() {
    final m = _memo;
    if (m == null || !mounted) return;
    _showPage(m.viewPage);
    setState(() {});
  }

  void _endMemorize() {
    ReciteBack.instance.stop();
    _memo?.removeListener(_onMemo);
    setState(() => _memo = null);
  }

  /// Ḥuṣarī reciting what's showing: the āyah being memorized up to the
  /// last revealed word ([page]: everything revealed on the page). Again
  /// while it plays: stop.
  Future<void> _playRevealed({bool page = false}) async {
    final m = _memo;
    if (m == null) return;
    if (ReciteBack.instance.playing.value) {
      await ReciteBack.instance.stop();
      return;
    }
    final clips = page
        ? m.pageClips()
        : [?m.currentClip];
    if (clips.isEmpty) return;
    _stopAudio();
    final s = SettingsScope.of(context);
    final err = await ReciteBack.instance.play(clips, rate: s.playbackSpeed);
    if (!mounted) return;
    if (err != null) {
      showQToast(context, err);
    } else if (AyahAudio.instance.fellBack && !_warnedTimings) {
      _warnedTimings = true;
      showQToast(context, context.l10n.mzNoTimings);
    }
  }

  /// A phone on its side: the room kept under the pages for the floating
  /// memorize, review or marking bar, so it doesn't cover the pages' last
  /// lines (the spread shrinks to fit; one page scrolls past it).
  double get _landscapeBarRoom => !_barShown || _sideBar ? 0 : _barH + 16;

  /// A memorize, review or marking bar is up.
  bool get _barShown => _memorizing || _reviewing || _marking.active;

  /// A phone on its side showing two pages: memorize's bar stands in the
  /// margin beside them, not under them.
  bool get _sideBar => _phoneSpread && _memorizing;

  /// The width kept at the desktop's right edge for memorize's bar.
  static const _sideBarW = 64.0;

  /// The floating bar's height as last laid out (see [_measured]).
  double _barH = 0;

  /// [bar], reporting its height: the room kept for it under the pages.
  Widget _measured(Widget bar) => _ReportHeight(
      onHeight: (h) {
        if (mounted && (h - _barH).abs() > .5) setState(() => _barH = h);
      },
      child: bar);

  /// Whether a tap reveals while memorizing (Settings) — never in the Hifẓ
  /// home, whose memorize is all buttons (a tap plays the word).
  bool _tapReveals(AppSettings s) => !widget.home && s.memorizeTapReveals;

  /// One hand: the thumb pad in its corner, above [bar].
  ///
  /// [enabled] false: [bar] alone (focus mode's docked bar, under its pill
  /// with a pad of its own).
  Widget _withPad(MushafPaper paper, Widget bar, {bool enabled = true}) {
    final s = SettingsScope.of(context);
    final m = _memo;
    if (m == null || !s.memorizePad || !enabled || widget.home) return bar;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Align(
        alignment: s.memorizePadSide == 'left'
            ? Alignment.centerLeft
            : Alignment.centerRight,
        child: Padding(
          // Up from the bar, where the thumb rests.
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 36),
          child: MemorizePad(
            controller: m,
            ink: paper.ink,
            accent: paper.id == 'mono' ? paper.ink : paper.acc,
            guide: s.memorizePadGuide,
            haptics: s.haptics,
          ),
        ),
      ),
      bar,
    ]);
  }

  Widget _memorizeBar(MushafPaper paper,
      {bool floating = false, bool compact = false, bool vertical = false}) {
    final s = SettingsScope.of(context);
    return MemorizeBar(
        controller: _memo!,
        surahNames: _tnames,
        bg: paper.chrome,
        ink: paper.ink,
        sub: paper.sub,
        line: paper.line,
        accent: paper.id == 'mono' ? paper.ink : paper.acc,
        floating: floating,
        compact: compact,
        vertical: vertical,
        screen: _screenOf(_pendingPage ?? _page),
        // The Hifẓ home's Play: everything showing on the page.
        onPlay: widget.home ? () => _playRevealed(page: true) : _playRevealed,
        onPlayPage: () => _playRevealed(page: true),
        onSwitchView: _memorizeAsCards,
        onEnd: _endMemorize,
        minimal: s.focusMode,
        onExitFocus: () => s.update(() => s.focusMode = false),
      );
  }

  /// Memorizing, with "tap to reveal" on: a tap steps by its zone.
  void _memoTap(MushafWord _) {
    _lastWordTap = DateTime.now();
    _memoStep();
  }

  /// Where the last touch came down on the screen (the tap zones).
  Offset _lastDown = Offset.zero;

  /// A tap's step (Settings): on in the screen's left half, back in its
  /// right; by words, by āyāt, or (split) words in the top half and āyāt
  /// in the bottom — or turning the page once the screen is all revealed
  /// (or, going back, all hidden).
  void _memoStep() => _memo?.tapStep(SettingsScope.of(context).memorizeTap,
      _lastDown, MediaQuery.sizeOf(context));

  /// The pages on screen with [p], (first, last): its spread when two
  /// show.
  (int, int) _screenOf(int p) {
    final s = _settingsRef;
    if (s == null) return (p, p);
    final spread = (_desktop && _view(s) == 'spread') || _phoneSpread;
    if (!spread) return (p, p);
    final first = _spreadStart(p);
    return (first, (first + 1).clamp(1, _total));
  }

  bool _memoShows(MushafWord wd) =>
      _memo?.isRevealed(MushafRepo.tokenOf(_script, wd.ayah, wd.wordIdx)) ??
      false;

  /// Memorizing (the default): a tap on a revealed word plays it; on a
  /// revealed ۝, Ḥuṣarī recites that āyah. A hidden word gives nothing away.
  void _memoPlayWord(MushafWord wd) {
    _lastWordTap = DateTime.now();
    if (_memoShows(wd)) _playWordAudio(wd);
  }

  void _memoPlayVerse(int g) {
    _lastWordTap = DateTime.now();
    if (!_memoShows(MushafWord('', g, -1))) return;
    _stopAudio();
    ReciteBack.instance.play([(g, -1)],
        rate: SettingsScope.of(context).playbackSpeed);
  }

  /// Holding a revealed word opens its sheet (mark a stumble right there).
  void _memoHold(MushafWord wd) {
    if (_memoShows(wd)) {
      _showWord(wd);
    } else if (_tapReveals(SettingsScope.of(context))) {
      _memoTap(wd);
    }
  }

  Future<void> _startReview() async {
    _stopAudio();
    await startReview(context,
        script: _script,
        page: _pendingPage ?? _page,
        onMushaf: (c) {
          _attachReview(c);
          _setChrome(true);
        });
  }

  Future<void> _endReview() async {
    final r = _review;
    if (r == null) return;
    final again = await showReviewSummary(context, r);
    if (again && mounted) _startReview();
  }

  void _repeatReviewed({bool verse = false}) {
    final w = _review?.current?.ref;
    if (w == null) return;
    if (verse || w.isWholeAyah) {
      _playVerse(w.globalAyah, userTap: false, reciter: ReciteBack.reciter);
    } else {
      _playWordAudio(MushafWord('', w.globalAyah, w.word0));
    }
  }

  Widget _reviewBar(MushafPaper paper, {bool floating = false, Axis? axis}) =>
      ReviewBar(
        axis: axis,
        controller: _review!,
        pal: markPaletteForPaper(paper),
        bg: paper.chrome,
        ink: paper.ink,
        sub: paper.sub,
        line: paper.line,
        accent: paper.id == 'mono' ? paper.ink : paper.acc,
        floating: floating,
        onRepeatWord: _repeatReviewed,
        onRepeatVerse: () => _repeatReviewed(verse: true),
        onOpenWord: () {
          final w = _review?.current?.ref;
          if (w == null) return;
          _showWord(MushafWord(MushafRepo.wordText(_script, w.globalAyah,
                  w.word <= 0 ? 0 : w.word0), w.globalAyah,
              w.isWholeAyah ? -1 : w.word0));
        },
        onEnd: _endReview,
      );

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

  /// Link mode on: [m]'s likenesses are tapped on any page.
  void _startLinking(Mark m) {
    _stopAudio();
    setState(() => _linking = m);
    _setChrome(false);
  }

  /// In link mode, a tap on a word (or, [ref] word 0, a ۝) links it to the
  /// mutashābih — or unlinks it.
  void _linkTap(WordRef ref) {
    _lastWordTap = DateTime.now();
    final m = _linking;
    final store = MarksScope.maybeOf(context);
    if (m == null || store == null || ref == m.ref) return;
    store.toggleLink(m, ref);
    if (SettingsScope.of(context).haptics) HapticFeedback.selectionClick();
  }

  /// Leaves link mode. A mutashābih with nothing linked isn't one: on
  /// cancel it goes (Done needs a link).
  void _endLinking() {
    final m = _linking;
    final store = MarksScope.maybeOf(context);
    if (m != null && store != null && store.linksOf(m).isEmpty) {
      store.deleteMark(m);
    }
    setState(() => _linking = null);
  }

  /// Link mode's banner: what to do, how many are linked, Cancel and Done.
  Widget _linkBar(MushafPaper paper) {
    final m = _linking!;
    final store = MarksScope.of(context);
    final n = store.linksOf(m).length;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: paper.chrome,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: paper.line),
        boxShadow: qShadows(context, const [
          BoxShadow(
              color: Color(0x40000000),
              blurRadius: 16,
              offset: Offset(0, 6),
              spreadRadius: -10),
        ]),
      ),
      child: Row(children: [
        Icon(AppIcons.link, color: accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${context.l10n.mkMutashabih} · '
                  '${linkLabel(_script, m.ref)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context,
                      size: 13, weight: FontWeight.w700, color: paper.ink)),
              Text(context.l10n.mtLinkBanner,
                  maxLines: 2,
                  style: uiStyle(context, size: 12, color: paper.sub)),
            ],
          ),
        ),
        TextButton(
          onPressed: _endLinking,
          child: Text(context.l10n.cancel,
              style: uiStyle(context, size: 13.5, color: paper.sub)),
        ),
        FilledButton(
          onPressed: n == 0 ? null : () => setState(() => _linking = null),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: paper.chrome,
            minimumSize: const Size(0, 38),
          ),
          child: Text(context.l10n.mtDone(n)),
        ),
      ]),
    );
  }

  /// A tap on ۝ while marking marks the whole āyah (e.g. skipped).
  void _markAyah(int global) {
    _lastWordTap = DateTime.now();
    final (s, a) = surahAyahFromGlobal(global);
    _marking.apply(context, WordRef(s, a, 0));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    displayRotationChanges.removeListener(_rotationChanged);
    disposeRecitationTracking();
    _doneSub?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    _ctrl?.dispose();
    _spreadCtrl?.dispose();
    _pageN.dispose();
    _marking.removeListener(_onMarking);
    // A review left by closing the muṣḥaf ends (its session closes) — just
    // after this frame: ending it notifies the marks, and the screens that
    // listen to them can't rebuild while the tree is being torn down.
    final r = _review;
    if (r != null) {
      r.removeListener(_onReview);
      Future.microtask(r.end);
    }
    if (_memo != null) {
      _memo!.removeListener(_onMemo);
      ReciteBack.instance.stop();
    }
    _marking.dispose();
    _marksLayer.dispose();
    MushafLineScheduler.reset();
    MushafAtlas.of(_script)?.releaseLarge();
    PerfLog.where = 'app';
    final n = _shell?.focus;
    if (n != null && n.value) n.value = false;
    if (!_chrome || _landscape) {
      _landscape = false;
      _restoreSystemBars();
    }
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(const []).catchError((_) {});
    }
    super.dispose();
  }

  // ── pages ──────────────────────────────────────────────────────────────

  // The Hifẓ home lays itself out (pages and toolbar) on every screen.
  bool get _desktop => !widget.home && useDesktop(context);
  String _view(AppSettings s) => _desktop ? s.mushafView : 'single';

  /// Desktop spreads pair pages like the open book: 1|2, 3|4 … with the
  /// lower page on the right.
  int _spreadStart(int p) => ((p - 1) >> 1) * 2 + 1;

  void _settle(int page) {
    final sw = kMushafPerf ? (Stopwatch()..start()) : null;
    PerfLog.where = 'muṣḥaf p.$page';
    _page = page;
    // A word an index count led to stays outlined until the page moves on
    // (a review's focus follows the review instead).
    if (!_reviewing && _focus != null && _pageOfWord(_focus!) != page) {
      _focus = null;
    }
    _curSurah = MushafRepo.firstVerseOfPage(_script, page).$1;
    ProgressScope.read(context).setLastMushafPage(page, _script);
    _notePage(page);
    _prewarm(page);
    _pageN.value = page;
    if (sw != null) {
      PerfLog.log('→ page $page (bookkeeping ${sw.elapsedMicroseconds} µs)');
    }
  }

  /// Prepares the pages either side of [page] in the background — their
  /// sizes and every line, one line per step — so the swipe that reaches
  /// them finds them ready. Paused while a finger is down (see
  /// [MushafLineScheduler]).
  void _prewarm(int page) {
    final s = _settingsRef;
    if (s == null) return;
    // Drawn from the glyph atlas: nothing to prepare.
    if (MushafAtlas.of(_script) != null) return;
    final spread = (_desktop && _view(s) == 'spread') || _phoneSpread;
    final first = spread ? _spreadStart(page) : page;
    final order = spread
        ? [first + 2, first + 3, first - 1, first - 2]
        : [page + 1, page - 1, page + 2, page - 2];
    MushafLineScheduler.addJob(_warm(order, _script, mushafPaperOf(s, _script)));
  }

  /// How the pages are dressed: ornaments and border, focus mode applied.
  MushafLook _look(AppSettings s) => s.mushafLook(_script);

  Iterable<void> _warm(List<int> pages, String script, MushafPaper paper) sync* {
    for (final p in pages) {
      if (!mounted || script != _script) return;
      if (p < 1 || p > _total) continue;
      final lines = MushafRepo.pageSync(script, p);
      if (lines == null || lines.isEmpty) continue;
      final sw = kMushafPerf ? (Stopwatch()..start()) : null;
      if (!MushafGeometry.hasWidths(script, p, lines)) {
        MushafGeometry.widestEm(script, p, lines);
        yield null;
      }
      _ayahsOn(p);
      final vp = mushafLastViewport;
      final size = mushafTextAreaFor(p);
      if (vp == null || size == null) continue;
      final fitWidth = vp.$2;
      final (fs, slotH, _) = mushafPageGeometry(
          script, p, lines, size.width, size.height,
          fitWidth: fitWidth);
      final marker = markerOf(_look(_settingsRef!), paper);
      var shaped = 0;
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].isText) continue;
        final spec = MushafLineSpec(
          script: script,
          page: p,
          index: i,
          line: lines[i],
          fontSize: fs,
          slotH: slotH,
          targetW: size.width,
          ink: paper.ink,
          accent: paper.acc,
          strongBg: paper.hl2,
          verseBg: paper.hl,
          justify: !mushafOpeningPage(p, lines),
          ornament: marker.color,
          ornamentFill: marker.fill,
          markerArt: marker.art,
          markerScale: marker.scale,
          markerDy: marker.dy,
        );
        if (MushafLineCache.has(spec.key)) continue;
        MushafLineCache.get(spec, why: 'prewarm');
        shaped++;
        yield null;
        if (!mounted || script != _script) return;
      }
      if (sw != null && shaped > 0) {
        PerfLog.log('prepared page $p in the background: $shaped lines');
      }
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
    final c = _phoneSpread ? _spreadCtrl : _ctrl;
    final idx = _phoneSpread ? (_spreadStart(t) - 1) ~/ 2 : t - 1;
    if (c == null || !c.hasClients || c.page?.round() == idx) {
      setState(() => _settle(t));
      return;
    }
    if (animate && !noMotion(context)) {
      c.animateToPage(idx,
          duration: const Duration(milliseconds: 380),
          curve: const Cubic(.2, .8, .2, 1));
    } else {
      c.jumpToPage(idx);
    }
  }

  /// One step forward (+1) or back (−1): a spread at a time in spread view.
  void _turn(int dir) {
    final s = SettingsScope.of(context);
    if (_desktop && _view(s) == 'spread') {
      _jump(_spreadStart(_page) + 2 * dir);
    } else if (_phoneSpread) {
      _jump(_spreadStart(_page) + 2 * dir, animate: true);
    } else {
      _jump(_page + dir, animate: true);
    }
  }

  /// The pager moved to a new page (fires halfway through a swipe). Only
  /// remembered here: the screen updates when the swipe has settled (see
  /// [_onScroll]), so nothing rebuilds while the finger is still moving.
  void _onPage(int i) {
    _pendingPage = i + 1;
    PerfLog.where = 'muṣḥaf p.${i + 1}';
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification) {
      MushafLineScheduler.scrolling = true;
    } else if (n is ScrollEndNotification) {
      MushafLineScheduler.scrolling = false;
      final p = _pendingPage;
      _pendingPage = null;
      // The bars follow through _pageN; the screen itself isn't rebuilt.
      if (p != null && p != _page && mounted) _settle(p);
    }
    return false;
  }

  /// The last script switch, to make switching straight back exact.
  ({String from, int fromPage, String to, int toPage})? _lastSwitch;

  Future<void> _switchScript(String v) async {
    if (v == _script) return;
    if (!kIndopakMushafAvailable && v == 'indopak') {
      comingSoon(context, context.l10n.indoPak);
      return;
    }
    _stopAudio();
    final from = _script, fromPage = _pendingPage ?? _page;
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
    await MushafRepo.ensure(from);
    await MushafRepo.ensure(v);
    if (!mounted) return;
    // Straight back to the script we just came from, without turning a
    // page: the page we were on. (Mapping back by the middle word could
    // land one page off, since the two scripts break pages differently.)
    final back = _lastSwitch;
    final p = back != null &&
            back.to == from &&
            back.toPage == fromPage &&
            back.from == v
        ? back.fromPage
        : MushafRepo.matchingPage(from, fromPage, v);
    _lastSwitch = (from: from, fromPage: fromPage, to: v, toPage: p);
    _page = p;
    _ctrl?.dispose();
    _ctrl = PageController(initialPage: p - 1);
    _spreadCtrl?.dispose();
    _spreadCtrl = _phoneSpread
        ? PageController(initialPage: (_spreadStart(p) - 1) ~/ 2)
        : null;
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

  /// A phone turned on its side hides the status bar for the whole time —
  /// the pages get its height; turned back, the bars return as they were.
  void _setLandscape(bool on) {
    if (on == _landscape) return;
    _landscape = on;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_landscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
            .catchError((_) {});
      } else if (_chrome) {
        _restoreSystemBars();
      }
    });
  }

  void _rotationChanged() {
    final r = displayRotationChanges.value;
    if (r >= 0 && widget.home) _onRotation(r);
  }

  /// Back from the background: Android shows the system bars again, so
  /// they're set as the page wants them (hidden on its side, while the bars
  /// are hidden, or by the immersive setting).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _desktop) return;
    if (_landscape || !_chrome) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
          .catchError((_) {});
    } else {
      _restoreSystemBars();
    }
  }

  void _restoreSystemBars() {
    // On its side the phone keeps the bars hidden (see _setLandscape).
    if (_landscape) return;
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
    // Linking: the page stays as it is (taps are for words and ۝).
    if (_linking != null) return;
    // The Hifẓ home keeps its toolbar.
    if (widget.home && !_memorizing) return;
    // While marking, the pen bar stays put: a near-miss on a word must not
    // hide it.
    if (_memorizing) {
      // The page itself: a step by its zone when taps reveal; else nothing
      // (the bars stay put, the words wait for the bar's buttons).
      if (_tapReveals(SettingsScope.of(context))) _memoStep();
      return;
    }
    if (_marking.active || _reviewing) return;
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

  /// Cream → white → Madani → mono → night → night mono → OLED → OLED mono,
  /// setting the app theme as it goes (cream, white and Madani are the light
  /// theme; the mono pages of night and OLED are theirs).
  ///
  /// Without customisation ([kMushafCustomization]): light → dark → OLED.
  void _cyclePaper(AppSettings s) {
    if (!kMushafCustomization) {
      s.update(s.cycleBrightness);
      return;
    }
    const light = ['cream', 'white', 'madani', 'tile1', 'tile2', 'tile3'];
    const order = [
      ...light, 'mono', //
      'night', 'night_mono', 'oled', 'oled_mono',
    ];
    final cur = mushafPaperOf(s, _script).id;
    final next = order[(order.indexOf(cur) + 1) % order.length];
    s.update(() {
      if (light.contains(next)) {
        s.appTheme = 'light';
        s.mushafPaper = next;
      } else if (next.endsWith('_mono')) {
        s.appTheme = next.substring(0, next.length - 5);
        s.mushafPaperDark = 'mono';
      } else {
        s.appTheme = next;
        if (next != 'mono') s.mushafPaperDark = 'default';
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

  /// Plays āyah [global] in the chosen reciter's voice ([reciter]: another
  /// one — review recites in Ḥuṣarī's).
  Future<void> _playVerse(int global,
      {bool userTap = true, String? reciter}) async {
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
        await AyahAudio.instance.play(surah, ayahInSurah,
            reciter: reciter ?? s.reciter);
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

  void _playAndShowWord(MushafWord wd) {
    _playWordAudio(wd);
    _showWord(wd);
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
    showAdaptiveSheet<void>(
      context,
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
                    wd.isMarker
                        ? '${_tnames[surah] ?? ''}  ·  $surah:$ayahInSurah  ·  '
                            '${context.l10n.mkWholeAyah}'
                        : context.l10n.wordN(_tnames[surah] ?? '',
                            '$surah:$ayahInSurah', wd.wordIdx + 1),
                    style: uiStyle(sheet,
                        size: 13, weight: FontWeight.w600, color: p.ink3)),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  if (!wd.isMarker)
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
                  sessionId: _marking.active
                      ? _marking.sessionId
                      : _review?.sessionId,
                  onLink: (m) {
                    Navigator.pop(sheet);
                    _startLinking(m);
                  },
                ),
            ],
          ),
        );
        if (!hasMarks || AdaptiveSheet.isSide(sheet)) return body(null);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .94,
          builder: (_, scroll) => body(scroll),
        );
      },
    );
  }

  /// The reader, at the first āyah on the page in view — the muṣḥaf's
  /// counterpart of the reader's 15-line toggle. It takes the muṣḥaf's
  /// place, so closing either returns to where the muṣḥaf was opened from.
  Future<void> _openReader() async {
    _stopAudio();
    final (su, ay) = MushafRepo.firstVerseOfPage(_script, _pendingPage ?? _page);
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    final nav = Navigator.of(context);
    final route = MaterialPageRoute<void>(
        builder: (_) => SurahReaderScreen(meta: metas[su - 1], startAyah: ay));
    nav.canPop() ? nav.pushReplacement(route) : nav.push(route);
  }

  /// Go to page, or to the start of a sūrah.
  void _showIndex() {
    showMushafIndex(
      context,
      script: _script,
      currentPage: _pendingPage ?? _page,
      onPage: (p) => _jump(p),
      // A count pill: to the first mark of that kind in the division, the
      // word outlined.
      onWord: _focusWord,
    );
  }

  void _showSettings() {
    showAdaptiveSheet<void>(
      context,
      builder: (sheet) => AdaptiveSheet.isSide(sheet)
          ? _settingsSheet(sheet, null)
          : DraggableScrollableSheet(
              expand: false,
              initialChildSize: .7,
              maxChildSize: .94,
              builder: _settingsSheet,
            ),
    );
  }

  /// [_showSettings]'s content.
  Widget _settingsSheet(BuildContext sheet, ScrollController? scroll) =>
      _MushafSettingsSheet(
          controller: scroll,
          script: _script,
          onScript: (v) {
            Navigator.pop(sheet);
            _switchScript(v);
          },
          onReview: MarksScope.maybeOf(context)?.activeBook == null
              ? null
              : () {
                  Navigator.pop(sheet);
                  if (_marking.active) _marking.stop();
                  if (_memorizing) _endMemorize();
                  _startReview();
                },
          onMemorize: _memorizing
              ? null
              : () {
                  Navigator.pop(sheet);
                  _startMemorize();
                },
          onMemorizeFrom: () {
            Navigator.pop(sheet);
            _memorizeFrom();
          },
          onMemorizeCards: () {
            Navigator.pop(sheet);
            _memorizeAsCards();
          },
        );

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    PerfLog.screenBuilt();
    final s = SettingsScope.of(context);
    if (s.lite != MushafAtlas.smallOnly) {
      // Lite mode toggled: rebuilt pages hand their lines a fresh spec,
      // which redraws them from the right sheets.
      MushafAtlas.setSmallOnly(s.lite);
      _pageMemo.clear();
    }
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
      _spreadCtrl?.dispose();
      _spreadCtrl = _phoneSpread
          ? PageController(initialPage: (_spreadStart(_page) - 1) ~/ 2)
          : null;
    }
    _wasDesktop = desktop;
    final paper = mushafPaperOf(s, _script);
    return PopScope(
      canPop: _chrome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_chrome) _setChrome(true);
      },
      child: Scaffold(
        backgroundColor: _look(s).edge ? paper.paper : paper.bg,
        body: _withLinkBar(paper, !_ready
            ? Center(child: CircularProgressIndicator(color: paper.acc))
            : widget.home
                ? _hifzBody(context, s, paper)
            : desktop
                ? _desktopBody(context, s, paper)
                : LayoutBuilder(builder: (context, c) {
                    // A phone on its side: short and wide. The page then uses
                    // the full width and scrolls vertically.
                    final landscape =
                        c.maxWidth > c.maxHeight && c.maxHeight < 520;
                    _setPhoneSpread(landscape && s.mushafPhoneSpread);
                    _setLandscape(landscape);
                    final pager = !landscape
                        ? _pager(s, paper,
                            fitWidth: false,
                            // Edge to edge: the page meets the screen's edges.
                            margin: _look(s).edge
                                ? EdgeInsets.zero
                                : const EdgeInsets.fromLTRB(8, 8, 8, 8))
                        : _phoneSpread
                            ? _spreadPager(s, paper,
                                margin: EdgeInsets.fromLTRB(
                                    68, 4, 72, 4 + _landscapeBarRoom))
                            : _pager(s, paper,
                                fitWidth: true,
                                margin: EdgeInsets.fromLTRB(
                                    68, 10, 72, _landscapeBarRoom));
                    // A page turn only refreshes the bars (title, page label,
                    // progress): the pager is handed through as the same
                    // widget, so its pages aren't rebuilt.
                    return ValueListenableBuilder<int>(
                      valueListenable: _pageN,
                      child: pager,
                      builder: (context, _, pager) => landscape
                          ? _landscapeBody(context, s, paper, pager!)
                          : _portraitBody(context, s, paper, pager!),
                    );
                  })),
      ),
    );
  }

  /// [body], with link mode's banner floating over its top.
  Widget _withLinkBar(MushafPaper paper, Widget body) {
    if (_linking == null) return body;
    return Stack(children: [
      body,
      Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 12,
        right: 12,
        child: Center(child: _linkBar(paper)),
      ),
    ]);
  }

  Widget _pageView(int page, AppSettings s, MushafPaper paper,
          {bool fitWidth = false,
          EdgeInsets margin = EdgeInsets.zero,
          String? spine,
          bool compact = false}) =>
      _memoPage(
        page: page,
        paper: paper,
        s: s,
        fitWidth: fitWidth,
        margin: margin,
        spine: spine,
        compact: compact,
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
    bool compact = false,
  }) {
    _handlers
      // Reading: a tap plays the word; holding it plays it and opens its
      // sheet. Marking: a tap steps the word's mark through the types;
      // holding it opens the sheet to fix, comment, reply or delete.
      // Reviewing: a tap plays the word (any word on the page), holding it
      // opens its sheet.
      ..onTapWord = _memorizing
          ? (_tapReveals(s) ? _memoTap : _memoPlayWord)
          : (_marking.active ? _markWord : _playWordAudio)
      ..onLongPressWord = _memorizing
          ? _memoHold
          : (_marking.active || _reviewing ? _showWord : _playAndShowWord)
      ..onTapVerse = _memorizing
          ? (_tapReveals(s) ? ((_) => _memoStep()) : _memoPlayVerse)
          : _onTapVerse
      // Holding a ۝: the whole āyah's sheet, to mark it (memorizing: once
      // it shows).
      ..onLongPressVerse = _memorizing ? _memoHold : _showWord;
    // The Hifẓ home: the word tool's taps (comment, eraser, audio, or none).
    if (widget.home && !_memorizing && !_marking.active && !_reviewing) {
      _hifzHandlers();
    }
    // Link mode: words and ۝ link (or unlink) whatever else is on.
    if (_linking != null) {
      WordRef word(MushafWord wd) => WordRef.fromGlobal(wd.ayah, wd.wordIdx);
      WordRef ayah(int g) => WordRef.fromGlobal(g, -1);
      _handlers
        ..onTapWord = ((wd) => _linkTap(word(wd)))
        ..onLongPressWord = ((wd) => _linkTap(word(wd)))
        ..onTapVerse = ((g) => _linkTap(ayah(g)))
        ..onLongPressVerse = ((wd) => _linkTap(word(wd)));
    }
    final (lo, hi) = _ayahsOn(page);
    final mine = _playAyah >= 0 && _playAyah >= lo && _playAyah <= hi;
    // Memorizing (revision too): a word's marks appear as the word does —
    // hidden words draw nothing, marks included. Each page gets only its
    // own cut, so pages away from it keep their look.
    // Marks reach the lines through the layer: an edit repaints its own
    // page's lines and rebuilds no page.
    _bindMarks(s);
    final markPal = markPaletteForPaper(paper);
    // Only the page holding the focused word gets it: the others' lines
    // keep their cached look.
    final f = _focus;
    final focus =
        f != null && !_memorizing && _pageOfWord(f) == page ? f.key : -1;
    final hideFrom = _memo?.hideFromOn(page) ?? -1;
    final tajwid = s.mushafTajwid ? tajwidColorsForDark(paper.dark) : null;
    // The spine's shade: the desktop's own spread; the Hifẓ home's pages lie
    // flat, a line between them.
    final shade = !widget.home && s.useGradients;
    final inputs = <Object?>[
      _script, paper, _look(s), fitWidth, s.mushafHeaderShown, margin, spine,
      _names, mine ? _playAyah : -1, mine ? _playWord : -1,
      mine && _reciting, markPal, tajwid, compact, focus, hideFrom, shade,
    ];
    final key = '$page/${spine ?? ''}';
    final memo = _pageMemo.remove(key);
    if (memo != null && _sameInputs(memo.$1, inputs)) {
      _pageMemo[key] = memo; // most recently used
      return memo.$2;
    }
    final w = _MushafPageView(
      page: page,
      script: _script,
      names: _names,
      paper: paper,
      look: _look(s),
      wideLayout: fitWidth,
      showHeader: s.mushafHeaderShown,
      margin: margin,
      spine: spine,
      playAyah: mine ? _playAyah : -1,
      playWord: mine ? _playWord : -1,
      reciting: mine && _reciting,
      marks: _marksLayer,
      markPal: markPal,
      shade: shade,
      handlers: _handlers,
      tajwid: tajwid,
      compact: compact,
      focus: focus,
      hideFrom: hideFrom,
    );
    // The least recently used go first (a spread keeps six pages alive).
    while (_pageMemo.length >= 20) {
      _pageMemo.remove(_pageMemo.keys.first);
    }
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

  /// The active mark book's marks, as the pages draw them.
  final _marksLayer = MushafMarksLayer();

  void _bindMarks(AppSettings s) => _marksLayer.bind(
        store: MarksScope.maybeOf(context),
        script: _script,
        show: s.showMarks,
        showFixed: s.showFixedMarks,
      );

  /// The pen button for the bars (starts or ends marking).
  Widget? _penButton(BuildContext context, MushafPaper paper,
      {double size = 40, bool shadow = false}) {
    if (MarksScope.maybeOf(context) == null || _reviewing || _memorizing) {
      return null;
    }
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

  Widget _markingBar(MushafPaper paper, {bool floating = false, Axis? axis}) =>
      MarkingBar(
        axis: axis,
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

  /// One page per swipe; with [head], each page has its own line above it
  /// (the Hifẓ home: sūrah · page · juzʼ, set on the page's edges).
  Widget _pager(AppSettings s, MushafPaper paper,
          {required bool fitWidth,
          required EdgeInsets margin,
          Widget Function(int page, double width)? head}) =>
      _swiper(
        controller: _ctrl,
        count: _total,
        onPage: _onPage,
        builder: (context, i) => _pagerItem(s, paper, i,
            fitWidth: fitWidth, margin: margin, head: head),
      );

  /// The height of the line a page's [_pager] head takes.
  static const _headH = 40.0;

  /// Two facing pages per swipe (a phone on its side; the Hifẓ home in
  /// landscape, with [rail] wide margins outside them and a [gap] between).
  Widget _spreadPager(AppSettings s, MushafPaper paper,
          {required EdgeInsets margin, double rail = 0, double gap = 0}) =>
      _swiper(
        controller: _spreadCtrl,
        count: (_total + 1) ~/ 2,
        onPage: (i) => _onPage(2 * i),
        builder: (context, i) => LayoutBuilder(builder: (context, c) {
          final avail = Size((c.maxWidth - margin.horizontal - 2 * rail - gap) / 2,
              c.maxHeight - margin.vertical);
          mushafPageBoxOf = (p) => _spreadBoxOf(p, avail, s, compact: true);
          return Padding(
            padding: margin,
            child: Center(
                child: _spreadRow(2 * i + 1, avail, s, paper,
                    compact: true, rail: rail, gap: gap)),
          );
        }),
      );

  /// Switches the phone between one page and two (and back), keeping the
  /// page: each pager starts where the other was.
  void _setPhoneSpread(bool on) {
    if (on == _phoneSpread) return;
    _phoneSpread = on;
    _ctrl?.dispose();
    _ctrl = PageController(initialPage: _page - 1);
    _spreadCtrl?.dispose();
    _spreadCtrl =
        on ? PageController(initialPage: (_spreadStart(_page) - 1) ~/ 2) : null;
  }

  Widget _swiper({
    required PageController? controller,
    required int count,
    required ValueChanged<int> onPage,
    required IndexedWidgetBuilder builder,
  }) =>
      Listener(
        // A finger on the pages pauses background work until it lifts.
        onPointerDown: (e) {
          _lastDown = e.position;
          MushafLineScheduler.pointerDown();
        },
        onPointerUp: (_) => MushafLineScheduler.pointerUp(),
        onPointerCancel: (_) => MushafLineScheduler.pointerUp(),
        child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onPageTap,
        child: PageView.builder(
          key: ValueKey('$_script/${count == _total}'),
          controller: controller,
          reverse: true, // right-to-left page turning
          // Pre-builds the adjacent page instead of Flutter's default
          // zero-length cache extent, so a page's first-visit layout cost
          // lands before the swipe reaches it, not mid-gesture.
          allowImplicitScrolling: true,
          itemCount: count,
          onPageChanged: onPage,
          itemBuilder: builder,
        ),
      ),
      ),
      );

  Widget _pagerItem(AppSettings s, MushafPaper paper, int i,
      {required bool fitWidth,
      required EdgeInsets margin,
      Widget Function(int page, double width)? head}) {
    final page = _pageView(i + 1, s, paper, fitWidth: fitWidth, margin: margin);
    if (fitWidth) return page;
    // Portrait: a page with a scanned shape takes exactly the printed page's
    // proportions (MushafGeometry.pageRatio); otherwise it takes the width
    // its text needs and the full height between the bars, spare height
    // spreading the lines.
    return LayoutBuilder(builder: (context, c) {
      final headH = head == null ? 0.0 : _headH;
      final avail = Size(
          c.maxWidth - margin.horizontal, c.maxHeight - margin.vertical - headH);
      Size box(int p) {
        final b = MushafGeometry.pageBox(avail, _script,
            look: _look(s), header: s.mushafHeaderShown, page: p);
        return MushafGeometry.pageRatio(_script, p) == null
            ? Size(b.width, avail.height)
            : b;
      }

      mushafPageBoxOf = box;
      final b = box(i + 1);
      // The opening pages' few lines sit together in the middle of the page:
      // the line above it comes down to them, over the page's empty top.
      var drop = 0.0;
      final lines = MushafRepo.pageSync(_script, i + 1);
      if (head != null && lines != null && mushafOpeningPage(i + 1, lines)) {
        final fs = b.width / MushafGeometry.refEmOf(_script);
        final block = lines.length * fs * MushafGeometry.pitch;
        drop = ((b.height - block) / 2 - 8).clamp(0.0, b.height);
      }
      final sized = SizedBox(
          width: b.width + margin.horizontal,
          height: b.height + margin.vertical,
          child: page);
      if (head == null) return Center(child: sized);
      return Center(
        child: SizedBox(
          width: b.width + margin.horizontal,
          height: headH + b.height + margin.vertical,
          child: Stack(children: [
            Positioned(top: headH, left: 0, right: 0, bottom: 0, child: sized),
            // Over the page (its empty top, on the opening pages).
            Positioned(
              top: drop,
              left: margin.left,
              width: b.width,
              height: headH,
              child: head(i + 1, b.width),
            ),
          ]),
        ),
      );
    });
  }

  /// Fades a bar in and out with the chrome (250ms), and stops it catching
  /// taps while hidden.
  Widget _fade(Widget child) => IgnorePointer(
        ignoring: !_chrome,
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: motion(context, const Duration(milliseconds: 250)),
          child: child,
        ),
      );

  // ── phone, portrait ──

  Widget _portraitBody(
      BuildContext context, AppSettings s, MushafPaper paper, Widget pager) {
    final pad = MediaQuery.paddingOf(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(
            top: _chrome ? pad.top + _kTopBar : pad.top,
            bottom: _chrome ? pad.bottom + _kBottomBar : pad.bottom,
          ),
          child: pager,
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
                  icon: AppIcons.reader,
                  tooltip: context.l10n.navReader,
                  onTap: _openReader),
              const SizedBox(width: 8),
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
        child: _fade(_withPad(paper, enabled: !s.focusMode, Container(
          padding: EdgeInsets.fromLTRB(12, 0, 12, pad.bottom + 10),
          decoration: BoxDecoration(
            color: paper.chrome,
            border: Border(top: BorderSide(color: paper.line)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _progressLine(paper),
            const SizedBox(height: 2),
            if (_memorizing && !s.focusMode)
              _memorizeBar(paper)
            else if (_reviewing)
              _reviewBar(paper)
            else if (_marking.active)
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
        ))),
      ),
      // Focus mode: memorize's small pill floats over the bare page.
      if (_memorizing && s.focusMode)
        Positioned(
          bottom: pad.bottom + 12,
          left: 12,
          right: 12,
          child: _withPad(
              paper, Center(child: _memorizeBar(paper, floating: true))),
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
      Text(mushafPaperName(context, paper.id),
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
      BuildContext context, AppSettings s, MushafPaper paper, Widget pager) {
    final pad = MediaQuery.paddingOf(context);
    return Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(
              left: pad.left, right: pad.right, top: pad.top, bottom: 0),
          child: pager,
        ),
      ),
      PositionedDirectional(
        top: pad.top + 14,
        start: pad.left + 12,
        child: _fade(Column(children: [
          _PaperButton(
              paper: paper,
              icon: AppIcons.close,
              size: 46,
              shadow: true,
              tooltip: context.l10n.closeMushaf,
              onTap: _close),
          const SizedBox(height: 8),
          _PaperButton(
              paper: paper,
              icon: AppIcons.tune,
              size: 46,
              shadow: true,
              tooltip: context.l10n.mushafSettings,
              onTap: _showSettings),
          const SizedBox(height: 8),
          _PaperButton(
              paper: paper,
              icon: AppIcons.indexList,
              size: 46,
              shadow: true,
              tooltip: context.l10n.idxIndex,
              onTap: _showIndex),
          // Its place on the right is taken by memorize's bar.
          if (_sideBar) ...[
            const SizedBox(height: 8),
            _PaperButton(
                paper: paper,
                icon: AppIcons.fitWidth,
                size: 46,
                shadow: true,
                tooltip: context.l10n.fillWidthScroll,
                onTap: () => s.update(() => s.mushafPhoneSpread = false)),
          ],
        ])),
      ),
      // (Memorizing two pages, the right margin holds memorize's bar.)
      if (!_sideBar)
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
          // One page across the width ↔ two facing pages.
          _PaperButton(
              paper: paper,
              icon: _phoneSpread ? AppIcons.fitWidth : AppIcons.viewSpread,
              size: 46,
              shadow: true,
              tooltip: _phoneSpread
                  ? context.l10n.fillWidthScroll
                  : context.l10n.twoPageSpread,
              onTap: () => s.update(
                  () => s.mushafPhoneSpread = !s.mushafPhoneSpread)),
          const SizedBox(height: 8),
          _PaperButton(
              paper: paper,
              icon: AppIcons.pageColour,
              size: 46,
              shadow: true,
              tooltip: context.l10n.pageColour,
              onTap: () => _cyclePaper(s)),
          const SizedBox(height: 8),
          _PaperButton(
              paper: paper,
              icon: AppIcons.reader,
              size: 46,
              shadow: true,
              tooltip: context.l10n.navReader,
              onTap: _openReader),
          const SizedBox(height: 8),
          if (_penButton(context, paper, size: 46, shadow: true)
              case final pen?) ...[
            pen,
            const SizedBox(height: 8),
          ],
          _reciteButton(context, paper, size: 46),
        ])),
      ),
      if (_sideBar) ...[
        // Two pages: the bar in the right margin, the pages at full height.
        Positioned(
          top: pad.top + 8,
          bottom: pad.bottom + 8,
          right: pad.right + 10,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _memorizeBar(paper, floating: true, vertical: true),
            ),
          ),
        ),
        if (s.memorizePad)
          Positioned(
            bottom: pad.bottom + 8,
            left: 80,
            right: 80,
            child: _withPad(paper, const SizedBox.shrink()),
          ),
      ] else if (_memorizing)
        Positioned(
          bottom: pad.bottom + 10,
          left: 80,
          right: 80,
          child: _withPad(
              paper,
              Center(
                  child: _measured(
                      _memorizeBar(paper, floating: true, compact: true)))),
        )
      else if (_reviewing)
        Positioned(
          bottom: pad.bottom + 10,
          left: 96,
          right: 96,
          child: Center(child: _measured(_reviewBar(paper, floating: true))),
        )
      else if (_marking.active)
        Positioned(
          bottom: pad.bottom + 10,
          left: 0,
          right: 0,
          child: Center(child: _measured(_markingBar(paper, floating: true))),
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
                boxShadow: qShadows(context, const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                      spreadRadius: -10),
                ]),
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
                      _phoneSpread && _spreadStart(_page) < _total
                          ? context.l10n.pagesJuz(
                              _spreadStart(_page),
                              _spreadStart(_page) + 1,
                              MushafRepo.juzOfPage(
                                  _script, _spreadStart(_page)))
                          : context.l10n.pageJuz(
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
    final mz = _memo;
    if (mz != null) {
      // Memorizing: ← (onward, as the text runs) or Space reveals the next
      // word, → hides it again; with Shift, a whole āyah. PageDown: the rest
      // of the page. P: hear what's showing. Esc: end.
      final shift = keys.isShiftPressed;
      if (k == LogicalKeyboardKey.arrowLeft ||
          (k == LogicalKeyboardKey.space && e is KeyDownEvent)) {
        shift ? mz.nextVerse() : mz.nextWord();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.backspace) {
        shift ? mz.prevVerse() : mz.prevWord();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.pageDown && e is KeyDownEvent) {
        mz.nextPage();
        return KeyEventResult.handled;
      }
      if (e is KeyDownEvent && k == LogicalKeyboardKey.keyP) {
        _playRevealed(page: shift);
        return KeyEventResult.handled;
      }
      if (e is KeyDownEvent && k == LogicalKeyboardKey.escape) {
        _endMemorize();
        return KeyEventResult.handled;
      }
    }
    final r = _review;
    if (r != null && _reviewing) {
      // Reviewing: the arrows step through the marks (← is onward, as the
      // book reads right to left), R repeats (Shift: the verse), F fixes.
      if (k == LogicalKeyboardKey.arrowLeft) {
        r.next();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        r.prev();
        return KeyEventResult.handled;
      }
      if (e is KeyDownEvent) {
        if (k == LogicalKeyboardKey.keyR) {
          _repeatReviewed(verse: keys.isShiftPressed);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyF) {
          r.markFixed();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.keyZ &&
            (keys.isControlPressed || keys.isMetaPressed)) {
          r.undo();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.escape) {
          _endReview();
          return KeyEventResult.handled;
        }
      }
    }
    if (e is KeyDownEvent && _marking.active) {
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
          duration: motion(context, const Duration(milliseconds: 250)),
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
        // A two-finger sideways swipe on a trackpad turns the page.
        Expanded(
            child: Listener(
              onPointerDown: (e) => _lastDown = e.position,
              child: TrackpadPager(
                onTurn: _turn,
                child: RepaintBoundary(
                    child: _stage(context, s, paper, view, first))))),
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
            icon: AppIcons.reader,
            tooltip: context.l10n.navReader,
            onTap: _openReader),
        const SizedBox(width: 10),
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

  /// [page]'s box in a two-page spread that fits pages of [avail] each:
  /// facing pages share one height (the shorter of the two), each as wide as
  /// its scanned shape makes it.
  Size _spreadBoxOf(int page, Size avail, AppSettings s,
      {bool compact = false}) {
    final first = _spreadStart(page);
    Size fit(int p, Size a) => MushafGeometry.pageBox(a, _script,
        look: _look(s), header: s.mushafHeaderShown, page: p, compact: compact);
    final r = fit(first, avail), l = fit(first + 1, avail);
    final h = r.height < l.height ? r.height : l.height;
    return fit(page, Size(avail.width, h));
  }

  /// The two facing pages from [first] (right) and [first] + 1 (left);
  /// with a [gap], a line down its middle, and with a [rail], each page's
  /// margin on its outer side.
  Widget _spreadRow(int first, Size avail, AppSettings s, MushafPaper paper,
      {bool compact = false, double rail = 0, double gap = 0}) {
    final left = first + 1;
    final rb = _spreadBoxOf(first, avail, s, compact: compact);
    final lb =
        left <= _total ? _spreadBoxOf(left, avail, s, compact: compact) : rb;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (rail > 0)
        SizedBox(
            width: rail,
            height: rb.height,
            child: left <= _total ? _hifzRail(left, paper, rail) : null),
      SizedBox(
        width: lb.width,
        height: rb.height,
        child: left <= _total
            ? _pageView(left, s, paper, spine: 'left', compact: compact)
            : const SizedBox(),
      ),
      if (gap > 0)
        SizedBox(
          width: gap,
          height: rb.height,
          child: Center(
              child: SizedBox(
                  width: 1, height: rb.height, child: ColoredBox(color: paper.line))),
        ),
      SizedBox(
          width: rb.width,
          height: rb.height,
          child: _pageView(first, s, paper, spine: 'right', compact: compact)),
      if (rail > 0)
        SizedBox(width: rail, height: rb.height, child: _hifzRail(first, paper, rail)),
    ]);
  }

  Widget _stage(BuildContext context, AppSettings s, MushafPaper paper,
      String view, int first) {
    // Edge to edge: the page reaches the window's edges (the arrows aside).
    final edge = _look(s).edge;
    final pad = edge ? 0.0 : (_chrome ? 24.0 : 14.0);
    final arrows = _chrome ? 60.0 : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: edge ? paper.paper : paper.bg,
        gradient: s.useGradients && !edge
            ? RadialGradient(
                radius: .9,
                colors: [paper.paper.withValues(alpha: .13), paper.bg])
            : null,
      ),
      child: LayoutBuilder(builder: (context, c) {
        // Memorizing: the bar stands at the right edge, the pages keep
        // their full height. Review and marking: room kept under the pages
        // for their bar, so it doesn't cover the last lines.
        final side = _memorizing ? _sideBarW : 0.0;
        final availW =
            (c.maxWidth - 2 * pad - 2 * arrows - side).clamp(200.0, 1e9);
        final room = _barShown && !_memorizing ? _barH + 20 : 0.0;
        final availH = (c.maxHeight - 2 * pad - room).clamp(200.0, 1e9);
        // Pages take their scanned shape (MushafGeometry.pageRatio), or, without
        // one, share one box sized from the text.
        Size box(Size avail, int page,
                {double? heightBudget, bool byWidthOnly = false}) =>
            MushafGeometry.pageBox(avail, _script,
                look: _look(s),
                header: s.mushafHeaderShown,
                page: page,
                heightBudget: heightBudget,
                byWidthOnly: byWidthOnly);
        Widget content;
        if (view == 'spread') {
          final avail = Size(availW / 2, availH);
          mushafPageBoxOf = (p) => _spreadBoxOf(p, avail, s);
          content = Container(
            key: ValueKey('spread-$first-$_script'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: qShadows(context, const [
                // Soft but cheap: a 60px blur was costly to repaint on weak
                // GPUs for little visible difference.
                BoxShadow(
                    color: Color(0x5C281E0A),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                    spreadRadius: -10),
              ]),
            ),
            child: _spreadRow(first, avail, s, paper),
          );
        } else {
          Size boxOf(int p) => view == 'fill'
              ? box(Size(availW, availH), p, byWidthOnly: true)
              : box(Size(availW, availH), p, heightBudget: availH * 1.6);
          mushafPageBoxOf = boxOf;
          final b = boxOf(_page);
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
              padding: EdgeInsets.fromLTRB(pad, pad, pad + side, pad + room),
              child: Center(
                child: noMotion(context) ? content : AnimatedSwitcher(
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
          if (_memorizing) ...[
            Positioned(
              top: 8,
              bottom: 8,
              right: 8,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _memorizeBar(paper, floating: true, vertical: true),
                ),
              ),
            ),
            if (s.memorizePad)
              Positioned(
                bottom: 12,
                left: 0,
                right: side,
                child: _withPad(paper, const SizedBox.shrink()),
              ),
          ] else if (_reviewing)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: _measured(_reviewBar(paper, floating: true))),
            )
          else if (_marking.active)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: _measured(_markingBar(paper, floating: true))),
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
              right: pad + side,
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
              right: 16 + side,
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
            ? qShadows(context, const [
                BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -8),
              ])
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
  final ScrollController? controller;
  final String script;
  final ValueChanged<String> onScript;

  /// Starts a review of the marks (null: no mark book to review).
  final VoidCallback? onReview;

  /// Starts memorizing from the page in view.
  final VoidCallback? onMemorize;

  /// Memorizing from a sūrah, juzʼ, page… chosen in the index.
  final VoidCallback? onMemorizeFrom;

  /// The same, as verse cards.
  final VoidCallback? onMemorizeCards;
  const _MushafSettingsSheet(
      {required this.controller,
      required this.script,
      required this.onScript,
      this.onReview,
      this.onMemorize,
      this.onMemorizeFrom,
      this.onMemorizeCards});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Text(context.l10n.mushafSettings, style: displayStyle(context, size: 24)),
        const SizedBox(height: 12),
        QGroup(children: [
          if (onMemorize != null)
            QRow(
              leading: Icon(AppIcons.memorize, color: pal(context).acc),
              title: context.l10n.mzStart,
              subtitle: context.l10n.mzStartSub,
              chevron: true,
              onTap: onMemorize,
            ),
          if (onMemorizeFrom != null)
            QRow(
              leading: Icon(AppIcons.indexList, color: pal(context).acc),
              title: context.l10n.mzStartFrom,
              subtitle: context.l10n.mzStartFromSub,
              chevron: true,
              onTap: onMemorizeFrom,
            ),
          if (onMemorizeCards != null)
            QRow(
              leading: Icon(AppIcons.cards, color: pal(context).acc),
              title: context.l10n.mzStartCards,
              subtitle: context.l10n.mzStartCardsSub,
              chevron: true,
              onTap: onMemorizeCards,
            ),
          QRow(
            title: context.l10n.fcFocus,
            subtitle: context.l10n.fcFocusSub,
            control: QSwitch(
                value: s.focusMode,
                onChanged: (v) => s.update(() => s.focusMode = v)),
          ),
          ...memorizeTapRows(context, s),
          if (onReview != null)
            QRow(
              leading: Icon(AppIcons.review, color: pal(context).acc),
              title: context.l10n.rvSetupTitle,
              chevron: true,
              onTap: onReview,
            ),
        ]),
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
            title: context.l10n.tajwidColors,
            control: QSwitch(
                value: s.mushafTajwid,
                onChanged: (v) => s.update(() => s.mushafTajwid = v)),
          ),
          if (kMushafCustomization) ...[
          QRow(
            title: context.l10n.pageHeader,
            control: QSwitch(
                value: s.mushafHeader,
                onChanged: (v) => s.update(() => s.mushafHeader = v)),
          ),
          QRow(
            title: context.l10n.msEdgeToEdge,
            subtitle: context.l10n.msEdgeToEdgeSub,
            control: QSwitch(
                value: s.styleFor(script).edge,
                onChanged: (v) => s.update(() => s.styleFor(script).edge = v)),
          ),
          ],
          if (MarksScope.maybeOf(context)?.activeBook != null)
            QRow(
              leading: Icon(AppIcons.link, color: pal(context).acc),
              title: context.l10n.mtTitle,
              subtitle: context.l10n.mtTitleSub,
              chevron: true,
              onTap: () => pushAdaptive(context, const MutashabihatScreen()),
            ),
          // Customisation (off for now, kMushafCustomization).
          if (kMushafCustomization) ...[
          QRow(
            title: context.l10n.msTitle,
            subtitle: context.l10n.msTitleSub,
            chevron: true,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const MushafStyleScreen())),
          ),
          // Quick switches; every ornament is on the style screen above.
          QRow(
            title: context.l10n.pageBorder,
            subtitle: context.l10n.pageBorderSub,
            control: QSwitch(
                value: s.orBorder != 'none',
                onChanged: (v) =>
                    s.update(() => s.orBorder = v ? 'auto' : 'none')),
          ),
          QRow(
            title: context.l10n.marginInfo,
            control: QSwitch(
                value: s.orMargin != 'none',
                onChanged: (v) =>
                    s.update(() => s.orMargin = v ? 'auto' : 'none')),
          ),
          ],
          QRow(
            title: context.l10n.liteMode,
            subtitle: context.l10n.liteModeSub,
            control: QSwitch(
                value: s.lite, onChanged: (v) => s.update(() => s.lite = v)),
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

/// One muṣḥaf page drawn as the muṣḥaf draws it, for previewing its look
/// (the style screen): the current settings' paper, ornaments, border and
/// margin (focus mode aside), fitted to the space. It takes no taps.
class MushafPagePreview extends StatelessWidget {
  final String script;
  final int page;
  final Map<int, String> names;
  const MushafPagePreview(
      {super.key, required this.script, required this.page, required this.names});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final paper = mushafPaperOf(s, script);
    final look = s.mushafLook(script, focus: false);
    return LayoutBuilder(builder: (context, c) {
      final box = MushafGeometry.pageBox(c.biggest, script,
          look: look, header: s.mushafHeader, page: page);
      return Center(
        child: IgnorePointer(
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: _MushafPageView(
              page: page,
              script: script,
              names: names,
              paper: paper,
              look: look,
              wideLayout: false,
              showHeader: s.mushafHeader,
              playAyah: -1,
              playWord: -1,
              reciting: false,
              handlers: MushafTapHandlers(),
              tajwid:
                  s.mushafTajwid ? tajwidColorsForDark(paper.dark) : null,
            ),
          ),
        ),
      );
    });
  }
}

class _MushafPageView extends StatelessWidget {
  final int page;
  final String script;
  final Map<int, String> names;
  final MushafPaper paper;
  final MushafLook look;
  final bool wideLayout;
  final bool showHeader;
  final EdgeInsets margin;

  /// On a desktop spread: which side of this page is the spine ('left' or
  /// 'right'), whose corners stay square.
  final String? spine;
  final int playAyah;
  final int playWord;
  final bool reciting;

  /// Word marks to draw, by [WordRef.key] (word 0 = the āyah's ۝): the
  /// lines follow them as they change.
  final MushafMarksSource? marks;

  /// A soft shade along the spine (a desktop spread with gradients on).
  final bool shade;
  final MarkPalette? markPal;
  final MushafTapHandlers handlers;

  /// Tajwīd rule colours, when the page shows tajwīd.
  final List<Color>? tajwid;

  /// The phone's two-page spread: thinner padding, page number in the head.
  final bool compact;

  /// The word in focus on this page ([WordRef.key]), or -1.
  final int focus;

  /// Memorize: the first hidden token on this page, or -1.
  final int hideFrom;
  const _MushafPageView({
    required this.page,
    required this.script,
    required this.names,
    required this.paper,
    required this.look,
    required this.wideLayout,
    required this.showHeader,
    this.margin = EdgeInsets.zero,
    this.spine,
    required this.playAyah,
    required this.playWord,
    required this.reciting,
    this.marks,
    this.shade = false,
    this.markPal,
    required this.handlers,
    this.tajwid,
    this.compact = false,
    this.focus = -1,
    this.hideFrom = -1,
  });

  @override
  Widget build(BuildContext context) {
    PerfLog.pageBuilt();
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
    // Edge to edge: a pixel inside the paper's hair of padding.
    final innerPad = look.edge
        ? const EdgeInsets.all(1)
        : compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    // The page border (its own choice): none, one or two thin rules, or an
    // artwork border, the text set inside it on the paper's inner colour.
    Widget framed(Widget child, double fs) => MushafPageBorder(
          kind: look.border,
          band: look.borderBand(fs),
          frame: paper.frame,
          cut: paper.inner ?? paper.paper,
          hairline: paper.paper,
          inner: look.artBorder ? paper.inner : null,
          padding: look.artBorder
              ? EdgeInsets.all(MushafGeometry.classicGap(fs)) + innerPad
              : innerPad,
          mono: paper.mono,
          dark: paper.dark,
          child: child,
        );

    return LayoutBuilder(builder: (context, outer) {
      final pageW = outer.maxWidth - margin.horizontal;
      final roomy = pageW > MushafGeometry.roomyWidth;
      final spineShade = spine == null || !shade
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
      // The artwork border, the margins and the edges follow the page's
      // font size.
      final fs = look.scalesChrome
          ? MushafGeometry.fontFor(pageW, script, look, compact: compact)
          : 0.0;
      final gap = look.tune['lanternGap'] * fs;
      final band = look.sideBand
          ? MushafGeometry.lanternBand(fs, look.tune['lanternGap'])
          : 0.0;
      final basePad = look.edge
          ? const EdgeInsets.all(MushafGeometry.edgePad)
          : roomy
          ? const EdgeInsets.fromLTRB(22, 18, 22, 10)
          : (compact
              ? const EdgeInsets.fromLTRB(4, 4, 4, 3)
              : const EdgeInsets.fromLTRB(6, 6, 6, 4));
      final padding = basePad + EdgeInsets.symmetric(horizontal: band);
      // How the running head is set: a line inside the frame, white boxes
      // on it (Madani), or along it outside (Indo-Pak).
      final head = !showHeader || look.edge
          ? 'none'
          : look.headOnFrame
              ? 'frame'
              : look.headOnEdges
                  ? 'edges'
                  : 'inside';
      final juz = MushafRepo.juzOfPage(script, page);
      // The outer side: right of an odd page, left of an even one.
      final outerRight = page.isOdd;
      final small = fs * .55 < 9 ? 9.0 : fs * .55;

      // The 'text' margin: the juzʼ (Indo-Pak: the para) written along the
      // frame on the inner side.
      Widget sideLabel(Widget child) {
        if (look.margin != 'text' || band <= 0) return child;
        final label = script == 'indopak'
            ? '${indopakParaName(juz)}  ${_ar(juz)}'
            : madaniJuzName(juz);
        return Stack(children: [
          child,
          Positioned.fill(
            child: Padding(
              padding: basePad,
              child: Align(
                alignment: Alignment(outerRight ? -1 : 1, 0),
                child: SizedBox(
                  width: band - gap,
                  child: Center(
                    child: EdgeLabel(
                      text: label,
                      size: small,
                      color: paper.ink,
                      quarterTurns: outerRight ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }

      // The Madani running head: the sūrah and the juzʼ in white boxes on
      // the frame's top band.
      Widget onFrame(Widget framedChild) {
        if (head != 'frame') return framedChild;
        final t = look.borderBand(fs);
        final v = MushafRepo.firstVerseOfPage(script, page);
        final boxH = small * 1.3 + 4;
        // The words in the Quran's script; a number in Naskh (the Quran
        // font draws digits as āyah markers).
        Widget box(String text, [int? n]) => Container(
              height: boxH,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: small * .8),
              decoration: BoxDecoration(
                color: paper.inner ?? paper.paper,
                border: Border.all(
                    color: paper.ink.withValues(alpha: .65), width: .8),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: text),
                    if (n != null)
                      TextSpan(
                          text: ' ${_ar(n)}',
                          style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic', height: 1.1)),
                  ]),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: small,
                      height: 1.25,
                      color: paper.ink)),
            );
        return Stack(
            clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
          framedChild,
          Positioned(
            top: t / 2 - boxH / 2,
            left: t * 6,
            child: box('سورة ${names[v.$1] ?? ''}', v.$1),
          ),
          Positioned(
            top: t / 2 - boxH / 2,
            right: t * 6,
            child: box(madaniJuzName(juz)),
          ),
        ]);
      }

      // The Indo-Pak edges: para · page · sūrah above the frame, the
      // manzil below it.
      final strip = MushafGeometry.edgeStrip(fs);
      TextStyle edgeStyle() => TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: small,
          height: 1.3,
          color: paper.ink);
      Widget topStrip() => SizedBox(
            height: strip,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Expanded(
                  child: Text(
                    [
                      for (final s in surahsOn(lines))
                        '${names[s] ?? ''} ${_ar(s)}',
                    ].join(' ـ '),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: edgeStyle(),
                  ),
                ),
                Text(_ar(page), style: edgeStyle()),
                Expanded(
                  child: Text(
                    '${indopakParaName(juz)}  ${_ar(juz)}',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: edgeStyle(),
                  ),
                ),
              ]),
            ),
          );
      Widget bottomStrip() {
        final (s, a) = MushafRepo.firstVerseOfPage(script, page);
        return SizedBox(
          height: strip,
          child: Center(
            child: Text('منزل ${_ar(manzilOf(s, a))}',
                textDirection: TextDirection.rtl, style: edgeStyle()),
          ),
        );
      }

      // Edge to edge: just the paper, square (its border kept, unseen, so
      // the geometry holds).
      final decoration = BoxDecoration(
        color: paper.paper,
        borderRadius: look.edge ? null : radius,
        border: Border.all(
            color: look.edge ? paper.paper : paper.line),
      );
      final foreground = spineShade == null
          ? null
          : BoxDecoration(borderRadius: radius, gradient: spineShade);
      final pageNumber = (head == 'inside' || head == 'frame') && !compact
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_ar(page),
                  textDirection: TextDirection.rtl,
                  style: arabicStyle(context,
                      size: 13, height: 1.3, color: paper.sub)),
            )
          : null;
      // Headers reach the frame's inner edge: past the text by the inner
      // padding (and an artwork border's gap).
      final bleed = look.border == 'none'
          ? 0.0
          : innerPad.horizontal / 2 +
              (look.artBorder ? MushafGeometry.classicGap(fs) : 0);
      final innerW = pageW - padding.horizontal;
      // Isolates the word grid's paint layer from the page frame around it:
      // every recitation word-highlight tick repaints this subtree, and
      // without this boundary the frame would be redrawn on every tick even
      // though its own inputs never change.
      Widget grid(double? height) => RepaintBoundary(
            child: LayoutBuilder(builder: (context, c) {
              final vh = height ?? c.maxHeight;
              if (height == null) {
                mushafChrome = Size(
                    outer.maxWidth - margin.horizontal - c.maxWidth,
                    outer.maxHeight - margin.vertical - vh);
              }
              return _grid(context, lines, c.maxWidth, vh,
                  bleed: bleed,
                  // From the text's edge to the margin band's.
                  toBand: (innerW - c.maxWidth) / 2,
                  band: band,
                  gap: gap,
                  fs: fs,
                  outerRight: outerRight);
            }),
          );
      Widget inFrame(Widget g) => onFrame(framed(
          Column(children: [
            if (head == 'inside') _pageHeader(context),
            g,
          ]),
          fs));

      if (wideLayout) {
        // A short-and-wide viewport (phone landscape): the page is laid out
        // to the full width and runs as tall as its text — paper, frame and
        // all — and scrolls as a whole, like a zoomed-in page rather than a
        // window onto one. Flutter desktop only drags scrollables with touch
        // by default; mouse and trackpad can pan it too.
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          }),
          child: SingleChildScrollView(
            padding: margin.copyWith(bottom: margin.bottom + 12),
            child: sideLabel(Container(
              decoration: decoration,
              foregroundDecoration: foreground,
              padding: padding,
              child: Column(
                children: [
                  if (head == 'edges' && look.edgeTop) topStrip(),
                  inFrame(grid(0)),
                  if (head == 'edges' && look.edgeBottom) bottomStrip(),
                  ?pageNumber,
                ],
              ),
            )),
          ),
        );
      }

      return Padding(
        padding: margin,
        child: sideLabel(Container(
          decoration: decoration,
          foregroundDecoration: foreground,
          padding: padding,
          child: Column(
            children: [
              if (head == 'edges' && look.edgeTop) topStrip(),
              Expanded(child: inFrame(Expanded(child: grid(null)))),
              if (head == 'edges' && look.edgeBottom) bottomStrip(),
              ?pageNumber,
            ],
          ),
        )),
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
            if (compact)
              Expanded(
                child: Text(_ar(page),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: arabicStyle(context,
                        size: 13, height: 1.3, color: paper.sub)),
              ),
            Text(context.l10n.juzOnly(juz),
                style: uiStyle(context,
                    size: 11.5, weight: FontWeight.w600, color: paper.sub)),
          ],
        ),
      ),
    );
  }

  /// The page's lines in a [vw] × [vh] text area, and — set out from them
  /// into the outer margin ([toBand] from the text's edge to the margin
  /// band, [band] wide, its first [gap] kept clear of the frame) — the
  /// ḥizb-quarter lanterns and rukūʿ marks level with their lines. Sūrah
  /// headers reach [bleed] past the text, to the frame.
  Widget _grid(BuildContext context, List<MushafLine> lines, double vw,
      double vh,
      {double bleed = 0,
      double toBand = 0,
      double band = 0,
      double gap = 0,
      double fs = 0,
      bool outerRight = true}) {
    final ink = paper.ink;
    // A short-and-wide viewport (phone landscape) lays the page out to the
    // FULL width and lets it run taller than the viewport (see _page, which
    // scrolls it); [vh] is 0 then.
    final fitWidth = wideLayout;
    mushafLastViewport = (Size(vw, vh), fitWidth);
    final (textFs, slotH, contentH) =
        mushafPageGeometry(script, page, lines, vw, vh, fitWidth: fitWidth);
    if (kMushafPerf) PerfLog.pageFontSize = textFs;
    final opening = mushafOpeningPage(page, lines);
    // Each row and the slots it spans: the Indo-Pak sūrah header takes a
    // heading and the basmala under it together, in its two tiers.
    final rows = <(int, Widget)>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      // A header runs out to the frame.
      Widget wide(Widget child) => bleed <= 0
          ? child
          : OverflowBox(
              maxWidth: vw + 2 * bleed,
              minWidth: vw + 2 * bleed,
              child: child);
      if (look.header == 'indopak' &&
          l.isHeader &&
          i + 1 < lines.length &&
          lines[i + 1].isBasmala) {
        rows.add((2, wide(_twoTierHeader(context, l, slotH))));
        i++;
        continue;
      }
      if (l.isHeader) {
        rows.add((
          1,
          Center(
              child: wide(_slot(
                  context, i, l, textFs, vw + 2 * bleed, slotH, ink))),
        ));
        continue;
      }
      rows.add((
        1,
        Center(
            child: _slot(context, i, l, textFs, vw, slotH, ink,
                justify: !opening)),
      ));
    }

    // Where line [i]'s middle is, down the text area.
    final lineCount = lines.length;
    double lineY(int i) => opening
        ? (contentH - lineCount * slotH) / 2 + (i + .5) * slotH
        : (i + .5) * contentH / lineCount;
    // The outer margin's marks, each [w] wide, at the band's outer side
    // (away from the frame).
    Positioned outerMark(int line, double w, double h, Widget child) =>
        Positioned(
          left: outerRight
              ? vw + toBand + band - w - 2
              : -(toBand + band) + 2,
          top: lineY(line) - h / 2,
          width: w,
          height: h,
          child: child,
        );
    final marks = <Widget>[
      if (look.lantern && band > 0)
        for (final (q, line) in hizbQuartersOn(lines))
          _lanternAt(outerMark, line, q, band, gap),
      if (look.headOnEdges && look.edgeRuku && band > 0)
        for (final (line, number, ayahs) in rukuEndsOn(lines))
          outerMark(
            line,
            band - gap,
            fs * 1.9,
            _RukuMark(
                number: number, ayahs: ayahs, size: fs * .5, ink: paper.ink),
          ),
    ];

    final pageBody = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        height: contentH,
        width: vw,
        // The opening pages: their few lines close together in the middle.
        child: opening
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (n, w) in rows)
                    SizedBox(height: slotH * n, child: w),
                ],
              )
            : Column(
                children: [
                  for (final (n, w) in rows) Expanded(flex: n, child: w),
                ],
              ),
      ),
    );
    if (marks.isEmpty) return pageBody;
    return Stack(clipBehavior: Clip.none, children: [pageBody, ...marks]);
  }

  /// A ḥizb-quarter lantern ([quarter] 1…240) level with [line], in ink.
  Widget _lanternAt(
      Positioned Function(int, double, double, Widget) at,
      int line,
      int quarter,
      double band,
      double gap) {
    final art =
        look.margin == 'lantern2' ? ClassicArt.lantern2 : ClassicArt.lantern1;
    final w = (band - gap) * .9 * look.tune['lanternScale'];
    return at(
      line,
      w,
      w / art.ratio,
      MarginLantern(
        kind: look.margin,
        width: w,
        text: hizbQuarterText(quarter),
        ink: paper.ink,
        fill: paper.inner,
      ),
    );
  }

  /// The sūrah's name for its header: in an Indo-Pak header, "sūrah" and
  /// its name in the Indo-Pak muṣḥaf's own font; otherwise its glyph in the
  /// SurahNames font (large; headers scale it down to fit), else its name.
  Widget _surahTitle(BuildContext context, MushafLine l, {double size = 60}) {
    if (look.header == 'indopak') {
      return Text(
        'سُوْرَةُ ${names[l.surah] ?? ''}',
        textDirection: TextDirection.rtl,
        style: TextStyle(
            fontFamily: MushafRepo.fontFamily('indopak'),
            fontSize: size,
            height: 1.6,
            color: paper.ink),
      );
    }
    final glyph = (l.surah >= 1 && l.surah <= surahGlyphCodes.length)
        ? surahGlyphCodes[l.surah - 1]
        : null;
    return Text(
      glyph == null
          ? (names[l.surah] ?? '')
          : String.fromCharCodes([glyph, 0xe903]),
      textDirection: TextDirection.rtl,
      style: glyph == null
          ? quranicStyle(context, size: size * .66, color: paper.ink)
          : TextStyle(fontFamily: 'SurahNames', fontSize: size, color: paper.ink),
    );
  }

  /// The Indo-Pak header's side cartouches, as its muṣḥafs print them:
  /// the sūrah's āyāt (right) and rukūʿ (left).
  (Widget, Widget) _surahCounts(MushafLine l) {
    // The words in the Indo-Pak muṣḥaf's font; the number in Naskh (that
    // font draws digits as its āyah-number marks).
    Text t(String words, int n) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '$words '),
            TextSpan(
                text: _ar(n),
                style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic', height: 1.2)),
          ]),
          textDirection: TextDirection.rtl,
          style: TextStyle(
              fontFamily: MushafRepo.fontFamily('indopak'),
              fontSize: 40,
              height: 1.6,
              color: paper.ink),
        );
    return (
      t('اٰيَاتُهَا', MushafRepo.ayahCountOf(l.surah)),
      t('رُكُوْعُهَا', rukuCountOf(l.surah)),
    );
  }

  /// The Indo-Pak two-tier sūrah header over a heading and its basmala.
  Widget _twoTierHeader(BuildContext context, MushafLine l, double slotH) =>
      IndopakTwoTierHeader(
        rowHeight: slotH,
        title: _surahTitle(context, l),
        sides: _surahCounts(l),
        frame: paper.frame,
        ink: paper.ink,
        fill: paper.inner,
        tune: look.tune,
      );

  Widget _slot(BuildContext context, int index, MushafLine l, double fs,
      double targetW, double slotH, Color ink, {bool justify = true}) {
    if (l.isHeader) {
      final glyph = (l.surah >= 1 && l.surah <= surahGlyphCodes.length)
          ? surahGlyphCodes[l.surah - 1]
          : null;
      return SizedBox(
        width: targetW,
        child: MushafSurahHeader(
          kind: look.header,
          lineHeight: slotH,
          title: _surahTitle(context, l),
          sides: look.header == 'indopak' ? _surahCounts(l) : null,
          mono: paper.mono,
          dark: paper.dark,
          plainTitle: glyph == null
              ? (names[l.surah] ?? '')
              : String.fromCharCodes([glyph, 0xe903]),
          plainStyle: glyph == null
              ? quranicStyle(context, size: slotH * .5)
              : TextStyle(fontFamily: 'SurahNames', fontSize: slotH * .62),
          frame: paper.frame,
          paper: paper.paper,
          soft: paper.soft,
          // Update 9: sūrah names in the page's ink.
          ink: paper.ink,
          fill: paper.inner,
          tune: look.tune,
        ),
      );
    }
    if (l.isBasmala) {
      // As printed: most of the line's height, at most 60% of its width.
      return SizedBox(
        width: targetW * .6,
        height: slotH,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(MushafRepo.bismillahChar,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'Bismillah',
                  fontSize: slotH * .62 * look.tune['basmalaScale'],
                  height: 1,
                  color: ink)),
        ),
      );
    }
    final marker = markerOf(look, paper);
    return MushafLineView(
      handlers: handlers,
      marks: marks,
      spec: MushafLineSpec(
        script: script,
        page: page,
        index: index,
        line: l,
        fontSize: fs,
        slotH: slotH,
        targetW: targetW,
        ink: ink,
        accent: paper.acc,
        strongBg: paper.hl2,
        verseBg: paper.hl,
        playAyah: playAyah,
        playWord: playWord,
        reciting: reciting,
        marks: marks?.visuals ?? const {},
        markPal: markPal,
        tajwid: tajwid,
        focus: focus,
        hideFrom: hideFrom,
        justify: justify,
        ornament: marker.color,
        ornamentFill: marker.fill,
        markerArt: marker.art,
        markerScale: marker.scale,
        markerDy: marker.dy,
      ),
    );
  }
}

/// The Indo-Pak margin's rukūʿ mark, where a rukūʿ ends: «ع» with the
/// rukūʿ's number in its sūrah above and its count of āyāt below.
class _RukuMark extends StatelessWidget {
  final int number, ayahs;
  final double size;
  final Color ink;
  const _RukuMark(
      {required this.number,
      required this.ayahs,
      required this.size,
      required this.ink});

  @override
  Widget build(BuildContext context) {
    TextStyle st(double k) => TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontSize: size * k,
        height: 1.05,
        color: ink);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_ar(number), style: st(.8)),
        Text('ع', style: st(1.3).copyWith(fontWeight: FontWeight.w700)),
        Text(_ar(ayahs), style: st(.8)),
      ]),
    );
  }
}

/// How a page's āyah markers are drawn on the atlas path: the traced
/// circle's colour (null: the font's own), hole fill, art and tuning.
({Color? color, Color? fill, String art, double scale, double dy}) markerOf(
    MushafLook look, MushafPaper paper) {
  if (look.marker == 'font') {
    return (color: null, fill: null, art: 'madani', scale: 1, dy: 0);
  }
  final c = ClassicCircle.of(look.marker);
  return (
    color: paper.frame,
    fill: paper.inner,
    art: c.art,
    scale: look.tune[c.scaleKey],
    dy: look.tune[c.dyKey],
  );
}

/// Reports its child's height after each layout that changes it.
class _ReportHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onHeight;
  const _ReportHeight({required this.onHeight, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
          BuildContext context, _RenderReportHeight renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  ValueChanged<double> onHeight;
  double? _last;
  _RenderReportHeight(this.onHeight);

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    // Not during layout: the host rebuilds with the room for it.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}
