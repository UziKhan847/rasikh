import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'mushaf_zoom.dart';

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

/// Turns pages with a mouse wheel: down is the next page, up the one before.
/// Asks after whatever's inside it: a page that can still scroll, or zoom, has
/// the wheel first. Ctrl (⌘) and the wheel are zoom's, always.
class WheelPager extends StatefulWidget {
  /// +1 forward, −1 back.
  final void Function(int dir) onTurn;
  final Widget child;

  /// Two fingers up and down on a trackpad turn the page too (not when the page
  /// itself scrolls, or is zoomed).
  final bool trackpadTurns;

  /// A mouse's button pressed: +1 or −1 if it turns the page.
  final int? Function(int buttons)? turnOfButton;
  const WheelPager(
      {super.key,
      required this.onTurn,
      required this.child,
      this.trackpadTurns = true,
      this.turnOfButton});

  /// A wheel's notch is at least this; a trackpad's scrolling comes in far
  /// smaller steps.
  static const notch = 30.0;

  /// The least between two notches' turns.
  static const cooldown = Duration(milliseconds: 180);

  @override
  State<WheelPager> createState() => _WheelPagerState();
}

class _WheelPagerState extends State<WheelPager> {
  double _smooth = 0;
  bool _smoothTurned = false;
  Timer? _idle;
  final _since = Stopwatch();
  bool _panTurned = false;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    if (MushafZoom.zoomHeld()) return;
    if (e.scrollDelta.dy.abs() <= e.scrollDelta.dx.abs()) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (e) {
      _wheel((e as PointerScrollEvent).scrollDelta.dy);
    });
  }

  void _wheel(double dy) {
    // A wheel's notch: a turn each, spun as fast as the cooldown lets it.
    if (dy.abs() >= WheelPager.notch) {
      if (_since.isRunning && _since.elapsed < WheelPager.cooldown) return;
      _since
        ..reset()
        ..start();
      widget.onTurn(dy > 0 ? 1 : -1);
      return;
    }
    // Small steps with no end to them (a trackpad, with its inertia): one
    // turn, until they pause.
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 220), () {
      _smooth = 0;
      _smoothTurned = false;
    });
    if (_smoothTurned) return;
    _smooth += dy;
    if (_smooth.abs() < WheelPager.notch) return;
    _smoothTurned = true;
    widget.onTurn(_smooth > 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: _signal,
        onPointerDown: (e) {
          if (e.kind != PointerDeviceKind.mouse) return;
          final dir = widget.turnOfButton?.call(e.buttons);
          if (dir != null) widget.onTurn(dir);
        },
        onPointerPanZoomStart: (_) => _panTurned = false,
        onPointerPanZoomUpdate: (e) {
          if (_panTurned || !widget.trackpadTurns || MushafZoom.zoomHeld()) return;
          final d = e.pan;
          if (d.dy.abs() < TrackpadPager.threshold || d.dy.abs() < d.dx.abs() * 1.5) return;
          _panTurned = true;
          // Fingers moving the page up: on, as scrolling down is.
          widget.onTurn(d.dy < 0 ? 1 : -1);
        },
        child: widget.child,
      );
}

/// A pager that doesn't take scroll events itself. Left to it, each one nudges
/// the page a little and snaps back, so the page shakes, and one arriving during
/// a turn cancels the turn. Drags are unaffected: whether a pager can be dragged
/// is only asked as it's laid out, whether a scroll is taken as the event arrives,
/// between frames.
class NoPointerScrollPhysics extends ScrollPhysics {
  const NoPointerScrollPhysics({super.parent});

  @override
  NoPointerScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      NoPointerScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle &&
      super.shouldAcceptUserOffset(position);
}

/// Sideways scrolling over the pages (a tilting wheel, or a trackpad the system
/// reports as scrolling): one turn per swipe.
class SidewaysScroll {
  final void Function(int dir) onTurn;

  /// Whether to leave it (zoomed: it moves about the page).
  final bool Function() standAside;
  SidewaysScroll({required this.onTurn, required this.standAside});

  double _scrolled = 0;
  bool _turned = false;
  Timer? _idle;

  void signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || standAside() || MushafZoom.zoomHeld()) return;
    if (e.scrollDelta.dx.abs() <= e.scrollDelta.dy.abs()) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (e) {
      final dx = (e as PointerScrollEvent).scrollDelta.dx;
      _idle?.cancel();
      _idle = Timer(const Duration(milliseconds: 220), () {
        _scrolled = 0;
        _turned = false;
      });
      if (_turned) return;
      // Scrolling moves the view, so the fingers went the other way.
      _scrolled -= dx;
      if (_scrolled.abs() < TrackpadPager.threshold) return;
      _turned = true;
      onTurn(_scrolled > 0 ? 1 : -1);
    });
  }

  void dispose() => _idle?.cancel();
}
