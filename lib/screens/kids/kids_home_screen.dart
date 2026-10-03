import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/kids_content.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_checkpoint_quiz.dart' show kidsWarmUpQuiz;
import 'kids_desktop_nav.dart';
import 'kids_avatar_face.dart';
import 'kids_build_word.dart';
import 'kids_find_in_ayah.dart';
import 'kids_game_bingo.dart';
import 'kids_game_memory_match.dart';
import 'kids_game_three_in_a_row.dart';
import 'kids_listen_and_pick.dart';
import 'kids_memorise.dart';
import 'kids_mouth_map.dart';
import 'kids_lookalike_quiz.dart';
import 'kids_write_from_memory.dart';
import 'kids_path.dart';
import 'kids_practice_screens.dart';
import 'kids_rank_data.dart';
import 'kids_widgets.dart';

/// How many nodes the **desktop** trail shows — a single row inside a
/// bordered card, so it stays a short stretch around where the child is now.
const _pathWindow = 6;

/// One row of the vertical trail: the design's 68 px node under a 6 px gap.
/// The current node is taller (84 px, with its "Start" tag above) and gets
/// [_trailCurrentRowHeight]. Load-bearing — the progress line is filled to
/// the current node's centre by these.
const _trailRowHeight = 74.0;
const _trailCurrentRowHeight = 126.0;

/// The current row at the ambient text size: the node (84), a 6 px gap and
/// the "Start" tag above it, whose line grows with the text scale — at the
/// largest system × kids text size 126 was 2 px short.
double _currentRowHeight(BuildContext context) {
  final tag = 1 + MediaQuery.textScalerOf(context).scale(15) * kbNormalHeight[kbFontUi]!;
  return (84 + 6 + tag + 2).ceilToDouble().clamp(_trailCurrentRowHeight, 400.0);
}

/// The Home tab, laid out to the Kids Mode design: greeting + streak pill,
/// a filled coral daily-goal card, a "keep going" resume card, the letter
/// trail, and the two practice shortcuts. On desktop this becomes a 2-column
/// layout with a right-hand rail (profile, family leaderboard, badges) —
/// see [_desktopBuild].
class KidsHomeScreen extends StatelessWidget {
  final VoidCallback onGoLearn;
  final VoidCallback? onGoRank;
  final VoidCallback? onGoRewards;
  const KidsHomeScreen(
      {super.key, required this.onGoLearn, this.onGoRank, this.onGoRewards});

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final profile = s.activeKidsProfile!;
    // The trail follows the stage the child is actually up to, not a flat
    // list of 28 letters — see kids_path.dart.
    final block = kidsPath(context)[kidsCurrentBlockIndex(context, prog)];
    final items = block.items(context);
    final doneCount = kidsCurrentItemIndex(prog, items);
    final allDone = doneCount >= items.length;
    final currentItem = items[allDone ? items.length - 1 : doneCount];

    final ui = kbUi(context);
    // The design's Home (kb_screens.dart `KbHomeScreen`): headings on the sky,
    // everything else on solid cards, the same order and gaps — with the app's
    // own greeting, daily goal and practice shortcuts in their places.
    return _MobileHome(
      items: items,
      doneCount: doneCount,
      unlocked: prog.unlockAll,
      above: [
      _Header(
          name: profile.name,
          streakDays: prog.streakDays,
          streakFreezes: prog.streakFreezes),
      _FreezeBanner(prog: prog),
      const SizedBox(height: 18),
      _DailyGoalCard(done: prog.todayActivityCount),
      _GentleStopBanner(done: prog.todayActivityCount),
      const SizedBox(height: 30),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsKeepGoing, ui: ui, fontSize: 25)),
      const SizedBox(height: 14),
      _ResumeCard(
        item: currentItem,
        fraction: items.isEmpty ? 0 : doneCount / items.length,
        allDone: allDone,
      ),
      const SizedBox(height: 30),
      _StageHeading(title: block.title(context), arabic: block.badge),
      const SizedBox(height: 14),
      ],
      below: [
      const SizedBox(height: 22),
      Center(child: KbPill(context.l10n.kidsSeeWholePath, ui: ui, onTap: onGoLearn)),
      const SizedBox(height: 28),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsPractice, ui: ui, fontSize: 25)),
      const SizedBox(height: 14),
      _WarmUpBanner(prog: prog),
      _PracticeRows(cards: _practiceCards(context, prog)),
      ],
    );
  }

  Widget _desktopBuild(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final profile = s.activeKidsProfile!;
    final block = kidsPath(context)[kidsCurrentBlockIndex(context, prog)];
    final items = block.items(context);
    final doneCount = kidsCurrentItemIndex(prog, items);
    final allDone = doneCount >= items.length;
    final currentItem = items[allDone ? items.length - 1 : doneCount];

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FreezeBanner(prog: prog),
        _DailyGoalCard(
          done: prog.todayActivityCount,
          onContinue: () => openKidsItem(context, currentItem),
        ),
        _GentleStopBanner(done: prog.todayActivityCount),
        const SizedBox(height: 30),
        _StageHeading(title: block.title(context), arabic: block.badge),
        const SizedBox(height: 14),
        Builder(builder: (context) {
          final ui = kbUi(context);
          return KbSurface(
            color: ui.surface,
            edge: ui.edge,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: _LetterTrail(
                items: items,
                doneCount: doneCount,
                unlocked: prog.unlockAll),
          );
        }),
        const SizedBox(height: 28),
        _StageHeading(
            title: context.l10n.kidsPractice,
            arabic: context.l10n.kidsPracticeArabic),
        const SizedBox(height: 14),
        _WarmUpBanner(prog: prog),
        _PracticeRows(cards: _practiceCards(context, prog)),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileRailCard(profile: profile, prog: prog),
        const SizedBox(height: 18),
        _RankRailCard(onViewAll: onGoRank),
        const SizedBox(height: 18),
        _BadgesRailCard(onViewAll: onGoRewards),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 900;
      return ListView(
        padding: const EdgeInsets.fromLTRB(44, 24, 44, 48),
        children: [
          if (narrow)
            Column(children: [
              left,
              const SizedBox(height: 28),
              right,
            ])
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 28),
                SizedBox(width: 300, child: right),
              ],
            ),
        ],
      );
    });
  }
}

