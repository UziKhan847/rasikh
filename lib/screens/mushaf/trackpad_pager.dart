import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Turns the desktop muṣḥaf's pages with a two-finger horizontal swipe on a
/// trackpad (Linux, Windows, macOS send it as a pan gesture), a sideways
/// scroll (a tilting wheel, or a trackpad the system reports as
/// scrolling), or a finger or pen swiping across the screen (a tablet in
/// the desktop layout): one turn per swipe. As on a phone, the page follows the
/// fingers — a swipe to the right turns forward (the muṣḥaf reads right to
/// left), to the left back.
class TrackpadPager extends StatefulWidget {
  /// +1 forward, −1 back.
  final void Function(int dir) onTurn;
  final Widget child;
  const TrackpadPager({super.key, required this.onTurn, required this.child});

  /// How far a swipe goes before it turns the page, in logical pixels.
  static const threshold = 60.0;

  @override
  State<TrackpadPager> createState() => _TrackpadPagerState();
}

class _TrackpadPagerState extends State<TrackpadPager> {
  bool _turned = false;

  // Scrolling has no start or end: a pause ends a swipe.
  double _scrolled = 0;
  bool _scrollTurned = false;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _pan(Offset pan) {
    if (_turned) return;
    if (pan.dx.abs() < TrackpadPager.threshold ||
        pan.dx.abs() < pan.dy.abs() * 1.5) {
      return;
    }
    _turned = true;
    widget.onTurn(pan.dx > 0 ? 1 : -1);
  }

  // A finger's swipe: how far it has gone across.
  double _dragged = 0;

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dx = _dragged;
    _dragged = 0;
    if (dx.abs() >= TrackpadPager.threshold || v.abs() > 400) {
      widget.onTurn((dx.abs() >= TrackpadPager.threshold ? dx : v) > 0 ? 1 : -1);
    }
  }

  void _scroll(PointerScrollEvent e) {
    final d = e.scrollDelta;
    if (d.dx.abs() <= d.dy.abs()) return;
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 220), () {
      _scrolled = 0;
      _scrollTurned = false;
    });
    if (_scrollTurned) return;
    // Scrolling moves the view, so the fingers went the other way.
    _scrolled -= d.dx;
    if (_scrolled.abs() < TrackpadPager.threshold) return;
    _scrollTurned = true;
    widget.onTurn(_scrolled > 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => Listener(
    // Over the margins around the pages too.
    behavior: HitTestBehavior.translucent,
    onPointerPanZoomStart: (_) => _turned = false,
    onPointerPanZoomUpdate: (e) => _pan(e.pan),
    onPointerPanZoomEnd: (_) => _turned = false,
    onPointerSignal: (e) {
      if (e is PointerScrollEvent) _scroll(e);
    },
    // Touch and pen only: a mouse dragging across mustn't turn pages.
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      },
      onHorizontalDragStart: (_) => _dragged = 0,
      onHorizontalDragUpdate: (d) => _dragged += d.delta.dx,
      onHorizontalDragEnd: _dragEnd,
      onHorizontalDragCancel: () => _dragged = 0,
      child: widget.child,
    ),
  );
}
