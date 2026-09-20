import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/quran.dart';
import '../../widgets/common.dart' show TapScale, starsForFraction;
import 'kids_desktop_nav.dart' show closeKidsOverlayOrPop;
import 'kids_find_in_ayah.dart' show kidsBaseLetters, kidsFindSurahs;
import 'kids_widgets.dart';

/// How many words make a round.
const kidsListenRound = 6;

/// One word to hear, where to find its recording, and the written words to
/// pick it from.
class KidsHeard {
  final int surah;

  /// 1-based, aligned with the per-word recordings' own numbering.
  final int ayah;
  final int index;
  final String word;

  /// The written choices, shuffled, [word] among them.
  final List<String> options;
  const KidsHeard({
    required this.surah,
    required this.ayah,
    required this.index,
    required this.word,
    required this.options,
  });
}

/// Builds up to [count] rounds from [corpus] (surah → āyahs → words).
///
/// A word must have two to six letters, so it is neither a single syllable
/// nor a whole clause. Words made only of [known] letters come first — a
/// child cannot pick a word out by its letters if half of them are ones they
/// have not met — falling back to the whole corpus only when there are too
/// few. Distractors are other words of a similar length, never the same word.
List<KidsHeard> kidsBuildHeard(
  Map<int, List<List<String>>> corpus,
  Set<String> known,
  math.Random rng, {
  int count = kidsListenRound,
}) {
  final all = <(int, int, int, String)>[];
  final seen = <String>{};
  for (final e in corpus.entries) {
    for (var a = 0; a < e.value.length; a++) {
      for (var w = 0; w < e.value[a].length; w++) {
        final word = e.value[a][w];
        final n = kidsBaseLetters(word).length;
        if (n < 2 || n > 6 || !seen.add(word)) continue;
        all.add((e.key, a + 1, w + 1, word));
      }
    }
  }
  bool easy((int, int, int, String) c) =>
      kidsBaseLetters(c.$4).every(known.contains);
  final easyOnes = [
    for (final c in all)
      if (easy(c)) c,
  ]..shuffle(rng);
  final rest = [
    for (final c in all)
      if (!easy(c)) c,
  ]..shuffle(rng);
  final targets = [...easyOnes, ...rest].take(count);
  final out = <KidsHeard>[];
  for (final t in targets) {
    final len = kidsBaseLetters(t.$4).length;
    final near = [
      for (final c in all)
        if (c.$4 != t.$4 && (kidsBaseLetters(c.$4).length - len).abs() <= 1) c,
    ]..shuffle(rng);
    // Prefer the easy ones here too, so the wrong options are readable.
    near.sort((a, b) => (easy(b) ? 1 : 0).compareTo(easy(a) ? 1 : 0));
    if (near.length < 2) continue;
    final options = [t.$4, near[0].$4, near[1].$4]..shuffle(rng);
    out.add(
      KidsHeard(
        surah: t.$1,
        ayah: t.$2,
        index: t.$3,
        word: t.$4,
        options: options,
      ),
    );
  }
  return out;
}

/// **Listen & pick.** A real word of the Qurʼān is played and the child picks
/// it from three written words. It is the one sound → symbol activity that
/// works today with no letter recordings of our own: the per-word
/// recitations already stream (and cache) for the reader, so a child hears a
/// word said properly and has to find how it is written.
///
/// It needs a connection, so a question can always be passed over — a child
/// must never be stuck on a question the device cannot ask — and a round in
/// which nothing could be graded earns nothing, rather than a free star.
///
/// Not fed to the review queue: a card there needs a text answer, and the
/// honest answer here is a sound.
class KidsListenAndPick extends StatefulWidget {
  final Set<String> known;
  final String progressId;
  final math.Random? rng;

  /// For tests: the corpus to draw from, and what "play" does. The defaults
  /// load [kidsFindSurahs] and stream the word's own recording.
  final Map<int, List<List<String>>>? corpus;
  final Future<void> Function(int surah, int ayah, int word)? play;
  const KidsListenAndPick({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
    this.corpus,
    this.play,
  });

