import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart' show KidsTextScale;
import '../../data/kids_content.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import '../../kids_backdrops/kb_screens.dart' show KbPage;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_desktop_nav.dart';
import 'kids_parent_gate.dart';
import 'kids_parent_report.dart';
import 'kids_path.dart';
import 'kids_profile_picker.dart';
import 'kids_widgets.dart';

/// The Me tab: profile, level, lifetime stats, and Kids Mode's own
/// Light/Dark/OLED appearance picker — independent of the grown-up app's
/// theme (see `kidsPal`/`s.kidsThemeMode`). Also the one place a parent can
/// switch children or leave Kids Mode, both gated behind the arithmetic
/// parent gate.
class KidsMeScreen extends StatelessWidget {
  const KidsMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final ui = kbUi(context);
    final profile = s.activeKidsProfile!;
    final desktop = useDesktop(context);

    Widget grid3(List<Widget> tiles) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, t) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: t),
            ],
          ],
        );
    Widget section(String title) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: KbHeading(title, ui: ui, fontSize: 21));

    // The design's Me screen (kb_screens.dart `KbMeScreen`), same order and
    // gaps, with the app's own Detail dial and parent actions after it.
    return KbPage(top: desktop ? 40 : 50, cross: CrossAxisAlignment.stretch, children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The avatar carries the developer unlock gesture as well as
              // the mascot does, because this screen is reachable from a
              // fresh install — the mascot only appears once a lesson has
              // been finished, which is the very thing the unlock is for.
              //
              // On a solid disc, not loose on the scene: the avatar is the
              // one image on this screen and must read on every backdrop.
              Center(
                child: KidsSecretUnlock(
                  child: KbSurface(
                    color: ui.surface,
                    edge: ui.edge,
                    elev: KbElev.cardHi,
                    circle: true,
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    child: KidsAvatar(profile: profile, size: 96 / 1.15),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(child: KbHeading(profile.name, ui: ui, fontSize: 32)),
              const SizedBox(height: 6),
              Center(
                  child: KbSubtitle(context.l10n.kidsLevelLabel(prog.level),
                      ui: ui)),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, (label, value)) in [
                      (context.l10n.kidsStatXp, '${prog.xp}'),
                      (context.l10n.kidsStatStreak, '${prog.streakDays}'),
                      (
                        context.l10n.kidsStatLetters,
                        '${prog.kidsLettersLearned}/${kidsLetterPath.length}'
                      ),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                          child: KbStatTile(ui: ui, value: value, label: label)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              section(context.l10n.kidsAppearance),
              const SizedBox(height: 12),
              grid3([
                for (final (label, value, icon) in [
                  (context.l10n.themeLight, 'light', 'light_mode'),
                  (context.l10n.themeDark, 'dark', 'dark_mode'),
                  (context.l10n.themeOled, 'oled', 'bedtime'),
                ])
                  KbOptionTile(
                    ui: ui,
                    selected: s.kidsThemeMode == value,
                    label: label,
                    onTap: () => s.update(() => s.kidsThemeMode = value),
                    top: KbIcon(icon,
                        size: 28,
                        color: KbOptionTile.inkOf(ui, s.kidsThemeMode == value)),
                  ),
              ]),
              const SizedBox(height: 24),
              section(context.l10n.kidsTextSize),
              const SizedBox(height: 12),
              const KidsTextSizePicker(),
              const SizedBox(height: 24),
              // Painted backdrops, raised cards, the bigger celebration — a
              // three-way dial rather than a switch. Plain gives back exactly
              // the flat, faster look every screen had before it; medium keeps
              // the scene but nothing moves; high is the full thing (see
              // `KidsBackdrop`). In a card: the dial comes with a full sentence
              // of explanation, and only headings may sit straight on the scene.
              KbSurface(
                color: ui.surface,
                edge: ui.edge,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.kidsDetailLevel,
                        style: kbText(20, kbC(ui.ink))),
                    const SizedBox(height: 4),
                    Text(context.l10n.kidsDetailLevelSub,
                        style: kbText(16, kbC(ui.inkSoft),
                            weight: FontWeight.w600, height: 1.35)),
                    const SizedBox(height: 16),
                    const KidsDetailPicker(),
                    // Ultra is the one level where the pages lean with the
                    // phone; how much is a comfort matter, so it is a choice.
                    if (s.kidsDetail == KidsDetail.ultra) ...[
                      const SizedBox(height: 20),
                      Text(context.l10n.kidsUiTilt,
                          style: kbText(18, kbC(ui.ink))),
                      const SizedBox(height: 4),
                      Text(context.l10n.kidsUiTiltSub,
                          style: kbText(16, kbC(ui.inkSoft),
                              weight: FontWeight.w600, height: 1.35)),
                      const SizedBox(height: 12),
                      const KidsUiTiltPicker(),
                    ],
                  ],
                ),
              ),
              // Full screen: the app-wide immersive mode (`settings.immersive`,
              // applied by main.dart's _SystemUiSync), so the choice is the same
              // one the grown-up app's toggle makes. Phones and tablets only —
              // a desktop window has no system bars to hide.
              if (!isDesktopPlatform()) ...[
                const SizedBox(height: 14),
                MergeSemantics(
                  child: KbSettingCard(
                    key: const ValueKey('kids.immersive'),
                    ui: ui,
                    title: context.l10n.kidsImmersive,
                    desc: context.l10n.kidsImmersiveSub,
                    trailing: KbToggle(
                      value: s.immersive,
                      ui: ui,
                      onChanged: (v) => s.update(() => s.immersive = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _ActionRow(
                icon: 'group',
                label: context.l10n.kidsSwitchProfile,
                onTap: () => pushKidsOverlay(
                  context,
                  title: context.l10n.kidsSwitchProfile,
                  // The builder's OWN context, not the outer KidsMeScreen
                  // one — by the time onDone fires, KidsMeScreen (tab 4)
                  // has been unmounted, since showing the overlay swaps
                  // the whole IndexedStack out for this builder. Only a
                  // context from inside the still-mounted overlay itself
                  // is safe to look up KidsDesktopOverlay from.
                  builder: (overlayContext) => KidsProfilePicker(
                    canCancel: true,
                    onDone: () => closeKidsOverlayOrPop(overlayContext),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ActionRow(
                icon: 'insights',
                label: context.l10n.kidsParentReport,
                onTap: () async {
                  // The report is for the grown-up, so it sits behind the
                  // same gate as leaving Kids Mode.
                  final ok = await showKidsParentGate(context);
                  if (!ok || !context.mounted) return;
                  pushKidsOverlay(
                    context,
                    title: context.l10n.kidsParentReport,
                    builder: (_) => const KidsParentReport(),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ActionRow(
                icon: 'exit_to_app',
                label: context.l10n.kidsExitToParentApp,
                onTap: () async {
                  final ok = await showKidsParentGate(context);
                  if (ok) s.disableKidsMode();
                },
              ),
              // The testing unlock says so out loud while it is on. It
              // changes what the whole Learn tab looks like, so leaving it
              // silent would make a stage that was never played look like
              // one that was simply reached.
              if (prog.unlockAll) ...[
                const SizedBox(height: 14),
                _ActionRow(
                  icon: 'lock_open',
                  label: context.l10n.kidsDevUnlockBanner,
                  onTap: () => kidsSetTestUnlock(context, false),
                ),
                const SizedBox(height: 14),
                _ActionRow(
                  icon: 'switch_access_shortcut',
                  label: prog.devStage == null
                      ? context.l10n.kidsDevJumpStage
                      : context.l10n.kidsDevJumpStageActive(
                          kidsPath(context)
                              .firstWhere((b) => b.id == prog.devStage)
                              .title(context),
                        ),
                  onTap: () => pushKidsOverlay(
                    context,
                    title: context.l10n.kidsDevJumpStage,
                    builder: (overlayContext) => _DevStagePicker(
                      onDone: () => closeKidsOverlayOrPop(overlayContext),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ]);
  }
}

/// The testing unlock's stage jump: a flat list of every [KidsBlock], so a
/// tester can point Home and the Learn tab's "current" row at any stage
/// (`ProgressStore.devStage`) without actually clearing everything before it.
/// Only reachable while the testing unlock is on — see [KidsMeScreen] — and
/// touches nothing about real progress, same as the unlock itself.
class _DevStagePicker extends StatelessWidget {
  final VoidCallback onDone;
  const _DevStagePicker({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final path = kidsPath(context);
    final desktop = KidsDesktopOverlay.maybeOf(context) != null;

    Widget list(BuildContext context) {
      final ui = kbUi(context);
      return KbPage(top: desktop ? 20 : 52, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
        if (!desktop) ...[
          Row(children: [
            KbRoundButton(
                Directionality.of(context) == TextDirection.rtl
                    ? 'arrow_forward'
                    : 'arrow_back',
                ui: ui,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 16),
            Flexible(
                child: KbHeading(context.l10n.kidsDevJumpStage,
                    ui: ui, fontSize: 30)),
          ]),
          const SizedBox(height: 20),
        ],
        KbSurface(
          color: ui.surface,
          edge: ui.edge,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Text(context.l10n.kidsDevJumpStageHint,
              style: kbText(16, kbC(ui.inkSoft),
                  weight: FontWeight.w600, height: 1.35)),
        ),
        const SizedBox(height: 16),
        _ActionRow(
          icon: 'replay',
          label: context.l10n.kidsDevJumpStageFollow,
          onTap: () {
            prog.setDevStage(null);
            onDone();
          },
        ),
        for (final block in path) ...[
          const SizedBox(height: 12),
          KbSurface(
            key: ValueKey('kids.devstage.${block.id}'),
            color: ui.surface,
            edge: prog.devStage == block.id ? ui.accentEdge : ui.edge,
            outline: prog.devStage == block.id ? ui.accent : null,
            radius: 22,
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            onTap: () {
              prog.setDevStage(block.id);
              onDone();
            },
            child: Row(children: [
              KbGlyphTile(block.badge,
                  size: 44, radius: 14, fontSize: 20,
                  bg: ui.tile, ink: ui.tileInk),
              const SizedBox(width: 14),
              Expanded(
                child: Text(block.title(context),
                    style: kbText(18, kbC(ui.ink), height: 1.15)),
              ),
              if (prog.devStage == block.id)
                KbDot('check', bg: ui.cardDeep, ink: kWhite),
            ]),
          ),
        ],
      ]);
    }

    if (desktop) return Builder(builder: list);
    return KidsTextScale(
      child: Scaffold(
        backgroundColor: kbPageBg(kbUi(context)),
        body: KidsBackdrop(child: Builder(builder: list)),
      ),
    );
  }
}

/// One of the Me tab's actions (switch child, parent report, leave): a row
/// card with its symbol in a glyph tile and a chevron.
class _ActionRow extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Row(
        children: [
          KbGlyphTile(icon,
              icon: true,
              size: 44,
              radius: 14,
              fontSize: 24,
              bg: ui.tile,
              ink: ui.tileInk),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: kbText(19, kbC(ui.ink), height: 1.15)),
          ),
          KbIcon(rtl ? 'chevron_left' : 'chevron_right',
              size: 28, color: kbC(ui.inkSoft)),
        ],
      ),
    );
  }
}
