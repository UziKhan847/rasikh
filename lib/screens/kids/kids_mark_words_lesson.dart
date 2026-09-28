import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/quran.dart';
import '../../data/word_pool.dart';
import 'kids_find_in_ayah.dart' show kidsFindSurahs;
import 'kids_widgets.dart';

/// The tamrīn every Qāʿidah runs after its own table: real muṣḥaf words
/// carrying the mark just drilled, read one at a time, with the mark itself
/// picked out in colour and its own recording a tap away. This is the half of
/// the method the syllable drill alone never reaches — a ḥarakah, sukūn or
/// shaddah met only as an isolated syllable is met again here inside a real
/// word, which is the whole point of learning it.
///
/// Sits between [KidsSyllableDrill]'s sessions and its stage's Test (see
/// `_drillBlock`'s `extra`), never graded — like `KidsReadingScreen`, reading
/// eight words correctly is the activity, not a multiple-choice check on top
/// of it. `completeOnOpen` would be dishonest (nothing is graded, but the
/// child did do the reading), so it reports a flat 3 stars once every word
/// has been read, the same convention `KidsReadingScreen` uses.
class KidsMarkWordsLesson extends StatefulWidget {
  /// The mark ids these words may carry — [kidsWordsWithMark]'s own OR. A
  /// single mark for sukūn/shaddah; all three ḥarakāt together for that
  /// stage, since its own drill covers all three in one sitting too.
  final List<String> markIds;
  final String progressId;

  /// For tests: the corpus to draw from, and what "play" does. The defaults
  /// load [kidsFindSurahs] and stream the word's own recording — the same
  /// seam `KidsListenAndPick` uses.
  final Map<int, List<List<String>>>? corpus;
  final Future<void> Function(int surah, int ayah, int word)? play;
  final math.Random? rng;
  const KidsMarkWordsLesson({
    super.key,
    required this.markIds,
    required this.progressId,
    this.corpus,
    this.play,
    this.rng,
  });

  @override
  State<KidsMarkWordsLesson> createState() => _KidsMarkWordsLessonState();
}

class _KidsMarkWordsLessonState extends State<KidsMarkWordsLesson> {
  List<KidsMarkWord>? _words;
  int _index = 0;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final corpus =
        widget.corpus ??
        {for (final s in kidsFindSurahs) s: await QuranRepo.words(s, 'uthmani')};
    if (!mounted) return;
    final words = kidsWordsWithMark(
      corpus,
      widget.markIds,
      widget.rng ?? math.Random(),
    );
    setState(() => _words = words);
    _say();
  }

  bool get _done {
    final words = _words;
    return words != null && (words.isEmpty || _index >= words.length);
  }

  void _say() {
    final words = _words;
    if (words == null || words.isEmpty || _index >= words.length) return;
    final w = words[_index];
    final play = widget.play ?? WbwAudio.instance.playWord;
    unawaited(play(w.surah, w.ayah, w.index).catchError((Object _) {}));
  }

  void _advance() {
    setState(() => _index++);
    _say();
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    if (words == null) {
      return const KidsLoadingScreen();
    }
    if (words.isEmpty) {
      // No word in the corpus happens to carry this mark — should not occur
      // for any of the five marks this feeds, but a stage must never hang a
      // child on an empty round.
      return KidsMessageScreen(context.l10n.kidsReadingUnavailable);
    }
    if (_done && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            kidsFinishLesson(context, progressId: widget.progressId, stars: 3),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: words.length,
      done: _done,
      child: _done
          ? const KidsLessonResult(stars: 3)
          : _WordCard(
              key: ValueKey('word.$_index'),
              word: words[_index],
              onHear: _say,
              onNext: _advance,
            ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final KidsMarkWord word;
  final VoidCallback onHear;
  final VoidCallback onNext;
  const _WordCard({
    super.key,
    required this.word,
    required this.onHear,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(context.l10n.kidsPracticeWords, align: TextAlign.center, fontSize: 26),
        const SizedBox(height: Geo.gapMd),
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KidsQuranWord(word.word, highlight: word.highlight, size: 44, block: false),
                  const SizedBox(height: Geo.gapMd),
                  KidsListenButton(onTap: onHear),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsReadIt, onTap: onNext),
      ],
    );
  }
}
