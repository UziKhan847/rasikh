import 'package:flutter/material.dart';

/// The two halves of a drag-and-drop activity, shared by every one in the app
/// (the quiz's "drag the shape onto the gap").
///
/// **A drag is never the only way.** Every activity built on these also
/// completes by tap — a child who cannot yet drag accurately still finishes
/// it, and assistive technology, which has no notion of a drag, still can. So
/// [DragTile] carries no tap handling of its own: wrap the child in a
/// `TapScale` (or whatever) and the two gestures share the arena — a tap that
/// never moves wins, a press that moves past the touch slop becomes a drag.
///
/// **A drop is never judged here.** [DropSlot] takes every drop and hands the
/// payload to its owner, which decides right or wrong exactly as it does for a
/// tap — so a wrong drop goes through the same feedback path as a wrong tap,
/// and the tile simply stays where it was.
class DragTile<T extends Object> extends StatefulWidget {
  /// What the drop target receives.
  final T data;
  final Widget child;

  /// What follows the finger; defaults to [child]. It is given the source
  /// tile's own size, since an overlay would otherwise hand it the whole
  /// screen to fill.
  final Widget? feedback;

  /// False while the activity is finished or the tile is spent: the child is
  /// returned as it is, with no drag recogniser at all.
  final bool enabled;

  const DragTile({
    super.key,
    required this.data,
    required this.child,
    this.feedback,
    this.enabled = true,
  });

  @override
  State<DragTile<T>> createState() => _DragTileState<T>();
}

class _DragTileState<T extends Object> extends State<DragTile<T>> {
  final _key = GlobalKey();

  Widget _feedback() => Builder(
    builder: (_) {
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      Widget c = widget.feedback ?? widget.child;
      if (box != null && box.hasSize) {
        c = SizedBox(width: box.size.width, height: box.size.height, child: c);
      }
      return Material(
        type: MaterialType.transparency,
        // Lifted a little: it reads as picked up, and its edges stay visible
        // around a fingertip.
        child: Transform.scale(scale: 1.1, child: c),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final tile = KeyedSubtree(key: _key, child: widget.child);
    if (!widget.enabled) return tile;
    return Draggable<T>(
      data: widget.data,
      maxSimultaneousDrags: 1,
      feedback: _feedback(),
      childWhenDragging: Opacity(opacity: .3, child: tile),
      child: tile,
    );
  }
}

/// Where a [DragTile] can be dropped. Accepts every drop of type [T] and calls
/// [onDrop] with it — the owner grades it, the same way it grades a tap.
///
/// [builder] is handed the payload of the tile currently hovering over the
/// slot — null when none is — so it can light up (see [DropGlow]).
class DropSlot<T extends Object> extends StatelessWidget {
  final void Function(T data) onDrop;
  final Widget Function(BuildContext context, T? hovering) builder;

  /// False once the activity no longer wants drops (it is finished, or the
  /// slot is already filled): a hovering tile then does not light it up.
  final bool enabled;

  /// Turns away a tile that could never belong here — a tile held over its own
  /// slot — so the slot neither lights up nor takes the drop. Unlike a WRONG
  /// drop, which is taken and graded, this one is not an attempt at all.
  final bool Function(T data)? accepts;

  const DropSlot({
    super.key,
    required this.onDrop,
    required this.builder,
    this.enabled = true,
    this.accepts,
  });

  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onWillAcceptWithDetails: (d) => enabled && (accepts?.call(d.data) ?? true),
    onAcceptWithDetails: (d) => onDrop(d.data),
    builder: (context, candidates, _) => builder(
      context,
      enabled && candidates.isNotEmpty ? candidates.first : null,
    ),
  );
}

/// A soft outline and a small swell around [child] while a tile hovers over it
/// — "yes, here". Purely visual; put it inside a [DropSlot] builder.
class DropGlow extends StatelessWidget {
  final bool hovering;
  final Color color;
  final double radius;
  final Widget child;
  const DropGlow({
    super.key,
    required this.hovering,
    required this.color,
    required this.child,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: hovering ? 1.03 : 1,
    duration: const Duration(milliseconds: 120),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: hovering ? color : Colors.transparent,
          width: 3,
        ),
      ),
      child: child,
    ),
  );
}
