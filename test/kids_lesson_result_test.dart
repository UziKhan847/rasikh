import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';
import 'kids_test_support.dart';

/// The result screen's stars land one at a time rather than appearing all at
/// once — but every existing kids test drives its widgets with
/// `useReducedMotion`, which must keep collapsing straight to the fully
/// revealed frame this screen has always shown, so none of them needed to
/// change. This file is the one that actually watches the animation run.
///
/// [KidsLessonResult] always hosts a looping [KidsConfetti], so — like every
/// other kids test — nothing here calls `pumpAndSettle()` unless motion is
/// reduced first; a repeating controller never lets it return.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  return settings;
}

Widget _harness(AppSettings s, Widget child) => SettingsScope(
  settings: s,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  ),
);

/// Star [i]'s scale-in progress, or null if it was never earned — an
/// unearned star renders as a plain outline with no [ScaleTransition] at all.
/// Keyed explicitly rather than found by type: `find.byType(ScaleTransition)`
/// also matches unrelated Material internals (the initial route's own
/// transition), which are not ours to assert on.
double? _starScale(WidgetTester tester, int i) {
  final finder = find.byKey(ValueKey('kidsCelebrationStar.$i'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<ScaleTransition>(finder).scale.value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'with motion on, the three stars land one at a time, not at once',
    (tester) async {
      final settings = await _boot();
      await tester.pumpWidget(
        _harness(settings, const KidsLessonResult(stars: 3)),
      );
      await tester.pump(); // first frame: the controller has just started

      expect(_starScale(tester, 0), lessThan(0.1));
      expect(_starScale(tester, 1), lessThan(0.1));
      expect(_starScale(tester, 2), lessThan(0.1));

      // Star 1 starts at 0.20 of an 1800ms run — well past it, well short of
      // star 2's 0.34.
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _starScale(tester, 0),
        greaterThan(0.1),
        reason: 'star 1 should have landed',
      );
      expect(
        _starScale(tester, 1),
        lessThan(0.1),
        reason: 'star 2 should not have, yet',
      );
      expect(
        _starScale(tester, 2),
        lessThan(0.1),
        reason: 'star 3 should not have, yet',
      );

      // Well past all three (0.20 / 0.34 / 0.48 of 1800ms) but bounded, not
      // pumpAndSettle — the confetti keeps looping forever.
      await tester.pump(const Duration(milliseconds: 900));
      expect(_starScale(tester, 0), greaterThan(0.1));
      expect(_starScale(tester, 1), greaterThan(0.1));
      expect(_starScale(tester, 2), greaterThan(0.1));

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'an unearned star never animates — it is a plain outline throughout',
    (tester) async {
      final settings = await _boot();
      await tester.pumpWidget(
        _harness(settings, const KidsLessonResult(stars: 1)),
      );
      await tester.pump();

      // Every slot has an outline (the star's "socket"); only the ONE earned
      // star also gets a filled star scaling in on top of it.
      expect(kidsIcon('star_outline', Icons.star_outline_rounded), findsNWidgets(3));
      expect(_starScale(tester, 0), isNotNull);
      expect(_starScale(tester, 1), isNull);
      expect(_starScale(tester, 2), isNull);

      await tester.pump(const Duration(milliseconds: 1800));
      expect(_starScale(tester, 1), isNull);
      expect(_starScale(tester, 2), isNull);
      // The filled star exists only where it was earned, whatever the score.
      expect(kidsIcon('star', Icons.star_rounded), findsOneWidget);
    },
  );

  testWidgets('a zero-star result still shows and lands one star', (
    tester,
  ) async {
    final settings = await _boot();
    await tester.pumpWidget(
      _harness(settings, const KidsLessonResult(stars: 0)),
    );
    await tester.pump();
    expect(_starScale(tester, 0), isNotNull);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Continue'), findsOneWidget);
  });

  group('reduce motion', () {
    Future<void> reduceMotion(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets(
      'skips straight to the fully-revealed frame — every star, XP, '
      'Continue, all there on the very first pump',
      (tester) async {
        await reduceMotion(tester);
        final settings = await _boot();
        await tester.pumpWidget(
          _harness(settings, const KidsLessonResult(stars: 3)),
        );
        await tester.pump();

        // Nothing to wait for: pumpAndSettle returns immediately rather than
        // hanging on the confetti's own repeating controller — the
        // load-bearing contract every kids animation follows.
        await tester.pumpAndSettle();

        expect(_starScale(tester, 0), greaterThanOrEqualTo(1.0));
        expect(_starScale(tester, 1), greaterThanOrEqualTo(1.0));
        expect(_starScale(tester, 2), greaterThanOrEqualTo(1.0));
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Perfect!'), findsOneWidget);
      },
    );

    testWidgets('one star also lands immediately, no waiting', (
      tester,
    ) async {
      await reduceMotion(tester);
      final settings = await _boot();
      await tester.pumpWidget(
        _harness(settings, const KidsLessonResult(stars: 1)),
      );
      await tester.pumpAndSettle();
      expect(_starScale(tester, 0), greaterThanOrEqualTo(1.0));
      expect(kidsIcon('star', Icons.star_rounded), findsOneWidget);
      expect(kidsIcon('star_outline', Icons.star_outline_rounded), findsNWidgets(3));
    });
  });

  testWidgets('the footer slot renders below the XP line, when given one', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final settings = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        const KidsLessonResult(stars: 2, footer: Text('streak: 4')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('streak: 4'), findsOneWidget);
  });
}
