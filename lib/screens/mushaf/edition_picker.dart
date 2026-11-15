import 'package:flutter/material.dart';
import 'package:qiraah_ui/responsive.dart' show isDesktopPlatform;

import '../../core/l10n.dart';
import '../../core/mushaf_edition.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart' show kOldMadani;
import '../../data/original/mushaf_packs.dart';
import '../../ui/app_icons.dart';
import '../../ui/tool_popover.dart';
import 'pack_sheet.dart';

/// Chooses the muṣḥaf: Generated (New Madani, Indo-Pak) or Original (Old
/// and New Madani; Indo-Pak greyed out until it's complete). A
/// printed one whose files aren't here asks for them first ([ensureMushafPack]).
class MushafEditionPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const MushafEditionPicker({super.key, required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context, String script) async {
    if (!await ensureMushafPack(context, script)) return;
    if (context.mounted) onChanged(script);
  }

  /// A print, held: Old Madani's āyah circle, and (desktop, with a folder)
  /// where its files are. Nothing to show: nothing opens.
  void _options(BuildContext anchor, String script) {
    final s = SettingsScope.of(anchor);
    final circle = script == kOldMadani;
    final hasDir = isDesktopPlatform() && MushafPacks.dirOf(script) != null;
    if (!circle && !hasDir) return;
    showToolPopover<void>(anchor, anchor: anchor, side: AxisDirection.up, builder: (pop) {
      final l = pop.l10n;
      Widget row(String id, String label) => ListTile(
            dense: true,
            title: Text(label, style: uiStyle(pop, size: 14.5, weight: FontWeight.w700)),
            trailing: s.oldMadaniCircle == id
                ? Icon(AppIcons.check, size: 18, color: pal(pop).acc)
                : null,
            onTap: () {
              Navigator.pop(pop);
              s.update(() => s.oldMadaniCircle = id);
              _pick(anchor, kOldMadani);
            },
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (circle) ...[
          row('modern', l.edCircleModern),
          row('classic', l.edCircleClassic),
        ],
        // Where its files are: another folder, or none.
        if (hasDir) ...[
          if (circle) const Divider(height: 8),
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_open_rounded, size: 20),
            title: Text(l.packChangeFolder),
            onTap: () async {
              Navigator.pop(pop);
              if (await choosePackFolder(anchor, script) && anchor.mounted) {
                onChanged(script);
              }
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_off_outlined, size: 20),
            title: Text(l.packForgetFolder),
            onTap: () {
              Navigator.pop(pop);
              forgetPackFolder(anchor, script);
              if (value == script) onChanged('uthmani');
            },
          ),
        ],
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget group(String label, List<MushafEdition> editions) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(label,
                  style: uiStyle(context,
                      size: 12.5, weight: FontWeight.w700, color: pal(context).ink3)),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in editions)
                Builder(builder: (chip) {
                  final option = ChoiceChip(
                    label: Text(e.name(l)),
                    selected: e.script == value,
                    showCheckmark: false,
                    onSelected: mushafEditionOn(e) ? (_) => _pick(chip, e.script!) : null,
                  );
                  if (!MushafPacks.scripts.contains(e.script)) return option;
                  // A print, held: its options.
                  return GestureDetector(
                    onLongPress: () => _options(chip, e.script!),
                    onSecondaryTap: () => _options(chip, e.script!),
                    child: option,
                  );
                }),
            ]),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        group(l.edGenerated, kGeneratedEditions),
        const SizedBox(height: 4),
        group(l.edOriginal, kOriginalEditions),
      ],
    );
  }
}
