import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/brand.dart';
import '../../ui/kit.dart';
import '../learn_screen.dart';
import '../marks/hifz_screen.dart';
import '../mushaf_screen.dart';
import '../quran_screen.dart';
import '../settings_screen.dart';
import '../today_screen.dart';
import '../tracing_screen.dart';

/// The top-level places of the app.
enum AppSection { today, quran, mushaf, hifz, learn, trace, settings }

/// Lets any screen inside the shell switch section (Today's tiles open the
/// reader, Learn or Trace this way).
class ShellScope extends InheritedWidget {
  final void Function(AppSection) go;

  /// True while a screen reads in focus (the muṣḥaf with its menus hidden):
  /// the desktop sidebar and its restore button step aside.
  final ValueNotifier<bool> focus;
  const ShellScope(
      {super.key, required this.go, required this.focus, required super.child});

  static ShellScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>();

  static void setFocus(BuildContext context, bool on) {
    final n = maybeOf(context)?.focus;
    if (n != null && n.value != on) n.value = on;
  }

  static void goTo(BuildContext context, AppSection s) {
    final scope = context.getInheritedWidgetOfExactType<ShellScope>();
    if (scope != null) {
      scope.go(s);
    } else if (s == AppSection.mushaf) {
      openMushaf(context);
    }
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Opens the 15-line muṣḥaf full-screen: at [page] in [script] (both default
/// to the last page read / the muṣḥaf setting), optionally straight into
/// marking mode.
void openMushaf(BuildContext context,
    {int? page, String? script, bool startMarking = false}) {
  final prog = ProgressScope.read(context);
  Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(
          builder: (_) => MushafPageScreen(
              startPage: page ?? prog.lastMushafPage ?? 1,
              script: script,
              startMarking: startMarking)));
}

String sectionLabel(BuildContext context, AppSection s) => switch (s) {
      AppSection.today => context.l10n.navToday,
      AppSection.quran => context.l10n.navReader,
      AppSection.mushaf => context.l10n.navMushaf,
      AppSection.hifz => context.l10n.mkHifz,
      AppSection.learn => context.l10n.navLearn,
      AppSection.trace => context.l10n.navTrace,
      AppSection.settings => context.l10n.settings,
    };

IconData sectionIcon(AppSection s) => switch (s) {
      AppSection.today => AppIcons.today,
      AppSection.quran => AppIcons.reader,
      AppSection.mushaf => AppIcons.mushaf,
      AppSection.hifz => AppIcons.hifz,
      AppSection.learn => AppIcons.learn,
      AppSection.trace => AppIcons.trace,
      AppSection.settings => AppIcons.settings,
    };

/// The app shell: bottom tabs on a phone, a collapsible sidebar on desktop.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.today;
  final Set<AppSection> _visited = {AppSection.today};
  final _focus = ValueNotifier(false);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _go(AppSection s) {
    if (s == AppSection.mushaf && !useDesktop(context)) {
      openMushaf(context);
      return;
    }
    setState(() {
      _section = s;
      _visited.add(s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktop(context);
    return ShellScope(
      go: _go,
      focus: _focus,
      child: desktop ? _desktop(context) : _mobile(context),
    );
  }

  // ── phone ──

  static const _tabs = [
    AppSection.today,
    AppSection.quran,
    AppSection.mushaf,
    AppSection.hifz,
    AppSection.learn,
    AppSection.trace,
  ];

  Widget _mobileRoot(AppSection s) => switch (s) {
        AppSection.today => const TodayScreen(),
        AppSection.quran => const SurahListScreen(embedded: true),
        AppSection.learn => const LearnScreen(),
        AppSection.trace => const TracingScreen(),
        AppSection.settings => const SettingsScreen(),
        AppSection.mushaf => const SizedBox.shrink(),
        AppSection.hifz => const HifzScreen(),
      };

  Widget _mobile(BuildContext context) {
    // Settings is not a tab on the phone: Today's cog pushes it.
    final current = _section == AppSection.settings ? AppSection.today : _section;
    return Scaffold(
      body: IndexedStack(
        index: _tabs.indexOf(current),
        children: [
          // TickerMode: IndexedStack keeps hidden tabs alive, and without it
          // their animations (e.g. the tracing board's pulse) kept running
          // and redrawing every frame from any other tab.
          for (final t in _tabs)
            TickerMode(
              enabled: t == current,
              child: _visited.contains(t)
                  ? _mobileRoot(t)
                  : const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: _TabBar(current: current, onTap: _go),
    );
  }

  // ── desktop ──

  Widget _desktopRoot(AppSection s) => switch (s) {
        AppSection.today => const TodayScreen(),
        AppSection.quran => const SurahListScreen(),
        // read, not of: the shell must not rebuild on every progress change.
        AppSection.mushaf => MushafPageScreen(
            startPage: ProgressScope.read(context).lastMushafPage ?? 1),
        AppSection.hifz => const HifzScreen(),
        AppSection.learn => const LearnScreen(),
        AppSection.trace => const TracingScreen(),
        AppSection.settings => const SettingsScreen(),
      };

  // One Navigator per section, built once: a new Navigator widget on every
  // shell build made each of them rebuild every page it holds.
  final Map<AppSection, Widget> _navigators = {};

  Widget _navigatorFor(AppSection t) => _navigators[t] ??= Navigator(
        key: ValueKey('nav-$t'),
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => _desktopRoot(t)),
      );

  Widget _desktop(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _focus,
      builder: (context, focus, _) => _desktopBody(context, p, s, focus),
    );
  }

  Widget _desktopBody(
      BuildContext context, Palette p, AppSettings s, bool focus) {
    final collapsed = s.sidebarCollapsed || focus;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        top: false,
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: collapsed ? 0 : 248,
            child: ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: 248,
                maxWidth: 248,
                child: _Sidebar(
                  current: _section,
                  onGo: _go,
                  onHide: () => s.update(() => s.sidebarCollapsed = true),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: IndexedStack(
                  index: AppSection.values.indexOf(_section),
                  children: [
                    for (final t in AppSection.values)
                      TickerMode(
                        enabled: t == _section,
                        child: _visited.contains(t)
                            ? _navigatorFor(t)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              if (collapsed && !focus)
                PositionedDirectional(
                  start: 16,
                  bottom: 16,
                  child: QIconButton(
                    icon: AppIcons.sidebarShow,
                    size: 44,
                    tooltip: context.l10n.showSidebar,
                    onTap: () => s.update(() => s.sidebarCollapsed = false),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The phone's bottom tab bar: Today · Reader · Muṣḥaf · Learn · Trace.
class _TabBar extends StatelessWidget {
  final AppSection current;
  final void Function(AppSection) onTap;
  const _TabBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.line2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (final t in _AppShellState._tabs)
              Expanded(
                child: Semantics(
                  selected: t == current,
                  button: true,
                  label: sectionLabel(context, t),
                  child: InkWell(
                    onTap: () => onTap(t),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(sectionIcon(t),
                            size: 22, color: t == current ? p.acc : p.ink3),
                        const SizedBox(height: 4),
                        Text(sectionLabel(context, t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: uiStyle(context,
                                size: 11,
                                weight: FontWeight.w700,
                                color: t == current ? p.acc : p.ink3)),
                      ],
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The desktop sidebar: logo and wordmark, the hide button, the main nav,
/// Settings, and a streak card at the bottom.
class _Sidebar extends StatelessWidget {
  final AppSection current;
  final void Function(AppSection) onGo;
  final VoidCallback onHide;
  const _Sidebar(
      {required this.current, required this.onGo, required this.onHide});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final g = gradientsOf(context);
    final on = gradientsOn(context);
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
      decoration: BoxDecoration(
        color: on ? null : g.sideFlat,
        gradient: on
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: g.side)
            : null,
        border: BorderDirectional(end: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Row(children: [
              const AppLogoTile(),
              const SizedBox(width: 12),
              const Expanded(child: AppWordmark()),
              QIconButton(
                icon: AppIcons.sidebarHide,
                size: 32,
                iconSize: 18,
                border: false,
                color: Colors.transparent,
                tooltip: context.l10n.hideSidebar,
                onTap: onHide,
              ),
            ]),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final s in const [
                  AppSection.today,
                  AppSection.quran,
                  AppSection.mushaf,
                  AppSection.hifz,
                  AppSection.learn,
                  AppSection.trace,
                  AppSection.settings,
                ])
                  _item(context, s),
              ],
            ),
          ),
          _StreakCard(),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, AppSection s) {
    final p = pal(context);
    final on = s == current;
    final label = s == AppSection.trace
        ? context.l10n.tracingStudio
        : sectionLabel(context, s);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: on ? p.accSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onGo(s),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(sectionIcon(s), size: 20, color: on ? p.accInk : p.ink2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 14.5,
                          weight: on ? FontWeight.w700 : FontWeight.w600,
                          color: on ? p.accInk : p.ink)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final days = prog.streakDays < 0 ? 0 : prog.streakDays;
    return QCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(AppIcons.streak, size: 16, color: const Color(0xFFD9622B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.l10n.streakDaysLabel(days),
                  style: uiStyle(context, size: 14, weight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(days == 0 ? context.l10n.streakStart : context.l10n.streakKeep,
              style: uiStyle(context, size: 12.5, color: p.ink3)),
        ],
      ),
    );
  }
}
