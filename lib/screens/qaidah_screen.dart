import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/letter_audio.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/extra_letters.dart';
import '../data/glyph_names.dart';
import '../data/letters.dart';
import '../data/makharij.dart';
import '../data/muqattaat.dart';
import '../data/quran.dart' show stripTashkil;
import '../data/small_letters.dart';
import '../data/strokes.dart' show glyphFor;
import '../data/tajweed.dart';
import '../data/tanwin_allographs.dart';
import '../data/tashkeel.dart';
import '../data/variants.dart';
import '../data/wasl.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import '../widgets/lesson.dart';
import 'lessons/forms_lessons.dart';
import 'lessons/forms_quizzes.dart';
import 'lessons/qaidah_lessons.dart';
import 'lessons/tajwid_lessons.dart';
import 'tashkeel_screen.dart';
import 'tracing_screen.dart' show TracingBoard;

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
    final stars = [for (final u in units) progress.starsFor(u.progressId)];
    // The first unit without stars is "current"; nothing is ever locked.
    final current = stars.indexWhere((x) => x == 0);
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.qaidahPath)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            QColumn(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(context.l10n.qaidahLead,
                    style: displayStyle(context, size: 24, height: 1.25)),
              ),
            ),
            for (var i = 0; i < units.length; i++)
              QColumn(
                child: QRiseIn(
                  delay: Duration(milliseconds: 30 * i),
                  child: _PathRow(
                    n: i + 1,
                    unit: units[i],
                    stars: stars[i],
                    current: i == current,
                    last: i == units.length - 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One unit on the path: a node (✓ done, ring for current, number for open)
/// on a connecting line, and the unit card with its stars and glyph.
class _PathRow extends StatelessWidget {
  final int n;
  final QaidahUnit unit;
  final int stars;
  final bool current;
  final bool last;
  const _PathRow({
    required this.n,
    required this.unit,
    required this.stars,
    required this.current,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final done = stars > 0;
    final latin = const {'en', 'fr', 'es'}
        .contains(SettingsScope.of(context).language);
    final label = context.l10n.unitLabel(n);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              const SizedBox(height: 20),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? p.accBg : (current ? p.card : p.bg),
                  border: Border.all(color: p.acc, width: 2),
                ),
                child: done
                    ? const Icon(AppIcons.check, size: 15, color: Colors.white)
                    : current
                        ? null
                        : Text('$n',
                            style: uiStyle(context,
                                size: 12,
                                weight: FontWeight.w700,
                                color: p.acc)),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.only(top: 4),
                  color: last ? Colors.transparent : (done ? p.acc : p.line3),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QCard(
                padding: const EdgeInsets.all(14),
                borderColor: current ? p.acc : null,
                onTap: () => pushAdaptive(context, QaidahUnitHub(unit: unit)),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(latin ? label.toUpperCase() : label,
                            style: uiStyle(context,
                                size: 11,
                                weight: FontWeight.w700,
                                letterSpacing: .6,
                                color: p.ink3)),
                        const SizedBox(height: 2),
                        Text(unit.title,
                            style: uiStyle(context,
                                size: 15, weight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(unit.subtitle,
                            style: uiStyle(context,
                                size: 12.5, color: p.ink3, height: 1.35)),
                        const SizedBox(height: 8),
                        StarRow(stars, size: 15),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.track,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(unit.arabicBadge,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        style: quranicStyle(context,
                            size: 22, height: 1.3, color: p.acc)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
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
              learn: (c) => lessonEntryScreen(formsLessonRoot(c)),
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
              learn: (c) => lessonEntryScreen(tashkilLessonRoot(c, focusCounts: true)),
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
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: PhaseHub(
          subtitle: unit.subtitle,
            glyph: unit.arabicBadge,
            title: unit.title,
            stars: ProgressScope.of(context).starsFor(unit.progressId),
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
  const LettersExplorer({super.key});

  Widget _tile(BuildContext context, ArabicLetter l,
      {required double glyph, bool dot = false, VoidCallback? onTap}) {
    final p = pal(context);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.line2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.char,
                  style: arabicStyle(context, size: glyph, height: 1.3)),
              Text(letterName(context, l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context,
                      size: 10.5, weight: FontWeight.w600, color: p.ink3)),
            ]),
          ),
          if (dot)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: p.acc, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }

  // The grid runs right to left like the alphabet; each tile goes back to
  // the app's direction so Latin names ("Tāʼ") don't reorder.
  Widget _grid(BuildContext context, List<ArabicLetter> items, double extent,
          Widget Function(ArabicLetter) tile) =>
      Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: extent,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10),
          itemCount: items.length,
          itemBuilder: (_, i) => Directionality(
              textDirection: Directionality.of(context), child: tile(items[i])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final progress = ProgressScope.of(context);
    final desk = useDesktop(context);
    bool seen(ArabicLetter l) => progress.starsFor('letter.${l.char}') > 0;
    final explored = letters.where(seen).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.theLetters),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 20),
            child: Center(
              child: Text(
                  context.l10n.lettersExploredCount(explored, letters.length),
                  style: uiStyle(context,
                      size: 13, weight: FontWeight.w600, color: p.ink3)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
          children: [
            QColumn(
              maxWidth: desk ? 1080 : 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grid(
                      context,
                      letters,
                      desk ? 120 : 84,
                      (l) => _tile(context, l,
                              glyph: desk ? 44 : 32, dot: seen(l), onTap: () {
                            progress.report('letter.${l.char}', 1);
                            pushAdaptive(context, LetterDetail(letter: l));
                          })),
                  SectionHeader(context.l10n.extraLettersTitle,
                      subtitle: context.l10n.extraLettersSub),
                  _grid(
                      context,
                      extraLetters,
                      desk ? 120 : 84,
                      (l) => _tile(context, l,
                          glyph: desk ? 36 : 28,
                          onTap: () =>
                              pushAdaptive(context, LetterDetail(letter: l)))),
                  SectionHeader(context.l10n.smallLettersTitle,
                      subtitle: context.l10n.smallLettersSub),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final sl in smallLetters)
                        QCard(
                          radius: 16,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          onTap: () => pushAdaptive(
                              context,
                              LessonDetailScreen(
                                  node: smallLetterLessonNode(context, sl))),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(sl.mark,
                                style: quranicStyle(context,
                                    size: 26, color: p.acc)),
                            const SizedBox(height: 4),
                            Text(sl.name,
                                style: uiStyle(context,
                                    size: 11.5, color: p.ink2)),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: p.ink,
        foregroundColor: p.bg,
        elevation: 6,
        onPressed: () => pushAdaptive(context, _letterQuiz(context)),
        icon: const Icon(AppIcons.quiz),
        label: Text(context.l10n.letterQuiz,
            style: uiStyle(context,
                size: 14, weight: FontWeight.w700, color: p.bg)),
      ),
    );
  }
}

/// 'beginning' | 'middle' | 'end' → the reader's language.
String _posLabel(BuildContext context, String p) => switch (p) {
      'beginning' => context.l10n.posBeginning,
      'middle' => context.l10n.posMiddle,
      _ => context.l10n.posEnd,
    };

/// One real word showing a letter in context, tagged with where it sits —
/// used by [LetterDetail] so "several real examples, not just one" looks and
/// behaves the same everywhere it appears.
Widget _wordCard(BuildContext context, LetterExample w) {
  final p = pal(context);
  return QCard(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        QTag(_posLabel(context, w.position)),
        Text(w.word,
            textDirection: TextDirection.rtl,
            style: quranicStyle(context, size: 44, height: 1.85, color: p.ink)),
        Text(w.translit,
            style: uiStyle(context,
                size: 13.5, weight: FontWeight.w600, color: p.ink3)),
      ],
    ),
  );
}

/// Mobile counterpart of [_wordCard] — a compact row instead of a tall card.
Widget _mobWordCard(BuildContext context, LetterExample w) => QCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        QTag(_posLabel(context, w.position)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(w.translit,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiStyle(context,
                  size: 12.5, weight: FontWeight.w600, color: pal(context).ink3)),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(w.word,
                textDirection: TextDirection.rtl,
                style: quranicStyle(context, size: 30)),
          ),
        ),
      ]),
    );

