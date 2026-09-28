import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

import 'kids_test_support.dart';

/// "Drag the right shape onto the word": a gap question whose options can be
/// dragged into the word as well as tapped. Both ways must answer it — the tap
/// is the way for a child who cannot drag yet.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
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

QuizQuestion _gap({bool drag = true}) => QuizQuestion(
  prompt: 'Drag the right shape into the word',
  arabic: 'ٱلۡكِتَٰبُ',
  blank: 'كِ',
  options: const ['كـ', 'ـكـ', 'ـك', 'ك'],
  correct: 1,
  optionsAreArabic: true,
  optionColumns: 4,
  optionAspect: 1.0,
  dragToGap: drag,
);

Future<ProgressStore> _open(
  WidgetTester tester,
  QuizQuestion q, {
  String id = 'test.draggap',
}) async {
  useReducedMotion(tester);
  final (settings, progress) = await _boot();
  await tester.pumpWidget(
    _harness(
      settings,
      progress,
      QuizScreen(title: 'Gap', progressId: id, questions: [q]),
    ),
  );
  await tester.pumpAndSettle();
  return progress;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dragging the right shape onto the word answers it correctly', (
    tester,
  ) async {
    final progress = await _open(tester, _gap(), id: 'test.dg.drag');
    await dragOnto(tester, find.text('ـكـ'), find.byType(DragTarget<int>));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(progress.starsFor('test.dg.drag'), 3);
  });

  testWidgets('dragging a wrong shape onto the word answers it wrong', (
    tester,
  ) async {
    final progress = await _open(tester, _gap(), id: 'test.dg.wrong');
    await dragOnto(tester, find.text('ك').last, find.byType(DragTarget<int>));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(progress.starsFor('test.dg.wrong'), 0);
  });

  testWidgets('tapping a shape still answers it — no drag needed', (
    tester,
  ) async {
    final progress = await _open(tester, _gap(), id: 'test.dg.tap');
    await tester.tap(find.text('ـكـ'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(progress.starsFor('test.dg.tap'), 3);
  });

  testWidgets('letting go anywhere but on the word answers nothing', (
    tester,
  ) async {
    final progress = await _open(tester, _gap(), id: 'test.dg.miss');
    final home = tester.getCenter(find.text('ـكـ'));
    final g = await tester.startGesture(home);
    await g.moveBy(const Offset(0, 30));
    await tester.pump();
    await g.moveTo(home + const Offset(0, 120));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 1500));

    // Still on the question, and nothing has been reported.
    expect(find.text('ـكـ'), findsOneWidget);
    expect(progress.starsFor('test.dg.miss'), 0);
    // ...and it can still be answered.
    await tester.tap(find.text('ـكـ'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(progress.starsFor('test.dg.miss'), 3);
  });

  testWidgets('the word is shown whole once the gap is answered', (
    tester,
  ) async {
    await _open(tester, _gap(), id: 'test.dg.whole');
    String shown() => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join();
    expect(shown().contains('ٱلۡكِتَٰبُ'), isFalse, reason: 'gap while asking');

    await tester.tap(find.text('ـكـ'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      shown().contains('ٱلۡكِتَٰبُ'),
      isTrue,
      reason: 'the lifted letter goes back into its word',
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  });

  testWidgets('a question that does not ask for a drag has nothing draggable', (
    tester,
  ) async {
    await _open(tester, _gap(drag: false), id: 'test.dg.off');
    expect(find.byType(Draggable<int>), findsNothing);
    expect(find.byType(DragTarget<int>), findsNothing);
    await tester.tap(find.text('ـكـ'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });
}
