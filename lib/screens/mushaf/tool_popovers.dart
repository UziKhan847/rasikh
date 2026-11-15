import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../ui/kit.dart';
import '../../ui/tool_popover.dart';
import 'edition_picker.dart';

/// The popovers both views share (the muṣḥaf's and the Reader's rows).

Widget popoverBody(BuildContext c, List<Widget> children) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children),
    );

Widget popoverLabel(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(t, style: uiStyle(c, size: 12.5, weight: FontWeight.w700, color: pal(c).ink3)),
    );

/// Which muṣḥaf: a pick goes to [onChanged].
void showEditionPopover(BuildContext context,
    {required BuildContext anchor,
    required AxisDirection side,
    required String script,
    required ValueChanged<String> onChanged}) {
  showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
    return popoverBody(pop, [
      MushafEditionPicker(
        value: script,
        onChanged: (v) {
          Navigator.pop(pop);
          onChanged(v);
        },
      ),
    ]);
  });
}

/// The theme: which dark, monochrome, the page and its ornaments.
void showThemePopover(BuildContext context,
  {required BuildContext anchor,
  required AxisDirection side,
  required AppSettings s,
  required String script}) {
  showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
    return StatefulBuilder(builder: (pop, setPop) {
      final l = pop.l10n;
      void set(VoidCallback f) {
        s.update(f);
        setPop(() {});
      }

      return popoverBody(pop, [
        // Light or dark is its own button in the row; which dark is here.
        if (s.isDarkTheme) ...[
          popoverLabel(pop, l.theme),
          QSegmented<String>(
            options: [
              ('night', l.themeDark, null),
              ('oled', l.themeOled, null),
            ],
            value: s.appTheme,
            onChanged: (v) => set(() {
              s.appTheme = v;
              s.darkTheme = v;
              s.mushafPaperDark = 'default';
            }),
          ),
        ],
        SwitchListTile(
          key: const ValueKey('theme-mono'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          dense: true,
          title: Text(l.hzMonochrome, style: uiStyle(pop, size: 14)),
          value: s.isMonochrome,
          onChanged: (v) => set(() => s.setMonochrome(v)),
        ),
        // The page and its ornaments, each chosen on its own.
        if (s.theme == AppTheme.light) ...[
          popoverLabel(pop, l.pageColour),
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final id in const ['white', 'cream', 'madani'])
              Swatch(
                colour: kMushafPapers[id]!.paper,
                selected: mushafPaperOf(s, script).id == id,
                onTap: () => set(() => s.mushafPaper = id),
              ),
          ]),
        ],
        if (!mushafPaperOf(s, script).mono) ...[
          popoverLabel(pop, l.ornamentColour),
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final id in kOrnamentSeeds.keys)
              Swatch(
                colour: ornamentColours(id, dark: mushafPaperOf(s, script).dark).art,
                selected: s.styleFor(script).ornament == id,
                onTap: () => set(() => s.styleFor(script).ornament = id),
              ),
          ]),
        ],
      ]);
    });
  });
}

/// A colour to pick: the page's, or its ornaments'.
class Swatch extends StatelessWidget {
  final Color colour;
  final bool selected;
  final VoidCallback onTap;
  const Swatch({super.key, required this.colour, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour,
            border: Border.all(
                color: selected ? pal(context).acc : pal(context).line2,
                width: selected ? 3 : 1),
          ),
        ),
      );
}
