import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressScope;
import '../../data/glyph_names.dart' show letterName;
import '../../data/letters.dart';
import '../../data/strokes.dart' show glyphFor;
import '../../widgets/common.dart' show pickN, starsForFraction;
import '../tracing_screen.dart' show TracingBoard;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_widgets.dart';

/// How many letters one "Write it" round asks for — five is a check-up's
/// worth (`kidsCheckpointEvery`) and, at a blank board apiece, a few minutes.
const kidsWriteRound = 5;

/// **Write it from memory.** The letter's NAME is shown — never its shape —
/// and the child draws it on a blank board. Recognising a letter when it is
/// in front of you and producing it from nothing are different skills, and
/// producing is the stronger test of whether a shape is really known;
/// everything else in Kids Mode asks the easier question.
///
/// Uses the Tracing Studio's own `memory` mode, which was already shipped and
/// grades stroke shape, order, pen direction and dot placement, but which
/// Kids Mode had never used. After Check the board draws the true shape
/// alongside, so a wrong attempt still teaches. No audio is involved.
///
/// Each result feeds the same spaced-repetition queue as every other check
/// (`letter.<char>`, the id the checkpoints already use): a poor attempt
/// files a miss so the letter resurfaces in the Warm-up, a good one promotes
/// an existing card.
class KidsWriteFromMemory extends StatefulWidget {
  final List<ArabicLetter> letters;
  final String progressId;
  const KidsWriteFromMemory({
    super.key,
    required this.letters,
    required this.progressId,
  });

  /// A round over [known], [kidsWriteRound] letters at most.
  static KidsWriteFromMemory forKnown(
    List<ArabicLetter> known, {
    required String progressId,
    math.Random? rng,
  }) => KidsWriteFromMemory(
    letters: pickN(
      known,
      math.min(kidsWriteRound, known.length),
      rng ?? math.Random(),
    ),
    progressId: progressId,
  );

  @override
  State<KidsWriteFromMemory> createState() => _KidsWriteFromMemoryState();
}

class _KidsWriteFromMemoryState extends State<KidsWriteFromMemory> {
  int _index = 0;
  final List<int> _stars = [];

  /// The current letter's result once its board has been checked; null until.
  int? _last;
  bool _reported = false;

  bool get _done => _index >= widget.letters.length;

  int get _roundStars => _stars.isEmpty
      ? 3
      : starsForFraction(
          _stars.fold<int>(0, (a, b) => a + b) / (3 * _stars.length),
          kids: true,
        );

  void _onChecked(ArabicLetter l, int stars) {
    if (_last != null) return;
    final prog = ProgressScope.of(context);
    // 2+ stars is a letter genuinely written from memory. Anything less is
    // filed to come back, with the letter's own look-alikes as the options.
    final ok = stars >= 2;
    final names = letterName(context, l);
    if (ok) {
      prog.reviewCorrect('letter.${l.char}');
    } else {
      prog.recordMiss(
        'letter.${l.char}',
        l.char,
        answer: names,
        distractors: [
          for (final o in letters)
            if (o != l) letterName(context, o),
        ].take(3).toList(),
      );
    }
    setState(() {
      _last = stars;
      _stars.add(stars);
    });
  }

  void _next() => setState(() {
    _index++;
    _last = null;
  });

  @override
  Widget build(BuildContext context) {
    if (_done && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _roundStars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: widget.letters.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _roundStars)
          : _WriteStep(
              key: ValueKey('write.${widget.letters[_index].char}'),
              letter: widget.letters[_index],
              last: _last,
              onChecked: (s) => _onChecked(widget.letters[_index], s),
              onNext: _next,
            ),
    );
  }
}

class _WriteStep extends StatelessWidget {
  final ArabicLetter letter;
  final int? last;
  final void Function(int stars) onChecked;
  final VoidCallback onNext;
  const _WriteStep({
    super.key,
    required this.letter,
    required this.last,
    required this.onChecked,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(context.l10n.kidsWriteFromMemory(letterName(context, letter)), fontSize: 26),
        const SizedBox(height: Geo.gapSm),
        Expanded(
          child: TracingBoard(
            glyph: glyphFor(letter.char, 'iso'),
            mode: 'memory',
            // Kids Mode shows its own result below; the board's overlay is
            // the grown-up "Perfect trace / Try again" card.
            showOverlay: false,
            onStars: onChecked,
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: Geo.gapSm),
          // The stars, on a small surface capsule — icons on the sky would
          // not read on every scene.
          Center(
            child: Builder(builder: (context) {
              final ui = kbUi(context);
              final n = last == 0 ? 1 : last!;
              return KbSurface(
                color: ui.surface,
                edge: ui.edge,
                elev: KbElev.edge4,
                radius: 999,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 3; i++)
                    KbIcon(i < n ? 'star' : 'star_outline',
                        size: 30, color: kbC(i < n ? ui.reward : ui.inkSoft)),
                ]),
              );
            }),
          ),
          const SizedBox(height: Geo.gapSm),
          KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
        ],
      ],
    );
  }
}
