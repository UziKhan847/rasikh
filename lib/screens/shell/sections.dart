import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../marks/history_screen.dart';
import '../profiles_sheet.dart';
import '../settings_screen.dart';
import '../../ui/adaptive_sheet.dart';
import 'app_shell.dart' show AppSection, openMushaf;

/// Opens one of the app's areas over the muṣḥaf.
void openSection(BuildContext context, AppSection s, {ValueListenable<bool>? fromLeft}) {
  if (s == AppSection.mushaf) {
    openMushaf(context);
    return;
  }
  // Over the page, as the index comes.
  if (s == AppSection.settings) {
    showSettingsSheet(context, fromLeft: fromLeft);
    return;
  }
  // History too: an overlay, closed as the others are.
  showAdaptiveSheet<void>(
    context,
    useRootNavigator: true,
    fromLeft: fromLeft,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: AdaptiveSheet.isSide(sheet) ? 1 : .9,
      child: const HistoryScreen(),
    ),
  );
}

/// The settings button: a tap opens Settings, a long press the profiles.
class SettingsButton extends StatelessWidget {
  final double size;
  const SettingsButton({super.key, this.size = 40});

  // The tooltip shows on hover only: a long press is the profiles'.
  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.settings,
        triggerMode: TooltipTriggerMode.manual,
        child: GestureDetector(
          onLongPress: () => showProfilesSheet(context),
          child: QIconButton(
            icon: AppIcons.settings,
            size: size,
            onTap: () => openSection(context, AppSection.settings),
          ),
        ),
      );
}
