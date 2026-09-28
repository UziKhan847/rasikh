import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart' show kidsLetterPath;
import '../../data/letters.dart';
import '../../data/tashkeel.dart';
import '../../widgets/common.dart' show starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_checkpoint_quiz.dart' show kidsCheckpointEvery;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// The letters a ḥarakah drill walks: the alphabet without alif, which takes
/// none of these marks (it is a madd letter, met on its own).
List<ArabicLetter> get kidsSyllableLetters => [
  for (final l in kidsLetterPath)
    if (l.char != 'ا') l,
];

/// How many sessions each mark's drill is split into.
const kidsDrillSessions = 3;

/// The `[start, end)` slice of [kidsSyllableLetters] each session covers —
/// near-equal, in order, and together exactly the whole list.
List<(int, int)> kidsDrillRanges() {
  final n = kidsSyllableLetters.length;
  return [
    for (var i = 0; i < kidsDrillSessions; i++)
      ((n * i) ~/ kidsDrillSessions, (n * (i + 1)) ~/ kidsDrillSessions),
  ];
}

/// One thing to say on a drill card: what is printed, and how it sounds in
/// Latin letters. Most marks have exactly one form (`بَ` / `ba`); sukūn and
/// shaddah — the two marks that cannot be said on a bare letter — get several.
typedef KidsForm = ({String arabic, String sound});

/// Fixed hamzah-on-alif carriers used to give sukūn and shaddah a letter to
/// lean on — every Qāʿidah's own device for "a sākin letter joins the vowel
/// before it" (`tashkeel.dart`'s own sukūn note). Only three exist because
/// only three vowels do: fatḥah, kasrah, ḍammah.
const _fathaCarrier = 'أَ'; // أَ
const _kasraCarrier = 'إِ'; // إِ
const _dammaCarrier = 'أُ'; // أُ

/// [l] with [m] the way this drill actually asks a child to say it.
///
/// A vowel or tanwīn mark still has exactly one form — the letter with the
/// mark on it, unchanged from before. **Sukūn and shaddah do not**: a sākin
/// letter has no sound of its own (it "joins the vowel before it"), and a
/// shaddah is, in every Qāʿidah, "one symbol, two letters" — first sākin,
/// then moving. Printing either alone, as this drill used to, asks for a
/// syllable that cannot be said.
///
/// Sukūn gets three forms — the sākin letter after each of the three
/// carrier vowels, since the whole point is that the letter itself stays
/// silent whichever vowel led into it. Shaddah gets six — the classical
/// "shaddah with the six ḥarakāt" table (Qāʿidah Nūrāniyyah): the three
/// short vowels and the three tanwīn, all on the SAME doubled letter, with a
/// fixed fatḥah carrier leading into it.
///
/// Code-point order matters and is verified against the bundled corpus
/// (`assets/quran/u/*.json`): a mushaddad letter is written shaddah-THEN-
/// vowel (`ذَرَّةٍ` → ر + SHADDA + FATHA), and the muṣḥaf's own sukūn glyph is
/// U+06E1 (small high rounded zero — see `tashkeel.dart`'s own `'بۡ'`), not
/// the plain Arabic sukūn U+0652.
List<KidsForm> kidsSyllableForms(ArabicLetter l, TashkilItem m) {
  switch (m.id) {
    case 'sukun':
      return [
        (arabic: '$_fathaCarrier${l.char}ۡ', sound: 'a${l.translit}'),
        (arabic: '$_kasraCarrier${l.char}ۡ', sound: 'i${l.translit}'),
        (arabic: '$_dammaCarrier${l.char}ۡ', sound: 'u${l.translit}'),
      ];
    case 'shadda':
      final doubled = '${l.translit}${l.translit}';
      return [
        (
          arabic: '$_fathaCarrier${l.char}َّ',
          sound: 'a${doubled}a',
        ),
        (
          arabic: '$_fathaCarrier${l.char}ِّ',
          sound: 'a${doubled}i',
        ),
        (
          arabic: '$_fathaCarrier${l.char}ُّ',
          sound: 'a${doubled}u',
        ),
        (
          arabic: '$_fathaCarrier${l.char}ًّ',
          sound: 'a${doubled}an',
        ),
        (
          arabic: '$_fathaCarrier${l.char}ٍّ',
          sound: 'a${doubled}in',
        ),
        (
          arabic: '$_fathaCarrier${l.char}ٌّ',
          sound: 'a${doubled}un',
        ),
      ];
    default:
      // Every other mark's [TashkilItem.sound] is spelled on a bā’ carrier,
      // so the vowel part is everything after its first character.
      return [
        (
          arabic: '${l.char}${m.mark.substring(1)}',
          sound: '${l.translit}${m.sound.substring(1)}',
        ),
      ];
  }
}

