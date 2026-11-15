import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';
import '../../ui/bidi.dart';
import '../mushaf_screen.dart' show HomeLink;

/// Everything marked on one word in the active mark book, with the actions to
/// add, comment, fix, re-type or delete. Embedded in the word sheets of the
/// muṣḥaf and the card reader. Renders nothing without a [MarksStore].
class WordMarksPanel extends StatelessWidget {
  final WordRef ref;

  /// The open session on this device, if marking (new marks join it).
  final String? sessionId;

  /// Links a mutashābih mark to the passages it's confused with (the
  /// muṣḥaf's link mode): called with a new one, and by "Link another".
  /// Null: no linking here.
  final ValueChanged<Mark>? onLink;
  const WordMarksPanel(
      {super.key, required this.ref, this.sessionId, this.onLink});

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready) return const SizedBox.shrink();
    final p = pal(context);
    final mp = markPaletteFor(p,
        mono: SettingsScope.of(context).appTheme == 'mono');
    final book = store.activeBook;
    final marks =
        book == null ? const <Mark>[] : store.marksAt(book.id, ref).reversed;
    final canMark = book == null || book.myRole.canMark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.getInheritedWidgetOfExactType<ProgressScope>()?.notifier case final prog?)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ValueListenableBuilder<int>(
              valueListenable: prog.readingSignal,
              builder: (context, _, _) {
                final on = prog.isBookmarked(ref.surah, ref.ayah);
                return TextButton.icon(
                  onPressed: () => prog.toggleBookmark(ref.surah, ref.ayah),
                  icon: Icon(on ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                      size: 16, color: on ? p.gold : p.ink2),
                  label: Text(on ? context.l10n.removeBookmark : context.l10n.bmAyah,
                      style: uiStyle(context, size: 13, weight: FontWeight.w600, color: p.ink2)),
                );
              },
            ),
          ),
        QSectionLabel(
          ref.isWholeAyah ? context.l10n.mkWholeAyah : context.l10n.mkMarksOnWord,
          trailing: book == null
              ? null
              : Text(book.name,
                  style: uiStyle(context, size: 12.5, color: p.ink3)),
        ),
        if (marks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.l10n.mkNoMarksOnWord,
                style: uiStyle(context, size: 13.5, color: p.ink3)),
          )
        else
          for (final m in marks)
            _MarkTile(
                mark: m,
                store: store,
                mp: mp,
                sessionId: sessionId,
                onLink: _link(context)),
        if (canMark) ...[
          const SizedBox(height: 6),
          Text(context.l10n.mkAddMark,
              style: uiStyle(context,
                  size: 12.5, weight: FontWeight.w700, color: p.ink3)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            // A mutashābih needs its likenesses tapped: on the muṣḥaf (from
            // elsewhere, it goes there to link them).
            for (final t in MarkType.marking)
              if (t != MarkType.mutashabih || _link(context) != null)
              ActionChip(
                avatar: MarkSwatch(type: t, pal: mp, size: 14),
                label: Text(markTypeLabel(context, t)),
                tooltip: markTypeHint(context, t),
                onPressed: () => _add(context, store, t),
              ),
          ]),
        ],
      ],
    );
  }

  /// Where a mutashābih's likenesses get linked: here ([onLink]), else on
  /// the home muṣḥaf.
  ValueChanged<Mark>? _link(BuildContext context) =>
      onLink ?? (HomeLink.ready ? (m) => HomeLink.link(context, m) : null);

  Future<void> _add(BuildContext context, MarksStore store, MarkType t) async {
    final book = store.ensureActiveBook(context.l10n.mkYou);
    if (t == MarkType.note) {
      final text = await askText(context,
          title: context.l10n.mkNote, comment: true, word: ref, markType: t);
      if (text == null || text.trim().isEmpty) return;
      store.addMark(book.id, ref, t, sessionId: sessionId, comment: text);
    } else if (t == MarkType.mutashabih) {
      // Then straight to tapping the passages it's confused with.
      final op = store.addMark(book.id, ref, t, sessionId: sessionId);
      final id = op.changes.single.$2;
      final m = store.marksAt(book.id, ref).where((m) => m.id == id).single;
      _link(context)?.call(m);
    } else {
      store.addMark(book.id, ref, t, sessionId: sessionId);
    }
  }
}

