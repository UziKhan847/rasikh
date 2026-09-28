import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/kids_content.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import '../../kids_backdrops/kb_screens.dart' show KbPage;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_avatar_face.dart';

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
    final ui = kbUi(context);
    final badges = kidsBadgeDefs();
    final profile = s.activeKidsProfile!;

    // The design's Rewards screen (kb_screens.dart `KbRewardsScreen`).
    return KbPage(cross: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
            child: KbHeading(context.l10n.kidsTabRewards, ui: ui, fontSize: 30)),
        const SizedBox(width: 12),
        KbGemCounter(prog.gems, ui: ui),
      ]),
      const SizedBox(height: 22),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsBadges, ui: ui, fontSize: 23)),
      const SizedBox(height: 14),
      _BadgeGrid(badges: badges, prog: prog),
      const SizedBox(height: 28),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsShop, ui: ui, fontSize: 23)),
      const SizedBox(height: 10),
      _ShopShelves(profile: profile),
    ]);
  }

  Widget _desktopBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final ui = kbUi(context);
    final badges = kidsBadgeDefs();
    final profile = s.activeKidsProfile!;

    Widget section(String title, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: KbHeading(title, ui: ui, fontSize: 23)),
            const SizedBox(height: 14),
            child,
          ],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 24, 44, 48),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: KbHeading(context.l10n.kidsTabRewards,
                    ui: ui, fontSize: 30)),
            if (context.l10n.kidsRewardsArabic.isNotEmpty)
              KbArabicTitle(context.l10n.kidsRewardsArabic, ui: ui),
          ],
        ),
        const SizedBox(height: 18),
        // The balance, on the reward colour — gems are what a child earns.
        KbSurface(
          color: ui.reward,
          edge: ui.rewardEdge,
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: Row(children: [
            const Text('💎', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${prog.gems}',
                      style: kbText(24, kbC(ui.rewardInk), height: 1.1)),
                  Text(context.l10n.kidsGemsEarned,
                      style: kbText(16, kbC(ui.rewardInk),
                          weight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(builder: (context, c) {
          final badgeGrid = section(context.l10n.kidsBadges,
              _BadgeGrid(badges: badges, prog: prog));
          final shopShelves =
              section(context.l10n.kidsShop, _ShopShelves(profile: profile));
          if (c.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [badgeGrid, const SizedBox(height: 28), shopShelves],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: badgeGrid),
              const SizedBox(width: 32),
              Expanded(child: shopShelves),
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
  const _BadgeGrid({required this.badges, required this.prog});

  /// The design's gap between badge tiles.
  static const spacing = 12.0;

  /// Rows, not columns — the cap that keeps this off the rest of the page.
  static const _rows = 3;

  /// A badge tile's own proportions (`KbBadgeTile`): `width / height`,
  /// very slightly taller than wide.
  static const _tileAspect = 1 / 1.05;

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return LayoutBuilder(builder: (context, c) {
      // Aim for ~110px tiles, so a phone shows the intended three columns and
      // a wide desktop panel shows more rather than three enormous ones.
      final columns = (c.maxWidth / 110).floor().clamp(3, 6);
      final tileW = (c.maxWidth - spacing * (columns - 1)) / columns;
      final tileH = tileW / _tileAspect;
      final height = tileH * _rows + spacing * (_rows - 1);
      final scrolls = badges.length > columns * _rows;

      final grid = GridView.count(
        scrollDirection: Axis.horizontal,
        // Horizontal scroll ⇒ the cross axis is vertical, so this is the ROW
        // count, and `childAspectRatio` is cross/main, i.e. height/width —
        // the reciprocal of the vertical-grid figure.
        crossAxisCount: _rows,
        childAspectRatio: 1 / _tileAspect,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        // Room for the tiles' edges and the earned ring, which sit outside
        // their boxes.
        clipBehavior: Clip.none,
        children: [
          for (final b in badges)
            SizedBox(
              width: tileW,
              child: KbBadgeTile(
                  ui: ui,
                  emoji: b.emoji,
                  label: b.title(context),
                  earned: b.earned(prog)),
            ),
        ],
      );
      return SizedBox(
        height: height,
        // The row fades out at the cut edge, so it reads as continuing rather
        // than ending — the same cue the Home trail uses for its own scroll
        // window. A mask, so the scene shows through.
        child: !scrolls
            ? grid
            : ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  begin: AlignmentDirectional.centerStart
                      .resolve(Directionality.of(context)),
                  end: AlignmentDirectional.centerEnd
                      .resolve(Directionality.of(context)),
                  stops: [0, 1 - 24 / r.width, 1],
                  colors: [kbC(kWhite), kbC(kWhite), kbC(kWhite, 0)],
                ).createShader(r),
                child: grid,
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Themes first, as a grid of painted previews: a theme is the one item
        // a child cannot judge from a name or an emoji, so the tile IS the scene.
        _ShelfLabel(context.l10n.kidsShopThemes),
        _ThemeShop(items: colours, profile: profile),
        const SizedBox(height: 20),
        _ShelfLabel(context.l10n.kidsShopLooks),
        for (final (i, item) in looks.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          _ShopRow(item: item, profile: profile),
        ],
        const SizedBox(height: 20),
        _ShelfLabel(context.l10n.kidsShopHelpers),
        for (final (i, item) in consumables.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          _ConsumableRow(item: item),
        ],
      ],
    );
  }
}

/// The Themes shelf: the design's 3-column grid of painted theme tiles
/// (`KbThemeShopTile`). Everything a tile does is the app's own shop logic,
/// unchanged from the rows it replaced — a locked tile buys the item
/// (`buyShopItem`, only when the balance covers it), an owned one equips it, and
/// the Classic tile takes the current theme off (`kidsUnequipItem`), which is how
/// a child has always gone back to the original palette.
class _ThemeShop extends StatelessWidget {
  final List<KidsShopItem> items;
  final KidsProfile profile;
  const _ThemeShop({required this.items, required this.profile});

  static String _name(BuildContext context, String family) => switch (family) {
    'kids_ocean' => context.l10n.kidsThemeOcean,
    'kids_lagoon' => context.l10n.kidsThemeLagoon,
    'kids_desert' => context.l10n.kidsThemeDesert,
    'kids_night' => context.l10n.kidsThemeNight,
    'kids_forest' => context.l10n.kidsThemeForest,
    'kids_blossom' => context.l10n.kidsThemeBlossom,
    'kids_sunset' => context.l10n.kidsThemeSunset,
    'kids_rain' => context.l10n.kidsThemeRain,
    'kids_cave' => context.l10n.kidsThemeCave,
    'kids_sunrise' => context.l10n.kidsThemeSunrise,
    'kids_frozen' => context.l10n.kidsThemeFrozen,
    'kids_snowy' => context.l10n.kidsThemeSnowy,
    _ => context.l10n.kidsThemeClassic,
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final ui = kbUi(context);
    final current = profile.theme;
    final worn = items.where((i) => i.id == current).firstOrNull;

    Widget tile(String family, {KidsShopItem? item}) {
      final owned = item == null || prog.shopOwned.contains(item.id);
      return KbThemeShopTile(
        key: ValueKey('kidsThemeTile.$family'),
        theme: kbThemeFor(family),
        ui: ui,
        name: _name(context, family),
        price: item?.cost ?? 0,
        useLabel: context.l10n.kidsShopUse,
        inUseLabel: context.l10n.kidsShopInUse,
        owned: owned,
        inUse: current == family,
        onTap: () {
          if (current == family) return;
          if (item == null) {
            // Classic: back to the original palette.
            if (worn != null) s.update(() => kidsUnequipItem(worn, profile));
          } else if (!owned) {
            if (prog.gems >= item.cost) prog.buyShopItem(item.id, item.cost);
          } else {
            s.update(() => kidsEquipItem(item, profile));
          }
        },
      );
    }

    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final columns = c.maxWidth > 560 ? 4 : 3;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final t in [
          tile(kKidsDefaultTheme),
          for (final item in items) tile(item.id, item: item),
        ])
          SizedBox(width: w, child: t),
      ]);
    });
  }
}

