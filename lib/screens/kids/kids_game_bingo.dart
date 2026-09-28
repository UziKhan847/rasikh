import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../data/glyph_names.dart' show letterName;
import '../../data/letters.dart';
import '../../widgets/common.dart' show starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_board.dart';
import 'kids_widgets.dart';

enum _Outcome { playing, won, noLine }

/// **Letter Bingo.** A caller says one letter out loud; the child taps any
/// cell that shows it. Four in a row — a row, a column, or either diagonal —
/// wins. Unlike Three in a Row and Memory Match, the board never prints the
/// letter's name anywhere: the only way to know which cell is right is to
/// have understood the sound, which is the one thing this app's other games
/// leave to the eye instead of the ear.
///
/// One guess per call — right or wrong, the game moves straight to the next
/// call, the same honesty [KidsThreeInARow] documents for itself. A miss
/// files against the letter that was CALLED, the thing the child was asked
/// to find, not whatever got tapped instead — the same convention
/// [KidsFindInAyah] uses for "tap the word with this letter in it".
class KidsGameBingo extends StatefulWidget {
  final List<ArabicLetter> known;
  final String progressId;
  final math.Random? rng;
  const KidsGameBingo({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
  });

  @override
  State<KidsGameBingo> createState() => _KidsGameBingoState();
}

class _KidsGameBingoState extends State<KidsGameBingo> {
  static const _n = 4;
  static const _cellCount = _n * _n;
  static const _maxCalls = 24;

  late final math.Random _rng = widget.rng ?? math.Random();
  late final List<ArabicLetter> _cells = _pickCells();
  late final List<ArabicLetter> _onBoard = {..._cells}.toList();
  final List<bool> _claimed = List.filled(_cellCount, false);
  final Set<int> _wrongFlash = {};
  List<ArabicLetter> _queue = [];
  late ArabicLetter _call = _nextCall();
  _Outcome _outcome = _Outcome.playing;
  bool _busy = false;
  int _calls = 0;
  int _right = 0;
  int _wrong = 0;
  bool _reported = false;

  List<ArabicLetter> _pickCells() {
    final pool = [...widget.known]..shuffle(_rng);
    return [for (var i = 0; i < _cellCount; i++) pool[i % pool.length]];
  }

  ArabicLetter _nextCall() {
    if (_queue.isEmpty) _queue = [..._onBoard]..shuffle(_rng);
    return _queue.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
  }

  /// Says the current call out loud. A failure (no clip yet) is silent here,
  /// same as every ambient replay elsewhere — the "Listen again" button is
  /// the honest fallback, not an error toast in the middle of a game.
  void _say() {
    if (!mounted || _outcome != _Outcome.playing) return;
    LetterAudio.play(_call);
  }

  void _tap(int i) {
    if (_busy || _outcome != _Outcome.playing || _claimed[i]) return;
    final letter = _cells[i];
    final called = _call;
    final correct = letter.char == called.char;
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'letter.${called.char}',
      arabic: called.char,
      answer: letterName(context, called),
      distractors: correct ? const [] : [letterName(context, letter)],
    );
    if (correct) {
      _right++;
      setState(() => _claimed[i] = true);
    } else {
      _wrong++;
      setState(() => _wrongFlash.add(i));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongFlash.remove(i));
      });
    }
    if (kidsHasWinningLine(_n, (j) => _claimed[j])) {
      setState(() => _outcome = _Outcome.won);
      return;
    }
    _calls++;
    if (_calls >= _maxCalls) {
      setState(() => _outcome = _Outcome.noLine);
      return;
    }
    setState(() {
      _busy = true;
      _call = _nextCall();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _busy = false);
      _say();
    });
  }

  int get _stars {
    final total = _right + _wrong;
    if (total == 0) return 3;
    return starsForFraction(_right / total, kids: true);
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
      return KidsScreenScaffold(
        child: KidsLessonResult(
          stars: _stars,
          footer: Text(
            _outcome == _Outcome.won
                ? context.l10n.kidsGameYouWon
                : context.l10n.kidsGameBingoNoLine,
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
            // The design's game page (kb_screens.dart `KbBingoScreen`).
            KidsLessonTitle(context.l10n.kidsGameBingo,
                fontSize: 32, height: 1.1, align: TextAlign.center),
            const SizedBox(height: 10),
            KidsLessonSubtitle(context.l10n.kidsGameBingoSub,
                align: TextAlign.center),
            const SizedBox(height: 16),
            Center(
              child: KidsListenButton(onTap: _say),
            ),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AspectRatio(
                aspectRatio: 1,
                child: KidsBoard(
                  columns: _n,
                  cellCount: _cellCount,
                  cellBuilder: (context, i) {
                    final state = _claimed[i]
                        ? KidsCellState.picked
                        : _wrongFlash.contains(i)
                        ? KidsCellState.wrong
                        : KidsCellState.empty;
                    return KidsBoardCell(
                      key: ValueKey('kidsBingoCell.$i'),
                      state: state,
                      elev: KbElev.letter,
                      radius: 20,
                      onTap: _claimed[i] ? null : () => _tap(i),
                      child: Text(
                        _cells[i].char,
                        textDirection: TextDirection.rtl,
                        style: kbText(38, kidsBoardInk(context, state),
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
