import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/extra_letters.dart';
import '../data/glyph_names.dart';
import '../data/letters.dart';
import '../data/muqattaat.dart';
import '../data/quran.dart' show stripTashkil;
import '../data/small_letters.dart';
import '../data/tajweed.dart';
import '../data/tanwin_allographs.dart';
import '../data/tashkeel.dart';
import '../data/variants.dart';
import '../data/wasl.dart';
import '../widgets/common.dart';
import 'tashkeel_screen.dart';

/// 📖 The Qaidah Path — the full beginner journey, in the order a
/// classical Qaidah teaches it. Every unit opens onto a Learn → Test →
/// Practice hub; nothing is locked, and Test alone awards stars.
class QaidahScreen extends StatelessWidget {
  const QaidahScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final units = qaidahUnits(context);
    return Scaffold(
      appBar: embedded ? null : AppBar(title:  Text(context.l10n.qaidahPath)),
      body: SafeArea(
        top: false,
        child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: units.length,
        itemBuilder: (context, i) {
          final u = units[i];
          final stars = progress.starsFor(u.progressId);
          return FadeSlideIn(
            delayMs: 50 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TapScale(
                onTap: () => pushAdaptive(context, QaidahUnitHub(unit: u)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: stars > 0
                            ? pal(context).accent.withValues(alpha: .45)
                            : pal(context).surfaceHigh),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal(context).surfaceHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(u.arabicBadge,
                          style: quranicStyle(context, size: 24, height: 1.3,
                              color: pal(context).accent)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.unitTitle(i + 1, u.title),
                              style: uiStyle(context,
                                  size: 16.5, weight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(u.subtitle,
                              style: uiStyle(context,
                                  size: 13, color: pal(context).textDim)),
                        ],
                      ),
                    ),
                    StarRow(stars),
                  ]),
                ),
              ),
            ),
          );
        },
      )),
    );
  }


}

/// A unit of the Qaidah path. Every unit has three phases — Learn, Test,
/// Practice — none of them locked; Test alone reports stars under
/// [progressId], Practice feeds the spaced-repetition queue without ever
/// awarding stars, and Learn is always a real lesson surface, never a bare
/// stub.
class QaidahUnit {
  final String title;
  final String subtitle;
  final String arabicBadge;
  final String progressId;
  final List<UnitPhase> phases;
  QaidahUnit(this.title, this.subtitle, this.arabicBadge, this.progressId,
      {required this.phases});
}

/// The eleven units of the Qaidah path — shared by mobile and desktop.
List<QaidahUnit> qaidahUnits(BuildContext context) => [
      QaidahUnit(context.l10n.unitLetters, context.l10n.unitLettersSub, 'ا ب',
          'qaidah.letters',
          phases: standardPhases(context,
              learn: (_) => const LettersExplorer(),
              test: (c) => _letterQuiz(c),
              practice: (c) => _letterPracticeQuiz(c))),
      QaidahUnit(context.l10n.unitJoiningForms, context.l10n.unitJoiningFormsSub,
          'ـبـ', 'qaidah.forms',
          phases: standardPhases(context,
              learn: (_) => const FormsLab(),
              test: (c) => _formsQuiz(c),
              practice: (c) => _formsPracticeQuiz(c))),
      QaidahUnit(context.l10n.unitHarakat, context.l10n.unitHarakatSub, 'بَ',
          'qaidah.harakat',
          phases: standardPhases(context,
              learn: (c) => _harakatLearn(c),
              test: (c) => _syllableQuiz(
                  c, context.l10n.harakatDrill, 'qaidah.harakat', harakat),
              practice: (c) => _harakatPracticeQuiz(c))),
      QaidahUnit(context.l10n.unitTanwin, context.l10n.unitTanwinSub, 'بً',
          'qaidah.tanwin',
          phases: standardPhases(context,
              learn: (c) => _tanwinLearn(c),
              test: (c) => _syllableQuiz(
                  c, context.l10n.tanwinDrill, 'qaidah.tanwin', tanwin),
              practice: (c) => _tanwinPracticeQuiz(c))),
      QaidahUnit(
          tashkilName(context, tashkil.firstWhere((t) => t.id == 'sukun')),
          context.l10n.unitSukunSub, 'بۡ', 'qaidah.sukun',
          phases: standardPhases(context,
              learn: (c) => _sukunLearn(c),
              test: (c) => _sukunQuiz(c),
              practice: (c) => _sukunQuiz(c, graded: false))),
      QaidahUnit(context.l10n.shaddah, context.l10n.unitShaddahSub, 'بّ',
          'qaidah.shadda',
          phases: standardPhases(context,
              learn: (c) => _shaddaLearn(c),
              test: (c) => _shaddaQuiz(c),
              practice: (c) => _shaddaQuiz(c, graded: false))),
      QaidahUnit(context.l10n.unitMaddLin, context.l10n.unitMaddLinSub, 'بَا',
          'qaidah.madd',
          phases: standardPhases(context,
              learn: (_) => const TashkeelScreen(focusCounts: true),
              test: (c) => maddLinQuizScreen(c),
              practice: (c) => maddLinQuizScreen(c, graded: false))),
      QaidahUnit(context.l10n.readingWords, context.l10n.unitReadingWordsSub,
          'قُلۡ', 'qaidah.words',
          phases: standardPhases(context,
              learn: (c) => _wordsLearn(c),
              test: (c) => _wordQuiz(c),
              practice: (c) => _wordsPracticeQuiz(c))),
      QaidahUnit(context.l10n.unitWasl, context.l10n.unitWaslSub, 'ٱ',
          'qaidah.wasl',
          phases: standardPhases(context,
              learn: (c) => _waslLearn(c),
              test: (c) => _waslQuiz(c),
              practice: (c) => _waslQuiz(c, graded: false))),
      QaidahUnit(context.l10n.unitMuqattaat, context.l10n.unitMuqattaatSub,
          'الٓمٓ', 'qaidah.muqattaat',
          phases: standardPhases(context,
              learn: (c) => _muqattaatLearn(c),
              test: (c) => _muqattaatTest(c),
              practice: (c) => _muqattaatTest(c, graded: false))),
      QaidahUnit(context.l10n.qaidahReview, context.l10n.unitReviewSub, '۝',
          'qaidah.review',
          phases: standardPhases(context,
              learn: (c) => _reviewLearn(c),
              test: (c) => _reviewQuiz(c),
              practice: (c) => _reviewQuiz(c, graded: false))),
    ];

/// The Learn → Test → Practice hub for one unit — pushed when its card is
/// tapped from the path list. All three phases are always reachable.
class QaidahUnitHub extends StatelessWidget {
  final QaidahUnit unit;
  const QaidahUnitHub({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(unit.title)),
      body: SafeArea(
        top: false,
        child: PhaseHub(
          subtitle: unit.subtitle,
          phases: unit.phases,
          onPick: (i) =>
              pushAdaptive(context, Builder(builder: unit.phases[i].builder!)),
        ),
      ),
    );
  }
}

// ─────────────────────────── Unit 1: Letters ───────────────────────────