/// How [l] with [m] is said, as one Latin string — the FIRST of
/// [kidsSyllableForms], which is the whole syllable for every mark except
/// sukūn and shaddah, and that mark's canonical form for those two. Used by
/// the review queue's answer field and by anything that only needs one sound
/// to compare against, not the full drilled set.
String kidsSyllableSound(ArabicLetter l, TashkilItem m) =>
    kidsSyllableForms(l, m).first.sound;

/// One thing to do inside a [KidsSyllableDrill]: meet a syllable, or answer
/// a quick recognition check over the ones just met.
sealed class _Step {
  const _Step();
}

class _LetterStep extends _Step {
  final ArabicLetter letter;
  const _LetterStep(this.letter);
}

class _CheckStep extends _Step {
  final ArabicLetter answer;
  final List<ArabicLetter> options;
  const _CheckStep({required this.answer, required this.options});
}

/// Qāʿidah Nūrāniyyah's own drill for one mark: walked letter by letter
/// through the whole alphabet — بَ تَ ثَ جَ … — rather than a single page of
/// prose about the mark in the abstract. Alif takes none of these eight marks
/// (it is a madd letter, met on its own in the Letters stage), so it is
/// skipped here the same way `qaidah_screen.dart`'s own `_syllableQuiz`
/// already does.
///
/// A short recognition check-up is woven in every five letters — the same
/// cumulative-checkup rhythm the Letters and Joining Shapes stages use
/// (`kidsCheckpointEvery`) — rather than one long unbroken walk.
///
/// The whole alphabet in one sitting is ~32 steps, which is well past what a
/// 4–6 year old sustains (roughly 8–10 minutes; the leading kids' apps aim
/// for 3–5). The path therefore opens each mark as [kidsDrillSessions]
/// shorter sessions, each a [start]..[end] slice of the letters; the default
/// (no slice) is still the whole alphabet. Check-up distractors are always
/// drawn from the WHOLE alphabet, since every letter is already known by the
/// time this stage is reached, not just this session's slice.
class KidsSyllableDrill extends StatefulWidget {
  final TashkilItem mark;
  final String progressId;

  /// The slice of the alif-less alphabet this session covers.
  final int start;
  final int? end;
  const KidsSyllableDrill({
    super.key,
    required this.mark,
    required this.progressId,
    this.start = 0,
    this.end,
  });

  @override
  State<KidsSyllableDrill> createState() => _KidsSyllableDrillState();
}

class _KidsSyllableDrillState extends State<KidsSyllableDrill> {
  late final List<ArabicLetter> _all = kidsSyllableLetters;
  late final List<ArabicLetter> _letters = _all.sublist(
    widget.start,
    widget.end ?? _all.length,
  );
  late final List<_Step> _steps = _buildSteps();

  int _index = 0;
  int _correct = 0;
  int _total = 0;

  List<_Step> _buildSteps() {
    final out = <_Step>[];
    for (var i = 0; i < _letters.length; i++) {
      out.add(_LetterStep(_letters[i]));
      final done = i + 1;
      if (done % kidsCheckpointEvery == 0 && done != _letters.length) {
        final pool = _letters.sublist(
          math.max(0, done - kidsCheckpointEvery),
          done,
        );
        final answer = pool[_rng.nextInt(pool.length)];
        final rest = [..._all]..shuffle(_rng);
        final options = <ArabicLetter>[answer];
        for (final l in rest) {
          if (options.length >= 4) break;
          if (l != answer) options.add(l);
        }
        options.shuffle(_rng);
        out.add(_CheckStep(answer: answer, options: options));
      }
    }
    return out;
  }

  bool get _done => _index >= _steps.length;

  /// A drill with no checkpoints at all (a mark with fewer than five letters
  /// — none today, but nothing here assumes eight) has nothing to grade
  /// itself on, so it earns a perfect mark for having been walked at all.
  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_correct / _total, kids: true);

  bool _reported = false;

  void _advance() => setState(() => _index++);

  /// Files the check in the review queue: a miss the moment it happens, a
  /// promotion only for a first-try right answer.
  void _recordCheck(
    bool correct,
    ArabicLetter answer,
    List<ArabicLetter> options,
  ) {
    final form = kidsSyllableForms(answer, widget.mark).first;
    // The Warm-up card asks "how does this sound?", so what it stores is the
    // syllable and its SOUND — storing the syllable as its own answer would
    // put the answer on the card's face.
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.syllable.${widget.mark.id}.${answer.char}',
      arabic: form.arabic,
      answer: form.sound,
      distractors: [
        for (final o in options)
          if (o != answer) kidsSyllableForms(o, widget.mark).first.sound,
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry,
    ArabicLetter answer,
    List<ArabicLetter> options,
  ) {
    _total++;
    if (firstTry) {
      _correct++;
      _recordCheck(true, answer, options);
    }
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    if (_done && !_reported) {
      // Reported exactly once, after this build commits — not from inside
      // build() itself, which must stay free of side effects.
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _stars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: _steps.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : switch (_steps[_index]) {
              _LetterStep(:final letter) => _SyllableStep(
                key: ValueKey('letter.${letter.char}'),
                letter: letter,
                mark: widget.mark,
                onNext: _advance,
              ),
              _CheckStep(:final answer, :final options) => _CheckWidget(
                key: ValueKey('check.${answer.char}'),
                answer: answer,
                options: options,
                mark: widget.mark,
                onMiss: () => _recordCheck(false, answer, options),
                onDone: (firstTry) => _answerCheck(firstTry, answer, options),
              ),
            },
    );
  }
}

