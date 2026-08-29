import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../data/extra_letters.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../data/tracing_levels.dart';
import '../../widgets/common.dart' show QuizScreen, UnitPhase;
import '../../widgets/lesson.dart';
import '../lessons/forms_lessons.dart';
import '../lessons/forms_quizzes.dart';
import '../qaidah_screen.dart'
    show LetterDetail, letterQuizScreen, qaidahUnits;
import '../script_screen.dart' show scriptUnits;
import '../tajweed_screen.dart' show tajwidUnits;
import 'kids_desktop_nav.dart';
import 'kids_letter_flow.dart';
import 'kids_reading_screen.dart';

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
/// **Later blocks reuse the grown-up path's own lessons and quizzes** rather
/// than duplicating the content — see [_unitBlock]. They render under the
/// kids palette because both shells publish a `PaletteScope`.

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
  final level = tracingLevels.firstWhere((t) => t.id == levelId,
      orElse: () => tracingLevels.firstWhere((t) => !t.words));
  return [for (final f in level.formsPresentFor(l.char)) if (f != 'iso') f];
}

KidsItem _letterItem(String blockId, String levelId, ArabicLetter l) =>
    KidsItem(
      // Block 1 keeps the original id; every later block namespaces itself.
      id: blockId == 'letters.more'
          ? 'kids.letter.${l.char}'
          : 'kids.$blockId.${l.char}',
      glyph: l.char,
      label: (c) => letterName(c, l),
      open: (c) => KidsLetterFlow(
        letter: l.char,
        levelId: levelId,
        progressId: blockId == 'letters.more'
            ? 'kids.letter.${l.char}'
            : 'kids.$blockId.${l.char}',
      ),
    );

KidsItem _formsItem(String blockId, String levelId, ArabicLetter l) {
  final forms = _formsOf(levelId, l);
  return KidsItem(
    id: 'kids.$blockId.${l.char}',
    glyph: l.joins ? l.medial : l.finalForm,
    label: (c) => letterName(c, l),
    open: (c) => KidsLetterFlow(
      letter: l.char,
      levelId: levelId,
      forms: forms.isEmpty ? const ['iso'] : forms,
      progressId: 'kids.$blockId.${l.char}',
    ),
  );
}

KidsItem _quizItem(String id, String Function(BuildContext) label,
        Widget Function(BuildContext) open) =>
    KidsItem(
        id: id, icon: Icons.quiz_rounded, label: label, open: open);

KidsItem _lessonItem(String id, String Function(BuildContext) label,
        Widget Function(BuildContext) open) =>
    KidsItem(
      id: id,
      icon: Icons.menu_book_rounded,
      label: label,
      open: open,
      completeOnOpen: true,
    );

/// A block built from one of the grown-up units: its Learn page, then its
/// Test. This is the whole of the "reuse, don't re-author" decision — the
/// Qāʿidah units (ḥarakāt through waṣl), the Script & Symbols units (waqf),
/// and the Tajwīd units all already have real lessons and real quizzes, and a
/// second kid-only copy of each would be a second thing to keep correct.
///
/// [phases] is a function rather than a progress id because the three unit
/// types are separate classes that happen to share a shape: `QaidahUnit`,
/// `ScriptUnit` and `TajwidUnit` all carry a `List<UnitPhase>`, but nothing
/// in the app declares that as a common interface.
KidsBlock _unitBlock({
  required String id,
  required String badge,
  required List<UnitPhase> Function(BuildContext) phases,
  required String Function(BuildContext) title,
  required String Function(BuildContext) subtitle,
}) =>
    KidsBlock(
      id: id,
      title: title,
      subtitle: subtitle,
      badge: badge,
      items: (c) {
        final ps = phases(c);
        final learn = ps.isNotEmpty ? ps[0].builder : null;
        final test = ps.length > 1 ? ps[1].builder : null;
        return [
          // The lesson item carries the STAGE's name, not the generic
          // "Learn" — Home's resume card shows the item's label, and
          // "Next: Learn" tells a child nothing about what is next.
          if (learn != null) _lessonItem('kids.$id.learn', title, learn),
          if (test != null)
            _quizItem('kids.$id.test', (c) => c.l10n.phaseTest, test),
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
}) =>
    KidsBlock(
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

List<UnitPhase> _qaidah(BuildContext c, String progressId) =>
    qaidahUnits(c).firstWhere((u) => u.progressId == progressId).phases;

List<UnitPhase> _tajwid(BuildContext c, String progressId) =>
    tajwidUnits(c).firstWhere((u) => u.progressId == progressId).phases;

List<UnitPhase> _script(BuildContext c, String progressId) =>
    scriptUnits(c).firstWhere((u) => u.progressId == progressId).phases;

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
              open: (c) => LetterDetail(letter: l),
              completeOnOpen: true,
            );
          }()
    ];

// ── the path ──────────────────────────────────────────────────────────────

