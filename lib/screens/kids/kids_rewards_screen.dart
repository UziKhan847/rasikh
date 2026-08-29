import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import 'kids_widgets.dart';

/// Gems, badges, and a small cosmetic shop. Gems are earned only — every
/// gem on the balance came from a lesson/quiz/streak reward (see
/// `ProgressStore.awardGems` call sites), never a purchase; buying a shop
/// item only ever spends gems already earned (`ProgressStore.buyShopItem`).
class KidsRewardsScreen extends StatelessWidget {
  const KidsRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final badges = kidsBadgeDefs(context);
    final shop = kidsShopItems(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapXl),
        children: [
          Row(children: [
            Text(context.l10n.kidsTabRewards,
                style: kidsStyle(context, size: 20, weight: FontWeight.w800)),
            const Spacer(),
            KidsStatChip(
                icon: Icons.diamond_rounded,
                color: p.accent2,
                label: '${prog.gems}'),
          ]),
          const SizedBox(height: Geo.gapLg),
          Text(context.l10n.kidsBadges,
              style: kidsStyle(context, size: 15, weight: FontWeight.w800)),
          const SizedBox(height: Geo.gapSm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: Geo.gapSm,
            crossAxisSpacing: Geo.gapSm,
            childAspectRatio: .95,
            children: [
              for (final b in badges)
                KidsBadgeTile(
                    emoji: b.emoji, title: b.title(context), earned: b.earned(prog)),
            ],
          ),
          const SizedBox(height: Geo.gapLg),
          Text(context.l10n.kidsShop,
              style: kidsStyle(context, size: 15, weight: FontWeight.w800)),
          const SizedBox(height: Geo.gapSm),
          for (final item in shop)
            Padding(
              padding: const EdgeInsets.only(bottom: Geo.gapSm),
              child: _ShopRow(item: item),
            ),
        ],
      ),
    );
  }

  Widget _desktopBuild(BuildContext context) {
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final badges = kidsBadgeDefs(context);
    final shop = kidsShopItems(context);
    final gold = kidsTint(context, p.amber);

    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 24, 44, 48),
      children: [
        KidsSectionHeader(
          title: context.l10n.kidsTabRewards,
          arabic: context.l10n.kidsRewardsArabic,
          size: 24,
          arabicSize: 20,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: gold.bg,
            border: Border.all(color: gold.border, width: 1.5),
            borderRadius: BorderRadius.circular(Geo.radiusLg),
          ),
          child: Row(children: [
            const Text('💎', style: TextStyle(fontSize: 30)),
            const SizedBox(width: Geo.gapMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${prog.gems}',
                    style: kidsStyle(context,
                        size: 22, weight: FontWeight.w800, color: gold.text)),
                Text(context.l10n.kidsGemsEarned,
                    style: kidsStyle(context, size: 12.5, color: gold.text)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(builder: (context, c) {
          final badgeGrid = GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: Geo.gapMd,
            crossAxisSpacing: Geo.gapMd,
            childAspectRatio: .95,
            children: [
              for (final b in badges)
                KidsBadgeTile(
                    emoji: b.emoji,
                    title: b.title(context),
                    earned: b.earned(prog)),
            ],
          );
          final shopList = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in shop)
                Padding(
                  padding: const EdgeInsets.only(bottom: Geo.gapSm),
                  child: _ShopRow(item: item),
                ),
            ],
          );
          if (c.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.kidsBadges,
                    style: kidsStyle(context,
                        size: 15, weight: FontWeight.w800)),
                const SizedBox(height: Geo.gapSm),
                badgeGrid,
                const SizedBox(height: Geo.gapLg),
                Text(context.l10n.kidsShop,
                    style: kidsStyle(context,
                        size: 15, weight: FontWeight.w800)),
                const SizedBox(height: Geo.gapSm),
                shopList,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.kidsBadges,
                        style: kidsStyle(context,
                            size: 15, weight: FontWeight.w800)),
                    const SizedBox(height: Geo.gapSm),
                    badgeGrid,
                  ],
                ),
              ),
              const SizedBox(width: Geo.gapXl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.kidsShop,
                        style: kidsStyle(context,
                            size: 15, weight: FontWeight.w800)),
                    const SizedBox(height: Geo.gapSm),
                    shopList,
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  final KidsShopItem item;
  const _ShopRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final owned = prog.shopOwned.contains(item.id);
    final canBuy = !owned && prog.gems >= item.cost;
    return Container(
      padding: const EdgeInsets.all(Geo.gapMd),
      decoration: kidsCard(context),
      child: Row(children: [
        Text(item.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: Geo.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title(context),
                  style: kidsStyle(context, size: 14.5, weight: FontWeight.w700)),
              if (!owned)
                Row(children: [
                  Icon(Icons.diamond_rounded, size: 13, color: p.accent2),
                  const SizedBox(width: 4),
                  Text('${item.cost}',
                      style: kidsStyle(context, size: 12.5, color: p.textDim)),
                ]),
            ],
          ),
        ),
        if (owned)
          Icon(Icons.check_circle_rounded, color: p.accent)
        else
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: canBuy ? p.accent : p.surfaceHigh,
                foregroundColor: canBuy ? Colors.white : p.textDim),
            onPressed: canBuy ? () => prog.buyShopItem(item.id, item.cost) : null,
            child: Text(context.l10n.kidsBuy),
          ),
      ]),
    );
  }
}
