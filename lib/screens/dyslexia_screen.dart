import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/letters.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import '../ui/app_icons.dart';

/// 👁 Reading Coach — built for readers who find similar shapes and dots
/// hard to tell apart. One-tap preset, fine-grained reading settings, and
/// three drills: Spot the Letter, Dot Detective, and the Fluency Sprint.
class DyslexiaScreen extends StatelessWidget {
  const DyslexiaScreen({super.key, this.embedded = false});
  final bool embedded;

  /// The look-alike families the coach drills. The letter groups are fixed;
  /// the labels are localised.
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
    final s = SettingsScope.of(context);
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    Widget cap(Widget w) => QColumn(child: w);
    final drills = <Widget>[
      _drill(context, context.l10n.spotTheLetter, context.l10n.spotTheLetterSub,
          AppIcons.coach, 220, 'coach.spot', (_) => const SpotTheLetterDrill()),
      _drill(context, context.l10n.dotDetective, context.l10n.dotDetectiveSub,
          AppIcons.dots, 280, 'coach.dots', (_) => const DotDetectiveDrill()),
      _drill(context, context.l10n.fluencySprint, context.l10n.fluencySprintSub,
          AppIcons.bolt, 75, 'coach.sprint', (_) => const FluencySprint()),
      if (prog.hasReviews)
        _drill(
            context,
            context.l10n.mistakeReview,
            _reviewSubtitle(context),
            AppIcons.repeat,
            50,
            'coach.review',
            (c) => mistakeReviewQuiz(c, prog, title: context.l10n.mistakeReview)),
    ];
    Widget grid(List<Widget> items, {double gap = 10}) => LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 680 ? 2 : 1;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final i in items) SizedBox(width: w, child: i),
            ]);
          },
        );
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.readingCoach)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            cap(Text(context.l10n.tellLookAlikesApart,
                style: displayStyle(context, size: 28, height: 1.2))),
            const SizedBox(height: 8),
            cap(Text(context.l10n.coachIntroBlurb,
                style: uiStyle(context, size: 14.5, color: p.ink2, height: 1.5))),
            const SizedBox(height: 16),
            cap(QHeroCard(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 16,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.comfort, color: kHeroGold, size: 26),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                            s.dyslexiaMode
                                ? context.l10n.comfortPresetFineTuneBelow
                                : context.l10n.sameShapeDifferentDotsCoach,
                            style: uiStyle(context,
                                size: 14, color: kHeroInk, height: 1.45)),
                      ),
                    ]),
                  ),
                  if (!s.dyslexiaMode)
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: kHeroInk,
                          foregroundColor: const Color(0xFF0F3B32)),
                      onPressed: () {
                        s.enableDyslexiaPreset();
                        showQToast(context, context.l10n.comfortPresetOn);
                      },
                      child: Text(context.l10n.turnComfortPreset),
                    ),
                ],
              ),
            )),
            cap(SectionHeader(context.l10n.drills,
                subtitle: context.l10n.shortKindRepeatable)),
            cap(grid(drills)),
            cap(SectionHeader(context.l10n.confusableSets,
                subtitle: context.l10n.sameSkeletonDotsDecide)),
            cap(LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 680 ? 4 : 2;
              final w = (c.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final set in _sets(context))
                  SizedBox(width: w, child: _setCard(context, set)),
              ]);
            })),
            if (wide)
              cap(Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _setup(context)),
                  const SizedBox(width: 20),
                  Expanded(child: _sample(context)),
                ],
              ))
            else ...[
              cap(_setup(context)),
              cap(_sample(context)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(context.l10n.readingSetup,
              subtitle: context.l10n.appliesEverywhereApp),
          const _SettingsPanel(),
        ],
      );

  Widget _sample(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(context.l10n.sample,
            subtitle: context.l10n.yourSettingsLive),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: s.paperMode ? p.paper : p.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.line2),
          ),
          child: Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: quranicStyle(context, size: 30)),
        ),
      ],
    );
  }

  Widget _setCard(BuildContext context, (String, String, List<String>) set) {
    final p = pal(context);
    final t = hueTint(context, 220);
    return QCard(
      padding: const EdgeInsets.all(14),
      onTap: () => pushAdaptive(context, const SpotTheLetterDrill()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(children: [
            for (final ch in set.$3) ...[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: t.bg, borderRadius: BorderRadius.circular(11)),
                child: Text(ch,
                    style: arabicStyle(context, size: 20, height: 1.3, color: t.fg)),
              ),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Text(set.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 14, weight: FontWeight.w700)),
        Text(set.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 12, color: p.ink3)),
      ]),
    );
  }

  /// One line describing the spaced-repetition state: what's due today, or
  /// when the next card comes back if the learner is caught up.
  String _reviewSubtitle(BuildContext context) {
    final p = ProgressScope.of(context);
    final due = p.dueCount;
    if (due > 0) {
      return context.l10n.cardsDueForReview(due);
    }
    final n = p.nextReviewInDays;
    if (n == null || n <= 0) return context.l10n.reviewMissedItems;
    return context.l10n.allCaughtUp(n);
  }

  Widget _drill(BuildContext context, String title, String sub, IconData icon,
      double hue, String progressId, WidgetBuilder builder) {
    final p = pal(context);
    final t = hueTint(context, hue);
    final stars = ProgressScope.of(context).starsFor(progressId);
    return QCard(
      padding: const EdgeInsets.all(14),
      onTap: () => pushAdaptive(context, builder(context)),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: t.fg, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  style: uiStyle(context, size: 12.5, color: p.ink3, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StarRow(stars, size: 14),
      ]),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    Widget slider(String label, double value, double min, double max,
            void Function(double) set) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: uiStyle(context, size: 14, weight: FontWeight.w600))),
            Expanded(
              child: SettingsSlider(
                  value: value,
                  min: min,
                  max: max,
                  onCommit: (v) => s.update(() => set(v))),
            ),
          ]),
        );
    Widget toggle(String label, bool value, void Function(bool) set) => QRow(
          title: label,
          control: QSwitch(value: value, onChanged: (v) => s.update(() => set(v))),
        );
    return QGroup(children: [
      QRow(
        title: context.l10n.tashkilTermsLabel,
        control: QSegmented<String>(
          expand: false,
          options: [
            ('arabic', context.l10n.arabicTerms, null),
            ('indopak', context.l10n.indopak, null),
          ],
          value: s.tashkilTerms,
          onChanged: (v) => s.update(() => s.tashkilTerms = v),
        ),
      ),
      slider(context.l10n.letterSize, s.arabicScale, 0.8, 1.8,
          (v) => s.arabicScale = v),
      slider(context.l10n.wordSpacing, s.wordSpacing, 0, 24,
          (v) => s.wordSpacing = v),
      slider(context.l10n.glyphSpacing, s.letterTracking, 0, 10,
          (v) => s.letterTracking = v),
      toggle(context.l10n.warmPaperBackground, s.paperMode, (v) => s.paperMode = v),
      toggle(context.l10n.colorCodedDots, s.dotEmphasis, (v) => s.dotEmphasis = v),
      toggle(context.l10n.focusWindow, s.focusWindow, (v) => s.focusWindow = v),
      toggle(context.l10n.hapticFeedback, s.haptics, (v) => s.haptics = v),
    ]);
  }
}

