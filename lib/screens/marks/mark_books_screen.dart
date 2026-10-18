import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'marking.dart';

/// Mark books — one per reciter: create, rename, delete, pick the active one.
class MarkBooksScreen extends StatelessWidget {
  const MarkBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final p = pal(context);
    if (store == null) return const SizedBox.shrink();
    final books = store.books;
    return QScreen(
      title: context.l10n.mkManageBooks,
      actions: [
        QIconButton(
          icon: AppIcons.add,
          tooltip: context.l10n.mkNewBook,
          onTap: () => _create(context, store),
        ),
      ],
      children: [
        if (books.isEmpty)
          QEmptyState(
            icon: AppIcons.person,
            title: context.l10n.mkNoMarksYet,
            hint: context.l10n.mkNoMarksYetSub,
            action: QPrimaryButton(context.l10n.mkNewBook,
                icon: AppIcons.add, onTap: () => _create(context, store)),
          )
        else
          QGroup(children: [
            for (final b in books)
              QRow(
                title: b.name,
                subtitle: [
                  if (b.id == store.activeBookId) context.l10n.mkActive,
                  if (b.myRole != BookRole.owner) _role(context, b.myRole),
                  '${store.marksOf(b.id).length} · ${context.l10n.mkMarks}',
                ].join(' · '),
                leading: Icon(
                    b.id == store.activeBookId
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: b.id == store.activeBookId ? p.acc : p.ink3),
                onTap: () => store.setActiveBook(b.id),
                control: PopupMenuButton<String>(
                  icon: Icon(AppIcons.more, color: p.ink3),
                  onSelected: (v) => _action(context, store, b, v),
                  itemBuilder: (_) => [
                    if (b.myRole == BookRole.owner)
                      PopupMenuItem(
                          value: 'rename', child: Text(context.l10n.mkRename)),
                    PopupMenuItem(
                        value: 'delete', child: Text(context.l10n.mkDelete)),
                  ],
                ),
              ),
          ]),
      ],
    );
  }

  static String _role(BuildContext context, BookRole r) => switch (r) {
        BookRole.owner => '',
        BookRole.listener => context.l10n.mkListener,
        BookRole.checker => context.l10n.mkChecker,
      };

  Future<void> _create(BuildContext context, MarksStore store) async {
    final name = await askText(context,
        title: context.l10n.mkNewBook, hint: context.l10n.mkBookNameHint);
    if (name == null || name.trim().isEmpty) return;
    store.createBook(name);
  }

  Future<void> _action(
      BuildContext context, MarksStore store, MarkBook b, String v) async {
    if (v == 'rename') {
      final name = await askText(context,
          title: context.l10n.mkRename,
          initial: b.name,
          hint: context.l10n.mkBookNameHint);
      if (name != null && name.trim().isNotEmpty) store.renameBook(b.id, name);
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(b.name),
          content: Text(d.l10n.mkDeleteBookQ),
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
      if (ok != true) return;
      // Someone else's book is only dropped from this device.
      b.myRole == BookRole.owner
          ? store.deleteBook(b.id)
          : store.forgetBook(b.id);
    }
  }
}
