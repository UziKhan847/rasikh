import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/letters.dart';
import '../../data/qiraat.dart';
import '../../data/quran.dart';
import '../../data/strokes.dart';
import '../../data/tajweed.dart';
import '../../data/glyph_names.dart';
import '../../data/tashkeel.dart';
import '../../data/tracing_levels.dart';
import '../../widgets/common.dart'
    show StarRow, TapScale, QuizHostScope, PhaseHub;
import '../dyslexia_screen.dart'
    show SpotTheLetterDrill, DotDetectiveDrill, FluencySprint, mistakeReviewQuiz;
import '../qaidah_screen.dart' show QaidahUnit, qaidahUnits;
import '../quran_screen.dart' show SurahReaderScreen;
import '../script_screen.dart' show ScriptUnit, scriptUnits;
import '../tajweed_screen.dart' show tajwidQuizScreen, TajwidUnit, tajwidUnits;
import '../tashkeel_screen.dart' show CountsStudio;
import '../tracing_screen.dart' show TracingBoard;
import 'screen_tints.dart';
import 'tab_names.dart';

// ─────────────────────────── shared building blocks ──────────────────────────

/// The tinted hero banner at the top of every desktop screen — gradient,
/// faint watermark glyph, kicker, title, blurb. Colors come from [TabTint].
Widget deskHero(BuildContext context, DeskTab t,
    {String? kicker, String? title, String? blurb, Widget? trailing}) {
  final tint = kTint[t]!;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
          colors: tint.hero,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      boxShadow: [
        BoxShadow(
            color: tint.hero.last.withValues(alpha: .28),
            blurRadius: 34,
            offset: const Offset(0, 14)),
      ],
    ),
    child: Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned(
        top: -40,
        right: 20,
        child: Text(tint.watermark,
            style: TextStyle(
                fontFamily: 'ScheherazadeNew',
                fontSize: 160,
                height: 1,
                color: Colors.white.withValues(alpha: .12))),
      ),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((kicker ?? deskKickerOf(context, t)).toUpperCase(),
                style: uiStyle(context,
                    size: 12.5,
                    weight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: .82))),
            const SizedBox(height: 4),
            Text(title ?? deskTitleOf(context, t),
                style: uiStyle(context,
                    size: 28, weight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            Text(blurb ?? deskBlurbOf(context, t),
                style: uiStyle(context,
                        size: 14, color: Colors.white.withValues(alpha: .9))
                    .copyWith(height: 1.5)),
          ]),
        ),
        ?trailing,
      ]),
    ]),
  );
}

/// Section header: a short colored bar + bold title (the reference's pattern).
Widget deskSection(BuildContext context, DeskTab t, String title,
    {String? action, VoidCallback? onAction}) {
  final tint = kTint[t]!;
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
              color: tint.kickerColor,
              borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 11),
      Text(title, style: uiStyle(context, size: 20, weight: FontWeight.w800)),
      if (action != null) ...[
        const Spacer(),
        TextButton(
            onPressed: onAction,
            child: Text(action,
                style: uiStyle(context,
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: tint.kickerColor))),
      ],
    ]),
  );
}

BoxDecoration deskCard(BuildContext context) => BoxDecoration(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: pal(context).surfaceHigh.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
            color: pal(context).shadow,
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ],
    );

/// Border-only decoration for tappable tiles: the tile's Material carries the
/// surface color + elevation shadow so the ink ripple paints OVER the tile
/// (the old opaque-Container-over-Material made the splash leak out as a glow
/// behind the card, visible in dark mode).
BoxDecoration deskBorder(BuildContext context, {Color? color, double radius = 18}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: color ?? pal(context).surfaceHigh.withValues(alpha: .6)),
    );

Widget deskGrid(List<Widget> children, {double minWidth = 300, double gap = 16}) {
  return LayoutBuilder(builder: (context, c) {
    var cols = (c.maxWidth / (minWidth + gap)).floor();
    cols = cols.clamp(1, 6);
    final w = (c.maxWidth - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final ch in children) SizedBox(width: w, child: ch)],
    );
  });
}

Widget _scroll(BuildContext context, List<Widget> children) => ListView(
      padding: const EdgeInsets.fromLTRB(34, 4, 34, 40),
      children: children,
    );

// ═══════════════════════════ TAJWĪD ACADEMY ══════════════════════════════════
class DesktopTajwid extends StatefulWidget {
  const DesktopTajwid({super.key});
  @override
  State<DesktopTajwid> createState() => _DesktopTajwidState();
}

class _DesktopTajwidState extends State<DesktopTajwid> {
  TajwidUnit? open;
  int? openPhase;