class LettersExplorer extends StatelessWidget {
  /// Desktop: the reference "Letters grid" — auto-fill tiles with a big glyph
  /// and the name beneath, plus a Letter Quiz CTA.
  Widget _desktopBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: pal(context).bg,
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 166, mainAxisSpacing: 16, crossAxisSpacing: 16),
            itemCount: letters.length,
            itemBuilder: (context, i) {
              final l = letters[i];
              return Material(
                color: pal(context).surface,
                borderRadius: BorderRadius.circular(22),
                elevation: 4,
                shadowColor: pal(context).shadow,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => pushAdaptive(context, LetterDetail(letter: l)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color:
                              pal(context).surfaceHigh.withValues(alpha: .6)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.char,
                            style: quranicStyle(context,
                                size: 52, color: pal(context).text)),
                        const SizedBox(height: 14),
                        Text(letterName(context, l),
                            style: uiStyle(context,
                                size: 13,
                                weight: FontWeight.w600,
                                color: pal(context).textDim)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          _deskSection(context, context.l10n.extraLettersTitle,
              sub: context.l10n.extraLettersSub),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140, mainAxisSpacing: 14, crossAxisSpacing: 14),
            itemCount: extraLetters.length,
            itemBuilder: (context, i) {
              final l = extraLetters[i];
              return Material(
                color: pal(context).surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => pushAdaptive(context, LetterDetail(letter: l)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: pal(context).surfaceHigh.withValues(alpha: .6)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.char, style: quranicStyle(context, size: 36)),
                        const SizedBox(height: 8),
                        Text(letterName(context, l),
                            style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _deskSection(context, context.l10n.smallLettersTitle,
              sub: context.l10n.smallLettersSub),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final s in smallLetters)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: _deskCard(context),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.mark,
                        style: quranicStyle(context, size: 30, color: pal(context).accent)),
                    const SizedBox(height: 6),
                    Text(s.name, style: uiStyle(context, size: 12.5)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 26),
          _deskCta(context, context.l10n.letterQuizTitle,
              () => pushAdaptive(context, _letterQuiz(context))),
        ],
      )),
    );
  }

  const LettersExplorer({super.key});

  Widget _smallGrid(BuildContext context, List<ArabicLetter> items,
          void Function(ArabicLetter) onTap) =>
      GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final l = items[i];
          return TapScale(
            onTap: () => onTap(l),
            child: Container(
              decoration: BoxDecoration(
                color: pal(context).surface,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(l.char, style: quranicStyle(context, size: 34)),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    return Scaffold(
      appBar: AppBar(title:  Text(context.l10n.theLetters)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          children: [
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12),
              itemCount: letters.length,
              itemBuilder: (context, i) {
                final l = letters[i];
                return FadeSlideIn(
                  delayMs: 22 * i,
                  child: TapScale(
                    onTap: () {
                      ProgressScope.of(context).report('letter.${l.char}', 1);
                      pushAdaptive(context, LetterDetail(letter: l));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal(context).surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.char, style: quranicStyle(context, size: 34)),
                    ),
                  ),
                );
              },
            ),
            SectionHeader(context.l10n.extraLettersTitle,
                subtitle: context.l10n.extraLettersSub),
            _smallGrid(context, extraLetters,
                (l) => pushAdaptive(context, LetterDetail(letter: l))),
            SectionHeader(context.l10n.smallLettersTitle,
                subtitle: context.l10n.smallLettersSub),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in smallLetters)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: pal(context).surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal(context).surfaceHigh),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.mark,
                          style: quranicStyle(context, size: 26, color: pal(context).accent)),
                      const SizedBox(height: 4),
                      Text(s.name, style: uiStyle(context, size: 11.5)),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: pal(context).accent,
        foregroundColor: Colors.white,
        onPressed: () => pushAdaptive(context, _letterQuiz(context)),
        icon: const Icon(Icons.quiz_rounded),
        label:  Text(context.l10n.letterQuiz),
      ),
    );
  }
}

class LetterDetail extends StatelessWidget with DesktopAware {
  final ArabicLetter letter;
  final String mode; // 'letters' | 'joining'
  const LetterDetail({super.key, required this.letter, this.mode = 'letters'});

