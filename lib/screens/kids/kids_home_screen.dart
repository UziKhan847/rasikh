import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import '../../widgets/common.dart';
import 'kids_desktop_nav.dart';
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

/// Height of one row of the vertical trail. Load-bearing — [_ScrollingTrail]
/// scrolls in multiples of it to bring the current node into view.
const _trailRowHeight = 82.0;

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
    final p = kidsPal(context);
    final profile = s.activeKidsProfile!;
    // The trail follows the stage the child is actually up to, not a flat
    // list of 28 letters — see kids_path.dart.
    final block = kidsPath(context)[kidsCurrentBlockIndex(context, prog)];
    final items = block.items(context);
    final doneCount = kidsCurrentItemIndex(prog, items);
    final allDone = doneCount >= items.length;
    final currentItem = items[allDone ? items.length - 1 : doneCount];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapXl),
        children: [
          _Header(
              name: profile.name,
              streakDays: prog.streakDays,
              streakFreezes: prog.streakFreezes),
          _FreezeBanner(prog: prog),
          const SizedBox(height: Geo.gapLg),
          _DailyGoalCard(done: prog.todayActivityCount),
          const SizedBox(height: Geo.gapLg),
          KidsSectionHeader(title: context.l10n.kidsKeepGoing),
          const SizedBox(height: Geo.gapSm),
          _ResumeCard(
            item: currentItem,
            fraction: items.isEmpty ? 0 : doneCount / items.length,
            allDone: allDone,
          ),
          const SizedBox(height: Geo.gapLg),
          KidsSectionHeader(
            title: block.title(context),
            arabic: block.badge,
          ),
          const SizedBox(height: Geo.gapSm),
          _LetterTrail(
              items: items,
              doneCount: doneCount,
              axis: Axis.vertical,
              unlocked: prog.unlockAll),
          Center(
            child: TextButton(
              onPressed: onGoLearn,
              child: Text(context.l10n.kidsSeeWholePath,
                  style: kidsStyle(context,
                      size: 13, weight: FontWeight.w700, color: p.accent)),
            ),
          ),
          const SizedBox(height: Geo.gapSm),
          KidsSectionHeader(title: context.l10n.kidsPractice),
          const SizedBox(height: Geo.gapSm),
          Row(children: [
            Expanded(
              child: _PracticeCard(
                icon: Icons.style_rounded,
                label: context.l10n.kidsFlashcards,
                onTap: () => pushKidsOverlay(context,
                    title: context.l10n.kidsFlashcards,
                    builder: (_) => const KidsFlashcardsScreen()),
              ),
            ),
            const SizedBox(width: Geo.gapMd),
            Expanded(
              child: _PracticeCard(
                icon: Icons.headphones_rounded,
                label: context.l10n.kidsListening,
                onTap: () => pushKidsOverlay(context,
                    title: context.l10n.kidsListening,
                    builder: (_) => const KidsListeningScreen()),
              ),
            ),
          ]),
        ],
      ),
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
        const SizedBox(height: Geo.gapLg),
        KidsSectionHeader(
          title: block.title(context),
          arabic: block.badge,
        ),
        const SizedBox(height: Geo.gapSm),
        Container(
          padding: const EdgeInsets.all(Geo.gapLg),
          decoration: kidsPanel(context, radius: Geo.radiusXl),
          child: _LetterTrail(
              items: items,
              doneCount: doneCount,
              axis: Axis.horizontal,
              unlocked: prog.unlockAll),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsSectionHeader(
          title: context.l10n.kidsPractice,
          arabic: context.l10n.kidsPracticeArabic,
        ),
        const SizedBox(height: Geo.gapSm),
        Row(children: [
          Expanded(
            child: _PracticeCard(
              icon: Icons.style_rounded,
              label: context.l10n.kidsFlashcards,
              onTap: () => pushKidsOverlay(context,
                  title: context.l10n.kidsFlashcards,
                  builder: (_) => const KidsFlashcardsScreen()),
            ),
          ),
          const SizedBox(width: Geo.gapMd),
          Expanded(
            child: _PracticeCard(
              icon: Icons.headphones_rounded,
              label: context.l10n.kidsListening,
              onTap: () => pushKidsOverlay(context,
                  title: context.l10n.kidsListening,
                  builder: (_) => const KidsListeningScreen()),
            ),
          ),
        ]),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileRailCard(profile: profile, prog: prog),
        const SizedBox(height: Geo.gapMd),
        _RankRailCard(onViewAll: onGoRank),
        const SizedBox(height: Geo.gapMd),
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
              const SizedBox(height: Geo.gapLg),
              right,
            ])
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: Geo.gapLg),
                SizedBox(width: 300, child: right),
              ],
            ),
        ],
      );
    });
  }
}

