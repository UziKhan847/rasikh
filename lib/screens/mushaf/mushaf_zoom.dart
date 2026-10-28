import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The pages, zoomable. Off, they're just the pages (swiped as ever). On
/// ([active]: the dock's zoom, which also stops the swipe), two fingers
/// pinch and one pans; a mouse wheel pans too, and a trackpad pinches.
///
/// With a mouse no mode is needed: Ctrl (⌘) and the wheel zoom about the
/// pointer from anywhere, turning zoom on ([onActive]) and — back at 1× —
/// off again.
class MushafZoom extends StatefulWidget {
  final bool active;
  final ValueChanged<bool> onActive;
  final TransformationController controller;

  /// The pages: kept by its key as zoom wraps and unwraps it, so the pager
  /// stays where it was.
  final Widget child;
  const MushafZoom({
    super.key,
    required this.active,
    required this.onActive,
    required this.controller,
    required this.child,
  });

  static const maxScale = 4.0;

  @override
  State<MushafZoom> createState() => _MushafZoomState();
}

class _MushafZoomState extends State<MushafZoom> {
  TransformationController get _t => widget.controller;

  /// [m], kept to the window: no smaller than it, no gap at an edge.
  Matrix4 _clamp(Matrix4 m, Size size) {
    final s = m.getMaxScaleOnAxis().clamp(1.0, MushafZoom.maxScale);
    final tx = m.getTranslation().x.clamp(size.width * (1 - s), 0.0);
    final ty = m.getTranslation().y.clamp(size.height * (1 - s), 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    final zoomKey = keys.isControlPressed || keys.isMetaPressed;
    if (!zoomKey && !widget.active) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (e) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final d = (e as PointerScrollEvent).scrollDelta;
      final m = _t.value.clone();
      if (zoomKey) {
        // About the pointer: the point under it stays under it.
        final at = box.globalToLocal(e.position);
        final f = d.dy > 0 ? 1 / 1.12 : 1.12;
        final next = Matrix4.identity()
          ..translateByDouble(at.dx, at.dy, 0, 1)
          ..scaleByDouble(f, f, 1, 1)
          ..translateByDouble(-at.dx, -at.dy, 0, 1)
          ..multiply(m);
        _t.value = _clamp(next, box.size);
        final zoomed = _t.value.getMaxScaleOnAxis() > 1.001;
        if (zoomed != widget.active) widget.onActive(zoomed);
      } else {
        _t.value = _clamp(
            Matrix4.identity()
              ..translateByDouble(-d.dx, -d.dy, 0, 1)
              ..multiply(m),
            box.size);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Inside the viewer, so it's asked before the viewer's own wheel zoom.
    final pages = Listener(onPointerSignal: _onSignal, child: widget.child);
    if (!widget.active) return pages;
    return InteractiveViewer(
      transformationController: _t,
      minScale: 1,
      maxScale: MushafZoom.maxScale,
      child: pages,
    );
  }
}

/// A scroll that stands aside while Ctrl (⌘) is held, so Ctrl and the
/// wheel reach [MushafZoom] rather than scrolling the page under it.
class CtrlYieldsScrollPhysics extends ScrollPhysics {
  const CtrlYieldsScrollPhysics({super.parent});

  @override
  CtrlYieldsScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CtrlYieldsScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) return false;
    return super.shouldAcceptUserOffset(position);
  }
}
