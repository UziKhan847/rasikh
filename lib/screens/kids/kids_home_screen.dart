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
import 'kids_checkpoint_quiz.dart' show kidsWarmUpQuiz;
import 'kids_desktop_nav.dart';
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

/// The mobile trail scrolls instead: it holds the whole stage, in a window
/// this many nodes tall.
const _trailVisibleRows = 5;

/// One row of the vertical trail: the design's 68 px node under a 6 px gap.
/// The current node is taller (84 px, with its "Start" tag above) and gets
/// [_trailCurrentRowHeight]. Load-bearing — [_ScrollingTrail] scrolls by these
/// to bring the current node into view.
const _trailRowHeight = 74.0;
const _trailCurrentRowHeight = 126.0;

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
    return KbPage(cross: CrossAxisAlignment.stretch, children: [
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
      _LetterTrail(
          items: items,
          doneCount: doneCount,
          axis: Axis.vertical,
          unlocked: prog.unlockAll),
      const SizedBox(height: 22),
      Center(child: KbPill(context.l10n.kidsSeeWholePath, ui: ui, onTap: onGoLearn)),
      const SizedBox(height: 28),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: KbHeading(context.l10n.kidsPractice, ui: ui, fontSize: 25)),
      const SizedBox(height: 14),
      _WarmUpBanner(prog: prog),
      _PracticeRows(cards: _practiceCards(context, prog)),
    ]);
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
                axis: Axis.horizontal,
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

  @override
  void initState() {
    super.initState();
    if (widget.prog.justUsedFreeze) {
      _show = true;
      widget.prog.acknowledgeFreezeUsed();
      _scheduleHide();
    }
  }

  @override
  void didUpdateWidget(_FreezeBanner old) {
    super.didUpdateWidget(old);
    if (widget.prog.justUsedFreeze) {
      widget.prog.acknowledgeFreezeUsed();
      setState(() => _show = true);
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    Future.delayed(const Duration(seconds: 4), () {
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
            const Text('🧊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(context.l10n.kidsStreakSaved,
                  style: kbText(17, kbC(ui.ink))),
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

/// The letter trail — nodes threaded along a dashed spine, the design's
/// centrepiece for the Home screen. Vertical (a zig-zag either side of the
/// spine) on mobile; horizontal (a single row, matching the desktop design's
/// bordered card) on desktop — see [axis].
class _LetterTrail extends StatelessWidget {
  final List<KidsItem> items;
  final int doneCount;
  final Axis axis;

  /// [ProgressStore.unlockAll] — passed down rather than looked up here so
  /// the two trail layouts and the Learn tab all read the same answer.
  final bool unlocked;
  const _LetterTrail(
      {required this.items,
      required this.doneCount,
      required this.axis,
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

    if (axis == Axis.horizontal) {
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
        height: _trailCurrentRowHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 30,
              right: 30,
              bottom: 34 - 2.5,
              height: 5,
              child: CustomPaint(
                  painter: _TrailLinePainter(ui.pathLine, Axis.horizontal)),
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

    // Mobile holds the *whole* stage and scrolls within itself. The design's
    // zig-zag (kb_components.dart `KbLessonPath`): nodes alternate sides
    // inside 34 px of padding, over a dashed line down the middle.
    return _ScrollingTrail(
      length: items.length,
      current: doneCount,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Stack(
          children: [
            Positioned.fill(
              top: 30,
              bottom: 30,
              child: CustomPaint(
                painter: _TrailLinePainter(ui.pathLine, Axis.vertical),
              ),
            ),
            Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    height: i == doneCount
                        ? _trailCurrentRowHeight
                        : _trailRowHeight,
                    child: Align(
                      alignment: i.isEven
                          ? AlignmentDirectional.bottomStart
                          : AlignmentDirectional.bottomEnd,
                      child: _TrailNode(item: items[i], state: _stateAt(i)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The mobile trail's own scroll area: a few nodes tall, opened on the one
/// the child is up to, and holding the whole stage behind and ahead of it.
///
/// It used to be a fixed six-node slice of the stage with no way to move it,
/// so the moment a letter was two steps behind it left the Home screen for
/// good — a child who had just finished bāʾ could no longer see the alif they
/// cleared yesterday. Scrolling inside a fixed height rather than growing the
/// Home list is deliberate: a stage is 28 letters, which inline would be some
/// four screens of trail with the practice shortcuts stranded underneath.
class _ScrollingTrail extends StatefulWidget {
  final int length;

  /// Index of the current node — the trail opens with this one near the top.
  final int current;
  final Widget child;
  const _ScrollingTrail(
      {required this.length, required this.current, required this.child});

  @override
  State<_ScrollingTrail> createState() => _ScrollingTrailState();
}

class _ScrollingTrailState extends State<_ScrollingTrail> {
  late final ScrollController _c =
      ScrollController(initialScrollOffset: _offsetFor(widget.current));

  /// Every row is [_trailRowHeight] except the current one's.
  bool get _hasCurrent => widget.current < widget.length;

  double get _contentHeight =>
      widget.length * _trailRowHeight +
      (_hasCurrent ? _trailCurrentRowHeight - _trailRowHeight : 0);

  double get _height => _scrolls
      ? (_trailVisibleRows - 1) * _trailRowHeight + _trailCurrentRowHeight
      : _contentHeight;

  bool get _scrolls => widget.length > _trailVisibleRows;

  /// Puts node [i] one row down from the top, so the step just cleared is
  /// still visible above it.
  double _offsetFor(int i) {
    final max = (_contentHeight - _height).clamp(0.0, 1e6);
    // Rows above the current one are all the standard height.
    return ((i - 1) * _trailRowHeight).clamp(0.0, max);
  }

  @override
  void didUpdateWidget(_ScrollingTrail old) {
    super.didUpdateWidget(old);
    // Coming back from a finished lesson advances the current node; follow it
    // rather than leaving the child looking at where they used to be.
    if (old.current == widget.current) return;

    // AFTER this frame, never during it. didUpdateWidget runs inside the
    // parent's build, and driving a scroll position from there notifies its
    // listeners synchronously — a scroll notification and the position's own
    // listeners — which can mark other elements dirty mid-build. Finishing a
    // lesson arrives exactly that way: ProgressStore notifies, Home rebuilds,
    // and this widget's `current` moves on. Deferring costs a frame and
    // removes the whole class of hazard.
    final target = _offsetFor(widget.current);
    final reduced = kidsReduceMotion(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_c.hasClients) return;
      if (reduced) {
        _c.jumpTo(target);
      } else {
        _c.animateTo(target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The trail itself fades out over the last 22 px at a cut edge, so it reads
  /// as a window on to something longer instead of a list that stops there.
  /// A mask, not a wash of colour: the scene shows through it.
  ///
  /// One mask, always there, whose gradient changes — never a mask that comes
  /// and goes around the scroll view, which would move the scroll view in the
  /// tree, rebuild its scroll position and cancel a drag in progress.
  static Shader _mask(Rect r, {required bool top, required bool bottom}) {
    final edge = (22 / r.height).clamp(0.0, .5);
    final clear = kbC(kWhite, 0), solid = kbC(kWhite);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0, edge, 1 - edge, 1],
      colors: [top ? clear : solid, solid, solid, bottom ? clear : solid],
    ).createShader(r);
  }

  /// The band a fade covers. Keyed so a test can tell it apart from the true
  /// edge of the stage — see the caller: it must only appear on a side that
  /// actually hides content.
  Widget _fadeBand({required bool top}) => Positioned(
        key: ValueKey(top ? 'kids.trail.fadeTop' : 'kids.trail.fadeBottom'),
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: 0,
        right: 0,
        height: 22,
        child: const IgnorePointer(child: SizedBox.expand()),
      );

  @override
  Widget build(BuildContext context) {
    final scroller = NotificationListener<OverscrollNotification>(
        // Hands the leftover drag to the Home list underneath. Without
        // this the trail is a dead end: a finger that scrolls to the
        // stage's last node just stops, and the child has to lift off
        // and start a new drag in the page margin to reach the practice
        // tiles below — which is not discoverable and reads as the
        // scroll being broken.
        //
        // ClampingScrollPhysics (above) is what makes this possible:
        // unlike BouncingScrollPhysics, which absorbs the excess into a
        // stretch, it reports whatever it could not consume as an
        // OverscrollNotification — during a drag AND during a fling, so
        // momentum carries through too. Forwarding the delta by hand
        // also sidesteps the gesture arena entirely: the inner
        // scrollable keeps the gesture from first touch to last, so
        // there is never a contest for the outer list to win.
        //
        // It works in both directions — overscroll at the top is
        // negative, so dragging down on a top-parked trail scrolls the
        // page back up.
        onNotification: (n) {
          if (n.depth != 0) return false; // our own scroll view only
          // Resolved from THIS context, which sits above the
          // SingleChildScrollView below — so it finds the Home
          // page scroll, not the trail itself.
          final outer = Scrollable.maybeOf(context)?.position;
          if (outer == null || !outer.hasContentDimensions) return false;
          final to = (outer.pixels + n.overscroll)
              .clamp(outer.minScrollExtent, outer.maxScrollExtent);
          if (to != outer.pixels) outer.jumpTo(to);
          return true;
        },
        child: SingleChildScrollView(
          controller: _c,
          physics: const ClampingScrollPhysics(),
          child: widget.child,
        ),
    );
    return SizedBox(
      key: const ValueKey('kids.trail'),
      height: _height,
      child: NotificationListener<ScrollMetricsNotification>(
        // ScrollController only notifies its own listeners (what the
        // AnimatedBuilder below is watching) when the scroll OFFSET changes —
        // not when its extents are first established with no offset change
        // of their own, which is exactly the trail's opening frame: it starts
        // already positioned at `_offsetFor(current)`, so nothing here would
        // otherwise prompt a rebuild to notice that position now has real
        // content dimensions to check against. ScrollMetricsNotification
        // exists precisely for that gap — it fires on first layout too — so
        // this just asks for one more rebuild when it does.
        onNotification: (n) {
          if (mounted) setState(() {});
          return false;
        },
        // Reactive to the actual scroll position, not just "is this stage
        // long enough to scroll at all": a fade at an edge that has nothing
        // beyond it claims there is more to see when there isn't — which on
        // a stage's true last node (nothing below it, and
        // ClampingScrollPhysics gives no bounce to say so either) reads as
        // the scroll being stuck rather than having reached the end.
        child: !_scrolls
            ? scroller
            : AnimatedBuilder(
                animation: _c,
                child: scroller,
                builder: (context, child) {
                  // hasClients alone isn't enough — the position exists
                  // before its first layout pass, and maxScrollExtent is null
                  // until hasContentDimensions is true.
                  final hasDims =
                      _c.hasClients && _c.position.hasContentDimensions;
                  final atTop =
                      !hasDims || _c.offset <= _c.position.minScrollExtent;
                  final atBottom =
                      !hasDims || _c.offset >= _c.position.maxScrollExtent;
                  return Stack(children: [
                    ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) =>
                          _mask(r, top: !atTop, bottom: !atBottom),
                      child: child,
                    ),
                    if (!atTop) _fadeBand(top: true),
                    if (!atBottom) _fadeBand(top: false),
                  ]);
                },
              ),
      ),
    );
  }
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1 + .08 * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// The dashed line the trail nodes hang off: the design's 5 px dashes, 15 on
/// and 10 off, in the palette's path colour.
class _TrailLinePainter extends CustomPainter {
  final Color color;
  final Axis axis;
  _TrailLinePainter(this.color, this.axis);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5;
    if (axis == Axis.vertical) {
      final x = size.width / 2;
      for (var y = 0.0; y < size.height; y += 25) {
        canvas.drawLine(
            Offset(x, y), Offset(x, (y + 15).clamp(0, size.height)), paint);
      }
    } else {
      final y = size.height / 2;
      for (var x = 0.0; x < size.width; x += 25) {
        canvas.drawLine(
            Offset(x, y), Offset((x + 15).clamp(0, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TrailLinePainter old) =>
      old.color != color || old.axis != axis;
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