/// "Marhaba 👋 / Hello, {name}!" with the streak pill opposite it.
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
    final p = kidsPal(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.kidsMarhaba,
                  style: kidsStyle(context,
                      size: 12.5, weight: FontWeight.w600, color: p.textDim)),
              const SizedBox(height: 2),
              Text(context.l10n.kidsHelloName(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      kidsStyle(context, size: 22, weight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: Geo.gapSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(Geo.radiusPill),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: p.amber),
                  child: const Icon(Icons.local_fire_department_rounded,
                      size: 13, color: Colors.white),
                ),
                const SizedBox(width: 7),
                Text(context.l10n.streakDaysCount(streakDays),
                    style: kidsStyle(context,
                        size: 12.5, weight: FontWeight.w800)),
              ]),
            ),
            // A bought streak freeze is otherwise a silent mechanic — this
            // is the one place a family sees it is there at all, and how
            // many are left, before it is ever spent.
            if (streakFreezes > 0) ...[
              const SizedBox(height: 4),
              Text(context.l10n.kidsFreezesCount(streakFreezes),
                  style: kidsStyle(context,
                      size: 11, weight: FontWeight.w700, color: p.accent2)),
            ],
          ],
        ),
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
    final p = kidsPal(context);
    return Padding(
      padding: const EdgeInsets.only(top: Geo.gapSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.accent2.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(Geo.radiusPill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🧊', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(context.l10n.kidsStreakSaved,
              style: kidsStyle(context,
                  size: 12.5, weight: FontWeight.w700, color: p.accent2)),
        ]),
      ),
    );
  }
}

