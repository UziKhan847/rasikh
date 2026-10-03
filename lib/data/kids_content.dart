import 'package:flutter/widgets.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import 'kids_avatars.dart' show kidsAnimals;
import 'letters.dart';

/// The curated letter path Kids Mode teaches, in order. This is the same
/// traditional ordering `data/letters.dart` already uses everywhere else in
/// the app (and what the grown-up Qaidah path teaches) — reusing it means a
/// family with both a parent on the adult app and a child on Kids Mode sees
/// the same letter order, not two competing curricula.
List<ArabicLetter> get kidsLetterPath => letters;

/// Total Joining Shapes lessons across the whole path: three per letter that
/// joins both ways (start, middle, end), one for a non-joiner (ا و د ذ ر ز —
/// its only real joining shape is the end form; the isolated one is what the
/// Letters stage already taught). Used by the `forms_few_cleared` badge,
/// which used to just check `kidsLetterPath.length` back when this stage was
/// one lesson per letter rather than one per shape.
int get kidsFormsLessonCount => kidsLetterPath
    .fold(0, (n, l) => n + (l.joins ? 3 : 1));

// ── XP & gems — gems are earned only; there is no purchase path anywhere in
// Kids Mode, only these award sites. See test/kids_mode_test.dart. ──
const kidsXpPerStar = 10; // per star (0-3) earned on a lesson step
const kidsGemsPerLesson = 5; // flat, per completed letter (trace + sentence)
const kidsGemsBonusPerfect = 10; // extra when every step earned 3 stars
const kidsGemsPerBadge = 15; // awarded once, the moment a badge unlocks
const kidsDailyGoal = 5; // lessons/day shown on the Home goal ring

/// How many times a shape is written in the fewer-strokes pass — the pass
/// nearest to actually handwriting it. Handwriting is learned by repetition,
/// so every tracing lesson (a letter, and each joining form of it) ends on
/// this many goes at the same shape, graded on the best of them.
const kidsWritingPasses = 5;

/// One sūrah on the reading ladder.
class KidsReadingSurah {
  final int n;

  /// As the muṣḥaf writes it — checked against the bundled `meta.json`.
  final String arabic;
  final String translit;

  /// 0 = the whole āyah on one line, else that many words to a line.
  final int wordsPerChunk;
  const KidsReadingSurah(this.n, this.arabic, this.translit, this.wordsPerChunk);
}

/// The sūrahs a child reads on the path's closing ladder, in muṣḥaf order —
/// from az-Zalzalah to an-Nās. The longer āyāt of the first ones come three
/// words to a line; from al-Fīl on a line is a whole āyah.
///
/// (Two earlier stages — "Two Words" and "Three Words", over al-Ikhlāṣ and
/// al-Kawthar — teach the skill before this; the ladder is where it is used.)
const kidsReadingSurahs = <KidsReadingSurah>[
  KidsReadingSurah(99, 'الزلزلة', 'Az-Zalzalah', 3),
  KidsReadingSurah(100, 'العاديات', 'Al-ʿĀdiyāt', 3),
  KidsReadingSurah(101, 'القارعة', 'Al-Qāriʿah', 3),
  KidsReadingSurah(102, 'التكاثر', 'At-Takāthur', 3),
  KidsReadingSurah(103, 'العصر', 'Al-ʿAṣr', 0),
  KidsReadingSurah(104, 'الهمزة', 'Al-Humazah', 3),
  KidsReadingSurah(105, 'الفيل', 'Al-Fīl', 0),
  KidsReadingSurah(106, 'قريش', 'Quraysh', 0),
  KidsReadingSurah(107, 'الماعون', 'Al-Māʿūn', 0),
  KidsReadingSurah(108, 'الكوثر', 'Al-Kawthar', 0),
  KidsReadingSurah(109, 'الكافرون', 'Al-Kāfirūn', 0),
  KidsReadingSurah(110, 'النصر', 'An-Naṣr', 0),
  KidsReadingSurah(111, 'المسد', 'Al-Masad', 0),
  KidsReadingSurah(112, 'الإخلاص', 'Al-Ikhlāṣ', 0),
  KidsReadingSurah(113, 'الفلق', 'Al-Falaq', 0),
  KidsReadingSurah(114, 'الناس', 'An-Nās', 0),
];

/// The progress id a sūrah's reading stage reports under. al-Ikhlāṣ keeps the
/// id it had when it was the path's one closing "capstone" sūrah, so a child
/// who had already read it keeps that.
String kidsReadingProgressId(int surah) =>
    surah == 112 ? 'kids.capstone.read' : 'kids.read.$surah.read';