  @override
  Widget build(BuildContext context) {
    if (open != null) {
      final phaseBuilder = openPhase == null ? null : open!.phases[openPhase!].builder;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 0, 34, 8),
          child: Row(children: [
            Material(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() {
                  if (openPhase != null) {
                    openPhase = null;
                  } else {
                    open = null;
                  }
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      border: Border.all(color: pal(context).surfaceHigh),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.arrow_back_rounded, color: pal(context).text),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(open!.title,
                style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: phaseBuilder == null
                  ? PhaseHub(
                      subtitle: open!.subtitle,
                      phases: open!.phases,
                      onPick: (i) => setState(() => openPhase = i),
                    )
                  : QuizHostScope(
                      embedded: true,
                      child: _UnitHost(builder: phaseBuilder),
                    ),
            ),
          ),
        ),
      ]);
    }
    final units = tajwidUnits(context);
    return _scroll(context, [
      deskHero(context, DeskTab.tajwid,
          kicker: context.l10n.k16RulesColorCoded,
          title: context.l10n.reciteWayWasRevealed,
          blurb:
              context.l10n.eachRuleHasColorOnce),
      const SizedBox(height: 24),
      // ── legend (like mobile): every rule as a colored pill ──
      deskSection(context, DeskTab.tajwid, context.l10n.colorLegend),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: deskCard(context),
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final r in tajwidRules)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: r.color.withValues(alpha: .5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration:
                        BoxDecoration(color: r.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(tajwidName(context, r),
                      style: uiStyle(context,
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: r.color)),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      deskSection(context, DeskTab.tajwid, context.l10n.theRules, action: context.l10n.takeTheQuiz,
          onAction: () => pushAdaptive(context, tajwidQuizScreen(context))),
      deskGrid([
        for (final u in units) _unitCard(context, u)
      ], minWidth: 300),
    ]);
  }

  Widget _unitCard(BuildContext context, TajwidUnit u) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => open = u),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal(context).surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(u.arabicBadge,
                  style: quranicStyle(context, size: 22, height: 1.3,
                      color: pal(context).accent)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.title,
                      style: uiStyle(context, size: 16.5, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(u.subtitle,
                      style: uiStyle(context, size: 13, color: pal(context).textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: pal(context).textDim),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════ SCRIPT & SYMBOLS ═══════════════════════════════════
class DesktopScript extends StatefulWidget {
  const DesktopScript({super.key});
  @override
  State<DesktopScript> createState() => _DesktopScriptState();
}

class _DesktopScriptState extends State<DesktopScript> {
  ScriptUnit? open;
  int? openPhase;

  @override
  Widget build(BuildContext context) {
    if (open != null) {
      final phaseBuilder = openPhase == null ? null : open!.phases[openPhase!].builder;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 0, 34, 8),
          child: Row(children: [
            Material(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() {
                  if (openPhase != null) {
                    openPhase = null;
                  } else {
                    open = null;
                  }
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      border: Border.all(color: pal(context).surfaceHigh),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.arrow_back_rounded, color: pal(context).text),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(open!.title,
                style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: phaseBuilder == null
                  ? PhaseHub(
                      subtitle: open!.subtitle,
                      phases: open!.phases,
                      onPick: (i) => setState(() => openPhase = i),
                    )
                  : QuizHostScope(
                      embedded: true,
                      child: _UnitHost(builder: phaseBuilder),
                    ),
            ),
          ),
        ),
      ]);
    }
    final units = scriptUnits(context);
    return _scroll(context, [
      deskHero(context, DeskTab.script,
          kicker: context.l10n.foundations4Units,
          title: context.l10n.scriptSymbols,
          blurb: context.l10n.scriptSymbolsSub),
      const SizedBox(height: 24),
      deskSection(context, DeskTab.script, context.l10n.everyUnit),
      deskGrid([for (final u in units) _unitCard(context, u)], minWidth: 320),
    ]);
  }

  Widget _unitCard(BuildContext context, ScriptUnit u) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => open = u),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal(context).surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(u.arabicBadge,
                  style: quranicStyle(context, size: 20, height: 1.3,
                      color: pal(context).accent)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.title,
                      style: uiStyle(context, size: 16.5, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(u.subtitle,
                      style: uiStyle(context, size: 13, color: pal(context).textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: pal(context).textDim),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════ HOME ══════════════════════════════════════════
class DesktopHome extends StatelessWidget {
  final void Function(DeskTab)? onGo;
  const DesktopHome({super.key, this.onGo});
  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final stars = prog.totalStars;
    final learned = prog.lettersLearned;
    return _scroll(context, [
      deskHero(context, DeskTab.home,
          kicker: context.l10n.assalamuAlaykum,
          title: context.l10n.fromFirstAlifTenQira,
          blurb:
              context.l10n.pickUpWhereLeftOff),
      const SizedBox(height: 26),
      deskSection(context, DeskTab.home, context.l10n.yourProgress),
      Row(children: [
        Expanded(child: _stat(context, '$stars', context.l10n.starsEarned, Icons.star_rounded, AppColors.star)),
        const SizedBox(width: 16),
        Expanded(child: _stat(context, '$learned / 28', context.l10n.lettersExplored, Icons.abc_rounded, const Color(0xFF0FA87E))),
        const SizedBox(width: 16),
        Expanded(child: _stat(context, '${prog.streakDays}', context.l10n.dayStreak, Icons.local_fire_department_rounded, const Color(0xFFE45F52))),
      ]),
      const SizedBox(height: 26),
      deskSection(context, DeskTab.home, context.l10n.explorePath),
      deskGrid([
        _jump(context, DeskTab.qaidah, context.l10n.qaidahPath, context.l10n.lettersToWords),
        _jump(context, DeskTab.tracing, context.l10n.tracingStudio, context.l10n.writeByHand),
        _jump(context, DeskTab.tajwid, context.l10n.tajwidAcademy, context.l10n.coloredRules16),
        _jump(context, DeskTab.reader, context.l10n.quranReader, context.l10n.surahs114),
        _jump(context, DeskTab.tashkil, context.l10n.tashkilLab, context.l10n.vowelsMarks),
        _jump(context, DeskTab.coach, context.l10n.readingCoach, context.l10n.lookAlikeDrills),
      ], minWidth: 260),
    ]);
  }

  Widget _stat(BuildContext context, String big, String label, IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: deskCard(context),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: c, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(big, style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          Text(label, style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
        ]),
      ]),
    );
  }

  Widget _jump(BuildContext context, DeskTab t, String title, String sub) {
    final tint = kTint[t]!;
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onGo?.call(t),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: deskBorder(context, radius: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: tint.softOf(context),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(tint.icon, color: tint.kickerColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: uiStyle(context, size: 16, weight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub,
                style:
                    uiStyle(context, size: 12.5, color: pal(context).textDim)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════ READER ════════════════════════════════════════
class DesktopReader extends StatefulWidget {
  const DesktopReader({super.key});
  @override
  State<DesktopReader> createState() => _DesktopReaderState();
}

class _DesktopReaderState extends State<DesktopReader> {
  SurahMeta? open;

  @override
  Widget build(BuildContext context) {
    // reading a sūrah → show the reader in place (sidebar + top bar stay)
    if (open != null) {
      return SurahReaderScreen(
        key: ValueKey('reader-${open!.n}'),
        meta: open!,
        shell: true,
        onBack: () => setState(() => open = null),
      );
    }
    return _scroll(context, [
      deskHero(context, DeskTab.reader,
          kicker: context.l10n.qur114Surahs,
          title: context.l10n.readHelpEveryWord,
          blurb:
              context.l10n.wordWordMeaningsTajwidColors),
      const SizedBox(height: 24),
      deskSection(context, DeskTab.reader, context.l10n.allSurahs),
      FutureBuilder<List<SurahMeta>>(
        future: QuranRepo.meta(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: pal(context).accent),
            ));
          }
          return deskGrid(
              [for (final m in snap.data!) _surahCard(context, m)],
              minWidth: 300);
        },
      ),
    ]);
  }

  Widget _surahCard(BuildContext context, SurahMeta m) {
    final tint = kTint[DeskTab.reader]!;
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => open = m),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: deskBorder(context),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: tint.softOf(context), borderRadius: BorderRadius.circular(13)),
              child: Text('${m.n}',
                  style: uiStyle(context,
                      size: 15,
                      weight: FontWeight.w800,
                      color: tint.kickerColor)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.tname,
                      style: uiStyle(context,
                          size: 15.5, weight: FontWeight.w800)),
                  Text(
                      context.l10n.typeAyat(
                          m.type == 'meccan'
                              ? context.l10n.meccan
                              : context.l10n.medinan,
                          m.ayahs),
                      style: uiStyle(context,
                          size: 12.5, color: pal(context).textDim)),
                ],
              ),
            ),
            Text(m.name, style: quranicStyle(context, size: 24)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════ QAIDAH ════════════════════════════════════════
class DesktopQaidah extends StatefulWidget {
  const DesktopQaidah({super.key});
  @override
  State<DesktopQaidah> createState() => _DesktopQaidahState();
}

class _DesktopQaidahState extends State<DesktopQaidah> {
  QaidahUnit? open;
  int? openPhase;

  @override
  Widget build(BuildContext context) {
    if (open != null) {
      // host the unit (phase hub, then the picked phase) inside the shell
      // with a desktop back header — back from a phase returns to the hub,
      // back from the hub returns to the unit list.
      final phaseBuilder = openPhase == null ? null : open!.phases[openPhase!].builder;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 0, 34, 8),
          child: Row(children: [
            Material(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() {
                  if (openPhase != null) {
                    openPhase = null;
                  } else {
                    open = null;
                  }
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      border: Border.all(color: pal(context).surfaceHigh),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.arrow_back_rounded, color: pal(context).text),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(open!.title,
                style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: phaseBuilder == null
                  ? PhaseHub(
                      subtitle: open!.subtitle,
                      phases: open!.phases,
                      onPick: (i) => setState(() => openPhase = i),
                    )
                  : QuizHostScope(
                      embedded: true,
                      child: _UnitHost(builder: phaseBuilder),
                    ),
            ),
          ),
        ),
      ]);
    }
    final prog = ProgressScope.of(context);
    final units = qaidahUnits(context);
    final done = units.where((u) => prog.starsFor(u.progressId) > 0).length;
    return _scroll(context, [
      deskHero(context, DeskTab.qaidah,
          kicker: context.l10n.foundations9Units,
          title: context.l10n.fromLettersReadingRealWords,
          blurb:
              context.l10n.unitsProgress(
            done, units.length, prog.lettersLearned, letters.length)),
      const SizedBox(height: 26),
      deskSection(context, DeskTab.qaidah, context.l10n.everyUnit),
      deskGrid([
        for (var i = 0; i < units.length; i++)
          _unitCard(context, prog, units[i], i)
      ], minWidth: 320),
    ]);
  }

  Widget _unitCard(BuildContext context, ProgressStore prog, QaidahUnit u, int i) {
    final tint = kTint[DeskTab.qaidah]!;
    final stars = prog.starsFor(u.progressId);
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => open = u),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: deskBorder(context,
              color: stars > 0
                  ? tint.kickerColor.withValues(alpha: .5)
                  : null),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: tint.softOf(context), borderRadius: BorderRadius.circular(15)),
              child: Text(u.arabicBadge,
                  style: quranicStyle(context,
                      size: 22, color: tint.kickerColor)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.unitTitle(i + 1, u.title),
                      style: uiStyle(context,
                          size: 15.5, weight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(u.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 12.5, color: pal(context).textDim)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StarRow(stars),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════ TRACING ═══════════════════════════════════════
class DesktopTracing extends StatefulWidget {
  final String? initialLetter;
  const DesktopTracing({super.key, this.initialLetter});
  @override
  State<DesktopTracing> createState() => _DesktopTracingState();
}

class _DesktopTracingState extends State<DesktopTracing> {
  int level = 0;
  late String letter;
  String form = 'iso';
  int wordIdx = 0;
  /// 'guided' · 'outline' · 'memory' — see [TracingBoard.mode].
  String mode = 'guided';
  // 0 = spinner · 1 = layout with board placeholder · 2 = board mounted
  int _stage = 0;

  // ── quiz ──
  bool quiz = false;
  int quizTarget = 5;
  int quizStreak = 0;
  int attempt = 0;
  final Set<String> quizCleared = {};
  TracedGlyph? quizGlyph;
  int? lastStars;
  bool awaitingNext = false;
  bool quizComplete = false;
  final math.Random _rng = math.Random();

  TracingLevel get lvl => tracingLevels[level];

  TracedGlyph get glyph {
    if (quiz) return quizGlyph ?? lvl.quizPool.first;
    if (lvl.words) return lvl.glyphs[wordIdx.clamp(0, lvl.glyphs.length - 1)];
    return lvl.glyphForIn(letter, form);
  }

  static const _modeSuffix = {
    'guided': '',
    'outline': '.out',
    'memory': '.mem',
  };

  String get progressId =>
      'trace.${lvl.id}.${glyph.id}${_modeSuffix[mode] ?? ''}';

  @override
  void initState() {
    super.initState();
    letter = widget.initialLetter ?? '';
    if (!lvl.letters.any((l) => l.char == letter)) {
      letter = lvl.letters.first.char;
    }
    final f = lvl.formsPresentFor(letter);
    if (!f.contains(form)) form = f.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _stage = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stage = 2);
      });
    });
  }

  void _setLevel(int i) {
    setState(() {
      level = i;
      quiz = false;
      awaitingNext = false;
      quizComplete = false;
      quizStreak = 0;
      quizCleared.clear();
      quizGlyph = null;
      if (lvl.words) {
        wordIdx = 0;
      } else {
        if (!lvl.letters.any((l) => l.char == letter)) {
          letter = lvl.letters.first.char;
        }
        final f = lvl.formsPresentFor(letter);
        if (!f.contains(form)) form = f.first;
      }
      attempt++;
    });
  }

  TracedGlyph? _pickQuiz() {
    final pool = lvl.quizPool.where((g) => !quizCleared.contains(g.id)).toList();
    if (pool.isEmpty) return null;
    return pool[_rng.nextInt(pool.length)];
  }

  void _startQuiz() {
    setState(() {
      quiz = true;
      quizComplete = false;
      awaitingNext = false;
      quizStreak = 0;
      lastStars = null;
      quizCleared.clear();
      quizGlyph = _pickQuiz();
      attempt++;
    });
  }

  void _exitQuiz() {
    setState(() {
      quiz = false;
      awaitingNext = false;
      attempt++;
    });
  }

  void _onStars(int s) {
    if (quiz && awaitingNext) return;
    ProgressScope.of(context).report(progressId, s);
    if (!quiz) return;
    setState(() {
      lastStars = s;
      awaitingNext = true;
      if (s >= 2) {
        quizStreak++;
        if (quizStreak >= quizTarget && quizGlyph != null) {
          quizCleared.add(quizGlyph!.id);
        }
      } else {
        quizStreak = 0;
      }
    });
  }

  void _quizNext() {
    setState(() {
      final cleared = quizGlyph != null && quizCleared.contains(quizGlyph!.id);
      if (cleared) {
        quizStreak = 0;
        final next = _pickQuiz();
        if (next == null) {
          quizComplete = true;
          awaitingNext = false;
          return;
        }
        quizGlyph = next;
      }
      awaitingNext = false;
      lastStars = null;
      attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == 0) {
      return Center(child: CircularProgressIndicator(color: pal(context).accent));
    }
    final prog = ProgressScope.of(context);
    final tint = kTint[DeskTab.tracing]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 4, 34, 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deskHero(context, DeskTab.tracing,
                  kicker: context.l10n.guidedHandwriting,
                  title: context.l10n.writeEachLetterStrokeStroke,
                  blurb:
                      context.l10n.followGlowingCometFromGreen),
              const SizedBox(height: 14),
              _levelBar(context, tint),
              const SizedBox(height: 14),
              Row(children: [
                Text(
                    quiz
                        ? '${glyphNameOf(context, glyph)}  ·  quiz'
                        : glyphNameOf(context, glyph),
                    style: uiStyle(context, size: 18, weight: FontWeight.w800)),
                const Spacer(),
                StarRow(prog.starsFor(progressId)),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  // TracingBoard is a Column: the board + a toolbar Row (~56px)
                  // beneath it. Size the board so the WHOLE column fits.
                  const toolbar = 60.0;
                  final boardMax = c.maxHeight - toolbar;
                  final aspect = glyph.aspect > 0 ? glyph.aspect : 1.0;
                  var w = boardMax * aspect;
                  if (w > c.maxWidth) w = c.maxWidth;
                  return Center(
                    child: SizedBox(
                      width: w,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: deskCard(context),
                        child: _stage < 2
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: pal(context).accent))
                            : TracingBoard(
                                key: ValueKey(
                                    '${lvl.id}-${glyph.id}-$mode-$quiz-$attempt'),
                                glyph: glyph,
                                mode: mode,
                                showOverlay: !quiz,
                                onStars: _onStars,
                              ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              if (!quiz && !lvl.words)
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final f in lvl.formsPresentFor(letter))
                        _formChip(context, f, tint),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(width: 300, child: _picker(context, tint)),
      ]),
    );
  }

  Widget _levelBar(BuildContext context, TabTint tint) => SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tracingLevels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final lv = tracingLevels[i];
            final on = i == level;
            return TapScale(
              onTap: () => _setLevel(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? tint.kickerColor : pal(context).surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: on ? tint.kickerColor : pal(context).surfaceHigh),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1} · ${levelNameOf(context, lv.id)}',
                        style: uiStyle(context,
                            size: 13,
                            weight: FontWeight.w800,
                            color: on ? Colors.white : pal(context).text)),
                    Text(tierLabelOf(context, lv.tier),
                        style: uiStyle(context,
                            size: 10.5,
                            color:
                                on ? Colors.white70 : pal(context).textDim)),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _picker(BuildContext context, TabTint tint) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: deskCard(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final value in const [
            'guided',
            'outline',
            'memory',
          ]) ...[
            _seg(context, modeLabelOf(context, value), mode == value, () {
              setState(() {
                mode = value;
                attempt++;
              });
            }, tint),
            if (value != 'memory') const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 8),
        Text(
            switch (mode) {
              'outline' => context.l10n.hintOutlineDesk,
              'memory' => context.l10n.hintMemoryDesk,
              _ => context.l10n.hintGuidedDesk,
            },
            style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
        const SizedBox(height: 10),
        Row(children: [
          _seg(context, context.l10n.practice, !quiz, () {
            if (quiz) _exitQuiz();
          }, tint),
          const SizedBox(width: 8),
          _seg(context, context.l10n.quiz, quiz, () {
            if (!quiz) _startQuiz();
          }, tint),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: quiz
                ? _quizPanel(context, tint)
                : (lvl.words ? _wordList(context, tint) : _letterGrid(context, tint)),
          ),
        ),
      ]),
    );
  }

  Widget _letterGrid(BuildContext context, TabTint tint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.chooseALetter,
              style: uiStyle(context, size: 14, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final l in lvl.letters) _letterTile(context, l.char, tint),
            ],
          ),
        ],
      );

  Widget _wordList(BuildContext context, TabTint tint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.chooseAWord,
              style: uiStyle(context, size: 14, weight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (var i = 0; i < lvl.glyphs.length; i++) ...[
            TapScale(
              onTap: () => setState(() {
                wordIdx = i;
                attempt++;
              }),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: i == wordIdx ? tint.kickerColor : pal(context).bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(lvl.glyphs[i].char,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 22,
                        height: 1.5,
                        color:
                            i == wordIdx ? Colors.white : pal(context).text)),
              ),
            ),
            if (i != lvl.glyphs.length - 1) const SizedBox(height: 8),
          ],
        ],
      );

  Widget _quizPanel(BuildContext context, TabTint tint) {
    final total = lvl.quizPool.length;
    final cleared = quizGlyph != null && quizCleared.contains(quizGlyph!.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(context.l10n.inARow,
            style: uiStyle(context,
                size: 13,
                weight: FontWeight.w700,
                color: pal(context).textDim)),
        const SizedBox(width: 8),
        _seg(context, '5', quizTarget == 5,
            () => setState(() => quizTarget = 5), tint),
        const SizedBox(width: 8),
        _seg(context, '10', quizTarget == 10,
            () => setState(() => quizTarget = 10), tint),
      ]),
      const SizedBox(height: 14),
      Text(context.l10n.clearedXofY(quizCleared.length, total),
          style: uiStyle(context,
              size: 14, weight: FontWeight.w800, color: tint.kickerColor)),
      const SizedBox(height: 14),
      if (quizComplete) ...[
        Text(context.l10n.levelCompleteEveryLetterCleared,
            style: uiStyle(context, size: 15, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: tint.kickerColor),
          onPressed: _startQuiz,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label:  Text(context.l10n.restartQuiz),
        ),
      ] else ...[
        Text(context.l10n.streak,
            style: uiStyle(context,
                size: 13,
                weight: FontWeight.w700,
                color: pal(context).textDim)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < quizTarget; i++)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < quizStreak ? tint.kickerColor : pal(context).bg,
                border: Border.all(color: pal(context).surfaceHigh),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        if (awaitingNext) ...[
          Row(children: [
            StarRow(lastStars ?? 0, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  cleared
                      ? context.l10n.clearedExclaim
                      : ((lastStars ?? 0) >= 2
                          ? context.l10n.niceKeepGoing
                          : context.l10n.streakReset),
                  style: uiStyle(context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: cleared ? AppColors.ok : pal(context).textDim)),
            ),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: tint.kickerColor),
            onPressed: _quizNext,
            icon: Icon(
                cleared ? Icons.arrow_forward_rounded : Icons.refresh_rounded,
                size: 18),
            label: Text(cleared ? context.l10n.nextLetter : context.l10n.traceAgain),
          ),
        ] else
          Text(
              switch (mode) {
                'memory' => context.l10n.quizInstrMemoryShort(quizTarget),
                'outline' => context.l10n.quizInstrOutlineShort(quizTarget),
                _ => context.l10n.quizInstrGuidedShort(quizTarget),
              },
              style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
      ],
    ]);
  }

  Widget _letterTile(BuildContext context, String ch, TabTint tint) {
    final on = ch == letter;
    return TapScale(
      onTap: () => setState(() {
        letter = ch;
        final f = lvl.formsPresentFor(ch);
        if (!f.contains(form)) form = f.first;
        attempt++;
      }),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint.kickerColor : pal(context).bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(ch,
            style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 30,
                height: 1.4,
                color: on ? Colors.white : pal(context).text)),
      ),
    );
  }

  Widget _formChip(BuildContext context, String f, TabTint tint) {
    final on = form == f;
    return TapScale(
      onTap: () => setState(() {
        form = f;
        attempt++;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? tint.softOf(context) : pal(context).surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: on ? tint.kickerColor : pal(context).surfaceHigh),
        ),
        child: Text(formLabelOf(context, f),
            style: uiStyle(context,
                size: 12.5,
                weight: FontWeight.w700,
                color: on ? tint.kickerColor : pal(context).textDim)),
      ),
    );
  }

  Widget _seg(BuildContext context, String label, bool on, VoidCallback onTap,
      TabTint tint) {
    return Expanded(
      child: TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? tint.kickerColor : pal(context).bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: uiStyle(context,
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: on ? Colors.white : pal(context).text)),
        ),
      ),
    );
  }

}