/// The filled coral daily-goal panel — a white ring on the accent, per the
/// design (the same [KidsGoalRing], recoloured for a dark ground). On
/// desktop the design adds an explicit "Continue" button; mobile keeps the
/// separate [_ResumeCard] below it for that action instead.
class _DailyGoalCard extends StatelessWidget {
  final int done;
  final VoidCallback? onContinue;
  const _DailyGoalCard({required this.done, this.onContinue});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final capped = done.clamp(0, kidsDailyGoal);
    final left = kidsDailyGoal - capped;
    return Container(
      padding: const EdgeInsets.all(Geo.gapLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [p.accent, p.accentBright],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Geo.radiusXl),
        boxShadow: [
          BoxShadow(
              color: p.accent.withValues(alpha: .30),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        KidsGoalRing(
          fraction: done / kidsDailyGoal,
          size: 68,
          strokeWidth: 6,
          color: Colors.white,
          trackColor: Colors.white.withValues(alpha: .28),
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$capped',
                style: kidsStyle(context,
                    size: 20, weight: FontWeight.w800, color: Colors.white)),
            Text('/$kidsDailyGoal',
                style: kidsStyle(context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .8))),
          ]),
        ),
        const SizedBox(width: Geo.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.kidsDailyGoalTitle,
                  style: kidsStyle(context,
                      size: 17, weight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 5),
              Text(
                  left == 0
                      ? context.l10n.kidsGoalComplete
                      : context.l10n.kidsGoalRemaining(left),
                  style: kidsStyle(context,
                      size: 12.5,
                      color: Colors.white.withValues(alpha: .92))),
            ],
          ),
        ),
        if (onContinue != null) ...[
          const SizedBox(width: Geo.gapMd),
          TapScale(
            onTap: onContinue!,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Geo.radiusMd),
              ),
              child: Text(context.l10n.continueLabel,
                  style: kidsStyle(context,
                      size: 14.5, weight: FontWeight.w800, color: p.accent)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// The "keep going" resume card: the letter in a teal-tinted swatch, its
/// name, the path progress bar, and a coral go button. Mobile-only — the
/// desktop layout folds this action into the goal card's "Continue" button.
class _ResumeCard extends StatelessWidget {
  final KidsItem item;
  final double fraction;
  final bool allDone;
  const _ResumeCard(
      {required this.item, required this.fraction, required this.allDone});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TapScale(
      onTap: () => openKidsItem(context, item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: kidsCard(context),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent2.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(Geo.radiusMd),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: item.glyph.isEmpty
                  ? Icon(item.icon, size: 26, color: p.accent2)
                  : Text(item.glyph,
                      textDirection: TextDirection.rtl,
                      style: quranicStyle(context,
                          size: 28, height: 1.05, color: p.accent2)),
            ),
          ),
          const SizedBox(width: Geo.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    // Stage-neutral: a stage's items are letters, quizzes,
                    // lesson pages or a reading, so "Letter Test" and "You
                    // finished the alphabet!" were both wrong here.
                    allDone
                        ? context.l10n.kidsStageDone
                        : context.l10n.kidsNextUp(item.label(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kidsStyle(context,
                        size: 14.5, weight: FontWeight.w800)),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Geo.radiusPill),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: p.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(p.accent2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Geo.gapMd),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
            child: Icon(
                rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 21,
                color: Colors.white),
          ),
        ]),
      ),
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
    final p = kidsPal(context);

    if (axis == Axis.horizontal) {
      // Desktop keeps a fixed window: the trail is one row inside a bordered
      // card, and the whole stage sits beside it on the Learn tab anyway.
      // Start a step behind where the child is, so a cleared node stays in
      // view, and never run past the end of the stage.
      final start = (doneCount - 1)
          .clamp(0, (items.length - _pathWindow).clamp(0, items.length));
      final end = (start + _pathWindow).clamp(0, items.length);
      return SizedBox(
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: CustomPaint(
                    painter:
                        _DashedSpinePainter(kidsLockedFill(p), Axis.horizontal)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = start; i < end; i++)
                  _TrailNode(item: items[i], state: _stateAt(i)),
              ],
            ),
          ],
        ),
      );
    }

    // Mobile holds the *whole* stage and scrolls within itself.
    return _ScrollingTrail(
      length: items.length,
      current: doneCount,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedSpinePainter(kidsLockedFill(p), Axis.vertical),
            ),
          ),
          Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _TrailRowAlign(
                  node: _TrailNode(item: items[i], state: _stateAt(i)),
                  // Alternate sides so the trail keeps its zig-zag rhythm.
                  alignment: i.isEven ? -0.55 : 0.55,
                ),
            ],
          ),
        ],
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

  double get _height =>
      widget.length.clamp(1, _trailVisibleRows) * _trailRowHeight;

  bool get _scrolls => widget.length > _trailVisibleRows;

  /// Puts node [i] one row down from the top, so the step just cleared is
  /// still visible above it.
  double _offsetFor(int i) {
    final max = (widget.length * _trailRowHeight - _height).clamp(0.0, 1e6);
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

  /// A short wash of the page colour at the cut edges, so the trail reads as
  /// a window on to something longer instead of a list that stops there.
  /// Keyed so a test can tell it apart from the true edge of the stage — see
  /// the caller: it must only appear on a side that actually hides content.
  Widget _fade(Color bg, {required bool top}) => Positioned(
        key: ValueKey(top ? 'kids.trail.fadeTop' : 'kids.trail.fadeBottom'),
        top: top ? 0 : null,
        bottom: top ? null : 0,
        left: 0,
        right: 0,
        height: 22,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [bg, bg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
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
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _c,
              physics: const ClampingScrollPhysics(),
              child: widget.child,
            ),
            // Reactive to the actual scroll position, not just "is this stage
            // long enough to scroll at all": a fade painted at an edge that
            // has nothing beyond it claims there is more to see when there
            // isn't — which on a stage's true last node (nothing below it,
            // and ClampingScrollPhysics gives no bounce to say so either)
            // reads as the scroll being stuck rather than having reached the
            // end.
            if (_scrolls)
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
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
                    if (!atTop) _fade(p.bg, top: true),
                    if (!atBottom) _fade(p.bg, top: false),
                  ]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Vertical-layout wrapper: places one [_TrailNode] to either side of the
/// dashed spine.
class _TrailRowAlign extends StatelessWidget {
  final Widget node;
  final double alignment;
  const _TrailRowAlign({required this.node, required this.alignment});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _trailRowHeight,
        child: Align(alignment: Alignment(alignment, 0), child: node),
      );
}

