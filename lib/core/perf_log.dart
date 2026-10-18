import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Opt-in performance logging for the muṣḥaf, compiled out unless the app is
/// built with `--dart-define=MUSHAF_PERF=true`. Prints lines starting with
/// `[perf]`:
///   * every frame that misses the 120 Hz budget (8.3 ms), split into the UI
///     thread's build/layout time and the raster (GPU) thread's time;
///   * each page's first layout, and how much of it was spent measuring text;
///   * page changes.
const kMushafPerf = bool.fromEnvironment('MUSHAF_PERF');

abstract final class PerfLog {
  static bool _started = false;

  /// What's on screen, for the frame lines (e.g. "page 51").
  static String where = '';

  static int _frames = 0, _slow = 0;
  static double _worstBuild = 0, _worstRaster = 0;

  static void start() {
    if (!kMushafPerf || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    log('logging on — frame budget 8.3 ms (120 Hz)');
  }

  static void log(String msg) {
    if (kMushafPerf) {
      // ignore: avoid_print
      print('[perf] $msg');
    }
  }

  static String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      final build = t.buildDuration.inMicroseconds / 1000;
      final raster = t.rasterDuration.inMicroseconds / 1000;
      if (build > _worstBuild) _worstBuild = build;
      if (raster > _worstRaster) _worstRaster = raster;
      if (build > 8.3 || raster > 8.3) {
        _slow++;
        log('SLOW frame: ui ${_ms(t.buildDuration)} ms, raster '
            '${_ms(t.rasterDuration)} ms, total ${_ms(t.totalSpan)} ms  ($where)');
      }
      if (_frames % 240 == 0) {
        log('summary: $_frames frames, $_slow slow; worst ui '
            '${_worstBuild.toStringAsFixed(1)} ms, worst raster '
            '${_worstRaster.toStringAsFixed(1)} ms');
        _worstBuild = 0;
        _worstRaster = 0;
      }
    }
  }

  // ── per-page text measuring, folded into the page's layout line ──

  static final Map<int, _PageStats> _pages = {};

  static void measured(int page, String what, Stopwatch sw, int lines) {
    if (!kMushafPerf) return;
    final s = _pages.putIfAbsent(page, _PageStats.new);
    s.us += sw.elapsedMicroseconds;
    s.parts[what] = (s.parts[what] ?? 0) + lines;
  }

  static void pageLaidOut(int page, int layoutUs) {
    final s = _pages.remove(page);
    final measuring = s == null
        ? ''
        : ' — measuring text ${(s.us / 1000).toStringAsFixed(1)} ms '
            '(${s.parts.entries.map((e) => '${e.key} ${e.value}').join(', ')})';
    log('page $page layout ${(layoutUs / 1000).toStringAsFixed(1)} ms$measuring');
  }
}

class _PageStats {
  int us = 0;
  final Map<String, int> parts = {};
}

/// Times its child's layout and reports it for [page] (only when it takes
/// more than half a millisecond, i.e. a real first layout, not a no-op).
class PerfLayoutTimer extends SingleChildRenderObjectWidget {
  final int page;
  const PerfLayoutTimer({super.key, required this.page, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPerfLayoutTimer(page);

  @override
  void updateRenderObject(
          BuildContext context, RenderPerfLayoutTimer renderObject) =>
      renderObject.page = page;
}

class RenderPerfLayoutTimer extends RenderProxyBox {
  int page;
  RenderPerfLayoutTimer(this.page);

  @override
  void performLayout() {
    final sw = Stopwatch()..start();
    super.performLayout();
    sw.stop();
    if (sw.elapsedMicroseconds > 500) {
      PerfLog.pageLaidOut(page, sw.elapsedMicroseconds);
    }
  }
}
