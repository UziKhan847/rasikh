import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart' show TapScale;
import 'kids_alphabet_screen.dart';
import 'kids_desktop_nav.dart';
import 'kids_home_screen.dart';
import 'kids_me_screen.dart';
import 'kids_profile_gate.dart';
import 'kids_rank_screen.dart';
import 'kids_rewards_screen.dart';
import 'kids_widgets.dart';

/// Kids Mode's desktop shell — a 248px sidebar (brand, 5 nav items, streak
/// card, Light/Dark/OLED buttons) plus a top bar over the content pane.
///
/// Unlike the mobile shell, a full-pane kids destination (a letter's lesson,
/// Flashcards, Listening) can't be a routed push here: the design keeps the
/// sidebar on screen throughout, with only the top bar swapping to its
/// "lesson" variant (a back control, no search/gems/avatar). That's what
/// [KidsDesktopOverlay] is for — see `kids_desktop_nav.dart`.
class KidsDesktopShell extends StatefulWidget {
  const KidsDesktopShell({super.key});
  @override
  State<KidsDesktopShell> createState() => _KidsDesktopShellState();
}

class _KidsDesktopShellState extends State<KidsDesktopShell> {
  int _tab = 0;
  String? _overlayTitle;
  WidgetBuilder? _overlayBuilder;

  void _go(int tab) => setState(() {
    _tab = tab;
    _overlayTitle = null;
    _overlayBuilder = null;
  });

  void _openOverlay(String title, WidgetBuilder builder) => setState(() {
    _overlayTitle = title;
    _overlayBuilder = builder;
  });

  void _closeOverlay() => setState(() {
    _overlayTitle = null;
    _overlayBuilder = null;
  });

