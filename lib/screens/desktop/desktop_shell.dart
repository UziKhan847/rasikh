import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../about_screen.dart';
import '../search.dart';
import 'desktop_pages.dart';
import 'screen_tints.dart';
import 'tab_names.dart';

/// Desktop shell: fixed sidebar + top bar + tinted content area.
/// Rebuilt to follow the Qiraah Arabiyyah desktop reference — each tab keeps its
/// own hero gradient and heading color.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});
  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  DeskTab tab = DeskTab.home;
  bool collapsed = false;

  static const _learn = [
    DeskTab.home,
    DeskTab.reader,
    DeskTab.qaidah,
    DeskTab.tracing,
    DeskTab.tashkil,
    DeskTab.tajwid,
    DeskTab.coach,
    DeskTab.qiraat,
  ];

  void go(DeskTab t) => setState(() => tab = t);

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Row(children: [
        _Sidebar(
            tab: tab,
            onGo: go,
            learn: _learn,
            collapsed: collapsed,
            onToggle: () => setState(() => collapsed = !collapsed)),
        Expanded(
          child: Column(children: [
            _TopBar(tint: kTint[tab]!, onGo: go),
            Expanded(child: _content()),
          ]),
        ),
      ]),
    );
  }

  Widget _content() {
    // A nested Navigator per tab: anything pushed from inside (letter details,
    // quizzes, drills, counts trainer) opens WITHIN the content pane — the
    // sidebar and top bar stay visible, instead of a full-screen mobile page.
    return Navigator(
      key: ValueKey('nav-$tab'),
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => _tabRoot()),
    );
  }

  Widget _tabRoot() {
    switch (tab) {
      case DeskTab.home:
        return DesktopHome(onGo: go);
      case DeskTab.reader:
        return const DesktopReader();
      case DeskTab.qaidah:
        return const DesktopQaidah();
      case DeskTab.tracing:
        return const DesktopTracing();
      case DeskTab.tashkil:
        return const DesktopTashkil();
      case DeskTab.tajwid:
        return const DesktopTajwid();
      case DeskTab.coach:
        return const DesktopCoach();
      case DeskTab.qiraat:
        return const DesktopQiraat();
      case DeskTab.about:
        return const AboutScreen(embedded: true);
    }
  }
}

