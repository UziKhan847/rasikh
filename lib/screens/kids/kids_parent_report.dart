import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import 'kids_path.dart';
import 'kids_widgets.dart';

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
    if (blockId.startsWith('words') || blockId == 'capstone') return 'reading';
    if (const {'wasl', 'solar_lunar', 'tamarbuta', 'waqf'}.contains(blockId) ||
        blockId.startsWith('tajwid.')) {
      return 'rules';
    }
    return 'general';
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
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
      padding: const EdgeInsets.only(bottom: Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: kidsStyle(context, size: 15, weight: FontWeight.w800),
          ),
          const SizedBox(height: Geo.gapSm),
          Container(
            padding: const EdgeInsets.all(Geo.gapMd),
            decoration: kidsCard(context),
            child: child,
          ),
        ],
      ),
    );

    final dayLetters = MaterialLocalizations.of(context).narrowWeekdays;
    final content = Padding(
      padding: const EdgeInsets.all(Geo.gapLg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Geo.gapLg),
                child: Row(
                  children: [
                    KidsAvatar(profile: profile, size: 52),
                    const SizedBox(width: Geo.gapMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: kidsStyle(
                              context,
                              size: 20,
                              weight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            context.l10n.kidsLevelLabel(prog.level),
                            style: kidsStyle(
                              context,
                              size: 12,
                              color: p.textDim,
                            ),
                          ),
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
                    context.l10n.kidsReportCurrentStage(current.title(context)),
                    style: kidsStyle(
                      context,
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Geo.radiusPill),
                    child: LinearProgressIndicator(
                      value: itemTotal == 0 ? 0 : doneTotal / itemTotal,
                      minHeight: 8,
                      backgroundColor: p.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(p.accent2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.kidsReportOverall(doneTotal, itemTotal),
                    style: kidsStyle(context, size: 12, color: p.textDim),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: p.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.l10n.kidsReportStreakDays(prog.streakDays),
                          style: kidsStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Geo.gapSm),
                  // The seven days on a row of their own, spread across the
                  // card: beside the streak text they were wider than a
                  // 320px phone's card.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: prog.weekdayActive(i)
                              ? p.accent
                              : p.surfaceHigh,
                          child: Text(
                            dayLetters[(i + 1) % 7],
                            style: kidsStyle(
                              context,
                              size: 9,
                              weight: FontWeight.w800,
                              color: prog.weekdayActive(i)
                                  ? Colors.white
                                  : p.textDim,
                            ),
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
                  ? Text(
                      context.l10n.kidsReportNothing,
                      style: kidsStyle(context, size: 13, color: p.textDim),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Geo.gapMd,
                          runSpacing: Geo.gapSm,
                          children: [
                            for (final it in weak.take(3))
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    it.arabic,
                                    textDirection: TextDirection.rtl,
                                    style: quranicStyle(
                                      context,
                                      size: 30,
                                      color: p.accent,
                                    ),
                                  ),
                                  Text(
                                    it.answer,
                                    style: kidsStyle(
                                      context,
                                      size: 11,
                                      color: p.textDim,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (due > 0) ...[
                          const SizedBox(height: Geo.gapSm),
                          Text(
                            context.l10n.kidsReportDue(due),
                            style: kidsStyle(
                              context,
                              size: 12,
                              color: p.textDim,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            section(
              context.l10n.kidsReportTalk,
              Text(talk, style: kidsStyle(context, size: 13)),
            ),
          ],
        ),
      ),
    );

    if (useDesktop(context)) return content;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.l10n.kidsParentReport,
          style: kidsStyle(context, size: 16, weight: FontWeight.w800),
        ),
      ),
      body: SafeArea(child: content),
    );
  }
}
