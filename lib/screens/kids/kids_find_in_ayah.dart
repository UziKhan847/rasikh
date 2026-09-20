import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressScope;
import '../../core/theme.dart';
import '../../data/glyph_names.dart' show letterName;
import '../../data/letters.dart';
import '../../data/quran.dart';
import '../../widgets/common.dart' show TapScale, starsForFraction;
import 'kids_widgets.dart';

/// Short sūrahs a child already meets in the reading stages, in the order
/// they are most familiar. Lines here are short and are real muṣḥaf text.
const kidsFindSurahs = [1, 112, 108, 103, 110, 109, 105, 106, 107, 111, 113, 114];

/// How many hunts (one letter, one line) make a round.
const kidsFindRound = 3;

/// Arabic combining marks: ḥarakāt, shaddah, sukūn, dagger alif, and the small
/// high signs the muṣḥaf uses. Same ranges as `QuranRepo`'s own annotation test.
final _marks = RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]');

/// The base letters of [word] — its letters with every mark stripped, and
/// alif waṣla (ٱ) counted as the alif a child sees in it.
List<String> kidsBaseLetters(String word) => [
  for (final r in word.runes)
    if (!_marks.hasMatch(String.fromCharCode(r)) &&
        !const {0x200C, 0x200D, 0x0640}.contains(r))
      String.fromCharCode(r) == 'ٱ' ? 'ا' : String.fromCharCode(r),
];

/// Whether [word] contains [letter] as one of its base letters.
bool kidsWordHas(String word, String letter) =>
    kidsBaseLetters(word).contains(letter);

/// One line to hunt through and the letter to hunt for.
class KidsHunt {
  final ArabicLetter letter;
  final List<String> words;
  const KidsHunt(this.letter, this.words);

  /// Indices of the words that contain the letter.
  Set<int> get targets => {
    for (var i = 0; i < words.length; i++)
      if (kidsWordHas(words[i], letter.char)) i,
  };
}

/// Builds up to [count] hunts over [known] letters from [lines] (each a real
/// āyah as its words). A hunt needs some words with the letter AND some
/// without, or there is nothing to reject and nothing to find.
List<KidsHunt> kidsBuildHunts(
  List<ArabicLetter> known,
  List<List<String>> lines,
  math.Random rng, {
  int count = kidsFindRound,
}) {
  final order = [...known]..shuffle(rng);
  final out = <KidsHunt>[];
  for (final l in order) {
    if (out.length >= count) break;
    final fits = [
      for (final w in lines)
        if (w.length >= 3 && w.length <= 8)
          if (() {
            final n = w.where((x) => kidsWordHas(x, l.char)).length;
            return n >= 1 && n <= 3 && w.length - n >= 2;
          }())
            w,
    ];
    if (fits.isEmpty) continue;
    out.add(KidsHunt(l, fits[rng.nextInt(fits.length)]));
  }
  return out;
}

/// **Find it in the āyah.** "Tap every word with Bāʼ", over a real line of the
/// muṣḥaf. Everywhere else in Kids Mode a letter is shown alone, big, in its
/// isolated shape; a reader meets it inside connected words, in a different
/// shape, next to other letters — so being able to pick it out THERE is the
/// skill that transfers to reading, and the one nothing else here practises.
///
/// The child taps WORDS, not letters inside them: one letter of a connected
/// word is a very small target for a small finger, and pulling letters apart
/// would break the joining that is the whole point. Once a word is found the
/// letter lights up inside it, so the child sees where it was.
///
/// Feeds the shared review queue under `letter.<char>` like every other check:
/// a tap on a word that does NOT contain the letter files a miss for it.
class KidsFindInAyah extends StatefulWidget {
  final List<ArabicLetter> known;
  final String progressId;
  final math.Random? rng;

  /// Lines to hunt through, for tests; null loads [kidsFindSurahs].
  final List<List<String>>? lines;
  const KidsFindInAyah({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
    this.lines,
  });

  @override
  State<KidsFindInAyah> createState() => _KidsFindInAyahState();
}

