import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/qaidah_home.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

/// Widget-level checks for the multi-select / ordering additions to the quiz
/// engine (Round 1), and a navigation smoke test through the new
/// Learn → Test → Practice hub (Round 3) — the two things `flutter test`'s
/// data-file tests can't see: actual widget interaction and screen wiring.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  // The default flutter_test surface (800x600) has shortestSide >= 600, so
  // useDesktop()'s 'auto' mode would otherwise resolve to the desktop shell
  // here — force the mobile layout so these assertions are deterministic.
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress, Widget child) {
  return SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: progress,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multi-select: grading requires an exact set match',
      (tester) async {
    final (settings, progress) = await _boot();
    final question = QuizQuestion(
      prompt: 'Choose every letter with 2 dots',
      options: const ['ب', 'ت', 'ق', 'ي'],
      optionsAreArabic: true,
      correctSet: const {1, 2, 3}, // ت ق ي
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Test', progressId: 'test.multiselect', questions: [question])));
    await tester.pumpAndSettle();

    // Submit button is disabled until at least one option is picked.
    final submitFinder = find.byType(FilledButton);
    expect(submitFinder, findsOneWidget);
    FilledButton submitBtn = tester.widget(submitFinder);
    expect(submitBtn.onPressed, isNull);

    // Pick only ONE of the three correct answers and submit — must be wrong.
    await tester.tap(find.text('ت'));
    await tester.pump();
    submitBtn = tester.widget(submitFinder);
    expect(submitBtn.onPressed, isNotNull);
    await tester.tap(submitFinder);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Wrong (partial) answer -> 0 score -> the result view shows 0/1.
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('multi-select: exact match grades correct', (tester) async {
    final (settings, progress) = await _boot();
    final question = QuizQuestion(
      prompt: 'Choose every letter with 2 dots',
      options: const ['ب', 'ت', 'ق', 'ي'],
      optionsAreArabic: true,
      correctSet: const {1, 2, 3},
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Test', progressId: 'test.multiselect2', questions: [question])));
    await tester.pumpAndSettle();

    for (final label in ['ت', 'ق', 'ي']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('ordering: tapping the correct sequence grades correct',
      (tester) async {
    final (settings, progress) = await _boot();
    final question = QuizQuestion(
      prompt: 'List these letters backward',
      options: const ['Alif', 'Bā’', 'Tā’'],
      sequence: const ['Tā’', 'Bā’', 'Alif'],
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Test', progressId: 'test.order', questions: [question])));
    await tester.pumpAndSettle();

    for (final label in ['Tā’', 'Bā’', 'Alif']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('ordering: wrong tap order grades incorrect', (tester) async {
    final (settings, progress) = await _boot();
    final question = QuizQuestion(
      prompt: 'List these letters backward',
      options: const ['Alif', 'Bā’', 'Tā’'],
      sequence: const ['Tā’', 'Bā’', 'Alif'],
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Test', progressId: 'test.order2', questions: [question])));
    await tester.pumpAndSettle();

    // Tap in forward (wrong) order instead of the required reverse order.
    for (final label in ['Alif', 'Bā’', 'Tā’']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('a skipped question is neither right nor wrong, and leaves the '
      'score', (tester) async {
    final (settings, progress) = await _boot();
    // Two questions: answer the first correctly, skip the second. Scoring
    // over the whole round would read 1/2 — one star. Skipped questions come
    // out of the denominator instead, so it is 1/1: a clean three stars.
    final questions = [
      const QuizQuestion(
          prompt: 'Pick one', options: ['a', 'b'], correct: 0),
      const QuizQuestion(
        prompt: 'Listen, then pick',
        options: ['ب', 'ت'],
        correct: 0,
        optionsAreArabic: true,
        audioRef: '1:1',
        skippable: true,
      ),
    ];
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Skip', progressId: 'test.skip', questions: questions)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // The second question offers a way past it — there is no per-letter
    // audio, so a learner must never be stranded on one of these.
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget,
        reason: 'the skipped question should be out of the denominator');
    expect(progress.starsFor('test.skip'), 3);
  });

  testWidgets('a grid question lays its options out as a grid', (tester) async {
    final (settings, progress) = await _boot();
    const question = QuizQuestion(
      prompt: 'Pick Kāf in the right shape',
      arabic: 'ٱلۡكِتَٰبُ',
      blank: 'كِ',
      options: ['كـ', 'ـكـ', 'ـك', 'ك'],
      correct: 1,
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Grid',
            progressId: 'test.grid',
            questions: [question])));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
    expect(delegate.childAspectRatio, 1.0);

    // The gap is drawn as a slot, so the letter being asked about must not
    // still be sitting in the prompt word.
    final rich = tester.widgetList<RichText>(find.byType(RichText));
    final shown = rich.map((r) => r.text.toPlainText()).join();
    expect(shown.contains('ٱلۡكِتَٰبُ'), isFalse);
  });

  testWidgets('practice mode (graded: false) never reports stars',
      (tester) async {
    final (settings, progress) = await _boot();
    final question = QuizQuestion(
      prompt: 'Pick one',
      options: const ['a', 'b'],
      correct: 0,
    );
    await tester.pumpWidget(_harness(
        settings,
        progress,
        QuizScreen(
            title: 'Practice',
            progressId: 'qaidah.practice.probe',
            questions: [question],
            graded: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(progress.starsFor('qaidah.practice.probe'), 0);
    // No star row on the practice result screen.
    expect(find.byType(StarRow), findsNothing);
  });

  testWidgets(
      'navigation: a unit opens the Learn/Test/Practice hub, and each phase renders',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    // A unit card (Ḥarakāt; the letters are lessons, not units).
    await tester.scrollUntilVisible(find.text('Ḥarakāt'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ḥarakāt'));
    await tester.pumpAndSettle();

    // The phase hub shows all three phases, unlocked.
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);

    // Learn opens the lessons.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Fatḥah'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Test opens a graded quiz.
    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Practice opens too, ungraded, without throwing.
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  testWidgets('navigation: the new Ḥurūf Muqaṭṭaʿāt unit is reachable',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.textContaining('Ḥurūf Muqaṭṭaʿāt'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Ḥurūf Muqaṭṭaʿāt'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Ḥurūf Muqaṭṭaʿāt'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ḥurūf Muqaṭṭaʿāt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    // The Learn screen renders at least one of the 14 sets without throwing.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
