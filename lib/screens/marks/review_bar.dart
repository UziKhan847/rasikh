import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart' show Recall;
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/review.dart';
import '../../data/divisions.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';
import '../../ui/bidi.dart';

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

  /// Set: the Hifẓ home's slot — one dense row (the kinds in a menu) or a
  /// column beside the pages.
  final Axis? axis;
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
    this.axis,
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
                        text: '  ${isolateArabic(m.comment)}',
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
            Text(context.l10n.rvPos(c.shownPosition, c.shownCount),
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
            _WhereChip(controller: c, ink: ink, line: line, accent: accent),
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
          // Right to left like the text: "next" points left and stands on
          // the left, "previous" on the right.
          icon(AppIcons.chevronLeft, context.l10n.rvNext,
              c.hasNext ? c.next : null),
          icon(AppIcons.chevronRight, context.l10n.rvPrev,
              c.hasPrev ? c.prev : null),
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
          icon(AppIcons.recite, context.l10n.rvReciteVerse,
              m == null ? null : onRepeatVerse),
          icon(AppIcons.undo, context.l10n.mkUndo, c.canUndo ? c.undo : null),
          const SizedBox(width: 2),
          // A fluency mark is read better, not fixed: how it went.
          if (c.onFluency)
            for (final (r, label, colour) in [
              (Recall.instant, context.l10n.flInstant, const Color(0xFF2E8B57)),
              (Recall.slow, context.l10n.flSlowRead, const Color(0xFFC27C12)),
              (Recall.wrong, context.l10n.flWrong, const Color(0xFFB4483B)),
            ])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FilledButton(
                  onPressed: () => c.rate(r),
                  style: FilledButton.styleFrom(
                    backgroundColor: colour,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 38),
                  ),
                  child: Text(label),
                ),
              )
          else
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
        if (axis == Axis.horizontal) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: m == null ? null : onOpenWord,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m != null)
                      MarkSwatch(type: fixed ? null : m.type, pal: pal, size: 14),
                    const SizedBox(width: 6),
                    Text(c.length > 0 ? context.l10n.rvPos(c.shownPosition, c.shownCount) : '',
                        style: uiStyle(context,
                            size: 12.5, weight: FontWeight.w700, color: sub)),
                  ]),
                ),
              ),
              PopupMenuButton<MarkType?>(
                tooltip: context.l10n.rvAll,
                icon: Icon(AppIcons.tune, color: ink),
                onSelected: c.setOnly,
                itemBuilder: (_) => [
                  PopupMenuItem(value: null, child: Text(context.l10n.rvAll)),
                  for (final t in MarkType.values)
                    if (kinds.contains(t))
                      PopupMenuItem(
                        value: t,
                        child: Row(children: [
                          MarkSwatch(type: t, pal: pal, size: 12),
                          const SizedBox(width: 8),
                          Text(markTypeLabel(context, t)),
                        ]),
                      ),
                ],
              ),
              actions,
            ]),
          );
        }
        if (axis == Axis.vertical) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            caption,
            const SizedBox(height: 8),
            Wrap(runSpacing: 6, children: [
              chip(null),
              for (final t in MarkType.values)
                if (kinds.contains(t)) chip(t),
            ]),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...actions.children],
            ),
          ]);
        }
        final body = Column(mainAxisSize: MainAxisSize.min, children: [
          caption,
          const SizedBox(height: 6),
          chips,
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: actions),
        ]);
        // Docked: centred, at most 720 wide on a wide window.
        if (!floating) {
          return Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: body));
        }
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

/// Where the arrows step: everywhere in the review, or one sūrah, juzʼ,
/// manzil, ḥizb or page of those it has marks in (each with its count).
class _WhereChip extends StatefulWidget {
  final ReviewController controller;
  final Color ink, line, accent;
  const _WhereChip(
      {required this.controller, required this.ink, required this.line, required this.accent});

  @override
  State<_WhereChip> createState() => _WhereChipState();
}

class _WhereChipState extends State<_WhereChip> {
  /// The places are counted only while the menu is open (not on every step
  /// through the review).
  bool _open = false;

  static const _divisions = [
    Division.surah,
    Division.juz,
    Division.manzil,
    Division.hizb,
    Division.page,
  ];

  static String placeLabel(BuildContext context, Division d, int n) {
    final l = context.l10n;
    return switch (d) {
      Division.surah => '${l.idxSurah} $n',
      Division.juz => l.juzN(n),
      Division.manzil => l.idxManzilN(n),
      Division.hizb => l.idxHizbN(n),
      Division.rub => l.idxRubN(n),
      _ => l.pageN(n),
    };
  }

  static String divisionLabel(BuildContext context, Division d) {
    final l = context.l10n;
    return switch (d) {
      Division.surah => l.idxSurah,
      Division.juz => l.idxJuz,
      Division.manzil => l.idxManzil,
      Division.hizb => l.idxHizb,
      Division.rub => l.idxRub,
      _ => l.idxPage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final where = c.where;
    final on = where != null;
    final label = where == null
        ? context.l10n.rvWholeBook
        : placeLabel(context, where.$1, where.$2);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: MenuAnchor(
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        menuChildren: [
          MenuItemButton(
            key: const ValueKey('where-all'),
            leadingIcon: where == null ? const Icon(Icons.check, size: 16) : null,
            onPressed: () => c.setWhere(null),
            child: Text('${context.l10n.rvWholeBook} · ${c.length}'),
          ),
          for (final d in _divisions)
            SubmenuButton(
              key: ValueKey('where-${d.name}'),
              menuChildren: [
                if (_open)
                for (final (n, count) in c.placesOf(d))
                  MenuItemButton(
                    key: ValueKey('where-${d.name}-$n'),
                    leadingIcon: where == (d, n) ? const Icon(Icons.check, size: 16) : null,
                    onPressed: () => c.setWhere((d, n)),
                    child: Text('${placeLabel(context, d, n)} · $count'),
                  ),
              ],
              child: Text(divisionLabel(context, d)),
            ),
        ],
        builder: (context, menu, _) => InkWell(
          key: const ValueKey('review-where'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? widget.accent.withValues(alpha: .16) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? widget.accent : widget.line, width: on ? 1.6 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.place_outlined, size: 14, color: widget.ink),
              const SizedBox(width: 4),
              Text(label,
                  style: uiStyle(context,
                      size: 12.5, weight: on ? FontWeight.w700 : FontWeight.w500, color: widget.ink)),
              Icon(Icons.arrow_drop_down, size: 16, color: widget.ink),
            ]),
          ),
        ),
      ),
    );
  }
}
