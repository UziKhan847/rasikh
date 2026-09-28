import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../data/extra_letters.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../data/tajwid_path.dart' show tajwidTopicById;
import '../../data/tashkeel.dart' show tashkil;
import '../../data/tracing_levels.dart';
import '../../widgets/common.dart' show QuizScreen;
import '../lessons/forms_quizzes.dart' show taMarbutaQuestions;
import 'kids_checkpoint_quiz.dart';
import 'kids_desktop_nav.dart';
import 'kids_extra_letter_lesson.dart';
import 'kids_game_bingo.dart';
import 'kids_game_memory_match.dart';
import 'kids_game_three_in_a_row.dart';
import 'kids_join_letters.dart';
import 'kids_lookalike_quiz.dart' show kidsLearnedLetters;
import 'kids_letter_flow.dart';
import 'kids_madd_lesson.dart';
import 'kids_mark_words_lesson.dart';
import 'kids_muqattaat_lesson.dart';
import 'kids_reading_screen.dart';
import 'kids_special_shapes_lesson.dart';
import 'kids_review_recap.dart';
import 'kids_solar_lunar_lesson.dart';
import 'kids_stage_quizzes.dart';
import 'kids_syllable_drill.dart';
import 'kids_tanwin_shapes_lesson.dart';
import 'kids_tajwid_rule_lesson.dart';
import 'kids_waqf_lesson.dart';
import 'kids_wasl_lesson.dart';
import 'kids_words_lesson.dart';

/// The Kids Mode curriculum, as data.
///
/// Kids Mode shipped as a flat list of 28 letters, which is where a Qāʿidah
/// *begins*, not what it covers. This is the whole path — letters, joining
/// forms, special shapes, ḥarakāt, madd, tanwīn, the muqaṭṭaʿāt, words and
/// tajwīd — in the order a classical Qāʿidah teaches it.
///
/// Two levels, because that is what the screens need: a [KidsBlock] is one
/// row on the Learn tab, and its [KidsItem]s are the tiles inside it. Blocks
/// unlock in order, and items unlock in order within a block.
///
/// **Nothing on this path opens a grown-up Learn page, and no Test asks a
/// grown-up question.** A stage's Test is its own kid lesson's check-ups with
/// the cards taken away (`quiz:` on the lesson), or — for the drills and the
/// closing review, whose lessons are not check-driven — a short kid-worded
/// quiz over the same reviewed data (`kids_stage_quizzes.dart`); both report
/// under `kids.<stage>.test`. Learn content is kid-native throughout: hand-built for the letters and joining shapes
/// (`kids_letter_flow.dart`), and for every later stage its own dedicated
/// lesson (`kids_syllable_drill.dart`, `kids_solar_lunar_lesson.dart`,
/// `kids_madd_lesson.dart`, `kids_muqattaat_lesson.dart`,
/// `kids_words_lesson.dart`, `kids_wasl_lesson.dart`, `kids_waqf_lesson.dart`,
/// `kids_tajwid_rule_lesson.dart`, `kids_review_recap.dart`). They render
/// under the kids palette because both shells publish a `PaletteScope`.

/// One tile in a block: a letter to trace, a quiz to sit, or a lesson to read.
class KidsItem {
  /// Progress key. Unique across the whole path, and **stable** — the letter
  /// items deliberately keep the original `kids.letter.<char>` ids so nothing
  /// already earned is orphaned by the path growing around them.
  final String id;

  /// Arabic to show on the tile. Empty for a non-letter item, which shows
  /// [icon] instead.
  final String glyph;
  final IconData icon;
  final String Function(BuildContext) label;
  final Widget Function(BuildContext) open;

  /// True when opening the item is all there is to it — a Learn page has
  /// nothing to grade, so the shell marks it done on open. A tracing lesson
  /// or a quiz reports its own stars and leaves this false.
  final bool completeOnOpen;

  const KidsItem({
    required this.id,
    required this.label,
    required this.open,
    this.glyph = '',
    this.icon = Icons.school_rounded,
    this.completeOnOpen = false,
  });
}

/// One stage of the path: a row on Learn, a cluster on the Home trail.
class KidsBlock {
  final String id;
  final String Function(BuildContext) title;
  final String Function(BuildContext) subtitle;

  /// The Arabic shown on the block's row, the way the grown-up Qāʿidah units
  /// carry a badge glyph ('ا ب', 'ـبـ', 'بَ').
  final String badge;
  final List<KidsItem> Function(BuildContext) items;

  const KidsBlock({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.items,
  });
}

// ── item builders ─────────────────────────────────────────────────────────

/// The shapes [l] actually has at [levelId], in writing order. A non-joiner
/// (ا و د ذ ر ز) has only two, so its lesson is two steps, not four — asking
/// a child to trace a medial dāl would be teaching a shape that doesn't exist.
List<String> _formsOf(String levelId, ArabicLetter l) {
  final level = tracingLevels.firstWhere(
    (t) => t.id == levelId,
    orElse: () => tracingLevels.firstWhere((t) => !t.words),
  );
  return [
    for (final f in level.formsPresentFor(l.char))
      if (f != 'iso') f,
  ];
}

