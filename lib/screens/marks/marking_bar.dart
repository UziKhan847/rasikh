import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// The pen bar shown while marking: four mark pens and "fix", then undo and
/// end. Colours come from the host (muṣḥaf paper or app palette).
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
        final pen = controller.pen;
        final type = pen.type;
        final hint = type == null
            ? context.l10n.mkFixHint
            : markTypeHint(context, type);
        final title =
            type == null ? context.l10n.mkFix : markTypeLabel(context, type);
        final pens = Row(mainAxisSize: MainAxisSize.min, children: [
          for (final p in MarkPen.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PenButton(
                pen: p,
                selected: p == pen,
                pal: pal,
                ring: ink,
                bg: bg,
                tooltip: p.type == null
                    ? context.l10n.mkFix
                    : markTypeLabel(context, p.type!),
                onTap: () => controller.setPen(p),
              ),
            ),
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
            TextSpan(
                text: '$title  ',
                style: uiStyle(context,
                    size: 12.5, weight: FontWeight.w700, color: ink)),
            TextSpan(
                text: hint, style: uiStyle(context, size: 12.5, color: sub)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        );
        final body = Column(mainAxisSize: MainAxisSize.min, children: [
          caption,
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              pens,
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
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: -10),
            ],
          ),
          child: body,
        );
      },
    );
  }
}

class _PenButton extends StatelessWidget {
  final MarkPen pen;
  final bool selected;
  final MarkPalette pal;
  final Color ring, bg;
  final String tooltip;
  final VoidCallback onTap;
  const _PenButton({
    required this.pen,
    required this.selected,
    required this.pal,
    required this.ring,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = pen.type;
    final c = t == null ? pal.fixed : pal.colorOf(t);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? c.withValues(alpha: .18) : Colors.transparent,
              border: Border.all(
                  color: selected ? c : ring.withValues(alpha: .15),
                  width: selected ? 2.2 : 1),
            ),
            alignment: Alignment.center,
            child: t == null
                ? Icon(AppIcons.check, size: 20, color: c)
                : MarkSwatch(type: t, pal: pal, size: 18),
          ),
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