  @override
  State<KidsListenAndPick> createState() => _KidsListenAndPickState();
}

class _KidsListenAndPickState extends State<KidsListenAndPick> {
  List<KidsHeard>? _rounds;
  int _index = 0;
  int _right = 0;
  int _wrong = 0;
  String? _picked;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final corpus =
        widget.corpus ??
        {
          for (final s in kidsFindSurahs)
            s: await QuranRepo.words(s, 'uthmani'),
        };
    if (!mounted) return;
    setState(() {
      _rounds = kidsBuildHeard(
        corpus,
        widget.known,
        widget.rng ?? math.Random(),
      );
    });
    _say();
  }

  bool get _done => _rounds != null && _index >= _rounds!.length;

  int get _graded => _right + _wrong;

  int get _stars =>
      starsForFraction(_graded == 0 ? 0 : _right / _graded, kids: true);

  KidsHeard get _round => _rounds![_index];

  /// Plays the current word. A failure (offline, no plugin) is silent: the
  /// child's way out is the Next button, not an error.
  void _say() {
    final rounds = _rounds;
    if (rounds == null || _done) return;
    final r = rounds[_index];
    final play = widget.play ?? WbwAudio.instance.playWord;
    unawaited(play(r.surah, r.ayah, r.index).catchError((Object _) {}));
  }

  void _advance() {
    setState(() {
      _index++;
      _picked = null;
    });
    _say();
  }

  void _pick(String option) {
    if (_picked != null) return;
    final ok = option == _round.word;
    setState(() {
      _picked = option;
      ok ? _right++ : _wrong++;
    });
    Future.delayed(Duration(milliseconds: ok ? 650 : 1100), () {
      if (mounted) _advance();
    });
  }

  /// Past a question without grading it: neither right nor wrong.
  void _skip() {
    if (_picked == null) _advance();
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final rounds = _rounds;
    if (rounds == null) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }
    if (rounds.isEmpty) {
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
    if (_done && _graded > 0 && !_reported) {
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
      total: rounds.length,
      done: _done,
      child: !_done
          ? _question(context, _round)
          : _graded == 0
          ? Padding(
              padding: const EdgeInsets.all(Geo.gapXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.kidsListenOffline,
                    textAlign: TextAlign.center,
                    style: kidsStyle(context, size: 15, color: p.textDim),
                  ),
                  const SizedBox(height: Geo.gapLg),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => closeKidsOverlayOrPop(context),
                    child: Text(context.l10n.continueLabel),
                  ),
                ],
              ),
            )
          : KidsLessonResult(stars: _stars),
    );
  }

  Widget _question(BuildContext context, KidsHeard r) {
    final p = kidsPal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.kidsWhichWordHeard,
          style: kidsStyle(context, size: 17, weight: FontWeight.w800),
        ),
        const SizedBox(height: Geo.gapMd),
        Center(
          child: TapScale(
            onTap: _say,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: p.accent2,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in r.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Geo.gapSm),
                    child: _optionTile(context, r, o),
                  ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: _picked == null ? _skip : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(context.l10n.kidsNextCard),
          ),
        ),
      ],
    );
  }

  Widget _optionTile(BuildContext context, KidsHeard r, String option) {
    final p = kidsPal(context);
    final picked = _picked;
    final isRight = option == r.word;
    final color = picked == null
        ? p.surface
        : isRight
        ? AppColors.ok.withValues(alpha: .18)
        : option == picked
        ? AppColors.bad.withValues(alpha: .16)
        : p.surface;
    return TapScale(
      onTap: () => _pick(option),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Geo.radiusLg),
          border: Border.all(
            color: picked != null && isRight
                ? AppColors.ok
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          option,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: quranicStyle(context, size: 30),
        ),
      ),
    );
  }
}