// ═════════════════════════════ TASHKĪL ═══════════════════════════════════════
class DesktopTashkil extends StatefulWidget {
  const DesktopTashkil({super.key});
  @override
  State<DesktopTashkil> createState() => _DesktopTashkilState();
}

class _DesktopTashkilState extends State<DesktopTashkil> {
  int sel = 0;
  bool hearOpen = false;

  @override
  Widget build(BuildContext context) {
    final tint = kTint[DeskTab.tashkil]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 4, 34, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        deskHero(context, DeskTab.tashkil,
            kicker: context.l10n.marksN(tashkil.length),
            title: context.l10n.everyVowelMark,
            blurb:
                context.l10n.pickMarkHearHowSounds),
        const SizedBox(height: 22),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(children: [
                for (var i = 0; i < tashkil.length; i++)
                  _markRow(context, tashkil[i], i, tint),
              ]),
            ),
            const SizedBox(width: 24),
            SizedBox(
                width: 360,
                child: SingleChildScrollView(
                    child: _detail(context, tashkil[sel], tint))),
          ]),
        ),
      ]),
    );
  }

  Widget _markRow(BuildContext context, TashkilItem m, int i, TabTint tint) {
    final on = i == sel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: on ? tint.softOf(context) : pal(context).surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() {
            if (sel != i) hearOpen = false;
            sel = i;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? tint.kickerColor : Colors.transparent, width: 2),
            ),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: tint.softOf(context), borderRadius: BorderRadius.circular(14)),
                child: Text(m.mark,
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context,
                        size: 26, color: tint.kickerColor)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tashkilName(context, m),
                        style: uiStyle(context,
                            size: 16, weight: FontWeight.w800)),
                    Text('“${m.sound}” · ${m.counts == 0 ? context.l10n.noCount : context.l10n.countLabelPlural(m.counts)}',
                        style: uiStyle(context,
                            size: 13, color: pal(context).textDim)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: pal(context).textDim),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, TashkilItem m, TabTint tint) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: deskCard(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tashkilName(context, m),
                    style: uiStyle(context, size: 22, weight: FontWeight.w900)),
                Text('“${m.sound}” · ${m.counts == 0 ? context.l10n.noCount : context.l10n.countLabelPlural(m.counts)}',
                    style: uiStyle(context,
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: tint.kickerColor)),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: tint.softOf(context), borderRadius: BorderRadius.circular(16)),
            child: Text(m.mark,
                textDirection: TextDirection.rtl,
                style: quranicStyle(context,
                    size: 30, color: tint.kickerColor)),
          ),
        ]),
        const SizedBox(height: 16),
        Text(tashkilNote(context, m),
            style: uiStyle(context, size: 14, color: pal(context).text)
                .copyWith(height: 1.5)),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: pal(context).bg, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(m.example,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    fontFamily: 'UthmanicHafs', fontSize: 34, height: 1.6)),
            const SizedBox(height: 6),
            Text(context.l10n.surahRef(m.ref),
                style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: hearOpen ? pal(context).surfaceHigh : tint.kickerColor,
                foregroundColor: hearOpen ? pal(context).text : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => setState(() => hearOpen = !hearOpen),
            icon: Icon(
                hearOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.headphones_rounded,
                size: 18),
            label: Text(hearOpen ? context.l10n.hideTheCounter : context.l10n.hearTheCount),
          ),
        ),
        if (hearOpen) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: pal(context).bg, borderRadius: BorderRadius.circular(16)),
            child: CountsStudio(
                key: ValueKey('cs$sel'),
                embedded: true,
                initialCounts: m.counts < 1 ? 1 : m.counts,
                word: m.example,
                highlight: m.highlight),
          ),
        ],
      ]),
    );
  }
}

