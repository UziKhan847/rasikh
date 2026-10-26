import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../widgets/lesson.dart';
import '../../core/settings.dart';
import '../dyslexia_screen.dart';
import '../nabr/nabr_screen.dart';
import '../lessons/qaidah_lessons.dart';
import '../qaidah_screen.dart';
import '../qiraat_screen.dart';
import '../script_screen.dart';
import '../tajweed_screen.dart';
import '../tracing_screen.dart';

/// The seven learning modules, as the Learn hub and Today's Explore tiles
/// show them: an Arabic glyph on a hue-tinted tile (OKLCH hue degrees, as in
/// the prototype), a title, a one-line description and an optional tag.
enum LearnModule { qaidah, tajwid, tashkil, script, tracing, coach, nabr, qiraat }

extension LearnModuleInfo on LearnModule {
  String get glyph => switch (this) {
        LearnModule.qaidah => 'ق',
        LearnModule.tajwid => 'ج',
        LearnModule.tashkil => 'بَ',
        LearnModule.script => '۩',
        LearnModule.tracing => 'ب',
        LearnModule.coach => 'ت',
        LearnModule.nabr => 'نَبْر',
        LearnModule.qiraat => '١٠',
      };

  double get hue => switch (this) {
        LearnModule.qaidah => 165,
        LearnModule.tajwid => 140,
        LearnModule.tashkil => 280,
        LearnModule.script => 75,
        LearnModule.tracing => 25,
        LearnModule.coach => 220,
        LearnModule.nabr => 330,
        LearnModule.qiraat => 50,
      };

  /// Shown, but not open yet: Qirāʾāt's content is being reviewed, Nabr
  /// comes later ([kNabrEnabled]).
  bool get soon =>
      this == LearnModule.qiraat || (this == LearnModule.nabr && !kNabrEnabled);

  /// Whether the module is offered at all (every one is, for now).
  bool shown(BuildContext context) => true;

  String title(BuildContext context) => switch (this) {
        LearnModule.qaidah => context.l10n.qaidahPath,
        LearnModule.tajwid => context.l10n.tajwidAcademy,
        LearnModule.tashkil => context.l10n.tashkilLab,
        LearnModule.script => context.l10n.scriptSymbols,
        LearnModule.tracing => context.l10n.tracingStudio,
        LearnModule.coach => context.l10n.readingCoach,
        LearnModule.nabr => context.l10n.nbTitle,
        LearnModule.qiraat => context.l10n.qiraHallAdvanced,
      };

  String subtitle(BuildContext context) => switch (this) {
        LearnModule.qaidah => context.l10n.qaidahSub,
        LearnModule.tajwid => context.l10n.tajwidSub,
        LearnModule.tashkil => context.l10n.tashkilSub,
        LearnModule.script => context.l10n.scriptSymbolsSub,
        LearnModule.tracing => context.l10n.tracingSub,
        LearnModule.coach => context.l10n.coachSub,
        LearnModule.nabr => context.l10n.nbSub,
        LearnModule.qiraat => context.l10n.qiraatSub,
      };

  /// The module's screen — one responsive screen on phone and desktop.
  Widget screen(BuildContext context) => switch (this) {
        LearnModule.qaidah => const QaidahScreen(),
        LearnModule.tajwid => const TajweedScreen(),
        LearnModule.tashkil => lessonEntryScreen(tashkilLessonRoot(context)),
        LearnModule.script => const ScriptScreen(),
        LearnModule.tracing => const TracingScreen(),
        LearnModule.coach => const DyslexiaScreen(),
        LearnModule.nabr => const NabrScreen(),
        LearnModule.qiraat => const QiraatScreen(),
      };

  void open(BuildContext context) {
    // Not open yet (see [soon]).
    if (soon) {
      showQToast(
          context,
          this == LearnModule.nabr
              ? context.l10n.nbFuture
              : context.l10n.comingSoonNamed(title(context)));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: screen));
  }
}

/// A module row card: tinted glyph tile, title (with an optional tag), one
/// line of description, and a chevron.
class ModuleCard extends StatelessWidget {
  final LearnModule module;
  final String? tag;
  const ModuleCard({super.key, required this.module, this.tag});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Opacity(
      opacity: module.soon ? .6 : 1,
      child: QCard(
        padding: const EdgeInsets.all(14),
        onTap: () => module.open(context),
        child: Row(children: [
          QGlyphTile(module.glyph, hue: module.hue, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(module.title(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiStyle(context, size: 15.5, weight: FontWeight.w700)),
                  ),
                  if (tag != null || module.soon) ...[
                    const SizedBox(width: 8),
                    QTag(module.soon ? context.l10n.badgeSoon : tag!,
                        color: module.soon ? p.ink3 : null),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(module.subtitle(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: uiStyle(context, size: 13, color: p.ink2, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
        ]),
      ),
    );
  }
}