/// How many of the ladder's sūrahs [p] has read to the end.
int kidsSurahsRead(ProgressStore p) => kidsReadingSurahs
    .where((s) => p.starsFor(kidsReadingProgressId(s.n)) > 0)
    .length;

/// [s]'s name for the current language: in Arabic for an Arabic or Urdu
/// reader, transliterated otherwise.
String kidsSurahTitle(BuildContext context, KidsReadingSurah s) {
  final lang = Localizations.localeOf(context).languageCode;
  return lang == 'ar' || lang == 'ur' ? s.arabic : s.translit;
}

class KidsBadge {
  final String id;
  final String emoji;
  final String Function(BuildContext) title;
  final bool Function(ProgressStore prog) earned;
  const KidsBadge(
      {required this.id,
      required this.emoji,
      required this.title,
      required this.earned});
}

/// Every badge Kids Mode can award, spanning the whole path rather than just
/// letters and streaks. Does not take a [BuildContext] — nothing here reads
/// one; [title] is already its own `String Function(BuildContext)` closure,
/// resolved by whoever renders a badge, so [kidsSyncBadges] can evaluate
/// these against a bare [ProgressStore] with no widget tree in reach.
///
/// Progress ids below are written as the literal strings `kids_path.dart`
/// produces rather than imported from it — `kids_path.dart` already imports
/// this file, so the reverse import would be circular. This mirrors
/// `ProgressStore.kidsLettersLearned`, which hardcodes the `kids.letter.`
/// prefix the same way.
List<KidsBadge> kidsBadgeDefs() => [
      // ── path ──
      KidsBadge(
          id: 'first_letter',
          emoji: '🌱',
          title: (c) => c.l10n.kidsBadgeFirstLetter,
          earned: (p) => p.kidsLettersLearned >= 1),
      KidsBadge(
          id: 'five_letters',
          emoji: '⭐',
          title: (c) => c.l10n.kidsBadgeFiveLetters,
          earned: (p) => p.kidsLettersLearned >= 5),
      KidsBadge(
          id: 'ten_letters',
          emoji: '📗',
          title: (c) => c.l10n.kidsBadgeTenLetters,
          earned: (p) => p.kidsLettersLearned >= 10),
      KidsBadge(
          id: 'halfway',
          emoji: '🚀',
          title: (c) => c.l10n.kidsBadgeHalfway,
          earned: (p) => p.kidsLettersLearned >= (kidsLetterPath.length ~/ 2)),
      KidsBadge(
          id: 'alphabet_master',
          emoji: '👑',
          title: (c) => c.l10n.kidsBadgeAlphabetMaster,
          earned: (p) => p.kidsLettersLearned >= kidsLetterPath.length),
      KidsBadge(
          // For writing every joining shape of every letter — the lessons
          // themselves, counted directly. Earned just before [forms_cleared]
          // below, which is for passing the quiz that follows them. One
          // lesson per shape now (`kids.forms.<ini|med|fin>.<char>`) rather
          // than one per letter, so the threshold is shapes, not letters —
          // see [kidsFormsLessonCount].
          id: 'forms_few_cleared', // stale id, kept: badges persist by id
          emoji: '✍️',
          title: (c) => c.l10n.kidsBadgeFormsFewCleared,
          earned: (p) =>
              p.countStarred('kids.forms.') >= kidsFormsLessonCount),
      KidsBadge(
          // The forms.quiz block only unlocks once every letter's joining-
          // forms lesson is done (blocks unlock in order), so passing its
          // quiz is a reliable stand-in for "cleared the joining-forms stage".
          id: 'forms_cleared',
          emoji: '🔗',
          title: (c) => c.l10n.kidsBadgeFormsCleared,
          earned: (p) => p.starsFor('kids.quiz.forms') > 0),
      KidsBadge(
          // Same reasoning: special.quiz is gated behind the whole special
          // block (lām-alif, kāf wraps, stacks, hamza carriers, alif maqṣūrah).
          id: 'special_shapes',
          emoji: '✨',
          title: (c) => c.l10n.kidsBadgeSpecialShapes,
          earned: (p) => p.starsFor('kids.quiz.special') > 0),
      KidsBadge(
          id: 'harakat_cleared',
          emoji: '🎵',
          title: (c) => c.l10n.kidsBadgeHarakatCleared,
          earned: (p) => p.starsFor('kids.harakat.test') > 0),
      KidsBadge(
          id: 'sukun_cleared',
          emoji: '⏹️',
          title: (c) => c.l10n.kidsBadgeSukunCleared,
          earned: (p) => p.starsFor('kids.sukun.test') > 0),
      KidsBadge(
          id: 'shadda_cleared',
          emoji: '🧩',
          title: (c) => c.l10n.kidsBadgeShaddaCleared,
          earned: (p) => p.starsFor('kids.shadda.test') > 0),
      KidsBadge(
          id: 'madd_cleared',
          emoji: '🎶',
          title: (c) => c.l10n.kidsBadgeMaddCleared,
          earned: (p) => p.starsFor('kids.madd.test') > 0),
      KidsBadge(
          id: 'tanwin_cleared',
          emoji: '🔤',
          title: (c) => c.l10n.kidsBadgeTanwinCleared,
          earned: (p) => p.starsFor('kids.tanwin.test') > 0),
      KidsBadge(
          id: 'muqattaat_read',
          emoji: '🔠',
          title: (c) => c.l10n.kidsBadgeMuqattaatRead,
          earned: (p) => p.starsFor('kids.muqattaat.test') > 0),
      KidsBadge(
          id: 'words_cleared',
          emoji: '🧵',
          title: (c) => c.l10n.kidsBadgeWordsCleared,
          earned: (p) => p.starsFor('kids.words.test') > 0),
      KidsBadge(
          id: 'wasl_cleared',
          emoji: '🌉',
          title: (c) => c.l10n.kidsBadgeWaslCleared,
          earned: (p) => p.starsFor('kids.wasl.test') > 0),
      KidsBadge(
          id: 'solar_lunar',
          emoji: '☀️',
          title: (c) => c.l10n.kidsBadgeSolarLunar,
          earned: (p) => p.starsFor('kids.solar_lunar.test') > 0),
      KidsBadge(
          id: 'tamarbuta_cleared',
          emoji: '🌿',
          title: (c) => c.l10n.kidsBadgeTaMarbutaCleared,
          earned: (p) => p.starsFor('kids.tamarbuta.test') > 0),
      KidsBadge(
          id: 'waqf_cleared',
          emoji: '🛑',
          title: (c) => c.l10n.kidsBadgeWaqfCleared,
          earned: (p) => p.starsFor('kids.waqf.test') > 0),
      KidsBadge(
          id: 'two_words',
          emoji: '📃',
          title: (c) => c.l10n.kidsBadgeTwoWords,
          earned: (p) => p.starsFor('kids.words.two.read') > 0),
      KidsBadge(
          id: 'three_words',
          emoji: '📄',
          title: (c) => c.l10n.kidsBadgeThreeWords,
          earned: (p) => p.starsFor('kids.words.three.read') > 0),
      KidsBadge(
          // The moment the first Tajwīd lesson is opened — Learn items are
          // `completeOnOpen`, so this does not wait for its quiz.
          id: 'reached_tajwid',
          emoji: '📜',
          title: (c) => c.l10n.kidsBadgeReachedTajwid,
          earned: (p) => p.starsFor('kids.tajwid.madd.learn') > 0),
      KidsBadge(
          id: 'tajwid_mim_cleared',
          emoji: '👄',
          title: (c) => c.l10n.kidsBadgeTajwidMimCleared,
          earned: (p) => p.starsFor('kids.tajwid.mim.test') > 0),
      KidsBadge(
          id: 'tajwid_nun_cleared',
          emoji: '🔔',
          title: (c) => c.l10n.kidsBadgeTajwidNunCleared,
          earned: (p) => p.starsFor('kids.tajwid.nun.test') > 0),
      KidsBadge(
          id: 'tajwid_qalqalah_cleared',
          emoji: '⚡',
          title: (c) => c.l10n.kidsBadgeTajwidQalqalahCleared,
          earned: (p) => p.starsFor('kids.tajwid.qalqalah.test') > 0),
      KidsBadge(
          id: 'tajwid_raa_cleared',
          emoji: '🌊',
          title: (c) => c.l10n.kidsBadgeTajwidRaaCleared,
          earned: (p) => p.starsFor('kids.tajwid.raa.test') > 0),
      KidsBadge(
          // The comprehensive review, one stage before the capstone sūrah —
          // distinct from [read_a_surah] below, which is the capstone itself.
          id: 'path_finished',
          emoji: '🎓',
          title: (c) => c.l10n.kidsBadgePathFinished,
          earned: (p) => p.starsFor('kids.review.test') > 0),
      KidsBadge(
          // Any sūrah on the closing reading ladder — the first one counts,
          // whichever it is (this used to be the single capstone sūrah).
          id: 'read_a_surah',
          emoji: '📖',
          title: (c) => c.l10n.kidsBadgeReadASurah,
          earned: (p) => kidsSurahsRead(p) >= 1),
      KidsBadge(
          id: 'read_five_surahs',
          emoji: '📚',
          title: (c) => c.l10n.kidsBadgeReadFiveSurahs,
          earned: (p) => kidsSurahsRead(p) >= 5),
      KidsBadge(
          id: 'read_ten_surahs',
          emoji: '🏅',
          title: (c) => c.l10n.kidsBadgeReadTenSurahs,
          earned: (p) => kidsSurahsRead(p) >= 10),
      KidsBadge(
          id: 'read_all_surahs',
          emoji: '🌟',
          title: (c) => c.l10n.kidsBadgeReadAllSurahs,
          earned: (p) => kidsSurahsRead(p) >= kidsReadingSurahs.length),
      // ── habit ──
      KidsBadge(
          id: 'streak_3',
          emoji: '🔥',
          title: (c) => c.l10n.kidsBadgeStreak3,
          earned: (p) => p.streakDays >= 3),
      KidsBadge(
          id: 'streak_7',
          emoji: '🏆',
          title: (c) => c.l10n.kidsBadgeStreak7,
          earned: (p) => p.streakDays >= 7),
      KidsBadge(
          id: 'streak_14',
          emoji: '💫',
          title: (c) => c.l10n.kidsBadgeStreak14,
          earned: (p) => p.streakDays >= 14),
      KidsBadge(
          id: 'streak_30',
          emoji: '🌙',
          title: (c) => c.l10n.kidsBadgeStreak30,
          earned: (p) => p.streakDays >= 30),
      KidsBadge(
          id: 'full_week',
          emoji: '🗓️',
          title: (c) => c.l10n.kidsBadgeFullWeek,
          earned: (p) => p.weekDoneCount >= p.weekGoal),
      KidsBadge(
          id: 'five_in_a_day',
          emoji: '⚡',
          title: (c) => c.l10n.kidsBadgeFiveInADay,
          earned: (p) => p.todayActivityCount >= 5),
      // ── mastery ──
      KidsBadge(
          id: 'first_quiz',
          emoji: '🎯',
          title: (c) => c.l10n.kidsBadgeFirstQuiz,
          earned: (p) => p.kidsAnyQuizPassed),
      KidsBadge(
          id: 'perfect_quiz',
          emoji: '💯',
          title: (c) => c.l10n.kidsBadgePerfectQuiz,
          earned: (p) => p.kidsAnyQuizPerfect),
      KidsBadge(
          id: 'ten_perfect',
          emoji: '🎖️',
          title: (c) => c.l10n.kidsBadgeTenPerfect,
          earned: (p) => p.perfectCount >= 10),
      KidsBadge(
          id: 'fifty_stars',
          emoji: '💠',
          title: (c) => c.l10n.kidsBadgeFiftyStars,
          earned: (p) => p.totalStars >= 50),
      KidsBadge(
          id: 'hundred_stars',
          emoji: '🌟',
          title: (c) => c.l10n.kidsBadgeHundredStars,
          earned: (p) => p.totalStars >= 100),
      KidsBadge(
          id: 'level_5',
          emoji: '🥉',
          title: (c) => c.l10n.kidsBadgeLevel5,
          earned: (p) => p.level >= 5),
      KidsBadge(
          id: 'level_10',
          emoji: '🏅',
          title: (c) => c.l10n.kidsBadgeLevel10,
          earned: (p) => p.level >= 10),
    ];