class _MarkTile extends StatelessWidget {
  final Mark mark;
  final MarksStore store;
  final MarkPalette mp;
  final String? sessionId;
  final ValueChanged<Mark>? onLink;
  const _MarkTile(
      {required this.mark,
      required this.store,
      required this.mp,
      required this.sessionId,
      this.onLink});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final fix = store.fixOf(mark);
    final book = store.book(mark.bookId);
    final mine = mark.authorId == store.authorId;
    final canEdit = mine || book?.myRole == BookRole.owner;
    final canFix = book?.myRole.canMark ?? true;
    final session =
        mark.sessionId == null ? null : store.session(mark.bookId, mark.sessionId!);
    final replies = store.commentsOn(mark);
    final color = fix != null ? mp.fixed : mp.colorOf(mark.type);
    // A rounded card with the mark's colour as a stripe down its leading
    // edge. (One border with a radius must be a single colour — a stripe
    // drawn as a differently coloured side failed to paint at all.)
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            MarkSwatch(type: fix != null ? null : mark.type, pal: mp),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fix != null
                    ? '${markTypeLabel(context, mark.type)} · ${context.l10n.mkFixed}'
                    : markTypeLabel(context, mark.type),
                style: uiStyle(context, size: 14.5, weight: FontWeight.w700),
              ),
            ),
            // Changing the type stays in a menu; the everyday actions are
            // buttons below.
            if (canEdit)
              PopupMenuButton<String>(
                icon: Icon(AppIcons.more, color: p.ink3),
                tooltip: '',
                onSelected: (v) => _action(context, v),
                itemBuilder: (_) => [
                  for (final t in MarkType.marking)
                    if (t != mark.type)
                      PopupMenuItem(
                          value: 'type:${t.code}',
                          child: Row(children: [
                            MarkSwatch(type: t, pal: mp, size: 13),
                            const SizedBox(width: 8),
                            Text(markTypeLabel(context, t)),
                          ])),
                ],
              ),
          ]),
          Text(
            [
              context.l10n.mkMarkedBy(
                  authorLabel(context, store, mark.authorId, mark.authorName),
                  shortDate(context, mark.createdAt)),
              if (session != null && session.kind != SessionKind.none)
                sessionKindLabel(context, session.kind),
              if (fix != null)
                context.l10n.mkFixedOn(shortDate(context, fix.fixedAt)),
            ].join(' · '),
            style: uiStyle(context, size: 12, color: p.ink3),
          ),
          if (mark.type == MarkType.mutashabih) ...[
            const SizedBox(height: 6),
            MutashabihLinks(mark: mark, store: store, canEdit: canEdit),
          ],
          if (mark.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (mark.type == MarkType.mutashabih)
              Text(context.l10n.mtTechnique,
                  style: uiStyle(context,
                      size: 12, weight: FontWeight.w700, color: p.ink3)),
            CommentText(mark.comment, style: uiStyle(context, size: 14)),
          ],
          for (final r in replies)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 10),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text:
                        '${authorLabel(context, store, r.authorId, r.authorName)}: ',
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w700, color: p.ink2)),
                TextSpan(text: isolateArabic(r.text), style: uiStyle(context, size: 13)),
              ])),
            ),
          const SizedBox(height: 4),
          Wrap(spacing: 2, runSpacing: 0, children: [
            if (canFix && mark.type.fixable)
              _act(context, AppIcons.check,
                  fix == null ? context.l10n.mkMarkFixed : context.l10n.mkMarkNotFixed,
                  'fix', color: fix == null ? mp.fixed : null),
            if (canEdit && mark.type == MarkType.mutashabih && onLink != null)
              _act(context, AppIcons.add, context.l10n.mtLinkAnother, 'link'),
            if (canEdit)
              _act(
                  context,
                  AppIcons.pen,
                  mark.type == MarkType.mutashabih
                      ? context.l10n.mtTechnique
                      : context.l10n.mkComment,
                  'comment'),
            _act(context, AppIcons.comment, context.l10n.mkReply, 'reply'),
            if (canEdit)
              _act(context, AppIcons.delete, context.l10n.mkDelete, 'delete'),
          ]),
        ],
      ),
      ),
    );
  }

  Widget _act(BuildContext context, IconData icon, String label, String v,
      {Color? color}) {
    final c = color ?? pal(context).ink2;
    return TextButton.icon(
      onPressed: () => _action(context, v),
      icon: Icon(icon, size: 16, color: c),
      label: Text(label,
          style: uiStyle(context, size: 13, weight: FontWeight.w600, color: c)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _action(BuildContext context, String v) async {
    if (v == 'fix') {
      store.setFixed(mark, store.fixOf(mark) == null, sessionId: sessionId);
    } else if (v == 'link') {
      onLink?.call(mark);
    } else if (v == 'comment') {
      final technique = mark.type == MarkType.mutashabih;
      final t = await askText(context,
          title: technique ? context.l10n.mtTechnique : context.l10n.mkComment,
          hint: technique ? context.l10n.mtTechniqueHint : null,
          initial: mark.comment,
          long: technique,
          comment: true,
          word: mark.ref,
          markType: mark.type);
      if (t != null) store.setComment(mark, t);
    } else if (v == 'reply') {
      final t = await askText(context,
          title: context.l10n.mkReply, comment: true, word: mark.ref, markType: mark.type);
      if (t != null && t.trim().isNotEmpty) store.addComment(mark, t);
    } else if (v.startsWith('type:')) {
      store.setType(mark, MarkType.fromCode(v.substring(5)));
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(d.l10n.mkDeleteMarkQ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(d.l10n.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(d.l10n.mkDelete)),
          ],
        ),
      );
      if (ok == true) store.deleteMark(mark);
    }
  }
}

