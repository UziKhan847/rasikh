import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
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
    final p = kidsPal(context);
    final path = kidsPath(context);
    final current = kidsCurrentBlockIndex(context, prog);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          // .builder, not a children list: building a stage's items is not
          // free — the reused grown-up stages construct a whole unit list to
          // find their phases — and there are enough stages now that doing
          // every one of them per frame is wasted work on a phone.
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapXl),
            itemCount: path.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Geo.gapMd),
                  child: KidsSectionHeader(
                    title: context.l10n.kidsPathTitle,
                    arabic: context.l10n.kidsPathArabic,
                    size: 20,
                    arabicSize: 17,
                    arabicColor: p.accent,
                  ),
                );
              }
              final b = i - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: Geo.gapSm),
                child: _BlockRow(block: path[b], index: b, current: current),
              );
            },
          ),
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
    final p = kidsPal(context);
    final prog = ProgressScope.of(context);
    // Built once: a reused grown-up stage constructs the whole Qāʿidah unit
    // list to find its phases, so this is not a cheap getter.
    final items = block.items(context);
    final total = items.length;
    final done = kidsItemsDone(prog, items);
    final isDone = total > 0 && done == total;
    final isCurrent = index == current;
    final locked = !isDone && !isCurrent && kidsLocked(prog, index, current);
    final state = isDone
        ? _State.done
        : isCurrent
            ? _State.current
            : locked
                ? _State.locked
                : _State.open;
    final title = block.title(context);

    return Semantics(
      label: title,
      button: true,
      child: TapScale(
        key: ValueKey('kids.block.${block.id}'),
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
        child: Container(
          padding: const EdgeInsets.all(Geo.gapMd),
          decoration: BoxDecoration(
            color: locked ? kidsLockedFill(p) : p.surface,
            borderRadius: BorderRadius.circular(Geo.radiusLg),
            border: Border.all(
                color: isCurrent ? p.accent : Colors.transparent, width: 2),
            boxShadow: locked
                ? null
                : [
                    BoxShadow(
                        color: p.shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent
                    ? p.accent
                    : locked
                        ? Colors.transparent
                        : p.amber.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(Geo.radiusMd),
              ),
              child: locked
                  ? Icon(Icons.lock_rounded,
                      size: 20, color: p.textDim.withValues(alpha: .75))
                  // Scale-down guard: the badge glyph grows with the reader's
                  // arabicScale, and 'الٓمٓ' is already four letters wide.
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(block.badge,
                            textDirection: TextDirection.rtl,
                            style: quranicStyle(context,
                                size: 19,
                                height: 1.05,
                                color: isCurrent ? Colors.white : p.text)),
                      ),
                    ),
            ),
            const SizedBox(width: Geo.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kidsStyle(context,
                          size: 15, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(block.subtitle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          kidsStyle(context, size: 12, color: p.textDim)),
                  if (!locked) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(Geo.radiusPill),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : done / total,
                            minHeight: 6,
                            backgroundColor: p.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation(p.accent2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$done / $total',
                          style: kidsStyle(context,
                              size: 11.5,
                              weight: FontWeight.w800,
                              color: p.accent2)),
                    ]),
                  ],
                ],
              ),
            ),
            if (state == _State.done)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: Geo.gapSm),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: p.amber),
                  child: const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white),
                ),
              ),
          ]),
        ),
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
    final p = kidsPal(context);
    final items = block.items(context);
    final done = kidsCurrentItemIndex(prog, items);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapSm),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Geo.radiusPill),
                    child: LinearProgressIndicator(
                      value: items.isEmpty ? 0 : done / items.length,
                      minHeight: 8,
                      backgroundColor: p.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(p.accent2),
                    ),
                  ),
                ),
                const SizedBox(width: Geo.gapSm),
                Text('$done / ${items.length}',
                    style: kidsStyle(context,
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: p.accent2)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              // Measured INSIDE the 900px cap, not the pane's full width —
              // otherwise a wide desktop window computes columns for its own
              // width, then the cap squeezes that many into 900px anyway.
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = (c.maxWidth / 150).floor().clamp(3, 8);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapXl),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: Geo.gapMd,
                      crossAxisSpacing: Geo.gapMd,
                      childAspectRatio: 1.06,
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
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );

    // On desktop the shell hosts this in its content pane, under a top bar
    // that already carries the title and the way back. On mobile it is a
    // pushed route, so it needs its own Scaffold — without one there is no
    // ScaffoldMessenger for the "finish the one before it" snackbar to land
    // in, and no background behind the grid.
    if (useDesktop(context)) return body;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(block.title(context),
            style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final KidsItem item;
  final _State state;
  const _ItemTile({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final locked = state == _State.locked;
    final current = state == _State.current;
    final label = item.label(context);

    return Semantics(
      label: label,
      button: true,
      child: TapScale(
        // Keyed by the item's own progress id — already unique across the
        // path — so the widget tests can address a specific tile. Locked
        // tiles deliberately render no text to find them by (see below).
        key: ValueKey(item.id),
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
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: current
                      ? p.accent
                      : locked
                          ? kidsLockedFill(p)
                          : p.surface,
                  borderRadius: BorderRadius.circular(Geo.radiusLg),
                  boxShadow: locked
                      ? null
                      : [
                          BoxShadow(
                            color: current
                                ? p.accent.withValues(alpha: .28)
                                : p.shadow,
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                // A tile still ahead is a plain lock in the design — no
                // glyph, no name — so the stage reads as a sequence to
                // unlock rather than a wall of equal cards.
                child: locked
                    ? Center(
                        child: Icon(Icons.lock_rounded,
                            size: 22,
                            color: p.textDim.withValues(alpha: .75)),
                      )
                    // Scale-down guard around the WHOLE tile, not just the
                    // glyph: `quranicStyle` multiplies by the reader's
                    // arabicScale and the label rides the UI text scale, so
                    // either one can outgrow the cell. Scaling them together
                    // keeps the glyph and its name in proportion, where
                    // shrinking only the glyph would not.
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 42,
                                child: Center(
                                  child: item.glyph.isEmpty
                                      ? Icon(item.icon,
                                          size: 30,
                                          color: current
                                              ? Colors.white
                                              : p.accent2)
                                      : Text(
                                          item.glyph,
                                          textDirection: TextDirection.rtl,
                                          style: quranicStyle(
                                            context,
                                            size: 30,
                                            height: 1.05,
                                            color: current
                                                ? Colors.white
                                                : p.text,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kidsStyle(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color:
                                      current ? Colors.white : p.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            if (state == _State.done)
              PositionedDirectional(
                top: 7,
                end: 7,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: p.amber),
                  child: const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
