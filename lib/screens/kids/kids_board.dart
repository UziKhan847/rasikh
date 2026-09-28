import 'package:flutter/material.dart';

import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kBlack, kbC;

/// The shared shape behind Three in a Row, Memory Match and Letter Bingo: an
/// n×n grid of square, evenly-spaced cells. Each game supplies its own cell
/// content and tap handling; this only lays them out the same way everywhere,
/// so a fourth game later is a new file, not a new layout.
class KidsBoard extends StatelessWidget {
  final int columns;
  final int cellCount;
  final Widget Function(BuildContext context, int index) cellBuilder;
  final double spacing;
  const KidsBoard({
    super.key,
    required this.columns,
    required this.cellCount,
    required this.cellBuilder,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Room for the cells' edges, rings and shadows, which sit outside
      // their boxes.
      clipBehavior: Clip.none,
      itemCount: cellCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemBuilder: cellBuilder,
    );
  }
}

/// How one [KidsBoardCell] is coloured. `a`/`b` are the two "sides" of a
/// two-player board (Three in a Row's X and O); `matched`/`wrong` are
/// Memory Match's and Bingo's own momentary feedback; `revealed` is a card
/// turned face up; `picked` is a bingo square the child has claimed.
enum KidsCellState { empty, a, b, matched, wrong, locked, revealed, picked }

/// The design's cell state for a board state (kb_components.dart
/// `KbGlyphCell`): the child's square is "mine" (deep face, star), the
/// computer's "cpu", a match "good", a miss "bad".
KbCellState kidsBoardCellState(KidsCellState s) => switch (s) {
  KidsCellState.empty || KidsCellState.locked => KbCellState.idle,
  KidsCellState.a => KbCellState.mine,
  KidsCellState.b => KbCellState.cpu,
  KidsCellState.matched => KbCellState.good,
  KidsCellState.wrong => KbCellState.bad,
  KidsCellState.revealed => KbCellState.open,
  KidsCellState.picked => KbCellState.selected,
};

/// The ink to draw a cell's content in, for its [state] — white on the
/// child's own deep squares.
Color kidsBoardInk(BuildContext context, KidsCellState state) =>
    kbC(KbGlyphCell.inkOf(kbUi(context), kidsBoardCellState(state)));

/// One square cell — the design's game cell: filled and edged by [state] —
/// the one visual vocabulary all three games share, so a claimed square
/// always means the same thing wherever it appears. A locked cell stays solid
/// and fades its content (UI_SPEC §1.7).
class KidsBoardCell extends StatelessWidget {
  final Widget? child;
  final KidsCellState state;
  final VoidCallback? onTap;

  /// The design's cells: three-in-a-row and memory are `game` (radius 24 / 22),
  /// bingo's are `letter` (radius 20).
  final KbElev elev;
  final double radius;
  const KidsBoardCell({
    super.key,
    this.child,
    this.state = KidsCellState.empty,
    this.onTap,
    this.elev = KbElev.game,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) => KbGlyphCell(
    ui: kbUi(context),
    state: kidsBoardCellState(state),
    elev: elev,
    radius: radius,
    onTap: onTap,
    child: Opacity(
      opacity: state == KidsCellState.locked ? .4 : 1,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

/// Every winning line on an [n]×[n] board, as cell indices — every row, every
/// column, and both diagonals. Shared by Three in a Row (n=3) and Letter
/// Bingo (n=4); Memory Match has no lines, it wins by clearing every pair.
List<List<int>> kidsBoardLines(int n) {
  final lines = <List<int>>[];
  for (var r = 0; r < n; r++) {
    lines.add([for (var c = 0; c < n; c++) r * n + c]);
  }
  for (var c = 0; c < n; c++) {
    lines.add([for (var r = 0; r < n; r++) r * n + c]);
  }
  lines.add([for (var i = 0; i < n; i++) i * n + i]);
  lines.add([for (var i = 0; i < n; i++) i * n + (n - 1 - i)]);
  return lines;
}

/// Whether some line of an [n]×[n] board is entirely [owns] — the one check
/// both Three in a Row and Letter Bingo need to know they have just won.
bool kidsHasWinningLine(int n, bool Function(int index) owns) =>
    kidsBoardLines(n).any((line) => line.every(owns));

/// A fast, single-attempt question for inside a game turn — unlike
/// [KidsChoiceCard]'s careful second-try-then-teach flow (right for a
/// lesson's own check-up), a game has to keep its own pace: one try, an
/// immediate right or wrong, gone. Returns whether it was answered correctly;
/// the caller still records the miss/correct in the review queue itself,
/// since only it knows the review id.
Future<bool> kidsBoardQuestion(
  BuildContext context, {
  required String prompt,
  required List<String> options,
  required int correct,
  bool optionsAreArabic = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _BoardQuestionDialog(
      prompt: prompt,
      options: options,
      correct: correct,
      optionsAreArabic: optionsAreArabic,
    ),
  ).then((v) => v ?? false);
}

class _BoardQuestionDialog extends StatefulWidget {
  final String prompt;
  final List<String> options;
  final int correct;
  final bool optionsAreArabic;
  const _BoardQuestionDialog({
    required this.prompt,
    required this.options,
    required this.correct,
    required this.optionsAreArabic,
  });

  @override
  State<_BoardQuestionDialog> createState() => _BoardQuestionDialogState();
}

class _BoardQuestionDialogState extends State<_BoardQuestionDialog> {
  int? _picked;

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) Navigator.of(context).pop(i == widget.correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    // A hero card over the game (the design's Hamzah card shape), its options
    // the design's answer cells.
    return Dialog(
      backgroundColor: kbC(kBlack, 0),
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: KbSurface(
        color: ui.surface,
        edge: ui.edge,
        elev: KbElev.hero,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.prompt,
              textAlign: TextAlign.center,
              style: kbText(21, kbC(ui.ink), height: 1.2),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 280,
              child: GridView.count(
                shrinkWrap: true,
                clipBehavior: Clip.none,
                crossAxisCount: widget.optionsAreArabic ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: widget.optionsAreArabic ? 1.0 : 2.4,
                children: [
                  for (final (i, o) in widget.options.indexed)
                    () {
                      final showResult = _picked != null;
                      final right = i == widget.correct;
                      return KbGlyphCell(
                        ui: ui,
                        square: false,
                        elev: KbElev.option,
                        state: !showResult
                            ? KbCellState.idle
                            : right
                                ? KbCellState.good
                                : _picked == i
                                    ? KbCellState.bad
                                    : KbCellState.idle,
                        onTap: () => _pick(i),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              o,
                              textDirection: widget.optionsAreArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: widget.optionsAreArabic
                                  ? kbText(30, kbC(ui.ink),
                                      family: kbFontArabic,
                                      weight: FontWeight.w600,
                                      height: 1.3)
                                  : kbText(18, kbC(ui.ink),
                                      weight: FontWeight.w700),
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
