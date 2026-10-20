import 'package:flutter/material.dart';

import '../../core/audio.dart';
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
import '../marks/word_marks_sheet.dart';
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
  const MemorizeCardsScreen(
      {super.key, required this.controller, this.fromMushaf = false});

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
    _handlers
      ..onTapWord = _tapWord
      ..onTapVerse = _tapVerse
      ..onLongPressWord = _hold;
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    // Leaving for good (not to the muṣḥaf, which carries on): stop playing.
    if (!_switching && !widget.fromMushaf) ReciteBack.instance.stop();
    super.dispose();
  }

  bool get _tapReveals => SettingsScope.of(context).memorizeTapReveals;

  bool _shows(MushafWord wd) =>
      _c.isRevealed(MushafRepo.tokenOf(_script, wd.ayah, wd.wordIdx));

  /// A tap on a word: the next word when taps reveal; else (the default) a
  /// revealed word plays — a hidden one gives nothing away.
  void _tapWord(MushafWord wd) {
    if (_tapReveals) {
      _c.nextWord();
    } else if (_shows(wd)) {
      ReciteBack.instance.stop();
      final (s, a) = MushafRepo.surahAyahOf(wd.ayah);
      final qc = qcWordOf(wd.ayah, wd.wordIdx) + 1;
      WbwAudio.instance.playWords(s, a, qc, qc, (_) {});
    }
  }

  /// A tap on a ۝: the next word when taps reveal; else, once it shows,
  /// Ḥuṣarī recites the āyah.
  void _tapVerse(int g) {
    if (_tapReveals) {
      _c.nextWord();
    } else if (_shows(MushafWord('', g, -1))) {
      ReciteBack.instance.play([(g, -1)],
          rate: SettingsScope.of(context).playbackSpeed);
    }
  }

  /// Holding a revealed word opens its sheet (mark a stumble right there).
  void _hold(MushafWord wd) {
    if (!_shows(wd)) {
      if (_tapReveals) _c.nextWord();
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(
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
    final (su, ay) = MushafRepo.surahAyahOf(g);
    return Scaffold(
      backgroundColor: paper.bg,
      // Focus mode: the āyah alone (its pill below has the essentials).
      appBar: s.focusMode
          ? null
          : AppBar(
        backgroundColor: paper.chrome,
        title: Text(context.l10n.mzMemorize),
        actions: [
          IconButton(
              tooltip: context.l10n.mzSmaller,
              onPressed: () => _size(-4),
              icon: const Icon(AppIcons.textSmaller)),
          IconButton(
              tooltip: context.l10n.mzBigger,
              onPressed: () => _size(4),
              icon: const Icon(AppIcons.textBigger)),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'tap',
                checked: s.memorizeTapReveals,
                child: Text(context.l10n.mzTapReveals),
              ),
              CheckedPopupMenuItem(
                value: 'focus',
                checked: s.focusMode,
                child: Text(context.l10n.fcFocus),
              ),
            ],
            onSelected: (v) => s.update(() => v == 'focus'
                ? s.focusMode = !s.focusMode
                : s.memorizeTapReveals = !s.memorizeTapReveals),
          ),
        ],
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator(color: p.acc))
          : Column(children: [
              Expanded(
                // With "tap to reveal" on, a tap anywhere on the card reveals
                // the next word.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: s.memorizeTapReveals ? _c.nextWord : null,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: contentMaxWidth(
                                  context, ContentKind.reading)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!s.focusMode) ...[
                                Text('${_tnames[su] ?? ''} $su:$ay',
                                    style: uiStyle(context,
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: paper.sub)),
                                const SizedBox(height: 10),
                              ] else
                                SizedBox(
                                    height: MediaQuery.paddingOf(context).top),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                          ),
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
                          border: Border(top: BorderSide(color: paper.line)),
                        ),
                  child: MemorizeBar(
                    minimal: s.focusMode,
                    onExitFocus: () => s.update(() => s.focusMode = false),
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
                    onSwitchView: _toMushaf,
                    onEnd: _end,
                  ),
                ),
              ),
            ]),
    );
  }
}
