import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressStore;
import '../../data/quran.dart';
import '../../widgets/common.dart' show MediaRow, starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_choice_card.dart';
import 'kids_order_card.dart';
import 'kids_widgets.dart';

/// The sūrah a child memorises first: al-Ikhlāṣ, four short āyāt — and the
/// one the path's capstone already reads.
const kidsMemoriseSurah = 112;

/// Three sittings: āyāt 1–2, āyāt 3–4, then the whole sūrah back together.
/// A child of four to six holds about eight minutes; four āyāt at once is more
/// than that, and revision is a habit, not a lesson.
const kidsMemoriseSessions = 3;

/// The āyāt a session teaches (empty for the closing revision, which teaches
/// nothing new).
List<int> kidsMemoriseAyahsOf(int session) => switch (session) {
  1 => const [1, 2],
  2 => const [3, 4],
  _ => const [],
};

/// The sitting to offer next: the first not yet done, then the revision — over
/// and over, since bringing it back together is the point.
int kidsMemoriseNextSession(ProgressStore prog) {
  for (var n = 1; n < kidsMemoriseSessions; n++) {
    if (prog.starsFor('kids.memorise.$n') == 0) return n;
  }
  return kidsMemoriseSessions;
}

/// Splits [words] into evenly-sized phrases of at most [max] words — the two
/// to four word chunks the hifz research says a young child can hold.
List<List<String>> kidsChunks(List<String> words, {int max = 3}) {
  if (words.isEmpty) return const [];
  final n = (words.length / max).ceil();
  final out = <List<String>>[];
  var start = 0;
  for (var i = 0; i < n; i++) {
    final size = ((words.length - start) / (n - i)).ceil();
    out.add(words.sublist(start, start + size));
    start += size;
  }
  return out;
}

/// How many words stay visible at each step of the vanishing cue — everything,
/// then about two thirds, then only the first word, then nothing. Steps that
/// would show the same as the one before are dropped, so a two-word āyah goes
/// 2, 1, 0 rather than repeating itself.
List<int> kidsFadeLevels(int words) {
  final raw = [words, math.max(1, (words * 0.6).floor()), 1, 0];
  final out = <int>[];
  for (final v in raw) {
    if (out.isEmpty || out.last != v) out.add(v);
  }
  return out;
}

sealed class _Step {
  const _Step();
}

class _Listen extends _Step {
  final int ayah;
  const _Listen(this.ayah);
}

class _Say extends _Step {
  final int ayah;
  const _Say(this.ayah);
}

class _Fade extends _Step {
  final int ayah;
  const _Fade(this.ayah);
}

class _OrderWords extends _Step {
  final int ayah;
  const _OrderWords(this.ayah);
}

class _Next extends _Step {
  final int from;
  const _Next(this.from);
}

class _OrderAyahs extends _Step {
  const _OrderAyahs();
}

/// **Memorise.** One sūrah, learnt the way the hifz teachers of young children
/// do it: hear an āyah in short phrases, say it back three times, say it
/// again while its words vanish a few at a time (a fading cue), then prove it
/// by putting its words back in order. A closing question — "what comes
/// next?" — is what revision is made of, and it feeds the same review queue as
/// every other check, so the Warm-up brings it back after a few days.
///
/// Everything gradable is gradable without audio: ordering words and āyāt and
/// choosing what comes next need only the text. The listening (the āyah's own
/// recitation, over the network) is there to be followed, never to be passed.
class KidsMemoriseLesson extends StatefulWidget {
  /// 1 and 2 teach two āyāt each; 3 is the revision.
  final int session;
  final String progressId;

  /// For tests: the sūrah's words, āyah by āyah. The default loads
  /// [kidsMemoriseSurah] from the bundled corpus.
  final List<List<String>>? ayahs;
  final math.Random? rng;
  const KidsMemoriseLesson({
    super.key,
    required this.session,
    required this.progressId,
    this.ayahs,
    this.rng,
  });

  @override
  State<KidsMemoriseLesson> createState() => _KidsMemoriseLessonState();
}