/// A shelf's name, on the sky: the design's one-line subtitle ("Themes",
/// "Looks"), 10 above its contents.
class _ShelfLabel extends StatelessWidget {
  final String label;
  const _ShelfLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KbSubtitle(label, ui: kbUi(context)),
      );
}

/// One shop row — the design's Looks row (kb_components.dart `KbLooksRow`):
/// the thing itself in a 50 px face, its name, and on the right what can be
/// done with it. Built from the same parts as `KbLooksRow` because the app's
/// rows have more states than the design's two.
class _Row extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final int? price;
  final Widget? extra;
  final Widget action;
  const _Row(
      {required this.emoji,
      required this.title,
      this.subtitle,
      this.price,
      this.extra,
      required this.action});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      elev: KbElev.card,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        KidsAvatarFace(emoji, size: 50 / 1.15),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kbText(22, kbC(ui.ink), height: 1.1)),
              if (subtitle != null)
                Text(subtitle!,
                    style: kbText(16, kbC(ui.inkSoft),
                        weight: FontWeight.w600, height: 1.35)),
              if (price != null || extra != null)
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (price != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        KbIcon('diamond', size: 18, color: kbC(ui.linkInk)),
                        const SizedBox(width: 4),
                        Text('$price',
                            style: kbText(18, kbC(ui.inkSoft),
                                weight: FontWeight.w700)),
                      ]),
                    ?extra,
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ]),
    );
  }
}

