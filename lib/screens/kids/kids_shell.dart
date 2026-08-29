import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import 'kids_alphabet_screen.dart';
import 'kids_home_screen.dart';
import 'kids_me_screen.dart';
import 'kids_profile_gate.dart';
import 'kids_rank_screen.dart';
import 'kids_rewards_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return PaletteScope(
      palette: kidsPal(context),
      child: Theme(
        data: kidsTheme(context),
        child: KidsProfileGate(
          builder: (context) => Scaffold(
            backgroundColor: kidsPal(context).bg,
            body: IndexedStack(index: _tab, children: [
              KidsHomeScreen(onGoLearn: () => setState(() => _tab = 1)),
              const KidsAlphabetScreen(),
              const KidsRankScreen(),
              const KidsRewardsScreen(),
              const KidsMeScreen(),
            ]),
            bottomNavigationBar:
                _NavBar(tab: _tab, onTap: (i) => setState(() => _tab = i)),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  const _NavBar({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final items = [
      (Icons.home_rounded, context.l10n.kidsTabHome),
      (Icons.menu_book_rounded, context.l10n.kidsTabLearn),
      (Icons.emoji_events_rounded, context.l10n.kidsTabRank),
      (Icons.card_giftcard_rounded, context.l10n.kidsTabRewards),
      (Icons.face_rounded, context.l10n.kidsTabMe),
    ];
    return BottomNavigationBar(
      currentIndex: tab,
      onTap: onTap,
      backgroundColor: p.surface,
      selectedItemColor: p.accent,
      unselectedItemColor: p.textDim,
      selectedLabelStyle:
          kidsStyle(context, size: 11, weight: FontWeight.w800),
      unselectedLabelStyle: kidsStyle(context, size: 11),
      type: BottomNavigationBarType.fixed,
      items: [
        for (final (icon, label) in items)
          BottomNavigationBarItem(icon: Icon(icon), label: label),
      ],
    );
  }
}