/// A letter's whole lesson: meet the shape, say it out loud, then trace it —
/// several times over, in fewer, longer strokes. One lesson, not two: the
/// beginner stroke breakdown (`naskh_more`) used to run first, but an extra,
/// slower attempt before the real one taught nothing the writing pass didn't,
/// and only made the lesson longer. It stays in `tracing_levels.dart` for the
/// adult Tracing Studio, which still opens on it.
KidsItem _letterItem(ArabicLetter l) => KidsItem(
  // The original id, unchanged: anything already earned under it would
  // otherwise be orphaned, and `kidsLettersLearned` counts this prefix.
  id: 'kids.letter.${l.char}',
  glyph: l.char,
  label: (c) => letterName(c, l),
  open: (c) => KidsLetterFlow(
    letter: l.char,
    traces: const [
      KidsTraceStep('naskh_few', 'iso', repeat: kidsWritingPasses),
    ],
    progressId: 'kids.letter.${l.char}',
  ),
);

/// [l]'s joining-forms lessons — **one per shape it actually has**, not one
/// lesson covering all of them: بَاء gets three (start, middle, end), a
/// non-joiner (ا و د ذ ر ز) gets one (end — its only real joining shape,
/// since the isolated one is what [_letterItem] already taught). Each is
/// built exactly like a letter lesson: meet the shape, say it, then trace it
/// several times over.
///
/// This used to be a single 20-step lesson walking all of a joiner's shapes
/// in one sitting, opening on the isolated glyph the Letters stage had
/// already taught. Splitting it means each lesson is short, and the intro
/// step ([KidsLetterFlow._introForm]) shows the actual shape being taught —
/// or, for a non-joiner, a contrast card against the shape already known.
List<KidsItem> _formsItems(ArabicLetter l) {
  final forms = _formsOf('naskh_few', l);
  return [
    for (final f in forms.isEmpty ? const ['fin'] : forms)
      KidsItem(
        // A clean id per form — the old single-lesson-per-letter id
        // (`kids.forms.more.<char>`) is migrated onto these in
        // `ProgressStore.load()` rather than kept, since one lesson's worth
        // of progress cannot honestly become three.
        id: 'kids.forms.$f.${l.char}',
        glyph: _glyphInFormFor(l, f),
        label: (c) => letterName(c, l),
        open: (c) => KidsLetterFlow(
          letter: l.char,
          traces: [KidsTraceStep('naskh_few', f, repeat: kidsWritingPasses)],
          progressId: 'kids.forms.$f.${l.char}',
        ),
      ),
  ];
}

/// The glyph a Joining Shapes tile shows for [l] in position [form] — the
/// same rendering `ArabicLetter.initial`/`medial`/`finalForm` use.
String _glyphInFormFor(ArabicLetter l, String form) => switch (form) {
  'ini' => l.initial,
  'med' => l.medial,
  'fin' => l.finalForm,
  _ => l.char,
};

/// Interleaves a cumulative check-up after every [kidsCheckpointEvery]
/// lessons of a stage — after five letters a quiz on those five, after ten a
/// quiz on all ten, and so on. Only the two long stages (28 letters, 28 sets
/// of joining forms) are long enough for this to fire; every other stage is
/// one or two items and passes through untouched.
///
/// Nothing is added on the stage's own last lesson: a stage-wide quiz of its
/// own already follows immediately, and two quizzes back to back is a wall,
/// not a checkpoint.
List<KidsItem> _withCheckpoints(
  List<KidsItem> lessons,
  KidsItem Function(int upTo) checkpoint, {
  /// A game after every SECOND checkpoint (see [_gameItem]). Every other one
  /// on purpose: a game at every checkpoint would be the reward for finishing
  /// five lessons rather than a change of pace within a long stage.
  KidsItem Function(int upTo)? game,
}) {
  final out = <KidsItem>[];
  for (var i = 0; i < lessons.length; i++) {
    out.add(lessons[i]);
    final done = i + 1;
    if (done % kidsCheckpointEvery == 0 && done != lessons.length) {
      out.add(checkpoint(done));
      if (game != null && done % (kidsCheckpointEvery * 2) == 0) {
        out.add(game(done));
      }
    }
  }
  return out;
}

/// A checkpoint tile. Its id sits in its own `kids.check.` namespace on
/// purpose: the lesson ids are counted by prefix in several places
/// (`kidsLettersLearned` over `kids.letter.`, the joining-forms badge over
/// `kids.forms.more.`), and a checkpoint filed under one of those prefixes
/// would quietly inflate the count it is not part of.
KidsItem _checkpointItem(
  String stage,
  int upTo,
  QuizScreen Function(BuildContext, String progressId, int upTo) build,
) => KidsItem(
  id: 'kids.check.$stage.$upTo',
  icon: Icons.fact_check_rounded,
  label: (c) => c.l10n.kidsCheckpointFirst(upTo),
  open: (c) => build(c, 'kids.check.$stage.$upTo', upTo),
);

