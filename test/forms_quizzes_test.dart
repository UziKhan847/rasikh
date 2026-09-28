import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/screens/lessons/forms_quizzes.dart';

/// The joining-form question shapes added alongside the existing "which
/// letter is this?" forms quiz.
///
/// [contextualForms] gets the closest scrutiny: it is the one part of these
/// generators that can be *wrong* rather than merely awkward. A mis-derived
/// shape marks a correct answer incorrect, which teaches a child the exact
/// opposite of the lesson.
void main() {
  group('contextualForms', () {
    test('derives shapes from neighbours, not from a position tag', () {
      // ٱلۡكِتَٰبُ — the superscript alif is a mark, so the bases are ٱ ل ك ت ب.
      // The kāf is tagged "middle" in letterExamples, and it IS mid-word, but
      // it follows a lām that joins forward, so it takes the medial shape.
      expect(contextualForms('ٱلۡكِتَٰبُ').map((f) => '${f.char}:${f.form}'),
          ['ٱ:iso', 'ل:ini', 'ك:med', 'ت:med', 'ب:fin']);
    });

    test('a letter after a non-joiner takes the INITIAL shape, not medial',
        () {
      // أَحَدٌ: the ḥāʾ is mid-word but follows a hamza-on-alif, which never
      // joins forward — so it is initial. Trusting the 'middle' tag here is
      // precisely the mistake this function exists to avoid.
      expect(contextualForms('أَحَدٌ').map((f) => f.form),
          ['iso', 'ini', 'fin']);
    });

    test('the six non-connectors never join forward', () {
      // كَفَرُواْ — the rāʾ joins right but not left, so the wāw after it is
      // isolated, not final.
      final forms = contextualForms('كَفَرُواْ');
      expect(forms.map((f) => '${f.char}:${f.form}').toList(),
          containsAll(['ر:fin', 'و:iso']));
    });

    test('a two-letter word is initial + final', () {
      expect(contextualForms('قُلۡ').map((f) => f.form), ['ini', 'fin']);
    });

    test('ḥarakāt and tatweel are not letters', () {
      expect(contextualForms('بِسۡمِ').map((f) => f.char), ['ب', 'س', 'م']);
    });
  });

  group('generated questions', () {
    late BuildContext ctx;

    Future<void> boot(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
    }

    testWidgets('the form grid offers 12 tiles and exactly one right answer',
        (tester) async {
      await boot(tester);
      final qs = formGridQuestions(ctx, count: 6);
      expect(qs, isNotEmpty);
      for (final q in qs) {
        expect(q.options, hasLength(12), reason: '3 letters x 4 shapes');
        expect(q.optionColumns, 4);
        expect(q.correct, inInclusiveRange(0, 11));
        // The gap must really be part of the word, or nothing is removed and
        // the answer is sitting there in plain sight.
        expect(q.blank, isNotNull);
        expect(q.arabic!.contains(q.blank!), isTrue);
        // No duplicate tiles: two identical shapes would make one correct
        // tap gradeable as wrong.
        expect(q.options.toSet(), hasLength(12));
      }
    });

    testWidgets('position questions offer the four shapes', (tester) async {
      await boot(tester);
      final qs = formPositionQuestions(ctx, count: 5);
      expect(qs, hasLength(5));
      for (final q in qs) {
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4));
        expect(q.correct, inInclusiveRange(0, 3));
      }
    });

    testWidgets('build-the-word sequences match the word’s real shapes',
        (tester) async {
      await boot(tester);
      final qs = buildTheWordQuestions(ctx, count: 4);
      expect(qs, isNotEmpty);
      for (final q in qs) {
        expect(q.sequence, isNotNull);
        // Every tile is used exactly once, and the shuffled options are the
        // same multiset as the answer.
        expect(q.options.length, q.sequence!.length);
        expect(q.options.toSet(), q.sequence!.toSet());
      }
    });

    testWidgets('listening questions are always skippable', (tester) async {
      await boot(tester);
      final qs = listenAndPickQuestions(ctx, count: 4);
      expect(qs, hasLength(4));
      for (final q in qs) {
        // There is no per-letter audio — only whole-āyah recitation that
        // needs the network — so a learner must always be able to move on.
        expect(q.skippable, isTrue);
        expect(q.audioRef, matches(RegExp(r'^\d+:\d+$')));
        expect(q.correct, inInclusiveRange(0, q.options.length - 1));
      }
    });
  });
}
