import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/keymap.dart';
import '../../core/settings.dart';

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

  /// Whether the keys held now zoom (Ctrl, unless it's been changed).
  static bool Function() zoomHeld = () =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

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

  /// By [f], about [global]: the point under it stays under it.
  void _zoomAbout(Offset global, double f) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.globalToLocal(global);
    // Kept to 1×–max before moving about the point: past the end the step
    // is nothing, not a shift (clamping the scale after left the shift of
    // the bigger one, and the page slid away at full zoom).
    final now = _t.value.getMaxScaleOnAxis();
    f = (now * f).clamp(1.0, MushafZoom.maxScale) / now;
    if ((f - 1).abs() < 1e-6) return;
    final next = Matrix4.identity()
      ..translateByDouble(at.dx, at.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-at.dx, -at.dy, 0, 1)
      ..multiply(_t.value);
    _t.value = _clamp(next, box.size);
    final zoomed = _t.value.getMaxScaleOnAxis() > 1.001;
    if (zoomed != widget.active) widget.onActive(zoomed);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final zoomKey = MushafZoom.zoomHeld();
    if (!zoomKey && !widget.active) return;
    // A trackpad's scrolling, zoomed: the viewer moves the page for that.
    if (!zoomKey && e.kind == PointerDeviceKind.trackpad) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (e) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final d = (e as PointerScrollEvent).scrollDelta;
      if (zoomKey) {
        _zoomAbout(e.position, d.dy > 0 ? 1 / 1.12 : 1.12);
      } else {
        _t.value = _clamp(
          Matrix4.identity()
            ..translateByDouble(-d.dx, -d.dy, 0, 1)
            ..multiply(_t.value),
          box.size,
        );
      }
    });
  }

  // ── a trackpad: two fingers up and down with the zoom key, or a pinch ──

  double _pinch = 1;

  void _panZoomUpdate(PointerPanZoomUpdateEvent e) {
    if (MushafZoom.zoomHeld()) {
      // As the wheel goes: scrolling up zooms in.
      if (e.panDelta.dy != 0) _zoomAbout(e.position, math.exp(e.panDelta.dy / 150));
    } else if (!widget.active && e.scale != _pinch && _pinch > 0) {
      // (Zoomed, the viewer has the pinch.)
      _zoomAbout(e.position, e.scale / _pinch);
    }
    _pinch = e.scale;
  }

  // ── Ctrl and the wheel's button, dragged: the zoomed page moves ──

  bool _panning = false;

  bool _isPan(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return false;
    final keymap = SettingsScope.maybeOf(context)?.keymap;
    if (keymap != null) return keymap.mouseActionFor(e.buttons) == MouseAction.pan;
    return e.buttons == kMiddleMouseButton && MushafZoom.zoomHeld();
  }

  void _panBy(Offset d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _t.value = _clamp(
      Matrix4.identity()
        ..translateByDouble(d.dx, d.dy, 0, 1)
        ..multiply(_t.value),
      box.size,
    );
  }

  // The viewer mustn't also move the page while the zoom key's held.
  bool _held = false;

  bool _onKey(KeyEvent _) {
    final now = MushafZoom.zoomHeld();
    if (now != _held && mounted) setState(() => _held = now);
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inside the viewer, so it's asked before the viewer's own wheel zoom.
    final pages = Listener(
      onPointerDown: (e) => _panning = widget.active && _isPan(e),
      onPointerMove: (e) {
        if (_panning) _panBy(e.delta);
      },
      onPointerUp: (_) => _panning = false,
      onPointerCancel: (_) => _panning = false,
      onPointerSignal: _onSignal,
      onPointerPanZoomStart: (_) => _pinch = 1,
      onPointerPanZoomUpdate: _panZoomUpdate,
      child: widget.child,
    );
    if (!widget.active) return pages;
    return InteractiveViewer(
      transformationController: _t,
      minScale: 1,
      maxScale: MushafZoom.maxScale,
      panEnabled: !_held,
      // The wheel is [_onSignal]'s: left alone it would zoom out here too.
      scaleFactor: double.maxFinite,
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
    if (MushafZoom.zoomHeld()) return false;
    return super.shouldAcceptUserOffset(position);
  }
}
