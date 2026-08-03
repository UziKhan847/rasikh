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
import '../widgets/common.dart';

/// 👁 Reading Coach — built for readers who find similar shapes and dots
/// hard to tell apart. One-tap preset, fine-grained reading settings, and
/// three drills: Spot the Letter, Dot Detective, and the Fluency Sprint.
class DyslexiaScreen extends StatelessWidget {
  const DyslexiaScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Scaffold(
      appBar: embedded ? null : AppBar(title:  Text(context.l10n.readingCoach)),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                pal(context).accent.withValues(alpha: .18),
                AppColors.lilac.withValues(alpha: .14),
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.coachIntroBlurb,
                    style: uiStyle(context, size: 14, color: pal(context).textDim)),
                const SizedBox(height: 12),
                if (!s.dyslexiaMode)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: pal(context).accent,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      s.enableDyslexiaPreset();
                      ScaffoldMessenger.of(context).showSnackBar( SnackBar(
                          content: Text(
                              context.l10n.comfortPresetOn)));
                    },
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label:  Text(context.l10n.turnComfortPreset),
                  )
                else
                  Text(context.l10n.comfortPresetFineTuneBelow,
                      style: uiStyle(context, size: 13.5,
                          color: pal(context).accent, weight: FontWeight.w600)),
              ],
            ),
          ),
           SectionHeader(context.l10n.readingSetup,
              subtitle: context.l10n.appliesEverywhereApp),
          _SettingsPanel(),
           SectionHeader(context.l10n.sample, subtitle: context.l10n.yourSettingsLive),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: s.paperMode ? pal(context).paper : pal(context).surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: quranicStyle(context, size: 30)),
          ),
           SectionHeader(context.l10n.drills, subtitle: context.l10n.shortKindRepeatable),
          _drill(context, context.l10n.spotTheLetter, context.l10n.spotTheLetterSub,
              Icons.visibility_rounded, pal(context).accent, 'coach.spot',
              (_) => const SpotTheLetterDrill()),
          _drill(context, context.l10n.dotDetective, context.l10n.dotDetectiveSub,
              Icons.blur_on_rounded, AppColors.lilac, 'coach.dots',
              (_) => const DotDetectiveDrill()),
          _drill(context, context.l10n.fluencySprint, context.l10n.fluencySprintSub,
              Icons.bolt_rounded, pal(context).accent, 'coach.sprint',
              (_) => const FluencySprint()),
          if (ProgressScope.of(context).hasReviews)
            _drill(
                context,
                context.l10n.mistakeReview,
                _reviewSubtitle(context),
                Icons.refresh_rounded,
                AppColors.star,
                'coach.review',
                (c) => mistakeReviewQuiz(c, ProgressScope.of(context),
                    title: context.l10n.mistakeReview)),
        ],
      )),
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
      Color color, String progressId, WidgetBuilder builder) {
    final stars = ProgressScope.of(context).starsFor(progressId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TapScale(
        onTap: () =>
            pushAdaptive(context, builder(context)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal(context).surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: uiStyle(context,
                          size: 16, weight: FontWeight.w700)),
                  Text(sub,
                      style: uiStyle(context,
                          size: 13, color: pal(context).textDim)),
                ],
              ),
            ),
            StarRow(stars),
          ]),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    Widget slider(String label, double value, double min, double max,
            void Function(double) set) =>
        Row(children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: uiStyle(context, size: 13.5,
                      color: pal(context).textDim))),
          Expanded(
            child: Slider(
                value: value, min: min, max: max,
                onChanged: (v) => s.update(() => set(v))),
          ),
        ]);
    Widget toggle(String label, bool value, void Function(bool) set) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: uiStyle(context, size: 14.5)),
          value: value,
          onChanged: (v) => s.update(() => set(v)),
        );
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(context.l10n.language,
                    style: uiStyle(context,
                        size: 13.5, color: pal(context).textDim))),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (code, label) in L10n.supported)
                  ChoiceChip(
                    label: Text(label),
                    selected: s.language == code,
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    labelStyle: uiStyle(context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: s.language == code
                            ? Colors.white
                            : pal(context).text),
                    onSelected: (_) => s.update(() => s.language = code),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(context.l10n.tashkilTermsLabel,
                    style: uiStyle(context,
                        size: 13.5, color: pal(context).textDim))),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, value) in [
                  (context.l10n.arabicTerms, 'arabic'),
                  (context.l10n.indopak, 'indopak'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: s.tashkilTerms == value,
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    labelStyle: uiStyle(context,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: s.tashkilTerms == value
                            ? Colors.white
                            : pal(context).text),
                    onSelected: (_) => s.update(() => s.tashkilTerms = value),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(context.l10n.style,
                    style: uiStyle(context,
                        size: 13.5, color: pal(context).textDim))),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, value) in [
                  (context.l10n.themeFamilyMint, 'mint'),
                  (context.l10n.themeFamilyNoor, 'noor')
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: s.themeFamily == value,
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    labelStyle: uiStyle(context,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: s.themeFamily == value
                            ? Colors.white
                            : pal(context).text),
                    onSelected: (_) => s.update(() => s.themeFamily = value),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(children: [
            SizedBox(
                width: 110,
                child: Text(context.l10n.theme,
                    style: uiStyle(context,
                        size: 13.5, color: pal(context).textDim))),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, value) in const [
                  ('Light', 'light'),
                  ('Dark', 'dark'),
                  ('OLED', 'oled')
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: s.themeMode == value,
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    labelStyle: uiStyle(context,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: s.themeMode == value
                            ? Colors.white
                            : pal(context).text),
                    onSelected: (_) => s.update(() => s.themeMode = value),
                  ),
              ]),
            ),
          ]),
        ),
        slider(context.l10n.letterSize, s.arabicScale, 0.8, 1.8,
            (v) => s.arabicScale = v),
        slider(context.l10n.wordSpacing, s.wordSpacing, 0, 24, (v) => s.wordSpacing = v),
        slider(context.l10n.glyphSpacing, s.letterTracking, 0, 10,
            (v) => s.letterTracking = v),
        toggle(context.l10n.warmPaperBackground, s.paperMode, (v) => s.paperMode = v),
        toggle(context.l10n.colorCodedDots, s.dotEmphasis,
            (v) => s.dotEmphasis = v),
        toggle(context.l10n.focusWindow, s.focusWindow,
            (v) => s.focusWindow = v),
        toggle(context.l10n.hapticFeedback, s.haptics, (v) => s.haptics = v),
      ]),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    final family =
        similarFamilies.values.elementAt(rng.nextInt(similarFamilies.length));
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
        ProgressScope.of(context).report('coach.spot', stars);
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
    const coral = Color(0xFFE45F52);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final soft = dark ? const Color(0xFF2A1512) : const Color(0xFFFDF1EE);
    final dotInfo = dotsDesc(context, tl.dotCount, tl.dotPos);
    return Scaffold(
      backgroundColor: pal(context).bg,
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
                      color: pal(context).surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: pal(context)
                              .surfaceHigh
                              .withValues(alpha: .6)),
                      boxShadow: [
                        BoxShadow(
                            color: pal(context).shadow,
                            blurRadius: 24,
                            offset: const Offset(0, 6)),
                      ],
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
                                    color: pal(context).text)),
                            const SizedBox(height: 18),
                            Text(context.l10n.letterDash(letterName(context, tl), tl.translit),
                                style: uiStyle(context,
                                    size: 24, weight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const SizedBox.shrink(),
                            Text(dotInfo,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: coral)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.l10n.roundProgress,
                                style: uiStyle(context,
                                    size: 13, color: pal(context).textDim)),
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
                                const AlwaysStoppedAnimation(coral),
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
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: isWrong
                  ? AppColors.bad
                  : pal(context).surfaceHigh.withValues(alpha: .6),
              width: isWrong ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(children: [
          Center(
            child: Text(grid[i],
                style: quranicStyle(context,
                    size: 64, height: 1.85, color: pal(context).text)),
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
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
              style: uiStyle(context, size: 15, color: pal(context).textDim)),
          const SizedBox(height: 6),
          Text(context.l10n.letterDash(letterName(context, tl), tl.translit),
              style: uiStyle(context, size: 19, weight: FontWeight.w700)),
          if (s.dotEmphasis)
            Text(
                dotsDesc(context, tl.dotCount, tl.dotPos),
                style: uiStyle(context, size: 13.5, color: pal(context).accent)),
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
                      color: s.paperMode ? pal(context).paper : pal(context).surface,
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
                                      ? pal(context).accent
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

const _sprintWords = <String>[
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
    if (index + 1 >= _sprintWords.length) {
      ticker?.cancel();
      final d = DateTime.now().difference(start);
      final wpm = _sprintWords.length / (d.inMilliseconds / 60000);
      final stars = wpm >= 30 ? 3 : (wpm >= 18 ? 2 : 1);
      ProgressScope.of(context).report('coach.sprint', stars);
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
    const coral = Color(0xFFE45F52);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final softIcon = dark ? const Color(0xFF2A1512) : const Color(0xFFFDE9E4);
    final card = BoxDecoration(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(28),
      border:
          Border.all(color: pal(context).surfaceHigh.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
            color: pal(context).shadow,
            blurRadius: 30,
            offset: const Offset(0, 8)),
      ],
    );
    if (!running) {
      return Scaffold(
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
                      child: const Icon(Icons.bolt_rounded,
                          size: 36, color: coral),
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
                                size: 16, color: pal(context).textDim)
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
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      onPressed: _start,
                      icon: const Icon(Icons.bolt_rounded),
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
                Text(context.l10n.wordXofY(index + 1, _sprintWords.length),
                    style:
                        uiStyle(context, size: 14, weight: FontWeight.w700)),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: pal(context).textDim, shape: BoxShape.circle),
                ),
                Text('${secs.toStringAsFixed(1)}s',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: coral)),
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
                    child: Text(_sprintWords[index],
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
                      uiStyle(context, size: 15, color: pal(context).textDim)),
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
                        index + 1, _sprintWords.length, secs.toStringAsFixed(1))
                : context.l10n.readEachWordAloudShort,
            style: uiStyle(context, size: 14.5, color: pal(context).textDim),
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: Center(
              child: !running
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: pal(context).accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 18)),
                      onPressed: _start,
                      icon: const Icon(Icons.bolt_rounded),
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
                              : pal(context).surface,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: a, child: child)),
                          child: s.focusWindow
                              ? Text(_sprintWords[index],
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
                                        i < _sprintWords.length;
                                        i++)
                                      TextSpan(
                                        text: '${_sprintWords[i]} ',
                                        style: quranicStyle(context, size: 28,
                                            color: i == index
                                                ? pal(context).accent
                                                : (s.paperMode
                                                        ? pal(context).paperInk
                                                        : pal(context).text)
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
                style: uiStyle(context, size: 13, color: pal(context).textDim)),
        ]),
          ),
        ),
      )),
    );
  }
}

Widget _doneDialog(BuildContext context, int stars, String message) =>
    AlertDialog(
      backgroundColor: pal(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Center(child: StarRow(stars, size: 34)),
      content: Text(message,
          textAlign: TextAlign.center,
          style: uiStyle(context, size: 15, color: pal(context).textDim)),
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
    {String? title, String? prompt}) {
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
      progressId: 'coach.review',
      questions: qs);
}
