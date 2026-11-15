import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio.dart';
import '../../core/follow/follow_session.dart';
import '../../core/keymap.dart';
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/qc_words.dart';
import '../../core/marks/word_ref.dart';
import '../../core/memorize.dart';
import '../../core/recite_back.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../follow/follow_ui.dart';
import '../marks/marking.dart';
import '../marks/marking_bar.dart' show kMarkPens;
import '../marks/word_marks_sheet.dart';
import '../marks/word_menu.dart';
import '../mushaf_screen.dart';
import 'memorize_bar.dart';
import 'mushaf_line.dart';
import 'verse_view.dart';

/// Memorize as verse cards: one āyah at a time, in large writing, revealed
/// word by word — for those who don't keep to the page. It walks the same
/// [MemorizeController] as the muṣḥaf page, so the two views swap without
/// losing the place. The āyah is drawn from the glyph atlas: hidden words
/// are left out of the sprite lists; a revealed word's marks come with it.
class MemorizeCardsScreen extends StatefulWidget with DesktopAware {
  final MemorizeController controller;

  /// Opened from the muṣḥaf (going back returns to it); otherwise "Muṣḥaf
  /// page" opens one in its place.
  final bool fromMushaf;

  /// Opened from the Reader: there's no page to switch to, and leaving stops
  /// and goes back to it.
  final bool fromReader;
  const MemorizeCardsScreen({
    super.key,
    required this.controller,
    this.fromMushaf = false,
    this.fromReader = false,
  });

  @override
  State<MemorizeCardsScreen> createState() => _MemorizeCardsScreenState();
}

class _MemorizeCardsScreenState extends State<MemorizeCardsScreen> {
  final _handlers = MushafTapHandlers();
  Map<int, String> _tnames = {};
  bool _ready = false;
  bool _warnedTimings = false;
  bool _switching = false;