  /// Desktop: the reference "Letter detail" — ONLY the big letter card on the
  /// left and the "Easily confused with" family on the right.
  Widget _desktopBuild(BuildContext context) {
    final dotInfo = dotsDescForLetter(context, letter);
    final fam = letter.similarGroup == null
        ? <ArabicLetter>[letter]
        : [
            for (final ch in similarFamilies[letter.similarGroup]!)
              letters.firstWhere((l) => l.char == ch)
          ];
    return Scaffold(
      backgroundColor: pal(context).bg,
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(34, 4, 30, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      border: Border.all(color: pal(context).surfaceHigh),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: pal(context).text),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(letterName(context, letter),
              style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── the letter ──
                Expanded(
                  flex: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 48, horizontal: 40),
                    decoration: _deskCard(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(letter.char,
                            style: quranicStyle(context,
                                size: 200,
                                height: 1.85,
                                color: pal(context).accent)),
                        const SizedBox(height: 34),
                        Text(letterName(context, letter),
                            style: uiStyle(context,
                                size: 34, weight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('“${letter.translit}”',
                              style: uiStyle(context,
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: pal(context).accent)),
                          Container(
                            width: 4,
                            height: 4,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: pal(context).textDim,
                                shape: BoxShape.circle),
                          ),
                          Text(dotInfo,
                              style: uiStyle(context,
                                  size: 15, color: pal(context).textDim)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                // ── easily confused with ──
                Expanded(
                  flex: 14,
                  child: Container(
                    padding: const EdgeInsets.all(36),
                    decoration: _deskCard(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _deskSection(context, context.l10n.easilyConfusedWith),
                        Padding(
                          padding: const EdgeInsets.only(left: 17, bottom: 22),
                          child: Text(
                              fam.length > 1
                                  ? context.l10n.sameSkeletonDotsDecideDot
                                  : context.l10n.noLookAlikes,
                              style: uiStyle(context,
                                  size: 14, color: pal(context).textDim)),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < fam.length; i++) ...[
                                if (i > 0) const SizedBox(width: 14),
                                Expanded(
                                    child: _confusedTile(
                                        context, fam[i],
                                        target: fam[i].char == letter.char)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        ],
      )),
    );
  }

  Widget _confusedTile(BuildContext context, ArabicLetter l,
      {required bool target}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 10),
      decoration: BoxDecoration(
        color: target
            ? pal(context).accent.withValues(alpha: .10)
            : pal(context).bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: target
                ? pal(context).accent.withValues(alpha: .55)
                : Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.char,
              style: quranicStyle(context,
                  size: 70,
                  height: 1.85,
                  color: target ? pal(context).accent : pal(context).text)),
          const SizedBox(height: 22),
          Text(letterName(context, l),
              style: uiStyle(context, size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(dotsDesc(context, l.dotCount, l.dotPos),
              textAlign: TextAlign.center,
              style:
                  uiStyle(context, size: 12, color: pal(context).textDim)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final s = SettingsScope.of(context);
    final dotInfo = dotsDescForLetter(context, letter);
    return Scaffold(
      appBar: AppBar(title: Text(letterName(context, letter))),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              // elasticOut overshoots past 1.0 by design; Transform.scale
              // doesn't affect layout, so an un-clamped overshoot would
              // paint the glyph larger than the box it was just sized for.
              builder: (context, v, child) =>
                  Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
              child: Text(letter.char,
                  style: quranicStyle(context,
                      size: 120, height: 1.85, color: pal(context).accent)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('“${letter.translit}” · $dotInfo',
                style: uiStyle(context, size: 15, color: pal(context).textDim)),
          ),
          if (letter.similarGroup != null) ...[
             SectionHeader(context.l10n.easilyConfusedWith,
                subtitle: context.l10n.sameSkeletonDotsDecide),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: pal(context).surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                textDirection: TextDirection.rtl,
                children: [
                  for (final c in similarFamilies[letter.similarGroup]!)
                    Text(c,
                        style: quranicStyle(context, size: 38,
                            color: c == letter.char
                                ? pal(context).accent
                                : (s.paperMode
                                    ? pal(context).paperInk
                                    : pal(context).text))),
                ],
              ),
            ),
          ],
        ],
      )),
    );
  }

}

/// Desktop letter/joining detail — two-column: hero + actions on the left,
/// content cards on the right. Content differs by [mode].
class FormsLab extends StatefulWidget {
  const FormsLab({super.key});

  @override
  State<FormsLab> createState() => _FormsLabState();
}

class _FormsLabState extends State<FormsLab> {
  ArabicLetter sel = letters[1];

  /// Desktop: the reference "Joining forms" — letter strip, the four Shapes,
  /// "In the Qur'an", and "See it in Words", plus the Forms Quiz CTA.
  Widget _desktopBuild(BuildContext context) {
    final joins = sel.joins;
    final shapes = joins
        ? <(String, String)>[
            (sel.finalForm, context.l10n.formEnd),
            (sel.medial, context.l10n.formMiddle),
            (sel.initial, context.l10n.formStart),
            (sel.char, context.l10n.formAlone),
          ]
        : <(String, String)>[
            (sel.finalForm, context.l10n.formJoined),
            (sel.char, context.l10n.formAlone),
          ];
    final words = letterExamples[sel.char] ?? const <LetterExample>[];
    return Scaffold(
      backgroundColor: pal(context).bg,
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
        children: [
          // ── letter strip ──
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final l in letters)
                TapScale(
                  onTap: () => setState(() => sel = l),
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: l.char == sel.char
                          ? pal(context).accent
                          : pal(context).surface,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: l.char == sel.char
                              ? pal(context).accent
                              : pal(context).surfaceHigh.withValues(alpha: .7)),
                    ),
                    child: Text(l.char,
                        style: quranicStyle(context,
                            size: 26,
                            color: l.char == sel.char
                                ? Colors.white
                                : pal(context).text)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _deskSection(context, context.l10n.shapes,
              sub: joins
                  ? context.l10n.shapesSubJoin
                  : context.l10n.shapesSubNonJoin),
          Row(children: [
            for (var i = 0; i < shapes.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 38, 20, 24),
                  decoration: _deskCard(context),
                  child: Column(children: [
                    Text(shapes[i].$1,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context,
                            size: 74, height: 1.85, color: pal(context).text)),
                    const SizedBox(height: 20),
                    Text(shapes[i].$2,
                        style: uiStyle(context,
                            size: 13,
                            weight: FontWeight.w600,
                            color: pal(context).textDim)),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 34),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _deskSection(context, context.l10n.inTheQuran),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 42, horizontal: 30),
                          decoration: _deskCard(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(sel.exampleWord,
                                  textDirection: TextDirection.rtl,
                                  style: quranicStyle(context,
                                      size: 76,
                                      height: 1.85,
                                      color: pal(context).text)),
                              const SizedBox(height: 22),
                              Text(context.l10n.surahRef(sel.exampleRef),
                                  style: uiStyle(context,
                                      size: 13,
                                      color: pal(context).textDim)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _deskSection(context, context.l10n.seeItInWords,
                          sub: context.l10n.seeItInWordsSub),
                      Expanded(
                        child: words.isEmpty
                            ? Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                decoration: _deskCard(context),
                                child: Text(context.l10n.wordExamplesComingThisLetter,
                                    style: uiStyle(context,
                                        size: 13.5,
                                        color: pal(context).textDim)),
                              )
                            : Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < words.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 16),
                                    Expanded(
                                        child: _wordCard(context, words[i])),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _deskCta(context, context.l10n.formsQuiz,
              () => pushAdaptive(context, _formsQuiz(context))),
        ],
      )),
    );
  }

  Widget _wordCard(BuildContext context, LetterExample w) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      decoration: _deskCard(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: pal(context).accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_posLabel(context, w.position),
                style: uiStyle(context,
                    size: 11.5,
                    weight: FontWeight.w800,
                    color: pal(context).accent)),
          ),
          Text(w.word,
              textDirection: TextDirection.rtl,
              style: quranicStyle(context,
                  size: 56, height: 1.85, color: pal(context).text)),
          Text(w.translit,
              style: uiStyle(context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: pal(context).textDim)),
        ],
      ),
    );
  }

  /// Forms laid out right-to-left (alone on the right), wrapping wide letters
  /// like ṣād into a 2×2 grid while narrow letters stay on one row.
  /// 'beginning' | 'middle' | 'end' → the reader's language.
  String _posLabel(BuildContext context, String p) => switch (p) {
        'beginning' => context.l10n.posBeginning,
        'middle' => context.l10n.posMiddle,
        _ => context.l10n.posEnd,
      };

  Widget _formsGrid(BuildContext context, ArabicLetter l) {
    final joins = l.joins;
    final forms = joins
        ? <(String, String)>[
            (l.char, context.l10n.formAlone),
            (l.initial, context.l10n.formStart),
            (l.medial, context.l10n.formMiddle),
            (l.finalForm, context.l10n.formEnd),
          ]
        : <(String, String)>[
            (l.char, context.l10n.formAlone),
            (l.finalForm, context.l10n.formJoined),
          ];

    return LayoutBuilder(builder: (context, c) {
      final glyphStyle = quranicStyle(context, size: 46);
      const hpad = 14.0, spacing = 10.0;
      final maxW = c.maxWidth;

      double measure(String t) {
        final tp = TextPainter(
          text: TextSpan(text: t, style: glyphStyle),
          textDirection: TextDirection.rtl,
        )..layout();
        return tp.width + hpad * 2;
      }

      final widths = [for (final f in forms) measure(f.$1)];
      final oneRowWidth =
          widths.fold(0.0, (a, b) => a + b) + spacing * (forms.length - 1);
      final oneRow = oneRowWidth <= maxW;
      final cellW = oneRow ? null : (maxW - spacing) / 2; // 2-col grid

      Widget cell((String, String) f) => Container(
            width: cellW,
            constraints: cellW == null
                ? const BoxConstraints(minWidth: 70)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: hpad, vertical: 10),
            decoration: BoxDecoration(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pal(context).surfaceHigh),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 56,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(f.$1,
                      textDirection: TextDirection.rtl, style: glyphStyle),
                ),
              ),
              const SizedBox(height: 4),
              Text(f.$2,
                  style: uiStyle(context,
                      size: 11.5, color: pal(context).textDim)),
            ]),
          );

      // Always lay out right-to-left: "Alone" sits on the right.
      return Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final f in forms) cell(f)],
      );
    });
  }

  /// Small section heading for the phone lab — mirrors the desktop's
  /// _deskSection so both layouts label the same material the same way.
  Widget _mobSection(BuildContext context, String title, String? sub) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: pal(context).accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: uiStyle(context, size: 14.5, weight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 11, color: pal(context).textDim)),
            ),
          ],
        ]),
      );

  /// The letter inside a real word, tagged with where it sits.
  Widget _mobWordCard(BuildContext context, LetterExample w) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal(context).surfaceHigh),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pal(context).accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(_posLabel(context, w.position),
                style: uiStyle(context,
                    size: 10.5,
                    weight: FontWeight.w800,
                    color: pal(context).accent)),
          ),
          const Spacer(),
          Text(w.translit,
              style: uiStyle(context,
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: pal(context).textDim)),
          const SizedBox(width: 12),
          Text(w.word,
              textDirection: TextDirection.rtl,
              style: quranicStyle(context, size: 30)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final joins = sel.joins;
    final words = letterExamples[sel.char] ?? const <LetterExample>[];
    return Scaffold(
      appBar: AppBar(title:  Text(context.l10n.joiningForms)),
      body: SafeArea(
        top: false,
        child: Column(children: [
        // Same material as the desktop lab — shapes, the Qur'anic example with
        // its reference, and the letter seen at the beginning/middle/end of
        // real words — just stacked and scrollable for a phone.
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: ListView(
              key: ValueKey(sel.char),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                _mobSection(context, context.l10n.shapes,
                    joins
                        ? context.l10n.shapesSubJoin
                        : context.l10n.shapesSubNonJoin),
                _formsGrid(context, sel),
                const SizedBox(height: 18),
                _mobSection(context, context.l10n.inTheQuran, null),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pal(context).surfaceHigh),
                  ),
                  child: Column(children: [
                    Text(context.l10n.letterInAWord(letterName(context, sel)),
                        style: uiStyle(context,
                            size: 13, color: pal(context).textDim)),
                    const SizedBox(height: 6),
                    Text(sel.exampleWord,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context,
                            size: 40, color: pal(context).accent)),
                    const SizedBox(height: 6),
                    Text(context.l10n.surahRef(sel.exampleRef),
                        style: uiStyle(context,
                            size: 12, color: pal(context).textDim)),
                  ]),
                ),
                const SizedBox(height: 18),
                _mobSection(context, context.l10n.seeItInWords,
                    context.l10n.seeItInWordsSub),
                if (words.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal(context).surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: pal(context).surfaceHigh),
                    ),
                    child: Text(context.l10n.wordExamplesComingThisLetter,
                        textAlign: TextAlign.center,
                        style: uiStyle(context,
                            size: 12.5, color: pal(context).textDim)),
                  )
                else
                  for (final w in words) ...[
                    _mobWordCard(context, w),
                    if (w != words.last) const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: letters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => TapScale(
              onTap: () => setState(() => sel = letters[i]),
              child: Container(
                width: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel == letters[i]
                      ? pal(context).surfaceHigh
                      : pal(context).surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel == letters[i]
                          ? pal(context).accent
                          : Colors.transparent),
                ),
                child: Text(letters[i].char,
                    style: quranicStyle(context, size: 26)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: pal(context).accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => pushAdaptive(context, _formsQuiz(context)),
              icon: const Icon(Icons.quiz_rounded),
              label:  Text(context.l10n.formsQuiz),
            ),
          ),
        ),
      ])),
    );
  }
}