/// [_withCheckpoints]'s shape, for the Joining Shapes stage specifically:
/// [kidsFormsCheckpoint]'s `upTo` counts LETTERS, but a joiner now
/// contributes three lessons per letter against a non-joiner's one, so
/// counting by lesson position (as [_withCheckpoints] does) would misname a
/// check-up and quiz over more or fewer letters than it claims. This groups
/// each letter's own lessons together and counts letters, not lessons.
List<KidsItem> _formsWithCheckpoints(List<ArabicLetter> letters) {
  final out = <KidsItem>[];
  for (var i = 0; i < letters.length; i++) {
    out.addAll(_formsItems(letters[i]));
    final done = i + 1;
    if (done % kidsCheckpointEvery == 0 && done != letters.length) {
      out.add(
        _checkpointItem(
          'forms',
          done,
          (c, id, n) => kidsFormsCheckpoint(c, progressId: id, upTo: n),
        ),
      );
      if (done % (kidsCheckpointEvery * 2) == 0) {
        out.add(
          _gameItem(
            'kids.game.forms.$done',
            _gameAt(const [KidsPathGame.threeInARow, KidsPathGame.bingo], done),
          ),
        );
      }
    }
  }
  return out;
}

KidsItem _quizItem(
  String id,
  String Function(BuildContext) label,
  Widget Function(BuildContext) open,
) => KidsItem(id: id, icon: Icons.quiz_rounded, label: label, open: open);

KidsItem _lessonItem(
  String id,
  String Function(BuildContext) label,
  Widget Function(BuildContext) open,
) => KidsItem(
  id: id,
  icon: Icons.menu_book_rounded,
  label: label,
  open: open,
  completeOnOpen: true,
);

/// A stage built from real Qāʿidah Nūrāniyyah drills — [kidsDrillSessions]
/// [KidsSyllableDrill] sessions per mark in [markIds], together walking every
/// letter of the alphabet with that mark rather than a single prose page
/// about it. Closes on a Test built by [test] over the same marks.
KidsBlock _drillBlock({
  required String id,
  required String badge,
  required List<String> markIds,
  required QuizScreen Function(BuildContext, String testId) test,
  required String Function(BuildContext) title,
  required String Function(BuildContext) subtitle,
  /// Extra items between the drills and the Test — the tanwīn shapes lesson,
  /// and now the tamrīn word-practice item every drill stage gets (see
  /// [_wordPracticeItem]). Not a new BLOCK: adding one would move every later
  /// stage's index and every `kids_badges_test.dart`/`kids_path_test.dart`
  /// position pinned to it.
  List<KidsItem Function(BuildContext)> extra = const [],
}) => KidsBlock(
  id: id,
  title: title,
  subtitle: subtitle,
  badge: badge,
  items: (c) {
    final kidsTestId = 'kids.$id.test';
    return [
      // One tile per SESSION, not per mark: the whole alphabet with one mark
      // is ~32 steps, past what a young child sustains, so each mark opens
      // as [kidsDrillSessions] shorter runs (see [KidsSyllableDrill]).
      for (final markId in markIds)
        for (final (n, (from, to)) in kidsDrillRanges().indexed)
          () {
            final mark = tashkil.firstWhere((t) => t.id == markId);
            final drillId = 'kids.$id.$markId.${n + 1}';
            return KidsItem(
              id: drillId,
              // The first syllable of THIS session, so the three tiles of
              // one mark read بَ, سَ, غَ… instead of three identical glyphs.
              glyph:
                  '${kidsSyllableLetters[from].char}${mark.mark.substring(1)}',
              label: (c) => '${tashkilName(c, mark)} · ${n + 1}',
              icon: Icons.record_voice_over_rounded,
              open: (c) => KidsSyllableDrill(
                mark: mark,
                progressId: drillId,
                start: from,
                end: to,
              ),
            );
          }(),
      for (final e in extra) e(c),
      _quizItem(kidsTestId, (c) => c.l10n.phaseTest, (c) => test(c, kidsTestId)),
    ];
  },
);

/// The tamrīn every Qāʿidah runs after its own table: real muṣḥaf words
/// carrying [markIds], between a drill stage's last session and its Test (see
/// `_drillBlock`'s `extra`). Not fed word practice by this route: `tanwin`,
/// whose own [KidsTanwinShapesLesson] already shows a real, highlighted
/// muṣḥaf example for each of the three allograph shapes — a second,
/// generic word-practice item over the same nine examples would repeat it.
KidsItem _wordPracticeItem(String stageId, List<String> markIds) => KidsItem(
  id: 'kids.$stageId.words',
  icon: Icons.menu_book_rounded,
  label: (c) => c.l10n.kidsPracticeWordsTitle,
  open: (c) => KidsMarkWordsLesson(
    markIds: markIds,
    progressId: 'kids.$stageId.words',
  ),
);

/// Which of the three board games a path slot opens.
enum KidsPathGame { threeInARow, memoryMatch, bingo }

/// A game between lessons. The three games are Practice tiles too, on demand;
/// these slots are about PACING — a stage of twenty-eight letters is a long
/// way to walk on lessons and check-ups alone, and the games are the variety
/// in it. They fall where a checkpoint already does, so the rhythm reads as
/// "five lessons, a check-up, a game".
///
/// Its own `kids.game.` namespace, deliberately: the lesson ids are counted
/// by PREFIX in several places (`kidsLettersLearned` over `kids.letter.`, the
/// joining-forms badge over `kids.forms.`), and an item filed under one of
/// those would quietly inflate a count it is not part of — the same reasoning
/// [_checkpointItem] gives for its own namespace.
///
/// Which game a slot opens is fixed here rather than chosen when it opens: a
/// tile whose label changed between one look and the next is not something a
/// child can look forward to.
KidsItem _gameItem(String id, KidsPathGame which) => KidsItem(
  id: id,
  icon: Icons.videogame_asset_rounded,
  label: (c) => switch (which) {
    KidsPathGame.threeInARow => c.l10n.kidsGameThreeInARow,
    KidsPathGame.memoryMatch => c.l10n.kidsGameMemoryMatch,
    KidsPathGame.bingo => c.l10n.kidsGameBingo,
  },
  open: (c) {
    final known = _gameLetters(ProgressScope.of(c), which);
    return switch (which) {
      KidsPathGame.threeInARow =>
        KidsThreeInARow(known: known, progressId: id),
      KidsPathGame.memoryMatch =>
        KidsMemoryMatch(known: known, progressId: id),
      KidsPathGame.bingo => KidsGameBingo(known: known, progressId: id),
    };
  },
);