  MemorizeController get _c => widget.controller;
  String get _script => _c.script;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _c.cards = true;
    _handlers
      ..onTapWord = _tapWord
      ..onTapVerse = _tapVerse
      ..onLongPressWord = _hold
      // Holding a revealed ۝: the whole āyah's sheet.
      ..onLongPressVerse = _hold
      // Desktop: the muṣḥaf's mouse (Shift+click, wheel click, right-click…)
      // on a word that shows.
      ..onMouseWord = _mouse;
    _marking.addListener(_changed);
    FollowSession.instance.word.addListener(_heard);
    FollowSession.instance.status.addListener(_followStatus);
    _load();
  }

  Future<void> _load() async {
    await MushafRepo.ensure(_script);
    await MushafAtlas.load(_script, MushafRepo.tokensSync(_script));
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    setState(() {
      _tnames = {for (final m in metas) m.n: m.tname};
      _ready = true;
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _followCard();
  }

  // ── the scrolling view ──

  /// The āyah it was opened on: the list starts there.
  late final int _firstAyah = _c.viewAyah;
  final _scroll = ScrollController();
  final _currentCard = GlobalKey();
  int? _followed;

  /// Desktop keeps to one card, one word at a time.
  bool get _scrolling =>
      !useDesktop(context) &&
      SettingsScope.of(context).memorizeCardsView != 'single';

  /// Marks made here (the mouse, the menu), for undo and redo.
  final _marking = MarkingController();

  bool _mouse(MushafWord wd, int buttons, Offset at) {
    if (!_shows(wd)) return false;
    final ref = WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx);
    return wordMouse(
      context,
      ref,
      buttons,
      _marking,
      menu: () => showWordMenu(
        context,
        at,
        ref: ref,
        script: _script,
        onEdit: _marking.recordOp,
        onFluency: _marking.recordStep,
        onComment: () => _hold(wd),
        onPlay: () => wd.isMarker ? _tapVerseAudio(wd.ayah) : _playWord(wd),
        onMore: () => _hold(wd),
      ),
    );
  }

  /// The keys: the muṣḥaf's memorize keys (Space the next word, Backspace
  /// back one), and its marking keys.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final down = e is KeyDownEvent;
    final s = SettingsScope.of(context);
    final km = s.keymap;
    bool hit(KeyAction a) => km.matches(a, e);
    KeyEventResult did(VoidCallback f) {
      f();
      return KeyEventResult.handled;
    }

    if (hit(KeyAction.memoNextVerse)) return did(_c.nextVerse);
    if (hit(KeyAction.memoNextWord)) return did(_c.nextWord);
    if (hit(KeyAction.memoPrevVerse)) return did(_c.prevVerse);
    if (hit(KeyAction.memoPrevWord)) return did(_c.prevWord);
    if (!down) return KeyEventResult.ignored;
    if (hit(KeyAction.memoNextPage)) return did(_c.nextPage);
    if (hit(KeyAction.memoPlay)) return did(_play);
    if (hit(KeyAction.memoPlayPage)) return did(() => _play(withBefore: true));
    if (hit(KeyAction.redo) && _marking.canRedo) {
      return did(() => _marking.redo(context));
    }
    if (hit(KeyAction.undo) && _marking.canUndo) {
      return did(() => _marking.undo(context));
    }
    if (useDesktop(context)) {
      const pens = [
        KeyAction.pen1,
        KeyAction.pen2,
        KeyAction.pen3,
        KeyAction.pen4,
        KeyAction.pen5,
      ];
      for (final (i, a) in pens.indexed) {
        if (hit(a)) {
          return did(
            () => s.update(() {
              s.markMethod = 'pen';
              s.markPen = kMarkPens[i].code;
            }),
          );
        }
      }
    }
    if (hit(KeyAction.leave)) return did(_end);
    return KeyEventResult.ignored;
  }

  /// The word just revealed (the last showing word of the āyah in view), or
  /// null with the card still blank.
  String? _currentWord() {
    var t = _c.revealedEnd - 1;
    if (t < 0) return null;
    var (g, w) = MushafRepo.tokenAt(_script, t);
    if (w < 0) {
      if (--t < 0) return null;
      (g, w) = MushafRepo.tokenAt(_script, t);
    }
    if (g != _c.viewAyah || w < 0) return null;
    return MushafRepo.wordText(_script, g, w);
  }

  /// Desktop: the word just revealed, large, under the card.
  Widget _wordPanel(AppSettings s, MushafPaper paper) {
    final w = _currentWord();
    return Container(
      key: const ValueKey('memo-word'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      constraints: BoxConstraints(minHeight: s.memorizeCardFont * 2.4),
      decoration: BoxDecoration(
        color: paper.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paper.line, width: 1.5),
      ),
      alignment: Alignment.center,
      child: w == null
          ? const SizedBox.shrink()
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                w,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: MushafRepo.fontFamily(_script),
                  fontSize: s.memorizeCardFont * 1.8,
                  height: 1.9,
                  color: paper.ink,
                ),
              ),
            ),
    );
  }

  /// Keeps the card being revealed in view: a new one comes a quarter of the
  /// way down, with the last still above it; one growing is only kept on
  /// screen.
  void _followCard() {
    if (!_scrolling) return;
    final g = _c.viewAyah;
    final isNew = g != _followed;
    _followed = g;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _currentCard.currentContext;
      if (ctx == null) {
        // Not built yet, far below: to the list's end, then look again.
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          _followed = null;
          _followCard();
        }
        return;
      }
      final d = motion(context, const Duration(milliseconds: 240));
      if (isNew) {
        Scrollable.ensureVisible(
          ctx,
          alignment: .25,
          duration: d,
          curve: Curves.easeOut,
        );
      } else {
        Scrollable.ensureVisible(
          ctx,
          duration: d,
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  // ── reveal as I recite (Follow my recitation) ──

  bool _listening = false;

  Future<void> _listen() async {
    final fs = FollowSession.instance;
    if (_listening) {
      setState(() => _listening = false);
      if (identical(fs.owner, this)) await fs.stop();
      return;
    }
    if (_c.atEnd) return;
    // (Not waited for: listening needn't wait on the player.)
    ReciteBack.instance.stop();
    final (g, w) = MushafRepo.tokenAt(_script, _c.nextHiddenWord);
    setState(() => _listening = true);
    final ok = await startFollow(context, this, g, w < 0 ? 0 : w);
    if (mounted && !ok) setState(() => _listening = false);
  }

  /// A word heard: shown, with what's before it — but not a jump far on
  /// (a look-alike misheard): it's told where they are instead.
  void _heard() {
    if (!mounted || !_listening) return;
    final place = FollowSession.instance.place;
    if (place == null) return;
    final t = MushafRepo.tokenOf(_script, place.$1, place.$2);
    if (t < _c.revealedEnd) return;
    if (t > _c.revealedEnd + 30) {
      final (g, w) = MushafRepo.tokenAt(_script, _c.nextHiddenWord);
      FollowSession.instance.setPosition(g, w < 0 ? 0 : w);
      return;
    }
    _c.revealThrough(t);
  }

  void _followStatus() {
    if (mounted && _listening && !FollowSession.instance.active) {
      setState(() => _listening = false);
    }
  }

  @override
  void dispose() {
    FollowSession.instance.word.removeListener(_heard);
    FollowSession.instance.status.removeListener(_followStatus);
    if (identical(FollowSession.instance.owner, this)) FollowSession.instance.stop();
    _scroll.dispose();
    _c.removeListener(_changed);
    _marking.removeListener(_changed);
    _marking.dispose();
    _c.cards = false;
    // Leaving for good (not to the muṣḥaf, which carries on): stop playing.
    if (!_switching && !widget.fromMushaf) ReciteBack.instance.stop();
    super.dispose();
  }

  bool get _tapReveals => SettingsScope.of(context).memorizeTapReveals;

  /// Where the last touch came down on the screen (the tap zones).
  Offset _lastDown = Offset.zero;

  /// A tap's step (Settings): on in the screen's left half, back in its
  /// right; by words, by āyāt, or (split) words in the top half and āyāt
  /// in the bottom — or, the card all revealed, the next card, blank.
  void _step() => _c.tapStep(SettingsScope.of(context).memorizeTap,
      _lastDown, MediaQuery.sizeOf(context));

  bool _shows(MushafWord wd) =>
      _c.isRevealed(MushafRepo.tokenOf(_script, wd.ayah, wd.wordIdx));

  /// A tap on a word: the next word when taps reveal; else (the default) a
  /// revealed word plays — a hidden one gives nothing away.
  void _tapWord(MushafWord wd) {
    if (_tapReveals) {
      _step();
    } else if (_shows(wd)) {
      _playWord(wd);
    }
  }

  void _playWord(MushafWord wd) {
    ReciteBack.instance.stop();
    final (s, a) = MushafRepo.surahAyahOf(wd.ayah);
    final qc = qcWordOf(wd.ayah, wd.wordIdx) + 1;
    WbwAudio.instance.playWords(s, a, qc, qc, (_) {});
  }

  /// Ḥuṣarī reciting āyah [g] — only as far as it shows.
  void _tapVerseAudio(int g) {
    final clip = _c.clipOf(g);
    if (clip == null) return;
    ReciteBack.instance.play([clip], rate: SettingsScope.of(context).playbackSpeed);
  }

  /// A tap on a ۝: the next word when taps reveal; else, once it shows,
  /// Ḥuṣarī recites the āyah.
  void _tapVerse(int g) {
    if (_tapReveals) {
      _step();
    } else if (_shows(MushafWord('', g, -1))) {
      _tapVerseAudio(g);
    }
  }

  /// Holding a revealed word opens its sheet (mark a stumble right there).
  void _hold(MushafWord wd) {
    if (!_shows(wd)) {
      if (_tapReveals) _step();
      return;
    }
    if (MarksScope.maybeOf(context) == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .94,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          children: [
            WordMarksPanel(ref: WordRef.fromGlobal(wd.ayah, wd.wordIdx)),
          ],
        ),
      ),
    );
  }

  Future<void> _play({bool withBefore = false}) async {
    if (ReciteBack.instance.playing.value) {
      await ReciteBack.instance.stop();
      return;
    }
    final clips = withBefore ? _c.ayahClips() : [?_c.currentClip];
    if (clips.isEmpty) return;
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

  void _toMushaf() {
    if (widget.fromMushaf) {
      Navigator.of(context).pop();
      return;
    }
    _switching = true;
    // The home page takes it on: one app, two views.
    if (HomeLink.ready) return HomeLink.memorize(context, _c);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(
            startPage: _c.viewPage, script: _script, memorize: _c)));
  }

  void _end() {
    ReciteBack.instance.stop();
    final nav = Navigator.of(context);
    // From the muṣḥaf: it ends there too.
    nav.pop(widget.fromMushaf ? 'end' : null);
  }

  void _size(double by) {
    final s = SettingsScope.of(context);
    s.update(() => s.memorizeCardFont = (s.memorizeCardFont + by).clamp(24, 72));
  }

  /// One āyah's card, its place above it.
  Widget _verseCard(
    BuildContext context,
    AppSettings s,
    MushafPaper paper,
    Map<int, MarkVisual> marks,
    int g,
  ) {
    final (su, ay) = MushafRepo.surahAyahOf(g);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!s.focusMode) ...[
          Text(
            '${_tnames[su] ?? ''} $su:$ay',
            style: uiStyle(
              context,
              size: 14,
              weight: FontWeight.w700,
              color: paper.sub,
            ),
          ),
          const SizedBox(height: 10),
        ] else
          SizedBox(height: MediaQuery.paddingOf(context).top),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: paper.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: paper.line),
          ),
          child: VerseView(
            key: ValueKey(g),
            script: _script,
            globalAyah: g,
            fontSize: s.memorizeCardFont,
            ink: paper.ink,
            accent: paper.acc,
            strongBg: paper.hl2,
            verseBg: paper.hl,
            marks: marks,
            markPal: markPaletteForPaper(paper),
            hideFrom: _c.revealedEnd,
            handlers: _handlers,
          ),
        ),
      ],
    );
  }

  /// The cards so far, from the āyah it opened on down to the one being
  /// revealed. What's still to come isn't there at all.
  Widget _scrollList(
    BuildContext context,
    AppSettings s,
    MushafPaper paper,
    Map<int, MarkVisual> marks,
  ) {
    final now = _c.viewAyah;
    final from = now < _firstAyah ? now : _firstAyah;
    return LayoutBuilder(
      builder: (context, c) {
        return ListView.builder(
          controller: _scroll,
          // Room below for the last card to come up a quarter of the way.
          padding: EdgeInsets.fromLTRB(16, 16, 16, c.maxHeight * .6),
          itemCount: now - from + 1,
          itemBuilder: (context, i) => Center(
            key: ValueKey(from + i),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentMaxWidth(context, ContentKind.reading),
              ),
              child: Padding(
                key: from + i == now ? _currentCard : null,
                padding: const EdgeInsets.only(bottom: 16),
                child: _verseCard(context, s, paper, marks, from + i),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final paper = mushafPaperOf(s);
    final store = MarksScope.maybeOf(context);
    final book = store?.activeBook;
    final marks = book == null
        ? const <int, MarkVisual>{}
        : store!.visuals(book.id);
    final g = _c.viewAyah;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: paper.bg,
        // Focus mode: the āyah alone (its pill below has the essentials).
        appBar: s.focusMode
            ? null
            : AppBar(
                backgroundColor: paper.chrome,
                title: Text(context.l10n.mzMemorize),
                actions: [
                  if (!useDesktop(context))
                    IconButton(
                      tooltip: _scrolling
                          ? context.l10n.mzOneCard
                          : context.l10n.mzScrollCards,
                      onPressed: () => s.update(
                        () => s.memorizeCardsView = _scrolling
                            ? 'single'
                            : 'scroll',
                      ),
                      icon: Icon(
                        _scrolling ? AppIcons.viewSingle : AppIcons.reader,
                      ),
                    ),
                  IconButton(
                    tooltip: context.l10n.mzSmaller,
                    onPressed: () => _size(-4),
                    icon: const Icon(AppIcons.textSmaller),
                  ),
                  IconButton(
                    tooltip: context.l10n.mzBigger,
                    onPressed: () => _size(4),
                    icon: const Icon(AppIcons.textBigger),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(AppIcons.more),
                    itemBuilder: (_) => [
                      for (final (v, label) in [
                        ('play', context.l10n.mzTapPlay),
                        ('word', context.l10n.mzTapWord),
                        ('verse', context.l10n.mzTapVerse),
                        ('split', context.l10n.mzTapSplit),
                        ('pad', context.l10n.mzTapPad),
                      ])
                        CheckedPopupMenuItem(
                          value: 'tap:$v',
                          checked: s.memorizeTap == v,
                          child: Text('${context.l10n.mzTap}: $label'),
                        ),
                      CheckedPopupMenuItem(
                        value: 'focus',
                        checked: s.focusMode,
                        child: Text(context.l10n.fcFocus),
                      ),
                    ],
                    onSelected: (v) => s.update(
                      () => v == 'focus'
                          ? s.focusMode = !s.focusMode
                          : s.memorizeTap = v.substring(4),
                    ),
                  ),
                ],
              ),
        body: Listener(
          onPointerDown: (e) => _lastDown = e.position,
          child: !_ready
              ? Center(child: CircularProgressIndicator(color: p.acc))
              : Column(
                  children: [
                    Expanded(
                      // With "tap to reveal" on, a tap anywhere on the card reveals
                      // the next word.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: s.memorizeTapReveals ? _step : null,
                        child: Stack(
                          children: [
                            if (_scrolling)
                              _scrollList(context, s, paper, marks)
                            else
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                children: [
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: contentMaxWidth(
                                          context,
                                          ContentKind.reading,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _verseCard(
                                            context,
                                            s,
                                            paper,
                                            marks,
                                            g,
                                          ),
                                          if (useDesktop(context))
                                            _wordPanel(s, paper),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // One hand: the thumb pad in its corner.
                            if (s.memorizePad)
                              Positioned(
                                bottom: 36,
                                left: s.memorizePadSide == 'left' ? 10 : null,
                                right: s.memorizePadSide == 'left' ? null : 10,
                                child: MemorizePad(
                                  controller: _c,
                                  ink: paper.ink,
                                  accent: paper.id == 'mono'
                                      ? paper.ink
                                      : paper.acc,
                                  guide: s.memorizePadGuide,
                                  haptics: s.haptics,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: s.focusMode
                            ? const EdgeInsets.only(bottom: 12)
                            : const EdgeInsets.fromLTRB(12, 8, 8, 6),
                        decoration: s.focusMode
                            ? null
                            : BoxDecoration(
                                color: paper.chrome,
                                border: Border(
                                  top: BorderSide(color: paper.line),
                                ),
                              ),
                        child: MemorizeBar(
                          minimal: s.focusMode,
                          onExitFocus: () =>
                              s.update(() => s.focusMode = false),
                          controller: _c,
                          surahNames: _tnames,
                          bg: paper.chrome,
                          ink: paper.ink,
                          sub: paper.sub,
                          line: paper.line,
                          accent: paper.id == 'mono' ? paper.ink : paper.acc,
                          cards: true,
                          onPlay: _play,
                          onPlayPage: () => _play(withBefore: true),
                          onPlayClips: (clips) => ReciteBack.instance
                              .play(clips, rate: SettingsScope.of(context).playbackSpeed),
                          onListen: _listen,
                          listening: _listening,
                          listenStatus: FollowStrip(
                              ink: paper.ink,
                              sub: paper.sub,
                              accent: paper.id == 'mono' ? paper.ink : paper.acc),
                          onSwitchView: _toMushaf,
                          onEnd: _end,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
