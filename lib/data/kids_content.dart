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
const kidsDailyGoal = 5; // lessons/day shown on the Home goal ring

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

List<KidsBadge> kidsBadgeDefs(BuildContext context) => [
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
          id: 'streak_3',
          emoji: '🔥',
          title: (c) => c.l10n.kidsBadgeStreak3,
          earned: (p) => p.streakDays >= 3),
      KidsBadge(
          id: 'streak_7',
          emoji: '🏆',
          title: (c) => c.l10n.kidsBadgeStreak7,
          earned: (p) => p.streakDays >= 7),
    ];

class KidsShopItem {
  final String id;
  final String emoji;
  final int cost;
  final String Function(BuildContext) title;
  const KidsShopItem(
      {required this.id,
      required this.emoji,
      required this.cost,
      required this.title});
}

List<KidsShopItem> kidsShopItems(BuildContext context) => [
      KidsShopItem(
          id: 'falcon_hat',
          emoji: '🦅',
          cost: 150,
          title: (c) => c.l10n.kidsShopFalconHat),
      KidsShopItem(
          id: 'star_cape',
          emoji: '🦸',
          cost: 250,
          title: (c) => c.l10n.kidsShopStarCape),
      KidsShopItem(
          id: 'golden_frame',
          emoji: '🖼️',
          cost: 400,
          title: (c) => c.l10n.kidsShopGoldenFrame),
    ];
