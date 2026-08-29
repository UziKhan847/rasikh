import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
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
    final p = kidsPal(context);
    final rows = _rows;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.kidsTabRank,
                    style:
                        kidsStyle(context, size: 20, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(context.l10n.kidsRankSub,
                    style: kidsStyle(context, size: 13, color: p.textDim)),
              ],
            ),
          ),
          Expanded(
            child: rows == null
                ? Center(
                    child: CircularProgressIndicator(color: p.accent))
                : rows.length <= 1
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Geo.gapLg),
                          child: Text(context.l10n.kidsRankNeedsSiblings,
                              textAlign: TextAlign.center,
                              style: kidsStyle(context,
                                  size: 14, color: p.textDim)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Geo.gapLg),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Geo.gapSm),
                        itemBuilder: (context, i) => _RankRow(
                            row: rows[i],
                            rank: i + 1,
                            isYou:
                                rows[i].profile.id == s.activeKidsProfileId),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = kidsPal(context);
    final rows = _rows;
    if (rows == null) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 24, 44, 48),
      children: [
        KidsSectionHeader(
          title: context.l10n.kidsTabRank,
          arabic: context.l10n.kidsRankArabic,
          size: 24,
          arabicSize: 20,
        ),
        const SizedBox(height: 6),
        Text(context.l10n.kidsRankSub,
            style: kidsStyle(context, size: 13.5, color: p.textDim)),
        const SizedBox(height: 22),
        if (rows.length <= 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(context.l10n.kidsRankNeedsSiblings,
                  textAlign: TextAlign.center,
                  style: kidsStyle(context, size: 15, color: p.textDim)),
            ),
          )
        else
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final youIndex =
                rows.indexWhere((r) => r.profile.id == s.activeKidsProfileId);
            final list = Column(children: [
              _RankBanner(count: rows.length),
              const SizedBox(height: 10),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Geo.gapSm),
                  child: _RankRow(
                      row: rows[i],
                      rank: i + 1,
                      isYou: i == youIndex,
                      desktop: true),
                ),
            ]);
            if (narrow || youIndex < 0) return list;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: list),
                const SizedBox(width: Geo.gapLg),
                SizedBox(
                    width: 280, child: _YouCard(rows: rows, youIndex: youIndex)),
              ],
            );
          }),
      ],
    );
  }
}

class _RankBanner extends StatelessWidget {
  final int count;
  const _RankBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [p.accent2, p.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Geo.radiusLg),
        boxShadow: [
          BoxShadow(
              color: p.accent2.withValues(alpha: .30),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        const Text('🏆', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Text(context.l10n.kidsRankBannerTitle,
            style: kidsStyle(context,
                size: 17, weight: FontWeight.w800, color: Colors.white)),
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
    final p = kidsPal(context);
    final you = rows[youIndex];
    final isFirst = youIndex == 0;
    final gap = isFirst ? 0 : rows[youIndex - 1].xp - you.xp;
    return Container(
      padding: const EdgeInsets.all(Geo.gapLg),
      decoration: kidsPanel(context),
      child: Column(children: [
        Text(you.profile.avatar, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 10),
        Text(context.l10n.kidsRankYouAre(youIndex + 1),
            style: kidsStyle(context, size: 16, weight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
            isFirst
                ? context.l10n.kidsRankYouAreFirst
                : context.l10n.kidsRankToNext(gap, youIndex),
            textAlign: TextAlign.center,
            style: kidsStyle(context, size: 12.5, color: p.textDim)),
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  final KidsRankRow row;
  final int rank;
  final bool isYou;
  final bool desktop;
  const _RankRow(
      {required this.row,
      required this.rank,
      required this.isYou,
      this.desktop = false});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.all(Geo.gapMd),
      decoration: BoxDecoration(
        color: isYou ? p.accent.withValues(alpha: .14) : p.surface,
        borderRadius: BorderRadius.circular(Geo.radiusMd),
        border: isYou
            ? Border.all(color: p.accent, width: 2)
            : desktop
                ? Border.all(color: p.surfaceHigh, width: 1.5)
                : null,
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: rank <= 3 ? p.amber.withValues(alpha: .25) : p.surfaceHigh,
          ),
          child: Text('$rank',
              style: kidsStyle(context, size: 13, weight: FontWeight.w800)),
        ),
        const SizedBox(width: Geo.gapMd),
        Text(row.profile.avatar, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: Geo.gapSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isYou ? context.l10n.kidsYou : row.profile.name,
                  style:
                      kidsStyle(context, size: 14.5, weight: FontWeight.w700)),
              Text(context.l10n.kidsLevelLabel(row.level),
                  style: kidsStyle(context, size: 11.5, color: p.textDim)),
            ],
          ),
        ),
        Text('${row.xp} XP',
            style: kidsStyle(context, size: 14, weight: FontWeight.w800)),
      ]),
    );
  }
}
