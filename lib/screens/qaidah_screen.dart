import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/letters.dart';
import '../data/tashkeel.dart';
import '../widgets/common.dart';
import 'tashkeel_screen.dart';

/// 📖 The Qaidah Path — the full beginner journey, in the order a
/// classical Qaidah teaches it. Every unit ends in a drill that earns stars.
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
                onTap: () => pushAdaptive(context, Builder(builder: u.builder)),
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
                          style: arabicStyle(context, size: 24, height: 1.3,
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

class QaidahUnit {
  final String title;
  final String subtitle;
  final String arabicBadge;
  final String progressId;
  final WidgetBuilder builder;
  QaidahUnit(this.title, this.subtitle, this.arabicBadge, this.progressId,
      this.builder);
}

/// The nine units of the Qaidah path — shared by mobile and desktop.
List<QaidahUnit> qaidahUnits(BuildContext context) => [
      QaidahUnit(context.l10n.unitLetters,
          context.l10n.unitLettersSub, 'ا ب',
          'qaidah.letters', (_) => const LettersExplorer()),
      QaidahUnit(context.l10n.unitJoiningForms,
          context.l10n.unitJoiningFormsSub,
          'ـبـ', 'qaidah.forms', (_) => const FormsLab()),
      QaidahUnit(context.l10n.unitHarakat, context.l10n.unitHarakatSub,
          'بَ', 'qaidah.harakat',
          (c) => _syllableQuiz(c, context.l10n.harakatDrill, 'qaidah.harakat', harakat)),
      QaidahUnit(context.l10n.unitTanwin, context.l10n.unitTanwinSub, 'بً',
          'qaidah.tanwin',
          (c) => _syllableQuiz(c, context.l10n.tanwinDrill, 'qaidah.tanwin', tanwin)),
      QaidahUnit(context.l10n.sukunJazm, context.l10n.unitSukunSub,
          'بْ', 'qaidah.sukun', (c) => _sukunQuiz(c)),
      QaidahUnit(context.l10n.shaddah, context.l10n.unitShaddahSub, 'بّ',
          'qaidah.shadda', (c) => _shaddaQuiz(c)),
      QaidahUnit(context.l10n.unitMaddLin, context.l10n.unitMaddLinSub,
          'بَا', 'qaidah.madd',
          (_) => const TashkeelScreen(focusCounts: true)),
      QaidahUnit(context.l10n.readingWords, context.l10n.unitReadingWordsSub,
          'قُلْ', 'qaidah.words', (c) => _wordQuiz(c)),
      QaidahUnit(context.l10n.qaidahReview,
          context.l10n.unitReviewSub, '۝',
          'qaidah.review', (c) => _reviewQuiz(c)),
    ];

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
                            style: TextStyle(
                                fontFamily: 'ScheherazadeNew',
                                fontSize: 52,
                                height: 1,
                                color: pal(context).text)),
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
          const SizedBox(height: 26),
          _deskCta(context, context.l10n.letterQuizTitle,
              () => pushAdaptive(context, _letterQuiz(context))),
        ],
      )),
    );
  }

  const LettersExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    return Scaffold(
      appBar: AppBar(title:  Text(context.l10n.theLetters)),
      body: SafeArea(
        top: false,
        child: GridView.builder(
        padding: const EdgeInsets.all(18),
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
                child: Text(l.char,
                    style: arabicStyle(context, size: 34, height: 1.4)),
              ),
            ),
          );
        },
      )),
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
    final dotInfo = dotsDesc(context, letter.dotCount, letter.dotPos);
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
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
        children: [
          Row(children: [
            Material(
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
            const SizedBox(width: 14),
            Text(letterName(context, letter),
                style: uiStyle(context, size: 22, weight: FontWeight.w900)),
          ]),
          const SizedBox(height: 20),
          IntrinsicHeight(
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
                            style: TextStyle(
                                fontFamily: 'ScheherazadeNew',
                                fontSize: 200,
                                height: .95,
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
              style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 70,
                  height: 1,
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
    final dotInfo = dotsDesc(context, letter.dotCount, letter.dotPos);
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
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Text(letter.char,
                  style: arabicStyle(context, size: 120, height: 1.5,
                      color: pal(context).accent)),
            ),
          ),
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
                        style: arabicStyle(context, size: 38,
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
  final ScrollController _stripCtrl = ScrollController();

  @override
  void dispose() {
    _stripCtrl.dispose();
    super.dispose();
  }

  /// Desktop: the reference "Joining forms" — letter strip, the four Shapes,
  /// "In the Qur'an", and "See it in Words", plus the Forms Quiz CTA.
  Widget _desktopBuild(BuildContext context) {
    final joins = !_nonJoiners.contains(sel.char);
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
          // A horizontal strip. On desktop the mouse wheel scrolls vertically,
          // so we make this row reachable three ways: an always-visible
          // scrollbar, click-and-drag with the mouse/trackpad, and wheel-to-
          // horizontal — otherwise the letters past the right edge are stranded.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              dragDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: Scrollbar(
              controller: _stripCtrl,
              thumbVisibility: true,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && _stripCtrl.hasClients) {
                    final max = _stripCtrl.position.maxScrollExtent;
                    final target =
                        (_stripCtrl.offset + event.scrollDelta.dy)
                            .clamp(0.0, max);
                    if (target != _stripCtrl.offset) _stripCtrl.jumpTo(target);
                  }
                },
                child: SingleChildScrollView(
                  controller: _stripCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    for (final l in letters)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: TapScale(
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
                                      : pal(context)
                                          .surfaceHigh
                                          .withValues(alpha: .7)),
                            ),
                            child: Text(l.char,
                                style: TextStyle(
                                    fontFamily: 'ScheherazadeNew',
                                    fontSize: 26,
                                    height: 1.2,
                                    color: l.char == sel.char
                                        ? Colors.white
                                        : pal(context).text)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
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
                        style: TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 74,
                            height: 1,
                            color: pal(context).text)),
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
                                  style: TextStyle(
                                      fontFamily: 'ScheherazadeNew',
                                      fontSize: 76,
                                      height: 1.2,
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
              style: TextStyle(
                  fontFamily: 'ScheherazadeNew',
                  fontSize: 56,
                  height: 1.3,
                  color: pal(context).text)),
          Text(w.translit,
              style: uiStyle(context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: pal(context).textDim)),
        ],
      ),
    );
  }

  // ا و د ذ ر ز connect only on the right, so they have just two real shapes:
  // alone and joined (final). Showing four would only add stray-tatweel noise.
  static const _nonJoiners = 'اودذرز';

  /// Forms laid out right-to-left (alone on the right), wrapping wide letters
  /// like ṣād into a 2×2 grid while narrow letters stay on one row.
  /// 'beginning' | 'middle' | 'end' → the reader's language.
  String _posLabel(BuildContext context, String p) => switch (p) {
        'beginning' => context.l10n.posBeginning,
        'middle' => context.l10n.posMiddle,
        _ => context.l10n.posEnd,
      };

  Widget _formsGrid(BuildContext context, ArabicLetter l) {
    final joins = !_nonJoiners.contains(l.char);
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
      final glyphStyle = arabicStyle(context, size: 46);
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
              style: arabicStyle(context, size: 30)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final joins = !_nonJoiners.contains(sel.char);
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
                        style: arabicStyle(context,
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
                    style: arabicStyle(context, size: 26, height: 1.3)),
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

QuizScreen _letterQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  final pool = letters.map((l) => letterName(context, l)).toList();
  final sample = [...letters]..shuffle(_rng);
  for (final l in sample.take(10)) {
    final o = buildOptions(letterName(context, l), pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpWhichLetterIsThis,
        arabic: l.char,
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(
      title: context.l10n.letterQuiz, progressId: 'qaidah.letters', questions: qs);
}

QuizScreen _formsQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  final pool = letters.map((l) => letterName(context, l)).toList();
  final sample = [...letters]..shuffle(_rng);
  for (final l in sample.take(10)) {
    final form = [l.initial, l.medial, l.finalForm][_rng.nextInt(3)];
    final o = buildOptions(letterName(context, l), pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpShapeBelongsTo,
        arabic: form,
        options: o.options,
        correct: o.correct,
        explain: context.l10n.lookPastJoins));
  }
  return QuizScreen(
      title: context.l10n.formsQuiz, progressId: 'qaidah.forms', questions: qs);
}

