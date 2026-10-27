import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/learning_path.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/families.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/lesson_player.dart';
import 'package:qiraah_arabiyyah/screens/learn_screen.dart';
import 'package:qiraah_arabiyyah/screens/learning_path_screen.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

import 'test_support.dart';

/// Learning's step-by-step path: the letter families' lessons, then the
/// Qāʿidah's units, a quiz on every six; it resumes where it was left.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  test('a quiz after every six steps, on just those; one on the rest at the end', () {
    final path = learningPath();
    final items = path.where((s) => s.kind != PathKind.quiz).toList();
    expect(items.length, letterFamilies.length + 10);
    expect(items.first.kind, PathKind.lesson);
    expect(items.first.id, 'alif');
    var since = 0;
    for (final s in path) {
      if (s.kind == PathKind.quiz) {
        expect(s.covers.length, since);
        expect(since, lessThanOrEqualTo(kPathQuizEvery));
        since = 0;
      } else {
        since++;
      }
    }
    expect(path.last.kind, PathKind.quiz);
    expect(path.where((s) => s.kind == PathKind.quiz).length,
        (items.length / kPathQuizEvery).ceil());
    expect({for (final s in path) s.progressId}.length, path.length, reason: 'ids unique');
  });

  Future<ProgressStore> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      ),
    ));
    await tester.pump();
    return p;
  }

  testWidgets('Learn leads with the path; Continue opens the next lesson',
      (tester) async {
    await pump(tester, const LearnScreen());
    expect(find.text('STEP BY STEP'), findsOneWidget);
    expect(find.text('Step 1 of ${learningPath().length}'), findsOneWidget);
    await tester.tap(find.text('STEP BY STEP'));
    await tester.pumpAndSettle();
    expect(find.byType(LearningPathScreen), findsOneWidget);
    await tester.tap(find.textContaining('Continue · '));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPlayer), findsOneWidget);
  });

  testWidgets('the first quiz asks about its six lessons\' letters', (tester) async {
    final p = await pump(tester, const LearningPathScreen());
    final path = learningPath();
    final quiz = path.indexWhere((s) => s.kind == PathKind.quiz);
    for (var i = 0; i < quiz; i++) {
      p.report(path[i].progressId, 1);
    }
    await tester.pump();
    expect(nextPathStep(p, path), quiz);
    await tester.tap(find.text('Continue · Quiz 1'));
    await tester.pumpAndSettle();
    final q = tester.widget<QuizScreen>(find.byType(QuizScreen));
    expect(q.questions.length, kPathQuizEvery * 2);
    expect(q.progressId, path[quiz].progressId);
  });
}
