import 'package:flutter/material.dart';

import '../core/fluency/fluency_store.dart';
import '../core/l10n.dart';
import '../core/marks/marks_store.dart';
import '../core/profiles.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/adaptive_sheet.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';

/// [p]'s name, the default profile's "Me" until named.
String profileName(BuildContext context, Profile p) =>
    p.name.isEmpty ? context.l10n.prfMe : p.name;

/// A profile's round badge: its initial on its hue.
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  const ProfileAvatar({super.key, required this.profile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final name = profileName(context, profile);
    final c = HSLColor.fromAHSL(1, profile.hue.toDouble() % 360, .45, .42).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: .16), shape: BoxShape.circle),
      child: Text(name.characters.first.toUpperCase(),
          style: uiStyle(context, size: size * .42, weight: FontWeight.w700, color: c)),
    );
  }
}

/// Settings' row for the profiles: who's using the app, and the sheet.
class ProfilesRow extends StatelessWidget {
  const ProfilesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = ProfileScope.maybeOf(context);
    if (profiles == null) return const SizedBox.shrink();
    final p = profiles.active;
    return QGroup(children: [
      QRow(
        leading: ProfileAvatar(profile: p, size: 34),
        title: profileName(context, p),
        subtitle: context.l10n.prfSub,
        chevron: true,
        onTap: () => showProfilesSheet(context),
      ),
    ]);
  }
}

/// The profiles on this device: switch, add, rename, delete.
Future<void> showProfilesSheet(BuildContext context) {
  final profiles = ProfileScope.maybeOf(context);
  if (profiles == null) return Future.value();
  return showAdaptiveSheet<void>(
    context,
    builder: (sheet) => _ProfilesSheet(profiles: profiles, host: context),
  );
}

class _ProfilesSheet extends StatelessWidget {
  final ProfileStore profiles;

  /// Where the stores are (the sheet's own context is under its route).
  final BuildContext host;
  const _ProfilesSheet({required this.profiles, required this.host});

  Future<void> _switch(BuildContext sheet, Profile p) async {
    final settings = SettingsScope.of(host);
    final progress = ProgressScope.read(host);
    final marks = MarksScope.maybeOf(host);
    final nav = Navigator.of(host, rootNavigator: true);
    Navigator.pop(sheet);
    await profiles.switchTo(p.id,
        settings: settings,
        progress: progress,
        marks: marks,
        fluency: FluencyScope.read(host));
    // Back to the profile's home (its mode, its page).
    nav.popUntil((r) => r.isFirst);
    if (host.mounted) {
      showQToast(host, host.l10n.prfNow(profileName(host, p)));
    }
  }

  Future<String?> _askName(BuildContext context, {String initial = ''}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(initial.isEmpty ? d.l10n.prfAdd : d.l10n.prfRename),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: d.l10n.prfName),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(d.l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(d, c.text), child: Text(MaterialLocalizations.of(d).okButtonLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(context.l10n.prfTitle, style: displayStyle(context, size: 24)),
            const SizedBox(height: 4),
            Text(context.l10n.prfSub, style: uiStyle(context, size: 13, color: p.ink3)),
            const SizedBox(height: 14),
            for (final x in profiles.profiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: QCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  color: x.id == profiles.active.id ? p.accSoft : null,
                  borderColor: x.id == profiles.active.id ? p.acc : null,
                  onTap: x.id == profiles.active.id ? null : () => _switch(context, x),
                  child: Row(children: [
                    ProfileAvatar(profile: x),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profileName(context, x),
                            style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                        FutureBuilder<int?>(
                          future: profiles.lastPageOf(x.id),
                          builder: (context, page) => Text(
                            [
                              if (page.data != null) context.l10n.pageN(page.data!),
                              if (x.lastUsedAt > 0)
                                MaterialLocalizations.of(context).formatMediumDate(
                                    DateTime.fromMillisecondsSinceEpoch(x.lastUsedAt)),
                            ].join(' · '),
                            style: uiStyle(context, size: 12.5, color: p.ink3),
                          ),
                        ),
                      ]),
                    ),
                    if (x.id == profiles.active.id) Icon(AppIcons.check, color: p.acc),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'rename') {
                          final n = await _askName(context, initial: profileName(context, x));
                          if (n != null && n.trim().isNotEmpty) profiles.rename(x.id, n);
                        } else if (v == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              content: Text(d.l10n.prfDeleteQ(profileName(d, x))),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: Text(d.l10n.cancel)),
                                TextButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: Text(d.l10n.prfDelete)),
                              ],
                            ),
                          );
                          if (ok == true) profiles.remove(x.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(context.l10n.prfRename)),
                        if (x.id != ProfileStore.defaultId && x.id != profiles.active.id)
                          PopupMenuItem(value: 'delete', child: Text(context.l10n.prfDelete)),
                      ],
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: QOutlineButton(context.l10n.prfAdd, icon: AppIcons.add, onTap: () async {
                final n = await _askName(context);
                if (n == null || n.trim().isEmpty) return;
                final x = await profiles.add(n);
                if (context.mounted) await _switch(context, x);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
