import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show letterName;
import '../../data/letters.dart';
import '../../widgets/common.dart' show starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_board.dart';
import 'kids_lookalike_quiz.dart' show kidsConfusableOptions;
import 'kids_widgets.dart';

/// Tic-tac-toe against a simple computer — reading practice with a real game
/// on top of it, not tapping-with-reward-animations. Nine squares, each
/// showing a letter the child already knows; tapping an empty one on the
/// child's turn asks "which letter is this?" and only a right answer claims
/// it as an X. A wrong answer hands the turn to the computer without
/// claiming anything — the honest cost of a miss in this game, the same way
/// a miss anywhere else in Kids Mode costs the step's first-try mark rather
/// than undoing progress.
///
/// The computer plays a plain random empty square — this is retrieval
/// practice wearing a game's clothes, not a chess engine, and a hard-to-beat
/// opponent would just make a wrong answer feel worse.
class KidsThreeInARow extends StatefulWidget {
  final List<ArabicLetter> known;
  final String progressId;
  final math.Random? rng;

  /// For tests: skips the real `showDialog` machinery and answers every
  /// question with this instead, so a game can be played to a decided
  /// outcome without a widget tree to tap through.
  final Future<bool> Function(String prompt, List<String> options, int correct)?
  answer;
  const KidsThreeInARow({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
    this.answer,
  });

  @override
  State<KidsThreeInARow> createState() => _KidsThreeInARowState();
}

enum _Outcome { playing, won, lost, draw }

class _KidsThreeInARowState extends State<KidsThreeInARow> {
  static const _n = 3;
  late final math.Random _rng = widget.rng ?? math.Random();
  late final List<ArabicLetter> _cells = _pickCells();
  final List<String?> _owner = List.filled(9, null); // 'x' | 'o' | null
  _Outcome _outcome = _Outcome.playing;
  bool _busy = false; // a question is on screen, or the computer is "thinking"
  int _right = 0;
  int _wrong = 0;
  bool _reported = false;

  List<ArabicLetter> _pickCells() {
    final pool = [...widget.known]..shuffle(_rng);
    return [for (var i = 0; i < 9; i++) pool[i % pool.length]];
  }

  Future<void> _tap(int i) async {
    if (_busy || _outcome != _Outcome.playing || _owner[i] != null) return;
    final letter = _cells[i];
    final name = letterName(context, letter);
    final o = kidsConfusableOptions(
      answer: letter,
      pool: widget.known,
      show: (l) => letterName(context, l),
      rng: _rng,
    );
    setState(() => _busy = true);
    final correct = await (widget.answer != null
        ? widget.answer!(context.l10n.qpWhichLetterIsThis, o.options, o.correct)
        : kidsBoardQuestion(
            context,
            prompt: context.l10n.qpWhichLetterIsThis,
            options: o.options,
            correct: o.correct,
          ));
    if (!mounted) return;
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'letter.${letter.char}',
      arabic: letter.char,
      answer: name,
      distractors: [
        for (final s in o.options)
          if (s != name) s,
      ],
    );
    if (correct) {
      _right++;
      setState(() => _owner[i] = 'x');
    } else {
      _wrong++;
    }
    _checkEnd();
    if (_outcome != _Outcome.playing) {
      setState(() => _busy = false);
      return;
    }
    // Right or wrong, the turn is over — a wrong answer costs the square
    // (nothing claimed) exactly as the doc above says, not a second chance
    // at the same one.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _computerMove();
    if (mounted) setState(() => _busy = false);
  }

  void _computerMove() {
    final open = [
      for (var i = 0; i < 9; i++)
        if (_owner[i] == null) i,
    ];
    if (open.isEmpty) return;
    final pick = open[_rng.nextInt(open.length)];
    setState(() => _owner[pick] = 'o');
    _checkEnd();
  }

  void _checkEnd() {
    if (kidsHasWinningLine(_n, (i) => _owner[i] == 'x')) {
      setState(() => _outcome = _Outcome.won);
    } else if (kidsHasWinningLine(_n, (i) => _owner[i] == 'o')) {
      setState(() => _outcome = _Outcome.lost);
    } else if (_owner.every((o) => o != null)) {
      setState(() => _outcome = _Outcome.draw);
    }
  }

  int get _stars {
    final total = _right + _wrong;
    if (total == 0) return 3;
    // Winning matters, but so does how many tries it took to get there — a
    // win on the first try every time is the only way to a perfect score.
    final frac = _right / total;
    return starsForFraction(frac, kids: true);
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    if (_outcome != _Outcome.playing && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _stars,
        ),
      );
    }
    if (_outcome != _Outcome.playing) {
      final message = switch (_outcome) {
        _Outcome.won => context.l10n.kidsGameYouWon,
        _Outcome.lost => context.l10n.kidsGameComputerWon,
        _Outcome.draw => context.l10n.kidsGameDraw,
        _Outcome.playing => '',
      };
      return KidsScreenScaffold(
        child: KidsLessonResult(
          stars: _stars,
          footer: Text(
            message,
            textAlign: TextAlign.center,
            style: kbText(16, kbC(ui.ink), weight: FontWeight.w700),
          ),
        ),
      );
    }
    return KidsScreenScaffold(
      child: KidsCentered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The design's game page (kb_screens.dart `KbTttScreen`).
            KidsLessonTitle(context.l10n.kidsGameThreeInARow,
                fontSize: 32, height: 1.1, align: TextAlign.center),
            const SizedBox(height: 10),
            KidsLessonSubtitle(
              _busy
                  ? context.l10n.kidsGameComputerTurn
                  : context.l10n.kidsGameYourTurn,
              align: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: AspectRatio(
                aspectRatio: 1,
                child: KidsBoard(
                  columns: _n,
                  cellCount: 9,
                  spacing: 14,
                  cellBuilder: (context, i) {
                    final owner = _owner[i];
                    final state = switch (owner) {
                      'x' => KidsCellState.a,
                      'o' => KidsCellState.b,
                      _ => KidsCellState.empty,
                    };
                    // The letter stays on a claimed square; whose it is shows
                    // in the square itself — the child's deep with a star,
                    // the computer's in its own colour — as the design draws
                    // it.
                    return KidsBoardCell(
                      state: state,
                      radius: 24,
                      onTap: owner == null ? () => _tap(i) : null,
                      child: Text(
                        _cells[i].char,
                        textDirection: TextDirection.rtl,
                        style: kbText(46, kidsBoardInk(context, state),
                            family: kbFontArabic,
                            weight: FontWeight.w600,
                            height: 1.3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
