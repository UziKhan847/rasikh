import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A small panel beside the button that opened it — a toolbar's second
/// row of options, or a list to jump from — in place of a sheet: lighter,
/// and the page stays in view. It opens on [side] of [anchor] (the button's
/// context)
/// (above a bottom toolbar's, left of a side toolbar's, below a header's),
/// kept on screen; back or a tap elsewhere closes it.
Future<T?> showToolPopover<T>(
  BuildContext context, {
  required BuildContext anchor,
  required AxisDirection side,
  required WidgetBuilder builder,
  double maxWidth = 380,
  double maxHeight = 460,
  bool waitForExit = false,
}) async {
  final box = anchor.findRenderObject() as RenderBox?;
  final nav = Navigator.of(context);
  final overlay = nav.overlay?.context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null || !box.attached) return null;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final route = _PopoverRoute<T>(
    anchor: rect,
    side: side,
    builder: builder,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
  );
  final result = await nav.push(route);
  if (waitForExit) await route.completed;
  return result;
}

/// A popover listing [count] items, opened already scrolled to [selected]
/// (centred where it can be): the index of the one picked, or null. Built
/// lazily — a list of 604 pages costs the dozen rows on screen.
Future<int?> showAnchoredList(
  BuildContext context, {
  required BuildContext anchor,
  required AxisDirection side,
  required int count,
  required int selected,
  required Widget Function(BuildContext context, int i, bool selected) item,
  double itemExtent = 48,
  double width = 300,
  double maxHeight = 400,
  bool waitForExit = true,
}) =>
    showToolPopover<int>(
      context,
      anchor: anchor,
      side: side,
      maxWidth: width,
      maxHeight: maxHeight,
      waitForExit: waitForExit,
      builder: (popover) {
        final h = (count * itemExtent).clamp(0.0, maxHeight);
        final offset = (selected * itemExtent - h / 2 + itemExtent / 2)
            .clamp(0.0, (count * itemExtent - h).clamp(0.0, double.infinity));
        return SizedBox(
          width: width,
          height: h,
          child: ListView.builder(
            controller: ScrollController(initialScrollOffset: offset),
            itemExtent: itemExtent,
            itemCount: count,
            padding: EdgeInsets.zero,
            itemBuilder: (c, i) => InkWell(
              onTap: () => Navigator.of(c).pop(i),
              child: item(c, i, i == selected),
            ),
          ),
        );
      },
    );

class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({
    required this.anchor,
    required this.side,
    required this.builder,
    required this.maxWidth,
    required this.maxHeight,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final AxisDirection side;
  final WidgetBuilder builder;
  final double maxWidth, maxHeight;
  final CapturedThemes capturedThemes;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final mq = MediaQuery.of(context);
    final p = pal(context);
    return capturedThemes.wrap(CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor, side, mq.padding),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Material(
          color: p.card,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Builder(builder: builder),
        ),
      ),
    ));
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final from = switch (side) {
      AxisDirection.up => const Offset(0, .04),
      AxisDirection.down => const Offset(0, -.04),
      AxisDirection.left => const Offset(.04, 0),
      AxisDirection.right => const Offset(-.04, 0),
    };
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
          position: Tween(begin: from, end: Offset.zero).animate(a),
          child: child),
    );
  }
}

/// Places the panel on its side of the anchor, 8 px off it and 8 px inside
/// the screen's safe area.
class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final AxisDirection side;
  final EdgeInsets safe;
  const _PopoverLayout(this.anchor, this.side, this.safe);

  static const _gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = safe.deflateSize(constraints.biggest);
    final w = switch (side) {
      AxisDirection.left => anchor.left - safe.left - 2 * _gap,
      AxisDirection.right => constraints.maxWidth - safe.right - anchor.right - 2 * _gap,
      _ => room.width - 2 * _gap,
    };
    final h = switch (side) {
      AxisDirection.up => anchor.top - safe.top - 2 * _gap,
      AxisDirection.down => constraints.maxHeight - safe.bottom - anchor.bottom - 2 * _gap,
      _ => room.height - 2 * _gap,
    };
    return BoxConstraints.loose(Size(w.clamp(0.0, double.infinity), h.clamp(0.0, double.infinity)));
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) =>
        x.clamp(safe.left + _gap, (size.width - safe.right - _gap - child.width).clamp(safe.left + _gap, double.infinity));
    double clampY(double y) =>
        y.clamp(safe.top + _gap, (size.height - safe.bottom - _gap - child.height).clamp(safe.top + _gap, double.infinity));
    return switch (side) {
      AxisDirection.up => Offset(clampX(anchor.center.dx - child.width / 2),
          clampY(anchor.top - _gap - child.height)),
      AxisDirection.down => Offset(clampX(anchor.center.dx - child.width / 2),
          clampY(anchor.bottom + _gap)),
      AxisDirection.left => Offset(clampX(anchor.left - _gap - child.width),
          clampY(anchor.center.dy - child.height / 2)),
      AxisDirection.right => Offset(clampX(anchor.right + _gap),
          clampY(anchor.center.dy - child.height / 2)),
    };
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.side != side || old.safe != safe;
}