/// Evaluates every [kidsBadgeDefs] predicate against [prog] and unlocks any
/// newly-earned one, with gems.
///
/// This is the fix for the evaluation gap that shipped alongside the badges
/// above: `unlockBadge` used to be called from exactly two places — the
/// letter-lesson result screen and the reading screen — so a badge that
/// depended on a quiz or a reused Qāʿidah/Tajwīd unit (i.e. everything past
/// the Special Shapes stage) could never actually fire. Call this from
/// wherever the active child's `ProgressStore` is owned (`KidsProfileGate`),
/// on every change, so it runs regardless of which kind of activity earned
/// the progress.
void kidsSyncBadges(ProgressStore prog) {
  for (final b in kidsBadgeDefs()) {
    if (b.earned(prog) && !prog.badges.contains(b.id)) {
      prog.unlockBadge(b.id);
      prog.awardGems(kidsGemsPerBadge);
    }
  }
}

/// Which shelf a [KidsShopItem] sits on in Rewards' Shop.
enum KidsShopShelf {
  /// Avatar cosmetics: frames and unlockable animal avatars.
  looks,

  /// Object avatars — a lantern, dates, a tasbīḥ… (and the Ice Cube reward).
  things,

  /// Whole palettes for Kids Mode.
  colours,
}

class KidsShopItem {
  final String id;
  final String emoji;
  final int cost;
  final KidsShopShelf shelf;
  final String Function(BuildContext) title;

