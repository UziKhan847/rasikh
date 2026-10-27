import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// One tool on the dock. Its callbacks get the button's context, for a
/// popover to open from.
class DockItem {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final void Function(BuildContext button) onTap;

  /// Holding the tool (or tapping it again while it's on): its options.
  final void Function(BuildContext button)? onOptions;
  const DockItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.onOptions,
  });
}

/// The Hifẓ home's toolbar, as a note-taking app's: a lifted bar along the
/// bottom (its top corners rounded) or down the right edge (its left
/// corners rounded); tools that don't fit scroll within it, a fade at the
/// end that has more. A tool's own bar can take its place ([replacement]).
class HifzDock extends StatelessWidget {
  final Axis axis;
  final List<DockItem> items;
  final MushafPaper paper;

  /// The window's insets the bar runs under (the home indicator, a notch).
  final EdgeInsets safe;
  final Widget? replacement;
  const HifzDock({
    super.key,
    required this.axis,
    required this.items,
    required this.paper,
    this.safe = EdgeInsets.zero,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(24);
    final vertical = axis == Axis.vertical;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    final tools = [
      for (final it in items)
        _DockButton(item: it, ink: paper.ink, accent: accent),
    ];
    final body = replacement ??
        EdgeFadeScroll(
          axis: axis,
          color: paper.chrome,
          child: Flex(
            direction: axis,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in tools)
                Padding(
                  padding: vertical
                      ? const EdgeInsets.symmetric(vertical: 3)
                      : const EdgeInsets.symmetric(horizontal: 1),
                  child: t,
                ),
            ],
          ),
        );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper.chrome,
          borderRadius: vertical
              ? const BorderRadius.only(topLeft: r, bottomLeft: r)
              : const BorderRadius.only(topLeft: r, topRight: r),
          border: Border.all(color: paper.line.withValues(alpha: .6), width: .5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: paper.dark ? .5 : .14),
              blurRadius: 18,
              spreadRadius: -4,
              offset: vertical ? const Offset(-3, 0) : const Offset(0, -3),
            ),
          ],
        ),
        child: Padding(
          padding: vertical
              ? EdgeInsets.fromLTRB(6, safe.top + 10, 6 + safe.right, safe.bottom + 10)
              : EdgeInsets.fromLTRB(safe.left + 6, 6, safe.right + 6, safe.bottom + 6),
          child: Center(child: body),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final DockItem item;
  final Color ink, accent;
  const _DockButton({required this.item, required this.ink, required this.accent});

  @override
  Widget build(BuildContext context) {
    final on = item.selected;
    return Tooltip(
      message: item.tooltip,
      // A hold is the tool's options; the name shows on hover.
      triggerMode: item.onOptions == null
          ? TooltipTriggerMode.longPress
          : TooltipTriggerMode.manual,
      child: Material(
        color: on ? accent.withValues(alpha: .14) : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => on && item.onOptions != null
              ? item.onOptions!(context)
              : item.onTap(context),
          onLongPress:
              item.onOptions == null ? null : () => item.onOptions!(context),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(item.icon, size: 22, color: on ? accent : ink),
          ),
        ),
      ),
    );
  }
}

/// A scrolling row (or column) that fades out at whichever end has more to
/// show.
class EdgeFadeScroll extends StatefulWidget {
  final Axis axis;
  final Color color;
  final Widget child;
  const EdgeFadeScroll(
      {super.key, required this.axis, required this.color, required this.child});

  @override
  State<EdgeFadeScroll> createState() => _EdgeFadeScrollState();
}

class _EdgeFadeScrollState extends State<EdgeFadeScroll> {
  final _ctrl = ScrollController();
  bool _before = false, _after = false;

  void _measure() {
    if (!_ctrl.hasClients) return;
    final p = _ctrl.position;
    final before = p.pixels > 1, after = p.pixels < p.maxScrollExtent - 1;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final vertical = widget.axis == Axis.vertical;
    Widget fade(bool start) => IgnorePointer(
          child: Container(
            width: vertical ? double.infinity : 22,
            height: vertical ? 22 : double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: vertical
                    ? (start ? Alignment.topCenter : Alignment.bottomCenter)
                    : (start ? Alignment.centerLeft : Alignment.centerRight),
                end: vertical
                    ? (start ? Alignment.bottomCenter : Alignment.topCenter)
                    : (start ? Alignment.centerRight : Alignment.centerLeft),
                colors: [widget.color, widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _measure();
          return false;
        },
        child: Stack(children: [
          SingleChildScrollView(
            controller: _ctrl,
            scrollDirection: widget.axis,
            child: widget.child,
          ),
          if (_before)
            vertical
                ? Positioned(top: 0, left: 0, right: 0, child: fade(true))
                : Positioned(top: 0, bottom: 0, left: 0, child: fade(true)),
          if (_after)
            vertical
                ? Positioned(bottom: 0, left: 0, right: 0, child: fade(false))
                : Positioned(top: 0, bottom: 0, right: 0, child: fade(false)),
        ]),
      ),
    );
  }
}
