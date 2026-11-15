import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../mushaf/mushaf_line.dart';
import '../mushaf/verse_view.dart';
import '../mushaf_screen.dart' show HomeLink, MushafPageScreen;
import 'marking.dart';
import 'word_marks_sheet.dart';
import '../../ui/bidi.dart';

/// My mutashābihāt: each mutashābih mark in the active book, its āyah and
/// every āyah it's confused with drawn as the muṣḥaf draws them (the
/// confused words outlined), with the memory technique for telling them
/// apart and the replies on it.
class MutashabihatScreen extends StatefulWidget {
  const MutashabihatScreen({super.key});

  @override
  State<MutashabihatScreen> createState() => _MutashabihatScreenState();
}

class _MutashabihatScreenState extends State<MutashabihatScreen> {
  String? _script;
  bool _ready = false;

  /// Only the open ones (not yet marked fixed).
  bool _openOnly = true;
  final _handlers = MushafTapHandlers();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final script = SettingsScope.of(context).mushafScript;
    if (script == _script) return;
    _script = script;
    _ready = false;
    _load(script);
  }

  Future<void> _load(String script) async {
    await MushafRepo.ensure(script);
    await MushafAtlas.load(script, MushafRepo.tokensSync(script));
    if (mounted && script == _script) setState(() => _ready = true);
  }

  void _open(WordRef r) {
    // The home page, the word in focus there.
    if (HomeLink.ready) return HomeLink.focus(context, r);
    final script = _script!;
    Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(
          startPage: MushafRepo.pageOfWord(
            script,
            r.globalAyah,
            r.isWholeAyah ? 0 : r.word0,
          ),
          script: script,
          focus: r,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final p = pal(context);
    final book = store?.activeBook;
    final all = store == null || book == null
        ? const <Mark>[]
        : store.mutashabihatOf(book.id);
    final shown = [
      for (final m in all)
        if (!_openOnly || !store!.isFixed(m)) m,
    ];
    return QScreen(
      title: context.l10n.mtTitle,
      // A desktop's wide panel: the āyāt at a reading width, not a phone's.
      maxWidth: 900,
      children: [
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(context.l10n.mtOpenAll)),
                ButtonSegment(value: false, label: Text(context.l10n.mtAll)),
              ],
              selected: {_openOnly},
              onSelectionChanged: (v) => setState(() => _openOnly = v.first),
            ),
          ),
        if (shown.isEmpty)
          QEmptyState(
            icon: AppIcons.link,
            title: context.l10n.mtTitle,
            hint: context.l10n.mtEmpty,
          )
        else if (!_ready)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: p.acc)),
          )
        else
          for (final m in shown)
            _Card(
              mark: m,
              store: store!,
              script: _script!,
              handlers: _handlers,
              onOpen: _open,
            ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Mark mark;
  final MarksStore store;
  final String script;
  final MushafTapHandlers handlers;
  final ValueChanged<WordRef> onOpen;
  const _Card({
    required this.mark,
    required this.store,
    required this.script,
    required this.handlers,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final paper = mushafPaperOf(s, script);
    final mp = markPaletteForPaper(paper);
    final marks = store.visuals(mark.bookId);
    final links = store.linksOf(mark);
    final book = store.book(mark.bookId);
    final canEdit =
        mark.authorId == store.authorId || book?.myRole == BookRole.owner;
    final replies = store.commentsOn(mark);
    final fontSize = s.reviewCardFont * .85;

    // One passage: where it is, then its āyah with the word outlined.
    Widget passage(WordRef r) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(r),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            color: paper.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: paper.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                linkLabel(script, r),
                textDirection: TextDirection.rtl,
                style: uiStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w600,
                  color: p.ink3,
                ),
              ),
              VerseView(
                script: script,
                globalAyah: r.globalAyah,
                fontSize: fontSize,
                ink: paper.ink,
                accent: paper.acc,
                strongBg: paper.hl2,
                verseBg: paper.hl,
                marks: marks,
                markPal: mp,
                focus: r.isWholeAyah ? -1 : r.key,
                handlers: handlers,
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MarkSwatch(
                type: store.isFixed(mark) ? null : MarkType.mutashabih,
                pal: mp,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.isFixed(mark)
                      ? '${context.l10n.mkMutashabih} · ${context.l10n.mkFixed}'
                      : context.l10n.mkMutashabih,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: context.l10n.mtGoTo,
                icon: Icon(AppIcons.mushaf, color: p.ink2),
                onPressed: () => onOpen(mark.ref),
              ),
            ],
          ),
          passage(mark.ref),
          const SizedBox(height: 10),
          Text(
            context.l10n.mtLinked,
            style: uiStyle(
              context,
              size: 12.5,
              weight: FontWeight.w700,
              color: p.ink3,
            ),
          ),
          if (links.isEmpty)
            Text(
              context.l10n.mtNeedOne,
              style: uiStyle(context, size: 13, color: p.ink3),
            )
          else
            for (final l in links) passage(l.ref),
          const SizedBox(height: 12),
          Text(
            context.l10n.mtTechnique,
            style: uiStyle(
              context,
              size: 12.5,
              weight: FontWeight.w700,
              color: p.ink3,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: canEdit ? () => _editTechnique(context) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: CommentText(
                mark.comment.isEmpty
                    ? context.l10n.mtTechniqueHint
                    : mark.comment,
                style: uiStyle(
                  context,
                  size: 14.5,
                  height: 1.45,
                  color: mark.comment.isEmpty ? p.ink3 : p.ink,
                ),
              ),
            ),
          ),
          for (final r in replies)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${authorLabel(context, store, r.authorId, r.authorName)}: ',
                      style: uiStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: p.ink2,
                      ),
                    ),
                    TextSpan(text: isolateArabic(r.text), style: uiStyle(context, size: 13)),
                  ],
                ),
              ),
            ),
          Wrap(
            children: [
              if (canEdit)
                TextButton.icon(
                  onPressed: () => _editTechnique(context),
                  icon: Icon(AppIcons.pen, size: 16, color: p.ink2),
                  label: Text(context.l10n.mtTechnique),
                ),
              TextButton.icon(
                onPressed: () async {
                  final t = await askText(
                    context,
                    title: context.l10n.mkReply,
                    comment: true,
                    word: mark.ref,
                    markType: mark.type,
                  );
                  if (t != null && t.trim().isNotEmpty) store.addComment(mark, t);
                },
                icon: Icon(AppIcons.comment, size: 16, color: p.ink2),
                label: Text(context.l10n.mkReply),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editTechnique(BuildContext context) async {
    final t = await askText(context,
        title: context.l10n.mtTechnique,
        hint: context.l10n.mtTechniqueHint,
        initial: mark.comment,
        long: true);
    if (t != null) store.setComment(mark, t);
  }
}
