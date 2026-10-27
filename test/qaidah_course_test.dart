import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/strokes.dart' show glyphFor;
import 'package:qiraah_arabiyyah/learn/qaidah/audio_manifest.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/families.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/lesson.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/lesson_player.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/qaidah_home.dart';

import 'test_support.dart';

/// The Qāʿidah course: the letters in shape families, a lesson taken step
/// by step to its stars, resumed where it was left, a desktop of its own
/// (no phone frame), and listening only where a recording is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  test('every letter is in exactly one family, and can be traced', () {
    final all = [for (final f in letterFamilies) ...f.chars];
    expect(all.toSet().length, all.length, reason: 'a letter in two families');
    expect(all.toSet(), {for (final l in letters) l.char});
    for (final c in all) {
      expect(() => glyphFor(c, 'iso'), returnsNormally, reason: c);
    }
  });

  test('the recordings list is up to date', () {
    expect(File('docs/qaidah_audio_manifest.md').readAsStringSync(), qaidahAudioMarkdown(),
        reason: 'run: dart run tool/gen_qaidah_audio_manifest.dart');
    expect(File('docs/qaidah_audio_manifest.csv').readAsStringSync(), qaidahAudioCsv());
  });

  Future<ProgressStore> pump(WidgetTester tester, Widget Function(BuildContext) home,
      {Size size = const Size(430, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..desktopMode = size.width > 1000 ? 'on' : 'off';
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: home),
        ),
      ),
    ));
    await tester.pump();
    return p;
  }

  testWidgets('a family lesson: meet, shapes, find, write, tell apart, check — '
      'then its stars', (tester) async {
    late QLesson lesson;
    final p = await pump(tester, (c) {
      final f = familyById('dal');
      return LessonPlayer(
          id: f.progressId,
          build: (seed) => lesson = familyLesson(c, f, rng: math.Random(seed)));
    });
    // Every "find it in a word" marks a letter that is in its word.
    for (final s in lesson.steps.whereType<PickStep>()) {
      final q = s.question;
      if (q.highlight != null) expect(q.arabic, contains(q.highlight), reason: q.arabic);
    }
    expect(lesson.graded, greaterThan(0));
    // Through every step: a question is answered (its right option) first.
    for (var i = 0; i < lesson.steps.length; i++) {
      final s = lesson.steps[i];
      if (s is PickStep) {
        await tester.tap(find.text(s.question.options[s.question.correct]).last);
        await tester.pump();
        expect(find.text('Right!'), findsOneWidget);
      }
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }
    expect(find.text('Lesson done'), findsOneWidget);
    expect(p.starsFor(familyById('dal').progressId), 3);
  });

  testWidgets('a wrong answer shows the right one; the mistakes come back',
      (tester) async {
    late QLesson lesson;
    await pump(tester, (c) {
      final f = familyById('ra');
      return LessonPlayer(
          id: f.progressId,
          build: (seed) => lesson = familyLesson(c, f, rng: math.Random(seed)));
    });
    var wrong = 0;
    for (var i = 0; i < lesson.steps.length; i++) {
      final s = lesson.steps[i];
      if (s is PickStep) {
        final q = s.question;
        final bad = (q.correct + 1) % q.options.length;
        await tester.tap(find.text(q.options[bad]).last);
        await tester.pump();
        expect(find.textContaining('Not quite'), findsOneWidget);
        wrong++;
      }
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }
    expect(wrong, greaterThan(0));
    await tester.tap(find.text('Go over the mistakes'));
    await tester.pump();
    expect(find.byType(LessonPlayer), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('a lesson left halfway opens where it was, the same lesson; '
      'its card says so', (tester) async {
    late QLesson first, again;
    final p = await pump(tester, (c) {
      final f = familyById('sin');
      return LessonPlayer(
          id: f.progressId,
          build: (seed) => first = familyLesson(c, f, rng: math.Random(seed)));
    });
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }
    final place = p.lessonPlace(familyById('sin').progressId)!;
    expect(place.step, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(SettingsScope(
      settings: AppSettings(),
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (c) {
            final f = familyById('sin');
            return LessonPlayer(
                id: f.progressId,
                build: (seed) => again = familyLesson(c, f, rng: math.Random(seed)));
          }),
        ),
      ),
    ));
    await tester.pump();
    expect(again.steps.length, first.steps.length);
    final q1 = first.steps.whereType<PickStep>().map((s) => s.question.options.join()).toList();
    final q2 = again.steps.whereType<PickStep>().map((s) => s.question.options.join()).toList();
    expect(q2, q1, reason: 'the same questions');
    expect(find.text('Write Sīn'), findsNothing);
    // The course's card: where it was left.
    await tester.pumpWidget(SettingsScope(
      settings: AppSettings(),
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const QaidahHome(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Resume · step 4 of ${first.steps.length}'), findsOneWidget);
  });

  testWidgets('no recording, no Listen', (tester) async {
    await pump(tester, (c) => familyLessonPlayer(c, familyById('alif')));
    await tester.tap(find.text('Continue')); // the explanation → meet Alif
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Meet Alif'), findsOneWidget);
    expect(find.text('Listen'), findsNothing);
  });

  testWidgets('desktop: the course and its lessons fill the window, the '
      'lesson\'s outline beside it', (tester) async {
    await pump(tester, (_) => const QaidahHome(), size: const Size(1400, 900));
    expect(find.text('Letters'.toUpperCase()), findsOneWidget);
    await tester.tap(find.textContaining('Continue: '));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPlayer), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget, reason: 'the outline pane');
    final size = tester.getSize(find.byType(LessonPlayer));
    expect(size.width, greaterThan(1000), reason: 'not in a phone frame');
  });
}
