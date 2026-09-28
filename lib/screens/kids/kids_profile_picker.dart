import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../data/kids_avatars.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../kids_backdrops/kb_screens.dart' show KbPage;
import '../../kids_backdrops/kb_widgets.dart';
import 'kids_avatar_face.dart';
import 'kids_desktop_nav.dart';
import 'kids_widgets.dart';

/// Real animals only — the unicorn that used to sit here was the same
/// mistake the shop briefly made with a dragon and a superhero cape: mythical
/// and fantasy imagery does not belong in a muṣḥaf-learning app. Several of
/// these are named in the Qurʼān (the horse in al-ʿĀdiyāt, the frog in
/// al-Aʿrāf 7:133, the lion in al-Muddaththir 74:51), as are the extra
/// avatars the shop unlocks — see `kidsShopItems` in `data/kids_content.dart`.
///
/// These are the avatars a new profile can pick for free. Each has drawn art
/// (`kids_avatars.dart`); the shop sells the rest.
const kidsAvatarChoices = ['🦊', '🐼', '🐯', '🦁', '🐨', '🐸', '🐴', '🐬'];

/// "Who's learning?" — the family-profile picker Kids Mode opens with. With
/// no profile yet (a brand-new install) it goes straight to the creation
/// form; otherwise it shows every existing profile plus an "Add" tile, so
/// several children in one household can each keep their own progress, XP,
/// gems and badges (see `ProgressStore.profileId`).
class KidsProfilePicker extends StatefulWidget {
  final VoidCallback onDone;
  final bool canCancel;
  const KidsProfilePicker(
      {super.key, required this.onDone, this.canCancel = false});

  @override
  State<KidsProfilePicker> createState() => _KidsProfilePickerState();
}

class _KidsProfilePickerState extends State<KidsProfilePicker> {
  // Nullable so the SettingsScope-dependent default (skip straight to the
  // creation form when there's no profile yet) can be computed in
  // didChangeDependencies — InheritedWidget lookups aren't valid in
  // initState — rather than hardcoded before we know the answer.
  bool? _creating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _creating ??= SettingsScope.of(context).kidsProfiles.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final creating = _creating ?? SettingsScope.of(context).kidsProfiles.isEmpty;
    final title = creating
        ? context.l10n.kidsNewProfileTitle
        : context.l10n.kidsWhosLearning;
    final back = widget.canCancel && !creating ? () => Navigator.maybePop(context) : null;

    // Reached two ways: directly from KidsProfileGate (no profile yet — both
    // shells, needs its own full Scaffold since no shell chrome exists around
    // it yet) or via pushKidsOverlay from "Switch profile" once a shell is
    // already up. Branch on whether a KidsDesktopOverlay ancestor actually
    // exists, not on useDesktop() — that's what tells the two cases apart.
    if (KidsDesktopOverlay.maybeOf(context) != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(Geo.gapXl),
            child: _body(context, creating, title, null),
          ),
        ),
      );
    }

    // The design's page: title on the sky, content scrolling over the scene.
    return Scaffold(
      backgroundColor: kbPageBg(kbUi(context)),
      body: KidsBackdrop(child: _body(context, creating, title, back)),
    );
  }

  Widget _body(BuildContext context, bool creating, String title, VoidCallback? back) {
    final s = SettingsScope.of(context);
    return Builder(builder: (context) {
      final ui = kbUi(context);
      final heading = Row(children: [
        if (back != null) ...[
          KbRoundButton(
              Directionality.of(context) == TextDirection.rtl
                  ? 'arrow_forward'
                  : 'arrow_back',
              ui: ui,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: back),
          const SizedBox(width: 16),
        ],
        Flexible(child: KbHeading(title, ui: ui, fontSize: 30)),
      ]);
      return creating
          ? _CreateProfileForm(
              heading: heading,
              onCreated: widget.onDone,
              onCancel: s.kidsProfiles.isEmpty
                  ? null
                  : () => setState(() => _creating = false),
            )
          : _ProfileGrid(
              heading: heading,
              onAdd: () => setState(() => _creating = true),
              onPick: (id) {
                s.setActiveKidsProfile(id);
                widget.onDone();
              },
            );
    });
  }
}

/// "Who's learning?" — every profile as a tile, plus Add. The design has no
/// screen for this, so it is built from the kit's own rules: solid tiles with a
/// hard edge, the active child's tile selected (tile face, accent ring, accent
/// edge), each avatar in a surface circle.
class _ProfileGrid extends StatelessWidget {
  final Widget heading;
  final VoidCallback onAdd;
  final void Function(String id) onPick;
  const _ProfileGrid({required this.heading, required this.onAdd, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final ui = kbUi(context);
    Widget cell(bool selected, Widget top, String label, VoidCallback onTap, {Key? key}) => KbSurface(
      key: key,
      color: selected ? ui.tile : ui.surface,
      edge: selected ? ui.accentEdge : ui.edge,
      outline: selected ? ui.accent : null,
      elev: KbElev.tile,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        top,
        const SizedBox(height: 6),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kbText(17, kbC(selected ? ui.tileInk : ui.ink))),
      ]),
    );
    return KbPage(top: 52, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
      heading,
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final profile in s.kidsProfiles)
            SizedBox(
              width: w,
              child: cell(
                profile.id == s.activeKidsProfileId,
                KbAvatar(
                  size: 64,
                  background: kbC(ui.surface),
                  face: (d) => KidsAvatar(profile: profile, size: d / 1.15),
                ),
                profile.name,
                () => onPick(profile.id),
              ),
            ),
          SizedBox(
            width: w,
            child: cell(
              false,
              SizedBox(
                height: 64,
                child: Center(child: KbIcon('add', size: 34, color: kbC(ui.inkSoft))),
              ),
              context.l10n.kidsAddProfile,
              onAdd,
            ),
          ),
        ]);
      }),
    ]);
  }
}