/// A letter's articulation point, cross-linking into its Tajwīd Makhārij
/// lesson page — real data ([makhrajOfLetter]/[makhrajOfExtraLetter])
/// already existed for the quiz engine but was never surfaced here.
Widget _makhrajRow(BuildContext context, String char) {
  final id = makhrajOfLetter[char] ?? makhrajOfExtraLetter[char];
  if (id == null) return const SizedBox.shrink();
  final m = makhrajById(id);
  final p = pal(context);
  return QCard(
    padding: const EdgeInsets.all(14),
    onTap: () => openLesson(context, makharijPointNode(context, id)),
    child: Row(children: [
      Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.accSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: m.letters.isEmpty
            ? Text(char,
                textDirection: TextDirection.rtl,
                style: quranicStyle(context, size: 17, color: p.acc))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: separatedLetters(context, m.letters,
                    size: 17, color: p.acc, max: 3),
              ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.name,
                style: uiStyle(context, size: 14.5, weight: FontWeight.w700)),
            Text(m.arabicName,
                textDirection: TextDirection.rtl,
                style: arabicStyle(context, size: 13, color: p.ink3)),
          ],
        ),
      ),
      Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
    ]),
  );
}

/// Listen + Watch for one letter — unlike the shared [MediaRow]
/// (`widgets/common.dart`), Listen here is the letter's own sound via
/// [LetterAudio] rather than a verse, and Watch is a real stroke-by-stroke
/// replay built from the same data [TracingBoard]'s guided mode already uses
/// to ink a learner's own strokes, not [MediaRow]'s permanent "coming soon"
/// stub. Watch only appears for the 28 traced letters — the extra letters
/// [LetterDetail] also renders (hamza carriers, tāʼ marbūṭah…) have no
/// stroke data to animate.
class _LetterMediaRow extends StatelessWidget {
  final ArabicLetter letter;
  const _LetterMediaRow({required this.letter});

