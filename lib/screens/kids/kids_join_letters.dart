import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show letterNameOf;
import '../../data/letters.dart' show letters;
import '../../widgets/common.dart' show starsForFraction;
import '../../widgets/drag_kit.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import 'kids_widgets.dart';

/// A real word to join, and the picture that says what it is — a picture rather
/// than a translation, so there is nothing to read that a child cannot.
class KidsJoinWord {
  final String word;
  final String emoji;
  const KidsJoinWord(this.word, this.emoji);
}

/// Six words, easiest first. The first three show which letters can hold the
/// next one's hand; the rest do not, and rely on the six that never do.
/// كِتَاب and بَاب have one of those six inside them.
const kidsJoinWords = [
  KidsJoinWord('بَيْت', '🏠'),
  KidsJoinWord('قَمَر', '🌙'),
  KidsJoinWord('شَمْس', '☀️'),
  KidsJoinWord('بَاب', '🚪'),
  KidsJoinWord('سَمَك', '🐟'),
  KidsJoinWord('كِتَاب', '📖'),
];

/// How many of [kidsJoinWords] come with the hint.
const kidsJoinHintedWords = 3;

/// The six letters that never join the letter after them.
const kidsNonJoiners = ['ا', 'د', 'ذ', 'ر', 'ز', 'و'];

bool _isMark(int r) =>
    (r >= 0x064B && r <= 0x065F) || r == 0x0670 || (r >= 0x06D6 && r <= 0x06ED);

/// [word] split into its letters, each with the marks that sit on it — the
/// unit a child joins. A mark never starts a piece of its own.
List<String> kidsJoinClusters(String word) {
  final out = <String>[];
  for (final r in word.runes) {
    if (_isMark(r) && out.isNotEmpty) {
      out[out.length - 1] += String.fromCharCode(r);
    } else {
      out.add(String.fromCharCode(r));
    }
  }
  return out;
}

/// Whether the letter in [cluster] joins the letter AFTER it.
bool kidsJoinsForward(String cluster) {
  final base = String.fromCharCode(cluster.runes.first);
  return letters.any((l) => l.char == base && l.joins);
}

/// Letters hold hands to make words: separate letters, joined by dragging one
/// onto its neighbour (or by tapping it), until they are the word — and the six
/// that never join the next letter find that out for themselves.
///
/// The letter shapes change as they join, and nothing here draws that: the
/// merged piece is just the letters' text, shaped by the font, so what a child
/// sees join is what the muṣḥaf shows.
class KidsJoinLettersLesson extends StatefulWidget {
  final String progressId;
  const KidsJoinLettersLesson({super.key, required this.progressId});

  @override
  State<KidsJoinLettersLesson> createState() => _KidsJoinLettersLessonState();
}

class _KidsJoinLettersLessonState extends State<KidsJoinLettersLesson> {
  // Step 0 is the introduction; step n is word n - 1.
  int _step = 0;
  int _correct = 0;
  bool _reported = false;

  int get _total => kidsJoinWords.length + 1;
  bool get _done => _step >= _total;
  int get _stars =>
      starsForFraction(_correct / kidsJoinWords.length, kids: true);

  void _next() => setState(() => _step++);

  void _answer(bool firstTry) {
    if (firstTry) _correct++;
    _next();
  }

  @override
  Widget build(BuildContext context) {
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
      index: _step,
      total: _total,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : _step == 0
          ? _JoinIntro(onNext: _next)
          : KidsJoinCard(
              key: ValueKey('join.$_step'),
              word: kidsJoinWords[_step - 1],
              hint: _step <= kidsJoinHintedWords,
              onDone: _answer,
            ),
    );
  }
}

class _JoinIntro extends StatelessWidget {
  final VoidCallback onNext;
  const _JoinIntro({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KidsLessonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🤝',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 56),
                ),
                const SizedBox(height: Geo.gapSm),
                Text(
                  context.l10n.kidsJoinIntroTitle,
                  textAlign: TextAlign.center,
                  style: kbText(24, kbC(ui.ink), height: 1.15),
                ),
                const SizedBox(height: Geo.gapSm),
                Text(
                  context.l10n.kidsJoinIntro,
                  textAlign: TextAlign.center,
                  style: kbText(18, kbC(ui.inkSoft),
                      weight: FontWeight.w600, height: 1.35),
                ),
                const SizedBox(height: Geo.gapLg),
                Text(
                  context.l10n.kidsJoinSix,
                  textAlign: TextAlign.center,
                  style: kbText(18, kbC(ui.ink), weight: FontWeight.w700),
                ),
                const SizedBox(height: Geo.gapSm),
                Wrap(
                  alignment: WrapAlignment.center,
                  textDirection: TextDirection.rtl,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final ch in kidsNonJoiners)
                      KbGlyphTile(ch,
                          bg: ui.tile,
                          ink: ui.tileInk,
                          size: 56,
                          radius: 16,
                          fontSize: 30),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Geo.gapLg),
          KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
        ],
      ),
    );
  }
}

/// One word to join. Its letters start apart, each on its own tile; joining
/// two neighbours — a drag of one onto the other, or a tap on the first, which
/// reaches for the letter after it — makes them one tile, shaped as the word
/// shapes them. It is done when every letter that CAN hold the next one's hand
/// has.
class KidsJoinCard extends StatefulWidget {
  final KidsJoinWord word;

  /// Mark the letters that can join the next one.
  final bool hint;

  /// Every joinable pair is joined; true if no join was ever attempted that
  /// could not work.
  final void Function(bool firstTry) onDone;

