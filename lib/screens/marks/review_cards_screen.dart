import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/keymap.dart';
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/qc_words.dart';
import '../../core/marks/review.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../mushaf/mushaf_line.dart';
import '../mushaf/verse_view.dart';
import '../reader/reader_host.dart' show ReaderViewSwitch;
import '../mushaf_screen.dart';
import 'marking.dart';
import 'report_pdf.dart';
import 'review_bar.dart';
import '../../core/recite_back.dart';
import 'review_setup_sheet.dart';
import 'word_marks_sheet.dart';
import '../../ui/bidi.dart';

/// Asks what to review (around [page] of [script]) and starts it — on the
/// muṣḥaf page or as verse cards ([as], unasked). [onMushaf] takes the controller when the
/// caller is the muṣḥaf itself; otherwise the muṣḥaf opens.
Future<void> startReview(
  BuildContext context, {
  required String script,
  required int page,
  void Function(ReviewController c)? onMushaf,
  bool ask = false,
  ReviewView as = ReviewView.mushaf,
  String scope = 'marks',
}) async {
  final store = MarksScope.maybeOf(context);
  final book = store?.activeBook;
  if (store == null || book == null) {
    if (context.mounted) showQToast(context, context.l10n.rvNothing);
    return;
  }
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  // At once: every open mark, on the muṣḥaf, from this page on. Held: what,
  // where and how, asked.
  var (q, view) = (
    ReviewQuery(script: script, scope: reviewScopeOf(scope)),
    as,
  );
  if (ask) {
    final picked = await showReviewSetup(
      context,
      store: store,
      bookId: book.id,
      script: script,
      page: page,
    );
    if (picked == null || !context.mounted) return;
    (q, view) = picked;
  }
  int pageOf(WordRef r) =>
      MushafRepo.pageOfWord(script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1);
  final c = ReviewController.start(
    store,
    book.id,
    q,
    pageOf: pageOf,
    fluency: FluencyScope.read(context),
  );
  if (c.isEmpty) {
    showQToast(context, context.l10n.rvNothing);
    return;
  }
  if (!ask) {
    final i = c.items.indexWhere((m) => pageOf(m.ref) >= page);
    if (i > 0) c.goTo(i);
  }
  if (view == ReviewView.cards) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewCardsScreen(controller: c, script: script),
      ),
    );
  } else if (onMushaf != null) {
    onMushaf(c);
  } else {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(
          startPage: pageOf(c.current!.ref),
          script: script,
          review: c,
        ),
      ),
    );
  }
}

/// The end of a review: its session closed and kept quietly (History has
/// it), or dropped if nothing was looked at.
void endReview(BuildContext context, ReviewController c) {
  final seen = c.seenCount;
  final sid = c.sessionId;
  c.end();
  if (sid == null) return;
  if (seen == 0) {
    c.store.deleteSession(c.bookId, sid);
  } else {
    showSessionSaved(context);
  }
}

/// The end of a review with its numbers and "review again" — kept for
/// History's sessions. Returns true if "review again" was picked.
Future<bool> showReviewSummary(BuildContext context, ReviewController c) async {
  c.end();
  final choice = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(d.l10n.rvDoneTitle),
      content: Text(
        d.l10n.rvDoneSummary(c.seenCount, c.fixedCount, c.openCount),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, 'pdf'),
          child: Text(d.l10n.rpExport),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, 'again'),
          child: Text(d.l10n.rvAgain),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, 'done'),
          child: Text(d.l10n.rvDone),
        ),
      ],
    ),
  );
  if (choice == 'pdf' && context.mounted) {
    // The same marks, every status (what was fixed shows as fixed).
    await showReportSheet(
      context,
      store: c.store,
      bookId: c.bookId,
      script: c.query.script,
      query: c.query.copyWith(status: ReviewStatus.any),
    );
  }
  return choice == 'again';
}