  /// No longer sold: listed only for a child who already owns it, so nothing
  /// bought is ever lost.
  final bool retired;

  /// Never sold — earned (the Ice Cube, for a streak freeze saving the
  /// streak). Listed only once owned, and never with a price or a Buy button.
  final bool rewardOnly;
  const KidsShopItem(
      {required this.id,
      required this.emoji,
      required this.cost,
      required this.shelf,
      required this.title,
      this.retired = false,
      this.rewardOnly = false});
}

/// The one-time cosmetic purchases. Every one renders somewhere the child
/// already looks — see [kidsFrameKind] and [kidsAvatarUnlock] below, and
/// `KidsAvatar` in `screens/kids/kids_widgets.dart` — which is the whole
/// point: the shop used to sell three items that appeared nowhere in the app
/// once bought.
///
/// **There is deliberately no hat, or any other drawn-on accessory.** One
/// shipped briefly ("Falcon Hat", `falcon_hat`) and it could not be made to
/// look like anything: the avatars here are emoji — full-colour illustrations
/// with no consistent head, and no anchor point an accessory could attach to
/// — and a flat hand-drawn cap beside one reads as a rendering artefact, not
/// a hat. It is worse at the sizes that matter: `KidsAvatar` renders as small
/// as 17px in the desktop nav, where any drawn shape is a smudge. The two
/// things that DO survive an emoji avatar at every size are a ring around it
/// and the emoji itself, so those are what this shelf sells. Do not re-use
/// the `falcon_hat` id.
///
/// Prices came down from the original 150–400 (the entire alphabet, traced
/// perfectly, for one frame) to land inside the letters stage.
List<KidsShopItem> kidsShopItems(BuildContext context) => [
      // ── looks: avatar unlocks ──
      // Animals the Qurʼān itself names, so an unlock is a small piece of
      // content rather than decoration borrowed from somewhere else. A
      // superhero cape, a falcon and a dragon shipped here briefly and were
      // wrong for this app: fantasy and heraldic imagery has no place in a
      // muṣḥaf-learning tool. Do not re-use `star_cape`, `falcon_avatar` or
      // `dragon_avatar`.
      KidsShopItem(
          id: 'camel_avatar', // al-Ghāshiyah 88:17
          emoji: '🐪',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopCamelAvatar),
      KidsShopItem(
          id: 'bee_avatar', // an-Naḥl, sūrah 16
          emoji: '🐝',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopBeeAvatar),
      KidsShopItem(
          id: 'elephant_avatar', // al-Fīl, sūrah 105
          emoji: '🐘',
          cost: 80,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopElephantAvatar),
      KidsShopItem(
          id: 'ant_avatar', // an-Naml, sūrah 27
          emoji: '🐜',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopAntAvatar),
      KidsShopItem(
          id: 'spider_avatar', // al-ʿAnkabūt, sūrah 29
          emoji: '🕷️',
          cost: 70,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopSpiderAvatar),
      // Retired: the horse is a free choice in the New Profile picker, so selling
      // it as well offered the same animal twice. Those who bought it keep it,
      // and it now shows the drawn horse (see `kidsAnimals`).
      KidsShopItem(
          id: 'horse_avatar', // al-ʿĀdiyāt, sūrah 100
          emoji: '🐎',
          cost: 90,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopHorseAvatar,
          retired: true),
      KidsShopItem(
          id: 'cow_avatar', // al-Baqarah, sūrah 2
          emoji: '🐄',
          cost: 90,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopCowAvatar),
      KidsShopItem(
          id: 'whale_avatar', // aṣ-Ṣāffāt 37:142, Yūnus and "Ṣāḥib al-Ḥūt"
          emoji: '🐋',
          cost: 110,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopWhaleAvatar),
      // The two the design's avatar set adds that the Qurʼān also names. The
      // design draws more that it does not (cat, bunny, penguin, owl, hippo,
      // crocodile, rhino, shark), so they are NOT sold — see `kidsAnimals` —
      // and these two are priced as the design prices them, the eight above
      // keeping what they always cost.
      KidsShopItem(
          id: 'monkey_avatar', // al-Baqarah 2:65, al-Aʿrāf 7:166
          emoji: '🐵',
          cost: 100,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopMonkeyAvatar),
      KidsShopItem(
          id: 'sheep_avatar', // Ṣād 38:23–24, al-Anʿām 6:143
          emoji: '🐑',
          cost: 120,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopSheepAvatar),
      KidsShopItem(
          id: 'goat_avatar', // al-Anʿām 6:143
          emoji: '🐐',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopGoatAvatar),
      KidsShopItem(
          id: 'wolf_avatar', // Yūsuf 12:13–17
          emoji: '🐺',
          cost: 100,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopWolfAvatar),
      // ── things: object avatars ──
      // The design's objects, at its prices — all but the Qurʼān stand, the
      // mosque and the prayer mat, which ship as art but are not sold (a child
      // "wearing" a sacred thing as an avatar is not for every family).
      KidsShopItem(
          id: 'shield_avatar',
          emoji: 'avatar:shield',
          cost: 60,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopShield),
      KidsShopItem(
          id: 'sword_avatar',
          emoji: 'avatar:sword',
          cost: 80,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopSword),
      KidsShopItem(
          id: 'helmet_avatar',
          emoji: 'avatar:helmet',
          cost: 100,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopHelmet),
      KidsShopItem(
          id: 'tasbeeh_avatar',
          emoji: 'avatar:tasbeeh',
          cost: 40,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopTasbeeh),
      KidsShopItem(
          id: 'topi_avatar',
          emoji: 'avatar:topi',
          cost: 40,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopTopi),
      KidsShopItem(
          id: 'dates_avatar',
          emoji: 'avatar:dates',
          cost: 30,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopDates),
      KidsShopItem(
          id: 'dallah_avatar',
          emoji: 'avatar:dallah',
          cost: 60,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopQahwa),
      KidsShopItem(
          id: 'tea_avatar',
          emoji: 'avatar:tea',
          cost: 30,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopChai),
      KidsShopItem(
          id: 'flask_avatar',
          emoji: 'avatar:flask',
          cost: 50,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopFlask),
      KidsShopItem(
          id: 'lantern_avatar',
          emoji: 'avatar:lantern',
          cost: 80,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopLantern),
      KidsShopItem(
          id: 'crescent_avatar',
          emoji: 'avatar:crescent',
          cost: 100,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopCrescent),
      KidsShopItem(
          id: 'palm_avatar',
          emoji: 'avatar:palm',
          cost: 40,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopPalmTree),
      KidsShopItem(
          id: 'miswak_avatar',
          emoji: 'avatar:miswak',
          cost: 30,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopMiswak),
      KidsShopItem(
          id: 'zamzam_avatar',
          emoji: 'avatar:zamzam',
          cost: 50,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopZamzam),
      KidsShopItem(
          id: 'attar_avatar',
          emoji: 'avatar:attar',
          cost: 60,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopAttar),
      // The Ice Cube: never for sale — the reward for a streak freeze saving
      // the streak (ProgressStore.iceCubeItem).
      KidsShopItem(
          id: 'icecube_avatar',
          emoji: 'avatar:icecube',
          cost: 0,
          shelf: KidsShopShelf.things,
          title: (c) => c.l10n.kidsShopIceCube,
          rewardOnly: true),
      // ── looks: frames ──
      // Four frames that differ by TECHNIQUE, not just by colour: a plain ring,
      // a ring of beads, a soft halo, a sweeping two-tone ring. They were once
      // three flat rings in silver, gold and emerald, and the gold was the very
      // colour of every badge border and goal ring already on screen, and the
      // emerald was the default theme's own teal — so a bought frame looked
      // like something the app already had. The three below also take their
      // colours from the child's equipped THEME (see `KidsAvatar`), so a frame
      // never clashes with the screen it sits on. `golden_frame` and
      // `emerald_frame` were retired into `starlight_frame` and `aurora_frame`
      // of the same price tier (`kLegacyFrameIds`); do not re-use those ids.
      KidsShopItem(
          id: 'silver_frame',
          emoji: '⚪',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopSilverFrame),
      KidsShopItem(
          id: 'starlight_frame',
          emoji: '✨',
          cost: 100,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopStarlightFrame),
      KidsShopItem(
          id: 'glow_frame',
          emoji: '🌟',
          cost: 120,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopGlowFrame),
      KidsShopItem(
          id: 'aurora_frame',
          emoji: '🌌',
          cost: 160,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopAuroraFrame),
      // ── colours — repaints the whole of Kids Mode; see `kidsPal` ──
      KidsShopItem(
          id: 'kids_ocean',
          emoji: '🌊',
          cost: 200,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeOcean),
      KidsShopItem(
          id: 'kids_desert',
          emoji: '🏜️',
          cost: 200,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeDesert),
      KidsShopItem(
          id: 'kids_night',
          emoji: '🌙',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeNight),
      KidsShopItem(
          id: 'kids_forest',
          emoji: '🌳',
          cost: 200,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeForest),
      KidsShopItem(
          id: 'kids_lagoon',
          emoji: '🐠',
          cost: 200,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeLagoon),
      KidsShopItem(
          id: 'kids_blossom',
          emoji: '🌸',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeBlossom),
      KidsShopItem(
          id: 'kids_sunset',
          emoji: '🌅',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeSunset),
      KidsShopItem(
          id: 'kids_rain',
          emoji: '🌧️',
          cost: 200,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeRain),
      KidsShopItem(
          id: 'kids_cave',
          emoji: '🦇',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeCave),
      KidsShopItem(
          id: 'kids_sunrise',
          emoji: '🌄',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeSunrise),
      KidsShopItem(
          id: 'kids_frozen',
          emoji: '🧊',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeFrozen),
      KidsShopItem(
          id: 'kids_snowy',
          emoji: '⛄',
          cost: 250,
          shelf: KidsShopShelf.colours,
          title: (c) => c.l10n.kidsShopThemeSnowy),
    ];

