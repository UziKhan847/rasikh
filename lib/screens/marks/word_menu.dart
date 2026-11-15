import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fluency/chunks.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/fluency/words.dart';
import '../../core/keymap.dart';
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart' show showQToast;
import '../../ui/mark_style.dart';
import '../fluency/fluency_tools.dart';
import 'marking.dart';
import 'marking_bar.dart' show kMarkPens;
import '../mushaf_screen.dart' show HomeLink;

/// A mouse button pressed on a word, as the key map has it (out of the box:
/// Shift and a click marks it and again the next kind, the wheel's click writes
/// its comment, a right-click opens [menu]). Whether it was one of those. Only
/// the menu outside desktop mode.
bool wordMouse(BuildContext context, WordRef ref, int buttons, MarkingController marking,
    {required VoidCallback menu}) {
  final action = SettingsScope.of(context).keymap.mouseActionFor(buttons);
  if (action == MouseAction.menu) {
    menu();
    return true;
  }
  if (!useDesktop(context)) return false;
  switch (action) {
    case MouseAction.stepMark:
      marking.stepMark(context, ref);
      return true;
    case MouseAction.fluencyStep:
      final f = FluencyScope.read(context);
      if (f == null || ref.isWholeAyah) return false;
      final step = cycleFluency(f, SettingsScope.of(context).mushafScript, ref);
      if (step != null) marking.recordStep(step);
      return true;
    case MouseAction.comment:
      _writeComment(context, ref, marking);
      return true;
    default:
      return false;
  }
}

/// Straight to the comment: on the word's own mark, or as a note if it has
/// none.
Future<void> _writeComment(BuildContext context, WordRef ref, MarkingController marking) async {
  final store = MarksScope.maybeOf(context);
  if (store == null || !store.ready) return;
  final l = context.l10n;
  final book = store.ensureActiveBook(l.mkMe);
  if (!book.myRole.canMark) return;
  final mine = [
    for (final m in store.marksAt(book.id, ref))
      if (m.authorId == store.authorId) m
  ].lastOrNull;
  final text = await askText(context,
      title: l.mkComment,
      initial: mine?.comment ?? '',
      comment: true,
      word: ref,
      markType: mine?.type);
  if (text == null) return;
  if (mine != null) {
    marking.recordOp(store.setComment(mine, text));
  } else if (text.trim().isNotEmpty) {
    marking.recordOp(store.addMark(book.id, ref, MarkType.note,
        sessionId: marking.active ? marking.sessionId : null, comment: text));
  }
}