/// "Marhaba 👋 / Hello, {name}!" with the streak pill opposite it: a subtitle
/// and a page heading on the sky, the streak as a solid pill (the gem
/// counter's shape).
class _Header extends StatelessWidget {
  final String name;
  final int streakDays;
  final int streakFreezes;
  const _Header(
      {required this.name,
      required this.streakDays,
      this.streakFreezes = 0});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KbSubtitle(context.l10n.kidsMarhaba, ui: ui, fontSize: 18),
              KbHeading(context.l10n.kidsHelloName(name), ui: ui, fontSize: 30),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            KbSurface(
              color: ui.surface,
              edge: ui.edge,
              elev: KbElev.edge4,
              radius: 999,
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                KbIcon('local_fire_department', size: 22, color: kbC(ui.accent)),
                const SizedBox(width: 4),
                Text(context.l10n.streakDaysCount(streakDays),
                    style: kbText(18, kbC(ui.ink))),
              ]),
            ),
            // A bought streak freeze is otherwise a silent mechanic — this
            // is the one place a family sees it is there at all, and how
            // many are left, before it is ever spent.
            if (streakFreezes > 0) ...[
              const SizedBox(height: 8),
              KbSubtitle(context.l10n.kidsFreezesCount(streakFreezes),
                  ui: ui, fontSize: 15),
            ],
          ],
        ),
      ],
    );
  }
}

/// A stage or section heading with its Arabic name opposite it. The Arabic
/// sits on a small tile, never on the sky — UI_SPEC §1.6: letters always sit
/// on a tile.
class _StageHeading extends StatelessWidget {
  final String title;
  final String arabic;
  const _StageHeading({required this.title, this.arabic = ''});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: KbHeading(title, ui: ui, fontSize: 25)),
        if (arabic.isNotEmpty) ...[
          const SizedBox(width: 12),
          KbSurface(
            color: ui.tile,
            edge: ui.edge,
            elev: KbElev.edge3,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(arabic,
                textDirection: TextDirection.rtl,
                style: kbText(22, kbC(ui.tileInk),
                    family: kbFontArabic, weight: FontWeight.w600, height: 1.6)),
          ),
        ],
      ],
    );
  }
}

/// A "Your streak was saved!" banner for a few seconds right after a streak
/// freeze is spent (see `ProgressStore.justUsedFreeze`) — otherwise a freeze
/// is a fully silent mechanic: the only visible effect is the streak NOT
/// resetting, which looks identical to nothing having gone wrong, giving the
/// child no way to connect that to the gems they spent on it.
///
/// `didUpdateWidget` runs on every rebuild [KidsHomeScreen] gets from its
/// `ProgressScope` dependency — a fresh `widget` instance each time,
/// regardless of whether any field actually changed — so checking
/// `justUsedFreeze` there catches it whenever it becomes true while this
/// stays mounted; `initState` catches the case where it was already true the
/// moment Home first builds (opening the app itself is what triggered it).
class _FreezeBanner extends StatefulWidget {
  final ProgressStore prog;
  const _FreezeBanner({required this.prog});

  @override
  State<_FreezeBanner> createState() => _FreezeBannerState();
}

class _FreezeBannerState extends State<_FreezeBanner> {
  bool _show = false;

  /// This freeze was the one that earned the Ice Cube avatar.
  bool _iceCube = false;

  @override
  void initState() {
    super.initState();
    if (widget.prog.justUsedFreeze) {
      _show = true;
      _iceCube = widget.prog.justUnlockedIceCube;
      widget.prog.acknowledgeFreezeUsed();
      _scheduleHide();
    }
  }

