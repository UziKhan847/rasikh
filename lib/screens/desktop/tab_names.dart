import 'package:flutter/widgets.dart';

import '../../core/l10n.dart';
import 'screen_tints.dart';

/// Localized hero text for each desktop tab.
///
/// [kTint] is a `const` map, so it cannot hold a runtime lookup — the English
/// strings stay there as the reference, and these read the translation for the
/// current language instead.

String deskTitleOf(BuildContext context, DeskTab t) => switch (t) {
      DeskTab.home => context.l10n.tabHome,
      DeskTab.reader => context.l10n.quranReader,
      DeskTab.qaidah => context.l10n.qaidahPath,
      DeskTab.tracing => context.l10n.tracingStudio,
      DeskTab.tashkil => context.l10n.tashkilLab,
      DeskTab.tajwid => context.l10n.tajwidAcademy,
      DeskTab.coach => context.l10n.readingCoach,
      DeskTab.qiraat => context.l10n.qiraHallAdvanced,
      DeskTab.about => context.l10n.about,
    };

String deskKickerOf(BuildContext context, DeskTab t) => switch (t) {
      DeskTab.home => context.l10n.assalamuAlaykum,
      DeskTab.reader => context.l10n.qur114Surahs,
      DeskTab.qaidah => context.l10n.foundations9Units,
      DeskTab.tracing => context.l10n.guidedHandwriting,
      DeskTab.tashkil => context.l10n.tabTashkilKicker,
      DeskTab.tajwid => context.l10n.tabTajwidKicker,
      DeskTab.coach => context.l10n.tabCoachKicker,
      DeskTab.qiraat => context.l10n.tabQiraatKicker,
      DeskTab.about => context.l10n.qiraahArabiyyah,
    };

String deskBlurbOf(BuildContext context, DeskTab t) => switch (t) {
      DeskTab.home => context.l10n.tabHomeBlurb,
      DeskTab.reader => context.l10n.tabReaderBlurb,
      DeskTab.qaidah => context.l10n.tabQaidahBlurb,
      DeskTab.tracing => context.l10n.tabTracingBlurb,
      DeskTab.tashkil => context.l10n.tabTashkilBlurb,
      DeskTab.tajwid => context.l10n.tabTajwidBlurb,
      DeskTab.coach => context.l10n.tabCoachBlurb,
      DeskTab.qiraat => context.l10n.tabQiraatBlurb,
      DeskTab.about => context.l10n.tabAboutBlurb,
    };
