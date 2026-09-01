import 'package:flutter/widgets.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import 'letters.dart';

/// The curated letter path Kids Mode teaches, in order. This is the same
/// traditional ordering `data/letters.dart` already uses everywhere else in
/// the app (and what the grown-up Qaidah path teaches) — reusing it means a
/// family with both a parent on the adult app and a child on Kids Mode sees
/// the same letter order, not two competing curricula.
List<ArabicLetter> get kidsLetterPath => letters;

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
          // below, which is for passing the quiz that follows them.
          id: 'forms_few_cleared', // stale id, kept: badges persist by id
          emoji: '✍️',
          title: (c) => c.l10n.kidsBadgeFormsFewCleared,
          earned: (p) =>
              p.countStarred('kids.forms.more.') >= kidsLetterPath.length),
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
          // The comprehensive review, one stage before the capstone sūrah —
          // distinct from [read_a_surah] below, which is the capstone itself.
          id: 'path_finished',
          emoji: '🎓',
          title: (c) => c.l10n.kidsBadgePathFinished,
          earned: (p) => p.starsFor('kids.review.test') > 0),
      KidsBadge(
          id: 'read_a_surah',
          emoji: '📖',
          title: (c) => c.l10n.kidsBadgeReadASurah,
          earned: (p) => p.starsFor('kids.capstone.read') > 0),
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
enum KidsShopShelf { looks, colours }

class KidsShopItem {
  final String id;
  final String emoji;
  final int cost;
  final KidsShopShelf shelf;
  final String Function(BuildContext) title;
  const KidsShopItem(
      {required this.id,
      required this.emoji,
      required this.cost,
      required this.shelf,
      required this.title});
}

/// The one-time cosmetic purchases. Every one renders somewhere the child
/// already looks — see [kidsFrameColor] and [kidsAvatarUnlock] below, and
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
      // ── looks: frames ──
      KidsShopItem(
          id: 'silver_frame',
          emoji: '⚪',
          cost: 60,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopSilverFrame),
      KidsShopItem(
          id: 'golden_frame',
          emoji: '🖼️',
          cost: 100,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopGoldenFrame),
      KidsShopItem(
          id: 'emerald_frame',
          emoji: '💚',
          cost: 140,
          shelf: KidsShopShelf.looks,
          title: (c) => c.l10n.kidsShopEmeraldFrame),
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
    ];

/// The ring colour a frame item draws around the avatar — see `KidsAvatar`.
/// Null for no frame equipped or an unrecognised id.
///
/// A ring is one of only two cosmetics that work on an emoji avatar (the
/// other being [kidsAvatarUnlock]): it surrounds the emoji rather than trying
/// to sit on it, so it stays legible from 64px down to the 17px the desktop
/// nav renders at.
Color? kidsFrameColor(String frameId) => switch (frameId) {
      'silver_frame' => const Color(0xFFB9C2CC),
      'golden_frame' => const Color(0xFFF4B23E),
      'emerald_frame' => const Color(0xFF2FB39A),
      _ => null,
    };

/// The avatar emoji an unlock item swaps to, chosen to be that item's own
/// shop icon — buying one is "unlock this avatar", not a second, unrelated
/// cosmetic slot. Null for any id that is not an avatar unlock.
String? kidsAvatarUnlock(String itemId) => switch (itemId) {
      'camel_avatar' => '🐪',
      'bee_avatar' => '🐝',
      'elephant_avatar' => '🐘',
      _ => null,
    };

/// Which of [profile]'s equip slots [item] would occupy, and whether it is
/// currently worn there. Colours set `theme`; of the Looks items, a frame
/// sets `frame` and an avatar unlock sets `avatar` itself (matched by value —
/// there is no separate "avatar id" field, the child's whole `avatar` string
/// just becomes the unlocked emoji).
bool kidsItemEquipped(KidsShopItem item, KidsProfile profile) {
  if (item.shelf == KidsShopShelf.colours) return profile.theme == item.id;
  if (kidsFrameColor(item.id) != null) return profile.frame == item.id;
  final avatar = kidsAvatarUnlock(item.id);
  return avatar != null && profile.avatar == avatar;
}

/// True when taking [item] back off is itself a real, offered choice. A frame
/// has a meaningful "none" — the empty string it already defaults to. A
/// palette or an avatar swap does not: there is no shop item representing
/// "the original theme" or "the original avatar" to revert to, so those are
/// one-way once something else is equipped over them, the same way choosing
/// an avatar at profile creation already is.
bool kidsItemUnequippable(KidsShopItem item) =>
    kidsFrameColor(item.id) != null;

/// Equips [item] on [profile]. The caller is responsible for wrapping this
/// in `AppSettings.update` so the change is persisted and observed.
void kidsEquipItem(KidsShopItem item, KidsProfile profile) {
  if (item.shelf == KidsShopShelf.colours) {
    profile.theme = item.id;
  } else if (kidsFrameColor(item.id) != null) {
    profile.frame = item.id;
  } else {
    final avatar = kidsAvatarUnlock(item.id);
    if (avatar != null) profile.avatar = avatar;
  }
}

/// Un-equips [item] from [profile]. Only meaningful where
/// [kidsItemUnequippable] is true; a no-op otherwise.
void kidsUnequipItem(KidsShopItem item, KidsProfile profile) {
  if (kidsFrameColor(item.id) != null && profile.frame == item.id) {
    profile.frame = '';
  }
}

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
