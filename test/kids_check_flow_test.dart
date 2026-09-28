import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_sentences.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_mouth_map.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart'
    show kidsQuizLength;
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';

import 'kids_test_support.dart';

/// The checks inside the kid lessons all run on the shared `KidsChoiceCard`:
/// a wrong first pick is a miss in the review queue at once, earns a hint and
/// a second try, and can never be counted as a first-try right answer — while
/// an explanation ends each check the child reads at their own pace.
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// The Arabic word tiles on screen (each is a TapScale holding one Text).
List<String> _tiles(WidgetTester tester) => [
  for (final e
      in find
          .descendant(of: kidsTappables(), matching: find.byType(Text))
          .evaluate())
    (e.widget as Text).data!,
];

/// The word the current "which word means…" question is asking for.
String _rightWord(WidgetTester tester) {
  final prompt = tester
      .widgetList<Text>(find.textContaining('Which word means'))
      .single
      .data!;
  final gloss = RegExp(r'"(.*)"').firstMatch(prompt)!.group(1)!;
  return kidsSentences.firstWhere((s) => s.gloss == gloss).targetWord;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openWords(
    WidgetTester tester,
    AppSettings s,
    ProgressStore p,
  ) async {
    await tester.pumpWidget(
      _harness(
        s,
        p,
        const KidsWordsLesson(progressId: 'kids.words.test', quiz: true),
      ),
    );
    await tester.pump();
  }

  testWidgets('every word right first time: three stars, an explanation each '
      'time, nothing in the queue', (tester) async {
    useReducedMotion(tester);
    _phone(tester);
    final (settings, prog) = await _boot();
    await openWords(tester, settings, prog);

    for (var i = 0; i < kidsQuizLength; i++) {
      final word = _rightWord(tester);
      await tester.tap(
        find.descendant(of: kidsTappables(), matching: find.text(word)),
      );
      await tester.pump();
      expect(find.text('Yes!'), findsOneWidget, reason: 'question $i');
      // The word said in Latin letters, with what it means.
      final s = kidsSentences.firstWhere((s) => s.targetWord == word);
      expect(find.text('${s.translit} — ${s.gloss}'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    await tester.pump();
    expect(prog.starsFor('kids.words.test'), 3);
    expect(prog.dueCount, 0);
  });

  testWidgets('a wrong pick is a miss at once, gets a hint and a second '
      'try — and the second try never counts as first-try', (tester) async {
    useReducedMotion(tester);
    _phone(tester);
    final (settings, prog) = await _boot();
    await openWords(tester, settings, prog);

    for (var i = 0; i < kidsQuizLength; i++) {
      final right = _rightWord(tester);
      final wrong = _tiles(tester).firstWhere((t) => t != right);
      await tester.tap(
        find.descendant(of: kidsTappables(), matching: find.text(wrong)),
      );
      await tester.pump();

      // A miss the moment it happens, and a hint — not the answer.
      expect(prog.dueCount, i + 1, reason: 'question $i');
      expect(find.text('Sound it out, letter by letter.'), findsOneWidget);
      expect(find.text('Yes!'), findsNothing);
      expect(find.text("Not quite — it's this one:"), findsNothing);
      // The tile tried is no longer a target.
      expect(_tiles(tester), isNot(contains(wrong)));

      // The second try lands: it is right, but not FIRST-try right.
      await tester.tap(
        find.descendant(of: kidsTappables(), matching: find.text(right)),
      );
      await tester.pump();
      // Got there: "Yes!", not the reveal shown after two misses.
      expect(find.text('Yes!'), findsOneWidget);
      expect(find.text("Not quite — it's this one:"), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    await tester.pump();
    // Nothing right first time: the lowest a finished lesson can score.
    expect(prog.starsFor('kids.words.test'), 1);
    expect(prog.dueCount, kidsQuizLength);
  });

  testWidgets('two wrong picks reveal the answer with its explanation', (
    tester,
  ) async {
    useReducedMotion(tester);
    _phone(tester);
    final (settings, prog) = await _boot();
    await openWords(tester, settings, prog);

    final right = _rightWord(tester);
    for (var n = 0; n < 2; n++) {
      final wrong = _tiles(tester).firstWhere((t) => t != right);
      await tester.tap(
        find.descendant(of: kidsTappables(), matching: find.text(wrong)),
      );
      await tester.pump();
    }
    expect(find.text("Not quite — it's this one:"), findsOneWidget);
    final s = kidsSentences.firstWhere((s) => s.targetWord == right);
    expect(find.text('${s.translit} — ${s.gloss}'), findsOneWidget);
    expect(prog.dueCount, 1, reason: 'one card for the one check');
  });

  testWidgets('the waqf check explains with the mark itself', (tester) async {
    useReducedMotion(tester);
    _phone(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsWaqfLesson(progressId: 'kids.waqf.test', quiz: true),
      ),
    );
    await tester.pump();
    // Tap tiles until the check resolves (right first time, or two misses).
    for (var i = 0; i < 2; i++) {
      final tiles = kidsTappables();
      if (tiles.evaluate().isEmpty) break;
      await tester.ensureVisible(tiles.first);
      await tester.tap(tiles.first);
      await tester.pump();
    }
    expect(find.textContaining(RegExp('Yes!|Not quite')), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mouth map: a wrong place gets a hint, then the place\'s '
      'tip when revealed', (tester) async {
    useReducedMotion(tester);
    _phone(tester);
    final (settings, prog) = await _boot();
    final qs = kidsMouthQuestions({}, math.Random(8));
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMouthMapLesson(
          progressId: 'kids.practice.mouth',
          rng: math.Random(8),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(kidsTappables().at(i));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump();

    final q = qs.first;
    expect(q.isNose, isFalse, reason: 'this seed opens on a letter question');
    const names = {
      'jawf': 'Open mouth',
      'halq': 'The Throat',
      'lisan': 'The Tongue',
      'shafatan': 'The Lips',
    };
    final wrongs = q.options.where((o) => o != q.answer).toList();
    await tester.tap(find.text(names[wrongs[0]]!));
    await tester.pump();
    expect(
      find.text('Touch your face and say it — where do you feel it?'),
      findsOneWidget,
    );
    expect(prog.review.containsKey('kids.mouth.${q.letter}'), isTrue);
    await tester.tap(find.text(names[wrongs[1]]!));
    await tester.pump();
    expect(find.text("Not quite — it's this one:"), findsOneWidget);
    // The reason is the place's own tip.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && RegExp(r'work|throat|touching').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );
  });
}
