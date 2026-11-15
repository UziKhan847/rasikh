import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'settings.dart';

/// The app's root ScaffoldMessenger, so a message can show over whatever
/// screen is open.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Notices a device that struggles to keep up and, once, offers Lite mode.
///
/// It reads the engine's frame timings (no work of its own per frame beyond
/// counting). After a warm-up, a run of [sample] frames is judged: if more
/// than [slowShare] of them took over 1.5× the display's frame budget to
/// build or to raster, the run counts as slow. The second slow app run (they
/// needn't be consecutive) shows the offer. It's made once, whatever the
/// answer ([AppSettings.liteSuggested]), and never with Lite mode already on.
class JankWatch {
  static const warmUp = 120; // first frames: shader compiles, first layouts
  static const sample = 600;
  static const slowShare = .2;
  static const slowRunsToOffer = 2;
  static const _runsKey = 'jankSlowRuns';

  final AppSettings settings;
  final Duration budget;
  int _seen = 0, _counted = 0, _slow = 0;
  bool _done = false;

  final bool _hooked;

  JankWatch._(this.settings, this.budget) : _hooked = true;

  /// A watch not hooked to the engine; tests feed it timings.
  @visibleForTesting
  JankWatch.detached(this.settings, this.budget) : _hooked = false;

  /// The judged run's outcome is applied (tests can await it).
  Future<void>? judged;

  @visibleForTesting
  void feed(List<FrameTiming> timings) => _onTimings(timings);

  /// Starts watching, unless the offer has been made or Lite mode is on.
  static JankWatch? start(AppSettings settings) {
    if (settings.lite || settings.liteSuggested) return null;
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    final hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    final w = JankWatch._(settings,
        Duration(microseconds: (1e6 / (hz < 30 ? 60 : hz)).round()));
    SchedulerBinding.instance.addTimingsCallback(w._onTimings);
    return w;
  }

  /// Whether a frame that took [build] and [raster] missed its slot by a
  /// visible margin.
  static bool isSlowFrame(Duration build, Duration raster, Duration budget) {
    final limit = budget * 1.5;
    return build > limit || raster > limit;
  }

  /// Whether a run with [slow] slow frames out of [total] is a slow run.
  static bool isSlowRun(int slow, int total) =>
      total >= sample && slow > total * slowShare;

  void _onTimings(List<FrameTiming> timings) {
    if (_done) return;
    for (final t in timings) {
      if (++_seen <= warmUp) continue;
      _counted++;
      if (isSlowFrame(t.buildDuration, t.rasterDuration, budget)) _slow++;
    }
    if (_counted < sample) return;
    _done = true;
    if (_hooked) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    if (isSlowRun(_slow, _counted)) judged = _slowRun();
  }

  Future<void> _slowRun() async {
    final p = await SharedPreferences.getInstance();
    final runs = (p.getInt(_runsKey) ?? 0) + 1;
    await p.setInt(_runsKey, runs);
    if (runs < slowRunsToOffer || settings.lite || settings.liteSuggested) {
      return;
    }
    final messenger = rootMessengerKey.currentState;
    final context = rootMessengerKey.currentContext;
    if (messenger == null || context == null || !context.mounted) return;
    settings.update(() => settings.liteSuggested = true);
    messenger.showSnackBar(SnackBar(
      content: Text(context.l10n.liteSuggest),
      duration: const Duration(seconds: 10),
      persist: false,
      action: SnackBarAction(
        label: context.l10n.liteTurnOn,
        onPressed: () => settings.update(() => settings.lite = true),
      ),
    ));
  }
}