class _CreateProfileForm extends StatefulWidget {
  final Widget heading;
  final VoidCallback onCreated;
  final VoidCallback? onCancel;
  const _CreateProfileForm({required this.heading, required this.onCreated, this.onCancel});

  @override
  State<_CreateProfileForm> createState() => _CreateProfileFormState();
}

class _CreateProfileFormState extends State<_CreateProfileForm> {
  final _name = TextEditingController();
  String _avatar = kidsAvatarChoices.first;
  String _gender = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final s = SettingsScope.of(context);
    s.addKidsProfile(KidsProfile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        avatar: _avatar,
        gender: _gender));
    widget.onCreated();
  }

  /// The animal's name, for the preview — the free choices, which are the only
  /// avatars this form offers.
  String? _animalName(BuildContext context) => switch (kidsAnimalFor(_avatar)?.id) {
    'fox' => context.l10n.kidsAnimalFox,
    'panda' => context.l10n.kidsAnimalPanda,
    'tiger' => context.l10n.kidsAnimalTiger,
    'lion' => context.l10n.kidsAnimalLion,
    'koala' => context.l10n.kidsAnimalKoala,
    'frog' => context.l10n.kidsAnimalFrog,
    'horse' => context.l10n.kidsAnimalHorse,
    'dolphin' => context.l10n.kidsAnimalDolphin,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final name = _animalName(context);
    // The design's New Profile screen (kb_screens.dart `KbProfileScreen`), same
    // widget order and gaps, on the app's own form state.
    return KbPage(top: 52, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
      widget.heading,
      const SizedBox(height: 22),
      Row(children: [
        KbSurface(
          color: ui.surface, edge: ui.edge, elev: KbElev.big, circle: true,
          width: 128, height: 128, alignment: Alignment.center,
          child: KidsAvatarFace(_avatar, size: 108 / 1.15),
        ),
        const SizedBox(width: 18),
        if (name != null)
          Flexible(
            child: Text(name,
                style: kbText(24, kbC(ui.headInk), height: 1.1, shadows: ui.headShadows)),
          ),
      ]),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, c) {
        const gapX = 8.0, gapY = 10.0, cols = 6;
        final w = (c.maxWidth - gapX * (cols - 1)) / cols;
        return Wrap(spacing: gapX, runSpacing: gapY, children: [
          for (final a in kidsAvatarChoices)
            SizedBox(
              width: w,
              child: KbAvatarPickerTile(
                key: ValueKey('kidsAvatarChoice.$a'),
                ui: ui,
                selected: a == _avatar,
                locked: false,
                face: (d) => KidsAvatarFace(a, size: d / 1.15),
                onTap: () => setState(() => _avatar = a),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 24),
      // Deliberately NOT autofocused. This is the only text field in the app,
      // so it was also the only thing that could raise a keyboard — and it did,
      // the instant Kids Mode was switched on for the first time, over the
      // avatar row that is the form's actual first step.
      KbTextField(ui: ui, controller: _name, hint: context.l10n.kidsNameHint),
      const SizedBox(height: 18),
      KbSubtitle(context.l10n.kidsGenderPrompt, ui: ui, fontSize: 18),
      const SizedBox(height: 12),
      // A Wrap: three chips are wider than a 320px phone at the Large text
      // size (and wider still in French).
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (label, value) in [
          (context.l10n.kidsGenderBoy, 'm'),
          (context.l10n.kidsGenderGirl, 'f'),
          (context.l10n.kidsGenderSkip, ''),
        ])
          KbChoiceChip(label, ui: ui, selected: _gender == value,
              onTap: () => setState(() => _gender = value)),
      ]),
      const SizedBox(height: 28),
      AnimatedBuilder(
        animation: _name,
        builder: (context, _) => KbBigButton(
          context.l10n.kidsStartLearning,
          ui: ui,
          enabled: _name.text.trim().isNotEmpty,
          onTap: _submit,
        ),
      ),
      if (widget.onCancel != null) ...[
        const SizedBox(height: 18),
        Center(
          child: KbPill(context.l10n.cancel, ui: ui, elev: KbElev.edge4,
              padding: const EdgeInsets.fromLTRB(20, 7, 20, 5), onTap: widget.onCancel),
        ),
      ],
    ]);
  }
}