  @override
  Widget build(BuildContext context) {
    final canWatch = letters.contains(letter);
    return Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          QPrimaryButton(context.l10n.listen,
              icon: AppIcons.volume,
              height: 42,
              onTap: () => LetterAudio.playOrComingSoon(context, letter,
                  variant: LetterAudio.adult)),
          if (canWatch)
            QOutlineButton(context.l10n.watch,
                icon: AppIcons.trace,
                onTap: () => _showWatchLetter(context, letter)),
        ]);
  }
}

void _showWatchLetter(BuildContext context, ArabicLetter letter) {
  showModalBottomSheet(
    context: context,
    backgroundColor: pal(context).bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 340,
          child: TracingBoard(
            key: ValueKey('watch.${letter.char}'),
            glyph: glyphFor(letter.char, 'iso'),
            mode: 'guided',
            watch: true,
          ),
        ),
      ),
    ),
  );
}

class LetterDetail extends StatelessWidget with DesktopAware {
  final ArabicLetter letter;
  final String mode; // 'letters' | 'joining'
  const LetterDetail({super.key, required this.letter, this.mode = 'letters'});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final dotInfo = dotsDescForLetter(context, letter);
    final words = letterExamples[letter.char] ?? const <LetterExample>[];
    final index = letters.indexOf(letter);
    final fam = letter.similarGroup == null
        ? const <String>[]
        : similarFamilies[letter.similarGroup]!;
    final hero = Column(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: .6, end: 1),
        duration: motion(context, const Duration(milliseconds: 500)),
        curve: Curves.elasticOut,
        // elasticOut overshoots past 1.0 by design; Transform.scale doesn't
        // affect layout, so an un-clamped overshoot would paint the glyph
        // larger than the box it was just sized for.
        builder: (context, v, child) =>
            Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
        child: Text(letter.char,
            style: quranicStyle(context, size: 120, height: 1.85, color: p.acc)),
      ),
      Text('“${letter.translit}” · $dotInfo',
          textAlign: TextAlign.center,
          style: uiStyle(context, size: 14, color: p.ink2)),
      const SizedBox(height: 14),
      _LetterMediaRow(letter: letter),
    ]);
    final forms = index < 0
        ? null
        : Row(children: [
            for (final (i, (g, label)) in [
              (letter.char, context.l10n.formAlone),
              (letter.joins ? letter.initial : letter.char, context.l10n.formStart),
              (letter.joins ? letter.medial : letter.finalForm,
                  context.l10n.formMiddle),
              (letter.finalForm, context.l10n.formEnd),
            ].indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                  child: QCard(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(children: [
                      Text(g,
                          textDirection: TextDirection.rtl,
                          style: arabicStyle(context,
                              size: 30,
                              height: 1.5,
                              color: i == 0 ? p.acc : p.ink)),
                      Text(label,
                          style: uiStyle(context,
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: p.ink3)),
                    ]),
                  ),
                ),
              ),
          ]);
    final confused = fam.length < 2
        ? null
        : Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in fam)
                Directionality(
                  textDirection: Directionality.of(context),
                  child: _confusedTile(
                    context,
                    letters.firstWhere((l) => l.char == c),
                    target: c == letter.char,
                  ),
                ),
            ]),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(letterName(context, letter)),
        actions: [
          if (index >= 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 20),
              child: Center(
                child: Text(context.l10n.nOfTotal(index + 1, letters.length),
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w600, color: p.ink3)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            children: [
              QColumn(
                maxWidth: wide ? 1080 : 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: QCard(
                                padding: const EdgeInsets.all(24),
                                child: Center(child: hero),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: QCard(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (forms != null) ...[
                                      SectionHeader(context.l10n.shapes),
                                      forms,
                                    ],
                                    SectionHeader(
                                        context.l10n.easilyConfusedWith,
                                        subtitle: confused == null
                                            ? context.l10n.noLookAlikes
                                            : context.l10n
                                                .sameSkeletonDotsDecide),
                                    ?confused,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      hero,
                      if (forms != null) ...[
                        SectionHeader(context.l10n.shapes),
                        forms,
                      ],
                      if (confused != null) ...[
                        SectionHeader(context.l10n.easilyConfusedWith,
                            subtitle: context.l10n.sameSkeletonDotsDecide),
                        confused,
                      ],
                    ],
                    if (words.isNotEmpty) ...[
                      SectionHeader(context.l10n.seeItInWords,
                          subtitle: context.l10n.seeItInWordsSub),
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < words.length; i++) ...[
                                if (i > 0) const SizedBox(width: 14),
                                Expanded(child: _wordCard(context, words[i])),
                              ],
                            ],
                          ),
                        )
                      else
                        for (final w in words)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _mobWordCard(context, w),
                          ),
                    ],
                    SectionHeader(context.l10n.lsnArticulationPoint),
                    _makhrajRow(context, letter.char),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _confusedTile(BuildContext context, ArabicLetter l,
      {required bool target}) {
    final p = pal(context);
    return Material(
      color: target ? p.accSoft : p.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: target ? p.acc : p.line2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: target
            ? null
            : () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => LetterDetail(letter: l, mode: mode))),
        child: SizedBox(
          width: 92,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(children: [
              Text(l.char,
                  style: arabicStyle(context,
                      size: 34, height: 1.4, color: target ? p.acc : p.ink)),
              Text(letterName(context, l),
                  style: uiStyle(context, size: 12, weight: FontWeight.w700)),
              Text(dotsDesc(context, l.dotCount, l.dotPos),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: uiStyle(context, size: 10.5, color: p.ink3)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Generated drills ───────────────────────────

final _rng = math.Random();

QuizScreen letterQuizScreen(BuildContext context,
        {String progressId = 'qaidah.letters'}) =>
    _letterQuiz(context, progressId: progressId);

QuizScreen _letterQuiz(BuildContext context,
    {bool graded = true, String progressId = 'qaidah.letters'}) {
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
      progressId: progressId,
      questions: qs,
      graded: graded);
}

QuizScreen _formsQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[];
  final pool = letters.map((l) => letterName(context, l)).toList();
  // Non-joiners (ا و د ذ ر ز) have no real initial/medial form — asking about
  // one would show a stray tatweel run, not a shape that exists in the muṣḥaf.
  final sample = letters.where((l) => l.joins).toList()..shuffle(_rng);
  for (final l in sample.take(5)) {
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
  // Half the round is now the other three question shapes — naming a shape
  // ten times over drills recognition only. See forms_quizzes.dart.
  qs
    ..addAll(formGridQuestions(context, count: 3))
    ..addAll(formPositionQuestions(context, count: 2))
    ..addAll(buildTheWordQuestions(context, count: 2))
    ..shuffle(_rng);
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
    ..._tashkilMarkQuestions(context, 'sukun', 2),
  ]..shuffle(_rng);
  return QuizScreen(
      title: tashkilName(context, tashkil.firstWhere((t) => t.id == 'sukun')),
      progressId: 'qaidah.sukun',
      questions: qs,
      graded: graded);
}

/// A few "identify the mark" questions for [tashkilId], drawn from its real
/// corpus examples (the primary plus `moreExamples`) — the same recognition
/// format tashkeel_screen.dart's `_tashkilQuiz` already uses, reused here
/// instead of Units 5-6 repeating the exact same handful of hand-authored
/// questions every session.
List<QuizQuestion> _tashkilMarkQuestions(
    BuildContext context, String tashkilId, int count) {
  final t = tashkil.firstWhere((x) => x.id == tashkilId);
  final examples = [
    (t.example, t.ref, t.highlight),
    ...t.moreExamples,
  ];
  final pool = tashkil.map((x) => tashkilName(context, x)).toList();
  final qs = <QuizQuestion>[];
  for (final (word, ref, hl) in pickN(examples, count, _rng)) {
    final o = buildOptions(tashkilName(context, t), pool, _rng);
    qs.add(QuizQuestion(
      prompt: context.l10n.qpIdentifyGoldenMark,
      arabic: word,
      highlight: hl,
      reviewId: 'qaidah.$tashkilId.mark.$ref',
      options: o.options,
      correct: o.correct,
      explain: t.note,
    ));
  }
  return qs;
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
    ..._tashkilMarkQuestions(context, 'shadda', 2),
  ]..shuffle(_rng);
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

QuizQuestion _dotCountQuestion(BuildContext context, int n) {
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
  final eligible =
      letterVariants.where((v) => v.letter.length == 1 || v.kind == 'ligature').toList();
  if (eligible.isEmpty) return null;
  final v = eligible[_rng.nextInt(eligible.length)];
  final pool = [
    ...letters.map((l) => l.char),
    ...extraLetters.map((l) => l.char),
    ...letterVariants.where((x) => x.kind == 'ligature').map((x) => x.letter),
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
    for (final n in pickN([0, 1, 2, 3], 2, _rng)) _dotCountQuestion(context, n),
    _dotPosQuestion(context),
    for (final q in [_resemblesQuestion(context), _variantIdQuestion(context)])
      ?q,
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

QuizQuestion _connectorQuestion(BuildContext context, ArabicLetter l) {
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

QuizQuestion? haaVsTaaMarbutaQuestion(BuildContext context) {
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

/// Recognise the lām-alif ligature family by shape — the compound reading
/// this project's Qaidah books teach right after the four tatweel forms
/// (Round 13's Special Shapes).
QuizQuestion? _ligatureQuestion(BuildContext context) {
  final ligatures = letterVariants.where((v) => v.kind == 'ligature').toList();
  if (ligatures.isEmpty) return null;
  final v = ligatures[_rng.nextInt(ligatures.length)];
  final pool = ligatures.map((x) => x.letter).toList();
  final o = buildOptions(v.letter, pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLettersFormThis,
    arabic: v.word,
    highlight: v.highlight,
    reviewId: 'variant.${v.id}',
    options: o.options,
    optionsAreArabic: true,
    correct: o.correct,
  );
}

const _hamzaCarrierChars = ['ء', 'أ', 'إ', 'ؤ', 'ئ'];

/// Which of the five hamza carriers is this? Shows the bare glyph and asks
/// for its NAME, rather than the reverse: naming one carrier ("Wāw with
/// Hamzah") and asking which glyph matches. The reverse used to break down
/// for the seatless ء — "Which is Hamzah?" over five options that are all,
/// in a real sense, "a hamzah" has no answer a child could deduce without
/// already knowing this app's own naming convention. Asking "which letter is
/// this?" of one glyph shown alone has exactly one right answer regardless of
/// which of the five gets picked.
QuizQuestion hamzaCarrierQuestion(BuildContext context) {
  final carriers =
      extraLetters.where((l) => _hamzaCarrierChars.contains(l.char)).toList();
  final l = carriers[_rng.nextInt(carriers.length)];
  final names = carriers.map((c) => letterName(context, c)).toList();
  final o = buildOptions(letterName(context, l), names, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLetterIsThis,
    arabic: l.char,
    reviewId: 'extra.${l.char}',
    options: o.options,
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
  for (final l in pickN(letters, 2, _rng)) {
    qs.add(_connectorQuestion(context, l));
  }
  for (final q in [
    _stackQuestion(context),
    haaVsTaaMarbutaQuestion(context),
    hamzaCarrierQuestion(context),
    _ligatureQuestion(context),
  ]) {
    if (q != null) qs.add(q);
  }
  // Practice draws on the same extra shapes as Test, including the listening
  // one — ungraded is exactly where a question that may have no audio belongs.
  qs
    ..addAll(formGridQuestions(context, count: 2))
    ..addAll(listenAndPickQuestions(context, count: 2))
    ..shuffle(_rng);
  return QuizScreen(
      title: context.l10n.formsQuiz,
      progressId: 'qaidah.forms',
      questions: qs,
      graded: false);
}

// ───────────────────── Units 3–4: Ḥarakāt / Tanwīn learn ──────────────────

Widget _harakatLearn(BuildContext context) => lessonEntryScreen(harakatLessonRoot(context));

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

Widget _tanwinLearn(BuildContext context) => lessonEntryScreen(tanwinLessonRoot(context));

QuizQuestion _allographRuleQuestion(BuildContext context, TanwinAllograph a,
    String text, String hl) {
  final rule = tajwidRules.firstWhere((r) => r.id == a.ruleId);
  final pool = tajwidRules
      .where((r) => ['izhar', 'idgham_g', 'idgham_ng', 'ikhfa', 'iqlab'].contains(r.id))
      .map((r) => tajwidName(context, r))
      .toList();
  final o = buildOptions(tajwidName(context, rule), pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichRuleThisShape,
    arabic: text,
    highlight: hl,
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
  final instances = <(TanwinAllograph, String, String)>[
    for (final a in tanwinAllographs) ...[
      (a, a.example, a.highlight),
      for (final (t, _, h) in a.moreExamples) (a, t, h),
    ],
  ];
  final qs = [
    ...base.questions,
    for (final (a, t, h) in pickN(instances, 2, _rng))
      _allographRuleQuestion(context, a, t, h),
  ]..shuffle(_rng);
  return QuizScreen(
      title: base.title, progressId: base.progressId, questions: qs, graded: false);
}

// ───────────────────────── Units 5–6: Sukūn / Shaddah ──────────────────────

Widget _sukunLearn(BuildContext context) => lessonEntryScreen(sukunLessonRoot(context));

Widget _shaddaLearn(BuildContext context) => lessonEntryScreen(shaddaLessonRoot(context));

// ─────────────────────── Unit 8: Reading Words ─────────────────────────────

// Each leaf here IS one word to practice reading — there's no second "more
// examples of this word" the way a rule or a mark has several demonstrating
// verses; the 16 different words together are the unit's breadth.
Widget _wordsLearn(BuildContext context) => lessonEntryScreen(LessonNode(
      id: 'qaidah.words',
      title: context.l10n.readingWords,
      children: [
        for (final (ar, tr) in _quranWords)
          LessonNode(
            id: 'word.$tr',
            glyph: ar,
            title: tr,
            detail: LessonDetail(
              hero: ar,
              letters: stripTashkil(ar),
              examples: [(text: ar, ref: '', highlight: null)],
            ),
          ),
      ],
    ));

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

Widget _waslLearn(BuildContext context) => lessonEntryScreen(waslLessonRoot(context));

QuizQuestion _waslSeamQuestion(BuildContext context, WaslItem w) {
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

QuizQuestion _waslZeroQuestion(BuildContext context, WaslItem w, String text, String hl) {
  final sounded = w.kind == 'zero_rect';
  final options = [context.l10n.optSoundedOnStopOnly, context.l10n.optNeverSounded];
  return QuizQuestion(
    prompt: context.l10n.qpAlifSoundsWhen,
    arabic: text,
    highlight: hl,
    reviewId: 'wasl.zero.${w.id}',
    options: options,
    correct: sounded ? 0 : 1,
  );
}

QuizScreen _waslQuiz(BuildContext context, {bool graded = true}) {
  final seamPool = [...waslOfKind('solar'), ...waslOfKind('lunar')];
  final zeroInstances = <(WaslItem, String, String)>[
    for (final w in [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')]) ...[
      (w, w.example, w.highlight),
      for (final (t, _, h) in w.moreExamples) (w, t, h),
    ],
  ];
  final qs = <QuizQuestion>[
    for (final w in pickN(seamPool, 4, _rng)) _waslSeamQuestion(context, w),
    _waslSolarSetQuestion(context),
    _waslSolarSetQuestion(context),
    for (final (w, t, h) in pickN(zeroInstances, 3, _rng))
      _waslZeroQuestion(context, w, t, h),
  ];
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitWasl,
      progressId: 'qaidah.wasl',
      questions: qs,
      graded: graded);
}

// ───────────────────────────── Unit 10: Review ─────────────────────────────

Widget _reviewLearn(BuildContext context) => lessonEntryScreen(reviewLessonRoot(context));

// ─────────────────────── Unit 10: Ḥurūf Muqaṭṭaʿāt ─────────────────────────

Widget _muqattaatLearn(BuildContext context) => lessonEntryScreen(muqattaatLessonRoot(context));

QuizQuestion _muqattaatSurahQuestion(BuildContext context, MuqattaatSet m) {
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

QuizQuestion _muqattaatCountsQuestion(BuildContext context, String letter) {
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

QuizQuestion _muqattaatLettersQuestion(BuildContext context, MuqattaatSet m) {
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
    for (final m in pickN(muqattaatSets, 3, _rng)) _muqattaatSurahQuestion(context, m),
    for (final l in pickN(muqattaatCounts.keys.toList(), 3, _rng))
      _muqattaatCountsQuestion(context, l),
    for (final m in pickN(muqattaatSets, 2, _rng)) _muqattaatLettersQuestion(context, m),
  ];
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitMuqattaat,
      progressId: 'qaidah.muqattaat',
      questions: qs,
      graded: graded);
}
