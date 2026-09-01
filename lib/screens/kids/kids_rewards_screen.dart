import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import 'kids_widgets.dart';

/// Gems, badges, and the shop. Gems are earned only — every gem on the
/// balance came from a lesson/quiz/streak/badge reward (see
/// `ProgressStore.awardGems` call sites), never a purchase; buying something
/// only ever spends gems already earned (`ProgressStore.buyShopItem` /
/// `buyStreakFreeze`).
///
/// The shop used to sell three items that rendered nowhere once bought — a
/// gem balance with nothing to show for it. Every item here now equips
/// somewhere the child already looks: `KidsAvatar` (the frame), `KidsMascot`
/// (the hat), `kidsPal` (a theme, which repaints the whole of Kids Mode), or
/// the child's own avatar (the extra unlock) — see `kids_content.dart`.
class KidsRewardsScreen extends StatelessWidget {
  const KidsRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final badges = kidsBadgeDefs();
    final profile = s.activeKidsProfile!;

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
          _BadgeGrid(badges: badges, prog: prog),
          const SizedBox(height: Geo.gapLg),
          Text(context.l10n.kidsShop,
              style: kidsStyle(context, size: 15, weight: FontWeight.w800)),
          const SizedBox(height: Geo.gapSm),
          _ShopShelves(profile: profile),
        ],
      ),
    );
  }

  Widget _desktopBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final badges = kidsBadgeDefs();
    final profile = s.activeKidsProfile!;
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
          final badgeGrid =
              _BadgeGrid(badges: badges, prog: prog, spacing: Geo.gapMd);
          final shopShelves = _ShopShelves(profile: profile);
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
                shopShelves,
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
                    shopShelves,
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

/// The badge wall: at most three rows tall, scrolling sideways past that.
///
/// It used to be a single `GridView` that grew a row for every three badges.
/// At 34 badges that is twelve rows — enough that the Shop below it was
/// several screens down and effectively hidden. Capping the height at three
/// rows and spilling the rest along the horizontal axis keeps the whole
/// Rewards tab on one screen no matter how many badges exist, which matters
/// because badges are meant to keep being added.
///
/// A horizontal `GridView` fills column-major, so the leftmost (visible)
/// nine are the first nine in [badges] — the early-path ones a child can
/// actually reach — and the long tail scrolls in from the right. Scrolling
/// sideways inside a vertically-scrolling list is unambiguous: the two
/// gestures are on different axes and never compete.
class _BadgeGrid extends StatelessWidget {
  final List<KidsBadge> badges;
  final ProgressStore prog;
  final double spacing;
  const _BadgeGrid(
      {required this.badges, required this.prog, this.spacing = Geo.gapSm});

  /// Rows, not columns — the cap that keeps this off the rest of the page.
  static const _rows = 3;