class _Sidebar extends StatelessWidget {
  final DeskTab tab;
  final void Function(DeskTab) onGo;
  final List<DeskTab> learn;
  final bool collapsed;
  final VoidCallback onToggle;
  const _Sidebar(
      {required this.tab,
      required this.onGo,
      required this.learn,
      required this.collapsed,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: collapsed ? 78 : 268,
      padding: EdgeInsets.fromLTRB(collapsed ? 14 : 18, 26, collapsed ? 14 : 18, 20),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.surfaceHigh)),
      ),
      child: Column(
          crossAxisAlignment: collapsed
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
        Row(mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                  colors: [Color(0xFF2BD6A3), Color(0xFF0FB68B)]),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF14C18E).withValues(alpha: .32),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: SvgPicture.asset(
              'assets/brand/qa_icon.svg',
              width: 26,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.qiraahArabiyyah,
                    style: uiStyle(context, size: 16, weight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis),
                Text(context.l10n.qurAnicArabic,
                    style: uiStyle(context, size: 11.5, color: p.textDim)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        // toggle button
        Align(
          alignment: collapsed ? Alignment.center : Alignment.centerRight,
          child: Material(
            color: p.bg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    border: Border.all(color: p.surfaceHigh),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 20,
                    color: p.textDim),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // The nav list is the flexible region: on short windows it scrolls,
        // so the bottom cluster (theme toggle, streak, About) never overflows.
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
                  child: Text(context.l10n.learn,
                      style: uiStyle(context,
                          size: 11,
                          weight: FontWeight.w800,
                          color: p.textDim)),
                ),
              for (final t in learn) _navItem(context, t),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _themeToggle(context),
        const SizedBox(height: 10),
        _streakCard(context),
        const SizedBox(height: 8),
        _navItem(context, DeskTab.about),
      ]),
    );
  }

  Widget _navItem(BuildContext context, DeskTab t) {
    final p = pal(context);
    final meta = kTint[t]!;
    final on = t == tab;
    final item = Opacity(
      opacity: meta.soon ? .55 : 1,
      child: Material(
      color: on ? meta.softOf(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onGo(t),
        child: collapsed
            ? SizedBox(
                width: 50,
                height: 46,
                child: Icon(meta.icon,
                    size: 22, color: on ? meta.kickerColor : p.textDim),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Row(children: [
                  Icon(meta.icon,
                      size: 21, color: on ? meta.kickerColor : p.textDim),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(deskTitleOf(context, t),
                        overflow: TextOverflow.ellipsis,
                        style: uiStyle(context,
                            size: 14.5,
                            weight: on ? FontWeight.w800 : FontWeight.w600,
                            color: on ? meta.kickerColor : p.text)),
                  ),
                  if (meta.soon || meta.advanced)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: meta.softOf(context),
                          borderRadius: BorderRadius.circular(7)),
                      child: Text(meta.soon ? 'SOON' : 'ADV',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: meta.soon
                                  ? p.textDim
                                  : const Color(0xFF7C6BB8))),
                    ),
                ]),
        ),
      ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: collapsed
          ? Center(child: Tooltip(message: deskTitleOf(context, t), child: item))
          : item,
    );
  }

  /// Theme toggle, styled per the reference: an icon tile + label, sitting
  /// just above the streak card. Toggles light ↔ OLED (dark stays reachable
  /// from the About screen's full theme controls).
  Widget _themeToggle(BuildContext context) {
    final p = pal(context);
    final s = SettingsScope.of(context);
    final isDarkish = s.themeMode != 'light';
    final label = isDarkish
        ? context.l10n.lightMode
        : context.l10n.oledMode;
    final icon = isDarkish
        ? const Icon(Icons.wb_sunny_rounded,
            size: 19, color: Color(0xFFF5B301))
        : Icon(Icons.dark_mode_rounded, size: 19, color: p.textDim);
    final tile = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: p.bg, borderRadius: BorderRadius.circular(11)),
      child: icon,
    );
    void flip() =>
        s.update(() => s.themeMode = isDarkish ? 'light' : 'oled');
    if (collapsed) {
      return Tooltip(
        message: label,
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: flip,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  border: Border.all(color: p.surfaceHigh),
                  borderRadius: BorderRadius.circular(15)),
              child: icon,
            ),
          ),
        ),
      );
    }
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: flip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              border: Border.all(color: p.surfaceHigh),
              borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            tile,
            const SizedBox(width: 12),
            Text(label,
                style: uiStyle(context,
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: p.textDim)),
          ]),
        ),
      ),
    );
  }

  Widget _streakCard(BuildContext context) {
    final prog = ProgressScope.of(context);
    final days = prog.streakDays;
    if (collapsed) {
      return Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
              colors: [Color(0xFF2BD6A3), Color(0xFF10B98C)]),
        ),
        child: const Icon(Icons.local_fire_department_rounded,
            color: Colors.white, size: 22),
      );
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            colors: [Color(0xFF2BD6A3), Color(0xFF10B98C)]),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.streakDaysCount(days < 0 ? 0 : days),
                style: uiStyle(context,
                    size: 18, weight: FontWeight.w800, color: Colors.white)),
            Text(
                days == 0
                    ? context.l10n.streakStart
                    : context.l10n.streakKeep,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context,
                    size: 11.5, color: Colors.white.withValues(alpha: .85))),
          ]),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TabTint tint;
  final void Function(DeskTab) onGo;
  const _TopBar({required this.tint, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 20, 30, 16),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deskKickerOf(context, DeskTab.home),
              style: uiStyle(context,
                  size: 13, weight: FontWeight.w700, color: p.textDim)),
          Text(tint.title,
              style: uiStyle(context, size: 25, weight: FontWeight.w900)),
        ]),
        const Spacer(),
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () =>
                showSearch(context: context, delegate: GlobalSearch(context.l10n.searchLettersRulesSurahs)),
            child: Container(
              height: 44,
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                border: Border.all(color: p.surfaceHigh),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 19, color: p.textDim),
                const SizedBox(width: 10),
                Text(context.l10n.search2,
                    style: uiStyle(context, size: 13.5, color: p.textDim)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
                colors: [Color(0xFF8E7DC4), Color(0xFF6E5BB0)]),
          ),
          child: IconButton(
            onPressed: () => onGo(DeskTab.about),
            icon: const Icon(Icons.person_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

}