/// A right-click's menu on a word (or an āyah's ۝, [ref] its word 0): the kinds
/// of mark (a tick by what's on it already; choosing that takes it off), its
/// comments, hearing it, copying it, and the whole sheet. The same things a
/// hold opens on a touch screen, a click apart.
Future<void> showWordMenu(
  BuildContext context,
  Offset at, {
  required WordRef ref,
  required String script,
  String? sessionId,
  required void Function(MarkOp op) onEdit,
  void Function(UndoStep step)? onFluency,
  required VoidCallback onComment,
  required VoidCallback onPlay,
  required VoidCallback onMore,
}) async {
  final store = MarksScope.maybeOf(context);
  final l = context.l10n;
  final p = pal(context);
  final mp = markPaletteFor(p, mono: SettingsScope.of(context).appTheme == 'mono');
  final book = store?.ready == true ? store!.ensureActiveBook(l.mkMe) : null;
  final canMark = book != null && book.myRole.canMark;
  final on = book == null
      ? const <MarkType>{}
      : {for (final m in store!.marksAt(book.id, ref)) if (!store.isFixed(m)) m.type};
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(at);
  final fluency = ref.isWholeAyah ? null : FluencyScope.read(context);
  final flKind = fluency == null ? null : fluencyKindAt(fluency, ref);
  final progress = context.getInheritedWidgetOfExactType<ProgressScope>()?.notifier;
  final saved = progress?.isBookmarked(ref.surah, ref.ayah) ?? false;

  PopupMenuItem<String> row(String value, Widget lead, String text, {Widget? trail}) =>
      PopupMenuItem<String>(
        value: value,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          SizedBox(width: 22, child: Center(child: lead)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: uiStyle(context, size: 13.5))),
          if (trail != null) ...[const SizedBox(width: 12), trail],
        ]),
      );
  Icon icon(IconData i) => Icon(i, size: 17, color: p.ink2);

  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(local.dx, local.dy,
        overlay.size.width - local.dx, overlay.size.height - local.dy),
    constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
    items: [
      if (canMark) ...[
        for (final t in kMarkPens)
          row('type:${t.code}', MarkSwatch(type: t, pal: mp, size: 13), markTypeLabel(context, t),
              trail: on.contains(t) ? Icon(AppIcons.check, size: 15, color: p.ink2) : null),
        // A mutashābih: on the muṣḥaf, to tap what it's confused with.
        if (HomeLink.ready)
          row('mutashabih', MarkSwatch(type: MarkType.mutashabih, pal: mp, size: 13),
              markTypeLabel(context, MarkType.mutashabih),
              trail: on.contains(MarkType.mutashabih)
                  ? Icon(AppIcons.check, size: 15, color: p.ink2)
                  : null),
        const PopupMenuDivider(height: 8),
      ],
      // A word's fluency: not fluent, paired with the next, a chunk.
      if (fluency != null) ...[
        for (final (k, label, i) in [
          (FluencyKind.word, l.flSlow, AppIcons.bolt),
          (FluencyKind.pair, l.flPair, AppIcons.link),
          (FluencyKind.chunk, l.flChunk, AppIcons.shapeStack),
        ])
          row('fl:${k.name}', icon(i), label,
              trail: fluency.markAt(k, ref) != null
                  ? Icon(AppIcons.check, size: 15, color: p.ink2)
                  : null),
        if (flKind == FluencyKind.chunk) row('split', icon(AppIcons.tune), l.wmSplit),
        const PopupMenuDivider(height: 8),
      ],
      row('comment', icon(AppIcons.comment), l.mkComment),
      row('play', icon(AppIcons.volume), ref.isWholeAyah ? l.listen : l.playWord),
      if (progress != null)
        row(
            'bookmark',
            Icon(saved ? AppIcons.bookmarkFilled : AppIcons.bookmark, size: 17, color: p.ink2),
            saved ? l.removeBookmark : l.bmAyah),
      row('copy', icon(Icons.content_copy), l.wmCopy),
      const PopupMenuDivider(height: 8),
      row('more', icon(AppIcons.more), l.wmMore),
    ],
  );
  if (picked == null || !context.mounted) return;
  switch (picked) {
    case 'comment':
      onComment();
    case 'play':
      onPlay();
    case 'more':
      onMore();
    case 'split':
      showChunkEditor(context, script, ref);
    case final v when v.startsWith('fl:') && fluency != null:
      final before = fluency.snapshotAt(ref);
      final form = formOf(script, ref);
      switch (v.substring(3)) {
        case 'word':
          fluency.toggleSlow(ref, form);
        case 'pair':
          togglePairAt(fluency, script, ref);
        case 'chunk':
          if (fluency.markAt(FluencyKind.chunk, ref) != null) {
            fluency.setChunk(ref, form, 0, 0);
          } else {
            var (pre, suf) = suggestSplit(form);
            if (pre == 0 && suf == 0) pre = 1;
            fluency.setChunk(ref, form, pre, suf);
          }
      }
      onFluency?.call(FluencyStep(fluency, before));
    case 'mutashabih':
      if (book == null) return;
      // Its likenesses, linked on the muṣḥaf: the one there, or a new one.
      final have = [
        for (final m in store!.marksAt(book.id, ref))
          if (m.type == MarkType.mutashabih) m
      ].lastOrNull;
      if (have != null) {
        HomeLink.link(context, have);
        return;
      }
      final op = store.addMark(book.id, ref, MarkType.mutashabih, sessionId: sessionId);
      onEdit(op);
      final id = op.changes.single.$2;
      final m = store.marksAt(book.id, ref).where((m) => m.id == id).single;
      HomeLink.link(context, m);
    case 'bookmark':
      progress?.toggleBookmark(ref.surah, ref.ayah);
    case 'copy':
      final String text;
      if (ref.isWholeAyah) {
        final (_, words) = MushafRepo.ayahTokens(script, ref.globalAyah);
        text = [for (final w in words) if (!w.isMarker) w.text].join(' ');
      } else {
        text = MushafRepo.wordText(script, ref.globalAyah, ref.word0);
      }
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showQToast(context, l.wmCopied);
    default:
      final type = MarkType.fromCode(picked.substring(5));
      if (book == null) return;
      if (type == MarkType.note && !on.contains(MarkType.note)) {
        final text = await askText(context,
            title: l.mkNote, comment: true, word: ref, markType: type);
        if (text == null || text.trim().isEmpty) return;
        onEdit(store!.addMark(book.id, ref, type, sessionId: sessionId, comment: text));
        return;
      }
      // Off whoever's session made it; else on, in the open one if any.
      final there = [
        for (final m in store!.marksAt(book.id, ref))
          if (m.type == type && !store.isFixed(m)) m
      ];
      onEdit(there.isNotEmpty
          ? store.deleteMark(there.last)
          : store.addMark(book.id, ref, type, sessionId: sessionId));
  }
}