/// The letters a path game plays with: the ones actually cleared, topped up
/// from the front of the path if there are fewer than the board needs.
///
/// Every slot below sits far enough along that the top-up never fires in
/// normal play — but the dev unlock opens the whole path at once, and a tile
/// that threw when opened early would be worse than one that plays with the
/// first six letters.
List<ArabicLetter> _gameLetters(ProgressStore prog, KidsPathGame which) {
  final need = which == KidsPathGame.bingo ? 10 : 6;
  final known = kidsLearnedLetters(prog);
  if (known.length >= need) return known;
  final out = [...known];
  for (final l in letters) {
    if (out.length >= need) break;
    if (!out.any((k) => k.char == l.char)) out.add(l);
  }
  return out;
}

/// Picks a stage's game by position, so a child meets all three rather than
/// the same one every time — and never the same one twice running.
KidsPathGame _gameAt(List<KidsPathGame> order, int upTo) =>
    order[(upTo ~/ (kidsCheckpointEvery * 2) - 1).clamp(0, 1 << 30) %
        order.length];

/// A Tajwīd rule-family stage taught rule by rule (`KidsTajwidRuleLesson`) —
/// works for a family of any size, from qalqalah's one rule to nūn sākinah's
/// five — closing on the same rule checks as a Test (`quiz: true`), drawn
/// from every rule in the family. [ruleIds] comes from the same
/// `tajwidTopics` grouping the grown-up hub itself reads
/// (`lib/data/tajwid_path.dart`), so a rule added to a family there reaches
/// this lesson with no edit here.
KidsBlock _tajwidRuleBlock({
  required String id,
  required String badge,
  required String topicId,
  required IconData icon,
  required String Function(BuildContext) title,
  required String Function(BuildContext) subtitle,
}) => _gradedLessonBlock(
  id: id,
  badge: badge,
  learnBuilder: (c, learnId) => KidsTajwidRuleLesson(
    ruleIds: tajwidTopicById(topicId).ruleIds,
    progressId: learnId,
    icon: icon,
    title: title,
    subtitle: subtitle,
  ),
  testBuilder: (c, testId) => KidsTajwidRuleLesson(
    ruleIds: tajwidTopicById(topicId).ruleIds,
    progressId: testId,
    icon: icon,
    title: title,
    subtitle: subtitle,
    quiz: true,
  ),
  icon: icon,
  title: title,
  subtitle: subtitle,
);

/// A stage whose Learn side is a bespoke kid-native page — [learnBuilder] —
/// that is read rather than graded, and whose Test is [testBuilder]. Complete
/// on open: nothing on the page is gradeable in the way a quiz or a drill's
/// check-up is, so there is nothing to hold XP back for.
KidsBlock _kidLearnBlock({
  required String id,
  required String badge,
  required Widget Function(BuildContext) learnBuilder,
  required Widget Function(BuildContext, String testId) testBuilder,
  required String Function(BuildContext) title,
  required String Function(BuildContext) subtitle,
}) => KidsBlock(
  id: id,
  title: title,
  subtitle: subtitle,
  badge: badge,
  items: (c) {
    final kidsTestId = 'kids.$id.test';
    return [
      _lessonItem('kids.$id.learn', title, learnBuilder),
      _quizItem(kidsTestId, (c) => c.l10n.phaseTest, (c) => testBuilder(c, kidsTestId)),
    ];
  },
);

/// A stage whose Learn side is a bespoke kid-native lesson that grades
/// ITSELF (a `KidsSolarLunarLesson`, a `KidsMuqattaatLesson`, and so on —
/// anything with its own internal check-ups), rather than being
/// complete-on-open like [_kidLearnBlock]'s. The Test side is [testBuilder]:
/// the same lesson's checks with the cards taken away.
KidsBlock _gradedLessonBlock({
  required String id,
  required String badge,
  required Widget Function(BuildContext, String progressId) learnBuilder,
  required Widget Function(BuildContext, String testId) testBuilder,
  required IconData icon,
  required String Function(BuildContext) title,
  required String Function(BuildContext) subtitle,
}) => KidsBlock(
  id: id,
  title: title,
  subtitle: subtitle,
  badge: badge,
  items: (c) {
    final learnId = 'kids.$id.learn';
    final testId = 'kids.$id.test';
    return [
      KidsItem(
        id: learnId,
        icon: icon,
        label: title,
        open: (c) => learnBuilder(c, learnId),
      ),
      _quizItem(testId, (c) => c.l10n.phaseTest, (c) => testBuilder(c, testId)),
    ];
  },
);