// ═════════════════════════════ COACH ═════════════════════════════════════════
class DesktopCoach extends StatelessWidget {
  const DesktopCoach({super.key});

  // Built per-call because the labels are localized (a `static` field has no
  // BuildContext). The letter groups themselves are fixed.
  List<(String, String, List<String>)> _sets(BuildContext context) => [
        (context.l10n.dottedFamily, context.l10n.oneTwoThreeDots,
            ['ب', 'ت', 'ث']),
        (context.l10n.jimGroup, context.l10n.belowNoneAbove, ['ج', 'ح', 'خ']),
        ('Dāl & Dhāl', context.l10n.plainVsOneDot, ['د', 'ذ']),
        ('Rāʼ & Zāy', context.l10n.plainVsOneDot, ['ر', 'ز']),
        ('Ṣād & Ḍād', context.l10n.plainVsOneDot, ['ص', 'ض']),
        ('Sīn & Shīn', context.l10n.plainVsThreeDots, ['س', 'ش']),
        (context.l10n.aynGhayn, context.l10n.plainVsOneDot, ['ع', 'غ']),
        ('Fāʼ & Qāf', context.l10n.oneVsTwoDots, ['ف', 'ق']),
      ];

  @override
  Widget build(BuildContext context) {
    final tint = kTint[DeskTab.coach]!;
    return _scroll(context, [
      deskHero(context, DeskTab.coach,
          kicker: context.l10n.fluencyDrills,
          title: context.l10n.tellLookAlikesApart,
          blurb:
              context.l10n.sameShapeDifferentDotsCoach),
      const SizedBox(height: 24),
      deskSection(context, DeskTab.coach, context.l10n.confusableSets,
          action: context.l10n.startADrill,
          onAction: () => pushAdaptive(context, const SpotTheLetterDrill())),
      deskGrid([for (final s in _sets(context)) _setCard(context, s, tint)],
          minWidth: 280),
      const SizedBox(height: 24),
      deskSection(context, DeskTab.coach, context.l10n.moreDrills),
      Row(children: [
        Expanded(
            child: _drillBtn(context, context.l10n.dotDetective, Icons.search_rounded,
                () => pushAdaptive(context, const DotDetectiveDrill()), tint)),
        const SizedBox(width: 14),
        Expanded(
            child: _drillBtn(context, context.l10n.fluencySprint, Icons.bolt_rounded,
                () => pushAdaptive(context, const FluencySprint()), tint)),
      ]),
      if (ProgressScope.of(context).hasReviews) ...[
        const SizedBox(height: 14),
        _drillBtn(
            context,
            ProgressScope.of(context).dueCount > 0
                ? context.l10n.mistakeReviewDue(
                    context.l10n.mistakeReview, ProgressScope.of(context).dueCount)
                : context.l10n.mistakeReviewCaughtUp(context.l10n.mistakeReview),
            Icons.refresh_rounded,
            () => pushAdaptive(
                context,
                mistakeReviewQuiz(context, ProgressScope.of(context),
                    title: context.l10n.mistakeReview)),
            tint),
      ],
    ]);
  }