  const KidsJoinCard({
    super.key,
    required this.word,
    required this.hint,
    required this.onDone,
  });

  @override
  State<KidsJoinCard> createState() => _KidsJoinCardState();
}

class _KidsJoinCardState extends State<KidsJoinCard> {
  late final List<String> _c = kidsJoinClusters(widget.word.word);

  /// Seams that have been joined: seam i is between letters i and i + 1.
  final Set<int> _joined = {};
  int _misses = 0;
  int? _flash; // the tile that could not join, briefly red
  String? _note;

  /// The pieces as (first letter, last letter) index pairs, in reading order.
  List<(int, int)> get _groups {
    final out = <(int, int)>[];
    var start = 0;
    for (var i = 0; i < _c.length; i++) {
      if (i == _c.length - 1 || !_joined.contains(i)) {
        out.add((start, i));
        start = i + 1;
      }
    }
    return out;
  }

  bool get _finished => [
    for (var i = 0; i < _c.length - 1; i++)
      if (kidsJoinsForward(_c[i])) i,
  ].every(_joined.contains);

  int _groupAt(int start) => _groups.indexWhere((g) => g.$1 == start);

  void _miss(int tile, String note) {
    _misses++;
    setState(() {
      _flash = tile;
      _note = note;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _flash == tile) setState(() => _flash = null);
    });
  }

  /// Join the piece starting at [a] with its neighbour on the far side of
  /// [seam] — or say why it cannot be.
  void _joinAcross(int tile, int seam) {
    if (!kidsJoinsForward(_c[seam])) {
      _miss(
        tile,
        context.l10n.kidsJoinNoJoin(
          letterNameOf(context, String.fromCharCode(_c[seam].runes.first)),
        ),
      );
      return;
    }
    setState(() {
      _joined.add(seam);
      _note = null;
    });
  }

  /// A tap: reach for the letter after this piece.
  void _tap(int start) {
    final g = _groups;
    final i = _groupAt(start);
    if (i < 0 || i == g.length - 1) return; // nothing after the last piece
    _joinAcross(start, g[i].$2);
  }

  /// A drag of the piece starting at [from] onto the piece starting at [to].
  void _drop(int from, int to) {
    final g = _groups;
    final a = _groupAt(from);
    final b = _groupAt(to);
    if (a < 0 || b < 0 || a == b) return;
    if ((a - b).abs() != 1) {
      _miss(to, context.l10n.kidsJoinNotNeighbours);
      return;
    }
    _joinAcross(to, g[a < b ? a : b].$2);
  }

  Widget _piece(BuildContext context, (int, int) g) {
    final ui = kbUi(context);
    final text = _c.sublist(g.$1, g.$2 + 1).join();
    final holds =
        widget.hint && g.$2 < _c.length - 1 && kidsJoinsForward(_c[g.$2]);
    // A piece as the design's answer cell — bad for a moment after a wrong
    // join.
    final tile = KbGlyphCell(
      ui: ui,
      state: _flash == g.$1 ? KbCellState.bad : KbCellState.idle,
      square: false,
      radius: 18,
      elev: KbElev.option,
      onTap: () => _tap(g.$1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: kbText(46, kbC(ui.ink),
              family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
    );
    return DropSlot<int>(
      key: ValueKey('joinPiece.${g.$1}'),
      enabled: !_finished,
      accepts: (from) => from != g.$1,
      onDrop: (from) => _drop(from, g.$1),
      builder: (context, hovering) => DropGlow(
        hovering: hovering != null,
        color: kbC(ui.accent),
        radius: 18,
        child: DragTile<int>(
          data: g.$1,
          enabled: !_finished,
          child: Stack(
              clipBehavior: Clip.none,
              children: [
                tile,
                // The letter after this one is on its left: a little chain
                // there says "this hand can be held".
                if (holds)
                  Positioned(
                    left: -10,
                    bottom: 4,
                    child: IgnorePointer(
                      child: KbDot('link',
                          bg: ui.accent,
                          ink: kWhite,
                          size: 26,
                          iconSize: 17,
                          ring: ui.surface),
                    ),
                  ),
              ],
            ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KbSubtitle(context.l10n.kidsJoinPrompt,
              ui: ui, fontSize: 22, height: 1.3, align: TextAlign.center),
          const SizedBox(height: Geo.gapSm),
          Text(
            widget.word.emoji,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: Geo.gapMd),
          if (_finished) ...[
            KbGlyphCell(
              ui: ui,
              state: KbCellState.good,
              square: false,
              elev: KbElev.big,
              radius: 28,
              child: Text(
                widget.word.word,
                textDirection: TextDirection.rtl,
                style: kbText(56, kbC(ui.ink),
                    family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
              ),
            ),
            const SizedBox(height: Geo.gapMd),
            KbSubtitle(context.l10n.kidsJoinDone,
                ui: ui, fontSize: 20, align: TextAlign.center),
            const SizedBox(height: Geo.gapLg),
            KidsNextButton(context.l10n.kidsNextCard, onTap: () => widget.onDone(_misses == 0)),
          ] else ...[
            Wrap(
              alignment: WrapAlignment.center,
              textDirection: TextDirection.rtl,
              spacing: Geo.gapMd,
              runSpacing: Geo.gapMd,
              children: [for (final g in _groups) _piece(context, g)],
            ),
            const SizedBox(height: Geo.gapMd),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: _note == null
                  ? const SizedBox.shrink()
                  : KbSubtitle(_note!,
                      ui: ui, fontSize: 18, align: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