QuizScreen _syllableQuiz(BuildContext context, String title, String progressId,
    List<(String, String, String)> marks) {
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
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(title: title, progressId: progressId, questions: qs);
}

QuizScreen _sukunQuiz(BuildContext context) {
  final qs = <QuizQuestion>[
     QuizQuestion(
        prompt: context.l10n.qpWhatDoesSukunDo,
        options: [
          context.l10n.optCutsNoVowel,
          context.l10n.optStretchesTwo,
          context.l10n.optDoublesIt,
          context.l10n.optSilentEntirely
        ],
        correct: 0),
     QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'أَبْ',
        options: ['ab', 'aba', 'ba', 'ib'],
        correct: 0),
     QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'قُلْ',
        options: ['qul', 'qal', 'qil', 'qulu'],
        correct: 0),
     QuizQuestion(
        prompt: context.l10n.qpWhichBounce,
        options: ['ق ط ب ج د', 'ا و ي', 'ء ه ع ح', 'ل ر ن م'],
        correct: 0,
        explain: context.l10n.rememberQutbuJadd),
     QuizQuestion(
        prompt: context.l10n.qpReadItBounce,
        arabic: 'لَمْ يَلِدْ',
        options: ['lam yalid', 'lam yalida', 'lama yalid', 'lim yalud'],
        correct: 0),
  ];
  return QuizScreen(
      title: context.l10n.sukunJazm, progressId: 'qaidah.sukun', questions: qs);
}

