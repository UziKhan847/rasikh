import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressScope;
import '../../data/glyph_names.dart' show letterName;
import '../../data/letters.dart';
import '../../data/quran.dart';
import '../../widgets/common.dart' show starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_find_in_ayah.dart' show kidsBaseLetters, kidsFindSurahs;
import 'kids_lookalike_quiz.dart' show kidsConfusablesIn;
import 'kids_order_card.dart';
import 'kids_widgets.dart';

/// How many words make a round.
const kidsBuildRound = 4;

/// One word to build: the word, its letters in reading order, and letters
/// that are not in it.
class KidsWordBuild {
  final String word;
  final List<String> letters;
  final List<String> decoys;
  const KidsWordBuild(this.word, this.letters, this.decoys);
}

/// Up to [count] words from [lines] that a child who knows [known] can build:
/// three to five letters, every one of them known. Each comes with up to two
/// decoys — look-alikes of its own letters where there are any, so the tiles
/// on offer are the honest mistakes — never a letter the word already has.
List<KidsWordBuild> kidsBuildWords(
  List<ArabicLetter> known,
  List<List<String>> lines,
  math.Random rng, {
  int count = kidsBuildRound,
}) {
  final chars = {for (final l in known) l.char};
  final seen = <String>{};
  final fits = <(String, List<String>)>[];
  for (final line in lines) {
    for (final w in line) {
      final ls = kidsBaseLetters(w);
      if (ls.length < 3 || ls.length > 5) continue;
      if (!ls.every(chars.contains) || !seen.add(w)) continue;
      fits.add((w, ls));
    }
  }
  fits.shuffle(rng);
  final out = <KidsWordBuild>[];
  for (final (w, ls) in fits.take(count)) {
    final inWord = ls.toSet();
    final near = <String>[];
    for (final c in ls.toSet()) {
      near.addAll(kidsConfusablesIn(letterFor(c), known).map((l) => l.char));
    }
    final pool = {...near}.where((c) => !inWord.contains(c)).toList()
      ..shuffle(rng);
    if (pool.length < 2) {
      // Too few look-alikes: top up with any other known letter.
      final rest = [
        for (final k in chars)
          if (!inWord.contains(k) && !pool.contains(k)) k,
      ]..shuffle(rng);
      pool.addAll(rest);
    }
    out.add(KidsWordBuild(w, ls, pool.take(2).toList()));
  }
  return out;
}

/// **Build the word.** A real word of the muṣḥaf, joined, is shown; the child
/// builds it from separate letters, tapping them in reading order — right to
/// left — with a look-alike or two among the tiles. Everywhere else a letter is
/// shown alone; here it is taken back out of a connected word, which is what
/// reading is, and the letters snap together into the word when it is done.
///
/// Feeds the review queue under `letter.<char>`: a wrong tap files a miss for
/// the letter that was wanted.
class KidsBuildWord extends StatefulWidget {
  final List<ArabicLetter> known;
  final String progressId;
  final math.Random? rng;

  /// Lines to draw words from, for tests; null loads [kidsFindSurahs].
  final List<List<String>>? lines;
  const KidsBuildWord({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
    this.lines,
  });

  @override
  State<KidsBuildWord> createState() => _KidsBuildWordState();
}

class _KidsBuildWordState extends State<KidsBuildWord> {
  List<KidsWordBuild>? _words;
  int _index = 0;
  int _right = 0;
  bool _reported = false;
  late final math.Random _rng = widget.rng ?? math.Random();

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
    setState(() => _words = kidsBuildWords(widget.known, lines, _rng));
  }

  bool get _done => _words != null && _index >= _words!.length;

  int get _stars => _words!.isEmpty
      ? 0
      : starsForFraction(_right / _words!.length, kids: true);

  void _wrong(String tapped, String expected) {
    final wanted = letterFor(expected);
    ProgressScope.of(context).recordMiss(
      'letter.$expected',
      expected,
      answer: letterName(context, wanted),
      distractors: [
        for (final l in kidsConfusablesIn(wanted, widget.known))
          letterName(context, l),
      ].take(3).toList(),
    );
  }

  void _next(bool firstTry) => setState(() {
    if (firstTry) _right++;
    _index++;
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final words = _words;
    if (words == null) {
      return const KidsLoadingScreen();
    }
    if (words.isEmpty) {
      return KidsMessageScreen(context.l10n.kidsReadingUnavailable);
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
      total: words.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : () {
              final w = words[_index];
              return KidsOrderCard(
                key: ValueKey('build.$_index.${w.word}'),
                prompt: context.l10n.kidsBuildThis,
                header: KidsLessonCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    w.word,
                    textDirection: TextDirection.rtl,
                    style: kbText(44, kbC(ui.linkInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                  ),
                ),
                items: w.letters,
                decoys: w.decoys,
                joined: w.word,
                rng: _rng,
                size: 36,
                wide: false,
                onWrong: _wrong,
                onDone: _next,
              );
            }(),
    );
  }
}
