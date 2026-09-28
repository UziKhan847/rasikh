import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import '../../kids_backdrops/kb_screens.dart' show KbPage;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_rank_data.dart';
import 'kids_widgets.dart';

/// The household leaderboard — every family profile on this device, ranked
/// by XP. There is no account system and nothing leaves the device (see the
/// Kids Mode plan's "local + family only" decision): [loadKidsRanking] reads
/// each sibling's own on-device [ProgressStore], never a server.
class KidsRankScreen extends StatefulWidget {
  const KidsRankScreen({super.key});
  @override
  State<KidsRankScreen> createState() => _KidsRankScreenState();
}

class _KidsRankScreenState extends State<KidsRankScreen> {
  List<KidsRankRow>? _rows;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // InheritedWidget lookups (SettingsScope/ProgressScope, inside
    // loadKidsRanking) aren't valid in initState — this is the first point
    // where they are, and it only needs to run once per mount.
    if (!_loadStarted) {
      _loadStarted = true;
      _load();
    }
  }

  Future<void> _load() async {
    final rows = await loadKidsRanking(context);
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    return _mobileBuild(context);
  }

  Widget _mobileBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final ui = kbUi(context);
    final rows = _rows;
    // The design's Rank screen (kb_screens.dart `KbRankScreen`).
    return KbPage(cross: CrossAxisAlignment.stretch, children: [
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsTabRank, ui: ui, fontSize: 30)),
      const SizedBox(height: 12),
      KbSubtitle(context.l10n.kidsRankSub, ui: ui, fontSize: 18),
      const SizedBox(height: 26),
      if (rows == null)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator(color: kbC(ui.accent))),
        )
      else if (rows.length <= 1)
        // On a card: this is a sentence, not a heading, and only headings
        // may sit straight on the scene.
        const _NeedsSiblingsCard()
      else
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RankRow(
              row: rows[i],
              rank: i + 1,
              isYou: rows[i].profile.id == s.activeKidsProfileId),
        ],
    ]);
  }

  Widget _desktopBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final ui = kbUi(context);
    final rows = _rows;
    if (rows == null) {
      return Center(child: CircularProgressIndicator(color: kbC(ui.accent)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 24, 44, 48),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: KbHeading(context.l10n.kidsTabRank, ui: ui, fontSize: 30)),
            if (context.l10n.kidsRankArabic.isNotEmpty)
              KbArabicTitle(context.l10n.kidsRankArabic, ui: ui),
          ],
        ),
        const SizedBox(height: 12),
        KbSubtitle(context.l10n.kidsRankSub, ui: ui, fontSize: 18),
        const SizedBox(height: 26),
        if (rows.length <= 1)
          const _NeedsSiblingsCard()
        else
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final youIndex =
                rows.indexWhere((r) => r.profile.id == s.activeKidsProfileId);
            final list = Column(children: [
              _RankBanner(count: rows.length),
              const SizedBox(height: 16),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RankRow(
                      row: rows[i], rank: i + 1, isYou: i == youIndex),
                ),
            ]);
            if (narrow || youIndex < 0) return list;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                const SizedBox(width: 28),
                SizedBox(
                    width: 280, child: _YouCard(rows: rows, youIndex: youIndex)),
              ],
            );
          }),
      ],
    );
  }
}

/// "Add a brother or sister to race" — a sentence, so it goes on a card.
class _NeedsSiblingsCard extends StatelessWidget {
  const _NeedsSiblingsCard();

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Text(context.l10n.kidsRankNeedsSiblings,
          textAlign: TextAlign.center,
          style: kbText(18, kbC(ui.inkSoft),
              weight: FontWeight.w600, height: 1.35)),
    );
  }
}

/// The desktop leaderboard's title card — the deep card, as Home's Practice.
class _RankBanner extends StatelessWidget {
  final int count;
  const _RankBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.cardDeep,
      edge: ui.cardDeepEdge,
      elev: KbElev.cardDeep,
      highlight: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(children: [
        const Text('🏆', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(context.l10n.kidsRankBannerTitle,
              style: kbText(21, kbC(kWhite), height: 1.15)),
        ),
      ]),
    );
  }
}

class _YouCard extends StatelessWidget {
  final List<KidsRankRow> rows;
  final int youIndex;
  const _YouCard({required this.rows, required this.youIndex});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final you = rows[youIndex];
    final isFirst = youIndex == 0;
    final gap = isFirst ? 0 : rows[youIndex - 1].xp - you.xp;
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        KbAvatar(
          size: 72,
          background: kbC(ui.tile),
          face: (d) => KidsAvatar(profile: you.profile, size: d / 1.15),
        ),
        const SizedBox(height: 10),
        Text(context.l10n.kidsRankYouAre(youIndex + 1),
            style: kbText(21, kbC(ui.ink), height: 1.1)),
        const SizedBox(height: 4),
        Text(
            isFirst
                ? context.l10n.kidsRankYouAreFirst
                : context.l10n.kidsRankToNext(gap, youIndex),
            textAlign: TextAlign.center,
            style: kbText(16, kbC(ui.inkSoft),
                weight: FontWeight.w600, height: 1.35)),
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  final KidsRankRow row;
  final int rank;
  final bool isYou;
  const _RankRow({required this.row, required this.rank, required this.isYou});

  @override
  Widget build(BuildContext context) => KbRankRow(
        ui: kbUi(context),
        rank: rank,
        face: (d) => KidsAvatar(profile: row.profile, size: d / 1.15),
        name: isYou ? context.l10n.kidsYou : row.profile.name,
        level: context.l10n.kidsLevelLabel(row.level),
        xp: '${row.xp} XP',
        me: isYou,
      );
}