QuizScreen _shaddaQuiz(BuildContext context) {
  final qs = <QuizQuestion>[
     QuizQuestion(
        prompt: context.l10n.qpShaddahMeans,
        options: [
          context.l10n.optTwiceCutVoweled,
          context.l10n.optSilently,
          context.l10n.optWithLongStretch,
          context.l10n.optFromTheNose
        ],
        correct: 0),
     QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'رَبِّ',
        options: ['rabbi', 'rabi', 'rab', 'raabi'],
        correct: 0),
     QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'إِنَّ',
        options: ['inna', 'ina', 'anna', 'in'],
        correct: 0,
        explain: context.l10n.explNunShaddahGhunnah),
     QuizQuestion(
        prompt: context.l10n.qpReadIt,
        arabic: 'ثُمَّ',
        options: ['thumma', 'thuma', 'summa', 'thum'],
        correct: 0),
  ];
  return QuizScreen(
      title: context.l10n.shaddah, progressId: 'qaidah.shadda', questions: qs);
}

const _quranWords = <(String, String)>[
  ('بِسْمِ', 'bismi'),
  ('قُلْ', 'qul'),
  ('هُوَ', 'huwa'),
  ('أَحَدٌ', 'aḥadun'),
  ('خَلَقَ', 'khalaqa'),
  ('نَعْبُدُ', 'naʿbudu'),
  ('يَوْمِ', 'yawmi'),
  ('رَبِّ', 'rabbi'),
  ('جَاءَ', 'jā’a'),
  ('لَهَبٍ', 'lahabin'),
  ('مَالِكِ', 'māliki'),
  ('دِينِ', 'dīni'),
  ('ثُمَّ', 'thumma'),
  ('سَلَامٌ', 'salāmun'),
  ('نَصْرُ', 'naṣru'),
  ('غَيْرِ', 'ghayri'),
];

QuizScreen _wordQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  final pool = _quranWords.map((w) => w.$2).toList();
  final sample = [..._quranWords]..shuffle(_rng);
  for (final (ar, tr) in sample.take(10)) {
    final o = buildOptions(tr, pool, _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpReadQuranicWord,
        arabic: ar,
        options: o.options,
        correct: o.correct));
  }
  return QuizScreen(
      title: context.l10n.readingWords, progressId: 'qaidah.words', questions: qs);
}

QuizScreen _reviewQuiz(BuildContext context) {
  final qs = <QuizQuestion>[];
  // letters
  final ls = [...letters]..shuffle(_rng);
  for (final l in ls.take(3)) {
    final o = buildOptions(letterName(context, l),
        letters.map((x) => letterName(context, x)).toList(), _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpNameTheLetter,
        arabic: l.char,
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
        options: o.options,
        correct: o.correct,
        explain: tashkilNote(context, t)));
  }
  // words
  final ws = [..._quranWords]..shuffle(_rng);
  for (final (ar, tr) in ws.take(3)) {
    final o = buildOptions(tr, _quranWords.map((w) => w.$2).toList(), _rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpReadIt, arabic: ar, options: o.options, correct: o.correct));
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.qaidahReview, progressId: 'qaidah.review', questions: qs);
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
