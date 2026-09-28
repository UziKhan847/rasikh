import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tajwid_path.dart' show tajwidTopicById;
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_bingo.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_memory_match.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_three_in_a_row.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_review_recap.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_solar_lunar_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_special_shapes_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizScreen;

/// The Kids Mode curriculum, as data — the stage engine that replaced the
/// flat 28-letter list.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  return (settings, progress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext ctx;
  late AppSettings settings;
  late ProgressStore prog;

  Future<void> boot(WidgetTester tester) async {
    (settings, prog) = await _boot();
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
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
        ),
      ),
    );
  }

  /// A stage's tracing lessons, without the check-up quizzes woven between
  /// them — those are `KidsItem`s too, but they open a `QuizScreen`.
  /// A stage's teaching tiles — neither the check-ups woven between them nor
  /// the games (both have their own namespace, and neither is a lesson).
  List<KidsItem> lessonsOf(String stage) => [
    for (final i in kidsPath(ctx).firstWhere((b) => b.id == stage).items(ctx))
      if (!i.id.startsWith('kids.check.') && !i.id.startsWith('kids.game.')) i,
  ];

  testWidgets('every stage has items, a title and its own subtitle', (
    tester,
  ) async {
    await boot(tester);
    final path = kidsPath(ctx);
    expect(path.length, greaterThan(8));
    for (final block in path) {
      expect(block.items(ctx), isNotEmpty, reason: block.id);
      expect(block.title(ctx), isNotEmpty, reason: block.id);
      expect(block.subtitle(ctx), isNotEmpty, reason: block.id);
      expect(block.badge, isNotEmpty, reason: block.id);
      // The sukūn stage shipped briefly with its subtitle used as its title
      // too, so the row read the same sentence twice.
      expect(block.subtitle(ctx), isNot(block.title(ctx)), reason: block.id);
    }
  });

  testWidgets('item ids are unique across the whole path', (tester) async {
    await boot(tester);
    final ids = [
      for (final block in kidsPath(ctx))
        for (final item in block.items(ctx)) item.id,
    ];
    // Two stages sharing an id would mean clearing one silently clears the
    // other — the "fewer strokes" pass in particular must not be satisfied by
    // the "more strokes" one.
    expect(ids.toSet().length, ids.length);
  });

  testWidgets('the letters stage keeps its original progress ids', (
    tester,
  ) async {
    await boot(tester);
    final first = kidsPath(ctx).first;
    expect(first.id, 'letters');
    // Deliberately unchanged: anything already earned under these ids would
    // otherwise be orphaned by the path growing around it, and
    // `kidsLettersLearned` counts exactly this prefix.
    expect(first.items(ctx).map((i) => i.id).take(3), [
      'kids.letter.ا',
      'kids.letter.ب',
      'kids.letter.ت',
    ]);
  });

  testWidgets('a letter lesson traces the fewer-strokes shape five times', (
    tester,
  ) async {
    await boot(tester);
    final alif = kidsPath(ctx).first.items(ctx).first;
    final flow = alif.open(ctx) as KidsLetterFlow;

    // Meet the shape, say it, then write it in fewer, longer strokes five
    // times over — practice is repetition. The beginner stroke breakdown
    // (`naskh_more`) used to run first; it was dropped as an extra, slower
    // attempt that taught nothing the writing pass didn't.
    expect(flow.introduce, isTrue);
    expect(flow.traces.map((t) => (t.levelId, t.repeat)), [('naskh_few', 5)]);
  });

  testWidgets(
    'a joining-forms lesson is one shape at a time, not all of them at once',
    (tester) async {
      await boot(tester);
      final items = kidsPath(
        ctx,
      ).firstWhere((b) => b.id == 'forms.more').items(ctx);
      // Bāʼ joins on both sides, so it gets three separate lessons — start,
      // middle, end — each tracing just that one shape five times over, rather
      // than one 20-step lesson covering all three (and re-tracing the
      // isolated shape the Letters stage already taught).
      final baItems = items.where((i) => i.id.endsWith('.ب')).toList();
      expect(baItems.map((i) => i.id), [
        'kids.forms.ini.ب',
        'kids.forms.med.ب',
        'kids.forms.fin.ب',
      ]);
      for (final (item, form) in [
        (baItems[0], 'ini'),
        (baItems[1], 'med'),
        (baItems[2], 'fin'),
      ]) {
        final flow = item.open(ctx) as KidsLetterFlow;
        expect(flow.introduce, isTrue);
        expect(flow.traces.map((t) => (t.levelId, t.form, t.repeat)), [
          ('naskh_few', form, 5),
        ], reason: item.id);
      }
    },
  );

  testWidgets('a non-connector gets exactly one joining-forms lesson', (
    tester,
  ) async {
    await boot(tester);
    final items = kidsPath(
      ctx,
    ).firstWhere((b) => b.id == 'forms.more').items(ctx);
    // Waw's only real joining shape is its end form — the isolated one is
    // what the Letters stage already taught, and it never has a start or
    // middle shape to begin with.
    final waw = items.where((i) => i.id.endsWith('.و')).toList();
    expect(waw.map((i) => i.id), ['kids.forms.fin.و']);
    final flow = waw.single.open(ctx) as KidsLetterFlow;
    expect(flow.traces.map((t) => (t.levelId, t.form, t.repeat)), [
      ('naskh_few', 'fin', 5),
    ]);
  });

  testWidgets('the fewer-strokes stage is gone, not hidden', (tester) async {
    await boot(tester);
    // "Shapes Again" used to make the child meet all 28 letters' shapes a
    // second time, a whole quiz later. Its pass lives inside the joining-forms
    // lesson now, so the stage itself must not still be in the path.
    expect(kidsPath(ctx).map((b) => b.id), isNot(contains('forms.few')));
    for (final item in lessonsOf('forms.more')) {
      final flow = item.open(ctx) as KidsLetterFlow;
      expect(
        flow.traces.any((t) => t.levelId == 'naskh_few'),
        isTrue,
        reason: item.id,
      );
      expect(
        flow.traces.any((t) => t.levelId == 'naskh_more'),
        isFalse,
        reason: item.id,
      );
    }
  });

  testWidgets('a long stage stops to check every five lessons', (tester) async {
    await boot(tester);
    final items = kidsPath(ctx).firstWhere((b) => b.id == 'letters').items(ctx);
    // Five lessons, a check-up, five more, another — and the check-up is
    // cumulative, so the one at 10 covers everything from letter one.
    const prefix = 'kids.check.letters.';
    expect(
      [
        for (var i = 0; i < items.length; i++)
          if (items[i].id.startsWith(prefix)) (i, items[i].id),
      ],
      [
        (5, '${prefix}5'),
        (11, '${prefix}10'),
        (18, '${prefix}15'),
        (24, '${prefix}20'),
        (31, '${prefix}25'),
      ],
    );
    // ...and a game after every SECOND check-up, which is what the two gaps
    // of 7 above (rather than 6) are: check-up, game, five more lessons.
    expect(
      [
        for (var i = 0; i < items.length; i++)
          if (items[i].id.startsWith('kids.game.')) (i, items[i].id),
      ],
      [(12, 'kids.game.letters.10'), (25, 'kids.game.letters.20')],
    );
    // 28 lessons + 5 check-ups + 2 games, and nothing tacked onto the end:
    // the stage's own quiz is the very next stage.
    expect(items, hasLength(letters.length + 5 + 2));
    expect(items.last.id.startsWith(prefix), isFalse);
    expect(items.last.id.startsWith('kids.game.'), isFalse);
  });

  testWidgets('the joining-forms check-up counts by LETTER, not by lesson', (
    tester,
  ) async {
    await boot(tester);
    // A joiner now contributes three lessons per letter against a
    // non-joiner's one, so the five-lessons-per-checkpoint rule from the
    // Letters stage would land on the wrong letter count entirely if it were
    // applied by lesson position instead of letter position.
    final items = kidsPath(
      ctx,
    ).firstWhere((b) => b.id == 'forms.more').items(ctx);
    const prefix = 'kids.check.forms.';
    expect(
      [
        for (var i = 0; i < items.length; i++)
          if (items[i].id.startsWith(prefix)) (i, items[i].id),
      ],
      [
        (13, '${prefix}5'), // ا ب ت ث ج: 1 non-joiner + 4 joiners = 13 lessons
        (
          23,
          '${prefix}10',
        ), // + a shift of 1 for each checkpoint already placed
        (38, '${prefix}15'), // + 1 for the game that follows check-up 10
        (54, '${prefix}20'),
        (71, '${prefix}25'), // + 1 more for the game that follows check-up 20
      ],
    );
    expect(
      [
        for (var i = 0; i < items.length; i++)
          if (items[i].id.startsWith('kids.game.')) (i, items[i].id),
      ],
      [(24, 'kids.game.forms.10'), (55, 'kids.game.forms.20')],
    );
    expect(items.last.id.startsWith(prefix), isFalse);
    // 72 lessons (kidsFormsLessonCount) + 5 check-ups + 2 games.
    expect(items, hasLength(79));
  });

  testWidgets('a checkpoint id cannot be counted as a lesson', (tester) async {
    await boot(tester);
    // `kidsLettersLearned` and the joining-forms badge both count progress
    // ids by prefix. A checkpoint filed under one of those prefixes would
    // inflate the count it is not part of — 28 letters would "arrive" at 23.
    for (final block in kidsPath(ctx)) {
      for (final item in block.items(ctx)) {
        if (!item.id.startsWith('kids.check.')) continue;
        expect(item.id.startsWith('kids.letter.'), isFalse, reason: item.id);
        expect(item.id.startsWith('kids.forms.'), isFalse, reason: item.id);
      }
    }
    for (var i = 1; i <= 5; i++) {
      prog.report('kids.check.letters.$i', 3);
    }
    expect(prog.kidsLettersLearned, 0);
    expect(prog.countStarred('kids.forms.'), 0);
  });

  /// The games are Practice tiles on Home too. These cover the OTHER half of
  /// the decision: they also fall along the path itself, where the quizzes
  /// fall, so a long stage has some variety in it.
  group('the games on the path', () {
    testWidgets('a game id is never counted as a lesson either', (
      tester,
    ) async {
      await boot(tester);
      // Same hazard as `kids.check.`: `kidsLettersLearned` and the
      // joining-forms badge count by PREFIX, so a game filed under one of
      // them would inflate a count it is not part of.
      for (final block in kidsPath(ctx)) {
        for (final item in block.items(ctx)) {
          if (!item.id.startsWith('kids.game.')) continue;
          expect(item.id.startsWith('kids.letter.'), isFalse, reason: item.id);
          expect(item.id.startsWith('kids.forms.'), isFalse, reason: item.id);
          expect(item.id.startsWith('kids.check.'), isFalse, reason: item.id);
        }
      }
      prog.report('kids.game.letters.10', 3);
      prog.report('kids.game.forms.10', 3);
      expect(prog.kidsLettersLearned, 0);
      expect(prog.countStarred('kids.forms.'), 0);
      expect(prog.countStarred('kids.check.'), 0);
    });

    testWidgets('all three games appear, and none is the only one', (
      tester,
    ) async {
      await boot(tester);
      final games = [
        for (final block in kidsPath(ctx))
          for (final item in block.items(ctx))
            if (item.id.startsWith('kids.game.')) item,
      ];
      expect(games.map((i) => i.id).toSet(), hasLength(games.length),
          reason: 'two game slots share an id');
      final kinds = games.map((i) => i.open(ctx).runtimeType).toSet();
      // The point of three games is variety; a path that only ever opened one
      // of them would have missed it.
      expect(kinds, containsAll(<Type>[
        KidsThreeInARow,
        KidsMemoryMatch,
        KidsGameBingo,
      ]));
      // Spread across stages, not clustered in one.
      final stages = [
        for (final block in kidsPath(ctx))
          if (block.items(ctx).any((i) => i.id.startsWith('kids.game.')))
            block.id,
      ];
      expect(stages, hasLength(greaterThanOrEqualTo(4)));
    });

    testWidgets('every game grades itself, like a quiz', (tester) async {
      await boot(tester);
      for (final block in kidsPath(ctx)) {
        for (final item in block.items(ctx)) {
          if (!item.id.startsWith('kids.game.')) continue;
          expect(item.completeOnOpen, isFalse, reason: item.id);
          expect(item.glyph, isEmpty, reason: item.id);
        }
      }
    });

    testWidgets('a game opened with nothing learned still has a board', (
      tester,
    ) async {
      // The dev unlock opens the whole path at once, so a game tile can be
      // reached before its own gate would have been met on Home. It must top
      // its board up from the front of the path rather than throw.
      await boot(tester);
      expect(prog.kidsLettersLearned, 0);
      for (final block in kidsPath(ctx)) {
        for (final item in block.items(ctx)) {
          if (!item.id.startsWith('kids.game.')) continue;
          final game = item.open(ctx);
          final known = switch (game) {
            KidsThreeInARow(:final known) => known,
            KidsMemoryMatch(:final known) => known,
            KidsGameBingo(:final known) => known,
            _ => fail('${item.id} did not open a game: $game'),
          };
          expect(
            known.length,
            greaterThanOrEqualTo(game is KidsGameBingo ? 10 : 6),
            reason: item.id,
          );
          expect(
            known.map((l) => l.char).toSet(),
            hasLength(known.length),
            reason: '${item.id}: the same letter twice in the board pool',
          );
        }
      }
    });
  });

  testWidgets('non-joiners are never asked for a shape they do not have', (
    tester,
  ) async {
    await boot(tester);
    final forms = lessonsOf('forms.more');
    // 3 lessons per joiner (start/middle/end), 1 per non-joiner (end only) —
    // see kidsFormsLessonCount, which this mirrors.
    final joiners = letters.where((l) => l.joins).length;
    expect(forms, hasLength(joiners * 3 + (letters.length - joiners)));
    // A dāl has no initial or medial shape, so it gets one lesson (its end
    // form) rather than three, and never a lesson tracing a form that
    // doesn't exist.
    final dalItems = forms.where((i) => i.id.endsWith('.د')).toList();
    expect(dalItems, hasLength(1));
    expect(dalItems.single.glyph, letterFor('د').finalForm);
    final baItems = forms.where((i) => i.id.endsWith('.ب')).toList();
    expect(baItems, hasLength(3));
    expect(baItems.map((i) => i.glyph), [
      letterFor('ب').initial,
      letterFor('ب').medial,
      letterFor('ب').finalForm,
    ]);
  });

  testWidgets('stages and tiles unlock in order as progress lands', (
    tester,
  ) async {
    await boot(tester);
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    final letters0 = kidsPath(ctx).first.items(ctx);
    expect(kidsCurrentItemIndex(prog, letters0), 0);

    prog.report('kids.letter.ا', 3);
    expect(kidsCurrentItemIndex(prog, letters0), 1);
    expect(kidsItemsDone(prog, letters0), 1);
    // Still on stage one — 27 letters to go.
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    for (final item in letters0) {
      prog.report(item.id, 3);
    }
    expect(
      kidsCurrentBlockIndex(ctx, prog),
      1,
      reason: 'clearing every letter should open the letters quiz',
    );
  });

  testWidgets(
    'devStage pins the current block for testing, without touching progress',
    (tester) async {
      await boot(tester);
      expect(kidsCurrentBlockIndex(ctx, prog), 0);

      // Ignored while the testing unlock is off — a corrupted or stale pref
      // must not silently move a real, non-testing session off alif.
      prog.setDevStage('forms.more');
      expect(kidsCurrentBlockIndex(ctx, prog), 0);

      prog.setUnlockAll(true);
      expect(
        kidsCurrentBlockIndex(ctx, prog),
        2,
        reason: 'forms.more is the third stage in the path',
      );
      expect(prog.xp, 0);
      expect(prog.gems, 0);
      expect(
        prog.kidsLettersLearned,
        0,
        reason: 'jumping the display must not fake having cleared letters',
      );

      // An id that no longer matches any stage falls back to real progress
      // rather than throwing or pointing nowhere.
      prog.setDevStage('not.a.real.stage');
      expect(kidsCurrentBlockIndex(ctx, prog), 0);

      // Turning the unlock back off drops the pin — it should not silently
      // keep steering a later, non-testing session.
      prog.setDevStage('forms.more');
      prog.setUnlockAll(false);
      expect(prog.devStage, isNull);
      expect(kidsCurrentBlockIndex(ctx, prog), 0);
    },
  );

  testWidgets(
    'madd is a kid-native lesson with the interactive Counts Studio, not '
    'the reused prose page',
    (tester) async {
      await boot(tester);
      final items = kidsPath(ctx).firstWhere((b) => b.id == 'madd').items(ctx);
      expect(items.map((i) => i.id), ['kids.madd.learn', 'kids.madd.test']);
      expect(
        items.first.completeOnOpen,
        isTrue,
        reason: 'no internal check-up — the metronome is practice, not a quiz',
      );
      expect(items.first.open(ctx), isA<KidsMaddLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'muqattaat is a real letter-by-letter lesson, not the reused prose page',
    (tester) async {
      await boot(tester);
      final items = kidsPath(
        ctx,
      ).firstWhere((b) => b.id == 'muqattaat').items(ctx);
      expect(items.map((i) => i.id), [
        'kids.muqattaat.learn',
        'kids.muqattaat.test',
      ]);
      expect(
        items.first.completeOnOpen,
        isFalse,
        reason: 'the lesson grades itself, with its own check-ups',
      );
      expect(items.first.open(ctx), isA<KidsMuqattaatLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'words is a real sentence-reading lesson, not the reused word list',
    (tester) async {
      await boot(tester);
      final items = kidsPath(ctx).firstWhere((b) => b.id == 'words').items(ctx);
      expect(items.map((i) => i.id), ['kids.words.learn', 'kids.words.test']);
      expect(
        items.first.completeOnOpen,
        isFalse,
        reason: 'the lesson grades itself, with its own check-ups',
      );
      expect(items.first.open(ctx), isA<KidsWordsLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'wasl is a real step-by-step lesson, not the reused six-row page',
    (tester) async {
      await boot(tester);
      final items = kidsPath(ctx).firstWhere((b) => b.id == 'wasl').items(ctx);
      expect(items.map((i) => i.id), ['kids.wasl.learn', 'kids.wasl.test']);
      expect(
        items.first.completeOnOpen,
        isFalse,
        reason: 'the lesson grades itself, with its own check-ups',
      );
      expect(items.first.open(ctx), isA<KidsWaslLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'waqf is a real traffic-light lesson, not the reused six-row page',
    (tester) async {
      await boot(tester);
      final items = kidsPath(ctx).firstWhere((b) => b.id == 'waqf').items(ctx);
      expect(items.map((i) => i.id), ['kids.waqf.learn', 'kids.waqf.test']);
      expect(
        items.first.completeOnOpen,
        isFalse,
        reason: 'the lesson grades itself, with its own check-ups',
      );
      expect(items.first.open(ctx), isA<KidsWaqfLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'review is a kid-native recap of every stage cleared, not the stale '
    'grown-up table of contents',
    (tester) async {
      await boot(tester);
      final items = kidsPath(
        ctx,
      ).firstWhere((b) => b.id == 'review').items(ctx);
      expect(items.map((i) => i.id), ['kids.review.learn', 'kids.review.test']);
      expect(
        items.first.completeOnOpen,
        isTrue,
        reason: 'a recap of what was already learned has nothing to grade',
      );
      expect(items.first.open(ctx), isA<KidsReviewRecap>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'ḥarakāt/sukūn/shaddah/tanwīn are real Nūrāniyyah drills, opened as short '
    'sessions rather than one 32-step sitting',
    (tester) async {
      await boot(tester);
      // Three sessions per mark, closing on the grown-up unit's own Test —
      // see _drillBlock. Unlike the plain _unitBlock stages, the Learn side
      // here is NOT `completeOnOpen`: each drill grades itself.
      for (final (id, markIds, extraIds) in [
        // harakat/sukun/shadda each get a tamrīn item — real words carrying
        // the mark(s) just drilled — between their drills and their Test.
        // ...and then a game, so a stage of nine drill sessions is not nine
        // drill sessions and a Test.
        (
          'harakat',
          ['fatha', 'kasra', 'damma'],
          ['kids.harakat.words', 'kids.game.harakat'],
        ),
        ('sukun', ['sukun'], ['kids.sukun.words', 'kids.game.sukun']),
        ('shadda', ['shadda'], ['kids.shadda.words', 'kids.game.shadda']),
        // tanwīn gets the shapes lesson in place of word practice, since it
        // already shows real, highlighted muṣḥaf examples; see
        // `_wordPracticeItem`'s own doc.
        (
          'tanwin',
          ['fathatan', 'kasratan', 'dammatan'],
          ['kids.tanwin.shapes', 'kids.game.tanwin'],
        ),
      ]) {
        final items = kidsPath(ctx).firstWhere((b) => b.id == id).items(ctx);
        final drills = markIds.length * kidsDrillSessions;
        expect(items, hasLength(drills + extraIds.length + 1), reason: id);
        expect(items.map((i) => i.id), [
          for (final m in markIds)
            for (var n = 1; n <= kidsDrillSessions; n++) 'kids.$id.$m.$n',
          ...extraIds,
          'kids.$id.test',
        ]);
        for (final drill in items.take(drills)) {
          expect(
            drill.completeOnOpen,
            isFalse,
            reason: '$id.${drill.id}: a drill grades itself, like a quiz',
          );
          expect(drill.open(ctx), isA<KidsSyllableDrill>(), reason: drill.id);
        }
        expect(items.last.completeOnOpen, isFalse, reason: '$id.test');
      }
    },
  );

  testWidgets(
    'a mark\'s sessions together cover every letter once, and each is short',
    (tester) async {
      await boot(tester);
      final ranges = kidsDrillRanges();
      expect(ranges, hasLength(kidsDrillSessions));
      expect(ranges.first.$1, 0);
      expect(ranges.last.$2, kidsSyllableLetters.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].$1, ranges[i - 1].$2, reason: 'no gap, no overlap');
      }
      for (final (from, to) in ranges) {
        // ≤ 9 letters + one check-up ≈ 10 steps: a 3–5 minute session.
        expect(to - from, lessThanOrEqualTo(10));
      }
    },
  );

  testWidgets(
    'solar_lunar is a real step-by-step lesson, not the reused Tajwīd rule page',
    (tester) async {
      await boot(tester);
      final items = kidsPath(
        ctx,
      ).firstWhere((b) => b.id == 'solar_lunar').items(ctx);
      expect(items.map((i) => i.id), [
        'kids.solar_lunar.learn',
        'kids.solar_lunar.test',
      ]);
      expect(
        items.first.completeOnOpen,
        isFalse,
        reason: 'the lesson grades itself, like a quiz — not read-and-done',
      );
      expect(items.first.open(ctx), isA<KidsSolarLunarLesson>());
      expect(items.last.completeOnOpen, isFalse);
    },
  );

  testWidgets(
    'all five Tajwīd rule families are real rule-by-rule lessons, not the '
    'reused hub page',
    (tester) async {
      await boot(tester);
      for (final (id, topicId) in [
        ('tajwid.madd', 'madd'),
        ('tajwid.mim', 'mim'),
        ('tajwid.nun', 'nun'),
        ('tajwid.qalqalah', 'qalqalah'),
        ('tajwid.raa', 'raa'),
      ]) {
        final items = kidsPath(ctx).firstWhere((b) => b.id == id).items(ctx);
        expect(items.map((i) => i.id), [
          'kids.$id.learn',
          'kids.$id.test',
        ], reason: id);
        expect(
          items.first.completeOnOpen,
          isFalse,
          reason: '$id: the lesson grades itself, like a quiz',
        );
        final lesson = items.first.open(ctx);
        expect(lesson, isA<KidsTajwidRuleLesson>(), reason: id);
        expect(
          (lesson as KidsTajwidRuleLesson).ruleIds,
          tajwidTopicById(topicId).ruleIds,
          reason: '$id: covers every rule in its own family, no more, no less',
        );
        expect(items.last.completeOnOpen, isFalse);
      }
    },
  );

  testWidgets('the path follows the agreed Qāʿidah order', (tester) async {
    await boot(tester);
    final ids = kidsPath(ctx).map((b) => b.id).toList();
    int at(String id) {
      final i = ids.indexOf(id);
      expect(i, isNot(-1), reason: 'missing stage: $id');
      return i;
    }

    // Reading مٓ needs the six counts of madd lāzim; a child who met it
    // earlier could only imitate the sound.
    expect(at('muqattaat'), greaterThan(at('madd')));
    expect(at('madd'), greaterThan(at('harakat')));
    // Shaddah IS sukūn plus a moving letter, so it follows sukūn directly.
    expect(at('shadda'), greaterThan(at('sukun')));
    expect(at('forms.more'), greaterThan(at('letters')));
    // ٱل is the archetypal waṣl, so sun/moon letters come right after it.
    expect(at('solar_lunar'), greaterThan(at('wasl')));
    // Tāʼ marbūṭah's whole point is what happens when you stop, so the
    // stopping rules follow it.
    expect(at('waqf'), greaterThan(at('tamarbuta')));
    // One word, then two, then three.
    expect(at('words.two'), greaterThan(at('words')));
    expect(at('words.three'), greaterThan(at('words.two')));
    // Tajwīd, the review, and then the reading ladder — the last thing on the
    // path, from az-Zalzalah (99) to an-Nās (114), with al-Ikhlāṣ keeping the
    // id it had as the one closing sūrah.
    expect(at('tajwid.nun'), greaterThan(at('words.three')));
    expect(at('review'), greaterThan(at('tajwid.nun')));
    final ladder = [
      for (final n in [for (var n = 99; n <= 114; n++) n])
        n == 112 ? 'capstone' : 'read.$n',
    ];
    expect(ids.skip(ids.length - ladder.length).toList(), ladder);
    expect(at('read.99'), greaterThan(at('review')));
  });

  testWidgets('sun and moon letters are taught once, not twice', (
    tester,
  ) async {
    await boot(tester);
    final ids = kidsPath(ctx).map((b) => b.id).toList();
    // `solar_lunar` IS the grown-up Tajwīd lām unit, moved to where a Qāʿidah
    // actually teaches it. Listing that unit again in the tajwīd block would
    // make the child sit the same lesson twice.
    expect(ids.contains('tajwid.lam'), isFalse);
    expect(ids.contains('solar_lunar'), isTrue);
  });

  testWidgets('the special shapes stage covers the hamza carriers', (
    tester,
  ) async {
    await boot(tester);
    final ids = kidsPath(
      ctx,
    ).firstWhere((b) => b.id == 'special').items(ctx).map((i) => i.id).toList();
    // The characters the 28-letter alphabet leaves out but the muṣḥaf uses
    // constantly — they were missing from this stage when it first shipped.
    for (final ch in ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى']) {
      expect(ids, contains('kids.special.$ch'));
    }
  });

  testWidgets(
    'special shapes and every extra letter open kid-native lessons, never '
    'the grown-up Joining Forms lesson viewer or LetterDetail',
    (tester) async {
      await boot(tester);
      final items = kidsPath(
        ctx,
      ).firstWhere((b) => b.id == 'special').items(ctx);
      for (final id in ['ligatures', 'kaf', 'stacks', 'heights']) {
        final item = items.firstWhere((i) => i.id == 'kids.special.$id');
        expect(item.open(ctx), isA<KidsSpecialShapesLesson>(), reason: id);
      }
      for (final ch in ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى']) {
        final item = items.firstWhere((i) => i.id == 'kids.special.$ch');
        expect(item.open(ctx), isA<KidsExtraLetterLesson>(), reason: ch);
      }
    },
  );

  testWidgets('tāʼ marbūṭah opens a kid-native lesson, never LetterDetail', (
    tester,
  ) async {
    await boot(tester);
    final items = kidsPath(
      ctx,
    ).firstWhere((b) => b.id == 'tamarbuta').items(ctx);
    final item = items.firstWhere((i) => i.id == 'kids.tamarbuta.ة');
    expect(item.open(ctx), isA<KidsExtraLetterLesson>());
  });

  testWidgets(
    'every stage Test is kid-native and reports under its own kids id',
    (tester) async {
      await boot(tester);
      var seen = 0;
      for (final block in kidsPath(ctx)) {
        for (final item in block.items(ctx)) {
          if (!item.id.endsWith('.test')) continue;
          seen++;
          final screen = item.open(ctx);
          // Nothing wraps a grown-up quiz to mirror its stars any more: the
          // widget itself reports under the kids id the trail looks at.
          expect(
            screen.runtimeType.toString(),
            isNot('_KidsProgressMirror'),
            reason: item.id,
          );
          expect((screen as dynamic).progressId, item.id, reason: item.id);
          // A lesson's Test is that lesson's own checks (quiz: true); the
          // rest are the shared quiz shell over kid-worded questions.
          final quiz = switch (screen) {
            KidsWaqfLesson(:final quiz) => quiz,
            KidsWaslLesson(:final quiz) => quiz,
            KidsWordsLesson(:final quiz) => quiz,
            KidsMuqattaatLesson(:final quiz) => quiz,
            KidsSolarLunarLesson(:final quiz) => quiz,
            KidsTajwidRuleLesson(:final quiz) => quiz,
            KidsMaddLesson(:final quiz) => quiz,
            QuizScreen() => true,
            _ => false,
          };
          expect(quiz, isTrue, reason: '${item.id} opens ${screen.runtimeType}');
        }
      }
      // ḥarakāt, sukūn, shaddah, madd, tanwīn, muqaṭṭaʿāt, words, waṣl, sun and
      // moon, tāʼ marbūṭah, waqf, five tajwīd families, review. (The letters,
      // forms and special-shapes quizzes are `kids.quiz.*`.)
      expect(seen, 17);
    },
  );

  testWidgets('reading stages ladder from two words to sūrah after sūrah', (
    tester,
  ) async {
    await boot(tester);
    for (final id in [
      'words.two',
      'words.three',
      for (var n = 99; n <= 114; n++) n == 112 ? 'capstone' : 'read.$n',
    ]) {
      final items = kidsPath(ctx).firstWhere((b) => b.id == id).items(ctx);
      expect(items, hasLength(1), reason: id);
      expect(items.single.id, 'kids.$id.read');
      // Reading is graded by doing it, so it must NOT be marked done merely
      // for being opened.
      expect(items.single.completeOnOpen, isFalse, reason: id);
    }
  });
}
