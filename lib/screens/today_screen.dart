import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/marks/marks_model.dart';
import '../core/marks/marks_store.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';
import '../data/votd.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import 'qaidah_screen.dart';
import 'quran_screen.dart';
import 'search.dart';
import 'settings_screen.dart';
import 'shell/app_shell.dart';
import 'shell/modules.dart';

/// Today: the greeting, Continue reading, the streak and daily goal, the verse
/// of the day, today's Qāʿidah lesson and the Explore tiles. Two columns on
/// a wide desktop window.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<SurahMeta>? _meta;

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _meta = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: screenDecoration(context),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1080;
            final continueCard = _ContinueCard(meta: _meta);
            final lesson = const _LessonCard();
            final explore = const _Explore();
            final streak = const _StreakCard();
            final votd = const _VerseOfTheDay();
            const marksCard = _MarksCard();
            return ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, wide ? 40 : 28),
              children: [
                QColumn(
                  kind: ContentKind.list,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 145,
                            child: Column(children: [
                              continueCard,
                              const SizedBox(height: 14),
                              lesson,
                              explore,
                            ]),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 100,
                            child: Column(children: [
                              streak,
                              marksCard,
                              const SizedBox(height: 14),
                              votd,
                            ]),
                          ),
                        ])
                      else ...[
                        continueCard,
                        const SizedBox(height: 14),
                        streak,
                        marksCard,
                        const SizedBox(height: 14),
                        votd,
                        const SizedBox(height: 14),
                        lesson,
                        explore,
                      ],
                      const SizedBox(height: 28),
                      const _Footer(),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final lang = SettingsScope.of(context).language;
    final now = DateTime.now();
    String date;
    try {
      date = DateFormat('EEEE · d MMMM', lang).format(now);
    } catch (_) {
      date = DateFormat('EEEE · d MMMM').format(now);
    }
    final latin = lang == 'en' || lang == 'fr' || lang == 'es';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(latin ? date.toUpperCase() : date, style: labelStyle(context)),
          const SizedBox(height: 4),
          Text(context.l10n.assalamuAlaykum,
              style: displayStyle(context, size: 30)),
        ]),
      ),
      const SizedBox(width: 10),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: p.sel, borderRadius: BorderRadius.circular(17)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.star, size: 14, color: p.gold),
          const SizedBox(width: 6),
          Text('${prog.totalStars}',
              style: uiStyle(context, size: 14, weight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(width: 8),
      QIconButton(
        icon: AppIcons.search,
        tooltip: context.l10n.search,
        onTap: () => showSearch(
            context: context,
            delegate: GlobalSearch(context.l10n.searchLettersRulesSurahs)),
      ),
      // On a computer, tablet or the web, the way back to the desktop layout.
      if (!useDesktop(context) && canUseDesktopShell(context)) ...[
        const SizedBox(width: 8),
        QIconButton(
          icon: AppIcons.desktop,
          tooltip: '${context.l10n.switchToDesktopLayout} (Ctrl+Shift+L)',
          onTap: () => toggleLayout(context),
        ),
      ],
      if (!useDesktop(context)) ...[
        const SizedBox(width: 8),
        QIconButton(
          icon: AppIcons.settings,
          tooltip: context.l10n.settings,
          onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    ]);
  }
}

/// Opens the verse-by-verse reader at [surah] (and [ayah]).
Future<void> openReader(BuildContext context, int surah, {int? ayah}) async {
  final meta = await QuranRepo.meta();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(
          builder: (_) =>
              SurahReaderScreen(meta: meta[surah - 1], startAyah: ayah)));
}

class _ContinueCard extends StatelessWidget {
  final List<SurahMeta>? meta;
  const _ContinueCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final (surah, ayah) = prog.lastRead ?? (1, 1);
    final m = meta == null || meta!.length < surah ? null : meta![surah - 1];
    final total = m?.ayahs ?? 7;
    final juz = MushafRepo.juzOfAyah(surah, ayah);
    return QHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  prog.lastRead == null
                      ? context.l10n.startReading.toUpperCase()
                      : context.l10n.continueReading.toUpperCase(),
                  style: uiStyle(context,
                      size: 12,
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                      color: kHeroInk2)),
              const SizedBox(height: 8),
              Text(m?.tname ?? 'Al-Fātiḥah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(context, size: 28, color: kHeroInk)),
              const SizedBox(height: 4),
              Text(context.l10n.ayahOfJuz(ayah, total, juz),
                  style: uiStyle(context, size: 13, color: kHeroInk2)),
            ]),
          ),
          if (m != null)
            Text(m.name,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 30,
                    height: 1.6,
                    color: kHeroGold)),
        ]),
        const SizedBox(height: 14),
        QProgressBar(
            value: ayah / total,
            color: kHeroGold,
            track: Colors.white.withValues(alpha: .14)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: _HeroButton(
              label: context.l10n.resume2,
              filled: true,
              onTap: () => openReader(context, surah, ayah: ayah),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: _HeroButton(
            label: context.l10n.recite,
            icon: AppIcons.recite,
            onTap: () {
              AyahAudio.instance.play(surah, ayah,
                  reciter: SettingsScope.of(context).reciter);
              openReader(context, surah, ayah: ayah);
            },
          )),
        ]),
      ]),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;
  const _HeroButton(
      {required this.label, this.icon, this.filled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? const Color(0xFF0F3B32) : kHeroInk;
    return Material(
      color: filled ? kHeroInk : Colors.transparent,
      shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: kHeroInk.withValues(alpha: .35))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context,
                      size: 15, weight: FontWeight.w700, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final s = SettingsScope.of(context);
    final days = prog.streakDays < 0 ? 0 : prog.streakDays;
    final initials = context.l10n.weekdayInitials.split(',');
    final today = prog.todayWeekday;
    return QCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(AppIcons.streak, size: 16, color: Color(0xFFD9622B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.streakDaysLabel(days),
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
          ),
          Text(
              context.l10n.goalMinutesToday(
                  prog.minutesToday, s.dailyGoalMinutes),
              style: uiStyle(context, size: 13, color: p.ink3)),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 36),
                  child: Column(children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: prog.weekdayActive(i) ? p.accBg : p.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: prog.weekdayActive(i)
                                  ? p.acc
                                  : (i == today ? p.gold : p.line),
                              width: i == today ? 1.5 : 1),
                        ),
                        child: prog.weekdayActive(i)
                            ? const Icon(AppIcons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(i < initials.length ? initials[i] : '',
                        style: uiStyle(context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: i == today ? p.ink : p.ink3)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        QProgressBar(
            value: s.dailyGoalMinutes == 0
                ? 0
                : prog.minutesToday / s.dailyGoalMinutes),
      ]),
    );
  }
}