/// One letter's turn: its form(s), a way to hear each; "I said it" to move
/// on — the same reinforcement shape `KidsLetterFlow`'s say-it-aloud step
/// uses, just once per letter here rather than five times on one letter,
/// since walking the whole alphabet IS the repetition.
///
/// A vowel or tanwīn mark shows the one big card this always showed. Sukūn
/// and shaddah — which have several forms — show all of them at once, each
/// its own small tappable card, so a child sees the whole table
/// (`kidsSyllableForms`) for this letter in one place rather than one form
/// at a time.
class _SyllableStep extends StatelessWidget {
  final ArabicLetter letter;
  final TashkilItem mark;
  final VoidCallback onNext;
  const _SyllableStep({
    super.key,
    required this.letter,
    required this.mark,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final forms = kidsSyllableForms(letter, mark);
    final single = forms.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: single
                ? _FormTile(form: forms.single, side: 180, fontSize: 90)
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Geo.gapSm,
                    runSpacing: Geo.gapSm,
                    children: [
                      for (final f in forms)
                        _FormTile(form: f, side: 92, fontSize: 34),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        // The letter's name and the hint are one line each, on the sky.
        Center(
          child: KbSubtitle(letterName(context, letter), ui: ui, fontSize: 24),
        ),
        if (single) ...[
          const SizedBox(height: Geo.gapMd),
          Center(
            child: KidsListenButton(
              onTap: () =>
                  LetterAudio.playOrComingSoonRaw(context, forms.single.arabic),
            ),
          ),
        ] else ...[
          const SizedBox(height: Geo.gapSm),
          Center(
            child: KbSubtitle(context.l10n.kidsTapEachToHear,
                ui: ui, fontSize: 17, align: TextAlign.center),
          ),
        ],
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(
          context.l10n.kidsSaidIt,
          onTap: () {
            // Ambient reinforcement, same as every other "I said it" tap in
            // Kids Mode — quiet on a missing clip, no coming-soon toast. A
            // multi-form letter has no single syllable to play here; each
            // form already played itself when tapped.
            if (single) LetterAudio.playRaw(forms.single.arabic);
            onNext();
          },
        ),
      ],
    );
  }
}

/// One form, shown and tap-to-hear.
class _FormTile extends StatelessWidget {
  final KidsForm form;
  final double side;
  final double fontSize;
  const _FormTile({
    required this.form,
    required this.side,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    // A tap-to-hear glyph cell at the design's lesson-card size
    // (`KbElev.big`, radius 28 for the big single form).
    return SizedBox(
      width: side,
      height: side,
      child: KbGlyphCell(
        ui: ui,
        glyph: form.arabic,
        family: kbFontQuran,
        weight: FontWeight.w400,
        fontSize: fontSize,
        elev: KbElev.big,
        radius: side > 120 ? 28 : 20,
        onTap: () => LetterAudio.playOrComingSoonRaw(context, form.arabic),
      ),
    );
  }
}

/// The check-up: which syllable did you just practise? Four glyph options,
/// one correct, drawn only from the five letters just covered — never the
/// whole alphabet, which would make an unmet letter a "distractor" that is
/// really just noise. Tests the mark's FIRST (canonical) form — the same one
/// [kidsSyllableSound] answers with.
class _CheckWidget extends StatefulWidget {
  final ArabicLetter answer;
  final List<ArabicLetter> options;
  final TashkilItem mark;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _CheckWidget({
    super.key,
    required this.answer,
    required this.options,
    required this.mark,
    required this.onMiss,
    required this.onDone,
  });

  @override
  State<_CheckWidget> createState() => _CheckWidgetState();
}

class _CheckWidgetState extends State<_CheckWidget> {
  late final String _answerArabic =
      kidsSyllableForms(widget.answer, widget.mark).first.arabic;

  @override
  void initState() {
    super.initState();
    LetterAudio.playRaw(_answerArabic);
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsChoiceCard(
      prompt: context.l10n.kidsWhichDidYouSay,
      display: Center(
        child: KidsListenButton(
          onTap: () => LetterAudio.playOrComingSoonRaw(context, _answerArabic),
        ),
      ),
      options: [
        for (final l in widget.options)
          Text(
            kidsSyllableForms(l, widget.mark).first.arabic,
            textDirection: TextDirection.rtl,
            style: kbText(40, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
      ],
      correct: widget.options.indexOf(widget.answer),
      aspect: 1.4,
      hint: context.l10n.kidsHintSyllable,
      settle: const Duration(milliseconds: 700),
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
