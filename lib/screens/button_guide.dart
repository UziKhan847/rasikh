import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../ui/adaptive_sheet.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';

/// What each button is: the app's icons aren't labelled.
Future<void> showButtonGuide(BuildContext context) => showAdaptiveSheet<void>(
      context,
      useRootNavigator: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: AdaptiveSheet.isSide(sheet) ? 1 : .9,
        child: const ButtonGuide(),
      ),
    );

class ButtonGuide extends StatelessWidget {
  const ButtonGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    Widget row(IconData icon, String name, String what, [String? hold]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: p.line2)),
              child: Icon(icon, size: 19, color: p.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: uiStyle(context, size: 14.5, weight: FontWeight.w700)),
                Text(what, style: uiStyle(context, size: 13, color: p.ink2)),
                if (hold != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(l.gdHold(hold), style: uiStyle(context, size: 12.5, color: p.ink3)),
                  ),
              ]),
            ),
          ]),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(l.gdTitle, style: displayStyle(context, size: 24)),
        QSectionLabel(l.gdHeaderRow),
        row(AppIcons.person, l.prfSwitch, l.gdProfileSwitch),
        row(AppIcons.bookmark, l.bmPage, l.gdBookmark),
        row(AppIcons.mushaf, l.rdPage, l.gdViewSwitch),
        QSectionLabel(l.gdMainRow),
        row(AppIcons.indexList, l.idxIndex, l.gdIndex),
        row(AppIcons.review, l.rvReview, l.gdReview, l.gdReviewHold),
        row(AppIcons.memorize, l.mzMemorize, l.gdMemorize, l.gdMemorizeHold),
        row(AppIcons.pen, l.tcMark, l.gdMark, l.gdMarkHold),
        row(AppIcons.volume, l.recitation, l.gdRecitation, l.gdRecitationHold),
        row(AppIcons.more, l.tcMore, l.gdMore),
        QSectionLabel(l.tcMore),
        row(AppIcons.reader, l.hzView, l.gdView),
        row(AppIcons.textSize, l.arabicScript, l.gdScript),
        row(AppIcons.pageColour, l.theme, l.gdTheme),
        row(Icons.dark_mode_outlined, l.themeDark, l.gdDark),
        row(AppIcons.viewSpread, l.hzPagesTwo, l.gdPages, l.gdPagesHold),
        row(AppIcons.zoom, l.hzZoom, l.gdZoom),
        row(AppIcons.pdf, l.tcExport, l.gdExport),
        row(AppIcons.chart, l.hsTitle, l.gdHistory),
        row(AppIcons.person, l.prfTitle, l.gdProfile),
        row(AppIcons.settings, l.settings, l.gdSettings, l.gdSettingsHold),
        QSectionLabel(l.tcMark),
        row(AppIcons.comment, l.mkComment, l.gdComment),
        row(AppIcons.eraser, l.hzEraser, l.gdEraser, l.gdEraserHold),
        row(Icons.air, l.mkBreath, l.gdBreath),
        row(AppIcons.undo, l.mkUndo, l.gdUndo),
      ],
    );
  }
}