/// A "read it aloud, then tap" stage over real text from the bundled corpus.
/// One item, because the reading itself is the whole stage.
KidsBlock _readingBlock({
  required String id,
  required String badge,
  required int surah,
  required int wordsPerChunk,
  required String Function(BuildContext) title,
  String Function(BuildContext)? subtitle,
  bool wholeAyahs = false,
}) => KidsBlock(
  id: id,
  title: title,
  subtitle: subtitle ?? (c) => c.l10n.kidsBlockWordsSub,
  badge: badge,
  items: (c) => [
    KidsItem(
      id: 'kids.$id.read',
      icon: Icons.auto_stories_rounded,
      label: title,
      open: (c) => KidsReadingScreen(
        surah: surah,
        wordsPerChunk: wordsPerChunk,
        wholeAyahs: wholeAyahs,
        progressId: 'kids.$id.read',
      ),
    ),
  ],
);

/// One sūrah of the closing reading ladder.
KidsBlock _surahBlock(KidsReadingSurah s) => _readingBlock(
  id: s.n == 112 ? 'capstone' : 'read.${s.n}',
  badge: _arabicIndic(s.n),
  surah: s.n,
  wordsPerChunk: s.wordsPerChunk,
  wholeAyahs: s.wordsPerChunk == 0,
  title: (c) => kidsSurahTitle(c, s),
  subtitle: (c) =>
      s.wordsPerChunk == 0 ? c.l10n.kidsBlockReadAyahSub : c.l10n.kidsBlockReadThreeSub,
);

/// [n] in Arabic-Indic digits — the way the muṣḥaf numbers a sūrah.
String _arabicIndic(int n) => [
  for (final d in '$n'.runes) String.fromCharCode(0x0660 + d - 0x30),
].join();

/// A block of "meet this character" pages, drawn from [extraLetters] — the
/// hamza carriers, tāʼ marbūṭah and alif maqṣūrah that the 28-letter alphabet
/// does not cover but the muṣḥaf uses constantly.
List<KidsItem> _extraLetterItems(String blockId, List<String> chars) => [
  for (final ch in chars)
    if (extraLetters.any((l) => l.char == ch))
      () {
        final l = extraLetters.firstWhere((x) => x.char == ch);
        return KidsItem(
          id: 'kids.$blockId.$ch',
          glyph: ch,
          label: (c) => letterName(c, l),
          open: (c) => KidsExtraLetterLesson(char: ch),
          completeOnOpen: true,
        );
      }(),
];

// ── the path ──────────────────────────────────────────────────────────────

