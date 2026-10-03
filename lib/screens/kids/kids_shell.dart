import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressScope, SettingsScope;
import '../../core/theme.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_parallax.dart' show KbSwipeTabs;
import '../../kids_backdrops/kb_scene.dart' show kBlack, kbC;
import 'kids_alphabet_screen.dart';
import 'kids_frame_readout.dart';
import 'kids_home_screen.dart';
import 'kids_me_screen.dart';
import 'kids_profile_gate.dart';
import 'kids_rank_screen.dart';
import 'kids_rewards_screen.dart';
import 'kids_widgets.dart' show KidsMascot, KidsTabBackdrop, kidsReduceMotion;

/// Kids Mode's own mobile shell: a 5-tab bottom nav (Home / Learn / Rank /
/// Rewards / Me) over a [ProgressStore] scoped to the active child profile —
/// never the grown-up app's global store. Reached on phones (see
/// `main.dart`'s `RootScreen`); a desktop-sized window gets
/// `KidsDesktopShell` instead.
class KidsShell extends StatefulWidget {
  const KidsShell({super.key});
  @override
  State<KidsShell> createState() => _KidsShellState();
}

class _KidsShellState extends State<KidsShell> {
  int _tab = 0;
  Timer? _breakTimer;
  bool _timerStarted = false;

  /// The backdrop's camera: how far across the five tabs it is looking, in
  /// pixels, eased to the current tab by [KbSwipeTabs] on each nav-bar tap;
  /// the parallax layers read it.
  final _camera = ValueNotifier<double>(0);

  /// How far the current tab's page is scrolled, and how far it CAN scroll,
  /// for the vertical parallax: the layers' travel is spread over the whole
  /// page, reaching its end exactly at the bottom.
  final _scrollY = ValueNotifier<double>(0);
  final _scrollExtent = ValueNotifier<double>(0);

  /// Each tab's own scroll offset and length. The tabs keep their state (and
  /// their scroll position) across a switch, so the backdrop picks up where
  /// that tab's page really is rather than resetting to the top.
  final _offsets = List<double>.filled(5, 0);
  final _extents = List<double>.filled(5, 0);

  /// Keeps the five tabs (their state, their scroll) when the backdrop around
  /// them changes shape — switching Detail between medium and high swaps the
  /// whole backdrop widget, and without this every tab was rebuilt from scratch.
  final _tabsKey = GlobalKey();

  /// The five pages, made once. A tab change rebuilds the shell; handing it
  /// the very same page widgets lets Flutter skip rebuilding them — Home alone
  /// is a whole stage of trail nodes, rebuilt on every tap of the nav bar.
  late final List<Widget> _pages = [
    KidsHomeScreen(onGoLearn: () => _go(1)),
    const KidsAlphabetScreen(),
    const KidsRankScreen(),
    const KidsRewardsScreen(),
    const KidsMeScreen(),
  ];

  /// Points the backdrop at the current tab's scroll. A page's length can
  /// change while it is being laid out (a lazily built list settling its
  /// size), and the backdrop must not be told mid-frame — so then it is told
  /// just after.
  void _follow() {
    void apply() {
      if (!mounted) return;
      _scrollY.value = _offsets[_tab];
      _scrollExtent.value = _extents[_tab];
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_followQueued) return;
      _followQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _followQueued = false;
        apply();
      });
    } else {
      apply();
    }
  }

  bool _followQueued = false;

  void _go(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _scrollY.value = _offsets[tab];
    _scrollExtent.value = _extents[tab];
  }

  /// Started once, from the settings in force when the shell first mounts —
  /// a parent turning the reminder off mid-session takes effect next time,
  /// same as every other Kids Mode setting reads once per screen.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timerStarted) return;
    _timerStarted = true;
    final minutes = SettingsScope.of(context).kidsSessionMinutes;
    if (minutes > 0) {
      _breakTimer = Timer(Duration(minutes: minutes), _suggestBreak);
    }
  }

  void _suggestBreak() {
    if (!mounted) return;
    showDialog<void>(context: context, builder: (_) => const _BreakDialog());
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    _camera.dispose();
    _scrollY.dispose();
    _scrollExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaletteScope(
      palette: kidsPal(context),
      child: Theme(
        data: kidsTheme(context),
        child: KidsTextScale(child: KidsProfileGate(
          builder: (context) => Scaffold(
            backgroundColor: kbPageBg(kbUi(context)),
            // The scene runs the full height of the screen, with the nav bar
            // floating over its foot — the design is authored that way (ridges
            // sit at fixed fractions of the WHOLE screen), and stopping it above
            // the bar squashed every ridge up the page.
            extendBody: true,
            // Tabs change only from the nav bar (no swiping): the backdrop's
            // camera eases across to the new tab and the page fades in.
            body: Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: KidsTabBackdrop(
              cameraX: _camera,
              scrollY: _scrollY,
              scrollExtent: _scrollExtent,
              child: KbSwipeTabs(
                key: _tabsKey,
                index: _tab,
                onChanged: _go,
                camera: _camera,
                swipe: false,
                child: IndexedStack(index: _tab, children: [
                  for (final (i, page) in _pages.indexed)
                    _TabPage(
                      active: i == _tab,
                      onScroll: (px, extent) {
                        _offsets[i] = px;
                        _extents[i] = extent;
                        if (i == _tab) _follow();
                      },
                      child: page,
                    ),
                ]),
              ),
            )),
              const _DevFrameReadout(),
            ]),
            bottomNavigationBar: _NavBar(tab: _tab, onTap: _go),
          ),
        )),
      ),
    );
  }
}

