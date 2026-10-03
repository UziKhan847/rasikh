import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/kids_content.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import '../../kids_backdrops/kb_screens.dart' show KbBleed, KbPage;
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
      // The two sideways shelves run to the screen's edges (KbBleed), so their
      // tiles scroll off the edge of the phone rather than stopping short of it.
      KbBleed(
          child: _BadgeGrid(badges: badges, prog: prog, gutter: KbBleed.gutter)),
      const SizedBox(height: 28),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsShop, ui: ui, fontSize: 23)),
      const SizedBox(height: 10),
      ..._shopShelves(context, profile, bleed: true),
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
          final shopShelves = section(
              context.l10n.kidsShop,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _shopShelves(context, profile, bleed: false),
              ));
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
/// A horizontal grid fills column-major, so the leftmost (visible) nine are
/// the first nine in [badges] — the early-path ones a child can actually
/// reach — and the long tail scrolls in from the right.
class _BadgeGrid extends StatelessWidget {
  final List<KidsBadge> badges;
  final ProgressStore prog;

  /// See [_SideGrid.gutter].
  final double gutter;
  const _BadgeGrid({required this.badges, required this.prog, this.gutter = 0});

  /// A badge tile's own proportions (`KbBadgeTile`): `width / height`,
  /// very slightly taller than wide.
  static const _tileAspect = 1 / 1.05;

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return _SideGrid(
      count: badges.length,
      rows: 3,
      gutter: gutter,
      // Aim for ~110px tiles, so a phone shows the intended three columns and
      // a wide desktop panel shows more rather than three enormous ones.
      columns: (w) => (w / 110).floor().clamp(3, 6),
      tileHeight: (w) => w / _tileAspect,
      item: (context, i) {
        final b = badges[i];
        return KbBadgeTile(
            ui: ui,
            emoji: b.emoji,
            label: b.title(context),
            earned: b.earned(prog));
      },
    );
  }
}

/// A shelf of tiles [rows] tall that scrolls sideways once there are more
/// than fit — the badge wall and the Themes shelf. Built lazily: only the
/// columns on screen (and just past its edge) exist, so a long shelf costs
/// what a screenful does. Scrolling sideways inside a vertically-scrolling
/// page is unambiguous: the two gestures are on different axes.
class _SideGrid extends StatefulWidget {
  final int count;
  final int rows;

  /// How many columns show at once, for the shelf's width less its gutters.
  final int Function(double width) columns;

  /// A tile's height for its width.
  final double Function(double tileWidth) tileHeight;
  final Widget Function(BuildContext context, int index) item;

  /// Space before the first tile and after the last. A shelf that runs to the
  /// screen's edges ([KbBleed]) passes the page's padding here, so at rest its
  /// tiles line up with everything else on the page.
  final double gutter;
  const _SideGrid({
    required this.count,
    required this.rows,
    required this.columns,
    required this.tileHeight,
    required this.item,
    this.gutter = 0,
  });

  /// The design's gap between tiles.
  static const spacing = 12.0;

  @override
  State<_SideGrid> createState() => _SideGridState();
}

class _SideGridState extends State<_SideGrid> {
  final _c = ScrollController();

  /// How far a tile's selection ring, 3D edge and shadow reach past its box.
  /// The clip and the fade mask are grown by these so they cover everything a
  /// tile paints — a fade that stopped at the tile's box left the shadow (and,
  /// sideways, whole tiles) drawn at full strength just beyond it, which is
  /// the hard vertical line a fade used to end in.
  static const _above = 16.0, _below = 48.0;

  /// Room for the first and last tiles' selection rings when the shelf does
  /// not bleed to the screen's edges.
  static const _ring = 6.0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return LayoutBuilder(builder: (context, c) {
      final side = w.gutter > 0 ? 0.0 : _ring;
      final inner = c.maxWidth - 2 * w.gutter;
      final cols = w.columns(inner);
      final tileW = (inner - _SideGrid.spacing * (cols - 1)) / cols;
      final tileH = w.tileHeight(tileW);
      final height = tileH * w.rows + _SideGrid.spacing * (w.rows - 1);
      final scrolls = w.count > cols * w.rows;
      final dir = Directionality.of(context);

      final grid = GridView.builder(
        controller: _c,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
            w.gutter + side, _above, w.gutter + side, _below),
        // Horizontal scroll ⇒ the cross axis is vertical: this is the ROW
        // count, and the main-axis extent is a tile's width.
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: w.rows,
          mainAxisExtent: tileW,
          mainAxisSpacing: _SideGrid.spacing,
          crossAxisSpacing: _SideGrid.spacing,
        ),
        itemCount: w.count,
        itemBuilder: w.item,
      );

