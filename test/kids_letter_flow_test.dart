import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart' show TracingBoard;

import 'kids_test_support.dart';

/// The shape of a letter lesson: meet the letter, say it out loud, trace it
/// twice, celebrate.
///
/// It used to end on "Read the sentence" — a fully voweled MSA sentence shown
/// to a child who had just traced their first letter and knew no ḥarakāt.
/// These tests exist mostly to keep that from creeping back.
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

  testWidgets('a letter lesson opens on the shape, not on a word',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ا',
          traces: [
            KidsTraceStep('naskh_more', 'iso'),
            KidsTraceStep('naskh_few', 'iso'),
          ],
        )));
    await tester.pumpAndSettle();

    // Meet the letter first: shape, name, and a way to hear it. The glyph
    // itself is painted on a canvas for ink-centring (see `_GlyphHero`), so
    // it is findable by its semantic label instead of as literal text.
    expect(find.text('This is Alif'), findsOneWidget);
    expect(find.bySemanticsLabel('ا'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    // Four steps: shape, say it, trace with more strokes, trace with fewer.
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  testWidgets('the child says it five times before writing it',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ا',
          traces: [KidsTraceStep('naskh_more', 'iso')],
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Say it out loud!'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);

    // Four taps still leave one to go — the fifth is what moves on.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('I said it!'));
      await tester.pumpAndSettle();
      expect(find.text('Say it out loud!'), findsOneWidget,
          reason: 'moved on after ${i + 1} repetitions, not 5');
    }
    await tester.tap(find.text('I said it!'));
    // Not pumpAndSettle: TracingBoard runs a repeating pulse.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Say it out loud!'), findsNothing);
    expect(find.text('Step 3 of 3'), findsOneWidget);
  });

  testWidgets('a lesson can skip the introduction and go straight to tracing',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ب',
          introduce: false,
          traces: [
            KidsTraceStep('naskh_more', 'ini'),
            KidsTraceStep('naskh_more', 'med'),
            KidsTraceStep('naskh_more', 'fin'),
          ],
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // `introduce: false` drops both opening steps, so the numbering counts
    // the traces alone. No path stage uses it today — the joining-forms
    // lesson introduces the letter like the letters stage does — but the
    // flow's own step counting has to hold without an introduction.
    expect(find.text('Say it out loud!'), findsNothing);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    // The trace step names which of the four shapes this is.
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets(
      '"Show me" opens a watch-only replay of the trace, never graded',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ب',
          introduce: false,
          traces: [KidsTraceStep('naskh_few', 'iso')],
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Show me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Two boards now exist: the interactive one underneath, and the
    // watch-only replay in the sheet on top.
    expect(find.byType(TracingBoard), findsNWidgets(2));
    expect(prog.starsFor('kids.letter.ب'), 0,
        reason: 'watching the demo must not count as tracing it');
  });

  testWidgets('a repeated shape is one step per repetition, and says so',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ا',
          introduce: false,
          traces: [KidsTraceStep('naskh_few', 'iso', repeat: 5)],
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Five goes at the same shape: each one is a step of its own, so the
    // progress label cannot sit on "Step 1 of 1" through all five.
    expect(find.text('Step 1 of 5'), findsOneWidget);
    // And the child is told this is the plan, not a re-do of a mistake.
    expect(find.text('Practice 1 of 5'), findsOneWidget);
  });

  testWidgets('a single trace shows no practice counter', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ا',
          introduce: false,
          traces: [KidsTraceStep('naskh_more', 'iso')],
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Step 1 of 1'), findsOneWidget);
    expect(find.textContaining('Practice'), findsNothing);
  });

  testWidgets('no step asks the child to read a sentence', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings, prog, const KidsLetterFlow(letter: 'ا')));
    await tester.pumpAndSettle();

    // Walk the whole introduction. A letter lesson must never show running
    // Arabic text — the child has met one letter and no vowel marks.
    expect(find.text('Read the sentence'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('I said it!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Read the sentence'), findsNothing);
  });
}
