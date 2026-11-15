import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/jank_watch.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';

const _budget = Duration(microseconds: 16667); // 60 Hz

/// A frame that took [buildMs] to build and [rasterMs] to raster.
FrameTiming _frame(double buildMs, double rasterMs) {
  final b = (buildMs * 1000).round(), r = (rasterMs * 1000).round();
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: b,
    rasterStart: b,
    rasterFinish: b + r,
    rasterFinishWallTime: b + r,
  );
}

/// One app run: the warm-up, then a sample with [slowShare] of slow frames.
List<FrameTiming> _run(double slowShare) {
  final n = JankWatch.sample;
  final slow = (n * slowShare).round();
  return [
    for (var i = 0; i < JankWatch.warmUp; i++) _frame(80, 80), // ignored
    for (var i = 0; i < n; i++) i < slow ? _frame(30, 8) : _frame(6, 8),
  ];
}

void main() {
  test('a slow frame misses its slot by half a frame or more', () {
    expect(JankWatch.isSlowFrame(const Duration(milliseconds: 20),
        const Duration(milliseconds: 5), _budget), isFalse);
    expect(JankWatch.isSlowFrame(const Duration(milliseconds: 5),
        const Duration(milliseconds: 26), _budget), isTrue);
    expect(JankWatch.isSlowRun(120, 600), isFalse); // exactly 20%
    expect(JankWatch.isSlowRun(121, 600), isTrue);
    expect(JankWatch.isSlowRun(500, 599), isFalse); // not a full sample
  });

  testWidgets('the second slow run offers Lite mode, once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const Scaffold(body: SizedBox()),
    ));

    Future<void> run(double share) async {
      final w = JankWatch.detached(s, _budget)..feed(_run(share));
      await tester.runAsync(() async => w.judged);
      await tester.pump();
    }

    await run(.05); // a fine run: nothing
    await run(.4); // first slow run: counted, no offer yet
    expect(find.byType(SnackBar), findsNothing);
    expect(s.liteSuggested, isFalse);

    await run(.4); // second slow run: the offer
    expect(find.text('This device seems slow — turn on Lite mode?'),
        findsOneWidget);
    expect(s.liteSuggested, isTrue);
    await tester.pump(const Duration(milliseconds: 500)); // slid in
    await tester.tap(find.text('Turn on'));
    await tester.pump();
    expect(s.lite, isTrue);

    // Never again, and not watched at all once made.
    expect(JankWatch.start(s), isNull);
    await tester.pump(const Duration(seconds: 1)); // the settings save
  });
}
