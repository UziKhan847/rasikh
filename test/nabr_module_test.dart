import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/nabr_content.dart';
import 'package:rasikh/screens/nabr/nabr_screen.dart';
import 'package:rasikh/screens/nabr/nabr_widgets.dart';

/// The Nabr module (behind kNabrEnabled): its content parses whole, every
/// drill and question is answerable, it stays hidden without the preview,
/// and every chapter, the drills and the quiz work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> settings({bool preview = false, String lang = 'en'}) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s
      ..onboarded = true
      ..language = lang
      ..nabrPreview = preview;
    return s;
  }

  Widget app(AppSettings s, Widget home, {String lang = 'en'}) => SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(lang),
          home: home,
        ),
      );

  /// Loads the content outside the fake clock (rootBundle reads real files).
  Future<NabrContent> content(WidgetTester tester) async =>
      (await tester.runAsync(NabrContent.load))!;

  testWidgets('the content parses whole; drills and questions are answerable',
      (tester) async {
    final c = await content(tester);
    expect(c.parts, hasLength(6));
    expect(c.parts.expand((p) => p.chapters), hasLength(38));
    expect(c.drills, hasLength(100));
    expect(c.quiz, hasLength(71));
    expect(c.levels.map((l) => l.id), containsAll(['strong', 'medium', 'weak']));
    expect(c.basedOn.ar, contains('صون اللسان'));
    for (final d in c.drills) {
      expect(d.correct, isNotEmpty, reason: d.id);
      for (final i in d.correct) {
        expect(i, inInclusiveRange(0, d.tokens.length - 1), reason: d.id);
        expect(d.nonSelectable, isNot(contains(i)), reason: d.id);
      }
      expect(d.multi || d.correct.length == 1, isTrue,
          reason: '${d.id}: a single-letter drill has one answer');
    }
    // No stress on the word separator, in the examples and answers either.
    for (final p in c.parts) {
      for (final ch in p.chapters) {
        for (final b in ch.blocks) {
          final ex = switch (b) {
            NabrExamples(:final items) => items,
            NabrPractice(:final answers) => answers,
            _ => const <NabrExample>[],
          };
          for (final e in ex) {
            for (final i in e.stressed) {
              expect(e.tokens[i], isNot('ـ'), reason: '${ch.id}: ${e.word}');
            }
          }
        }
      }
    }
    for (final q in c.quiz) {
      expect(q.correct, inInclusiveRange(0, q.options.length - 1), reason: q.id);
    }
  });

  testWidgets('every chapter draws all its blocks, in English and Arabic',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await content(tester);
    for (final lang in ['en', 'ar']) {
      final s = await settings(preview: true, lang: lang);
      for (final (pi, part) in c.parts.indexed) {
        for (final (ci, _) in part.chapters.indexed) {
          await tester.pumpWidget(app(s, NabrChapterScreen(content: c, part: pi, chapter: ci),
              lang: lang));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${part.id} ch$ci ($lang)');
          expect(find.byType(NabrBlockView), findsWidgets);
        }
      }
    }
  });

  testWidgets('a drill: tapping the stressed letter is right; the answer shows',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await content(tester);
    final s = await settings(preview: true);
    await tester.pumpWidget(app(s, NabrDrillScreen(content: c)));
    await tester.pump();
    final d = c.drills.first; // فَسَقَى: the sīn
    final row = find.byType(NabrTokenRow);
    await tester.tap(find.descendant(of: row, matching: find.text(d.tokens[d.correct.single])));
    await tester.pump();
    expect(find.text('Right'), findsOneWidget);
    expect(find.textContaining(d.answer.en), findsWidgets);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.textContaining('2/${c.drills.length}'), findsOneWidget);
  });

  testWidgets('the quiz: a wrong answer is marked, the score counts the right ones',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await content(tester);
    final s = await settings(preview: true);
    await tester.pumpWidget(app(s, NabrQuizScreen(content: c)));
    await tester.pump();
    final q = c.quiz.first;
    final wrong = q.options[(q.correct + 1) % q.options.length];
    await tester.tap(find.textContaining(wrong.en).first);
    await tester.pump();
    expect(find.text('Not quite'), findsOneWidget);
  });

  testWidgets('the hub lists the parts and opens the colour guide', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await settings(preview: true);
    await tester.runAsync(NabrContent.load);
    await tester.pumpWidget(app(s, const NabrScreen()));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('Colour guide'), findsOneWidget);
    expect(find.textContaining('Based on'), findsOneWidget);
    await tester.tap(find.text('Colour guide'));
    await tester.pumpAndSettle();
    expect(find.byType(NabrColoursScreen), findsOneWidget);
  });
}
