import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import '../../widgets/common.dart';
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
    final p = kidsPal(context);
    final profile = s.activeKidsProfile!;
    final desktop = useDesktop(context);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(Geo.gapLg, desktop ? Geo.gapXl : Geo.gapMd,
            Geo.gapLg, Geo.gapXl),
        children: [
          if (desktop) const SizedBox(height: Geo.gapLg),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(children: [
                // The avatar carries the developer unlock gesture as well as
                // the mascot does, because this screen is reachable from a
                // fresh install — the mascot only appears once a lesson has
                // been finished, which is the very thing the unlock is for.
                KidsSecretUnlock(
                    child: KidsAvatar(profile: profile, size: 64)),
                const SizedBox(height: 8),
                Text(profile.name,
                    style:
                        kidsStyle(context, size: 19, weight: FontWeight.w800)),
                Text(context.l10n.kidsLevelLabel(prog.level),
                    style: kidsStyle(context, size: 13, color: p.textDim)),
                const SizedBox(height: Geo.gapLg),
                Row(children: [
                  Expanded(
                      child: _StatCard(
                          label: context.l10n.kidsStatXp,
                          value: '${prog.xp}')),
                  const SizedBox(width: Geo.gapSm),
                  Expanded(
                      child: _StatCard(
                          label: context.l10n.kidsStatStreak,
                          value: '${prog.streakDays}')),
                  const SizedBox(width: Geo.gapSm),
                  Expanded(
                      child: _StatCard(
                          label: context.l10n.kidsStatLetters,
                          value:
                              '${prog.kidsLettersLearned}/${kidsLetterPath.length}')),
                ]),
                const SizedBox(height: Geo.gapLg),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(context.l10n.kidsAppearance,
                      style: kidsStyle(context,
                          size: 15, weight: FontWeight.w800)),
                ),
                const SizedBox(height: Geo.gapSm),
                Row(children: [
                  for (final (label, value, icon) in [
                    (context.l10n.themeLight, 'light',
                        Icons.light_mode_rounded),
                    (context.l10n.themeDark, 'dark', Icons.dark_mode_rounded),
                    (context.l10n.themeOled, 'oled',
                        Icons.brightness_2_rounded),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TapScale(
                          onTap: () =>
                              s.update(() => s.kidsThemeMode = value),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: s.kidsThemeMode == value
                                  ? p.accent.withValues(alpha: .16)
                                  : p.surface,
                              borderRadius:
                                  BorderRadius.circular(Geo.radiusMd),
                              border: Border.all(
                                  color: s.kidsThemeMode == value
                                      ? p.accent
                                      : Colors.transparent,
                                  width: 2),
                            ),
                            child: Column(children: [
                              Icon(icon,
                                  color: s.kidsThemeMode == value
                                      ? p.accent
                                      : p.textDim),
                              const SizedBox(height: 4),
                              Text(label,
                                  style: kidsStyle(context,
                                      size: 11.5,
                                      weight: FontWeight.w700,
                                      color: s.kidsThemeMode == value
                                          ? p.accent
                                          : p.textDim)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: Geo.gapLg),
                _ActionRow(
                  icon: Icons.group_rounded,
                  label: context.l10n.kidsSwitchProfile,
                  onTap: () => pushKidsOverlay(context,
                      title: context.l10n.kidsSwitchProfile,
                      // The builder's OWN context, not the outer KidsMeScreen
                      // one — by the time onDone fires, KidsMeScreen (tab 4)
                      // has been unmounted, since showing the overlay swaps
                      // the whole IndexedStack out for this builder. Only a
                      // context from inside the still-mounted overlay itself
                      // is safe to look up KidsDesktopOverlay from.
                      builder: (overlayContext) => KidsProfilePicker(
                          canCancel: true,
                          onDone: () =>
                              closeKidsOverlayOrPop(overlayContext))),
                ),
                const SizedBox(height: Geo.gapSm),
                _ActionRow(
                  icon: Icons.insights_rounded,
                  label: context.l10n.kidsParentReport,
                  onTap: () async {
                    // The report is for the grown-up, so it sits behind the
                    // same gate as leaving Kids Mode.
                    final ok = await showKidsParentGate(context);
                    if (!ok || !context.mounted) return;
                    pushKidsOverlay(context,
                        title: context.l10n.kidsParentReport,
                        builder: (_) => const KidsParentReport());
                  },
                ),
                const SizedBox(height: Geo.gapSm),
                _ActionRow(
                  icon: Icons.exit_to_app_rounded,
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
                  const SizedBox(height: Geo.gapSm),
                  _ActionRow(
                    icon: Icons.lock_open_rounded,
                    label: context.l10n.kidsDevUnlockBanner,
                    onTap: () => prog.setUnlockAll(false),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  _ActionRow(
                    icon: Icons.switch_access_shortcut_rounded,
                    label: prog.devStage == null
                        ? context.l10n.kidsDevJumpStage
                        : context.l10n.kidsDevJumpStageActive(
                            kidsPath(context)
                                .firstWhere((b) => b.id == prog.devStage)
                                .title(context)),
                    onTap: () => pushKidsOverlay(context,
                        title: context.l10n.kidsDevJumpStage,
                        builder: (overlayContext) => _DevStagePicker(
                            onDone: () =>
                                closeKidsOverlayOrPop(overlayContext))),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
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
    final p = kidsPal(context);
    final prog = ProgressScope.of(context);
    final path = kidsPath(context);

    final list = ListView(
      padding: const EdgeInsets.all(Geo.gapLg),
      children: [
        Text(context.l10n.kidsDevJumpStageHint,
            style: kidsStyle(context, size: 12.5, color: p.textDim)),
        const SizedBox(height: Geo.gapMd),
        _ActionRow(
          icon: Icons.replay_rounded,
          label: context.l10n.kidsDevJumpStageFollow,
          onTap: () {
            prog.setDevStage(null);
            onDone();
          },
        ),
        const SizedBox(height: Geo.gapSm),
        for (final block in path)
          Padding(
            padding: const EdgeInsets.only(bottom: Geo.gapSm),
            child: TapScale(
              key: ValueKey('kids.devstage.${block.id}'),
              onTap: () {
                prog.setDevStage(block.id);
                onDone();
              },
              child: Container(
                padding: const EdgeInsets.all(Geo.gapMd),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(Geo.radiusLg),
                  border: Border.all(
                      color: prog.devStage == block.id
                          ? p.accent
                          : Colors.transparent,
                      width: 2),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 36,
                    child: Text(block.badge,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 16, height: 1.05)),
                  ),
                  const SizedBox(width: Geo.gapSm),
                  Expanded(
                      child: Text(block.title(context),
                          style: kidsStyle(context,
                              size: 14.5, weight: FontWeight.w700))),
                  if (prog.devStage == block.id)
                    Icon(Icons.check_rounded, color: p.accent, size: 20),
                ]),
              ),
            ),
          ),
      ],
    );

    if (KidsDesktopOverlay.maybeOf(context) != null) return list;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.l10n.kidsDevJumpStage,
            style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(child: list),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: kidsCard(context),
      child: Column(children: [
        Text(value, style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: kidsStyle(context, size: 10.5, color: p.textDim)),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Geo.gapMd),
        decoration: kidsCard(context),
        child: Row(children: [
          Icon(icon, color: p.textDim),
          const SizedBox(width: Geo.gapMd),
          Expanded(
              child: Text(label,
                  style: kidsStyle(context, size: 14.5, weight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: p.textDim),
        ]),
      ),
    );
  }
}