class _VerseOfTheDay extends StatelessWidget {
  const _VerseOfTheDay();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final v = verseOfDay;
    final hair = p.gold;
    final lang = SettingsScope.of(context).language;
    final latin = lang == 'en' || lang == 'fr' || lang == 'es';
    return QCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 28, height: 1, color: hair),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
                latin ? context.l10n.verseDay.toUpperCase() : context.l10n.verseDay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle(context, size: 11.5)),
          ),
          const SizedBox(width: 10),
          Container(width: 28, height: 1, color: hair),
        ]),
        const SizedBox(height: 14),
        Text(v.ar,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 34, height: 1.9)
                .copyWith(color: p.ink)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(v.ref,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: uiStyle(context,
                    size: 13, weight: FontWeight.w600, color: p.ink2)),
          ),
          const SizedBox(width: 12),
          QIconButton(
            icon: AppIcons.play,
            size: 44,
            iconSize: 18,
            tooltip: context.l10n.listen,
            onTap: () => AyahAudio.instance
                .play(v.s, v.v, reciter: SettingsScope.of(context).reciter),
          ),
        ]),
      ]),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final units = qaidahUnits(context);
    var i = units.indexWhere((u) => prog.starsFor(u.progressId) == 0);
    if (i < 0) i = units.length - 1;
    final u = units[i];
    final done = units.where((x) => prog.starsFor(x.progressId) > 0).length;
    return QCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context, rootNavigator: !useDesktop(context))
          .push(MaterialPageRoute(builder: (_) => QaidahUnitHub(unit: u))),
      child: Row(children: [
        QGlyphTile(u.arabicBadge, hue: 165, size: 56, radius: 16),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.todaysLessonUnit(i + 1),
                style: uiStyle(context,
                    size: 12, weight: FontWeight.w600, color: p.ink3)),
            const SizedBox(height: 2),
            Text(u.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            QProgressBar(value: done / units.length),
          ]),
        ),
        const SizedBox(width: 10),
        Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
      ]),
    );
  }
}

class _Explore extends StatelessWidget {
  const _Explore();
  @override
  Widget build(BuildContext context) {
    final tiles = <(String, double, String, String, VoidCallback)>[
      ('ج', 170, context.l10n.tajwidAcademy, context.l10n.exploreTajwidSub,
          () => LearnModule.tajwid.open(context)),
      ('ب', 290, context.l10n.tracingStudio, context.l10n.exploreTraceSub,
          () => ShellScope.goTo(context, AppSection.trace)),
      ('؟', 75, context.l10n.letterQuiz, context.l10n.exploreQuizSub,
          () => Navigator.of(context, rootNavigator: !useDesktop(context)).push(
              MaterialPageRoute(builder: (c) => letterQuizScreen(c)))),
      ('۞', 28, context.l10n.navMushaf, context.l10n.exploreMushafSub,
          () => ShellScope.goTo(context, AppSection.mushaf)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QSectionLabel(context.l10n.explore),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final t in tiles)
            SizedBox(
              width: w,
              child: QCard(
                padding: const EdgeInsets.all(14),
                onTap: t.$5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  QGlyphTile(t.$1, hue: t.$2, size: 42, radius: 12),
                  const SizedBox(height: 12),
                  Text(t.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context, size: 14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(t.$4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 12, color: pal(context).ink3)),
                ]),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Column(children: [
      Text('وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا',
          textDirection: TextDirection.rtl,
          style: TextStyle(
              fontFamily: 'UthmanicHafs', fontSize: 22, height: 1.8, color: p.dim)),
      Text('73:4', style: uiStyle(context, size: 11, color: p.dim)),
    ]);
  }
}

/// The active mark book at a glance — only once it has marks.
class _MarksCard extends StatelessWidget {
  const _MarksCard();

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final book = store?.ready == true ? store!.activeBook : null;
    if (store == null || book == null) return const SizedBox.shrink();
    final marks = store.marksOf(book.id).where((m) => m.type != MarkType.note);
    if (marks.isEmpty) return const SizedBox.shrink();
    var fixed = 0;
    for (final m in marks) {
      if (store.isFixed(m)) fixed++;
    }
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: QCard(
        onTap: () => ShellScope.goTo(context, AppSection.hifz),
        child: Row(children: [
          Icon(AppIcons.hifz, color: p.acc),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${context.l10n.mkTodayCard} · ${book.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              Text(context.l10n.mkTodayCardSub(marks.length - fixed, fixed),
                  style: uiStyle(context, size: 13, color: p.ink3)),
            ]),
          ),
          Icon(AppIcons.chevronRight, color: p.ink3),
        ]),
      ),
    );
  }
}
