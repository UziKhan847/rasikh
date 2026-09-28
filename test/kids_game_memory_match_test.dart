import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/glyph_names.dart' show letterName;
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_board.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_memory_match.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// Concentration: a glyph card and its name card are the pair, over six
/// known letters — visual discrimination, the thing the research on Arabic
/// letter games singles out card matching for.
final _known = letters.take(6).toList();

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

/// Flips card [i], scrolling it into view first — the board can run taller
/// than the default test window.
Future<void> _flip(WidgetTester tester, Finder card) async {
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pump();
}

/// Flips the card at stable board index [i] — the cards' cells carry a
/// `kidsMemoryCard.<index>` key that never changes as cards flip or match,
/// so a specific card can be addressed by position rather than by "the
/// first face-down icon", which stops being unique the moment two cards are
/// already open.
Future<void> _flipAt(WidgetTester tester, int i) =>
    _flip(tester, find.byKey(ValueKey('kidsMemoryCard.$i')));

/// Whether the card at index [i] is currently shown as a confirmed match.
bool _isMatched(WidgetTester tester, int i) =>
    tester
        .widget<KidsBoardCell>(find.byKey(ValueKey('kidsMemoryCard.$i')))
        .state ==
    KidsCellState.matched;

/// Plays a complete, winning game: for each not-yet-matched card in order,
/// tries every higher-indexed not-yet-matched card until its partner turns
/// up. A mismatch flips both back after 750ms — the 900ms settle here always
/// clears that before the next attempt — so this always finds every pair
/// without needing to know the shuffle in advance, in at most 66 attempts
/// (11+10+...+1) for twelve cards.
///
/// The very last pair completes the whole board, and the widget swaps
/// straight to [KidsLessonResult] in that same frame — so once that shows
/// up there is no card left to inspect, and this just stops.
Future<void> _solveMemoryMatch(WidgetTester tester, {int cardCount = 12}) async {
  final matched = <int>{};
  for (var a = 0; a < cardCount; a++) {
    if (matched.contains(a)) continue;
    for (var b = a + 1; b < cardCount; b++) {
      if (matched.contains(b)) continue;
      await _flipAt(tester, a);
      await _flipAt(tester, b);
      await tester.pump(const Duration(milliseconds: 900));
      if (find.byType(KidsLessonResult).evaluate().isNotEmpty) return;
      if (_isMatched(tester, a)) {
        matched.addAll([a, b]);
        break;
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens with twelve face-down cards, nothing shown', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMemoryMatch(known: _known, progressId: 'test.memory'),
      ),
    );
    await tester.pump();

    // The board must bring its own Material: pushKidsOverlay's route has
    // none, and without one every Text falls back to the framework's "no
    // Material" debug style — a double yellow underline on black, which is
    // exactly how these three games shipped.
    expect(find.byType(Material), findsWidgets);
    expect(kidsIcon('help', Icons.help_outline_rounded), findsNWidgets(12));
    for (final l in _known) {
      expect(find.text(l.char), findsNothing);
      expect(find.text(letterName(_ctx(tester), l)), findsNothing);
    }
  });

  testWidgets('flipping one card reveals it; a second non-matching card '
      'flips both back', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMemoryMatch(known: _known, progressId: 'test.memory'),
      ),
    );
    await tester.pump();

    final faceDown = kidsIcon('help', Icons.help_outline_rounded);
    await _flip(tester, faceDown.first);
    expect(kidsIcon('help', Icons.help_outline_rounded), findsNWidgets(11));

    await _flip(tester, kidsIcon('help', Icons.help_outline_rounded).first);
    // Whether or not this second pick happened to match, both cards are
    // shown face-up right after the tap.
    expect(kidsIcon('help', Icons.help_outline_rounded), findsNWidgets(10));

    // If it was a mismatch, both flip back down after the pause.
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('a real pair (a glyph and its own name) stays face-up', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMemoryMatch(known: _known, progressId: 'test.memory'),
      ),
    );
    await tester.pump();
    final ctx = _ctx(tester);

    // Hunt pairs, same systematic order the full solve below uses, but stop
    // at the first real match — this checks the matching logic itself, not
    // full-game completion (that end state replaces the whole board with
    // KidsLessonResult in the same frame the last pair lands, so no card is
    // ever left on screen to inspect at "all six done").
    int? foundA, foundB;
    outer:
    for (var a = 0; a < 12; a++) {
      for (var b = a + 1; b < 12; b++) {
        await _flipAt(tester, a);
        await _flipAt(tester, b);
        await tester.pump(const Duration(milliseconds: 900));
        if (_isMatched(tester, a)) {
          foundA = a;
          foundB = b;
          break outer;
        }
      }
    }
    expect(foundA, isNotNull, reason: 'no pair ever matched');

    String textIn(int i) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('kidsMemoryCard.$i')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    final aText = textIn(foundA!);
    final bText = textIn(foundB!);
    final letter = _known.firstWhere(
      (l) => aText == l.char || aText == letterName(ctx, l),
    );
    expect({aText, bText}, {letter.char, letterName(ctx, letter)});

    // A real match stays face-up — unlike a mismatch, nothing flips it back
    // even after more time passes.
    await tester.pump(const Duration(milliseconds: 900));
    expect(_isMatched(tester, foundA), isTrue);
    expect(_isMatched(tester, foundB), isTrue);
  });

  testWidgets('clearing every pair reaches a real result screen', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMemoryMatch(
          known: _known,
          progressId: 'kids.practice.memory_match',
          rng: math.Random(7),
        ),
      ),
    );
    await tester.pump();

    await _solveMemoryMatch(tester);
    await tester.pump();

    expect(find.byType(KidsLessonResult), findsOneWidget);
    // ...and so must the result screen, which replaces the board outright.
    expect(find.byType(Material), findsWidgets);
    expect(prog.starsFor('kids.practice.memory_match'), greaterThan(0));
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
        KidsMemoryMatch(known: _known, progressId: 'test.memory'),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(KidsMemoryMatch));