/// How a frame is drawn around the avatar.
enum KidsFrameKind {
  /// A plain ring.
  ring,

  /// A ring of small beads.
  beads,

  /// A thin ring with a soft halo outside it.
  glow,

  /// A ring that sweeps between the theme's colours.
  sweep,
}

/// How the frame [frameId] is drawn — see `KidsAvatar`. Null for no frame
/// equipped or an unrecognised id. A retired id resolves to its successor
/// ([kLegacyFrameIds]).
///
/// A frame is one of only two cosmetics that work on an emoji avatar (the
/// other being [kidsAvatarUnlock]): it surrounds the emoji rather than trying
/// to sit on it, so it stays legible from 64px down to the 17px the desktop
/// nav renders at. Each kind is a different SHAPE, so they stay distinct at
/// 17px too, where two rings of two colours are the same smudge.
KidsFrameKind? kidsFrameKind(String frameId) =>
    switch (kLegacyFrameIds[frameId] ?? frameId) {
      'silver_frame' => KidsFrameKind.ring,
      'starlight_frame' => KidsFrameKind.beads,
      'glow_frame' => KidsFrameKind.glow,
      'aurora_frame' => KidsFrameKind.sweep,
      _ => null,
    };

/// The avatar emoji an unlock item swaps to, chosen to be that item's own
/// shop icon — buying one is "unlock this avatar", not a second, unrelated
/// cosmetic slot. Null for any id that is not an avatar unlock.
String? kidsAvatarUnlock(String itemId) => switch (itemId) {
      'camel_avatar' => '🐪',
      'bee_avatar' => '🐝',
      'elephant_avatar' => '🐘',
      'ant_avatar' => '🐜',
      'spider_avatar' => '🕷️',
      'horse_avatar' => '🐎',
      'cow_avatar' => '🐄',
      'whale_avatar' => '🐋',
      'monkey_avatar' => '🐵',
      'sheep_avatar' => '🐑',
      'goat_avatar' => '🐐',
      'wolf_avatar' => '🐺',
      'icecube_avatar' => 'avatar:icecube',
      final id when id.endsWith('_avatar') && _objectAvatars.contains(id.substring(0, id.length - 7)) =>
        'avatar:${id.substring(0, id.length - 7)}',
      _ => null,
    };