/// Review as verse cards: one card per mark, its whole āyah drawn as the
/// muṣḥaf draws it (glyph atlas), the mark's word outlined and every other
/// mark in the āyah shown. Any word plays when tapped; the āyah number
/// plays the verse.
class ReviewCardsScreen extends StatefulWidget with DesktopAware {
  final ReviewController controller;
  final String script;
  const ReviewCardsScreen(
      {super.key, required this.controller, required this.script});

  @override
  State<ReviewCardsScreen> createState() => _ReviewCardsScreenState();
}

class _ReviewCardsScreenState extends State<ReviewCardsScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.controller.index);
  final _handlers = MushafTapHandlers();
  Map<int, String> _tnames = {};
  bool _ready = false;
  int _playAyah = -1, _playWord = -1;
  bool _reciting = false;
  bool _ending = false;

  /// The āyah's recitation, paused from the audio bar.
  bool _paused = false;

  ReviewController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_follow);
    _handlers
      ..onTapWord = _playWordAudio
      ..onLongPressWord = _showWord
      ..onLongPressVerse = _showWord
      ..onTapVerse = _playVerse;
    _load();
  }

  Future<void> _load() async {
    await MushafRepo.ensure(widget.script);
    await MushafAtlas.load(widget.script, MushafRepo.tokensSync(widget.script));
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    setState(() {
      _tnames = {for (final m in metas) m.n: m.tname};
      _ready = true;
    });
  }

  @override
  void dispose() {
    _c.removeListener(_follow);
    _pages.dispose();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    // Ended just after this frame (it notifies the marks; nothing may
    // rebuild while the tree is torn down).
    if (!_ending) Future.microtask(_c.end);
    super.dispose();
  }

  /// The arrows (or a fix) moved the controller: bring its card in.
  void _follow() {
    if (!mounted || !_pages.hasClients) return;
    final i = _c.index;
    if (_pages.page?.round() != i) {
      noMotion(context)
          ? _pages.jumpToPage(i)
          : _pages.animateToPage(i,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut);
    }
    setState(() {});
  }

  void _playWordAudio(MushafWord wd) {
    if (wd.isMarker) {
      _playVerse(wd.ayah);
      return;
    }
    AyahAudio.instance.stop();
    final (surah, ayah) = MushafRepo.surahAyahOf(wd.ayah);
    setState(() {
      _paused = false;
      _reciting = false;
      _playAyah = wd.ayah;
      _playWord = wd.wordIdx;
    });
    final qc = qcWordOf(wd.ayah, wd.wordIdx) + 1;
    WbwAudio.instance.playWords(surah, ayah, qc, qc, (idx) {
      if (!mounted) return;
      setState(() {
        if (idx == -1) {
          _playAyah = -1;
          _playWord = -1;
        }
      });
    });
  }

  Future<void> _playVerse(int g) async {
    WbwAudio.instance.stop();
    final s = SettingsScope.of(context);
    final (surah, ayah) = MushafRepo.surahAyahOf(g);
    setState(() {
      _paused = false;
      _reciting = true;
      _playAyah = g;
      _playWord = -1;
    });
    AyahAudio.instance.setRate(s.playbackSpeed);
    // Review recites in Ḥuṣarī's voice (his timings light the words).
    final err = await AyahAudio.instance.play(
      surah,
      ayah,
      reciter: ReciteBack.reciter,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _reciting = false);
      showQToast(context, err);
    }
  }

  void _repeatWord() {
    final m = _c.current;
    if (m != null) _playWordAudio(_wordOf(m.ref));
  }

  void _repeatVerse() {
    final m = _c.current;
    if (m != null) _playVerse(m.ref.globalAyah);
  }

  /// The āyah's recitation: paused, or on again from where it stopped.
  void _pauseResume() {
    if (_paused) {
      AyahAudio.instance.resume();
    } else {
      AyahAudio.instance.pause();
    }
    setState(() => _paused = !_paused);
  }

  void _stopAudio() {
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    setState(() {
      _paused = false;
      _reciting = false;
      _playAyah = -1;
      _playWord = -1;
    });
  }

  /// The muṣḥaf review's keys: Space and Backspace (or the arrows) step,
  /// the rest repeat, fix, rate and undo.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final km = SettingsScope.of(context).keymap;
    bool hit(KeyAction a) => km.matches(a, e);
    KeyEventResult did(VoidCallback f) {
      f();
      return KeyEventResult.handled;
    }

    if (hit(KeyAction.reviewNext)) return did(_c.next);
    if (hit(KeyAction.reviewPrev)) return did(_c.prev);
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_c.onFluency) {
      if (hit(KeyAction.fluencyInstant)) {
        return did(() => _c.rate(Recall.instant));
      }
      if (hit(KeyAction.fluencySlow)) return did(() => _c.rate(Recall.slow));
      if (hit(KeyAction.fluencyWrong)) return did(() => _c.rate(Recall.wrong));
    }
    if (hit(KeyAction.reviewRepeat)) return did(_repeatWord);
    if (hit(KeyAction.reviewRepeatVerse)) return did(_repeatVerse);
    if (hit(KeyAction.reviewFix)) return did(_c.markFixed);
    if (hit(KeyAction.undo)) return did(_c.undo);
    if (hit(KeyAction.leave)) return did(_end);
    return KeyEventResult.ignored;
  }

  /// Desktop: the word, the āyah, pause or resume, stop.
  Widget _audioBar(MushafPaper paper) {
    final l = context.l10n;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    return ValueListenableBuilder<bool>(
      valueListenable: AyahAudio.instance.playing,
      builder: (context, playing, _) {
        final verse = _reciting && (playing || _paused);
        final any = verse || _playAyah >= 0;
        Widget btn(String key, IconData icon, String tip, VoidCallback? on) =>
            IconButton(
              key: ValueKey(key),
              tooltip: tip,
              visualDensity: VisualDensity.compact,
              color: paper.ink,
              disabledColor: paper.sub.withValues(alpha: .4),
              onPressed: on,
              icon: Icon(icon, size: 20),
            );
        return Container(
          key: const ValueKey('review-audio'),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: paper.chrome,
            border: Border(top: BorderSide(color: paper.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              btn('audio-word', AppIcons.wordByWord, l.playWord, _repeatWord),
              btn(
                'audio-verse',
                AppIcons.recite,
                l.rvReciteVerse,
                _repeatVerse,
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('audio-pause'),
                tooltip: _paused ? l.resume : l.pause,
                visualDensity: VisualDensity.compact,
                color: accent,
                disabledColor: paper.sub.withValues(alpha: .4),
                onPressed: verse ? _pauseResume : null,
                icon: Icon(_paused ? AppIcons.play : AppIcons.pause, size: 20),
              ),
              btn('audio-stop', AppIcons.stop, l.stop, any ? _stopAudio : null),
            ],
          ),
        );
      },
    );
  }

  MushafWord _wordOf(WordRef r) => r.isWholeAyah
      ? MushafWord('', r.globalAyah, -1)
      : MushafWord('', r.globalAyah, r.word0);

  void _showWord(MushafWord wd) {
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
            WordMarksPanel(
              ref: WordRef.fromGlobal(wd.ayah, wd.wordIdx),
              sessionId: _c.sessionId,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _end() async {
    _ending = true;
    final nav = Navigator.of(context);
    endReview(context, _c);
    nav.pop();
  }

  void _openInMushaf() {
    final m = _c.current;
    if (m == null) return;
    _ending = true; // the muṣḥaf carries the review on
    // The home page, where the review runs as the muṣḥaf's own.
    if (HomeLink.ready) return HomeLink.review(context, _c);
    final page = MushafRepo.pageOfWord(
      widget.script,
      m.ref.globalAyah,
      m.ref.word <= 0 ? 0 : m.ref.word0,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(
          startPage: page,
          script: widget.script,
          review: _c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final paper = mushafPaperOf(s);
    final mp = markPaletteForPaper(paper);
    final store = _c.store;
    final desk = useDesktop(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !_ending) _c.end();
        },
        child: Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Text(context.l10n.rvReview),
            actions: [
              IconButton(
                tooltip: context.l10n.mzSmaller,
                onPressed: () => s.update(
                  () => s.reviewCardFont = (s.reviewCardFont - 4).clamp(20, 72),
                ),
                icon: const Icon(AppIcons.textSmaller),
              ),
              IconButton(
                tooltip: context.l10n.mzBigger,
                onPressed: () => s.update(
                  () => s.reviewCardFont = (s.reviewCardFont + 4).clamp(20, 72),
                ),
                icon: const Icon(AppIcons.textBigger),
              ),
              // The same switch as the page's and the Reader's: the review
              // carries on there.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ReaderViewSwitch(
                  page: false,
                  dense: true,
                  onChanged: (_) => _openInMushaf(),
                  ink: p.ink3,
                  accent: p.acc.withValues(alpha: .3),
                  track: p.track,
                  onAccent: p.ink,
                ),
              ),
              if (!desk)
                PopupMenuButton<String>(
                  icon: const Icon(AppIcons.more),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: 'word',
                      checked: s.reviewCardWord,
                      child: Text(context.l10n.rvShowWord),
                    ),
                  ],
                  onSelected: (_) =>
                      s.update(() => s.reviewCardWord = !s.reviewCardWord),
                ),
            ],
          ),
          body: !_ready
              ? Center(child: CircularProgressIndicator(color: p.acc))
              : Column(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: store,
                        builder: (context, _) {
                          final marks = store.visuals(_c.bookId);
                          return PageView.builder(
                            controller: _pages,
                            // The book reads right to left: the next card comes
                            // in from the left.
                            reverse: true,
                            itemCount: _c.length,
                            onPageChanged: (i) {
                              if (i != _c.index) _c.goTo(i);
                            },
                            itemBuilder: (context, i) =>
                                _card(context, _c.items[i], marks, mp, paper),
                          );
                        },
                      ),
                    ),
                    if (desk) _audioBar(paper),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                        decoration: BoxDecoration(
                          color: paper.chrome,
                          border: Border(top: BorderSide(color: paper.line)),
                        ),
                        child: ReviewBar(
                          controller: _c,
                          pal: mp,
                          bg: paper.chrome,
                          ink: paper.ink,
                          sub: paper.sub,
                          line: paper.line,
                          accent: paper.id == 'mono' ? paper.ink : paper.acc,
                          onRepeatWord: _repeatWord,
                          onRepeatVerse: _repeatVerse,
                          onOpenWord: () {
                            final m = _c.current;
                            if (m != null) _showWord(_wordOf(m.ref));
                          },
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

  Widget _card(
    BuildContext context,
    Mark m,
    Map<int, MarkVisual> marks,
    MarkPalette mp,
    MushafPaper paper,
  ) {
    final p = pal(context);
    final r = m.ref;
    final store = _c.store;
    final fix = store.fixOf(m);
    final page = MushafRepo.pageOfWord(
      widget.script,
      r.globalAyah,
      r.word <= 0 ? 0 : r.word0,
    );
    final where = [
      '${_tnames[r.surah] ?? ''} ${r.surah}:${r.ayah}',
      context.l10n.pageN(page),
      context.l10n.juzN(divisionOf(Division.juz, r.surah, r.ayah)),
      context.l10n.idxHizbN(hizbOf(r.surah, r.ayah)),
    ].join(' · ');
    final replies = store.commentsOn(m);
    // Desktop: one word at a time, always — the āyah above, its word below.
    final showWord =
        useDesktop(context) || SettingsScope.of(context).reviewCardWord;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: contentMaxWidth(context, ContentKind.reading),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  where,
                  style: uiStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: p.ink3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: paper.paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: paper.line),
                  ),
                  child: VerseView(
                    script: widget.script,
                    globalAyah: r.globalAyah,
                    fontSize: SettingsScope.of(context).reviewCardFont,
                    ink: paper.ink,
                    accent: paper.acc,
                    strongBg: paper.hl2,
                    verseBg: paper.hl,
                    marks: marks,
                    markPal: mp,
                    focus: r.key,
                    playAyah: _playAyah,
                    playWord: _playWord,
                    reciting: _reciting,
                    handlers: _handlers,
                  ),
                ),
                const SizedBox(height: 12),
                if (showWord)
                  _WordPanel(
                    word: r.isWholeAyah
                        ? null
                        : MushafRepo.wordText(
                            widget.script,
                            r.globalAyah,
                            r.word0,
                          ),
                    fontFamily: MushafRepo.fontFamily(widget.script),
                    fontSize: SettingsScope.of(context).reviewCardFont * 1.8,
                    tint: fix == null ? mp.tintOf(m.type) : null,
                    line: fix == null ? mp.colorOf(m.type) : mp.fixed,
                    paper: paper,
                    onTap: () => _playWordAudio(_wordOf(r)),
                  ),
                if (showWord) const SizedBox(height: 12),
                Row(
                  children: [
                    MarkSwatch(type: fix == null ? m.type : null, pal: mp),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          fix == null
                              ? markTypeLabel(context, m.type)
                              : '${markTypeLabel(context, m.type)} · ${context.l10n.mkFixed}',
                          context.l10n.mkMarkedBy(
                            authorLabel(
                              context,
                              store,
                              m.authorId,
                              m.authorName,
                            ),
                            shortDate(context, m.createdAt),
                          ),
                        ].join(' · '),
                        style: uiStyle(context, size: 13, color: p.ink2),
                      ),
                    ),
                  ],
                ),
                // A mutashābih: what it's confused with, and the technique.
                if (m.type == MarkType.mutashabih) ...[
                  const SizedBox(height: 8),
                  MutashabihLinks(mark: m, store: store),
                ],
                if (m.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (m.type == MarkType.mutashabih)
                    Text(
                      context.l10n.mtTechnique,
                      style: uiStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: p.ink3,
                      ),
                    ),
                  CommentText(m.comment, style: uiStyle(context, size: 16)),
                ],
                for (final c in replies)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 6,
                      start: 10,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${authorLabel(context, store, c.authorId, c.authorName)}: ',
                            style: uiStyle(
                              context,
                              size: 13,
                              weight: FontWeight.w700,
                              color: p.ink2,
                            ),
                          ),
                          TextSpan(
                            text: c.text,
                            style: uiStyle(context, size: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The marked word under the verse card, large — what the student must fix
/// — tinted and underlined as its mark is; a tap plays it. A whole-āyah
/// mark says so instead.
class _WordPanel extends StatelessWidget {
  final String? word;
  final String fontFamily;
  final double fontSize;
  final Color? tint;
  final Color line;
  final MushafPaper paper;
  final VoidCallback onTap;
  const _WordPanel({
    required this.word,
    required this.fontFamily,
    required this.fontSize,
    required this.tint,
    required this.line,
    required this.paper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = word;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: paper.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line, width: 1.5),
        ),
        child: Center(
          child: w == null
              ? Text(context.l10n.mkWholeAyah,
                  style: uiStyle(context,
                      size: 18, weight: FontWeight.w700, color: paper.ink))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(bottom: BorderSide(color: line, width: 3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(w,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: fontSize,
                            height: 1.9,
                            color: paper.ink)),
                  ),
                ),
        ),
      ),
    );
  }
}
