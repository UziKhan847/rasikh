import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../downloads_screen.dart';
import 'kids_path.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import '../../kids_backdrops/kb_widgets.dart' show KbAvatar;
import 'kids_widgets.dart';

/// The session-reminder presets offered below — `0` is off.
const _kidsSessionPresets = [0, 15, 20, 30];

/// A read-only look at how a child is doing, for the grown-up sitting next to
/// them — reached only through [showKidsParentGate].
///
/// Everything here is derived from what the app already stores on this
/// device (the per-child [ProgressStore] and the [kidsPath] curriculum);
/// nothing is collected, sent, or added to what is kept. The research on
/// children's apps is consistent that a parent who talks WITH the child while
/// they play (naming, asking, being taught back) improves what is learned,
/// and that an app which gives that parent nothing to do is leaving the
/// strongest lever unused — so the last section is not a statistic but a
/// prompt: one thing to try together, matched to the kind of stage the child
/// is on.
class KidsParentReport extends StatelessWidget {
  const KidsParentReport({super.key});

  /// What KIND of thing the child is learning, which decides the prompt. One
  /// line per kind (five) rather than one per stage (thirty): a prompt is
  /// about how to talk about the material, not about the material itself.
  static String talkKey(String blockId) {
    if (blockId.startsWith('letters') ||
        blockId.startsWith('forms') ||
        blockId == 'join' ||
        blockId.startsWith('special')) {
      return 'shapes';
    }
    if (const {
      'harakat',
      'sukun',
      'shadda',
      'madd',
      'tanwin',
      'muqattaat',
    }.contains(blockId)) {
      return 'sounds';
    }
    if (blockId.startsWith('words') ||
        blockId.startsWith('read.') ||
        blockId == 'capstone') {
      return 'reading';
    }
    if (const {'wasl', 'solar_lunar', 'tamarbuta', 'waqf'}.contains(blockId) ||
        blockId.startsWith('tajwid.')) {
      return 'rules';
    }
    return 'general';
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final profile = s.activeKidsProfile;

    final path = kidsPath(context);
    var doneTotal = 0;
    var itemTotal = 0;
    KidsBlock? current;
    for (final b in path) {
      final items = b.items(context);
      final done = kidsItemsDone(prog, items);
      doneTotal += done;
      itemTotal += items.length;
      // Real progress only — the developer stage jump must not make a report
      // claim a child is somewhere they have not been.
      if (current == null && done < items.length) current = b;
    }
    current ??= path.last;

    // The concepts this child is shakiest on: lowest Leitner box first, then
    // the ones missed most often.
    final weak = prog.review.values.toList()
      ..sort((a, b) {
        if (a.box != b.box) return a.box - b.box;
        return b.lapses - a.lapses;
      });
    final due = prog.dueCount;

    final talk = switch (talkKey(current.id)) {
      'shapes' => context.l10n.kidsReportTalkShapes,
      'sounds' => context.l10n.kidsReportTalkSounds,
      'rules' => context.l10n.kidsReportTalkRules,
      'reading' => context.l10n.kidsReportTalkReading,
      _ => context.l10n.kidsReportTalkGeneral,
    };

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A settings-size heading on the sky, its card under it.
          KidsLessonTitle(title, fontSize: 21, height: 1.1),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final ui = kbUi(context);
            return KbSurface(
              color: ui.surface,
              edge: ui.edge,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: child,
            );
          }),
        ],
      ),
    );

    final dayLetters = MaterialLocalizations.of(context).narrowWeekdays;
    return KidsScreenScaffold(
      title: context.l10n.kidsParentReport,
      child: Builder(builder: (context) {
        final ui = kbUi(context);
        final body = kbText(15, kbC(ui.inkSoft),
            weight: FontWeight.w600, height: 1.35);
        return SingleChildScrollView(
          clipBehavior: Clip.none,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      KbAvatar(
                        size: 64,
                        background: kbC(ui.surface),
                        face: (d) =>
                            KidsAvatar(profile: profile, size: d / 1.15),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KidsLessonTitle(profile.name,
                                fontSize: 26, height: 1.1),
                            KidsLessonSubtitle(
                                context.l10n.kidsLevelLabel(prog.level),
                                fontSize: 17),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              section(
                context.l10n.kidsParentReport,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.kidsReportCurrentStage(current!.title(context)),
                      style: kbText(17, kbC(ui.ink), weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    KbProgress(
                        value: itemTotal == 0 ? 0 : doneTotal / itemTotal,
                        ui: ui,
                        height: 10),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.kidsReportOverall(doneTotal, itemTotal),
                      style: body,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        KbIcon('local_fire_department',
                            size: 22, color: kbC(ui.accent)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.l10n.kidsReportStreakDays(prog.streakDays),
                            style: kbText(16, kbC(ui.ink),
                                weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // The seven days on a row of their own, spread across the
                    // card: beside the streak text they were wider than a
                    // 320px phone's card.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kbC(prog.weekdayActive(i)
                                  ? ui.accent
                                  : ui.track),
                            ),
                            child: Text(
                              dayLetters[(i + 1) % 7],
                              style: kbText(
                                  11,
                                  kbC(prog.weekdayActive(i)
                                      ? kWhite
                                      : ui.inkSoft),
                                  height: 1),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              section(
                context.l10n.kidsReportPractise,
                weak.isEmpty
                    ? Text(context.l10n.kidsReportNothing, style: body)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              for (final it in weak.take(3))
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    KbGlyphTile(it.arabic,
                                        bg: ui.tile,
                                        ink: ui.tileInk,
                                        size: 60,
                                        radius: 18,
                                        fontSize: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      it.answer,
                                      style: kbText(13, kbC(ui.inkSoft),
                                          weight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (due > 0) ...[
                            const SizedBox(height: 10),
                            Text(context.l10n.kidsReportDue(due), style: body),
                          ],
                        ],
                      ),
              ),
              section(
                context.l10n.kidsReportTalk,
                Text(talk,
                    style: kbText(16, kbC(ui.ink),
                        weight: FontWeight.w600, height: 1.35)),
              ),
              section(
                context.l10n.kidsSessionReminder,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.kidsSessionReminderSub, style: body),
                    const SizedBox(height: 12),
                    // The design's choice chips (the New Profile gender chips).
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: [
                        for (final m in _kidsSessionPresets)
                          KbChoiceChip(
                            m == 0
                                ? context.l10n.kidsSessionOff
                                : context.l10n.kidsSessionMinutes(m),
                            ui: ui,
                            selected: s.kidsSessionMinutes == m,
                            onTap: () =>
                                s.update(() => s.kidsSessionMinutes = m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              section(
                context.l10n.kidsParentBackupTitle,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.kidsParentBackupSub, style: body),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 12, children: [
                      KbPill(
                        context.l10n.backUp,
                        ui: ui,
                        icon: 'upload',
                        fontSize: 17,
                        iconSize: 20,
                        padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
                        onTap: () async {
                          final path = await BackupService.export(s);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                                content: Text(path == null
                                    ? context.l10n.backupFailed
                                    : context.l10n.backedUpTo(path))));
                        },
                      ),
                      KbPill(
                        context.l10n.restore,
                        ui: ui,
                        icon: 'download',
                        fontSize: 17,
                        iconSize: 20,
                        padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
                        onTap: () async {
                          final ok = await BackupService.restore(s, prog);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                                content: Text(ok
                                    ? context.l10n.backupRestored
                                    : context.l10n.noBackupFound)));
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              section(
                context.l10n.kidsParentOfflineTitle,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.kidsParentOfflineSub, style: body),
                    const SizedBox(height: 12),
                    KbPill(
                      context.l10n.manageDownloads,
                      ui: ui,
                      icon: 'download_for_offline',
                      fontSize: 17,
                      iconSize: 20,
                      padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
                      onTap: () =>
                          pushAdaptive(context, const DownloadsScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
