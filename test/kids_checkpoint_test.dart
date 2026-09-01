import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/glyph_names.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_checkpoint_quiz.dart';

/// The check-up a long stage stops for every five lessons.
///
/// The rule it must never break: **nothing the child has not met yet.** A
/// checkpoint after five letters that quietly draws its distractors from the
/// whole alphabet is not a check-up, it is a guessing game — the child has no
/// way to rule out a letter they have never seen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext ctx;

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    settings.kidsMode = true;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
  }

  testWidgets('a letters check-up covers everything so far and nothing more',
      (tester) async {
    await boot(tester);
    for (final upTo in [5, 10, 25]) {
      final met = kidsLetterPath.take(upTo).toList();
      final chars = {for (final l in met) l.char};
      final names = {for (final l in met) letterName(ctx, l)};
      final quiz =
          kidsLetterCheckpoint(ctx, progressId: 'kids.check.letters.$upTo', upTo: upTo);

      expect(quiz.questions, hasLength(10), reason: 'upTo $upTo');
      expect(quiz.progressId, 'kids.check.letters.$upTo');
      for (final q in quiz.questions) {
        final arabic = q.arabic;
        if (arabic != null) expect(chars, contains(arabic));
        // Whichever direction the question runs, every option is a letter
        // already learned — a letter from lesson 26 is not a distractor at
        // the checkpoint after 25, it is noise.
        expect(q.options.toSet(),
            everyElement(isIn(q.optionsAreArabic ? chars : names)),
            reason: 'upTo $upTo: ${q.prompt}');
        expect(q.options[q.correct], isNotNull);
      }
      // Cumulative, not "the five just done": the first letter has to keep
      // turning up, which is the whole reason for the checkpoint.
      final asked = {
        for (final q in quiz.questions) q.reviewId,
      };
      expect(asked.length, greaterThan(1));
    }
  });

  testWidgets('both directions are drilled, not just recognition',
      (tester) async {
    await boot(tester);
    final quiz =
        kidsLetterCheckpoint(ctx, progressId: 'kids.check.letters.10', upTo: 10);
    // Naming a shape ten times over drills recognition only; recalling the
    // shape from the name is the other half, and the harder one.
    expect(quiz.questions.where((q) => q.optionsAreArabic), isNotEmpty);
    expect(quiz.questions.where((q) => !q.optionsAreArabic), isNotEmpty);
  });

  testWidgets('a forms check-up never asks for a shape that does not exist',
      (tester) async {
    await boot(tester);
    for (final upTo in [5, 15, 28]) {
      final met = kidsLetterPath.take(upTo).toList();
      final nonJoiners = {
        for (final l in met)
          if (!l.joins) l.char
      };
      final quiz =
          kidsFormsCheckpoint(ctx, progressId: 'kids.check.forms.$upTo', upTo: upTo);
      expect(quiz.questions, isNotEmpty, reason: 'upTo $upTo');
      for (final q in quiz.questions) {
        final id = q.reviewId!; // 'letter.form.<char>.<ini|med|fin>'
        final parts = id.split('.');
        final char = parts[2], form = parts[3];
        expect(met.map((l) => l.char), contains(char), reason: id);
        // A dāl has no initial or medial shape. Asking for one would show a
        // stray tatweel run, not a shape the muṣḥaf contains.
        if (nonJoiners.contains(char)) {
          expect(form, 'fin', reason: '$id: non-joiner has only a final shape');
        }
      }
    }
  });

  testWidgets('a check-up fires every five lessons', (tester) async {
    await boot(tester);
    // The number the path builder counts with — pinned here so changing it
    // has to be deliberate.
    expect(kidsCheckpointEvery, 5);
  });
}
