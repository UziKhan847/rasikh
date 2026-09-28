import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart' show KidsTextScale;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_desktop_nav.dart';
import 'kids_path.dart';
import 'kids_widgets.dart';

/// The Learn tab: the whole Kids path, stage by stage.
///
/// This used to be a flat grid of 28 letters, which is where a Qāʿidah
/// *begins* rather than what it covers. It is a list of [KidsBlock]s now —
/// letters, joining shapes, special shapes, then the ḥarakāt/madd/tanwīn/
/// words units the grown-up path already teaches — with the letter grid moved
/// down one level into [KidsBlockScreen].
///
/// Stages unlock in order, and so do the tiles inside them.
class KidsAlphabetScreen extends StatelessWidget {
  const KidsAlphabetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final ui = kbUi(context);
    final path = kidsPath(context);
    final current = kidsCurrentBlockIndex(context, prog);
    final safeTop = MediaQuery.paddingOf(context).top;

    // The design's Learn screen (kb_screens.dart `KbLearnScreen`): the title
    // and its Arabic name on the sky, then one card per stage, 16 apart.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        // .builder, not a children list: building a stage's items is not
        // free — the reused grown-up stages construct a whole unit list to
        // find their phases — and there are enough stages now that doing
        // every one of them per frame is wasted work on a phone.
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
              20, safeTop + 8 > 58 ? safeTop + 8 : 58, 20, 130),
          itemCount: path.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: KbHeading(context.l10n.kidsPathTitle,
                          ui: ui, fontSize: 30)),
                  KbArabicTitle(context.l10n.kidsPathArabic, ui: ui),
                ],
              );
            }
            final b = i - 1;
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _BlockRow(block: path[b], index: b, current: current),
            );
          },
        ),
      ),
    );
  }
}

/// [open] is a stage or tile that can be entered but has not been cleared —
/// only ever reached through the testing unlock ([kidsLocked]), and kept
/// distinct from [done] so an unlocked tile never wears a finished tile's
/// checkmark.
enum _State { done, open, current, locked }

class _BlockRow extends StatelessWidget {
  final KidsBlock block;
  final int index;

  /// The block [kidsCurrentBlockIndex] points at — normally the first with
  /// unfinished items, but the testing pin ([ProgressStore.devStage]) can
  /// move it anywhere. So "done" below is decided from this row's own items,
  /// not from `index < current`: that shortcut only held because "current"
  /// used to mean "the first incomplete stage" by construction.
  final int current;
  const _BlockRow({required this.block, required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    // Built once: a reused grown-up stage constructs the whole Qāʿidah unit
    // list to find its phases, so this is not a cheap getter.
    final items = block.items(context);
    final total = items.length;
    final done = kidsItemsDone(prog, items);
    final isDone = total > 0 && done == total;
    final isCurrent = index == current;
    final locked = !isDone && !isCurrent && kidsLocked(prog, index, current);
    final title = block.title(context);

    return Semantics(
      key: ValueKey('kids.block.${block.id}'),
      label: title,
      button: true,
      child: KbLearnCard(
        ui: kbUi(context),
        glyph: block.badge,
        title: title,
        desc: block.subtitle(context),
        current: isCurrent,
        done: isDone,
        locked: locked,
        count: done,
        total: total == 0 ? 1 : total,
        onTap: () {
          if (locked) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                  SnackBar(content: Text(context.l10n.kidsBlockLocked)));
            return;
          }
          pushKidsOverlay(context,
              title: title, builder: (_) => KidsBlockScreen(block: block));
        },
      ),
    );
  }
}