// ─────────────────────────── Generated drills ───────────────────────────

final _rng = math.Random();

QuizScreen letterQuizScreen(BuildContext context) => _letterQuiz(context);

QuizScreen _letterQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[];
  final pool = letters.map((l) => letterName(context, l)).toList();
  final sample = [...letters]..shuffle(_rng);
  for (final l in sample.take(10)) {
    final o = buildOptions(letterName(context, l), pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpWhichLetterIsThis,
        arabic: l.char,
        reviewId: 'letter.${l.char}',
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(
      title: context.l10n.letterQuiz,
      progressId: 'qaidah.letters',
      questions: qs,
      graded: graded);
}

QuizScreen _formsQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[];
  final pool = letters.map((l) => letterName(context, l)).toList();
  // Non-joiners (ا و د ذ ر ز) have no real initial/medial form — asking about
  // one would show a stray tatweel run, not a shape that exists in the muṣḥaf.
  final sample = letters.where((l) => l.joins).toList()..shuffle(_rng);
  for (final l in sample.take(10)) {
    final formIdx = _rng.nextInt(3);
    final form = [l.initial, l.medial, l.finalForm][formIdx];
    final formName = ['ini', 'med', 'fin'][formIdx];
    final o = buildOptions(letterName(context, l), pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpShapeBelongsTo,
        arabic: form,
        reviewId: 'letter.form.${l.char}.$formName',
        options: o.options,
        correct: o.correct,
        explain: context.l10n.lookPastJoins));
  }
  return QuizScreen(
      title: context.l10n.formsQuiz,
      progressId: 'qaidah.forms',
      questions: qs,
      graded: graded);
}

QuizScreen _syllableQuiz(BuildContext context, String title, String progressId,
    List<(String, String, String)> marks,
    {bool graded = true}) {
  final qs = <QuizQuestion>[];
  final sample = letters.where((l) => l.char != 'ا').toList()..shuffle(_rng);
  for (final l in sample.take(10)) {
    final (mark, _, sound) = marks[_rng.nextInt(marks.length)];
    final answer = '${l.translit}$sound';
    final pool = [
      for (final m in marks) '${l.translit}${m.$3}',
      for (final m in marks)
        '${sample[(sample.indexOf(l) + 1) % sample.length].translit}${m.$3}',
    ];
    final o = buildOptions(answer, pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpHowDoesThisSound,
        arabic: '${l.char}$mark',
        reviewId: '$progressId.${l.char}.${mark.codeUnitAt(0)}',
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(
      title: title, progressId: progressId, questions: qs, graded: graded);
}

QuizScreen _sukunQuiz(BuildContext context, {bool graded = true}) {
  final o1 = buildOptions(context.l10n.optCutsNoVowel, [
    context.l10n.optCutsNoVowel,
    context.l10n.optStretchesTwo,
    context.l10n.optDoublesIt,
    context.l10n.optSilentEntirely,
  ], _rng);
  final o2 = buildOptions('ab', ['ab', 'aba', 'ba', 'ib'], _rng);
  final o3 = buildOptions('qul', ['qul', 'qal', 'qil', 'qulu'], _rng);
  final o4 = buildOptions(
      'ق ط ب ج د', ['ق ط ب ج د', 'ا و ي', 'ء ه ع ح', 'ل ر ن م'], _rng);
  final o5 = buildOptions('lam yalid',
      ['lam yalid', 'lam yalida', 'lama yalid', 'lim yalud'], _rng);
  final qs = <QuizQuestion>[
    QuizQuestion(
        prompt: context.l10n.qpWhatDoesSukunDo,
        options: o1.options,
        correct: o1.correct),
    QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'أَبۡ',
        reviewId: 'qaidah.sukun.ab',
        options: o2.options,
        correct: o2.correct),
    QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'قُلۡ',
        reviewId: 'qaidah.sukun.qul',
        options: o3.options,
        correct: o3.correct),
    QuizQuestion(
        prompt: context.l10n.qpWhichBounce,
        options: o4.options,
        correct: o4.correct,
        explain: context.l10n.rememberQutbuJadd),
    QuizQuestion(
        prompt: context.l10n.qpReadItBounce,
        arabic: 'لَمۡ يَلِدۡ',
        reviewId: 'qaidah.sukun.lamyalid',
        options: o5.options,
        correct: o5.correct),
  ];
  return QuizScreen(
      title: tashkilName(context, tashkil.firstWhere((t) => t.id == 'sukun')),
      progressId: 'qaidah.sukun',
      questions: qs,
      graded: graded);
}