class _KidsMemoriseLessonState extends State<KidsMemoriseLesson> {
  List<List<String>>? _ayahs;
  List<_Step> _steps = const [];
  int _index = 0;
  int _right = 0;
  int _total = 0;
  bool _reported = false;
  late final math.Random _rng = widget.rng ?? math.Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ayahs =
        widget.ayahs ?? await QuranRepo.words(kidsMemoriseSurah, 'uthmani');
    if (!mounted) return;
    setState(() {
      _ayahs = ayahs;
      _steps = ayahs.length < 4 ? const [] : _buildSteps();
    });
  }

  List<_Step> _buildSteps() {
    final mine = kidsMemoriseAyahsOf(widget.session);
    if (mine.isEmpty) {
      return const [_Next(1), _Next(2), _Next(3), _OrderAyahs()];
    }
    return [
      for (final a in mine) ...[_Listen(a), _Say(a), _Fade(a), _OrderWords(a)],
      // The first of the pair leads into the second: that link is what a
      // child forgets first.
      _Next(mine.first),
    ];
  }

  List<String> _words(int ayah) => _ayahs![ayah - 1];
  String _text(int ayah) => _words(ayah).join(' ');

  bool get _done =>
      _ayahs != null && _steps.isNotEmpty && _index >= _steps.length;

  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_right / _total, kids: true);

  void _advance() => setState(() => _index++);

  void _graded(bool firstTry) {
    _total++;
    if (firstTry) _right++;
    _advance();
  }

  /// Files a "what comes next" in the review queue: a miss the moment it
  /// happens, a promotion only for a first-try right answer.
  void _recordNext(int from, bool correct) {
    final answer = _text(from + 1);
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.memorise.$kidsMemoriseSurah.$from',
      arabic: _text(from),
      answer: answer,
      distractors: [
        for (var a = 1; a <= 4; a++)
          if (a != from && a != from + 1) _text(a),
      ],
    );
  }

  void _answerNext(int from, bool firstTry) {
    if (firstTry) _recordNext(from, true);
    _graded(firstTry);
  }

  @override
  Widget build(BuildContext context) {
    if (_ayahs == null) {
      return const KidsLoadingScreen();
    }
    if (_steps.isEmpty) {
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
      total: _steps.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : switch (_steps[_index]) {
              _Listen(:final ayah) => _ListenCard(
                key: ValueKey('listen.$ayah'),
                ayah: ayah,
                chunks: kidsChunks(_words(ayah)),
                onNext: _advance,
              ),
              _Say(:final ayah) => _SayCard(
                key: ValueKey('say.$ayah'),
                chunks: kidsChunks(_words(ayah)),
                onNext: _advance,
              ),
              _Fade(:final ayah) => _FadeCard(
                key: ValueKey('fade.$ayah'),
                words: _words(ayah),
                onNext: _advance,
              ),
              _OrderWords(:final ayah) => KidsOrderCard(
                key: ValueKey('words.$ayah'),
                prompt: context.l10n.kidsMemOrderWords,
                items: _words(ayah),
                rng: _rng,
                size: 28,
                wide: false,
                onDone: _graded,
              ),
              _Next(:final from) => _NextCard(
                key: ValueKey('next.$from'),
                from: _text(from),
                answer: _text(from + 1),
                others: [
                  for (var a = 1; a <= 4; a++)
                    if (a != from && a != from + 1) _text(a),
                ],
                rng: _rng,
                onMiss: () => _recordNext(from, false),
                onDone: (firstTry) => _answerNext(from, firstTry),
              ),
              _OrderAyahs() => KidsOrderCard(
                key: const ValueKey('ayahs'),
                prompt: context.l10n.kidsMemOrderAyahs,
                items: [for (var a = 1; a <= 4; a++) _text(a)],
                rng: _rng,
                size: 22,
                wide: true,
                onDone: _graded,
              ),
            },
    );
  }
}

/// [chunks] as short lines of Arabic, one phrase to a line.
class _Chunks extends StatelessWidget {
  final List<List<String>> chunks;
  const _Chunks({required this.chunks});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsLessonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in chunks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                c.join(' '),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: kbText(30, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
              ),
            ),
        ],
      ),
    );
  }
}

/// The step's instruction, on the sky — the design's lesson heading.
Widget _prompt(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: Geo.gapMd),
  child: KidsLessonTitle(text, fontSize: 26),
);

Widget _primary(BuildContext context, String label, VoidCallback? onTap) =>
    KidsNextButton(label, onTap: onTap);

