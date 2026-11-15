import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/app_icons.dart';

/// One tool: a circle, or an entry in the ⋯ fan. Its callbacks get the
/// button's context, for a popover to open from.
class DockItem {
  final IconData icon;
  final String tooltip;

  /// Under its circle in the fan (the [tooltip] if unset).
  final String? label;
  final bool selected;
  final void Function(BuildContext button) onTap;

  /// Holding the tool: its options.
  final void Function(BuildContext button)? onOptions;

  /// Desktop mode: kept in the gear's menu, not the row.
  final bool inMenu;
  const DockItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.selected = false,
    this.onOptions,
    this.inMenu = false,
  });
}

/// The muṣḥaf home's tools: five round buttons floating at the foot of the
/// page (down its side, landscape) and a smaller ⋯ for the rest, which
/// [fanOpen] shows in a [ToolFan] above them. A swipe toward the page opens
/// the fan, away from it folds it. A mode's bar can take the circles'
/// place ([replacement]).
class ToolCircles extends StatelessWidget {
  final Axis axis;

  /// Down the left edge (the swipe that opens the fan goes right).
  final bool onLeft;
  final List<DockItem> items;
  final MushafPaper paper;
  final EdgeInsets safe;
  final Widget? replacement;
  final bool fanOpen;
  final ValueChanged<bool> onFan;

  /// The ⋯ button's key: the fan's popovers open from it.
  final Key? moreKey;
  final String moreLabel;

  /// Any tap or hold on a circle (the first-run hint goes).
  final VoidCallback? onUse;

  /// The circles' size.
  final double circleSize;

  /// Whether there's a ⋯ (not when everything's in the row).
  final bool showMore;
  const ToolCircles({
    super.key,
    required this.axis,
    this.onLeft = false,
    required this.items,
    required this.paper,
    this.safe = EdgeInsets.zero,
    this.replacement,
    required this.fanOpen,
    required this.onFan,
    required this.moreLabel,
    this.moreKey,
    this.onUse,
    this.circleSize = size,
    this.showMore = true,
  });

  static const size = 52.0, moreSize = 40.0, desktopSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    final gap = vertical
        ? const EdgeInsets.symmetric(vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 6);
    void swipe(double? v) {
      if (v == null || v.abs() < 150) return;
      // Toward the page: up in portrait, inward on a side.
      final toPage = vertical ? (onLeft ? v > 0 : v < 0) : v < 0;
      onFan(toPage);
    }

    final circles = GestureDetector(
      onVerticalDragEnd: vertical ? null : (d) => swipe(d.primaryVelocity),
      onHorizontalDragEnd: vertical ? (d) => swipe(d.primaryVelocity) : null,
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final it in items)
            Padding(
              padding: gap,
              child: ToolCircle(item: it, paper: paper, size: circleSize, onUse: onUse),
            ),
          if (showMore)
          Padding(
            padding: gap,
            child: ToolCircle(
              key: moreKey,
              paper: paper,
              size: moreSize,
              onUse: onUse,
              item: DockItem(
                icon: fanOpen ? AppIcons.close : AppIcons.more,
                tooltip: moreLabel,
                selected: fanOpen,
                onTap: (_) => onFan(!fanOpen),
              ),
            ),
          ),
        ],
      ),
    );
    return RepaintBoundary(
      child: Padding(
        padding: vertical
            ? EdgeInsets.fromLTRB(safe.left + 4, safe.top + 6, safe.right + 4, safe.bottom + 6)
            : EdgeInsets.fromLTRB(safe.left + 6, 4, safe.right + 6, safe.bottom + 6),
        // Narrow phones: the circles shrink a little rather than overflow.
        child: Center(
          child: replacement ?? FittedBox(fit: BoxFit.scaleDown, child: circles),
        ),
      ),
    );
  }
}

/// A tool's round button, lifted off the page; filled with the accent while
/// it's on.
class ToolCircle extends StatelessWidget {
  final DockItem item;
  final MushafPaper paper;
  final double size;
  final VoidCallback? onUse;
  const ToolCircle(
      {super.key, required this.item, required this.paper, this.size = 52, this.onUse});