/// A mutashābih mark's partners: each passage it's confused with, as a chip
/// (its sūrah:āyah, and the word) — removable by whoever may edit the mark.
class MutashabihLinks extends StatelessWidget {
  final Mark mark;
  final MarksStore store;
  final bool canEdit;

  /// A tap on a partner (open it); null: the chips only show.
  final ValueChanged<WordRef>? onOpen;
  const MutashabihLinks(
      {super.key,
      required this.mark,
      required this.store,
      this.canEdit = false,
      this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final links = store.linksOf(mark);
    final script = SettingsScope.of(context).mushafScript;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.mtLinked,
            style: uiStyle(context,
                size: 12, weight: FontWeight.w700, color: p.ink3)),
        const SizedBox(height: 4),
        if (links.isEmpty)
          Text(context.l10n.mtNeedOne,
              style: uiStyle(context, size: 13, color: p.ink3))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in links)
              InputChip(
                label: Text(linkLabel(script, l.ref),
                    textDirection: TextDirection.rtl),
                onPressed: onOpen == null ? null : () => onOpen!(l.ref),
                onDeleted: canEdit ? () => store.removeLink(l) : null,
              ),
          ]),
      ],
    );
  }
}

/// A linked passage in short: its sūrah:āyah and, for a word, the word.
String linkLabel(String script, WordRef r) {
  final at = '${r.surah}:${r.ayah}';
  if (r.isWholeAyah) return at;
  final w = MushafRepo.wordText(script, r.globalAyah, r.word0);
  return w.isEmpty ? at : '$w  $at';
}