  @override
  void didUpdateWidget(_FreezeBanner old) {
    super.didUpdateWidget(old);
    if (widget.prog.justUsedFreeze) {
      final ice = widget.prog.justUnlockedIceCube;
      widget.prog.acknowledgeFreezeUsed();
      setState(() {
        _show = true;
        _iceCube = ice;
      });
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    // Longer when there is a reward to read about too.
    Future.delayed(Duration(seconds: _iceCube ? 6 : 4), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final ui = kbUi(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: KbSurface(
          color: ui.surface,
          edge: ui.edge,
          elev: KbElev.edge4,
          radius: 999,
          padding: const EdgeInsets.fromLTRB(14, 7, 18, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _iceCube
                ? const KidsAvatarFace('avatar:icecube', size: 22)
                : const Text('🧊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.kidsStreakSaved,
                      style: kbText(17, kbC(ui.ink))),
                  if (_iceCube)
                    Text(context.l10n.kidsIceCubeUnlocked,
                        style: kbText(15, kbC(ui.linkInk))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The daily goal: a solid card with the goal ring — accent on the track, the
/// kit's progress colours. On desktop the design adds an explicit "Continue"
/// button; mobile keeps the separate [_ResumeCard] below it for that action.
class _DailyGoalCard extends StatelessWidget {
  final int done;
  final VoidCallback? onContinue;
  const _DailyGoalCard({required this.done, this.onContinue});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final capped = done.clamp(0, kidsDailyGoal);
    final left = kidsDailyGoal - capped;
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      elev: KbElev.card,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        KidsGoalRing(
          fraction: done / kidsDailyGoal,
          size: 68,
          strokeWidth: 7,
          color: kbC(ui.accent),
          trackColor: kbC(ui.track),
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$capped', style: kbText(22, kbC(ui.ink), height: 1)),
            Text('/$kidsDailyGoal',
                style: kbText(13, kbC(ui.inkSoft),
                    weight: FontWeight.w700, height: 1)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.kidsDailyGoalTitle,
                  style: kbText(21, kbC(ui.ink), height: 1.1)),
              const SizedBox(height: 4),
              Text(
                  left == 0
                      ? context.l10n.kidsGoalComplete
                      : context.l10n.kidsGoalRemaining(left),
                  style: kbText(16, kbC(ui.inkSoft),
                      weight: FontWeight.w600, height: 1.35)),
            ],
          ),
        ),
        if (onContinue != null) ...[
          const SizedBox(width: 14),
          KbPill(context.l10n.continueLabel,
              ui: ui, kind: KbPillKind.deep, onTap: onContinue),
        ],
      ]),
    );
  }
}

/// Shown once today's goal is met: a calm, non-blocking suggestion that this
/// is a fine place to stop — everything below stays fully open, nothing is
/// locked, and there is no streak-anxiety framing. The direct answer to the
/// "hard to put down without crying" complaint the v4 research turned up:
/// where other apps use the goal as a launchpad into "just one more", this
/// one uses it to say "you're done, and that's good".
class _GentleStopBanner extends StatelessWidget {
  final int done;
  const _GentleStopBanner({required this.done});

  @override
  Widget build(BuildContext context) {
    if (done < kidsDailyGoal) return const SizedBox.shrink();
    final ui = kbUi(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KbSurface(
        color: ui.surface,
        edge: ui.edge,
        elev: KbElev.card,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(children: [
          const Text('🌙', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.kidsGentleStopTitle,
                    style: kbText(18, kbC(ui.ink), height: 1.15)),
                Text(context.l10n.kidsGentleStopSub,
                    style: kbText(15, kbC(ui.inkSoft),
                        weight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// The "keep going" resume card — the design's Home "Next" card: the item in a
/// glyph tile, its name, the path progress bar and the accent go button.
/// Mobile-only — the desktop layout folds this action into the goal card's
/// "Continue" button.
class _ResumeCard extends StatelessWidget {
  final KidsItem item;
  final double fraction;
  final bool allDone;
  const _ResumeCard(
      {required this.item, required this.fraction, required this.allDone});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return KbNextCard(
      ui: kbUi(context),
      glyph: item.glyph,
      icon: item.glyph.isEmpty ? kbIconName(item.icon) : null,
      // Stage-neutral: a stage's items are letters, quizzes, lesson pages or
      // a reading, so "Letter Test" and "You finished the alphabet!" were
      // both wrong here.
      title: allDone
          ? context.l10n.kidsStageDone
          : context.l10n.kidsNextUp(item.label(context)),
      progress: fraction,
      goIcon: rtl ? 'arrow_back' : 'arrow_forward',
      onGo: () => openKidsItem(context, item),
    );
  }
}

/// [open] is a node the testing unlock ([kidsLocked]) has made reachable
/// without it having been cleared — never a padlock, never a checkmark.
enum _LetterState { done, open, current, locked }

/// The desktop letter trail — a single row of nodes along a dashed spine,
/// matching the desktop design's bordered card. (On a phone the trail is part
/// of [_MobileHome]'s scroll.)
class _LetterTrail extends StatelessWidget {
  final List<KidsItem> items;
  final int doneCount;

  /// [ProgressStore.unlockAll] — passed down rather than looked up here so
  /// the two trail layouts and the Learn tab all read the same answer.
  final bool unlocked;
  const _LetterTrail(
      {required this.items,
      required this.doneCount,
      required this.unlocked});

  _LetterState _stateAt(int i) => i < doneCount
      ? _LetterState.done
      : i == doneCount
          ? _LetterState.current
          : unlocked
              ? _LetterState.open
              : _LetterState.locked;

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final currentRow = _currentRowHeight(context);

      // Desktop keeps a fixed window: the trail is one row inside a card, and
      // the whole stage sits beside it on the Learn tab anyway. Start a step
      // behind where the child is, so a cleared node stays in view, and never
      // run past the end of the stage.
      final start = (doneCount - 1)
          .clamp(0, (items.length - _pathWindow).clamp(0, items.length));
      final end = (start + _pathWindow).clamp(0, items.length);
      // The design's nodes at their own size, spread across the card — and
      // the whole row scaled down, rather than overflowing, in a card too
      // narrow for them.
      final natural = (end - start) * (68.0 + 12) + 16;
      return LayoutBuilder(builder: (context, c) {
        final row = SizedBox(
        width: c.maxWidth < natural ? natural : c.maxWidth,
        height: currentRow,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 30,
              right: 30,
              bottom: 34 - 2.5,
              height: 5,
              child: LayoutBuilder(builder: (context, lc) {
                // Nodes are spread evenly (spaceBetween), so node k's centre
                // sits k/(n-1) of the way along — the line spans them, less
                // the 30 px insets either side.
                final n = end - start;
                final k = (doneCount - start).clamp(0, n - 1);
                final fill = doneCount <= start
                    ? 0.0
                    : doneCount >= end
                        ? lc.maxWidth
                        : n <= 1
                            ? 0.0
                            // A 68 px node's centre is 34 in from the row's
                            // end, 4 in from the line's (inset 30).
                            : 4 + k * (lc.maxWidth - 8) / (n - 1);
                return CustomPaint(
                    painter: _TrailLinePainter(ui.pathLine, Axis.horizontal,
                        // The nodes run in reading order, so in Arabic and
                        // Urdu the cleared stretch starts at the right.
                        direction: Directionality.of(context),
                        fill: fill, fillColor: kbC(ui.reward),
                        edgeColor: kbC(ui.rewardEdge)));
              }),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = start; i < end; i++)
                  _TrailNode(item: items[i], state: _stateAt(i)),
              ],
            ),
          ],
        ),
        );
        return c.maxWidth < natural
            ? FittedBox(fit: BoxFit.scaleDown, child: row)
            : row;
      });
  }
}

/// Home on a phone: one scroll — the page's own — with the whole stage's trail
/// in the middle of it.
///
/// The trail's rows are built lazily (a sliver list; the cards above and below
/// it are built whole): only the rows on screen,
/// and about half a screen either side, exist at any moment. They are built in
/// the frame they come near the screen, before they show, so nothing ever
/// looks like it is loading — but a long stage (Joining Shapes is 79 nodes) no
/// longer costs 79 nodes every time Home rebuilds or lays out.
///
/// The line down the middle is painted as one piece behind the list, following
/// the scroll, rather than a slice per row: the slices of a translucent line
/// would show faint seams where the rows meet on a high-density screen.
class _MobileHome extends StatefulWidget {
  final List<KidsItem> items;
  final int doneCount;
  final bool unlocked;
  final List<Widget> above;
  final List<Widget> below;
  const _MobileHome({
    required this.items,
    required this.doneCount,
    required this.unlocked,
    required this.above,
    required this.below,
  });

  @override
  State<_MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<_MobileHome> {
  final _c = ScrollController();

  /// On the trail's sliver: where the trail starts in the scroll comes from it.
  final _trailKey = GlobalKey();

  /// KbPage's top and bottom padding and side gutter, matched here.
  static const _top = 58.0, _bottom = 130.0, _gutter = 20.0;

  /// The trail's own side padding: the design's nodes sit 34 px in.
  static const _inset = 34.0;

  /// The line runs from 30 px into the first row to 30 px short of the end.
  static const _lineInset = 30.0;

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(_MobileHome old) {
    super.didUpdateWidget(old);
    // Finishing a lesson moves the current node on — follow it if it has
    // gone off screen. After this frame: this runs inside a build.
    if (old.doneCount != widget.doneCount) _reveal(animate: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  _LetterState _stateAt(int i) => i < widget.doneCount
      ? _LetterState.done
      : i == widget.doneCount
          ? _LetterState.current
          : widget.unlocked
              ? _LetterState.open
              : _LetterState.locked;

  /// Where the trail starts in the page's scroll, once laid out.
  double? _trailStart() {
    final r = _trailKey.currentContext?.findRenderObject();
    return r is RenderSliver && r.attached
        ? r.constraints.precedingScrollExtent
        : null;
  }

  /// Keeps the node the child is up to in view — when Home first opens, and
  /// when a finished lesson moves it on — but only when it is not already on
  /// screen, so a child reading the top of Home is not pulled away for nothing.
  /// Worked out from the row heights: the node itself may not be built yet.
  void _reveal({required bool animate}) {
    final current = widget.doneCount;
    if (current >= widget.items.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_c.hasClients) return;
      final start = _trailStart();
      final pos = _c.position;
      if (start == null || !pos.hasContentDimensions) return;
      final top = start + current * _trailRowHeight;
      final bottom = top + _currentRowHeight(context);
      // The nav bar floats over the page's foot.
      final shown = pos.viewportDimension - MediaQuery.paddingOf(context).bottom;
      if (top >= pos.pixels && bottom <= pos.pixels + shown) return;
      final to = ((top + bottom) / 2 - pos.viewportDimension * .45)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (animate && !kidsReduceMotion(context)) {
        pos.animateTo(to,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic);
      } else {
        pos.jumpTo(to);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final items = widget.items, done = widget.doneCount;
    final currentRow = _currentRowHeight(context);
    double rowHeight(int i) => i == done ? currentRow : _trailRowHeight;
    final total = items.length * _trailRowHeight +
        (done < items.length ? currentRow - _trailRowHeight : 0);
    // Filled to the current node's centre (it sits at the foot of its row);
    // to the end once the stage is finished.
    final fillTo = done <= 0
        ? 0.0
        : done >= items.length
            ? double.infinity
            : done * _trailRowHeight + currentRow - 42 - _lineInset;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ScrollingTrailLine(
                scroll: _c,
                trailStart: _trailStart,
                length: total - 2 * _lineInset,
                inset: _lineInset,
                line: _TrailLinePainter(ui.pathLine, Axis.vertical,
                    fill: fillTo,
                    fillColor: kbC(ui.reward),
                    edgeColor: kbC(ui.rewardEdge)),
              ),
            ),
          ),
        ),
      ),
      CustomScrollView(
        controller: _c,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                _gutter, _top > safeTop + 8 ? _top : safeTop + 8, _gutter, 0),
            // Built whole, not lazily: these hold state (the streak banner)
            // that must survive being scrolled away from, and their exact
            // height keeps the page's length — and so the parallax — exact.
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.above,
              ),
            ),
          ),
          SliverPadding(
            key: _trailKey,
            padding: const EdgeInsets.symmetric(horizontal: _gutter + _inset),
            sliver: SliverVariedExtentList.builder(
              itemCount: items.length,
              itemExtentBuilder: (i, _) => rowHeight(i),
              itemBuilder: (context, i) => Align(
                // The design's zig-zag (kb_components.dart `KbLessonPath`).
                alignment: i.isEven
                    ? AlignmentDirectional.bottomStart
                    : AlignmentDirectional.bottomEnd,
                child: _TrailNode(item: items[i], state: _stateAt(i)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, _bottom),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.below,
              ),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// The trail's line, painted behind the page's scroll view at wherever the
/// trail has scrolled to: the [line] painter, drawn [length] long, its top
/// [inset] below the trail's start. Repaints as the page scrolls — only these
/// few strokes, in their own layer.
class _ScrollingTrailLine extends CustomPainter {
  final ScrollController scroll;
  final double? Function() trailStart;
  final double length;
  final double inset;
  final _TrailLinePainter line;
  _ScrollingTrailLine({
    required this.scroll,
    required this.trailStart,
    required this.length,
    required this.inset,
    required this.line,
  }) : super(repaint: scroll);

  /// The fill, for tests: px from the line's top.
  double get fill => line.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final start = trailStart();
    if (start == null || !scroll.hasClients || length <= 0) return;
    final y = start + inset - scroll.offset;
    // Nothing of it on screen: skip.
    if (y > size.height || y + length < 0) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2 - 2.5, y);
    line.paint(canvas, Size(5, length));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrollingTrailLine o) =>
      o.length != length ||
      o.inset != inset ||
      o.scroll != scroll ||
      line.shouldRepaint(o.line);
}

/// One trail circle — the design's path node (kb_components.dart
/// `KbPathNode`): done (reward face, check badge), current (bigger, accent
/// ring, "Start" tag), locked (lock badge) or open (plain, no badge). Shared
/// by both the vertical (mobile) and horizontal (desktop) trail layouts.
class _TrailNode extends StatelessWidget {
  final KidsItem item;
  final _LetterState state;
  const _TrailNode({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final locked = state == _LetterState.locked;
    final current = state == _LetterState.current;
    final name = item.label(context);

    return Semantics(
      // Keyed by the item's progress id, the same convention the Learn grid
      // uses, so a node can be addressed however far down the stage it sits.
      key: ValueKey('kids.trail.${item.id}'),
      label: name,
      button: true,
      // The letter the child is on breathes, so the eye lands on where to go
      // next without needing to read anything.
      child: _MaybePulse(
        enabled: current,
        child: KbPathNode(
          ui: kbUi(context),
          letter: item.glyph,
          icon: item.glyph.isEmpty ? kbIconName(item.icon) : null,
          startLabel: context.l10n.kidsPathStart,
          state: switch (state) {
            _LetterState.done => KbNodeState.done,
            _LetterState.current => KbNodeState.current,
            _LetterState.open => KbNodeState.open,
            _LetterState.locked => KbNodeState.locked,
          },
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
        ),
      ),
    );
  }
}

/// Wraps [child] in a slow scale breath when [enabled]. A no-op otherwise —
/// including whenever the viewer has reduce-motion on, which also keeps the
/// widget tests' `pumpAndSettle()` from waiting on a controller that never
/// stops (see [kidsReduceMotion]).
class _MaybePulse extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const _MaybePulse({required this.enabled, required this.child});

  @override
  State<_MaybePulse> createState() => _MaybePulseState();
}

class _MaybePulseState extends State<_MaybePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  bool get _running => widget.enabled && !kidsReduceMotion(context);

  void _sync() {
    if (_running) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_MaybePulse old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_running) return widget.child;
    // Its own layer: without this boundary every frame of the breath marked the
    // whole Home page for repaint — every node, card and shadow re-recorded 60
    // times a second, which is what made High jank on a slow phone.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: 1 + .08 * Curves.easeInOut.transform(_c.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// The line the trail nodes hang off: the design's 5 px dashes, 15 on and 10
/// off, in the palette's path colour — and, up to [fill] (px along the line),
/// a solid bar in the done nodes' own reward colour with their darker edge
/// under it, so the stretch already cleared reads as a path laid down.
class _TrailLinePainter extends CustomPainter {
  final Color color;
  final Axis axis;
  final double fill;
  final Color? fillColor;
  final Color? edgeColor;

  /// Which end a horizontal line fills from; a vertical one fills downwards.
  final TextDirection direction;
  _TrailLinePainter(this.color, this.axis,
      {this.fill = 0,
      this.fillColor,
      this.edgeColor,
      this.direction = TextDirection.ltr});

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = axis == Axis.vertical;
    final length = vertical ? size.height : size.width;
    final solid = fill.clamp(0.0, length);
    final flip = !vertical && direction == TextDirection.rtl;
    Offset at(double t) => vertical
        ? Offset(size.width / 2, t)
        : Offset(flip ? size.width - t : t, size.height / 2);

    final dash = Paint()
      ..color = color
      ..strokeWidth = 5;
    // Dashes only where the bar is not; start on the dash grid so they don't
    // shift as the bar grows.
    for (var t = 0.0; t < length; t += 25) {
      final a = t, b = (t + 15).clamp(0.0, length);
      if (b <= solid) continue;
      canvas.drawLine(at(a < solid ? solid : a), at(b), dash);
    }
    if (solid <= 0 || fillColor == null) return;
    final cap = Paint()..strokeCap = StrokeCap.round;
    // Cased in the dashes' own colour, so the bar reads on every sky — a gold
    // core alone all but vanishes on the warm themes.
    canvas.drawLine(at(0), at(solid), cap..color = color..strokeWidth = 14);
    // The 3D edge: a darker copy of the bar, 3 px lower (UI_SPEC §1).
    if (edgeColor != null) {
      canvas.drawLine(at(0) + const Offset(0, 3), at(solid) + const Offset(0, 3),
          cap..color = edgeColor!..strokeWidth = 8);
    }
    canvas.drawLine(at(0), at(solid), cap..color = fillColor!..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_TrailLinePainter old) =>
      old.color != color ||
      old.axis != axis ||
      old.fill != fill ||
      old.fillColor != fillColor ||
      old.edgeColor != edgeColor ||
      old.direction != direction;
}

/// The Warm-up entry: a full-width banner above the practice shortcuts,
/// present ONLY while something is due for review — never a dead end, and
/// never a path stage (a stage nobody can finish would pin Home on it
/// forever; see `kidsCurrentBlockIndex`).
class _WarmUpBanner extends StatelessWidget {
  final ProgressStore prog;
  const _WarmUpBanner({required this.prog});

  @override
  Widget build(BuildContext context) {
    final due = prog.dueCount;
    if (due == 0) return const SizedBox.shrink();
    // The design's Practice card: the one deep card on Home, the one thing on
    // it that is trying to get tapped.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: KbDeepCard(
        ui: kbUi(context),
        icon: 'wb_twilight',
        title: context.l10n.kidsWarmUp,
        subtitle: context.l10n.kidsWarmUpSub(due),
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsWarmUp,
            builder: (c) => kidsWarmUpQuiz(c, ProgressScope.of(c))),
      ),
    );
  }
}

