import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../kids_backdrops/kb_components.dart' show kbText;
import '../../kids_backdrops/kb_scene.dart' show kBlack, kWhite, kbC;

/// A developer's frame-time readout, shown only while the testing unlock is on
/// (see `KidsShell`): how long the last second's frames took to build (UI) and
/// to draw (GPU), and what share of them missed the display's deadline.
///
/// It reads the engine's own frame timings, so it works in profile and release
/// builds — the ones whose numbers mean anything on a slow phone.
class KidsFrameReadout extends StatefulWidget {
  const KidsFrameReadout({super.key});

  @override
  State<KidsFrameReadout> createState() => _KidsFrameReadoutState();
}

class _KidsFrameReadoutState extends State<KidsFrameReadout> {
  final _window = <FrameTiming>[];
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  String? _text;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _window.addAll(timings);
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(seconds: 1) ||
        _window.isEmpty ||
        !mounted) {
      return;
    }
    _last = now;
    final hz = View.of(context).display.refreshRate;
    final budget = 1000 / (hz > 0 ? hz : 60);
    double ms(Duration d) => d.inMicroseconds / 1000;
    final ui = _window.map((t) => ms(t.buildDuration)).toList();
    final gpu = _window.map((t) => ms(t.rasterDuration)).toList();
    final slow = [
      for (var i = 0; i < _window.length; i++)
        if (ui[i] > budget || gpu[i] > budget) i,
    ].length;
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    final text =
        'UI ${avg(ui).toStringAsFixed(1)} · GPU ${avg(gpu).toStringAsFixed(1)} ms'
        ' · ${(100 * slow / _window.length).round()}% slow'
        ' · ${_window.length} f';
    _window.clear();
    if (text != _text) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kbC(kBlack, .6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 2),
          child: Text(
            text,
            textDirection: TextDirection.ltr,
            style: kbText(12, kbC(kWhite), weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