/// Hear the āyah and follow it. Ungraded: it cannot be, and must not be a wall.
class _ListenCard extends StatelessWidget {
  final int ayah;
  final List<List<String>> chunks;
  final VoidCallback onNext;
  const _ListenCard({
    super.key,
    required this.ayah,
    required this.chunks,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: Column(
              children: [
                _prompt(context, context.l10n.kidsMemListen),
                _Chunks(chunks: chunks),
                const SizedBox(height: Geo.gapSm),
                MediaRow(ref: '$kidsMemoriseSurah:$ayah'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        _primary(context, context.l10n.kidsNextCard, onNext),
      ],
    );
  }
}

/// Say it three times, counted on three dots.
class _SayCard extends StatefulWidget {
  final List<List<String>> chunks;
  final VoidCallback onNext;
  const _SayCard({super.key, required this.chunks, required this.onNext});

  @override
  State<_SayCard> createState() => _SayCardState();
}

class _SayCardState extends State<_SayCard> {
  static const _times = 3;
  int _said = 0;

  void _say() {
    setState(() => _said++);
    if (_said >= _times) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _prompt(context, context.l10n.kidsMemSay),
                _Chunks(chunks: widget.chunks),
              ],
            ),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _times; i++)
              // Progress dots: the accent fill on the track (UI_SPEC §2).
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kbC(i < _said ? ui.accent : ui.surface),
                  border: Border.all(color: kbC(ui.edge), width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: Geo.gapMd),
        _primary(context, context.l10n.kidsSaidIt, _say),
      ],
    );
  }
}

/// Say it again as its words vanish: everything, most, the first word, none —
/// a fading cue, the standard way to move a text from the page to the memory.
/// A "Peek" is always there, so being stuck is never a dead end.
class _FadeCard extends StatefulWidget {
  final List<String> words;
  final VoidCallback onNext;
  const _FadeCard({super.key, required this.words, required this.onNext});

  @override
  State<_FadeCard> createState() => _FadeCardState();
}

class _FadeCardState extends State<_FadeCard> {
  late final List<int> _levels = kidsFadeLevels(widget.words.length);
  int _level = 0;
  bool _peek = false;

  bool get _last => _level == _levels.length - 1;

  void _peekNow() {
    setState(() => _peek = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _peek = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final visible = _peek ? widget.words.length : _levels[_level];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            _prompt(context, context.l10n.kidsMemFade),
            KidsLessonCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                textDirection: TextDirection.rtl,
                alignment: WrapAlignment.center,
                spacing: Geo.gapSm,
                runSpacing: Geo.gapSm,
                children: [
                  for (final (i, w) in widget.words.indexed)
                    // A hidden word keeps its width, so the āyah keeps its
                    // shape and the gaps say how much is missing.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Geo.gapSm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kbC(i < visible ? ui.surface : ui.track),
                        borderRadius: BorderRadius.circular(Geo.radiusMd),
                      ),
                      child: Opacity(
                        opacity: i < visible ? 1 : 0,
                        child: Text(
                          w,
                          textDirection: TextDirection.rtl,
                          style: kbText(30, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        if (_last)
          Padding(
            padding: const EdgeInsets.only(bottom: Geo.gapMd),
            child: Center(
              child: Opacity(
                opacity: _peek ? .5 : 1,
                child: KbPill(context.l10n.kidsMemPeek,
                    ui: ui, icon: 'visibility', onTap: _peek ? null : _peekNow),
              ),
            ),
          ),
        _primary(
          context,
          _last ? context.l10n.kidsSaidIt : context.l10n.kidsMemHideMore,
          _last ? widget.onNext : () => setState(() => _level++),
        ),
      ],
    );
  }
}

/// "What comes next?": the āyah just learnt, and three to choose from. The
/// same question, asked cold a few days later by the Warm-up, is revision.
class _NextCard extends StatefulWidget {
  final String from;
  final String answer;
  final List<String> others;
  final math.Random rng;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _NextCard({
    super.key,
    required this.from,
    required this.answer,
    required this.others,
    required this.rng,
    required this.onMiss,
    required this.onDone,
  });

  @override
  State<_NextCard> createState() => _NextCardState();
}

class _NextCardState extends State<_NextCard> {
  late final List<String> _options = [widget.answer, ...widget.others]
    ..shuffle(widget.rng);

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsChoiceCard(
      prompt: context.l10n.kidsMemNext,
      display: KidsLessonCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.from,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: kbText(26, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
      options: [
        for (final o in _options)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              o,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: kbText(24, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
            ),
          ),
      ],
      correct: _options.indexOf(widget.answer),
      columns: 1,
      hint: context.l10n.kidsHintNext,
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