class _KidsFindInAyahState extends State<KidsFindInAyah> {
  List<KidsHunt>? _hunts;
  int _index = 0;
  final Set<int> _found = {};
  final Set<int> _flashWrong = {};
  int _right = 0;
  int _wrong = 0;
  bool _missedThisHunt = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lines =
        widget.lines ??
        [
          for (final s in kidsFindSurahs)
            ...await QuranRepo.words(s, 'uthmani'),
        ];
    if (!mounted) return;
    setState(
      () => _hunts = kidsBuildHunts(
        widget.known,
        lines,
        widget.rng ?? math.Random(),
      ),
    );
  }

  bool get _done => _hunts != null && _index >= _hunts!.length;

  int get _stars => _right + _wrong == 0
      ? 3
      : starsForFraction(_right / (_right + _wrong), kids: true);

  KidsHunt get _hunt => _hunts![_index];

  bool get _huntComplete => _found.length == _hunt.targets.length;

  void _tap(int i) {
    if (_huntComplete || _found.contains(i)) return;
    final prog = ProgressScope.of(context);
    final h = _hunt;
    if (h.targets.contains(i)) {
      setState(() {
        _found.add(i);
        _right++;
      });
      if (_huntComplete && !_missedThisHunt) {
        prog.reviewCorrect('letter.${h.letter.char}');
      }
    } else {
      _missedThisHunt = true;
      _wrong++;
      prog.recordMiss(
        'letter.${h.letter.char}',
        h.letter.char,
        answer: letterName(context, h.letter),
        distractors: [
          for (final o in widget.known)
            if (o != h.letter) letterName(context, o),
        ].take(3).toList(),
      );
      setState(() => _flashWrong.add(i));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _flashWrong.remove(i));
      });
    }
  }

  void _next() => setState(() {
    _index++;
    _found.clear();
    _flashWrong.clear();
    _missedThisHunt = false;
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final hunts = _hunts;
    if (hunts == null) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }
    if (hunts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Geo.gapXl),
        child: Center(
          child: Text(
            context.l10n.kidsReadingUnavailable,
            textAlign: TextAlign.center,
            style: kidsStyle(context, size: 15, color: p.textDim),
          ),
        ),
      );
    }
    if (_done && !_reported) {
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
      total: hunts.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : _huntView(context, _hunt),
    );
  }

  Widget _huntView(BuildContext context, KidsHunt h) {
    final p = kidsPal(context);
    final complete = _huntComplete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.kidsFindEvery(letterName(context, h.letter)),
          style: kidsStyle(context, size: 17, weight: FontWeight.w800),
        ),
        const SizedBox(height: Geo.gapMd),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: Geo.gapSm,
              runSpacing: Geo.gapSm,
              children: [
                for (var i = 0; i < h.words.length; i++)
                  TapScale(
                    onTap: () => _tap(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Geo.gapMd,
                        vertical: Geo.gapSm,
                      ),
                      decoration: BoxDecoration(
                        color: _found.contains(i)
                            ? AppColors.ok.withValues(alpha: .18)
                            : _flashWrong.contains(i)
                            ? AppColors.bad.withValues(alpha: .16)
                            : p.surface,
                        borderRadius: BorderRadius.circular(Geo.radiusLg),
                        border: Border.all(
                          color: _found.contains(i)
                              ? AppColors.ok
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _WordText(
                        word: h.words[i],
                        letter: h.letter.char,
                        // The letter lights up only once its word is found —
                        // before that it is the child's job to spot it.
                        reveal: _found.contains(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (complete) ...[
          const SizedBox(height: Geo.gapMd),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _next,
            child: Text(context.l10n.kidsNextCard),
          ),
        ],
      ],
    );
  }
}

/// [word] with its [letter] coloured when [reveal] — as spans of ONE
/// paragraph, not separate widgets, so the word still joins and shapes as a
/// word (Flutter shapes across spans that differ only in colour).
class _WordText extends StatelessWidget {
  final String word;
  final String letter;
  final bool reveal;
  const _WordText({
    required this.word,
    required this.letter,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final base = quranicStyle(context, size: 30);
    if (!reveal) {
      return Text(word, textDirection: TextDirection.rtl, style: base);
    }
    final spans = <TextSpan>[];
    var i = 0;
    final runes = word.runes.toList();
    while (i < runes.length) {
      // A letter together with the marks that follow it.
      final start = i++;
      while (i < runes.length &&
          _marks.hasMatch(String.fromCharCode(runes[i]))) {
        i++;
      }
      final cluster = String.fromCharCodes(runes.sublist(start, i));
      final baseCh = String.fromCharCode(runes[start]);
      final match = (baseCh == 'ٱ' ? 'ا' : baseCh) == letter;
      spans.add(
        TextSpan(
          text: cluster,
          style: match ? base.copyWith(color: p.accent) : base,
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.rtl,
    );
  }
}
