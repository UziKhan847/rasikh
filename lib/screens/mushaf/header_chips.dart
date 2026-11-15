import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/profiles.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../profiles_sheet.dart';

/// A small toggle in the line above the text, like the view switch beside it:
/// the muṣḥaf's and the Reader's, each in its own colours.
class HeaderChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final void Function(BuildContext anchor) onTap;
  final bool on;
  final Color track, onTrack, ink;
  const HeaderChip({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.on = false,
    required this.track,
    required this.onTrack,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Tooltip(
          message: tooltip,
          child: Builder(
            builder: (anchor) => Material(
              color: on ? onTrack : track,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onTap(anchor),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(icon, size: 13, color: on ? ink : ink.withValues(alpha: .65)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// The profiles, beside [anchor]: a click on a name switches to it.
Future<void> showProfileMenu(BuildContext context, BuildContext anchor) async {
  final profiles = ProfileScope.maybeOf(context);
  if (profiles == null) return;
  final l = context.l10n;
  final p = pal(context);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(rect.left, rect.bottom + 4,
        overlay.size.width - rect.left, overlay.size.height - rect.bottom),
    constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
    items: [
      for (final x in profiles.profiles)
        PopupMenuItem<String>(
          value: x.id,
          height: 36,
          child: Row(children: [
            SizedBox(
              width: 22,
              child: x.id == profiles.active.id
                  ? Icon(AppIcons.check, size: 15, color: p.acc)
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(profileName(context, x),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 13.5)),
            ),
          ]),
        ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem<String>(
        value: '',
        height: 36,
        child: Row(children: [
          SizedBox(width: 22, child: Icon(AppIcons.settings, size: 15, color: p.ink2)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.prfManage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 13.5)),
          ),
        ]),
      ),
    ],
  );
  if (picked == null || !context.mounted) return;
  if (picked.isEmpty) {
    showProfilesSheet(context);
  } else if (picked != profiles.active.id) {
    final who = profiles.profiles.firstWhere((x) => x.id == picked);
    await switchProfile(context, profiles, who);
  }
}
