import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_choice_card.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_order_card.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// "Some things are at the top of the screen rather than centred." A lesson
/// card is handed the whole height of the screen, and a bare Column packs its
/// content to the TOP of it. The smoke test asserts a card does not overflow;
/// nothing asserted where it SITS — so this does.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  ),
);

void _tallPhone(WidgetTester tester) {
  // A 360×800 phone, the shape most children's devices are today.
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// How far the vertical middle of [finder]'s union is from the middle of the
/// screen's usable area (below the step caption, above the bottom padding).
double _offCentre(WidgetTester tester, Finder top, Finder bottom) {
  final t = tester.getTopLeft(top.first).dy;
  final b = tester.getBottomRight(bottom.last).dy;
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return ((t + b) / 2 - screen / 2).abs();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a short check sits in the middle of a tall phone, not the top', (
    tester,
  ) async {
    useReducedMotion(tester);
    _tallPhone(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsLessonScaffold(
          index: 0,
          total: 3,
          done: false,
          child: KidsChoiceCard(
            prompt: 'Which one?',
            options: [for (var i = 0; i < 4; i++) Text('option $i')],
            correct: 1,
            onDone: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // The prompt is well below the top: the block is centred, not packed.
    final top = tester.getTopLeft(find.text('Which one?')).dy;
    expect(top, greaterThan(150), reason: 'packed to the top: prompt at $top');
    // And the block as a whole is near the middle of the screen.
    expect(
      _offCentre(
        tester,
        find.text('Which one?'),
        find.textContaining('option'),
      ),
      lessThan(60),
    );
  });

  testWidgets('the step caption clears the status bar, beside the back button', (
    tester,
  ) async {
    useReducedMotion(tester);
    _tallPhone(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsLessonScaffold(
          index: 2,
          total: 9,
          done: false,
          child: SizedBox(),
        ),
      ),
    );
    await tester.pump();
    final caption = find.text('Step 3 of 9');
    // Flush to the top (0) was the bug: there is a gap above it now.
    expect(tester.getTopLeft(caption).dy, greaterThanOrEqualTo(10));
    // The design's lesson header: the round back button, then the step.
    final back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    expect(tester.getCenter(caption).dy,
        closeTo(tester.getCenter(back).dy, 4));
    expect(tester.getTopLeft(caption).dx,
        greaterThan(tester.getTopRight(back).dx));
  });

  testWidgets('a long card still scrolls instead of overflowing', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(640, 1136); // 320×568
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsLessonScaffold(
          index: 0,
          total: 3,
          done: false,
          child: KidsChoiceCard(
            prompt: 'Which one?',
            display: Text('a very long verse ' * 80),
            options: [for (var i = 0; i < 6; i++) Text('option $i')],
            correct: 1,
            onDone: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The last option is reachable by scrolling.
    await tester.ensureVisible(find.text('option 5'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the order card centres its block too', (tester) async {
    useReducedMotion(tester);
    _tallPhone(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsLessonScaffold(
          index: 0,
          total: 3,
          done: false,
          child: KidsOrderCard(
            prompt: 'Tap them in order.',
            items: const ['one', 'two', 'three'],
            rng: math.Random(1),
            size: 28,
            wide: false,
            onDone: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Tap them in order.')).dy,
      greaterThan(150),
    );
  });
}