/// The object avatars the shop sells, by art id.
const _objectAvatars = {
  'shield', 'sword', 'helmet', 'tasbeeh', 'topi', 'dates', 'dallah', 'tea', //
  'flask', 'lantern', 'crescent', 'palm', 'miswak', 'zamzam', 'attar',
};

/// Which of [profile]'s equip slots [item] would occupy, and whether it is
/// currently worn there. Colours set `theme`; of the Looks items, a frame
/// sets `frame` and an avatar unlock sets `avatar` itself (matched by value —
/// there is no separate "avatar id" field, the child's whole `avatar` string
/// just becomes the unlocked emoji).
bool kidsItemEquipped(KidsShopItem item, KidsProfile profile) {
  if (item.shelf == KidsShopShelf.colours) return profile.theme == item.id;
  if (kidsFrameKind(item.id) != null) return profile.frame == item.id;
  final avatar = kidsAvatarUnlock(item.id);
  return avatar != null && profile.avatar == avatar;
}

/// The palette family every child starts on, and goes back to when a bought
/// theme is taken off.
const kKidsDefaultTheme = 'kids';

/// The avatar a profile falls back to when it has no [KidsProfile.baseAvatar]
/// on record (a profile saved before that field existed).
const kKidsDefaultAvatar = '🦊';