QuizScreen _shaddaQuiz(BuildContext context, {bool graded = true}) {
  final o1 = buildOptions(context.l10n.optTwiceCutVoweled, [
    context.l10n.optTwiceCutVoweled,
    context.l10n.optSilently,
    context.l10n.optWithLongStretch,
    context.l10n.optFromTheNose,
  ], _rng);
  final o2 = buildOptions('rabbi', ['rabbi', 'rabi', 'rab', 'raabi'], _rng);
  final o3 = buildOptions('inna', ['inna', 'ina', 'anna', 'in'], _rng);
  final o4 = buildOptions('thumma', ['thumma', 'thuma', 'summa', 'thum'], _rng);
  final qs = <QuizQuestion>[
    QuizQuestion(
        prompt: context.l10n.qpShaddahMeans,
        options: o1.options,
        correct: o1.correct),
    QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'رَبِّ',
        reviewId: 'qaidah.shadda.rabbi',
        options: o2.options,
        correct: o2.correct),
    QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'إِنَّ',
        reviewId: 'qaidah.shadda.inna',
        options: o3.options,
        correct: o3.correct,
        explain: context.l10n.explNunShaddahGhunnah),
    QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'ثُمَّ',
        reviewId: 'qaidah.shadda.thumma',
        options: o4.options,
        correct: o4.correct),
  ];
  return QuizScreen(
      title: context.l10n.shaddah,
      progressId: 'qaidah.shadda',
      questions: qs,
      graded: graded);
}

const _quranWords = <(String, String)>[
  ('بِسۡمِ', 'bismi'),
  ('قُلۡ', 'qul'),
  ('هُوَ', 'huwa'),
  ('أَحَدٌ', 'aḥadun'),
  ('خَلَقَ', 'khalaqa'),
  ('نَعۡبُدُ', 'naʿbudu'),
  ('يَوۡمِ', 'yawmi'),
  ('رَبِّ', 'rabbi'),
  ('جَآءَ', 'jā’a'),
  ('لَهَبٖ', 'lahabin'),
  ('مَٰلِكِ', 'māliki'),
  ('دِينِ', 'dīni'),
  ('ثُمَّ', 'thumma'),
  ('سَلَٰمٌ', 'salāmun'),
  ('نَصۡرُ', 'naṣru'),
  ('غَيۡرِ', 'ghayri'),
];

QuizScreen _wordQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[];
  final pool = _quranWords.map((w) => w.$2).toList();
  final sample = [..._quranWords]..shuffle(_rng);
  for (final (ar, tr) in sample.take(10)) {
    final o = buildOptions(tr, pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpReadQuranicWord,
        arabic: ar,
        reviewId: 'qaidah.word.$tr',
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(
      title: context.l10n.readingWords,
      progressId: 'qaidah.words',
      questions: qs,
      graded: graded);
}

QuizScreen _reviewQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[];
  // letters
  final ls = [...letters]..shuffle(_rng);
  for (final l in ls.take(3)) {
    final o = buildOptions(letterName(context, l),
        letters.map((x) => letterName(context, x)).toList(), _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpNameTheLetter,
        arabic: l.char,
        reviewId: 'letter.${l.char}',
        options: o.options,
        correct: o.correct));
  }
  // tashkil meanings
  final ts = [...tashkil]..shuffle(_rng);
  for (final t in ts.take(4)) {
    final o = buildOptions(tashkilName(context, t),
        tashkil.map((x) => tashkilName(context, x)).toList(), _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpWhichMarkHighlighted,
        arabic: t.example,
        highlight: t.highlight,
        reviewId: 'tashkil.${t.id}',
        options: o.options,
        correct: o.correct,
        explain: tashkilNote(context, t)));
  }
  // words
  final ws = [..._quranWords]..shuffle(_rng);
  for (final (ar, tr) in ws.take(3)) {
    final o = buildOptions(tr, _quranWords.map((w) => w.$2).toList(), _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpReadIt, arabic: ar, reviewId: 'qaidah.word.$tr',
        options: o.options, correct: o.correct));
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.qaidahReview,
      progressId: 'qaidah.review',
      questions: qs,
      graded: graded);
}

// ───────────────── shared: spell a word into named letters ────────────────

/// Builds an ordering question: decompose [word] into its base letters (no
/// ḥarakāt, via the same [stripTashkil] used for "clear letters" mode
/// elsewhere) and ask the learner to tap their NAMES in order — forward
/// (spell it out) or backward (a reading-direction drill). Options are
/// letter names via [letterForAny], so a hamza in the word is correctly
/// named rather than skipped. Returns null for anything [letterForAny] can't
/// resolve (only single Qurʼanic words are used, so this shouldn't happen in
/// practice) or that is too short to make a meaningful drill.
QuizQuestion? _spellQuestion(BuildContext context, String word,
    {required bool reverse}) {
  final baseChars = stripTashkil(word).split('');
  final names = <String>[];
  for (final ch in baseChars) {
    final l = letterForAny(ch);
    if (l == null) return null;
    names.add(letterName(context, l));
  }
  if (names.length < 3) return null;
  final sequence = reverse ? names.reversed.toList() : names;
  final displayOptions = [...names]..shuffle(_rng);
  return QuizQuestion(
    prompt: reverse ? context.l10n.qpSpellBackward : context.l10n.qpSpellForward,
    arabic: word,
    reviewId: 'qaidah.spell.$word.${reverse ? 'rev' : 'fwd'}',
    options: displayOptions,
    sequence: sequence,
  );
}

// ───────────────────────── Unit 1 practice: Letters ────────────────────────

QuizQuestion _dotCountQuestion(BuildContext context) {
  final n = [0, 1, 2, 3][_rng.nextInt(4)];
  final sample = ([...letters]..shuffle(_rng)).take(8).toList();
  if (!sample.any((l) => l.dotCount == n)) {
    sample[0] = letters.firstWhere((l) => l.dotCount == n);
  }
  final options = sample.map((l) => l.char).toList();
  final correctSet = <int>{
    for (var i = 0; i < sample.length; i++)
      if (sample[i].dotCount == n) i,
  };
  return QuizQuestion(
    prompt: context.l10n.qpChooseDotsCount(n),
    options: options,
    optionsAreArabic: true,
    correctSet: correctSet,
  );
}

