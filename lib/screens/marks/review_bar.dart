import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/review.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// The bar shown while reviewing marks (muṣḥaf and verse cards): what the
/// current mark is and where it stands in the queue, which kind the arrows
/// step through, and the actions — previous / next, repeat (tap: the word;
/// hold: the verse), fixed, end. Colours come from the host.
class ReviewBar extends StatelessWidget {
  final ReviewController controller;
  final MarkPalette pal;
  final Color bg, ink, sub, line, accent;
  final VoidCallback onRepeatWord;
  final VoidCallback onRepeatVerse;

  /// Opens the current word's sheet (its comment, replies, other marks).
  final VoidCallback onOpenWord;
  final VoidCallback onEnd;

  /// Floating pill (desktop / landscape) vs. a full-width bar.
  final bool floating;
  const ReviewBar({
    super.key,
    required this.controller,
    required this.pal,
    required this.bg,
    required this.ink,
    required this.sub,
    required this.line,
    required this.accent,
    required this.onRepeatWord,
    required this.onRepeatVerse,
    required this.onOpenWord,
    required this.onEnd,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.store]),
      builder: (context, _) {
        final c = controller;
        final m = c.current;
        final fixed = m != null && c.isFixed(m);
        // The kinds in the queue, for the arrow filter.
        final kinds = {for (final x in c.items) x.type};
        final caption = Row(children: [
          if (m != null) ...[
            MarkSwatch(type: fixed ? null : m.type, pal: pal, size: 14),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: GestureDetector(
              onTap: m == null ? null : onOpenWord,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: m == null
                        ? context.l10n.rvNone
                        : fixed
                            ? '${markTypeLabel(context, m.type)} · '
                                '${context.l10n.rvAlreadyFixed}'
                            : markTypeLabel(context, m.type),
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w700, color: ink),
                  ),
                  if (m != null && m.comment.isNotEmpty)
                    TextSpan(
                        text: '  ${m.comment}',
                        style: uiStyle(context, size: 12.5, color: sub)),
                  if (m != null && m.comment.isEmpty)
                    TextSpan(
                        text: '  ${context.l10n.rvTapHint}',
                        style: uiStyle(context, size: 12.5, color: sub)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (c.length > 0)
            Text(context.l10n.rvPos(c.index + 1, c.length),
                style: uiStyle(context,
                    size: 12.5, weight: FontWeight.w700, color: sub)),
        ]);
        Widget chip(MarkType? t) {
          final on = c.only == t;
          final col = t == null ? accent : pal.colorOf(t);
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => c.setOnly(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: on ? col.withValues(alpha: .16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: on ? col : line, width: on ? 1.6 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (t != null) ...[
                    MarkSwatch(type: t, pal: pal, size: 11),
                    const SizedBox(width: 5),
                  ],
                  Text(t == null ? context.l10n.rvAll : markTypeLabel(context, t),
                      style: uiStyle(context,
                          size: 12.5,
                          weight: on ? FontWeight.w700 : FontWeight.w500,
                          color: ink)),
                ]),
              ),
            ),
          );
        }

        final chips = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip(null),
            for (final t in MarkType.values)
              if (kinds.contains(t)) chip(t),
          ]),
        );
        IconButton icon(IconData i, String tip, VoidCallback? on) => IconButton(
              tooltip: tip,
              onPressed: on,
              icon: Icon(i, color: on == null ? sub.withValues(alpha: .5) : ink),
            );
        final actions = Row(mainAxisSize: MainAxisSize.min, children: [
          // Right to left like the text: "previous" points right.
          icon(AppIcons.chevronRight, context.l10n.rvPrev,
              c.hasPrev ? c.prev : null),
          icon(AppIcons.chevronLeft, context.l10n.rvNext,
              c.hasNext ? c.next : null),
          Tooltip(
            message: context.l10n.rvRepeatHint,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: m == null ? null : onRepeatWord,
              onLongPress: m == null ? null : onRepeatVerse,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(AppIcons.repeat,
                    color: m == null ? sub.withValues(alpha: .5) : ink),
              ),
            ),
          ),
          icon(AppIcons.undo, context.l10n.mkUndo, c.canUndo ? c.undo : null),
          const SizedBox(width: 2),
          FilledButton.icon(
            onPressed: m == null || fixed || !m.type.fixable
                ? null
                : () => c.markFixed(),
            icon: const Icon(AppIcons.check, size: 18),
            label: Text(context.l10n.mkMarkFixed),
            style: FilledButton.styleFrom(
              backgroundColor: pal.fixed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 38),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(48, 38),
            ),
            child: Text(context.l10n.mkEnd,
                style: uiStyle(context,
                    size: 14, weight: FontWeight.w700, color: accent)),
          ),
        ]);
        final body = Column(mainAxisSize: MainAxisSize.min, children: [
          caption,
          const SizedBox(height: 6),
          chips,
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: actions),
        ]);
        if (!floating) return body;
        return Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line),
            boxShadow: qShadows(context, const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: -10),
            ]),
          ),
          child: body,
        );
      },
    );
  }
}