/// Equips [item] on [profile]. The caller is responsible for wrapping this
/// in `AppSettings.update` so the change is persisted and observed.
void kidsEquipItem(KidsShopItem item, KidsProfile profile) {
  if (item.shelf == KidsShopShelf.colours) {
    profile.theme = item.id;
  } else if (kidsFrameKind(item.id) != null) {
    profile.frame = item.id;
  } else {
    final avatar = kidsAvatarUnlock(item.id);
    if (avatar == null) return;
    // Remember the avatar the child chose themselves — but only if what they
    // are wearing now is theirs, not another unlock (swapping the whale for the
    // bee must not make the whale their "own" avatar).
    final wearingUnlock = kidsAvatarUnlockEmojis.contains(profile.avatar);
    if (!wearingUnlock) profile.baseAvatar = profile.avatar;
    profile.avatar = avatar;
  }
}

/// Every emoji an avatar unlock can swap to.
final kidsAvatarUnlockEmojis = {
  '🐪', '🐝', '🐘', '🐜', '🕷️', '🐎', '🐄', '🐋', //
  '🐵', '🐑', '🐐', '🐺', //
  'avatar:icecube',
  for (final o in _objectAvatars) 'avatar:$o',
};

/// Takes [item] off [profile], back to what was there before: no frame, the
/// default theme, the child's own avatar. A no-op if [item] is not what they
/// are wearing.
///
/// **Every cosmetic can be taken back off.** A frame's "none" is the empty
/// string it already defaults to; a theme's is the default palette
/// ([kKidsDefaultTheme]); an avatar unlock's is the emoji the child chose when
/// they made their profile ([KidsProfile.baseAvatar]). This used to be true only
/// of frames, on the reasoning that there was "no shop item representing the
/// original theme". So an equipped theme showed a dead "Worn" label with no
/// button, and a child who bought Ocean could never go back to the default (or
/// off the whale, back to their own avatar) — the only way out was a new
/// profile, which lost every star, gem and badge.
void kidsUnequipItem(KidsShopItem item, KidsProfile profile) {
  if (item.shelf == KidsShopShelf.colours) {
    if (profile.theme == item.id) profile.theme = kKidsDefaultTheme;
  } else if (kidsFrameKind(item.id) != null) {
    if (profile.frame == item.id) profile.frame = '';
  } else {
    final avatar = kidsAvatarUnlock(item.id);
    if (avatar != null && profile.avatar == avatar) {
      profile.avatar =
          profile.baseAvatar.isEmpty ? kKidsDefaultAvatar : profile.baseAvatar;
    }
  }
}

