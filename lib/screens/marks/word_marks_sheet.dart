import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// Everything marked on one word in the active mark book, with the actions to
/// add, comment, fix, re-type or delete. Embedded in the word sheets of the
/// muṣḥaf and the card reader. Renders nothing without a [MarksStore].
class WordMarksPanel extends StatelessWidget {
  final WordRef ref;

  /// The open session on this device, if marking (new marks join it).
  final String? sessionId;
  const WordMarksPanel({super.key, required this.ref, this.sessionId});

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
            _MarkTile(mark: m, store: store, mp: mp, sessionId: sessionId),
        if (canMark) ...[
          const SizedBox(height: 6),
          Text(context.l10n.mkAddMark,
              style: uiStyle(context,
                  size: 12.5, weight: FontWeight.w700, color: p.ink3)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in MarkType.values)
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

  Future<void> _add(BuildContext context, MarksStore store, MarkType t) async {
    final book = store.ensureActiveBook(context.l10n.mkYou);
    if (t == MarkType.note) {
      final text = await askText(context, title: context.l10n.mkNote);
      if (text == null || text.trim().isEmpty) return;
      store.addMark(book.id, ref, t, sessionId: sessionId, comment: text);
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
  const _MarkTile(
      {required this.mark,
      required this.store,
      required this.mp,
      required this.sessionId});

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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: BorderDirectional(
          start: BorderSide(color: color, width: 4),
          top: BorderSide(color: p.line2),
          end: BorderSide(color: p.line2),
          bottom: BorderSide(color: p.line2),
        ),
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
            PopupMenuButton<String>(
              icon: Icon(AppIcons.more, color: p.ink3),
              tooltip: '',
              onSelected: (v) => _action(context, v),
              itemBuilder: (_) => [
                if (canFix && mark.type.fixable)
                  PopupMenuItem(
                      value: 'fix',
                      child: Text(fix == null
                          ? context.l10n.mkMarkFixed
                          : context.l10n.mkMarkNotFixed)),
                if (canEdit)
                  PopupMenuItem(
                      value: 'comment', child: Text(context.l10n.mkComment)),
                PopupMenuItem(value: 'reply', child: Text(context.l10n.mkReply)),
                if (canEdit)
                  for (final t in MarkType.values)
                    if (t != mark.type)
                      PopupMenuItem(
                          value: 'type:${t.code}',
                          child: Row(children: [
                            MarkSwatch(type: t, pal: mp, size: 13),
                            const SizedBox(width: 8),
                            Text(markTypeLabel(context, t)),
                          ])),
                if (canEdit)
                  PopupMenuItem(
                      value: 'delete', child: Text(context.l10n.mkDelete)),
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
          if (mark.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(mark.comment, style: uiStyle(context, size: 14)),
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
                TextSpan(text: r.text, style: uiStyle(context, size: 13)),
              ])),
            ),
        ],
      ),
    );
  }

  Future<void> _action(BuildContext context, String v) async {
    if (v == 'fix') {
      store.setFixed(mark, store.fixOf(mark) == null, sessionId: sessionId);
    } else if (v == 'comment') {
      final t = await askText(context,
          title: context.l10n.mkComment, initial: mark.comment);
      if (t != null) store.setComment(mark, t);
    } else if (v == 'reply') {
      final t = await askText(context, title: context.l10n.mkReply);
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
