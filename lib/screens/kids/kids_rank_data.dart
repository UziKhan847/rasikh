import 'package:flutter/widgets.dart';

import '../../core/settings.dart';

/// One row of the household leaderboard: a profile plus its XP/level.
/// Shared between [KidsRankScreen] and the desktop Home screen's leaderboard
/// preview rail, so both read the exact same ranking rather than keeping two
/// copies of the same load-and-sort logic in sync.
class KidsRankRow {
  final KidsProfile profile;
  final int xp;
  final int level;
  const KidsRankRow(this.profile, this.xp, this.level);
}

/// Ranks every profile on this device by XP, highest first. There is no
/// account system and nothing leaves the device (see the Kids Mode plan's
/// "local + family only" decision): this reads each sibling's own on-device
/// [ProgressStore], never a server.
Future<List<KidsRankRow>> loadKidsRanking(BuildContext context) async {
  final s = SettingsScope.of(context);
  final rows = <KidsRankRow>[];
  for (final profile in s.kidsProfiles) {
    // A sibling's `store.load()` below is a real await: Kids Mode can be
    // left (unmounting this whole subtree) while it's in flight. Bail
    // before touching `context` again — otherwise the next iteration's
    // `ProgressScope.of(context)` looks up a deactivated widget's ancestor.
    if (!context.mounted) break;
    // The active profile's own store is already live in ProgressScope —
    // reuse it instead of opening a second instance over the same prefs.
    if (profile.id == s.activeKidsProfileId) {
      final prog = ProgressScope.of(context);
      rows.add(KidsRankRow(profile, prog.xp, prog.level));
    } else {
      final store = ProgressStore(profileId: profile.id);
      await store.load();
      rows.add(KidsRankRow(profile, store.xp, store.level));
    }
  }
  rows.sort((a, b) => b.xp.compareTo(a.xp));
  return rows;
}