/// The row's primary action: the design's deep "Get" pill — or, when the
/// balance does not cover it, the same pill on the disabled face (UI_SPEC §5:
/// disabled = disabledBg, inkSoft), not tappable.
class _BuyPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _BuyPill(this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    const padding = EdgeInsets.fromLTRB(26, 9, 26, 7);
    if (onTap != null) {
      return KbPill(label,
          ui: ui, kind: KbPillKind.deep, padding: padding, onTap: onTap);
    }
    return KbSurface(
      color: ui.disabledBg,
      edge: ui.edge,
      elev: KbElev.edge4,
      radius: 999,
      padding: padding,
      child: Text(label, style: kbText(18, kbC(ui.inkSoft))),
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
    final ui = kbUi(context);
    final owned = prog.shopOwned.contains(item.id);
    final canBuy = !owned && prog.gems >= item.cost;
    final equipped = owned && kidsItemEquipped(item, profile);
    return _Row(
      emoji: item.emoji,
      title: item.title(context),
      price: owned ? null : item.cost,
      action: !owned
          ? _BuyPill(context.l10n.kidsBuy,
              onTap: canBuy ? () => prog.buyShopItem(item.id, item.cost) : null)
          : equipped
              // Worn — and, like every cosmetic, takeable off again: a frame
              // goes back to no frame, a theme to the original palette, an
              // avatar unlock to the child's own avatar. (A theme and an
              // avatar used to be one-way, with a dead "Worn" label where
              // this button is.)
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  KbDot('check', bg: ui.cardDeep, ink: kWhite),
                  const SizedBox(width: 10),
                  KbPill(
                    item.shelf == KidsShopShelf.colours ||
                            kidsAvatarUnlock(item.id) != null
                        ? context.l10n.kidsShopUseOriginal
                        : context.l10n.kidsShopTakeOff,
                    ui: ui,
                    kind: KbPillKind.outlined,
                    fontSize: 16,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    onTap: () => s.update(() => kidsUnequipItem(item, profile)),
                  ),
                ])
              : KbPill(context.l10n.kidsShopEquip,
                  ui: ui,
                  kind: KbPillKind.deep,
                  padding: const EdgeInsets.fromLTRB(26, 9, 26, 7),
                  onTap: () => s.update(() => kidsEquipItem(item, profile))),
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
    final ui = kbUi(context);
    final canBuy = prog.gems >= item.cost;
    return _Row(
      emoji: item.emoji,
      title: item.title(context),
      subtitle: item.subtitle(context),
      price: item.cost,
      extra: prog.streakFreezes > 0
          ? Text(context.l10n.kidsFreezesCount(prog.streakFreezes),
              style: kbText(16, kbC(ui.linkInk)))
          : null,
      action: _BuyPill(context.l10n.kidsBuy,
          onTap: canBuy ? () => prog.buyStreakFreeze(item.cost) : null),
    );
  }
}
