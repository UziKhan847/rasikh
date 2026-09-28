import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/quran.dart';
import '../../widgets/common.dart' show starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
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
    final ui = kbUi(context);
    final rounds = _rounds;
    if (rounds == null) {
      return const KidsLoadingScreen();
    }
    if (rounds.isEmpty) {
      return KidsMessageScreen(context.l10n.kidsReadingUnavailable);
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
                  KidsLessonCard(
                    child: Text(
                      context.l10n.kidsListenOffline,
                      textAlign: TextAlign.center,
                      style: kbText(18, kbC(ui.inkSoft),
                          weight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: Geo.gapLg),
                  KidsNextButton(context.l10n.continueLabel, onTap: () => closeKidsOverlayOrPop(context)),
                ],
              ),
            )
          : KidsLessonResult(stars: _stars),
    );
  }

  Widget _question(BuildContext context, KidsHeard r) {
    final ui = kbUi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(context.l10n.kidsWhichWordHeard, fontSize: 26),
        const SizedBox(height: Geo.gapMd),
        // Hear it again — icon-only, so the accent face (UI_SPEC §1.5).
        Center(
          child: KbSurface(
            color: ui.accent,
            edge: ui.accentEdge,
            elev: KbElev.edge6,
            circle: true,
            width: 84,
            height: 84,
            alignment: Alignment.center,
            onTap: _say,
            child: KbIcon('volume_up', size: 44, color: kbC(kWhite)),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        Expanded(
          child: KidsCentered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, o) in r.options.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _optionTile(context, r, o),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Opacity(
            opacity: _picked == null ? 1 : .5,
            child: KbPill(context.l10n.kidsNextCard,
                ui: ui,
                icon: Directionality.of(context) == TextDirection.rtl
                    ? 'arrow_back'
                    : 'arrow_forward',
                onTap: _picked == null ? _skip : null),
          ),
        ),
      ],
    );
  }

  Widget _optionTile(BuildContext context, KidsHeard r, String option) {
    final ui = kbUi(context);
    final picked = _picked;
    final isRight = option == r.word;
    return KbGlyphCell(
      ui: ui,
      square: false,
      elev: KbElev.option,
      state: picked == null
          ? KbCellState.idle
          : isRight
              ? KbCellState.good
              : option == picked
                  ? KbCellState.bad
                  : KbCellState.idle,
      onTap: () => _pick(option),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Text(
          option,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: kbText(30, kbC(ui.ink),
              family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
    );
  }
}