/// The practice shortcuts under the trail. Flashcards and Listening are
/// always there; Look-alikes joins them once the child has met at least one
/// pair of letters that can be confused (a drill with nothing to contrast
/// would be an empty round), and Write it / Find it once they know a letter.
/// Never a path stage — practice must not gate progress.
List<Widget> _practiceCards(BuildContext context, ProgressStore prog) {
  final known = kidsLearnedLetters(prog);
  final cards = <Widget>[
    _PracticeCard(
      icon: Icons.style_rounded,
      label: context.l10n.kidsFlashcards,
      onTap: () => pushKidsOverlay(context,
          title: context.l10n.kidsFlashcards,
          builder: (_) => const KidsFlashcardsScreen()),
    ),
    _PracticeCard(
      icon: Icons.headphones_rounded,
      label: context.l10n.kidsListening,
      onTap: () => pushKidsOverlay(context,
          title: context.l10n.kidsListening,
          builder: (_) => const KidsListeningScreen()),
    ),
    if (kidsLookalikeAvailable(known))
      _PracticeCard(
        icon: Icons.compare_rounded,
        label: context.l10n.kidsLookalikes,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsLookalikes,
            builder: (c) => kidsLookalikeQuiz(c,
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.lookalikes')),
      ),
    if (known.isNotEmpty)
      _PracticeCard(
        icon: Icons.draw_rounded,
        label: context.l10n.kidsWriteIt,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsWriteIt,
            builder: (c) => KidsWriteFromMemory.forKnown(
                kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.write')),
      ),
    if (known.isNotEmpty)
      _PracticeCard(
        icon: Icons.search_rounded,
        label: context.l10n.kidsFindIt,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsFindIt,
            builder: (c) => KidsFindInAyah(
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.find')),
      ),
    // Words are only buildable from letters already met, and the short sūrahs
    // hold few words made of a small alphabet — so this waits for most of it.
    if (known.length >= 20)
      _PracticeCard(
        icon: Icons.extension_rounded,
        label: context.l10n.kidsBuildWord,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsBuildWord,
            builder: (c) => KidsBuildWord(
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.build')),
      ),
    // A sūrah to learn by heart, in three short sittings — the next one not
    // yet done, then the revision. It works by ear and by eye, so it does not
    // wait on the letters.
    if (known.isNotEmpty)
      _PracticeCard(
        icon: Icons.psychology_alt_rounded,
        label: context.l10n.kidsMemorise,
        onTap: () {
          final n = kidsMemoriseNextSession(ProgressScope.of(context));
          pushKidsOverlay(context,
              title: context.l10n.kidsMemorise,
              builder: (c) => KidsMemoriseLesson(
                  session: n, progressId: 'kids.memorise.$n'));
        },
      ),
    // Where each sound is made needs no recording, but is only worth asking
    // about letters a child has met.
    if (known.length >= 6)
      _PracticeCard(
        icon: Icons.face_retouching_natural_rounded,
        label: context.l10n.kidsMouthMap,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsMouthMap,
            builder: (c) => KidsMouthMapLesson(
                known: {
                  for (final l in kidsLearnedLetters(ProgressScope.of(c)))
                    l.char
                },
                progressId: 'kids.practice.mouth')),
      ),
    // Words are picked out by hearing them, which is only fair once a child
    // has met enough letters to read a few of the choices.
    if (known.length >= 10)
      _PracticeCard(
        icon: Icons.hearing_rounded,
        label: context.l10n.kidsListenPick,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsListenPick,
            builder: (c) => KidsListenAndPick(
                known: {
                  for (final l in kidsLearnedLetters(ProgressScope.of(c)))
                    l.char
                },
                progressId: 'kids.practice.listen')),
      ),
    // Three games, sharing the same board engine — real retrieval practice
    // with an actual game on top, never a path stage (a lost or drawn game
    // must never gate a stage the way a missed lesson step never does
    // either). Each gate mirrors the one lesson-shape gate above it: enough
    // known letters for the letters themselves to make a fair board.
    if (known.length >= 6)
      _PracticeCard(
        icon: Icons.grid_3x3_rounded,
        label: context.l10n.kidsGameThreeInARow,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsGameThreeInARow,
            builder: (c) => KidsThreeInARow(
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.three_in_a_row')),
      ),
    if (known.length >= 6)
      _PracticeCard(
        icon: Icons.grid_view_rounded,
        label: context.l10n.kidsGameMemoryMatch,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsGameMemoryMatch,
            builder: (c) => KidsMemoryMatch(
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.memory_match')),
      ),
    if (known.length >= 10)
      _PracticeCard(
        icon: Icons.casino_rounded,
        label: context.l10n.kidsGameBingo,
        onTap: () => pushKidsOverlay(context,
            title: context.l10n.kidsGameBingo,
            builder: (c) => KidsGameBingo(
                known: kidsLearnedLetters(ProgressScope.of(c)),
                progressId: 'kids.practice.bingo')),
      ),
  ];
  return cards;
}

/// [cards] in rows of three — four across is too narrow for a phone — with
/// the last row padded so every card keeps the same width, and every card in
/// a row the same height.
class _PracticeRows extends StatelessWidget {
  final List<Widget> cards;
  const _PracticeRows({required this.cards});

  @override
  Widget build(BuildContext context) {
    const perRow = 3;
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += perRow) {
      final chunk = cards.skip(i).take(perRow).toList();
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < perRow; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(child: j < chunk.length ? chunk[j] : const SizedBox()),
            ],
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// One practice shortcut: a tile (UI_SPEC §1 — solid face, hard edge) with
/// its symbol in a glyph tile and the name under it.
class _PracticeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PracticeCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      elev: KbElev.tile,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
      onTap: onTap,
      child: Column(children: [
        KbGlyphTile(kbIconName(icon),
            icon: true,
            size: 50,
            radius: 16,
            fontSize: 28,
            bg: ui.tile,
            ink: ui.tileInk),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: kbText(16, kbC(ui.ink), height: 1.15)),
      ]),
    );
  }
}

/// Right-rail card #1 (desktop only): avatar, name, level, and a small
/// XP/streak stat pair — the design's mini profile summary.
class _ProfileRailCard extends StatelessWidget {
  final KidsProfile profile;
  final ProgressStore prog;
  const _ProfileRailCard({required this.profile, required this.prog});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        KbAvatar(
          size: 72,
          background: kbC(ui.tile),
          face: (d) => KidsAvatar(profile: profile, size: d / 1.15),
        ),
        const SizedBox(height: 10),
        Text(profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kbText(21, kbC(ui.ink), height: 1.1)),
        Text(context.l10n.kidsLevelLabel(prog.level),
            style: kbText(15, kbC(ui.inkSoft), weight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _MiniStat(
                  value: '${prog.xp}', label: context.l10n.kidsStatXp)),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
                value: context.l10n.streakDaysCount(prog.streakDays),
                label: context.l10n.kidsStatStreak),
          ),
        ]),
      ]),
    );
  }
}