  @override
  Widget build(BuildContext context) {
    final on = item.selected;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    return Tooltip(
      message: item.tooltip,
      triggerMode: item.onOptions == null
          ? TooltipTriggerMode.longPress
          : TooltipTriggerMode.manual,
      child: Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? accent : paper.chrome,
          shape: CircleBorder(
              side: BorderSide(color: paper.line.withValues(alpha: .6), width: .5)),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: paper.dark ? .7 : .35),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              onUse?.call();
              item.onTap(context);
            },
            onLongPress: item.onOptions == null
                ? null
                : () {
                    onUse?.call();
                    item.onOptions!(context);
                  },
            // A mouse's right button: the same as holding.
            onSecondaryTap: item.onOptions == null
                ? null
                : () {
                    onUse?.call();
                    item.onOptions!(context);
                  },
            child: SizedBox.square(
              dimension: size,
              child: Icon(item.icon,
                  size: size * .44, color: on ? paper.chrome : paper.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ⋯ fan: the rest of the tools as small labelled circles, on a card
/// above the circles (beside them, landscape).
class ToolFan extends StatelessWidget {
  final List<DockItem> items;
  final MushafPaper paper;
  final double maxWidth;
  const ToolFan({super.key, required this.items, required this.paper, this.maxWidth = 380}); // five a row

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: paper.chrome,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: paper.line.withValues(alpha: .6), width: .5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: paper.dark ? .5 : .16),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 8,
        children: [
          for (final it in items)
            SizedBox(
              width: 72,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ToolCircle(item: it, paper: paper, size: 44),
                const SizedBox(height: 5),
                Text(it.label ?? it.tooltip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: uiStyle(context,
                        size: 11.5, weight: FontWeight.w600, color: paper.sub)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Desktop mode's row: as many of the fan's tools beside [main] as fit in
/// [length] (one place kept for the gear), and what's left for the gear's
/// menu, those [DockItem.inMenu] last. Elsewhere, as they are.
(List<DockItem> row, List<DockItem> rest) splitDock(
    List<DockItem> main, List<DockItem> fan,
    {required bool desktop, required double length}) {
  if (!desktop) return (main, fan);
  const step = ToolCircles.desktopSize + 12;
  final room = ((length - 24) / step).floor();
  final rowable = [for (final f in fan) if (!f.inMenu) f];
  final menu = [for (final f in fan) if (f.inMenu) f];
  final take = (room - main.length - 1).clamp(0, rowable.length);
  return ([...main, ...rowable.take(take)], [...rowable.skip(take), ...menu]);
}

/// The row and the ⋯ fan's tools: on desktop no fan, the row ending in a gear
/// whose menu ([gear]) has the rest.
(List<DockItem> row, List<DockItem> fan) dockLayout(
    List<DockItem> main, List<DockItem> more,
    {required bool desktop,
    required double length,
    required DockItem Function(List<DockItem> menu) gear}) {
  if (!desktop) return (main, more);
  final (row, rest) = splitDock(main, more, desktop: true, length: length);
  return ([...row, gear(rest)], const []);
}

/// A tool's name in a menu, and its key if its tooltip carries one.
(String, String?) _menuName(DockItem it) {
  final t = it.tooltip;
  final m = RegExp(r'^(.*) \(([^()]+)\)$').firstMatch(t);
  return m == null ? (t, null) : (m.group(1)!, m.group(2));
}

/// The gear's menu: a small one beside it, each tool by its name.
Future<void> showDockMenu(BuildContext anchor, List<DockItem> items) async {
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final p = pal(anchor);
  final picked = await showMenu<int>(
    context: anchor,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
    items: [
      for (final (i, it) in items.indexed)
        PopupMenuItem<int>(
          value: i,
          height: 36,
          child: Row(children: [
            Icon(it.icon, size: 17, color: p.ink2),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_menuName(it).$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(anchor, size: 13.5)),
            ),
            // Its key on the right, as a computer's menus show it.
            if (_menuName(it).$2 case final key?) ...[
              const SizedBox(width: 16),
              Text(key, style: uiStyle(anchor, size: 12, color: p.ink3)),
            ],
          ]),
        ),
    ],
  );
  if (picked != null && anchor.mounted) items[picked].onTap(anchor);
}
