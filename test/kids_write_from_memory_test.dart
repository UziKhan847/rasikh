import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_write_from_memory.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart' show TracingBoard;

import 'kids_test_support.dart';

/// Write it from memory: the letter's NAME is shown, never its shape, and the
/// child draws it on a blank board — production recall, the stronger test of
/// whether a shape is really known. Uses the Tracing Studio's `memory` mode.
ArabicLetter _l(String ch) => letterFor(ch);

Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Test'));
  return (settings, progress);
}

Future<void> _pump(
  WidgetTester tester,
  AppSettings settings,
  ProgressStore prog,
  Widget child,
) => tester.pumpWidget(
  SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: prog,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  ),
);

/// The board's own callback — what the Check button calls with its grade.
void _check(WidgetTester tester, int stars) =>
    tester.widget<TracingBoard>(find.byType(TracingBoard)).onStars!(stars);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a round asks for at most five letters, never a repeat', () {
    final r = KidsWriteFromMemory.forKnown(
      letters,
      progressId: 'x',
      rng: math.Random(3),
    );
    expect(r.letters, hasLength(kidsWriteRound));
    expect(r.letters.toSet(), hasLength(kidsWriteRound));

    final two = KidsWriteFromMemory.forKnown([
      _l('ب'),
      _l('ت'),
    ], progressId: 'x');
    expect(two.letters.toSet(), {_l('ب'), _l('ت')});
  });

  testWidgets('shows the letter\'s NAME on a blank board, never its shape', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(
      tester,
      settings,
      prog,
      KidsWriteFromMemory(letters: [_l('ب')], progressId: 'test.write'),
    );
    await tester.pump();

    expect(find.byType(Material), findsWidgets);
    expect(find.text('Write Bā’ from memory'), findsOneWidget);
    // The whole point: the glyph is what the child must PRODUCE.
    expect(find.text('ب'), findsNothing);
    final board = tester.widget<TracingBoard>(find.byType(TracingBoard));
    expect(board.mode, 'memory');
    expect(board.onStars, isNotNull, reason: 'it is graded, unlike watch mode');
  });

  testWidgets('a poor attempt is filed for review; a good one promotes it', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    // ت was missed before, so a good attempt now should promote its card.
    prog.recordMiss('letter.ت', 'ت', answer: 'Tā’', distractors: const ['Bā’']);
    await _pump(
      tester,
      settings,
      prog,
      KidsWriteFromMemory(
        letters: [_l('ب'), _l('ت')],
        progressId: 'test.write',
      ),
    );
    await tester.pump();

    _check(tester, 1); // ب: a poor attempt
    await tester.pump();
    expect(prog.review['letter.ب']!.answer, 'Bā’');
    expect(prog.review['letter.ب']!.box, 0);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Write Tā’ from memory'), findsOneWidget);

    _check(tester, 3); // ت: a good one
    await tester.pump();
    expect(prog.review['letter.ت']!.box, 1, reason: 'promoted one Leitner box');
  });

  testWidgets('a round reports real stars when it is finished', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(
      tester,
      settings,
      prog,
      KidsWriteFromMemory(
        letters: [_l('ب'), _l('ت')],
        progressId: 'kids.practice.write',
      ),
    );
    await tester.pump();

    for (final _ in [0, 1]) {
      _check(tester, 3);
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    await tester.pump();

    expect(find.text('Continue'), findsOneWidget);
    expect(prog.starsFor('kids.practice.write'), 3);
  });

  testWidgets('Home offers Write it only once there is a letter to write', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(tester, settings, prog, KidsHomeScreen(onGoLearn: () {}));
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('Listening'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    expect(find.text('Write it'), findsNothing);

    prog.report('kids.letter.ب', 3);
    await tester.pump();
    expect(find.text('Write it'), findsOneWidget);
  });
}
