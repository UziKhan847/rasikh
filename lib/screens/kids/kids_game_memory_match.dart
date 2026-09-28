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
import 'kids_widgets.dart';

/// One face of a Memory Match card: a letter's glyph, or its name — the pair
/// a child hunts for is one of each, for the same letter.
class _Card {
  final ArabicLetter letter;
  final bool isGlyph;
  const _Card(this.letter, this.isGlyph);
}

/// The evidence on Arabic letter games singles out card matching for visual
/// discrimination — exactly the ب/ت/ث problem this app's Look-alikes drill
/// already targets. This is that game: six known letters, twelve face-down
/// cards, find the glyph and the name that belong together.
///
/// A pair is a glyph card and a name card of the SAME letter — never two
/// glyphs or two names — so a match genuinely tests "I know what this is
/// called", not just "these two cards look alike".
class KidsMemoryMatch extends StatefulWidget {
  final List<ArabicLetter> known;
  final String progressId;
  final math.Random? rng;
  const KidsMemoryMatch({
    super.key,
    required this.known,
    required this.progressId,
    this.rng,
  });

  @override
  State<KidsMemoryMatch> createState() => _KidsMemoryMatchState();
}

class _KidsMemoryMatchState extends State<KidsMemoryMatch> {
  static const _pairs = 6;
  late final math.Random _rng = widget.rng ?? math.Random();
  late final List<_Card> _cards = _buildCards();
  late final List<bool> _revealed = List.filled(_cards.length, false);
  late final List<bool> _matched = List.filled(_cards.length, false);
  int? _firstIndex;
  bool _busy = false;
  int _matches = 0;
  int _mismatches = 0;
  bool _reported = false;

  List<_Card> _buildCards() {
    final pool = [...widget.known]..shuffle(_rng);
    final chosen = [for (var i = 0; i < _pairs; i++) pool[i % pool.length]];
    final cards = <_Card>[
      for (final l in chosen) ...[_Card(l, true), _Card(l, false)],
    ];
    cards.shuffle(_rng);
    return cards;
  }

  bool get _done => _matched.every((m) => m);

  void _tap(int i) {
    if (_busy || _matched[i] || _revealed[i]) return;
    setState(() => _revealed[i] = true);
    final first = _firstIndex;
    if (first == null) {
      _firstIndex = i;
      return;
    }
    final a = _cards[first], b = _cards[i];
    final isMatch = a.letter.char == b.letter.char && a.isGlyph != b.isGlyph;
    if (isMatch) {
      _matches++;
      setState(() {
        _matched[first] = true;
        _matched[i] = true;
        _firstIndex = null;
      });
      final letter = a.letter;
      kidsRecordCheck(
        context,
        correct: true,
        reviewId: 'letter.${letter.char}',
        arabic: letter.char,
        answer: letterName(context, letter),
      );
    } else {
      _mismatches++;
      setState(() => _busy = true);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          _revealed[first] = false;
          _revealed[i] = false;
          _firstIndex = null;
          _busy = false;
        });
      });
    }
  }

  int get _stars {
    final total = _matches + _mismatches;
    if (total == 0) return 3;
    return starsForFraction(_matches / total, kids: true);
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
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
    if (_done) {
      return KidsScreenScaffold(
        child: KidsLessonResult(
          stars: _stars,
          footer: Text(
            context.l10n.kidsGameAllMatched,
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
            // The design's game page (kb_screens.dart `KbMemoryScreen`).
            KidsLessonTitle(context.l10n.kidsGameMemoryMatch,
                fontSize: 32, height: 1.1, align: TextAlign.center),
            const SizedBox(height: 10),
            KidsLessonSubtitle(context.l10n.kidsGameFindPairs,
                align: TextAlign.center, height: 1.35),
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: KidsBoard(
                  columns: 3,
                  cellCount: _cards.length,
                  spacing: 14,
                  cellBuilder: (context, i) {
                    final card = _cards[i];
                    final open = _revealed[i] || _matched[i];
                    return KidsBoardCell(
                      key: ValueKey('kidsMemoryCard.$i'),
                      state: _matched[i]
                          ? KidsCellState.matched
                          : open
                          ? KidsCellState.revealed
                          : KidsCellState.empty,
                      onTap: open ? null : () => _tap(i),
                      child: !open
                          // Face down: the design's question mark.
                          ? KbIcon('help', size: 36, color: kbC(ui.inkSoft))
                          : card.isGlyph
                          ? Text(
                              card.letter.char,
                              textDirection: TextDirection.rtl,
                              style: kbText(44, kbC(ui.ink),
                                  family: kbFontArabic,
                                  weight: FontWeight.w600,
                                  height: 1.3),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  letterName(context, card.letter),
                                  style: kbText(24, kbC(ui.ink)),
                                ),
                              ),
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
