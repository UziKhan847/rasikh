import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kBlack, kWhite, kbC;
import '../../kids_backdrops/kb_ui.dart' show KbUi, kbCssBlur;
import '../../kids_backdrops/kb_widgets.dart' show KbAvatar, KbHeading;
import 'kids_alphabet_screen.dart';
import 'kids_desktop_nav.dart';
import 'kids_home_screen.dart';
import 'kids_me_screen.dart';
import 'kids_profile_gate.dart';
import 'kids_rank_screen.dart';
import 'kids_rewards_screen.dart';
import 'kids_avatar_face.dart';
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
        child: KidsTextScale(child: KidsProfileGate(
          builder: (context) {
          return KidsDesktopOverlay(
            open: _openOverlay,
            close: _closeOverlay,
            child: Scaffold(
              backgroundColor: kbPageBg(kbUi(context)),
              // bottom only: an edge-to-edge Android tablet's gesture pill or
              // 3-button nav bar draws right over the sidebar's streak card
              // and over lesson content (e.g. the tracing flow's "Next"
              // button) that sits flush to the pane's own bottom edge.
              body: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _Sidebar(tab: _tab, onGo: _go),
                    // The content pane over the scene — the backdrop behind
                    // every Kids screen, with the top bar on its sky.
                    Expanded(
                      child: KidsBackdrop(child: Column(
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
                      )),
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        )),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int tab;
  final void Function(int) onGo;
  const _Sidebar({required this.tab, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
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
    // The phone's nav bar, stood on its side: a solid surface panel with a
    // soft shadow (kb_components.dart `KbNavBar`).
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
        color: kbC(ui.surface),
        boxShadow: [
          BoxShadow(
              color: kbC(kBlack, .18),
              offset: const Offset(8, 0),
              blurRadius: kbCssBlur(24)),
        ],
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
                  color: kbC(ui.cardDeep),
                  boxShadow: [
                    BoxShadow(
                        color: kbC(ui.cardDeepEdge), offset: const Offset(0, 3)),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/brand/qa_icon.svg',
                  width: 20,
                  height: 22,
                  colorFilter: ColorFilter.mode(kbC(kWhite), BlendMode.srcIn),
                ),
              ),
              if (showLabels) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.qiraahArabiyyah,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kbText(17, kbC(ui.ink)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < 5; i++)
                  _navItem(context, ui, i, labels[i], showLabels),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _streakCard(context, ui, prog.streakDays, showLabels),
          const SizedBox(height: 10),
          _appearanceRow(context, ui),
          const SizedBox(height: 10),
          const KidsTextSizePicker(compact: true),
        ],
      ),
    );
  }

  /// One nav item — the design's nav: the selected one on the tile colour in
  /// tile ink, the rest soft ink.
  Widget _navItem(
      BuildContext context, KbUi ui, int i, String label, bool showLabels) {
    final on = i == tab;
    final ink = kbC(on ? ui.tileInk : ui.inkSoft);
    final icon = KbIcon(kbNavItems[i].icon, size: 24, color: ink);
    final item = Semantics(
      button: true,
      selected: on,
      label: showLabels ? null : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onGo(i),
        child: Container(
          decoration: BoxDecoration(
            color: on ? kbC(ui.tile) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: !showLabels
              ? SizedBox(width: 52, height: 46, child: Center(child: icon))
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: kbText(16, ink,
                              weight: on ? FontWeight.w800 : FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: !showLabels
          ? Center(
              child: Tooltip(message: label, child: item),
            )
          : item,
    );
  }

  /// The streak, on the tile colour.
  Widget _streakCard(
      BuildContext context, KbUi ui, int days, bool showLabels) {
    if (!showLabels) {
      return Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kbC(ui.tile),
        ),
        child: KbIcon('local_fire_department',
            size: 24, color: kbC(ui.accent)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kbC(ui.tile),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KbIcon('local_fire_department', size: 24, color: kbC(ui.accent)),
          const SizedBox(width: 8),
          // Flexible + ellipsis: the sidebar is a fixed width, and at the
          // Large text size these two lines outgrew it.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.streakDaysCount(days),
                  overflow: TextOverflow.ellipsis,
                  style: kbText(17, kbC(ui.tileInk), height: 1.1),
                ),
                Text(
                  context.l10n.kidsCurrentStreak,
                  overflow: TextOverflow.ellipsis,
                  style: kbText(12, kbC(ui.tileInk), weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Light / Dark / OLED — small option tiles: the selected one on the tile
  /// colour with the accent ring.
  Widget _appearanceRow(BuildContext context, KbUi ui) {
    final s = SettingsScope.of(context);
    return Row(
      children: [
        for (final (i, (mode, icon)) in [
          ('light', 'light_mode'),
          ('dark', 'dark_mode'),
          ('oled', 'bedtime'),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: KbSurface(
              color: s.kidsThemeMode == mode ? ui.tile : ui.surface,
              edge: s.kidsThemeMode == mode ? ui.accentEdge : ui.edge,
              outline: s.kidsThemeMode == mode ? ui.accent : null,
              outlineWidth: 2,
              elev: KbElev.edge3,
              radius: 12,
              padding: const EdgeInsets.symmetric(vertical: 7),
              alignment: Alignment.center,
              onTap: () => s.update(() => s.kidsThemeMode = mode),
              child: KbIcon(icon,
                  size: 18,
                  color: KbOptionTile.inkOf(ui, s.kidsThemeMode == mode)),
            ),
          ),
        ],
      ],
    );
  }
}

/// The content pane's top bar, on the scene: the greeting as subtitle and
/// heading, the design's gem counter and the avatar in its surface circle —
/// or, over a lesson, the round back button and the lesson's name.
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
    final ui = kbUi(context);
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: overlayTitle != null
            ? Row(
                children: [
                  KbRoundButton(rtl ? 'arrow_forward' : 'arrow_back',
                      ui: ui,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onTap: onBack),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KbHeading(overlayTitle!,
                        ui: ui, fontSize: 24, height: 1.1),
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
                        KbSubtitle(context.l10n.kidsMarhaba,
                            ui: ui, fontSize: 16),
                        KbHeading(
                          context.l10n.kidsHelloName(
                            s.activeKidsProfile?.name ?? '',
                          ),
                          ui: ui,
                          fontSize: 24,
                        ),
                      ],
                    ),
                  ),
                  KbGemCounter(prog.gems, ui: ui),
                  const SizedBox(width: 14),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onAvatarTap,
                      child: KbAvatar(
                        size: 46,
                        background: kbC(ui.surface),
                        face: (d) => s.activeKidsProfile == null
                            ? KidsAvatarFace('🦊', size: d / 1.15)
                            : KidsAvatar(
                                profile: s.activeKidsProfile!, size: d / 1.15),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