/// Takes off whatever [profile] is wearing that is not really theirs — the
/// themes, frames and avatar unlocks the testing unlock let them try on for
/// free — back to what [kidsUnequipItem] would give. Run when that unlock is
/// turned off, so no profile is left wearing something it never bought.
/// [owned] is `ProgressStore.shopOwned`; [items] the shop.
void kidsTakeOffUnowned(
    KidsProfile profile, Set<String> owned, List<KidsShopItem> items) {
  bool has(String id) =>
      owned.contains(id) ||
      owned.contains(kLegacyFrameIds[id]) ||
      owned.any((o) => kLegacyFrameIds[o] == id);
  for (final item in items) {
    if (!has(item.id) && kidsItemEquipped(item, profile)) {
      kidsUnequipItem(item, profile);
    }
  }
  // A retired frame id is worn under its old name, which no shop item has.
  if (profile.frame.isNotEmpty && !has(profile.frame)) profile.frame = '';
  // A drawn animal that is never offered (only the testing unlock's picker
  // shows it) — and the same check for the avatar a child falls back to, which
  // a profile created under the unlock may hold. An emoji this does not
  // recognise is left alone: it may be an avatar an older version offered.
  bool wearable(String a) =>
      !_heldEmojis.contains(a) &&
      !(kidsAvatarUnlockEmojis.contains(a) &&
          !items.any((i) => kidsAvatarUnlock(i.id) == a && has(i.id)));
  if (!wearable(profile.baseAvatar)) profile.baseAvatar = kKidsDefaultAvatar;
  if (!wearable(profile.avatar)) {
    profile.avatar =
        profile.baseAvatar.isEmpty ? kKidsDefaultAvatar : profile.baseAvatar;
  }
}

final _heldEmojis = {
  for (final a in kidsAnimals)
    if (a.held) a.emoji,
};

/// One purchase that is spent rather than owned — a count on `ProgressStore`
/// (`streakFreezes`), not a `shopOwned` membership, since buying another is
/// always allowed rather than a one-time unlock. Kept separate from
/// [KidsShopItem] because it genuinely has a different shape: no "owned"
/// state, and the Rewards screen shows how many are in hand instead of a
/// checkmark.
class KidsConsumable {
  final String id;
  final String emoji;
  final int cost;
  final String Function(BuildContext) title;
  final String Function(BuildContext) subtitle;
  const KidsConsumable(
      {required this.id,
      required this.emoji,
      required this.cost,
      required this.title,
      required this.subtitle});
}

List<KidsConsumable> kidsConsumables(BuildContext context) => [
      KidsConsumable(
          id: 'streak_freeze',
          emoji: '🧊',
          cost: 40,
          title: (c) => c.l10n.kidsShopStreakFreeze,
          subtitle: (c) => c.l10n.kidsShopStreakFreezeDesc),
    ];