      // The shelf's own box is the tiles' height; the scroll view (and so its
      // clip and the fade mask) reaches past it by the tiles' overhang.
      return SizedBox(
        width: c.maxWidth,
        height: height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: -side,
            right: -side,
            top: -_above,
            bottom: -_below,
            // One mask, always there, whose gradient follows the scroll — a
            // mask that came and went would move the scroll view in the tree
            // and cancel a drag in progress. An edge fades only while it hides
            // something: the far end until the shelf reaches it, the near end
            // once it has moved off it.
            child: AnimatedBuilder(
              animation: _c,
              child: grid,
              builder: (context, child) {
                final dims = _c.hasClients && _c.position.hasContentDimensions;
                final lead = dims && _c.offset > .5;
                final trail = scrolls &&
                    (!dims || _c.offset < _c.position.maxScrollExtent - .5);
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) {
                    final e = (24 / r.width).clamp(0.0, .5);
                    final clear = kbC(kWhite, 0), solid = kbC(kWhite);
                    return LinearGradient(
                      begin: AlignmentDirectional.centerStart.resolve(dir),
                      end: AlignmentDirectional.centerEnd.resolve(dir),
                      stops: [0, e, 1 - e, 1],
                      colors: [
                        lead ? clear : solid,
                        solid,
                        solid,
                        trail ? clear : solid,
                      ],
                    ).createShader(r);
                  },
                  child: child,
                );
              },
            ),
          ),
        ]),
      );
    });
  }
}

/// Looks, Colours, then Helpers — the shop grouped into shelves rather than
/// one flat list, so the very different things gems can buy (a cosmetic worn
/// on the avatar, a palette that repaints the app, a consumable that spends
/// itself) read as three different kinds of thing rather than one list.
List<Widget> _shopShelves(BuildContext context, KidsProfile profile,
    {required bool bleed}) {
  final shop = kidsShopItems(context);
  final prog = ProgressScope.of(context);
  final owned = prog.shopOwned;
  // Retired items stay listed for those who own them; a reward appears once
  // earned (or under the testing unlock, which shows everything).
  bool listed(KidsShopItem i) =>
      owned.contains(i.id) ||
      (i.rewardOnly ? prog.unlockAll : !i.retired);
  final looks =
      shop.where((i) => i.shelf == KidsShopShelf.looks && listed(i)).toList();
  final things =
      shop.where((i) => i.shelf == KidsShopShelf.things && listed(i)).toList();
  final colours = shop.where((i) => i.shelf == KidsShopShelf.colours).toList();
  final consumables = kidsConsumables(context);
  final themes = _ThemeShop(
      items: colours, profile: profile, gutter: bleed ? KbBleed.gutter : 0);
  return [
    // Themes first, as a shelf of painted previews: a theme is the one item a
    // child cannot judge from a name or an emoji, so the tile IS the scene.
    _ShelfLabel(context.l10n.kidsShopThemes),
    bleed ? KbBleed(child: themes) : themes,
    const SizedBox(height: 20),
    _ShelfLabel(context.l10n.kidsShopLooks),
    for (final (i, item) in looks.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      _ShopRow(item: item, profile: profile),
    ],
    const SizedBox(height: 20),
    _ShelfLabel(context.l10n.kidsShopThings),
    for (final (i, item) in things.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      _ShopRow(item: item, profile: profile),
    ],
    const SizedBox(height: 20),
    _ShelfLabel(context.l10n.kidsShopHelpers),
    for (final (i, item) in consumables.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      _ConsumableRow(item: item),
    ],
  ];
}

/// The Themes shelf: painted theme tiles (`KbThemeShopTile`), three across and
/// [_rows] tall, scrolling sideways like the badge wall. Everything a tile does is the app's own shop logic,
/// unchanged from the rows it replaced — a locked tile buys the item
/// (`buyShopItem`, only when the balance covers it), an owned one equips it, and
/// the Classic tile takes the current theme off (`kidsUnequipItem`), which is how
/// a child has always gone back to the original palette.
class _ThemeShop extends StatelessWidget {
  final List<KidsShopItem> items;
  final KidsProfile profile;

  /// See [_SideGrid.gutter].
  final double gutter;
  const _ThemeShop(
      {required this.items, required this.profile, this.gutter = 0});

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
      // The testing unlock lets every theme be tried on without buying it.
      final owned =
          item == null || prog.unlockAll || prog.shopOwned.contains(item.id);
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

    final families = [kKidsDefaultTheme, for (final item in items) item.id];
    final ts = MediaQuery.textScalerOf(context);
    return _SideGrid(
      count: families.length,
      rows: _rows,
      gutter: gutter,
      // At most three across, at any width.
      columns: (_) => 3,
      // `KbThemeShopTile`: padding 8 / 10 around a square preview (the tile
      // less its side padding), 6, the name (17 × 1.1), 6, the price or state
      // row (15 px text beside a 15 px symbol, whose line box is 1.2 em).
      tileHeight: (w) =>
          8 + (w - 16) + 6 + ts.scale(17) * 1.1 + 6 +
          math.max(ts.scale(15), 15 * 1.2) + 10 + 2,
      item: (context, i) => i == 0
          ? tile(kKidsDefaultTheme)
          : tile(families[i], item: items[i - 1]),
    );
  }

  /// Rows on the shelf. Two keeps the whole shop close under the badges;
  /// the rest of the thirteen scroll in from the side.
  static const _rows = 2;
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
                        // Flexible: a 320 px phone at the largest text leaves
                        // this column very little room beside the Get pill.
                        Flexible(
                          child: Text('$price',
                              style: kbText(18, kbC(ui.inkSoft),
                                  weight: FontWeight.w700)),
                        ),
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
    // The testing unlock lets every look be tried on without buying it.
    final owned = prog.unlockAll || prog.shopOwned.contains(item.id);
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