QuizQuestion _dotPosQuestion(BuildContext context) {
  const positions = ['above', 'below', 'inside'];
  final pos = positions[_rng.nextInt(positions.length)];
  final sample = ([...letters]..shuffle(_rng)).take(8).toList();
  if (!sample.any((l) => l.dotPos == pos)) {
    sample[0] = letters.firstWhere((l) => l.dotPos == pos);
  }
  final options = sample.map((l) => l.char).toList();
  final correctSet = <int>{
    for (var i = 0; i < sample.length; i++)
      if (sample[i].dotPos == pos) i,
  };
  return QuizQuestion(
    prompt: context.l10n.qpChooseDotsPos(dotPosLabel(context, pos)),
    options: options,
    optionsAreArabic: true,
    correctSet: correctSet,
  );
}

QuizQuestion? _resemblesQuestion(BuildContext context) {
  final withFamily = letters.where((l) => l.similarGroup != null).toList()
    ..shuffle(_rng);
  if (withFamily.isEmpty) return null;
  final l = withFamily.first;
  final family =
      similarFamilies[l.similarGroup]!.where((c) => c != l.char).toList();
  final answer = family[_rng.nextInt(family.length)];
  final o = buildOptions(answer, letters.map((x) => x.char).toList(), _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichResembles(letterName(context, l)),
    arabic: l.char,
    reviewId: 'letter.resembles.${l.char}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

/// Recognise a letter by its shape even in one of the muṣḥaf's real
/// allographs (kāf wrapping an alif, the elevated tooth, ...) — the point
/// isn't the abstract fact "this letter has a variant", it's being able to
/// still read the letter when the font draws it differently.
QuizQuestion? _variantIdQuestion(BuildContext context) {
  final single = letterVariants.where((v) => v.letter.length == 1).toList();
  if (single.isEmpty) return null;
  final v = single[_rng.nextInt(single.length)];
  final pool = [
    ...letters.map((l) => l.char),
    ...extraLetters.map((l) => l.char),
  ];
  final o = buildOptions(v.letter, pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLetterShapesThis,
    arabic: v.word,
    highlight: v.highlight,
    reviewId: 'variant.${v.id}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

QuizScreen _letterPracticeQuiz(BuildContext context) {
  final qs = <QuizQuestion>[
    _dotCountQuestion(context),
    _dotPosQuestion(context),
    _dotCountQuestion(context),
    for (final q in [_resemblesQuestion(context), _variantIdQuestion(context)])
      if (q != null) q,
  ];
  final sample = [...letters]..shuffle(_rng);
  final pool = letters.map((l) => letterName(context, l)).toList();
  for (final l in sample.take(4)) {
    final o = buildOptions(letterName(context, l), pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpWhichLetterIsThis,
        arabic: l.char,
        reviewId: 'letter.${l.char}',
        options: o.options,
        correct: o.correct));
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.letterQuiz,
      progressId: 'qaidah.letters',
      questions: qs,
      graded: false);
}

// ──────────────────────── Unit 2 practice: Forms ───────────────────────────

QuizQuestion _connectorQuestion(BuildContext context) {
  final l = ([...letters]..shuffle(_rng)).first;
  final answer = l.joins ? context.l10n.optConnects : context.l10n.optDoesNotConnect;
  final o = buildOptions(
      answer, [context.l10n.optConnects, context.l10n.optDoesNotConnect], _rng);
  return QuizQuestion(
    prompt: context.l10n.qpDoesThisConnect,
    arabic: l.char,
    reviewId: 'letter.joins.${l.char}',
    options: o.options,
    correct: o.correct,
  );
}

const _stackPartner = {'stacks_jeem': 'ج', 'stacks_hah': 'ح', 'stacks_khah': 'خ'};

QuizQuestion? _stackQuestion(BuildContext context) {
  final stacked = letterVariants.where((v) => v.kind == 'stacked').toList();
  if (stacked.isEmpty) return null;
  final v = stacked[_rng.nextInt(stacked.length)];
  final partner = _stackPartner[v.id.split('.').last];
  if (partner == null) return null;
  final o = buildOptions(partner, letters.map((l) => l.char).toList(), _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLetterStacksUnder(v.letter),
    arabic: v.word,
    highlight: v.highlight,
    reviewId: 'variant.${v.id}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

QuizQuestion? _haaVsTaaMarbutaQuestion(BuildContext context) {
  final entries = letterVariants
      .where((v) => v.id == 'haa.word_final' || v.id == 'taa_marbuta.word_final')
      .toList();
  if (entries.isEmpty) return null;
  final v = entries[_rng.nextInt(entries.length)];
  final answer = v.id.startsWith('haa') ? 'ه' : 'ة';
  final o = buildOptions(answer, const ['ه', 'ة'], _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLetterEndsWord,
    arabic: v.word,
    highlight: v.highlight,
    reviewId: 'variant.${v.id}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

const _hamzaCarrierChars = ['ء', 'أ', 'إ', 'ؤ', 'ئ'];

QuizQuestion _hamzaCarrierQuestion(BuildContext context) {
  final carriers =
      extraLetters.where((l) => _hamzaCarrierChars.contains(l.char)).toList();
  final l = carriers[_rng.nextInt(carriers.length)];
  final o = buildOptions(l.char, carriers.map((c) => c.char).toList(), _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichHamzaForm(letterName(context, l)),
    arabic: l.exampleWord,
    highlight: l.char,
    reviewId: 'extra.${l.char}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

QuizScreen _formsPracticeQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  final sample = ([...letters]..shuffle(_rng)).take(4).toList();
  final names = sample.map((l) => letterName(context, l)).toList();
  qs.add(QuizQuestion(
      prompt: context.l10n.qpListBackward,
      options: [...names]..shuffle(_rng),
      sequence: names.reversed.toList()));
  for (final q in [
    _connectorQuestion(context),
    _connectorQuestion(context),
    _stackQuestion(context),
    _haaVsTaaMarbutaQuestion(context),
    _hamzaCarrierQuestion(context),
  ]) {
    if (q != null) qs.add(q);
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.formsQuiz,
      progressId: 'qaidah.forms',
      questions: qs,
      graded: false);
}

// ───────────────────── Units 3–4: Ḥarakāt / Tanwīn learn ──────────────────

Widget _harakatLearn(BuildContext context) {
  final items =
      tashkil.where((t) => ['fatha', 'kasra', 'damma'].contains(t.id)).toList();
  return ConceptLearnScreen(
    title: context.l10n.unitHarakat,
    cards: [
      for (final t in items)
        ConceptCard(
            glyph: t.mark,
            title: tashkilName(context, t),
            subtitle: t.sound,
            note: t.note,
            example: t.example,
            exampleRef: t.ref),
    ],
  );
}

QuizScreen _harakatPracticeQuiz(BuildContext context) {
  final base = _syllableQuiz(
      context, context.l10n.harakatDrill, 'qaidah.harakat', harakat,
      graded: false);
  final qs = [...base.questions];
  final sample = [..._quranWords]..shuffle(_rng);
  for (final (ar, _) in sample.take(2)) {
    final q = _spellQuestion(context, ar, reverse: qs.length.isEven);
    if (q != null) qs.add(q);
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: base.title, progressId: base.progressId, questions: qs, graded: false);
}

Widget _tanwinLearn(BuildContext context) {
  final items = tashkil
      .where((t) => ['fathatan', 'kasratan', 'dammatan'].contains(t.id))
      .toList();
  final cards = <ConceptCard>[
    for (final t in items)
      ConceptCard(
          glyph: t.mark,
          title: tashkilName(context, t),
          subtitle: t.sound,
          note: t.note,
          example: t.example,
          exampleRef: t.ref),
    for (final a in tanwinAllographs)
      ConceptCard(
        glyph: a.highlight,
        title:
            '${tashkilName(context, tashkil.firstWhere((t) => t.id == a.tanwinId))} · ${a.form}',
        subtitle: tajwidName(context, tajwidRules.firstWhere((r) => r.id == a.ruleId)),
        note: tajwidHow(context, tajwidRules.firstWhere((r) => r.id == a.ruleId)),
        example: a.example,
        exampleRef: a.ref,
      ),
  ];
  return ConceptLearnScreen(title: context.l10n.unitTanwin, cards: cards);
}

QuizQuestion _allographRuleQuestion(BuildContext context) {
  final a = tanwinAllographs[_rng.nextInt(tanwinAllographs.length)];
  final rule = tajwidRules.firstWhere((r) => r.id == a.ruleId);
  final pool = tajwidRules
      .where((r) => ['izhar', 'idgham_g', 'idgham_ng', 'ikhfa', 'iqlab'].contains(r.id))
      .map((r) => tajwidName(context, r))
      .toList();
  final o = buildOptions(tajwidName(context, rule), pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichRuleThisShape,
    arabic: a.example,
    highlight: a.highlight,
    reviewId: 'tanwin.allograph.${a.id}',
    options: o.options,
    correct: o.correct,
    explain: tajwidHow(context, rule),
  );
}

QuizScreen _tanwinPracticeQuiz(BuildContext context) {
  final base = _syllableQuiz(
      context, context.l10n.tanwinDrill, 'qaidah.tanwin', tanwin,
      graded: false);
  final qs = [...base.questions, _allographRuleQuestion(context), _allographRuleQuestion(context)];
  qs.shuffle(_rng);
  return QuizScreen(
      title: base.title, progressId: base.progressId, questions: qs, graded: false);
}

// ───────────────────────── Units 5–6: Sukūn / Shaddah ──────────────────────

Widget _sukunLearn(BuildContext context) {
  final t = tashkil.firstWhere((t) => t.id == 'sukun');
  return ConceptLearnScreen(title: tashkilName(context, t), cards: [
    ConceptCard(
        glyph: t.mark,
        title: tashkilName(context, t),
        subtitle: t.sound,
        note: t.note,
        example: t.example,
        exampleRef: t.ref),
  ]);
}

Widget _shaddaLearn(BuildContext context) {
  final t = tashkil.firstWhere((t) => t.id == 'shadda');
  return ConceptLearnScreen(title: context.l10n.shaddah, cards: [
    ConceptCard(
        glyph: t.mark,
        title: tashkilName(context, t),
        subtitle: t.sound,
        note: t.note,
        example: t.example,
        exampleRef: t.ref),
  ]);
}

// ─────────────────────── Unit 8: Reading Words ─────────────────────────────

Widget _wordsLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.readingWords,
      cards: [
        for (final (ar, tr) in _quranWords)
          ConceptCard(glyph: ar, title: tr, example: ar),
      ],
    );

QuizScreen _wordsPracticeQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  final sample = [..._quranWords]..shuffle(_rng);
  for (final (ar, _) in sample.take(6)) {
    final q = _spellQuestion(context, ar, reverse: false);
    if (q != null) qs.add(q);
  }
  if (qs.isEmpty) {
    // Fallback so the phase is never empty: reuse the graded word quiz.
    return _wordQuiz(context, graded: false);
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.readingWords,
      progressId: 'qaidah.words',
      questions: qs,
      graded: false);
}

// ───────────────────────────── Unit 9: Waṣl ────────────────────────────────

Widget _waslLearn(BuildContext context) {
  final shamsiyya = tajwidRules.firstWhere((r) => r.id == 'shamsiyya');
  final qamariyya = tajwidRules.firstWhere((r) => r.id == 'qamariyya');
  final solarEx = waslOfKind('solar').firstWhere((w) => w.letter == 'ل');
  final lunarEx = waslOfKind('lunar').firstWhere((w) => w.letter == 'م');
  final rect = waslOfKind('zero_rect').first;
  final round = waslOfKind('zero_round').first;
  final tanwinWasl = waslOfKind('tanwin_wasl').first;
  final waslConcept = waslOfKind('wasl').first;
  final waslTashkil = tashkil.firstWhere((t) => t.id == 'wasl');
  return ConceptLearnScreen(
    title: context.l10n.unitWasl,
    cards: [
      ConceptCard(
          glyph: waslTashkil.mark,
          title: tashkilName(context, waslTashkil),
          note: waslTashkil.note,
          example: waslConcept.example,
          exampleRef: waslConcept.ref),
      ConceptCard(
        glyph: 'ت ث د ذ ر ز س ش ص ض ط ظ ل ن',
        title: context.l10n.solarLetters14,
        subtitle: tajwidName(context, shamsiyya),
        note: tajwidHow(context, shamsiyya),
        example: solarEx.example,
        exampleRef: solarEx.ref,
      ),
      ConceptCard(
        glyph: 'ء ب ج ح خ ع غ ف ق ك م ه و ي',
        title: context.l10n.lunarLetters14,
        subtitle: tajwidName(context, qamariyya),
        note: tajwidHow(context, qamariyya),
        example: lunarEx.example,
        exampleRef: lunarEx.ref,
      ),
      ConceptCard(
        glyph: '۠',
        title: context.l10n.zeroRectTitle,
        note: context.l10n.zeroRectNote,
        example: rect.example,
        exampleRef: rect.ref,
      ),
      ConceptCard(
        glyph: 'ۡ',
        title: context.l10n.zeroRoundTitle,
        note: context.l10n.zeroRoundNote,
        example: round.example,
        exampleRef: round.ref,
      ),
      ConceptCard(
        glyph: 'ً ٱ',
        title: context.l10n.tanwinMeetsWaslTitle,
        note: context.l10n.tanwinMeetsWaslNote,
        example: tanwinWasl.example,
        exampleRef: tanwinWasl.ref,
      ),
    ],
  );
}

QuizQuestion _waslSeamQuestion(BuildContext context) {
  final solarOrLunar = [...waslOfKind('solar'), ...waslOfKind('lunar')]..shuffle(_rng);
  final w = solarOrLunar.first;
  final isSolar = w.kind == 'solar';
  final shamsiyya = tajwidRules.firstWhere((r) => r.id == 'shamsiyya');
  final qamariyya = tajwidRules.firstWhere((r) => r.id == 'qamariyya');
  final correctRule = isSolar ? shamsiyya : qamariyya;
  final otherRule = isSolar ? qamariyya : shamsiyya;
  final options = [tajwidName(context, correctRule), tajwidName(context, otherRule)]
    ..shuffle(_rng);
  return QuizQuestion(
    prompt: context.l10n.qpLamHereDoes,
    arabic: w.example,
    highlight: w.highlight,
    reviewId: 'wasl.seam.${w.id}',
    options: options,
    correct: options.indexOf(tajwidName(context, correctRule)),
    explain: tajwidHow(context, correctRule),
  );
}

QuizQuestion _waslSolarSetQuestion(BuildContext context) {
  final solar = waslOfKind('solar')..shuffle(_rng);
  final lunar = waslOfKind('lunar')..shuffle(_rng);
  final sample = [...solar.take(4), ...lunar.take(4)]..shuffle(_rng);
  final options = sample.map((w) => w.letter).toList();
  final correctSet = <int>{
    for (var i = 0; i < sample.length; i++)
      if (sample[i].kind == 'solar') i,
  };
  return QuizQuestion(
    prompt: context.l10n.qpChooseEverySolarLetter,
    options: options,
    optionsAreArabic: true,
    correctSet: correctSet,
  );
}

QuizQuestion _waslZeroQuestion(BuildContext context) {
  final zeros = [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')]..shuffle(_rng);
  final w = zeros.first;
  final sounded = w.kind == 'zero_rect';
  final options = [context.l10n.optSoundedOnStopOnly, context.l10n.optNeverSounded];
  return QuizQuestion(
    prompt: context.l10n.qpAlifSoundsWhen,
    arabic: w.example,
    highlight: w.highlight,
    reviewId: 'wasl.zero.${w.id}',
    options: options,
    correct: sounded ? 0 : 1,
  );
}

QuizScreen _waslQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[
    for (var i = 0; i < 4; i++) _waslSeamQuestion(context),
    _waslSolarSetQuestion(context),
    _waslSolarSetQuestion(context),
    for (var i = 0; i < 3; i++) _waslZeroQuestion(context),
  ];
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitWasl,
      progressId: 'qaidah.wasl',
      questions: qs,
      graded: graded);
}

// ───────────────────────────── Unit 10: Review ─────────────────────────────

Widget _reviewLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.qaidahReview,
      cards: [
        ConceptCard(
            glyph: 'ا ب', title: context.l10n.unitLetters, note: context.l10n.unitLettersSub),
        ConceptCard(
            glyph: 'ـبـ',
            title: context.l10n.unitJoiningForms,
            note: context.l10n.unitJoiningFormsSub),
        ConceptCard(glyph: 'بَ', title: context.l10n.unitHarakat, note: context.l10n.unitHarakatSub),
        ConceptCard(glyph: 'بً', title: context.l10n.unitTanwin, note: context.l10n.unitTanwinSub),
        ConceptCard(
            glyph: 'بۡ',
            title: tashkilName(context, tashkil.firstWhere((t) => t.id == 'sukun')),
            note: context.l10n.unitSukunSub),
        ConceptCard(glyph: 'بّ', title: context.l10n.shaddah, note: context.l10n.unitShaddahSub),
        ConceptCard(
            glyph: 'بَا', title: context.l10n.unitMaddLin, note: context.l10n.unitMaddLinSub),
        ConceptCard(
            glyph: 'قُلۡ',
            title: context.l10n.readingWords,
            note: context.l10n.unitReadingWordsSub),
      ],
    );

// ─────────────────────── Unit 10: Ḥurūf Muqaṭṭaʿāt ─────────────────────────

Widget _muqattaatLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.unitMuqattaat,
      cards: [
        for (final m in muqattaatSets)
          ConceptCard(
            glyph: m.displayText,
            title: m.displayText,
            subtitle: context.l10n.surahsList(m.surahs.join(', ')),
            note: context.l10n.muqattaatCountsNote(
                [for (final l in m.letters.split('')) '$l:${muqattaatCounts[l]}']
                    .join('  ')),
            example: m.ref == '42:1-2' ? null : m.example,
            exampleRef: m.ref == '42:1-2' ? null : m.ref,
          ),
      ],
    );

QuizQuestion _muqattaatSurahQuestion(BuildContext context) {
  final m = muqattaatSets[_rng.nextInt(muqattaatSets.length)];
  final surah = m.surahs[_rng.nextInt(m.surahs.length)];
  final pool = muqattaatSets.expand((s) => s.surahs).map((s) => '$s').toList();
  final o = buildOptions('$surah', pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichSurahOpensWith,
    arabic: m.displayText,
    reviewId: 'muqattaat.surah.${m.id}',
    options: o.options,
    correct: o.correct,
  );
}

QuizQuestion _muqattaatCountsQuestion(BuildContext context) {
  final letter = muqattaatCounts.keys.elementAt(_rng.nextInt(muqattaatCounts.length));
  final answer = muqattaatCounts[letter]!;
  final o = buildOptions(answer, muqattaatCounts.values.toSet().toList(), _rng);
  return QuizQuestion(
    prompt: context.l10n.qpHowManyCountsLetter,
    arabic: letter,
    reviewId: 'muqattaat.counts.$letter',
    options: o.options,
    correct: o.correct,
  );
}

QuizQuestion _muqattaatLettersQuestion(BuildContext context) {
  final m = muqattaatSets[_rng.nextInt(muqattaatSets.length)];
  final correctChars = m.letters.split('').toSet();
  const all14 = 'احرسصطعقكلمنهي';
  final distractorPool = all14.split('').where((c) => !correctChars.contains(c)).toList()
    ..shuffle(_rng);
  final options = [...correctChars, ...distractorPool.take(8 - correctChars.length)]
    ..shuffle(_rng);
  final correctSet = <int>{
    for (var i = 0; i < options.length; i++)
      if (correctChars.contains(options[i])) i,
  };
  return QuizQuestion(
    prompt: context.l10n.qpChooseLettersInSet,
    arabic: m.displayText,
    reviewId: 'muqattaat.letters.${m.id}',
    options: options,
    optionsAreArabic: true,
    correctSet: correctSet,
  );
}

QuizScreen _muqattaatTest(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[
    for (var i = 0; i < 3; i++) _muqattaatSurahQuestion(context),
    for (var i = 0; i < 3; i++) _muqattaatCountsQuestion(context),
    _muqattaatLettersQuestion(context),
    _muqattaatLettersQuestion(context),
  ];
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitMuqattaat,
      progressId: 'qaidah.muqattaat',
      questions: qs,
      graded: graded);
}

// ─────────────── desktop builds (match the reference HTML) ───────────────

Widget _deskSection(BuildContext context, String title, {String? sub}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
              color: pal(context).accent,
              borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 12),
      Text(title, style: uiStyle(context, size: 20, weight: FontWeight.w800)),
      if (sub != null) ...[
        const SizedBox(width: 12),
        Text(sub,
            style: uiStyle(context, size: 13, color: pal(context).textDim)),
      ],
    ]),
  );
}

BoxDecoration _deskCard(BuildContext context) => BoxDecoration(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
          color: pal(context).surfaceHigh.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
            color: pal(context).shadow,
            blurRadius: 20,
            offset: const Offset(0, 6)),
      ],
    );

Widget _deskCta(BuildContext context, String label, VoidCallback onTap) {
  return Align(
    alignment: Alignment.centerLeft,
    child: FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: pal(context).accent,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      onPressed: onTap,
      child: Text(label),
    ),
  );
}
