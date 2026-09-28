import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_join_letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';

import 'kids_test_support.dart';

/// Joining letters by hand: separate letters, dragged (or tapped) together
/// into a word, with the six that never join the next letter finding that out.
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

Finder _piece(int i) => find.byKey(ValueKey('joinPiece.$i'));

Future<List<bool>> _openCard(
  WidgetTester tester,
  String word, {
  bool hint = true,
}) async {
  useReducedMotion(tester);
  final (settings, prog) = await _boot();
  final done = <bool>[];
  await tester.pumpWidget(
    _harness(
      settings,
      prog,
      Scaffold(
        body: KidsJoinCard(
          word: kidsJoinWords.firstWhere((w) => w.word == word),
          hint: hint,
          onDone: done.add,
        ),
      ),
    ),
  );
  await tester.pump();
  return done;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the words', () {
    test('a letter carries its marks, and a mark never stands alone', () {
      expect(kidsJoinClusters('كِتَاب'), ['كِ', 'تَ', 'ا', 'ب']);
      expect(kidsJoinClusters('بَيْت'), ['بَ', 'يْ', 'ت']);
      expect(kidsJoinClusters('شَمْس'), ['شَ', 'مْ', 'س']);
    });

    test('every letter of every word is a real letter of the alphabet', () {
      for (final w in kidsJoinWords) {
        for (final c in kidsJoinClusters(w.word)) {
          final base = String.fromCharCode(c.runes.first);
          expect(
            letters.any((l) => l.char == base),
            isTrue,
            reason: '${w.word}: $base',
          );
        }
      }
    });

    test('only the six non-joiners say no', () {
      for (final l in letters) {
        expect(
          kidsJoinsForward(l.char),
          !kidsNonJoiners.contains(l.char),
          reason: l.char,
        );
      }
      expect(kidsNonJoiners.length, 6);
    });

    test('every word has something to join, and the hardest have a non-joiner '
        'inside them', () {
      for (final w in kidsJoinWords) {
        final c = kidsJoinClusters(w.word);
        expect(
          [
            for (var i = 0; i < c.length - 1; i++)
              if (kidsJoinsForward(c[i])) i,
          ],
          isNotEmpty,
          reason: w.word,
        );
      }
      bool hasBlocker(String word) {
        final c = kidsJoinClusters(word);
        return [
          for (var i = 0; i < c.length - 1; i++)
            if (!kidsJoinsForward(c[i])) i,
        ].isNotEmpty;
      }

      expect(hasBlocker('كِتَاب'), isTrue);
      expect(hasBlocker('بَاب'), isTrue);
      expect(hasBlocker('بَيْت'), isFalse);
    });
  });

  group('one word', () {
    testWidgets('dragging a letter onto its neighbour joins them', (
      tester,
    ) async {
      final done = await _openCard(tester, 'بَيْت');
      expect(find.text('بَ'), findsOneWidget);
      expect(find.text('يْ'), findsOneWidget);

      await dragOnto(tester, _piece(0), _piece(1));
      expect(
        find.text('بَيْ'),
        findsOneWidget,
        reason: 'two pieces became one',
      );
      expect(find.text('بَ'), findsNothing);

      await dragOnto(tester, _piece(0), _piece(2));
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('That’s the word!'), findsOneWidget);
      await tester.tap(find.text('Next'));
      expect(done, [true]);
    });

    testWidgets('a neighbour dragged the other way joins just the same', (
      tester,
    ) async {
      final done = await _openCard(tester, 'قَمَر');
      await dragOnto(tester, _piece(1), _piece(0));
      expect(find.text('قَمَ'), findsOneWidget);
      await dragOnto(tester, _piece(2), _piece(0));
      await tester.tap(find.text('Next'));
      expect(done, [true]);
    });

    testWidgets('tapping a letter joins it to the next, no drag needed', (
      tester,
    ) async {
      final done = await _openCard(tester, 'شَمْس');
      await tester.tap(_piece(0));
      await tester.pump();
      expect(find.text('شَمْ'), findsOneWidget);
      await tester.tap(_piece(0));
      await tester.pump();
      await tester.tap(find.text('Next'));
      expect(done, [true]);
    });

    testWidgets('a letter that never joins says so, and costs the first try', (
      tester,
    ) async {
      final done = await _openCard(tester, 'بَاب');
      // ا never joins the ب after it.
      await tester.tap(_piece(1));
      await tester.pump();
      expect(
        find.textContaining('never joins the next letter'),
        findsOneWidget,
      );
      expect(find.text('Next'), findsNothing, reason: 'not finished yet');
      await tester.pump(const Duration(milliseconds: 700));

      // ب does join ا — and that is all there is to join in this word.
      await tester.tap(_piece(0));
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      expect(done, [false]);
    });

    testWidgets('a word joined without a slip reports a first try', (
      tester,
    ) async {
      final done = await _openCard(tester, 'كِتَاب');
      await tester.tap(_piece(0));
      await tester.pump();
      expect(find.text('كِتَ'), findsOneWidget);
      await tester.tap(_piece(0));
      await tester.pump();
      // ك and ت hold hands; ا holds nobody's — so that is the whole word.
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      expect(done, [true]);
    });

    testWidgets('only neighbours can join — two apart is a miss', (
      tester,
    ) async {
      final done = await _openCard(tester, 'بَيْت');
      await dragOnto(tester, _piece(0), _piece(2));
      expect(find.text('Only letters side by side can join.'), findsOneWidget);
      expect(find.text('بَ'), findsOneWidget, reason: 'nothing merged');
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(_piece(0));
      await tester.pump();
      await tester.tap(_piece(0));
      await tester.pump();
      await tester.tap(find.text('Next'));
      expect(done, [false]);
    });

    testWidgets('letting go anywhere else is not a miss', (tester) async {
      final done = await _openCard(tester, 'بَيْت');
      final start = tester.getCenter(_piece(0));
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(0, -20));
      await tester.pump();
      await g.moveTo(start + const Offset(0, -150));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(
        find
            .byType(Text)
            .evaluate()
            .any(
              (e) =>
                  (e.widget as Text).data ==
                  'Only letters side by side can join.',
            ),
        isFalse,
      );
      await tester.tap(_piece(0));
      await tester.pump();
      await tester.tap(_piece(0));
      await tester.pump();
      await tester.tap(find.text('Next'));
      expect(done, [true]);
    });

    testWidgets('the hint marks exactly the letters that can hold a hand', (
      tester,
    ) async {
      await _openCard(tester, 'كِتَاب');
      // ك ت ا ب → ك and ت can; ا cannot; the last has nothing after it.
      expect(kidsIcon('link', Icons.link_rounded), findsNWidgets(2));
      await _openCard(tester, 'كِتَاب', hint: false);
      expect(kidsIcon('link', Icons.link_rounded), findsNothing);
    });
  });

  group('the lesson', () {
    testWidgets('opens on the six that never join, and ends in a real result', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsJoinLettersLesson(progressId: 'kids.join.words'),
        ),
      );
      await tester.pump();
      expect(find.byType(Material), findsWidgets);
      expect(find.text('Letters hold hands'), findsOneWidget);
      for (final ch in kidsNonJoiners) {
        expect(find.text(ch), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Every word, joined by TAPPING alone.
      for (final w in kidsJoinWords) {
        expect(
          find.text('Step ${kidsJoinWords.indexOf(w) + 2} of 7'),
          findsOneWidget,
        );
        for (var guard = 0; guard < 8; guard++) {
          if (find.text('Next').evaluate().isNotEmpty) break;
          await tester.tap(_piece(0));
          await tester.pump();
        }
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.join.words'), greaterThan(0));
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
          const KidsJoinLettersLesson(progressId: 'kids.join.words'),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'intro');
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'first word');
    });
  });

  testWidgets('it is a stage of its own, once, after the joining-shapes test', (tester) async {
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
    final path = kidsPath(ctx);
    final holders = [
      for (final b in path)
        for (final i in b.items(ctx))
          if (i.id == 'kids.join.words') b.id,
    ];
    expect(holders, ['join']);
    final ids = [for (final b in path) b.id];
    expect(ids.indexOf('join'), ids.indexOf('forms.quiz') + 1);
    expect(ids.indexOf('join') + 1, ids.indexOf('special'));
  });
}