  Widget _setCard(BuildContext context, (String, String, List<String>) s, TabTint tint) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => pushAdaptive(context, const SpotTheLetterDrill()),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: deskBorder(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (final ch in s.$3) ...[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: tint.softOf(context), borderRadius: BorderRadius.circular(12)),
                  child: Text(ch,
                      style: TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 24,
                          height: 1.3,
                          color: tint.kickerColor)),
                ),
                const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 14),
            Text(s.$1, style: uiStyle(context, size: 16, weight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(s.$2, style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
          ]),
        ),
      ),
    );
  }

  Widget _drillBtn(BuildContext context, String label, IconData icon,
      VoidCallback onTap, TabTint tint) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: deskBorder(context, radius: 16),
          child: Row(children: [
            Icon(icon, color: tint.kickerColor, size: 22),
            const SizedBox(width: 12),
            Text(label, style: uiStyle(context, size: 15, weight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════ QIRĀʼĀT ═══════════════════════════════════════
class DesktopQiraat extends StatelessWidget {
  const DesktopQiraat({super.key});
  @override
  Widget build(BuildContext context) {
    final tint = kTint[DeskTab.qiraat]!;
    return _scroll(context, [
      deskHero(context, DeskTab.qiraat,
          kicker: context.l10n.advancedTenReadings,
          title: context.l10n.tenCanonicalReaders,
          blurb:
              context.l10n.eachReaderTheirCityWhen),
      const SizedBox(height: 24),
      // Not open yet — the reader data is in place, but the hall still needs a
      // proper review before it teaches anyone.
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: deskCard(context),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_clock_rounded, size: 40, color: tint.kickerColor),
            const SizedBox(height: 14),
            Text(context.l10n.comingSoonShaAllah,
                style: uiStyle(context, size: 18, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                context.l10n.qiraHallStillBeingReviewed,
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 13.5, color: pal(context).textDim)),
          ]),
        ),
      ),
    ]);
  }

  // Kept ready for when the hall opens — see the coming-soon panel above.
  // ignore: unused_element
  Widget _readerCard(BuildContext context, Qiraah q, TabTint tint) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 5,
      shadowColor: pal(context).shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(context, q, tint),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: deskBorder(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(q.reader,
                    style: uiStyle(context, size: 16.5, weight: FontWeight.w800)),
              ),
              Text(q.arabic,
                  style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 26,
                      height: 1.2,
                      color: tint.kickerColor)),
            ]),
            const SizedBox(height: 6),
            Text(context.l10n.cityDied(q.city, q.died),
                style: uiStyle(context, size: 13, color: pal(context).textDim)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in [q.rawi1, q.rawi2])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: tint.softOf(context), borderRadius: BorderRadius.circular(9)),
                  child: Text(r,
                      style: uiStyle(context,
                          size: 12, weight: FontWeight.w700, color: tint.kickerColor)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Qiraah q, TabTint tint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal(context).surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(q.reader,
                      style: uiStyle(context, size: 22, weight: FontWeight.w900)),
                ),
                Text(q.arabic,
                    style: TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 34,
                        color: tint.kickerColor)),
              ]),
              const SizedBox(height: 4),
              Text(context.l10n.cityDiedNarrators(q.city, q.died, q.rawi1, q.rawi2),
                  style: uiStyle(context,
                      size: 13.5, weight: FontWeight.w700, color: tint.kickerColor)),
              if (q.bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(q.bio,
                    style: uiStyle(context, size: 14).copyWith(height: 1.55)),
              ],
              const SizedBox(height: 16),
              Text(context.l10n.signatures,
                  style: uiStyle(context,
                      size: 12, weight: FontWeight.w800, color: pal(context).textDim)),
              const SizedBox(height: 8),
              for (final s in q.signatures)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('• ', style: uiStyle(context, size: 14, color: tint.kickerColor)),
                    Expanded(child: Text(s, style: uiStyle(context, size: 13.5))),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hosts a mobile unit screen inside the desktop shell. The unit builds its
/// own Scaffold/AppBar; we wrap it so it fills the shell content area cleanly
/// (the desktop header above provides the back button).
class _UnitHost extends StatelessWidget {
  final WidgetBuilder builder;
  const _UnitHost({required this.builder});
  @override
  Widget build(BuildContext context) {
    // The unit's own Scaffold renders inside; its AppBar auto-hides the back
    // button because there is no route below it to pop. Each screen provides
    // its own desktop chrome now (quizzes render a self-contained panel).
    return Builder(builder: builder);
  }
}
