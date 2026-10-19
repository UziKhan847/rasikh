import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Performance logging: on in profile builds (`flutter run --profile`) or
/// with `--dart-define=MUSHAF_PERF=true`; compiled out of release builds.
/// Prints lines starting with `[perf]`:
///   * every frame that misses the display's budget, split into the UI
///     thread's build/layout time and the raster (GPU) thread's time, with
///     what the UI thread did in that frame (text lines shaped and the time
///     it took, pages built, screen rebuilds, background tasks) and whether a
///     finger was dragging;
///   * each muṣḥaf page's first layout;
///   * page changes and background page preparation.
const kMushafPerf = bool.fromEnvironment('MUSHAF_PERF') || kProfileMode;

abstract final class PerfLog {
  static bool _started = false;

  /// What's on screen, for the frame lines (e.g. "muṣḥaf p.51").
  static String where = 'app';

  /// What the user is doing: 'idle', 'dragging' or 'settling'.
  static String phase = 'idle';

  static int _frames = 0, _slow = 0;
  static double _worstBuild = 0, _worstRaster = 0;
  static double _budgetMs = 1000 / 60;

  // ── per-frame counters, filed under the frame they happened in ──
  static _Bucket _cur = _Bucket();
  static final Map<int, _Bucket> _byFrame = {};
  // The frame just drawn, for work done in its post-frame callbacks.
  static _Bucket? _last;
  static int _lastN = -1;
  static bool _post = false;

  static _Bucket get _bucket {
    final last = _last;
    if (!_post || last == null) return _cur;
    _byFrame[_lastN] = last;
    return last;
  }

  /// Runs [work] after a frame (in a post-frame callback), filing what it
  /// does under that frame — its time counts in that frame's UI time.
  static void afterFrame(VoidCallback work) {
    _post = true;
    try {
      work();
    } finally {
      _post = false;
    }
  }

  static void start() {
    if (!kMushafPerf || _started) return;
    _started = true;
    final displays = SchedulerBinding.instance.platformDispatcher.displays;
    final hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    _budgetMs = 1000 / (hz < 30 ? 60 : hz);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Runs at the end of every frame (after build, layout and paint): files
    // what happened under this frame's number for the timings callback.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      final n = SchedulerBinding.instance.platformDispatcher.frameData
          .frameNumber;
      if (_cur.any) _byFrame[n] = _cur;
      if (_byFrame.length > 120) _byFrame.remove(_byFrame.keys.first);
      _last = _cur;
      _lastN = n;
      _cur = _Bucket();
    });
    log('logging on — ${hz.toStringAsFixed(0)} Hz display, frame budget '
        '${_budgetMs.toStringAsFixed(1)} ms; accessibility semantics '
        '${SemanticsBinding.instance.semanticsEnabled ? 'ON (every build '
            'costs more)' : 'off'}');
  }

  static void log(String msg) {
    if (kMushafPerf) {
      // ignore: avoid_print
      print('[perf] $msg');
    }
  }

  // ── counters ──

  /// A text line was shaped ([what]: 'measure', 'line' or 'highlight').
  static void shaped(String what, int us) {
    if (!kMushafPerf) return;
    final b = _bucket;
    b.shaped[what] = (b.shaped[what] ?? 0) + 1;
    b.shapeUs += us;
  }

  /// A line was laid out from the glyph atlas (no shaping).
  static void atlasLine(int us) {
    if (!kMushafPerf) return;
    final b = _bucket;
    b.atlasLines++;
    b.atlasUs += us;
  }

  static void pageBuilt() {
    if (kMushafPerf) _cur.pages++;
  }

  static void screenBuilt() {
    if (kMushafPerf) _cur.screens++;
  }

  static void task(int us) {
    if (!kMushafPerf) return;
    final b = _bucket;
    b.tasks++;
    b.taskUs += us;
  }

  static String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      final build = t.buildDuration.inMicroseconds / 1000;
      final raster = t.rasterDuration.inMicroseconds / 1000;
      if (build > _worstBuild) _worstBuild = build;
      if (raster > _worstRaster) _worstRaster = raster;
      final b = _byFrame.remove(t.frameNumber);
      if (build > _budgetMs || raster > _budgetMs) {
        _slow++;
        log('SLOW frame: ui ${_ms(t.buildDuration)} ms, raster '
            '${_ms(t.rasterDuration)} ms, total ${_ms(t.totalSpan)} ms  '
            '[$where, ${b?.phase ?? phase}]'
            '${b == null ? '' : '  ${b.describe()}'}');
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

  static void pageLaidOut(int page, int layoutUs) {
    log('page $page layout ${(layoutUs / 1000).toStringAsFixed(1)} ms'
        '${pageFontSize == null ? '' : ', font ${pageFontSize!.toStringAsFixed(1)} px'}');
  }

  /// The font size of the last page laid out (each distinct size costs the
  /// renderer a fresh set of glyph images).
  static double? pageFontSize;
}

class _Bucket {
  final Map<String, int> shaped = {};
  int shapeUs = 0, pages = 0, screens = 0, tasks = 0, taskUs = 0;
  int atlasLines = 0, atlasUs = 0;
  final String phase = PerfLog.phase;

  bool get any =>
      shaped.isNotEmpty || pages > 0 || screens > 0 || tasks > 0 || atlasLines > 0;

  String describe() {
    final parts = <String>[];
    if (shaped.isNotEmpty) {
      parts.add('shaped ${shaped.entries.map((e) => '${e.value} ${e.key}').join(' + ')} '
          'lines in ${(shapeUs / 1000).toStringAsFixed(1)} ms');
    }
    if (atlasLines > 0) {
      parts.add('$atlasLines atlas lines in '
          '${(atlasUs / 1000).toStringAsFixed(1)} ms');
    }
    if (pages > 0) parts.add('$pages page builds');
    if (screens > 0) parts.add('$screens muṣḥaf screen builds');
    if (tasks > 0) {
      parts.add('$tasks background tasks '
          '(${(taskUs / 1000).toStringAsFixed(1)} ms)');
    }
    return parts.join(', ');
  }
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
