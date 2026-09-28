import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart' show SettingsScope;
import '../../core/theme.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kBlack, kbC;
import 'kids_alphabet_screen.dart';
import 'kids_home_screen.dart';
import 'kids_me_screen.dart';
import 'kids_profile_gate.dart';
import 'kids_rank_screen.dart';
import 'kids_rewards_screen.dart';
import 'kids_widgets.dart' show KidsBackdrop, KidsMascot;

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
            body: KidsBackdrop(
              child: IndexedStack(index: _tab, children: [
                KidsHomeScreen(onGoLearn: () => setState(() => _tab = 1)),
                const KidsAlphabetScreen(),
                const KidsRankScreen(),
                const KidsRewardsScreen(),
                const KidsMeScreen(),
              ]),
            ),
            bottomNavigationBar:
                _NavBar(tab: _tab, onTap: (i) => setState(() => _tab = i)),
          ),
        )),
      ),
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