// ───────────────────────── Spot the Letter ─────────────────────────

class SpotTheLetterDrill extends StatefulWidget {
  const SpotTheLetterDrill({super.key});

  @override
  State<SpotTheLetterDrill> createState() => _SpotTheLetterDrillState();
}

class _SpotTheLetterDrillState extends State<SpotTheLetterDrill> {
  final rng = math.Random();
  static const totalRounds = 12;
  int round = 0;
  int misses = 0;
  late String target;
  late List<String> grid;
  int? wrongIndex;
  // Which family each round uses, chosen without replacement (cycling once
  // exhausted) — 10 families across 12 rounds used to repeat a family by
  // pigeonhole with every round drawing independently; this guarantees all
  // 10 appear before any repeats.
  late final List<int> familyOrder =
      pickN(List.generate(similarFamilies.length, (i) => i), totalRounds, rng);

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    final family = similarFamilies.values.elementAt(familyOrder[round]);
    target = family[rng.nextInt(family.length)];
    grid = [
      target,
      for (var i = 0; i < 8; i++) family[rng.nextInt(family.length)],
    ];
    // ensure decoys exist
    grid.shuffle(rng);
    if (!grid.contains(target)) grid[0] = target;
    wrongIndex = null;
  }

  void _tap(int i) async {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    if (grid[i] == target) {
      if (s.haptics) HapticFeedback.lightImpact();
      prog.reviewCorrect('letter.$target'); // reading it right promotes the card
      if (round + 1 >= totalRounds) {
        final stars = misses == 0 ? 3 : (misses <= 3 ? 2 : 1);
        ProgressScope.read(context).report('coach.spot', stars);
        await showDialog(
            context: context,
            builder: (_) => _doneDialog(context, stars,
                context.l10n.toldApartLookAlikes(totalRounds)));
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() {
        round++;
        _nextRound();
      });
    } else {
      misses++;
      if (s.haptics) HapticFeedback.heavyImpact();
      // Remember the confusion for spaced review: "name this letter".
      final tl = letterFor(target);
      final fam = (tl.similarGroup != null
              ? similarFamilies[tl.similarGroup!]!
              : const <String>[])
          .where((c) => c != target)
          .map((c) => letterName(context, letterFor(c)))
          .toList();
      prog.recordMiss('letter.$target', target,
          answer: letterName(context, tl), prompt: context.l10n.qpNameThisLetter, distractors: fam);
      setState(() => wrongIndex = i);
    }
  }

  /// Desktop: the reference layout — a sticky "Find every occurrence of…"
  /// target card on the left, the 3-column letter grid on the right.
  Widget _desktopBuild(BuildContext context, AppSettings s, ArabicLetter tl) {
    final coral = pal(context).acc;
    final soft = pal(context).accSoft;
    final dotInfo = dotsDesc(context, tl.dotCount, tl.dotPos);
    return Scaffold(
      backgroundColor: pal(context).bg,
      appBar: AppBar(
          title: Text(context.l10n.spotTheLetterRound(round + 1, totalRounds))),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 12, 34, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── target card ──
                SizedBox(
                  width: 340,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(32, 38, 32, 32),
                    decoration: BoxDecoration(
                      color: pal(context).card,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: pal(context)
                              .track
                              .withValues(alpha: .6)),
                      boxShadow: qShadows(context, [
                        BoxShadow(
                            color: pal(context).shadow,
                            blurRadius: 24,
                            offset: const Offset(0, 6)),
                      ]),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(context.l10n.findEveryOccurrence,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: coral)),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 34, horizontal: 20),
                          decoration: BoxDecoration(
                              color: soft,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(children: [
                            Text(target,
                                style: quranicStyle(context,
                                    size: 120,
                                    height: 1.85,
                                    color: pal(context).ink)),
                            const SizedBox(height: 18),
                            Text(context.l10n.letterDash(letterName(context, tl), tl.translit),
                                style: uiStyle(context,
                                    size: 24, weight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const SizedBox.shrink(),
                            Text(dotInfo,
                                style: uiStyle(context, size: 14, weight: FontWeight.w600, color: coral)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.l10n.roundProgress,
                                style: uiStyle(context,
                                    size: 13, color: pal(context).ink3)),
                            Text('${round + 1} / $totalRounds',
                                style: uiStyle(context,
                                    size: 14, weight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (round + 1) / totalRounds,
                            minHeight: 7,
                            backgroundColor: soft,
                            valueColor:
                                AlwaysStoppedAnimation(coral),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                // ── the grid ──
                Expanded(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.5),
                    itemCount: grid.length,
                    itemBuilder: (context, i) => _deskCell(context, s, i),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _deskCell(BuildContext context, AppSettings s, int i) {
    final l = letterFor(grid[i]);
    final isWrong = wrongIndex == i;
    return TapScale(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: pal(context).card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: isWrong
                  ? AppColors.bad
                  : pal(context).track.withValues(alpha: .6),
              width: isWrong ? 2 : 1),
          boxShadow: qShadows(context, [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ]),
        ),
        child: Stack(children: [
          Center(
            child: Text(grid[i],
                style: quranicStyle(context,
                    size: 64, height: 1.85, color: pal(context).ink)),
          ),
          if (s.dotEmphasis && l.dotCount > 0)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.lilac.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                    '${l.dotCount}${l.dotPos == 'below' ? '↓' : '↑'}',
                    style: uiStyle(context,
                        size: 11,
                        weight: FontWeight.w800,
                        color: AppColors.lilac)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final tl = letterFor(target);
    if (useDesktop(context)) return _desktopBuild(context, s, tl);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.spotTheLetterRound(round + 1, totalRounds))),
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: useDesktop(context) ? 640 : double.infinity),
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(context.l10n.findEveryTimeSameLetter,
              style: uiStyle(context, size: 15, color: pal(context).ink3)),
          const SizedBox(height: 6),
          Text(context.l10n.letterDash(letterName(context, tl), tl.translit),
              style: uiStyle(context, size: 19, weight: FontWeight.w700)),
          if (s.dotEmphasis)
            Text(
                dotsDesc(context, tl.dotCount, tl.dotPos),
                style: uiStyle(context, size: 13.5, color: pal(context).acc)),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: grid.length,
              itemBuilder: (context, i) {
                final l = letterFor(grid[i]);
                final isWrong = wrongIndex == i;
                return TapScale(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: s.paperMode ? pal(context).paper : pal(context).card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color:
                              isWrong ? AppColors.bad : Colors.transparent,
                          width: 2),
                    ),
                    child: Stack(children: [
                      Center(
                        child: Text(grid[i],
                            style: quranicStyle(context, size: 44)),
                      ),
                      if (s.dotEmphasis && l.dotCount > 0)
                        Positioned(
                          top: 6, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (l.dotPos == 'below'
                                      ? pal(context).acc
                                      : AppColors.lilac)
                                  .withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '${l.dotCount}${l.dotPos == 'below' ? '↓' : '↑'}',
                                style: uiStyle(context,
                                    size: 11, color: Colors.white,
                                    weight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
          ),
        ),
      )),
    );
  }
}

// ───────────────────────── Dot Detective ─────────────────────────

class DotDetectiveDrill extends StatelessWidget {
  const DotDetectiveDrill({super.key});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random();
    final dotted = letters.where((l) => l.similarGroup != null).toList()
      ..shuffle(rng);
    final qs = <QuizQuestion>[];
    for (final l in dotted.take(12)) {
      final answer = dotsShort(context, l.dotCount, l.dotPos);
      // Options come from the SAME helper as the answer, so the correct one
      // always matches exactly — in every language.
      final pool = [
        dotsShort(context, 0, 'none'),
        dotsShort(context, 1, 'above'),
        dotsShort(context, 1, 'below'),
        dotsShort(context, 1, 'inside'),
        dotsShort(context, 2, 'above'),
        dotsShort(context, 2, 'below'),
        dotsShort(context, 3, 'above'),
      ];
      final o = buildOptions(answer, pool, rng);
      qs.add(QuizQuestion(
          prompt: context.l10n.qpWhereDotsLive(letterName(context, l)),
          arabic: l.char,
          reviewId: 'coach.dots.${l.char}',
          options: o.options,
          correct: o.correct,
          explain: context.l10n
              .lookAlikesList(similarFamilies[l.similarGroup]!.join(' '))));
    }
    return QuizScreen(
        title: context.l10n.dotDetective, progressId: 'coach.dots', questions: qs);
  }
}

// ───────────────────────── Fluency Sprint ─────────────────────────

const sprintWords = <String>[
  'بِسۡمِ', 'ٱللَّهِ', 'ٱلرَّحۡمَٰنِ', 'ٱلرَّحِيمِ', 'ٱلۡحَمۡدُ', 'رَبِّ',
  'ٱلۡعَٰلَمِينَ', 'مَٰلِكِ', 'يَوۡمِ', 'ٱلدِّينِ', 'إِيَّاكَ',
  'نَعۡبُدُ', 'نَسۡتَعِينُ', 'ٱهۡدِنَا', 'ٱلصِّرَٰطَ',
];

class FluencySprint extends StatefulWidget {
  const FluencySprint({super.key});

  @override
  State<FluencySprint> createState() => _FluencySprintState();
}

class _FluencySprintState extends State<FluencySprint> {
  int index = -1; // -1 = not started
  late DateTime start;
  Duration? elapsed;
  Timer? ticker;

  void _start() {
    setState(() {
      index = 0;
      start = DateTime.now();
      elapsed = null;
    });
    ticker = Timer.periodic(
        const Duration(milliseconds: 200), (_) => setState(() {}));
  }

  void _next() {
    final s = SettingsScope.of(context);
    if (s.haptics) HapticFeedback.selectionClick();
    if (index + 1 >= sprintWords.length) {
      ticker?.cancel();
      final d = DateTime.now().difference(start);
      final wpm = sprintWords.length / (d.inMilliseconds / 60000);
      final stars = wpm >= 30 ? 3 : (wpm >= 18 ? 2 : 1);
      ProgressScope.read(context).report('coach.sprint', stars);
      setState(() {
        elapsed = d;
        index = -1;
      });
      showDialog(
          context: context,
          builder: (_) => _doneDialog(context, stars,
              context.l10n.sprintResult(
                    '${d.inSeconds}', wpm.toStringAsFixed(0))));
    } else {
      setState(() => index++);
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  /// Desktop: the reference sprint — an intro hero card with a watermark and
  /// coral CTA, then a large tap-card with word count + live timer above it.
  Widget _desktopBuild(BuildContext context, bool running, double secs) {
    final coral = pal(context).acc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final softIcon = dark ? const Color(0xFF2A1512) : const Color(0xFFFDE9E4);
    final card = BoxDecoration(
      color: pal(context).card,
      borderRadius: BorderRadius.circular(28),
      border:
          Border.all(color: pal(context).track.withValues(alpha: .6)),
      boxShadow: qShadows(context, [
        BoxShadow(
            color: pal(context).shadow,
            blurRadius: 30,
            offset: const Offset(0, 8)),
      ]),
    );
    if (!running) {
      return Scaffold(
      appBar: AppBar(title: Text(context.l10n.fluencySprint)),
        backgroundColor: pal(context).bg,
        body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding:
                  const EdgeInsets.symmetric(vertical: 70, horizontal: 50),
              decoration: card,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(clipBehavior: Clip.hardEdge, children: [
                  Positioned(
                    top: -40,
                    right: -10,
                    child: Text('اقرأ',
                        style: TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 240,
                            height: 1,
                            color: coral.withValues(alpha: .10))),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 74,
                      height: 74,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: softIcon,
                          borderRadius: BorderRadius.circular(22)),
                      child: Icon(AppIcons.bolt, size: 36, color: coral),
                    ),
                    const SizedBox(height: 26),
                    Text(context.l10n.fluencySprint,
                        style: uiStyle(context,
                            size: 30, weight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        context.l10n.readEachWordAloudThen,
                        textAlign: TextAlign.center,
                        style: uiStyle(context,
                                size: 16, color: pal(context).ink3)
                            .copyWith(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 34),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 46, vertical: 18),
                          ),
                      onPressed: _start,
                      icon: const Icon(AppIcons.bolt),
                      label:  Text(context.l10n.startSprint),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.fluencySprint)),
      backgroundColor: pal(context).bg,
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(context.l10n.wordXofY(index + 1, sprintWords.length),
                    style:
                        uiStyle(context, size: 14, weight: FontWeight.w700)),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: pal(context).ink3, shape: BoxShape.circle),
                ),
                Text('${secs.toStringAsFixed(1)}s',
                    style: uiStyle(context, size: 14, weight: FontWeight.w600, color: coral)),
              ]),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: _next,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 640,
                  height: 380,
                  alignment: Alignment.center,
                  decoration: card,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: child)),
                    child: Text(sprintWords[index],
                        key: ValueKey(index),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 110)),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(context.l10n.tapCardAfterReadingWord,
                  style:
                      uiStyle(context, size: 15, color: pal(context).ink3)),
            ],
          ),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final running = index >= 0;
    final secs = running
        ? DateTime.now().difference(start).inMilliseconds / 1000
        : 0.0;
    if (useDesktop(context)) return _desktopBuild(context, running, secs);
    return Scaffold(
      appBar: AppBar(title:  Text(context.l10n.fluencySprint)),
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: useDesktop(context) ? 620 : double.infinity),
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(
            running
                ? context.l10n.wordXofYTime(
                        index + 1, sprintWords.length, secs.toStringAsFixed(1))
                : context.l10n.readEachWordAloudShort,
            style: uiStyle(context, size: 14.5, color: pal(context).ink3),
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: Center(
              child: !running
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: pal(context).acc,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 18)),
                      onPressed: _start,
                      icon: const Icon(AppIcons.bolt),
                      label:  Text(context.l10n.startSprint),
                    )
                  : GestureDetector(
                      onTap: _next,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 56),
                        decoration: BoxDecoration(
                          color: s.paperMode
                              ? pal(context).paper
                              : pal(context).card,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: a, child: child)),
                          child: s.focusWindow
                              ? Text(sprintWords[index],
                                  key: ValueKey(index),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: quranicStyle(context, size: 56))
                              : RichText(
                                  key: ValueKey(index),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  text: TextSpan(children: [
                                    for (var i = 0;
                                        i < sprintWords.length;
                                        i++)
                                      TextSpan(
                                        text: '${sprintWords[i]} ',
                                        style: quranicStyle(context, size: 28,
                                            color: i == index
                                                ? pal(context).acc
                                                : (s.paperMode
                                                        ? pal(context).paperInk
                                                        : pal(context).ink)
                                                    .withValues(alpha: .45)),
                                      ),
                                  ]),
                                ),
                        ),
                      ),
                    ),
            ),
          ),
          if (running)
            Text(context.l10n.tapCardAfterReadingWord,
                style: uiStyle(context, size: 13, color: pal(context).ink3)),
        ]),
          ),
        ),
      )),
    );
  }
}

