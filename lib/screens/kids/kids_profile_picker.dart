import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'kids_desktop_nav.dart';

const _avatarChoices = ['🦊', '🐼', '🐯', '🦁', '🐨', '🐸', '🦄', '🐬'];

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

  Widget _body(BuildContext context, bool creating) {
    final s = SettingsScope.of(context);
    return creating
        ? _CreateProfileForm(
            onCreated: widget.onDone,
            onCancel: s.kidsProfiles.isEmpty
                ? null
                : () => setState(() => _creating = false),
          )
        : _ProfileGrid(
            onAdd: () => setState(() => _creating = true),
            onPick: (id) {
              s.setActiveKidsProfile(id);
              widget.onDone();
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final creating = _creating ?? SettingsScope.of(context).kidsProfiles.isEmpty;
    final title = creating
        ? context.l10n.kidsNewProfileTitle
        : context.l10n.kidsWhosLearning;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style:
                        kidsStyle(context, size: 19, weight: FontWeight.w800)),
                const SizedBox(height: Geo.gapMd),
                Expanded(child: _body(context, creating)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: widget.canCancel && !creating,
        title: Text(title,
            style: kidsStyle(context, size: 19, weight: FontWeight.w800)),
      ),
      body: SafeArea(child: _body(context, creating)),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  final VoidCallback onAdd;
  final void Function(String id) onPick;
  const _ProfileGrid({required this.onAdd, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = kidsPal(context);
    return GridView.count(
      padding: const EdgeInsets.all(Geo.gapLg),
      crossAxisCount: 3,
      mainAxisSpacing: Geo.gapMd,
      crossAxisSpacing: Geo.gapMd,
      children: [
        for (final profile in s.kidsProfiles)
          TapScale(
            onTap: () => onPick(profile.id),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Geo.radiusLg),
                border: Border.all(
                    color: profile.id == s.activeKidsProfileId
                        ? p.accent
                        : Colors.transparent,
                    width: 2),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(profile.avatar, style: const TextStyle(fontSize: 34)),
                  const SizedBox(height: 6),
                  Text(profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kidsStyle(context,
                          size: 13, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        TapScale(
          onTap: onAdd,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Geo.radiusLg),
              border: Border.all(color: p.surfaceHigh, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: p.textDim, size: 30),
                const SizedBox(height: 4),
                Text(context.l10n.kidsAddProfile,
                    style: kidsStyle(context, size: 11.5, color: p.textDim)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateProfileForm extends StatefulWidget {
  final VoidCallback onCreated;
  final VoidCallback? onCancel;
  const _CreateProfileForm({required this.onCreated, this.onCancel});

  @override
  State<_CreateProfileForm> createState() => _CreateProfileFormState();
}

class _CreateProfileFormState extends State<_CreateProfileForm> {
  final _name = TextEditingController();
  String _avatar = _avatarChoices.first;
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

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_avatar, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: Geo.gapMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _avatarChoices)
                TapScale(
                  onTap: () => setState(() => _avatar = a),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a == _avatar
                          ? p.accent.withValues(alpha: .18)
                          : p.surface,
                      border: Border.all(
                          color: a == _avatar ? p.accent : p.surfaceHigh,
                          width: 2),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Geo.gapLg),
          TextField(
            controller: _name,
            autofocus: true,
            style: kidsStyle(context, size: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: p.surface,
              hintText: context.l10n.kidsNameHint,
              hintStyle: kidsStyle(context, size: 15, color: p.textDim),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Geo.radiusMd),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: Geo.gapMd),
          Text(context.l10n.kidsGenderPrompt,
              style: kidsStyle(context, size: 12.5, color: p.textDim)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (label, value) in [
              (context.l10n.kidsGenderBoy, 'm'),
              (context.l10n.kidsGenderGirl, 'f'),
              (context.l10n.kidsGenderSkip, ''),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                // Explicit colors, not the ambient ChoiceChip theme — same
                // reason every other ChoiceChip in this app (about_screen.dart,
                // dyslexia_screen.dart) sets its own: with no chip theme
                // customized, Material 3's default renders as a near-black
                // pill, which reads as broken against Kids Mode's warm palette.
                child: ChoiceChip(
                  label: Text(label),
                  selected: _gender == value,
                  selectedColor: p.accent,
                  backgroundColor: p.surface,
                  side: BorderSide(color: p.surfaceHigh),
                  labelStyle: kidsStyle(context,
                      size: 13,
                      weight: FontWeight.w700,
                      color: _gender == value ? Colors.white : p.text),
                  onSelected: (_) => setState(() => _gender = value),
                ),
              ),
          ]),
          const SizedBox(height: Geo.gapXl),
          AnimatedBuilder(
            animation: _name,
            builder: (context, _) => FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _name.text.trim().isEmpty ? null : _submit,
              child: Text(context.l10n.kidsStartLearning),
            ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(height: 8),
            TextButton(
                onPressed: widget.onCancel, child: Text(context.l10n.cancel)),
          ],
        ],
      ),
    );
  }
}
