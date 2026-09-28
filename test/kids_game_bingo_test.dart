import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_board.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_bingo.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// A caller says a letter; the child taps any cell showing it. Ten letters
/// gives enough variety for "which cell matches the call" without making
/// any one test depend on the shuffle.
final _known = letters.take(10).toList();

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
      // NOT `Scaffold(body: child)`: pushKidsOverlay hands a kids screen a
      // bare MaterialPageRoute, so the screen must bring its own Material —
      // a Scaffold here would supply one and hide the very bug the
      // find.byType(Material) guards below exist to catch. It did exactly
      // that once already; every other kids screen test uses `home: child`.
      home: child,
    ),
  ),
);

/// The glyph currently shown in board cell [i], or null once that cell has
/// no [Text] of its own (there always is one here, but kept safe).
String? _glyphAt(WidgetTester tester, int i) {
  final cell = find.byKey(ValueKey('kidsBingoCell.$i'));
  if (cell.evaluate().isEmpty) return null;
  final text = find.descendant(of: cell, matching: find.byType(Text));
  return tester.widget<Text>(text).data;
}

/// The index of some cell currently showing [char], or null if none does —
/// searched fresh each time since claimed cells never change their glyph,
/// only their state.
int? _cellShowing(WidgetTester tester, String char) {
  for (var i = 0; i < 16; i++) {
    if (_glyphAt(tester, i) == char) return i;
  }
  return null;
}

bool _isClaimed(WidgetTester tester, int i) =>
    tester
        .widget<KidsBoardCell>(find.byKey(ValueKey('kidsBingoCell.$i')))
        .state ==
    KidsCellState.picked;

Future<void> _tapCell(WidgetTester tester, int i) async {
  final cell = find.byKey(ValueKey('kidsBingoCell.$i'));
  await tester.ensureVisible(cell);
  await tester.tap(cell);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> played;
  setUp(() => LetterAudio.log = played = []);
  tearDown(() => LetterAudio.log = null);

  testWidgets('opens on sixteen cells and calls out the first letter', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsGameBingo(known: _known, progressId: 'test.bingo'),
      ),
    );
    await tester.pump();

    // The board must bring its own Material: pushKidsOverlay's route has
    // none, and without one every Text falls back to the framework's "no
    // Material" debug style — a double yellow underline on black, which is
    // exactly how these three games shipped.
    expect(find.byType(Material), findsWidgets);
    for (var i = 0; i < 16; i++) {
      expect(_glyphAt(tester, i), isNotNull, reason: 'cell $i');
    }
    // The board never prints a letter's name — only the letters called and
    // heard, which the log records instead of a Text finder.
    expect(played, hasLength(1));
    expect(_known.map((l) => l.char), contains(played.single));
  });

  testWidgets('tapping the called letter claims that cell and calls the '
      'next one', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsGameBingo(known: _known, progressId: 'test.bingo'),
      ),
    );
    await tester.pump();

    final called = played.single;
    final target = _cellShowing(tester, called);
    expect(target, isNotNull, reason: 'nothing on the board says $called');
    await _tapCell(tester, target!);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_isClaimed(tester, target), isTrue);
    expect(played, hasLength(2)); // the next call went out
  });

  testWidgets('tapping the wrong letter claims nothing and files a miss '
      'against the letter that was called', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsGameBingo(known: _known, progressId: 'test.bingo'),
      ),
    );
    await tester.pump();

    final called = played.single;
    final wrongIndex = () {
      for (var i = 0; i < 16; i++) {
        if (_glyphAt(tester, i) != called) return i;
      }
      throw StateError('every cell shows the called letter');
    }();
    await _tapCell(tester, wrongIndex);
    // Clears both the 250ms next-call delay and the 500ms wrong-flash
    // timer, so no timer is left pending when the test ends.
    await tester.pump(const Duration(milliseconds: 600));

    expect(_isClaimed(tester, wrongIndex), isFalse);
    expect(prog.review.containsKey('letter.$called'), isTrue);
    expect(played, hasLength(2)); // a wrong guess still costs the turn
  });

  testWidgets('a listen-again tap replays the current call', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsGameBingo(known: _known, progressId: 'test.bingo'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Listen'));
    await tester.pump();

    expect(played, [played.first, played.first]);
  });

  testWidgets('a real four-in-a-row wins and reaches a result screen with '
      'reported progress', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    // Every cell is the same single letter: every call matches every cell,
    // so a plain row of taps always wins — this is a test of the board's
    // win detection and the finish path, not of the caller/board matchup.
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsGameBingo(
          known: [_known.first],
          progressId: 'kids.practice.bingo',
        ),
      ),
    );
    await tester.pump();

    for (final i in [0, 1, 2, 3]) {
      await _tapCell(tester, i);
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.byType(KidsLessonResult), findsOneWidget);
    // ...and so must the result screen, which replaces the board outright.
    expect(find.byType(Material), findsWidgets);
    expect(prog.starsFor('kids.practice.bingo'), greaterThan(0));
  });

  testWidgets('fits a 320×568 phone at the largest text size', (tester) async {
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
        KidsGameBingo(known: _known, progressId: 'test.bingo'),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
