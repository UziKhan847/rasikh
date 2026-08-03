import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/l10n.dart';
import '../core/audio.dart';
import '../data/votd.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'dyslexia_screen.dart';
import 'qaidah_screen.dart';
import 'qiraat_screen.dart';
import 'quran_screen.dart';
import 'search.dart';
import 'tajweed_screen.dart';
import 'tashkeel_screen.dart';
import 'tracing_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final s = SettingsScope.of(context);
    final modules = [
      _M(context.l10n.quranReader, context.l10n.quranSub, '﴿﴾',
          pal(context).accentDeep, (_) => const SurahListScreen()),
      _M(context.l10n.qaidahPath, context.l10n.qaidahSub, 'ق',
          pal(context).accent, (_) => const QaidahScreen()),
      _M(context.l10n.tracingStudio, context.l10n.tracingSub, 'ب',
          pal(context).accent2, (_) => const TracingScreen()),
      _M(context.l10n.tashkilLab, context.l10n.tashkilSub, 'بَ',
          AppColors.lilac, (_) => const TashkeelScreen()),
      _M(context.l10n.tajwidAcademy, context.l10n.tajwidSub, 'ج',
          AppColors.tjGhunnah, (_) => const TajweedScreen()),
      _M(context.l10n.readingCoach, context.l10n.coachSub, 'ت',
          pal(context).accent2, (_) => const DyslexiaScreen()),
      _M(context.l10n.qiraHallAdvanced, context.l10n.qiraatSub, '١٠',
          AppColors.tjMadd4, (_) => const QiraatScreen(), soon: true),
    ];
    final themeIcon = switch (s.themeMode) {
      'dark' => Icons.dark_mode_rounded,
      'oled' => Icons.brightness_2_rounded,
      _ => Icons.light_mode_rounded,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [pal(context).accent, pal(context).accentBright],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).accent.withValues(alpha: .35),
                        blurRadius: 22,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('السَّلَامُ عَلَيْكُمْ',
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.left,
                                style: arabicStyle(context,
                                    size: 26, height: 1.5,
                                    color: Colors.white)),
                          ),
                        ]),
                        Text(context.l10n.qiraahArabiyyah,
                            style: uiStyle(context,
                                size: 24,
                                weight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(context.l10n.tagline,
                            style: uiStyle(context,
                                size: 13.5,
                                color: Colors.white.withValues(alpha: .85))),
                      ],
                    ),
                  ),
                  Column(children: [
                    ProgressRing(
                      fraction:
                          (progress.activitiesDone / 26).clamp(0.0, 1.0),
                      size: 74,
                      track: Colors.white.withValues(alpha: .3),
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.white, size: 17),
                          Text('${progress.totalStars}',
                              style: uiStyle(context,
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onLongPress: () => s.update(() => s.themeFamily =
                          s.themeFamily == 'mint' ? 'noor' : 'mint'),
                      child: TapScale(
                        onTap: s.cycleTheme,
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(themeIcon, size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                              s.themeMode == 'oled'
                                  ? context.l10n.themeOled
                                  : s.themeMode == 'dark'
                                      ? context.l10n.themeDark
                                      : context.l10n.themeLight,
                              style: uiStyle(context,
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                        ),
                      ),
                    ),
                    // Hiding system status/nav bars is a phone/tablet
                    // concept — desktop windows have none to hide, so the
                    // toggle is meaningless there (see _SystemUiSync).
                    if (!isDesktopPlatform()) ...[
                      const SizedBox(height: 6),
                      TapScale(
                        onTap: () => s.update(() => s.immersive = !s.immersive),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: s.immersive ? .38 : .22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                              s.immersive
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              size: 16,
                              color: Colors.white),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TapScale(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AboutScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // ── global search (letters, tajwīd rules, sūrahs) ──
            FadeSlideIn(
              delayMs: 30,
              child: TapScale(
                onTap: () =>
                    showSearch(context: context, delegate: GlobalSearch(context.l10n.searchLettersRulesSurahs)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: pal(context).shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: pal(context).textDim),
                    const SizedBox(width: 12),
                    Text(context.l10n.searchLettersRulesSurahs,
                        style: uiStyle(context,
                            size: 14, color: pal(context).textDim)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── streak + this-week (mobile) ──
            FadeSlideIn(
              delayMs: 40,
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal(context).surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: pal(context).accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                          context.l10n.streakDaysLabel(progress.streakDays),
                          style: uiStyle(context,
                              size: 15, weight: FontWeight.w800)),
                      const Spacer(),
                      Text(
                          context.l10n.thisWeek(progress.weekDoneCount, progress.weekGoal),
                          style: uiStyle(context,
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: pal(context).textDim)),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Column(children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: progress.weekdayActive(i)
                                    ? pal(context).accent
                                    : pal(context).bg,
                                borderRadius: BorderRadius.circular(10),
                                border: i == progress.todayWeekday &&
                                        !progress.weekdayActive(i)
                                    ? Border.all(
                                        color: pal(context).accent, width: 2)
                                    : null,
                              ),
                              child: progress.weekdayActive(i)
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 15)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(context.l10n.weekdayInitials.split(',')[i],
                                style: uiStyle(context,
                                    size: 10.5,
                                    weight: FontWeight.w700,
                                    color: i == progress.todayWeekday
                                        ? pal(context).text
                                        : pal(context).textDim)),
                          ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── verse of the day (mobile) ──
            FadeSlideIn(
              delayMs: 80,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: pal(context).surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 5,
                          height: 16,
                          decoration: BoxDecoration(
                              color: pal(context).accent,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Text(context.l10n.verseDay,
                          style: uiStyle(context,
                              size: 14.5, weight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(verseOfDay.ar,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: quranicStyle(context, size: 26, height: 1.95)),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text(verseOfDay.ref,
                          style: uiStyle(context,
                              size: 12.5,
                              weight: FontWeight.w800,
                              color: pal(context).textDim)),
                      const Spacer(),
                      TapScale(
                        onTap: () => AyahAudio.instance
                            .play(verseOfDay.s, verseOfDay.v),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: pal(context).accent,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < modules.length; i++)
              FadeSlideIn(
                delayMs: 60 * (i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: _ModuleCard(m: modules[i]),
                ),
              ),
            FadeSlideIn(
              delayMs: 60 * (modules.length + 1),
              child: Center(
                child: Text(
                  'وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا — 73:4',
                  textDirection: TextDirection.rtl,
                  style: quranicStyle(context, size: 20, height: 1.85,
                      color: pal(context).textDim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _M {
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final WidgetBuilder builder;

  /// Listed but not open yet: the card is dimmed, tagged, and won't navigate.
  final bool soon;
  _M(this.title, this.subtitle, this.badge, this.color, this.builder,
      {this.soon = false});
}

class _ModuleCard extends StatelessWidget {
  final _M m;
  const _ModuleCard({required this.m});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        if (m.soon) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
                content: Text(context.l10n.comingSoonNamed(m.title))));
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: m.builder));
      },
      child: Opacity(
        opacity: m.soon ? .55 : 1,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(m.badge,
                textDirection: TextDirection.rtl,
                style: arabicStyle(context, size: 22, height: 1.3,
                    color: m.color)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiStyle(context,
                            size: 17, weight: FontWeight.w700)),
                  ),
                  if (m.soon) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: pal(context).surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(context.l10n.soon,
                          style: uiStyle(context,
                              size: 9.5,
                              weight: FontWeight.w800,
                              color: pal(context).textDim)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(m.subtitle,
                    style: uiStyle(context,
                        size: 13, color: pal(context).textDim)),
              ],
            ),
          ),
          Icon(
              m.soon
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              color: pal(context).textDim),
        ]),
      ),
      ),
    );
  }
}
