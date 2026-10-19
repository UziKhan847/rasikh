import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// The bar shown while marking: the order a tap steps a word's mark through
/// (mistake → tajwīd → hesitation → doubt → off), what the last tap did, then
/// undo and end. Colours come from the host (muṣḥaf paper or app palette).
class MarkingBar extends StatelessWidget {
  final MarkingController controller;
  final MarkPalette pal;
  final Color bg, ink, sub, line, accent;
  final VoidCallback onEnd;
  final VoidCallback onUndo;

  /// Floating pill (desktop / landscape) vs. a full-width bar.
  final bool floating;
  const MarkingBar({
    super.key,
    required this.controller,
    required this.pal,
    required this.bg,
    required this.ink,
    required this.sub,
    required this.line,
    required this.accent,
    required this.onEnd,
    required this.onUndo,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final last = controller.lastType;
        final String title, hint;
        if (!controller.tapped) {
          title = '';
          hint = context.l10n.mkTapToMark;
        } else if (last == null) {
          title = context.l10n.mkMarkCleared;
          hint = context.l10n.mkTapAgainHint;
        } else {
          title = markTypeLabel(context, last);
          hint = markTypeHint(context, last);
        }
        // The cycle, read right to left like the text it marks (mistake on
        // the right, each next step to its left); the type the last tap left
        // is ringed. Laid out left to right explicitly: the icon font mirrors
        // chevrons inside right-to-left text.
        final cycle = Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, t) in MarkType.pens.reversed.indexed) ...[
            if (i > 0)
              Icon(AppIcons.chevronLeft, size: 14, color: sub),
            _CycleStep(
              type: t,
              current: controller.tapped && t == last,
              pal: pal,
              ring: ink,
              tooltip: markTypeLabel(context, t),
            ),
          ],
        ]);
        final actions = Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 1, height: 28, color: line),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.l10n.mkUndo,
            onPressed: controller.canUndo ? onUndo : null,
            icon: Icon(AppIcons.undo,
                color: controller.canUndo ? ink : sub.withValues(alpha: .5)),
          ),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(48, 40),
            ),
            child: Text(context.l10n.mkEnd,
                style: uiStyle(context,
                    size: 14, weight: FontWeight.w700, color: accent)),
          ),
        ]);
        final caption = Text.rich(
          TextSpan(children: [
            if (title.isNotEmpty)
              TextSpan(
                  text: '$title  ',
                  style: uiStyle(context,
                      size: 12.5, weight: FontWeight.w700, color: ink)),
            TextSpan(
                text: hint, style: uiStyle(context, size: 12.5, color: sub)),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        );
        final body = Column(mainAxisSize: MainAxisSize.min, children: [
          caption,
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Directionality(textDirection: TextDirection.ltr, child: cycle),
              const SizedBox(width: 4),
              actions,
            ]),
          ),
        ]);
        if (!floating) return body;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
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

/// One step of the tap cycle: the type's swatch, ringed when it's what the
/// last tap left on its word.
class _CycleStep extends StatelessWidget {
  final MarkType type;
  final bool current;
  final MarkPalette pal;
  final Color ring;
  final String tooltip;
  const _CycleStep({
    required this.type,
    required this.current,
    required this.pal,
    required this.ring,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = pal.colorOf(type);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        selected: current,
        label: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current ? c.withValues(alpha: .18) : Colors.transparent,
            border: Border.all(
                color: current ? c : ring.withValues(alpha: .15),
                width: current ? 2.2 : 1),
          ),
          alignment: Alignment.center,
          child: MarkSwatch(type: type, pal: pal, size: 16),
        ),
      ),
    );
  }
}

/// Legend row of all mark types (used in sheets and stats).
class MarkLegend extends StatelessWidget {
  final MarkPalette pal;
  final bool includeFixed;
  const MarkLegend({super.key, required this.pal, this.includeFixed = true});

  @override
  Widget build(BuildContext context) {
    final p = pal;
    Widget item(MarkType? t, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkSwatch(type: t, pal: p, size: 13),
            const SizedBox(width: 6),
            Text(label, style: uiStyle(context, size: 12.5)),
          ],
        );
    return Wrap(spacing: 14, runSpacing: 6, children: [
      for (final t in MarkType.values) item(t, markTypeLabel(context, t)),
      if (includeFixed) item(null, context.l10n.mkFixed),
    ]);
  }
}
