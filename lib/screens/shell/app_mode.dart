import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../learn_screen.dart';
import '../marks/hifz_screen.dart';
import '../quran_list_screen.dart';
import '../settings_screen.dart';
import '../today_screen.dart';
import '../tracing_screen.dart';
import 'app_shell.dart' show AppSection, openMushaf, sectionIcon, sectionLabel;

/// The four ways to use the app ([AppMode]): what each is called, says and
/// shows, the switcher, and the way to the app's other areas from any of
/// them.
extension AppModeInfo on AppMode {
  String title(BuildContext context) => switch (this) {
        AppMode.hifz => context.l10n.modeHifz,
        AppMode.reader => context.l10n.modeReader,
        AppMode.learn => context.l10n.modeLearn,
        AppMode.write => context.l10n.modeWrite,
      };

  String subtitle(BuildContext context) => switch (this) {
        AppMode.hifz => context.l10n.modeHifzSub,
        AppMode.reader => context.l10n.modeReaderSub,
        AppMode.learn => context.l10n.modeLearnSub,
        AppMode.write => context.l10n.modeWriteSub,
      };

  IconData get icon => switch (this) {
        AppMode.hifz => AppIcons.hifz,
        AppMode.reader => AppIcons.reader,
        AppMode.learn => AppIcons.learn,
        AppMode.write => AppIcons.trace,
      };

  /// The Arabic on its tile.
  String get glyph => switch (this) {
        AppMode.hifz => 'حفظ',
        AppMode.reader => 'اقرأ',
        AppMode.learn => 'تعلّم',
        AppMode.write => 'اكتب',
      };

  double get hue => switch (this) {
        AppMode.hifz => 165,
        AppMode.reader => 140,
        AppMode.learn => 280,
        AppMode.write => 25,
      };
}

/// Opens one of the app's areas over the current mode's home: the way to
/// everything a mode doesn't open to.
void openSection(BuildContext context, AppSection s) {
  if (s == AppSection.mushaf) {
    openMushaf(context);
    return;
  }
  final Widget screen = switch (s) {
    AppSection.today => const TodayScreen(),
    AppSection.quran => const SurahListScreen(),
    AppSection.hifz => const HifzScreen(),
    AppSection.learn => const LearnScreen(),
    AppSection.trace => const TracingScreen(),
    AppSection.settings => const SettingsScreen(),
    AppSection.mushaf => const SizedBox.shrink(),
  };
  Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Sets the mode (the app's home) and says so.
void setAppMode(BuildContext context, AppMode m) {
  final s = SettingsScope.of(context);
  if (s.mode == m) return;
  s.update(() => s.appMode = m.name);
  showQToast(context, context.l10n.modeNow(m.title(context)));
}

/// The modes as a list of cards, the current one marked — Settings' Mode
/// section and the switcher.
class ModeList extends StatelessWidget {
  final ValueChanged<AppMode>? onPicked;
  const ModeList({super.key, this.onPicked});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    return Column(children: [
      for (final m in AppMode.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: QCard(
            padding: const EdgeInsets.all(12),
            color: s.mode == m ? p.accSoft : null,
            borderColor: s.mode == m ? p.acc : null,
            onTap: () {
              setAppMode(context, m);
              onPicked?.call(m);
            },
            child: Row(children: [
              QGlyphTile(m.glyph, hue: m.hue, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title(context),
                      style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                  Text(m.subtitle(context),
                      style: uiStyle(context, size: 12.5, color: p.ink2, height: 1.35)),
                ]),
              ),
              if (s.mode == m) Icon(AppIcons.check, color: p.acc),
            ]),
          ),
        ),
    ]);
  }
}

/// The areas a mode doesn't open to, each a tap away.
class AlsoInApp extends StatelessWidget {
  /// Called before an area opens (the switcher closes itself).
  final VoidCallback? onOpen;
  const AlsoInApp({super.key, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QGroup(children: [
      for (final sec in const [
        AppSection.mushaf,
        AppSection.quran,
        AppSection.learn,
        AppSection.hifz,
        AppSection.trace,
        AppSection.today,
      ])
        QRow(
          leading: Icon(sectionIcon(sec), color: p.acc),
          title: sec == AppSection.trace
              ? context.l10n.tracingStudio
              : sectionLabel(context, sec),
          chevron: true,
          onTap: () {
            onOpen?.call();
            openSection(context, sec);
          },
        ),
    ]);
  }
}

/// The mode switcher: the modes, then the other areas.
Future<void> showModeSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .9),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(context.l10n.modeSwitch, style: displayStyle(sheet, size: 22)),
              const SizedBox(height: 10),
              ModeList(onPicked: (_) => Navigator.pop(sheet)),
              QSectionLabel(context.l10n.alsoInApp),
              AlsoInApp(onOpen: () => Navigator.pop(sheet)),
            ],
          ),
        ),
      ),
    );

/// The settings button every mode's home has: a tap opens Settings, a long
/// press the mode switcher.
class SettingsButton extends StatelessWidget {
  final double size;
  const SettingsButton({super.key, this.size = 40});

  // The tooltip shows on hover only: a long press is the switcher's.
  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.settings,
        triggerMode: TooltipTriggerMode.manual,
        child: GestureDetector(
          onLongPress: () => showModeSheet(context),
          child: QIconButton(
            icon: AppIcons.settings,
            size: size,
            onTap: () => openSection(context, AppSection.settings),
          ),
        ),
      );
}