List<KidsBlock> kidsPath(BuildContext context) => [
      KidsBlock(
        id: 'letters.more',
        title: (c) => c.l10n.kidsBlockLetters,
        subtitle: (c) => c.l10n.kidsBlockLettersSub,
        badge: 'ا ب',
        items: (c) => [
          for (final l in letters) _letterItem('letters.more', 'naskh_more', l),
        ],
      ),
      KidsBlock(
        id: 'letters.quiz',
        title: (c) => c.l10n.kidsBlockLettersQuiz,
        subtitle: (c) => c.l10n.kidsBlockQuizSub,
        badge: '؟',
        items: (c) => [
          _quizItem('kids.quiz.letters', (c) => c.l10n.letterQuiz,
              (c) => letterQuizScreen(c)),
        ],
      ),
      KidsBlock(
        id: 'letters.few',
        title: (c) => c.l10n.kidsBlockLettersFew,
        subtitle: (c) => c.l10n.kidsBlockLettersFewSub,
        badge: 'ا ب',
        items: (c) => [
          for (final l in letters) _letterItem('letters.few', 'naskh_few', l),
        ],
      ),
      KidsBlock(
        id: 'forms.more',
        title: (c) => c.l10n.kidsBlockForms,
        subtitle: (c) => c.l10n.kidsBlockFormsSub,
        badge: 'ـبـ',
        items: (c) => [
          for (final l in letters) _formsItem('forms.more', 'naskh_more', l),
        ],
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
              (c) => formsVarietyQuiz(c, progressId: 'kids.quiz.forms')),
        ],
      ),
      KidsBlock(
        id: 'forms.few',
        title: (c) => c.l10n.kidsBlockFormsFew,
        subtitle: (c) => c.l10n.kidsBlockLettersFewSub,
        badge: 'ـبـ',
        items: (c) => [
          for (final l in letters) _formsItem('forms.few', 'naskh_few', l),
        ],
      ),
      KidsBlock(
        id: 'special',
        title: (c) => c.l10n.kidsBlockSpecial,
        subtitle: (c) => c.l10n.kidsBlockSpecialSub,
        badge: 'لا',
        items: (c) => [
          for (final (id, node) in [
            ('ligatures', ligaturesGroupNode),
            ('kaf', kafWrapGroupNode),
            ('stacks', stackingGroupNode),
            ('heights', heightsGroupNode),
          ])
            _lessonItem('kids.special.$id', (c) => node(c).title,
                (c) => lessonEntryScreen(node(c))),
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
          // The grown-up Joining Forms unit's Practice round is exactly this
          // material — lām-alif, the kāf wraps, the stacks, the hamza
          // carriers — so it is reused rather than re-authored.
          _quizItem('kids.quiz.special', (c) => c.l10n.formsQuiz,
              (c) => qaidahUnits(c)
                  .firstWhere((u) => u.progressId == 'qaidah.forms')
                  .phases[2]
                  .builder!(c)),
        ],
      ),
      // ── from here on, the grown-up path's own units, in the Qāʿidah order
      // the child is ready for them. Ḥurūf Muqaṭṭaʿah sits AFTER madd and
      // tanwīn, not before: reading مٓ needs the six counts, so a child who
      // met it earlier could only imitate the sound.
      _unitBlock(
          id: 'harakat',
          badge: 'بَ',
          phases: (c) => _qaidah(c, 'qaidah.harakat'),
          title: (c) => c.l10n.unitHarakat,
          subtitle: (c) => c.l10n.unitHarakatSub),
      _unitBlock(
          id: 'sukun',
          badge: 'بۡ',
          phases: (c) => _qaidah(c, 'qaidah.sukun'),
          // The grown-up unit titles itself from the tashkīl data
          // (`tashkilName`); `mkSukun` is that same name as a plain string.
          title: (c) => c.l10n.mkSukun,
          subtitle: (c) => c.l10n.unitSukunSub),
      // Shaddah directly after sukūn: it IS sukūn plus a moving letter, and
      // the grown-up lesson literally builds it as بۡ + بَ = بَّ.
      _unitBlock(
          id: 'shadda',
          badge: 'بّ',
          phases: (c) => _qaidah(c, 'qaidah.shadda'),
          title: (c) => c.l10n.shaddah,
          subtitle: (c) => c.l10n.unitShaddahSub),
      _unitBlock(
          id: 'madd',
          badge: 'بَا',
          phases: (c) => _qaidah(c, 'qaidah.madd'),
          title: (c) => c.l10n.unitMaddLin,
          subtitle: (c) => c.l10n.unitMaddLinSub),
      _unitBlock(
          id: 'tanwin',
          badge: 'بً',
          phases: (c) => _qaidah(c, 'qaidah.tanwin'),
          title: (c) => c.l10n.unitTanwin,
          subtitle: (c) => c.l10n.unitTanwinSub),
      _unitBlock(
          id: 'muqattaat',
          badge: 'الٓمٓ',
          phases: (c) => _qaidah(c, 'qaidah.muqattaat'),
          title: (c) => c.l10n.unitMuqattaat,
          subtitle: (c) => c.l10n.unitMuqattaatSub),

      // ── words ──
      _unitBlock(
          id: 'words',
          badge: 'قُلۡ',
          phases: (c) => _qaidah(c, 'qaidah.words'),
          title: (c) => c.l10n.readingWords,
          subtitle: (c) => c.l10n.unitReadingWordsSub),
      _unitBlock(
          id: 'wasl',
          badge: 'ٱ',
          phases: (c) => _qaidah(c, 'qaidah.wasl'),
          title: (c) => c.l10n.unitWasl,
          subtitle: (c) => c.l10n.unitWaslSub),
      // Sun and moon letters ARE lām shamsiyyah/qamariyyah, so this is the
      // grown-up Tajwīd lām unit placed where a Qāʿidah actually teaches it —
      // with ٱل, right after waṣl — rather than repeated in the tajwīd block
      // at the end. Lām al-jalālah rides along in the same unit.
      _unitBlock(
          id: 'solar_lunar',
          badge: 'ال',
          phases: (c) => _tajwid(c, 'tajwid.lam'),
          title: (c) => c.l10n.kidsBlockSolarLunar,
          subtitle: (c) => c.l10n.kidsBlockSolarLunarSub),
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
                  questions: taMarbutaQuestions(c))),
        ],
      ),
      // How to stop — the rule that gives tāʼ marbūṭah its point, plus the
      // waqf signs themselves.
      _unitBlock(
          id: 'waqf',
          badge: 'صلى',
          phases: (c) => _script(c, 'script.waqf'),
          title: (c) => c.l10n.unitWaqfStopping,
          subtitle: (c) => c.l10n.unitWaqfStoppingSub),
      // Two words, then three: joining words up and reading them together,
      // over real text from the bundled corpus (see KidsReadingScreen).
      _readingBlock(
          id: 'words.two',
          badge: '٢',
          surah: 112, // al-Ikhlāṣ
          wordsPerChunk: 2,
          title: (c) => c.l10n.kidsBlockTwoWords),
      _readingBlock(
          id: 'words.three',
          badge: '٣',
          surah: 108, // al-Kawthar
          wordsPerChunk: 3,
          title: (c) => c.l10n.kidsBlockThreeWords),

      // ── tajwīd ──
      // Sun/moon letters (the lām unit) were taught with ٱl above, so they
      // are not repeated here.
      // Titles come straight from l10n rather than by looking the unit up
      // again: `_tajwid` already rebuilds the whole unit list once per row,
      // and resolving the title and subtitle that way would make it three.
      _unitBlock(
          id: 'tajwid.madd',
          badge: 'بَا',
          phases: (c) => _tajwid(c, 'tajwid.madd'),
          title: (c) => c.l10n.tjUnitMadd,
          subtitle: (c) => c.l10n.tjUnitMaddSub),
      _unitBlock(
          id: 'tajwid.mim',
          badge: 'مْ',
          phases: (c) => _tajwid(c, 'tajwid.mim'),
          title: (c) => c.l10n.tjUnitMim,
          subtitle: (c) => c.l10n.tjUnitMimSub),
      _unitBlock(
          id: 'tajwid.nun',
          badge: 'نْ',
          phases: (c) => _tajwid(c, 'tajwid.nun'),
          title: (c) => c.l10n.tjUnitNun,
          subtitle: (c) => c.l10n.tjUnitNunSub),
      _unitBlock(
          id: 'tajwid.qalqalah',
          badge: 'قْ',
          phases: (c) => _tajwid(c, 'tajwid.qalqalah'),
          title: (c) => c.l10n.tjUnitQalqalah,
          subtitle: (c) => c.l10n.tjUnitQalqalahSub),
      _unitBlock(
          id: 'tajwid.raa',
          badge: 'ر',
          phases: (c) => _tajwid(c, 'tajwid.raa'),
          title: (c) => c.l10n.tjUnitRaa,
          subtitle: (c) => c.l10n.tjUnitRaaSub),

      _unitBlock(
          id: 'review',
          badge: '۝',
          phases: (c) => _qaidah(c, 'qaidah.review'),
          title: (c) => c.l10n.qaidahReview,
          subtitle: (c) => c.l10n.unitReviewSub),
      // The capstone: everything, in one real sūrah, read āyah by āyah.
      _readingBlock(
          id: 'capstone',
          badge: '١١٢',
          surah: 112,
          wordsPerChunk: 0,
          wholeAyahs: true,
          title: (c) => c.l10n.kidsBlockCapstone,
          subtitle: (c) => c.l10n.kidsBlockCapstoneSub),
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
int kidsCurrentBlockIndex(BuildContext context, ProgressStore prog) {
  final path = kidsPath(context);
  for (var i = 0; i < path.length; i++) {
    final items = path[i].items(context);
    if (kidsItemsDone(prog, items) < items.length) return i;
  }
  return path.length - 1;
}

/// The item the child is up to within [items] — the first not cleared.
int kidsCurrentItemIndex(ProgressStore prog, List<KidsItem> items) {
  for (var i = 0; i < items.length; i++) {
    if (prog.starsFor(items[i].id) == 0) return i;
  }
  return items.length;
}
