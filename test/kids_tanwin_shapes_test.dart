import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/tanwin_allographs.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_sort_bins.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_stage_quizzes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tanwin_shapes_lesson.dart';

import 'kids_test_support.dart';

/// The tanwīn stage gets one Learn item its siblings (ḥarakāt, sukūn, shaddah)
/// don't — the muṣḥaf writes tanwīn in three shapes, and which one is drawn
/// says what to do with the sound — plus questions about that shape in the
/// stage's own Test.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the lesson', () {
    testWidgets('three shape cards, then a sort, then a real result', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsTanwinShapesLesson(progressId: 'kids.tanwin.shapes'),
        ),
      );
      await tester.pump();

      expect(find.byType(Material), findsWidgets);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Side by side'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Stacked up'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Turns into a mīm'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();

      // The sort: nine tiles (three marks x three shapes), three bins.
      expect(find.byType(KidsSortBins), findsOneWidget);
      await finishSortByTap(tester, bins: 3);
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.tanwin.shapes'), greaterThan(0));
    });

    testWidgets('every sort item is a real allograph example', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsTanwinShapesLesson(progressId: 'kids.tanwin.shapes'),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      for (final a in tanwinAllographs) {
        expect(find.text(a.example), findsOneWidget, reason: a.id);
      }
    });

    testWidgets('it sits inside the tanwīn drill stage, between the drills '
        'and the Test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final ids = kidsPath(ctx)
          .firstWhere((b) => b.id == 'tanwin')
          .items(ctx)
          .map((i) => i.id)
          .toList();
      // Third from last now: the stage's game sits between this lesson and
      // the Test.
      expect(ids[ids.length - 3], 'kids.tanwin.shapes');
      expect(ids[ids.length - 2], 'kids.game.tanwin');
      expect(ids.last, 'kids.tanwin.test');
      // Not counted as a new BLOCK: no `kids.check.` / badge id references it,
      // and there is exactly one 'tanwin' block on the path.
      expect(kidsPath(ctx).where((b) => b.id == 'tanwin'), hasLength(1));
    });

    testWidgets('fits a 320×568 phone at the largest text size', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot();
      settings.kidsTextScale = 1.2;
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsTanwinShapesLesson(progressId: 'kids.tanwin.shapes'),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'shape card');
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: 'sort card');
    });
  });

  group('the Test', () {
    testWidgets('mixes syllable-sound questions with shape questions', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (var seed = 0; seed < 20; seed++) {
        final qs = kidsTanwinTest(
          ctx,
          progressId: 'p',
          rng: math.Random(seed),
        ).questions;
        expect(qs, hasLength(8));
        final shapeQs = qs.where(
          (q) => q.reviewId?.startsWith('kids.tanwin.') ?? false,
        );
        expect(shapeQs, hasLength(3));
        for (final q in shapeQs) {
          expect(q.options, hasLength(3));
          expect(q.optionsAreArabic, isTrue);
          expect(q.correct, inInclusiveRange(0, 2));
          // The right answer really is the allograph the review id names.
          final id = q.reviewId!.substring('kids.tanwin.'.length);
          final answer = tanwinAllographs.firstWhere((a) => a.id == id);
          expect(q.options[q.correct], answer.highlight);
        }
      }
    });

    testWidgets('every allograph can be asked, across many rounds', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final seen = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final qs = kidsTanwinTest(
          ctx,
          progressId: 'p',
          rng: math.Random(seed),
        ).questions;
        seen.addAll(
          qs
              .where((q) => q.reviewId?.startsWith('kids.tanwin.') ?? false)
              .map((q) => q.reviewId!),
        );
      }
      expect(seen, hasLength(9));
    });
  });
}