/// One stage's tiles — the letter grid the Learn tab used to be, generalised
/// so a stage of quizzes or lesson pages renders through the same screen.
class KidsBlockScreen extends StatelessWidget {
  final KidsBlock block;
  const KidsBlockScreen({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final items = block.items(context);
    final done = kidsCurrentItemIndex(prog, items);
    final desktop = useDesktop(context);

    Widget body(BuildContext context) {
      final ui = kbUi(context);
      final safeTop = MediaQuery.paddingOf(context).top;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          // Measured INSIDE the 900px cap, not the pane's full width —
          // otherwise a wide desktop window computes columns for its own
          // width, then the cap squeezes that many into 900px anyway.
          child: LayoutBuilder(builder: (context, c) {
            final cols = ((c.maxWidth - 40) / 110).floor().clamp(3, 8);
            return CustomScrollView(slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    20, desktop ? 20 : (safeTop + 8 > 52 ? safeTop + 8 : 52), 20, 0),
                sliver: SliverList.list(children: [
                  // On desktop the shell's top bar already carries the title
                  // and the way back.
                  if (!desktop) ...[
                    Row(children: [
                      KbRoundButton(
                          Directionality.of(context) == TextDirection.rtl
                              ? 'arrow_forward'
                              : 'arrow_back',
                          ui: ui,
                          tooltip:
                              MaterialLocalizations.of(context).backButtonTooltip,
                          onTap: () => Navigator.maybePop(context)),
                      const SizedBox(width: 16),
                      Flexible(
                          child: KbHeading(block.title(context),
                              ui: ui, fontSize: 30)),
                    ]),
                    const SizedBox(height: 20),
                  ],
                  KbSurface(
                    color: ui.surface,
                    edge: ui.edge,
                    elev: KbElev.card,
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(children: [
                      Expanded(
                        child: KbProgress(
                            value: items.isEmpty ? 0 : done / items.length,
                            ui: ui),
                      ),
                      const SizedBox(width: 12),
                      Text('$done / ${items.length}',
                          style: kbText(17, kbC(ui.linkInk))),
                    ]),
                  ),
                  const SizedBox(height: 22),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: .95,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _ItemTile(
                    item: items[i],
                    state: i < done
                        ? _State.done
                        : i == done
                            ? _State.current
                            : kidsLocked(prog, i, done)
                                ? _State.locked
                                : _State.open,
                  ),
                ),
              ),
            ]);
          }),
        ),
      );
    }

    // On desktop the shell hosts this in its content pane, under a top bar
    // that already carries the title and the way back. On mobile it is a
    // pushed route, so it needs its own Scaffold — without one there is no
    // ScaffoldMessenger for the "finish the one before it" snackbar to land
    // in — and its own backdrop, the scene behind every Kids screen.
    if (desktop) return Builder(builder: body);
    return KidsTextScale(
      child: Scaffold(
        backgroundColor: kbPageBg(kbUi(context)),
        body: KidsBackdrop(child: Builder(builder: body)),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final KidsItem item;
  final _State state;
  const _ItemTile({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final locked = state == _State.locked;
    final current = state == _State.current;
    final label = item.label(context);

    // A tile (UI_SPEC §1): solid face and hard edge; the current one wears the
    // selection ring and accent edge; a cleared one gets the reward check.
    return Semantics(
      label: label,
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: KbSurface(
              // Keyed by the item's own progress id — already unique across
              // the path — so the widget tests can address a specific tile.
              // Locked tiles deliberately render no text to find them by (see
              // below).
              key: ValueKey(item.id),
              color: current ? ui.tile : ui.surface,
              edge: current ? ui.accentEdge : ui.edge,
              outline: current ? ui.accent : null,
              outlineWidth: 3,
              elev: KbElev.tile,
              radius: 20,
              onTap: () {
                if (locked) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                        SnackBar(content: Text(context.l10n.kidsItemLocked)));
                  return;
                }
                openKidsItem(context, item);
              },
              // A tile still ahead is a plain lock in the design — no glyph,
              // no name — so the stage reads as a sequence to unlock rather
              // than a wall of equal cards.
              child: locked
                  ? Center(
                      child: KbIcon('lock', size: 26, color: kbC(ui.inkSoft)))
                  // Scale-down guard around the WHOLE tile, not just the
                  // glyph: the glyph and its name both ride the reader's text
                  // size and either can outgrow the cell. Scaling them
                  // together keeps them in proportion.
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 48,
                              child: Center(
                                child: item.glyph.isEmpty
                                    ? KbIcon(kbIconName(item.icon),
                                        size: 32,
                                        color: kbC(current
                                            ? ui.tileInk
                                            : ui.linkInk))
                                    : Text(
                                        item.glyph,
                                        textDirection: TextDirection.rtl,
                                        style: kbText(
                                            32,
                                            kbC(current
                                                ? ui.tileInk
                                                : ui.ink),
                                            family: kbFontArabic,
                                            weight: FontWeight.w600,
                                            height: 1.3),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kbText(
                                  14,
                                  kbC(current ? ui.tileInk : ui.inkSoft),
                                  weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          if (state == _State.done)
            PositionedDirectional(
              top: -4,
              end: -4,
              child: IgnorePointer(
                child: KbDot('check',
                    bg: ui.reward, ink: ui.rewardInk, size: 24, iconSize: 15,
                    ring: ui.surface),
              ),
            ),
        ],
      ),
    );
  }
}