/// One trail circle: done (amber check), current (coral, the letter itself),
/// or locked (a padlock). Shared by both the vertical (mobile) and
/// horizontal (desktop) trail layouts.
class _TrailNode extends StatelessWidget {
  final KidsItem item;
  final _LetterState state;
  const _TrailNode({required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final locked = state == _LetterState.locked;
    final current = state == _LetterState.current;
    final size = current ? 68.0 : 56.0;
    final name = item.label(context);

    return Semantics(
      // Keyed by the item's progress id, the same convention the Learn grid
      // uses, so a node can be addressed however far down the stage it sits.
      key: ValueKey('kids.trail.${item.id}'),
      label: name,
      button: true,
      child: TapScale(
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
        // The letter the child is on breathes, so the eye lands on where to
        // go next without needing to read anything.
        child: _MaybePulse(
          enabled: current,
          child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (state) {
              _LetterState.done => p.amber,
              _LetterState.current => p.accent,
              _LetterState.open => p.surfaceHigh,
              _LetterState.locked => kidsLockedFill(p),
            },
            // Only a cleared or current node is lifted off the spine; an
            // unlocked-but-unplayed one sits flat, like a locked one.
            boxShadow: locked || state == _LetterState.open
                ? null
                : [
                    BoxShadow(
                        color: (current ? p.accent : p.amber)
                            .withValues(alpha: .32),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
          ),
          child: switch (state) {
            _LetterState.done =>
              const Icon(Icons.check_rounded, size: 26, color: Colors.white),
            _LetterState.locked => Icon(Icons.lock_rounded,
                size: 20, color: p.textDim.withValues(alpha: .75)),
            // Same glyph as the current node, in the muted fill above: it can
            // be opened, but it is not where the child is.
            _LetterState.open || _LetterState.current => FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: item.glyph.isEmpty
                      ? Icon(item.icon,
                          size: 28, color: current ? Colors.white : p.text)
                      : Text(item.glyph,
                          textDirection: TextDirection.rtl,
                          style: quranicStyle(context,
                              size: 30,
                              height: 1.05,
                              color: current ? Colors.white : p.text)),
                ),
              ),
            },
          ),
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

/// The dashed spine the trail nodes hang off, vertical or horizontal.
class _DashedSpinePainter extends CustomPainter {
  final Color color;
  final Axis axis;
  _DashedSpinePainter(this.color, this.axis);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 7.0, gap = 8.0;
    if (axis == Axis.vertical) {
      final x = size.width / 2;
      for (var y = 6.0; y < size.height - 6; y += dash + gap) {
        canvas.drawLine(
            Offset(x, y), Offset(x, (y + dash).clamp(0, size.height)), paint);
      }
    } else {
      final y = size.height / 2;
      for (var x = 0.0; x < size.width; x += dash + gap) {
        canvas.drawLine(
            Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSpinePainter old) =>
      old.color != color || old.axis != axis;
}

class _PracticeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PracticeCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Geo.gapMd),
        decoration: kidsCard(context),
        child: Column(children: [
          Icon(icon, color: p.accent2, size: 26),
          const SizedBox(height: 8),
          Text(label,
              style: kidsStyle(context, size: 13, weight: FontWeight.w700)),
        ]),
      ),
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
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.all(Geo.gapLg),
      decoration: kidsPanel(context),
      child: Column(children: [
        KidsAvatar(profile: profile, size: 44),
        const SizedBox(height: 8),
        Text(profile.name,
            style: kidsStyle(context, size: 15, weight: FontWeight.w800)),
        Text(context.l10n.kidsLevelLabel(prog.level),
            style: kidsStyle(context, size: 11, color: p.textDim)),
        const SizedBox(height: Geo.gapMd),
        Row(children: [
          Expanded(
            child: _MiniStat(
                value: '${prog.xp}',
                label: context.l10n.kidsStatXp,
                color: p.accent2),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MiniStat(
                value: context.l10n.streakDaysCount(prog.streakDays),
                label: context.l10n.kidsStatStreak,
                color: p.accent),
          ),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final tint = kidsTint(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
          color: tint.bg, borderRadius: BorderRadius.circular(Geo.radiusSm)),
      child: Column(children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kidsStyle(context,
                size: 13, weight: FontWeight.w800, color: tint.text)),
        Text(label,
            style: kidsStyle(context, size: 9, color: p.textDim)),
      ]),
    );
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
    final p = kidsPal(context);
    final rows = _rows?.take(3).toList() ?? const <KidsRankRow>[];
    return Container(
      padding: const EdgeInsets.all(Geo.gapMd),
      decoration: kidsPanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(context.l10n.kidsRankBannerTitle,
                  style: kidsStyle(context,
                      size: 13.5, weight: FontWeight.w800)),
            ),
            if (widget.onViewAll != null)
              GestureDetector(
                onTap: widget.onViewAll,
                child: Text(context.l10n.kidsViewAll,
                    style: kidsStyle(context,
                        size: 11, weight: FontWeight.w700, color: p.accent)),
              ),
          ]),
          if (rows.length > 1) ...[
            const SizedBox(height: Geo.gapSm),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text('${i + 1}',
                      style: kidsStyle(context,
                          size: 12, weight: FontWeight.w800, color: p.textDim)),
                  const SizedBox(width: 9),
                  KidsAvatar(profile: rows[i].profile, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(rows[i].profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kidsStyle(context,
                            size: 12.5, weight: FontWeight.w700)),
                  ),
                  Text('${rows[i].xp} XP',
                      style: kidsStyle(context,
                          size: 11, weight: FontWeight.w800, color: p.textDim)),
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
    final p = kidsPal(context);
    final earned =
        kidsBadgeDefs().where((b) => b.earned(prog)).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(Geo.gapMd),
      decoration: kidsPanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(context.l10n.kidsBadges,
                  style: kidsStyle(context,
                      size: 13.5, weight: FontWeight.w800)),
            ),
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: Text(context.l10n.kidsViewAll,
                    style: kidsStyle(context,
                        size: 11, weight: FontWeight.w700, color: p.accent)),
              ),
          ]),
          const SizedBox(height: Geo.gapSm),
          if (earned.isEmpty)
            Text('—', style: kidsStyle(context, size: 13, color: p.textDim))
          else
            Row(children: [
              for (final b in earned)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.amber.withValues(alpha: .18)),
                    child: Text(b.emoji, style: const TextStyle(fontSize: 17)),
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}