Widget _doneDialog(BuildContext context, int stars, String message) =>
    AlertDialog(
      backgroundColor: pal(context).card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Center(child: StarRow(stars, size: 34)),
      content: Text(message,
          textAlign: TextAlign.center,
          style: uiStyle(context, size: 15, color: pal(context).ink3)),
      actions: [
        Center(
          child: FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child:  Text(context.l10n.continueLabel),
          ),
        ),
      ],
    );

/// Builds a review quiz from the spaced-repetition queue: the cards that are
/// due (or soonest, if none are due yet), re-asked with their original
/// distractors. A correct answer here promotes the card; a miss resets it.
QuizScreen mistakeReviewQuiz(BuildContext context, ProgressStore prog,
    {String? title, String? prompt, String progressId = 'coach.review'}) {
  final rng = math.Random();
  final session = prog.reviewSession(max: 12);
  final qs = <QuizQuestion>[];
  for (final it in session) {
    if (it.answer.trim().isEmpty) continue;
    final opts = <String>[it.answer, ...it.distractors];
    // Top up legacy/short cards to four plausible options.
    if (opts.length < 4) {
      final pool = it.optionsArabic
          ? prog.review.values.map((r) => r.answer)
          : letters.map((l) => letterName(context, l));
      for (final p in pool) {
        if (opts.length >= 4) break;
        if (p != it.answer && !opts.contains(p)) opts.add(p);
      }
    }
    final shuffled = [...opts]..shuffle(rng);
    qs.add(QuizQuestion(
      // The stored prompt is a legacy fallback written by the model, which
      // has no context; the localized one wins whenever we can resolve it.
      prompt: prompt ?? context.l10n.qpMissedBefore,
      arabic: it.arabic,
      reviewId: it.id,
      options: shuffled,
      correct: shuffled.indexOf(it.answer),
      optionsAreArabic: it.optionsArabic,
    ));
  }
  return QuizScreen(
      title: title ?? context.l10n.mistakeReview,
      progressId: progressId,
      questions: qs);
}