/// A stat inside a card: flat on the tile colour, since the card is already
/// the raised thing.
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      decoration: BoxDecoration(
          color: kbC(ui.tile), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kbText(20, kbC(ui.tileInk), height: 1.1)),
        Text(label,
            style: kbText(14, kbC(ui.tileInk), weight: FontWeight.w600)),
      ]),
    );
  }
}

/// A rail card's title row with its "View all" link — secondary text on a
/// surface, so link ink.
class _RailTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  const _RailTitle({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Row(children: [
      Expanded(child: Text(title, style: kbText(20, kbC(ui.ink)))),
      if (onViewAll != null)
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: onViewAll,
            child: Text(context.l10n.kidsViewAll,
                style: kbText(16, kbC(ui.linkInk))),
          ),
        ),
    ]);
  }
}

/// Right-rail card #2 (desktop only): the top 3 of the household leaderboard,
/// with a "View all" link to the Rank tab.
class _RankRailCard extends StatefulWidget {
  final VoidCallback? onViewAll;
  const _RankRailCard({this.onViewAll});
  @override
  State<_RankRailCard> createState() => _RankRailCardState();
}

class _RankRailCardState extends State<_RankRailCard> {
  List<KidsRankRow>? _rows;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      loadKidsRanking(context).then((rows) {
        if (mounted) setState(() => _rows = rows);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final rows = _rows?.take(3).toList() ?? const <KidsRankRow>[];
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailTitle(
              title: context.l10n.kidsRankBannerTitle,
              onViewAll: widget.onViewAll),
          if (rows.length > 1) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 18,
                    child: Text('${i + 1}',
                        style: kbText(17, kbC(ui.inkSoft))),
                  ),
                  const SizedBox(width: 6),
                  KbAvatar(
                    size: 34,
                    background: kbC(ui.tile),
                    face: (d) =>
                        KidsAvatar(profile: rows[i].profile, size: d / 1.15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(rows[i].profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kbText(17, kbC(ui.ink))),
                  ),
                  Text('${rows[i].xp} XP',
                      style: kbText(15, kbC(ui.inkSoft))),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

/// Right-rail card #3 (desktop only): a small preview of earned badges, with
/// a "View all" link to the Rewards tab.
class _BadgesRailCard extends StatelessWidget {
  final VoidCallback? onViewAll;
  const _BadgesRailCard({this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final ui = kbUi(context);
    final earned =
        kidsBadgeDefs().where((b) => b.earned(prog)).take(3).toList();
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailTitle(title: context.l10n.kidsBadges, onViewAll: onViewAll),
          const SizedBox(height: 10),
          if (earned.isEmpty)
            Text('—', style: kbText(17, kbC(ui.inkSoft)))
          else
            Row(children: [
              for (final b in earned)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    // An earned badge wears the reward colour (UI_SPEC §2).
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: kbC(ui.reward)),
                    child: Text(b.emoji, style: const TextStyle(fontSize: 19)),
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}