/// One tab's page in the shell's stack: reports how far the page is scrolled
/// and how far it can scroll (its own outermost vertical scroll view — a
/// nested one is not the page), and fades in over 220 ms each time it becomes
/// the current tab, as the design's tab change does.
///
/// A hidden tab is paused (TickerMode): IndexedStack keeps it built but does
/// not stop its animations, and Home's pulsing node ticked on every tab.
class _TabPage extends StatefulWidget {
  final bool active;
  final void Function(double pixels, double extent) onScroll;
  final Widget child;
  const _TabPage({
    required this.active,
    required this.onScroll,
    required this.child,
  });

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !kidsReduceMotion(context)) {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
        onNotification: (n) {
          // A scroll, and also the page's first layout and any change in its
          // length (ScrollMetricsNotification): a freshly built page at 0 sends
          // no scroll notification, and the backdrop kept the old offset.
          final (depth, metrics) = switch (n) {
            ScrollNotification(:final depth, :final metrics) => (depth, metrics),
            ScrollMetricsNotification(:final depth, :final metrics) => (depth, metrics),
            _ => (-1, null),
          };
          if (depth == 0 &&
              metrics != null &&
              metrics.axis == Axis.vertical &&
              metrics.hasContentDimensions) {
            widget.onScroll(metrics.pixels, metrics.maxScrollExtent);
          }
          return false;
        },
        child: TickerMode(
          enabled: widget.active,
          child: FadeTransition(
            opacity: _opacity,
            child: widget.child,
          ),
        ),
      );
}

/// The frame readout, pinned under the status bar while the testing unlock is
/// on — its own widget so only it, not the whole shell, listens to progress.
class _DevFrameReadout extends StatelessWidget {
  const _DevFrameReadout();

  @override
  Widget build(BuildContext context) {
    if (!ProgressScope.of(context).unlockAll) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 4,
      left: 0,
      right: 0,
      child: const Center(child: KidsFrameReadout()),
    );
  }
}

/// The session-length reminder itself: a mascot, a warm "time for a
/// stretch?" line, and one button that dismisses it and changes nothing —
/// never a lockout, never a second nag this session (the timer that raised
/// it does not repeat).
class _BreakDialog extends StatelessWidget {
  const _BreakDialog();

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    // A hero card (UI_SPEC §1): solid surface, hard edge, the page's one action
    // as the big button.
    return Dialog(
      backgroundColor: kbC(kBlack, 0),
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: KbSurface(
        color: ui.surface,
        edge: ui.edge,
        elev: KbElev.hero,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KidsMascot(size: 84),
            const SizedBox(height: 14),
            Text(
              context.l10n.kidsBreakTitle,
              textAlign: TextAlign.center,
              style: kbText(26, kbC(ui.ink)),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.kidsBreakSub,
              textAlign: TextAlign.center,
              style: kbText(17, kbC(ui.inkSoft), weight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            KbBigButton(
              context.l10n.kidsBreakContinue,
              ui: ui,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  const _NavBar({required this.tab, required this.onTap});

  static const _ids = ['home', 'learn', 'rank', 'rewards', 'me'];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.kidsTabHome, l.kidsTabLearn, l.kidsTabRank, l.kidsTabRewards, l.kidsTabMe];
    return KbNavBar(
      ui: kbUi(context),
      current: _ids[tab],
      items: [
        for (final (i, it) in kbNavItems.indexed) KbNavItem(it.id, it.icon, labels[i]),
      ],
      onSelect: (id) => onTap(_ids.indexOf(id)),
    );
  }
}