  /// A badge tile's own proportions, carried over from the grid this
  /// replaced: `width / height`, i.e. very slightly taller than wide.
  static const _tileAspect = .95;

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return LayoutBuilder(builder: (context, c) {
      // Aim for ~110px tiles, so a phone shows the intended three columns and
      // a wide desktop panel shows more rather than three enormous ones.
      final columns = (c.maxWidth / 110).floor().clamp(3, 6);
      final tileW = (c.maxWidth - spacing * (columns - 1)) / columns;
      final tileH = tileW / _tileAspect;
      final height = tileH * _rows + spacing * (_rows - 1);
      final scrolls = badges.length > columns * _rows;

      return SizedBox(
        height: height,
        child: Stack(
          children: [
            GridView.count(
              scrollDirection: Axis.horizontal,
              // Horizontal scroll ⇒ the cross axis is vertical, so this is
              // the ROW count, and `childAspectRatio` is cross/main, i.e.
              // height/width — the reciprocal of the vertical-grid figure.
              crossAxisCount: _rows,
              childAspectRatio: 1 / _tileAspect,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: [
                for (final b in badges)
                  SizedBox(
                    width: tileW,
                    child: KidsBadgeTile(
                        emoji: b.emoji,
                        title: b.title(context),
                        earned: b.earned(prog)),
                  ),
              ],
            ),
            // A wash of the page colour at the cut edge, so the row reads as
            // continuing rather than ending — the same cue the Home trail
            // uses for its own scroll window.
            if (scrolls)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 20,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [p.bg, p.bg.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Looks, Colours, then Helpers — the shop grouped into shelves rather than
/// one flat list, so the very different things gems can buy (a cosmetic worn
/// on the avatar, a palette that repaints the app, a consumable that spends
/// itself) read as three different kinds of thing rather than one list.
class _ShopShelves extends StatelessWidget {
  final KidsProfile profile;
  const _ShopShelves({required this.profile});

  @override
  Widget build(BuildContext context) {
    final shop = kidsShopItems(context);
    final looks =
        shop.where((i) => i.shelf == KidsShopShelf.looks).toList();
    final colours =
        shop.where((i) => i.shelf == KidsShopShelf.colours).toList();
    final consumables = kidsConsumables(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfLabel(context.l10n.kidsShopLooks),
        for (final item in looks)
          Padding(
            padding: const EdgeInsets.only(bottom: Geo.gapSm),
            child: _ShopRow(item: item, profile: profile),
          ),
        const SizedBox(height: Geo.gapSm),
        _ShelfLabel(context.l10n.kidsShopColours),
        for (final item in colours)
          Padding(
            padding: const EdgeInsets.only(bottom: Geo.gapSm),
            child: _ShopRow(item: item, profile: profile),
          ),
        const SizedBox(height: Geo.gapSm),
        _ShelfLabel(context.l10n.kidsShopHelpers),
        for (final item in consumables)
          Padding(
            padding: const EdgeInsets.only(bottom: Geo.gapSm),
            child: _ConsumableRow(item: item),
          ),
      ],
    );
  }
}

class _ShelfLabel extends StatelessWidget {
  final String label;
  const _ShelfLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(label,
          style: kidsStyle(context,
              size: 12, weight: FontWeight.w800, color: p.textDim)),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final KidsShopItem item;
  final KidsProfile profile;
  const _ShopRow({required this.item, required this.profile});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final owned = prog.shopOwned.contains(item.id);
    final canBuy = !owned && prog.gems >= item.cost;
    final equipped = owned && kidsItemEquipped(item, profile);
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
        if (!owned)
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: canBuy ? p.accent : p.surfaceHigh,
                foregroundColor: canBuy ? Colors.white : p.textDim),
            onPressed: canBuy ? () => prog.buyShopItem(item.id, item.cost) : null,
            child: Text(context.l10n.kidsBuy),
          )
        else if (equipped)
          // Only a hat or a frame can be taken back off — see
          // `kidsItemUnequippable`. A theme or the avatar unlock is a plain,
          // static "worn" state once chosen.
          kidsItemUnequippable(item)
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: p.textDim,
                      side: BorderSide(color: p.surfaceHigh)),
                  onPressed: () => s.update(
                      () => kidsUnequipItem(item, profile)),
                  child: Text(context.l10n.kidsShopEquipped),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, color: p.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(context.l10n.kidsShopEquipped,
                      style: kidsStyle(context, size: 12.5, color: p.accent)),
                ])
        else
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: () => s.update(() => kidsEquipItem(item, profile)),
            child: Text(context.l10n.kidsShopEquip),
          ),
      ]),
    );
  }
}

/// One row on the Helpers shelf: how many are in hand, and a way to buy
/// another. Unlike [_ShopRow] there is no "owned" state to reach — a
/// consumable is always purchasable again once the balance covers it.
class _ConsumableRow extends StatelessWidget {
  final KidsConsumable item;
  const _ConsumableRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final canBuy = prog.gems >= item.cost;
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
              Text(item.subtitle(context),
                  style: kidsStyle(context, size: 12, color: p.textDim)),
              Row(children: [
                Icon(Icons.diamond_rounded, size: 13, color: p.accent2),
                const SizedBox(width: 4),
                Text('${item.cost}',
                    style: kidsStyle(context, size: 12.5, color: p.textDim)),
                if (prog.streakFreezes > 0) ...[
                  const SizedBox(width: 10),
                  Text(context.l10n.kidsFreezesCount(prog.streakFreezes),
                      style: kidsStyle(context,
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: p.accent)),
                ],
              ]),
            ],
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: canBuy ? p.accent : p.surfaceHigh,
              foregroundColor: canBuy ? Colors.white : p.textDim),
          onPressed:
              canBuy ? () => prog.buyStreakFreeze(item.cost) : null,
          child: Text(context.l10n.kidsBuy),
        ),
      ]),
    );
  }
}
