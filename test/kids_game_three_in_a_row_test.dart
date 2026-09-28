import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_three_in_a_row.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// Tic-tac-toe against a simple computer: a real game (win/lose/draw), but
/// every move of the child's is gated behind "which letter is this?" — a
/// wrong answer costs the square, not a second chance at it.
final _known = letters.take(9).toList();

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

/// The board's nine letter tiles, by their Arabic glyph, in cell order.
/// The open squares, by letter — a claimed square keeps its letter (the
/// design shows whose it is by the square itself), so only unclaimed ones.
List<Finder> _cellFinders() => [
  for (final l in _known)
    find.descendant(
      of: find.byWidgetPredicate(
          (w) => w is KidsBoardCell && w.state == KidsCellState.empty),
      matching: find.text(l.char),
    ),
];

/// The squares the child ([KidsCellState.a]) or the computer ([KidsCellState.b])
/// has claimed.
Finder _cells(KidsCellState s) =>
    find.byWidgetPredicate((w) => w is KidsBoardCell && w.state == s);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on nine empty, letter-labelled squares', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsThreeInARow(
          known: _known,
          progressId: 'test.game',
          answer: (_, _, _) async => true,
        ),
      ),
    );
    await tester.pump();

    // The board must bring its own Material: pushKidsOverlay's route has
    // none, and without one every Text falls back to the framework's "no
    // Material" debug style — a double yellow underline on black, which is
    // exactly how these three games shipped.
    expect(find.byType(Material), findsWidgets);
    expect(_cells(KidsCellState.a), findsNothing);
    expect(_cells(KidsCellState.b), findsNothing);
    // Every known letter is shown somewhere on the board.
    for (final l in _known) {
      expect(find.text(l.char), findsWidgets, reason: l.char);
    }
  });

  testWidgets('a correct answer claims the tapped square as X', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    var asked = 0;
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsThreeInARow(
          known: _known,
          progressId: 'test.game',
          answer: (prompt, options, correct) async {
            asked++;
            expect(prompt, isNotEmpty);
            expect(options, hasLength(4));
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    final target = find.text(_known.first.char).first;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(asked, 1);
    expect(_cells(KidsCellState.a), findsOneWidget);
    // The computer replied — exactly one O appears, once the dust settles.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_cells(KidsCellState.b), findsOneWidget);
  });

  testWidgets('a wrong answer claims nothing, but still costs a turn', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsThreeInARow(
          known: _known,
          progressId: 'test.game',
          answer: (_, _, _) async => false,
        ),
      ),
    );
    await tester.pump();

    final cell = find.text(_known.first.char).first;
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(_cells(KidsCellState.a), findsNothing);
    // The turn still passed to the computer.
    expect(_cells(KidsCellState.b), findsOneWidget);
  });

  testWidgets('a miss is filed in the review queue under the letter\'s id', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsThreeInARow(
          known: _known,
          progressId: 'test.game',
          answer: (_, _, _) async => false,
        ),
      ),
    );
    await tester.pump();
    final target = _known.first;
    final cell = find.text(target.char).first;
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(prog.review.containsKey('letter.${target.char}'), isTrue);
  });

  testWidgets(
    'answering every question right, playing to the end always reaches a '
    'real result screen and reports real progress',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsThreeInARow(
            known: _known,
            progressId: 'kids.practice.three_in_a_row',
            answer: (_, _, _) async => true,
          ),
        ),
      );
      await tester.pump();

      // Tap whatever is open each turn, until the game decides itself —
      // bounded, so a stuck game fails the test instead of hanging it.
      for (var guard = 0; guard < 9; guard++) {
        if (find.byType(KidsLessonResult).evaluate().isNotEmpty) break;
        var tappedSomething = false;
        for (final f in _cellFinders()) {
          if (f.evaluate().isEmpty) continue;
          await tester.ensureVisible(f.first);
          await tester.tap(f.first, warnIfMissed: false);
          tappedSomething = true;
          break;
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        if (!tappedSomething) break;
      }

      expect(find.byType(KidsLessonResult), findsOneWidget);
      // ...and so must the result screen, which replaces the board outright.
      expect(find.byType(Material), findsWidgets);
      expect(prog.starsFor('kids.practice.three_in_a_row'), greaterThan(0));
    },
  );

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
        KidsThreeInARow(known: _known, progressId: 'test.game'),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