  @override
  Widget build(BuildContext context) {
    return PaletteScope(
      palette: kidsPal(context),
      child: Theme(
        data: kidsTheme(context),
        child: KidsProfileGate(
          builder: (context) {
          final p = kidsPal(context);
          return KidsDesktopOverlay(
            open: _openOverlay,
            close: _closeOverlay,
            child: Scaffold(
              backgroundColor: p.bg,
              body: Row(
                children: [
                  _Sidebar(tab: _tab, onGo: _go),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          overlayTitle: _overlayTitle,
                          onBack: _closeOverlay,
                          onAvatarTap: () => _go(4),
                        ),
                        Expanded(
                          child: _overlayBuilder != null
                              ? Builder(builder: _overlayBuilder!)
                              : IndexedStack(
                                  index: _tab,
                                  children: [
                                    KidsHomeScreen(
                                      onGoLearn: () => _go(1),
                                      onGoRank: () => _go(2),
                                      onGoRewards: () => _go(3),
                                    ),
                                    const KidsAlphabetScreen(),
                                    const KidsRankScreen(),
                                    const KidsRewardsScreen(),
                                    const KidsMeScreen(),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int tab;
  final void Function(int) onGo;
  const _Sidebar({required this.tab, required this.onGo});

  static const _icons = [
    Icons.home_rounded,
    Icons.menu_book_rounded,
    Icons.emoji_events_rounded,
    Icons.card_giftcard_rounded,
    Icons.face_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final prog = ProgressScope.of(context);
    final labels = [
      context.l10n.kidsTabHome,
      context.l10n.kidsTabLearn,
      context.l10n.kidsTabRank,
      context.l10n.kidsTabRewards,
      context.l10n.kidsTabMe,
    ];
    // The sidebar's own incoming constraints (from Row) don't reflect the
    // window's width — it's the un-Expanded child, so it gets an unbounded
    // max width to size itself however it likes. Measure the window instead.
    final showLabels = MediaQuery.sizeOf(context).width >= 900;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: showLabels ? 248 : 78,
      padding: EdgeInsets.fromLTRB(
        showLabels ? 18 : 14,
        26,
        showLabels ? 18 : 14,
        20,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.surfaceHigh)),
      ),
      child: Column(
        crossAxisAlignment: showLabels
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF4B23E), Color(0xFFEC8A2D)],
                  ),
                ),
                child: SvgPicture.asset(
                  'assets/brand/qa_icon.svg',
                  width: 20,
                  height: 22,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
              if (showLabels) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.qiraahArabiyyah,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kidsStyle(
                      context,
                      size: 15,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Geo.gapLg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < 5; i++)
                  _navItem(context, i, labels[i], showLabels),
              ],
            ),
          ),
          const SizedBox(height: Geo.gapSm),
          _streakCard(context, prog.streakDays, showLabels),
          const SizedBox(height: Geo.gapSm),
          _appearanceRow(context),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int i, String label, bool showLabels) {
    final p = kidsPal(context);
    final on = i == tab;
    final item = Material(
      color: on ? p.accent.withValues(alpha: .14) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => onGo(i),
        child: !showLabels
            ? SizedBox(
                width: 50,
                height: 46,
                child: Icon(
                  _icons[i],
                  size: 21,
                  color: on ? p.accent : p.textDim,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(_icons[i], size: 20, color: on ? p.accent : p.textDim),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: kidsStyle(
                          context,
                          size: 14.5,
                          weight: on ? FontWeight.w800 : FontWeight.w600,
                          color: on ? p.accent : p.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: !showLabels
          ? Center(
              child: Tooltip(message: label, child: item),
            )
          : item,
    );
  }

  Widget _streakCard(BuildContext context, int days, bool showLabels) {
    final p = kidsPal(context);
    if (!showLabels) {
      return Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.amber.withValues(alpha: .18),
        ),
        child: const Icon(
          Icons.local_fire_department_rounded,
          color: Color(0xFFEC6A4B),
          size: 22,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.amber.withValues(alpha: .16),
        border: Border.all(color: p.amber.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.streakDaysCount(days),
                style: kidsStyle(context, size: 15, weight: FontWeight.w800),
              ),
              Text(
                context.l10n.kidsCurrentStreak,
                style: kidsStyle(context, size: 10, color: p.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceRow(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = kidsPal(context);
    return Row(
      children: [
        for (final (mode, icon) in [
          ('light', Icons.wb_sunny_rounded),
          ('dark', Icons.dark_mode_rounded),
          ('oled', Icons.brightness_2_rounded),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => s.update(() => s.kidsThemeMode = mode),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.kidsThemeMode == mode
                        ? p.accent.withValues(alpha: .16)
                        : p.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: s.kidsThemeMode == mode ? p.accent : p.surfaceHigh,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: s.kidsThemeMode == mode ? p.accent : p.textDim,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String? overlayTitle;
  final VoidCallback onBack;
  final VoidCallback onAvatarTap;
  const _TopBar({
    required this.overlayTitle,
    required this.onBack,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.surfaceHigh)),
      ),
      child: overlayTitle != null
          ? Row(
              children: [
                Material(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: p.surfaceHigh),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  overlayTitle!,
                  style: kidsStyle(context, size: 16, weight: FontWeight.w800),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.kidsMarhaba,
                        style: kidsStyle(
                          context,
                          size: 12,
                          weight: FontWeight.w700,
                          color: p.textDim,
                        ),
                      ),
                      Text(
                        context.l10n.kidsHelloName(
                          s.activeKidsProfile?.name ?? '',
                        ),
                        style: kidsStyle(
                          context,
                          size: 18,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: p.amber.withValues(alpha: .16),
                    border: Border.all(color: p.amber.withValues(alpha: .3)),
                    borderRadius: BorderRadius.circular(Geo.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond_rounded,
                        size: 15,
                        color: Color(0xFFC77A12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${prog.gems}',
                        style: kidsStyle(
                          context,
                          size: 13.5,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TapScale(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4B23E), Color(0xFFEC8A2D)],
                      ),
                    ),
                    child: s.activeKidsProfile == null
                        ? const Text('🦊', style: TextStyle(fontSize: 17))
                        : KidsAvatar(
                            profile: s.activeKidsProfile!, size: 17),
                  ),
                ),
              ],
            ),
    );
  }
}