List<KidsBlock> kidsPath(BuildContext context) => [
  KidsBlock(
    id: 'letters',
    title: (c) => c.l10n.kidsBlockLetters,
    subtitle: (c) => c.l10n.kidsBlockLettersSub,
    badge: 'ا ب',
    items: (c) => _withCheckpoints(
      [for (final l in letters) _letterItem(l)],
      (upTo) => _checkpointItem(
        'letters',
        upTo,
        (c, id, n) => kidsLetterCheckpoint(c, progressId: id, upTo: n),
      ),
      // Bingo is not offered here: it needs ten letters on a sixteen-cell
      // board, and the first slot falls at ten exactly. It comes in Joining
      // Shapes, by which point the whole alphabet is behind the child.
      game: (upTo) => _gameItem(
        'kids.game.letters.$upTo',
        _gameAt(const [
          KidsPathGame.memoryMatch,
          KidsPathGame.threeInARow,
        ], upTo),
      ),
    ),
  ),
  KidsBlock(
    id: 'letters.quiz',
    title: (c) => c.l10n.kidsBlockLettersQuiz,
    subtitle: (c) => c.l10n.kidsBlockQuizSub,
    badge: '؟',
    items: (c) => [
      _quizItem(
        'kids.quiz.letters',
        (c) => c.l10n.letterQuiz,
        // A cumulative check-up over the whole alphabet — shape→name AND
        // name→shape, with each letter's look-alikes as its distractors —
        // rather than the grown-up name-only quiz this used to reuse.
        (c) => kidsLetterCheckpoint(
          c,
          progressId: 'kids.quiz.letters',
          upTo: kidsLetterPath.length,
        ),
      ),
    ],
  ),
  KidsBlock(
    // The id is the old "more strokes" stage's, kept so progress recorded
    // under it survives the two stroke stages being merged into one.
    id: 'forms.more',
    title: (c) => c.l10n.kidsBlockForms,
    subtitle: (c) => c.l10n.kidsBlockFormsSub,
    badge: 'ـبـ',
    items: (c) => _formsWithCheckpoints(letters),
  ),
  KidsBlock(
    id: 'forms.quiz',
    title: (c) => c.l10n.kidsBlockFormsQuiz,
    subtitle: (c) => c.l10n.kidsBlockQuizSub,
    badge: '؟',
    items: (c) => [
      _quizItem(
        'kids.quiz.forms',
        (c) => c.l10n.formsQuiz,
        // A cumulative check-up over every joining shape — a shape → its
        // letter and a letter + position → its shape, with each letter's
        // look-alikes as distractors — like the Letters quiz, rather than the
        // grown-up "pick the letter AND its form from a grid of twelve".
        (c) => kidsFormsCheckpoint(
          c,
          progressId: 'kids.quiz.forms',
          upTo: kidsLetterPath.length,
        ),
      ),
    ],
  ),
  // Every shape has been met one at a time; here they are put to use, by hand.
  // Its own `kids.join.` namespace — not `kids.forms.`, which the joining-forms
  // badge counts by prefix.
  KidsBlock(
    id: 'join',
    title: (c) => c.l10n.kidsJoinTitle,
    subtitle: (c) => c.l10n.kidsBlockJoinSub,
    badge: 'بيت',
    items: (c) => [
      KidsItem(
        id: 'kids.join.words',
        icon: Icons.link_rounded,
        label: (c) => c.l10n.kidsJoinTitle,
        open: (c) => const KidsJoinLettersLesson(progressId: 'kids.join.words'),
      ),
    ],
  ),
  // No "Shapes Again" stage here: the fewer-strokes pass it used to be
  // now sits inside each joining-forms lesson above, where the shape is
  // already in the child's hand.
  KidsBlock(
    id: 'special',
    title: (c) => c.l10n.kidsBlockSpecial,
    subtitle: (c) => c.l10n.kidsBlockSpecialSub,
    badge: 'لا',
    items: (c) => [
      for (final (id, group, icon, title)
          in <(String, String, IconData, String Function(BuildContext))>[
            (
              'ligatures',
              'ligature',
              Icons.link_rounded,
              (c) => c.l10n.lsnLigatures,
            ),
            ('kaf', 'kaf', Icons.route_rounded, (c) => c.l10n.lsnKafsWrap),
            (
              'stacks',
              'stacking',
              Icons.layers_rounded,
              (c) => c.l10n.lsnStacking,
            ),
            (
              'heights',
              'tails',
              Icons.height_rounded,
              (c) => c.l10n.lsnHeightsAndTails,
            ),
          ])
        KidsItem(
          id: 'kids.special.$id',
          icon: icon,
          label: title,
          open: (c) => KidsSpecialShapesLesson(
            group: group,
            progressId: 'kids.special.$id',
          ),
        ),
      // The characters the 28-letter alphabet leaves out but the muṣḥaf
      // uses on every page. Tāʼ marbūṭah gets its own stage later, with
      // the stopping rule that makes it worth teaching separately.
      ..._extraLetterItems('special', const ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى']),
    ],
  ),
  KidsBlock(
    id: 'special.quiz',
    title: (c) => c.l10n.kidsBlockSpecialQuiz,
    subtitle: (c) => c.l10n.kidsBlockQuizSub,
    badge: '؟',
    items: (c) => [
      _quizItem(
        'kids.quiz.special',
        (c) => c.l10n.formsQuiz,
        (c) => kidsSpecialShapesQuiz(c, progressId: 'kids.quiz.special'),
      ),
    ],
  ),
  // ── from here on, the grown-up path's own units, in the Qāʿidah order
  // the child is ready for them. Ḥurūf Muqaṭṭaʿah sits AFTER madd and
  // tanwīn, not before: reading مٓ needs the six counts, so a child who
  // met it earlier could only imitate the sound.
  // Real Qāʿidah Nūrāniyyah drills — بَ تَ ثَ … one mark at a time, letter
  // by letter, rather than a single prose page about the mark in the
  // abstract. See [_drillBlock] and [KidsSyllableDrill].
  _drillBlock(
    id: 'harakat',
    badge: 'بَ',
    test: (c, id) => kidsSyllableQuiz(
      c,
      title: c.l10n.unitHarakat,
      progressId: id,
      markIds: const ['fatha', 'kasra', 'damma'],
    ),
    markIds: const ['fatha', 'kasra', 'damma'],
    title: (c) => c.l10n.unitHarakat,
    subtitle: (c) => c.l10n.unitHarakatSub,
    extra: [
      (c) => _wordPracticeItem('harakat', const ['fatha', 'kasra', 'damma']),
      (c) => _gameItem('kids.game.harakat', KidsPathGame.bingo),
    ],
  ),
  _drillBlock(
    id: 'sukun',
    badge: 'بۡ',
    test: (c, id) => kidsMarkSpotQuiz(
      c,
      title: c.l10n.mkSukun,
      progressId: id,
      markId: 'sukun',
    ),
    markIds: const ['sukun'],
    // The grown-up unit titles itself from the tashkīl data
    // (`tashkilName`); `mkSukun` is that same name as a plain string.
    title: (c) => c.l10n.mkSukun,
    subtitle: (c) => c.l10n.unitSukunSub,
    extra: [
      (c) => _wordPracticeItem('sukun', const ['sukun']),
      (c) => _gameItem('kids.game.sukun', KidsPathGame.memoryMatch),
    ],
  ),
  // Shaddah directly after sukūn: it IS sukūn plus a moving letter, and
  // the grown-up lesson literally builds it as بۡ + بَ = بَّ.
  _drillBlock(
    id: 'shadda',
    badge: 'بّ',
    test: (c, id) => kidsMarkSpotQuiz(
      c,
      title: c.l10n.shaddah,
      progressId: id,
      markId: 'shadda',
    ),
    markIds: const ['shadda'],
    title: (c) => c.l10n.shaddah,
    subtitle: (c) => c.l10n.unitShaddahSub,
    extra: [
      (c) => _wordPracticeItem('shadda', const ['shadda']),
      (c) => _gameItem('kids.game.shadda', KidsPathGame.threeInARow),
    ],
  ),
  _kidLearnBlock(
    id: 'madd',
    badge: 'بَا',
    testBuilder: (c, id) => KidsMaddLesson(quiz: true, progressId: id),
    learnBuilder: (c) => const KidsMaddLesson(),
    title: (c) => c.l10n.unitMaddLin,
    subtitle: (c) => c.l10n.unitMaddLinSub,
  ),
  _drillBlock(
    id: 'tanwin',
    badge: 'بً',
    test: (c, id) => kidsTanwinTest(c, progressId: id),
    markIds: const ['fathatan', 'kasratan', 'dammatan'],
    title: (c) => c.l10n.unitTanwin,
    subtitle: (c) => c.l10n.unitTanwinSub,
    extra: [
      (c) => KidsItem(
        id: 'kids.tanwin.shapes',
        icon: Icons.looks_rounded,
        label: (c) => c.l10n.kidsTanwinShapesTitle,
        open: (c) =>
            const KidsTanwinShapesLesson(progressId: 'kids.tanwin.shapes'),
      ),
      (c) => _gameItem('kids.game.tanwin', KidsPathGame.bingo),
    ],
  ),
  _gradedLessonBlock(
    id: 'muqattaat',
    badge: 'الٓمٓ',
    testBuilder: (c, id) => KidsMuqattaatLesson(progressId: id, quiz: true),
    learnBuilder: (c, id) => KidsMuqattaatLesson(progressId: id),
    icon: Icons.spellcheck_rounded,
    title: (c) => c.l10n.unitMuqattaat,
    subtitle: (c) => c.l10n.unitMuqattaatSub,
  ),

  // ── words ──
  _gradedLessonBlock(
    id: 'words',
    badge: 'قُلۡ',
    testBuilder: (c, id) => KidsWordsLesson(progressId: id, quiz: true),
    learnBuilder: (c, id) => KidsWordsLesson(progressId: id),
    icon: Icons.auto_stories_rounded,
    title: (c) => c.l10n.readingWords,
    subtitle: (c) => c.l10n.unitReadingWordsSub,
  ),
  _gradedLessonBlock(
    id: 'wasl',
    badge: 'ٱ',
    testBuilder: (c, id) => KidsWaslLesson(progressId: id, quiz: true),
    learnBuilder: (c, id) => KidsWaslLesson(progressId: id),
    icon: Icons.link_rounded,
    title: (c) => c.l10n.unitWasl,
    subtitle: (c) => c.l10n.unitWaslSub,
  ),
  // Sun and moon letters ARE lām shamsiyyah/qamariyyah, so this is the
  // grown-up Tajwīd lām unit placed where a Qāʿidah actually teaches it —
  // with ٱل, right after waṣl — rather than repeated in the tajwīd block
  // at the end. Lām al-jalālah rides along in the same unit.
  _gradedLessonBlock(
    id: 'solar_lunar',
    badge: 'ال',
    testBuilder: (c, id) => KidsSolarLunarLesson(progressId: id, quiz: true),
    learnBuilder: (c, id) => KidsSolarLunarLesson(progressId: id),
    icon: Icons.wb_sunny_rounded,
    title: (c) => c.l10n.kidsBlockSolarLunar,
    subtitle: (c) => c.l10n.kidsBlockSolarLunarSub,
  ),
  KidsBlock(
    id: 'tamarbuta',
    title: (c) => c.l10n.kidsBlockTaMarbuta,
    subtitle: (c) => c.l10n.kidsBlockTaMarbutaSub,
    badge: 'ة',
    items: (c) => [
      ..._extraLetterItems('tamarbuta', const ['ة']),
      _quizItem(
        'kids.tamarbuta.test',
        (c) => c.l10n.phaseTest,
        (c) => QuizScreen(
          title: c.l10n.kidsBlockTaMarbuta,
          progressId: 'kids.tamarbuta.test',
          questions: taMarbutaQuestions(c),
        ),
      ),
    ],
  ),
  // How to stop — the rule that gives tāʼ marbūṭah its point, plus the
  // waqf signs themselves.
  _gradedLessonBlock(
    id: 'waqf',
    badge: 'صلى',
    testBuilder: (c, id) => KidsWaqfLesson(progressId: id, quiz: true),
    learnBuilder: (c, id) => KidsWaqfLesson(progressId: id),
    icon: Icons.traffic_rounded,
    title: (c) => c.l10n.unitWaqfStopping,
    subtitle: (c) => c.l10n.unitWaqfStoppingSub,
  ),
  // Two words, then three: joining words up and reading them together,
  // over real text from the bundled corpus (see KidsReadingScreen).
  _readingBlock(
    id: 'words.two',
    badge: '٢',
    surah: 112, // al-Ikhlāṣ
    wordsPerChunk: 2,
    title: (c) => c.l10n.kidsBlockTwoWords,
  ),
  _readingBlock(
    id: 'words.three',
    badge: '٣',
    surah: 108, // al-Kawthar
    wordsPerChunk: 3,
    title: (c) => c.l10n.kidsBlockThreeWords,
  ),

  // ── tajwīd ──
  // Sun/moon letters (the lām unit) were taught with ٱl above, so they
  // are not repeated here.
  // Titles come straight from l10n rather than by looking the unit up
  // again: `_tajwid` already rebuilds the whole unit list once per row,
  // and resolving the title and subtitle that way would make it three.
  _tajwidRuleBlock(
    id: 'tajwid.madd',
    badge: 'بَا',
    topicId: 'madd',
    icon: Icons.timelapse_rounded,
    title: (c) => c.l10n.tjUnitMadd,
    subtitle: (c) => c.l10n.tjUnitMaddSub,
  ),
  _tajwidRuleBlock(
    id: 'tajwid.mim',
    badge: 'مْ',
    topicId: 'mim',
    icon: Icons.record_voice_over_rounded,
    title: (c) => c.l10n.tjUnitMim,
    subtitle: (c) => c.l10n.tjUnitMimSub,
  ),
  _tajwidRuleBlock(
    id: 'tajwid.nun',
    badge: 'نْ',
    topicId: 'nun',
    icon: Icons.record_voice_over_rounded,
    title: (c) => c.l10n.tjUnitNun,
    subtitle: (c) => c.l10n.tjUnitNunSub,
  ),
  _tajwidRuleBlock(
    id: 'tajwid.qalqalah',
    badge: 'قْ',
    topicId: 'qalqalah',
    icon: Icons.bolt_rounded,
    title: (c) => c.l10n.tjUnitQalqalah,
    subtitle: (c) => c.l10n.tjUnitQalqalahSub,
  ),
  _tajwidRuleBlock(
    id: 'tajwid.raa',
    badge: 'ر',
    topicId: 'raa',
    icon: Icons.graphic_eq_rounded,
    title: (c) => c.l10n.tjUnitRaa,
    subtitle: (c) => c.l10n.tjUnitRaaSub,
  ),

  _kidLearnBlock(
    id: 'review',
    badge: '۝',
    testBuilder: (c, id) =>
        kidsReviewQuiz(c, title: c.l10n.qaidahReview, progressId: id),
    learnBuilder: (c) => const KidsReviewRecap(),
    title: (c) => c.l10n.qaidahReview,
    subtitle: (c) => c.l10n.unitReviewSub,
  ),
  // The reading ladder: from az-Zalzalah to an-Nās, every sūrah of the last
  // two juz' that a child can read on their own, one stage each, in muṣḥaf
  // order. al-Ikhlāṣ keeps the id it had as the single "capstone" sūrah.
  for (final s in kidsReadingSurahs) _surahBlock(s),
];

// ── opening and progress ──────────────────────────────────────────────────

/// Opens [item] in the shell (a pushed route on mobile, the content pane on
/// desktop).
///
/// A [KidsItem.completeOnOpen] item is marked done on the way in: it is a
/// Learn page, so there is nothing to grade, and leaving it uncleared would
/// stall the whole path behind a page the child has already read.
void openKidsItem(BuildContext context, KidsItem item) {
  if (item.completeOnOpen) {
    final prog = ProgressScope.of(context);
    prog.report(item.id, 1);
    prog.awardXp(kidsXpPerStar);
  }
  pushKidsOverlay(context, title: item.label(context), builder: item.open);
}

// ── progress ──────────────────────────────────────────────────────────────

/// How many of [items] are cleared.
///
/// Takes the already-built list rather than a [KidsBlock]: building a stage's
/// items is not free — the reused grown-up stages construct the whole Qāʿidah
/// unit list to find their phases — and the Learn tab would otherwise do it
/// twice per row, every frame.
int kidsItemsDone(ProgressStore prog, List<KidsItem> items) {
  var n = 0;
  for (final item in items) {
    if (prog.starsFor(item.id) > 0) n++;
  }
  return n;
}

/// The block the child is up to: the first with unfinished items, or the last
/// one once the whole path is cleared.
///
/// Under the testing unlock, [ProgressStore.devStage] can pin this to any
/// stage instead — so Home, and the Learn tab's "current" row, can be pointed
/// at a stage under test without actually clearing everything before it. Real
/// progress is untouched either way; this only changes which stage the app
/// treats as "where the child is right now".
int kidsCurrentBlockIndex(BuildContext context, ProgressStore prog) {
  final path = kidsPath(context);
  if (prog.unlockAll && prog.devStage != null) {
    final pinned = path.indexWhere((b) => b.id == prog.devStage);
    if (pinned != -1) return pinned;
  }
  for (var i = 0; i < path.length; i++) {
    final items = path[i].items(context);
    if (kidsItemsDone(prog, items) < items.length) return i;
  }
  return path.length - 1;
}

/// Whether the stage row or tile at [index] is still shut, given that
/// everything up to [reached] is open.
///
/// The one place the answer is decided, so the testing unlock
/// ([ProgressStore.unlockAll]) cannot be honoured on the Learn tab and
/// forgotten on the Home trail. It lifts locks and nothing else: what counts
/// as *done* is still only what was actually finished, so a stage opened this
/// way still shows 0 / 28 and still has to be played to clear.
bool kidsLocked(ProgressStore prog, int index, int reached) =>
    index > reached && !prog.unlockAll;

/// The item the child is up to within [items] — the first not cleared.
int kidsCurrentItemIndex(ProgressStore prog, List<KidsItem> items) {
  for (var i = 0; i < items.length; i++) {
    if (prog.starsFor(items[i].id) == 0) return i;
  }
  return items.length;
}
