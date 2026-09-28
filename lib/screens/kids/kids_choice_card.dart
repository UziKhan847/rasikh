import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../kids_backdrops/kb_ui.dart';
import 'kids_widgets.dart' show KidsCentered, KidsNextButton;

/// One multiple-choice check, the way every kid lesson asks them — and the way
/// the research on young children says a check should behave:
///
///  * **A second try before it counts.** A first wrong pick is gentle: that tile
///    dims and can no longer be tapped, a pointing [hint] appears ("look at the
///    small sign above the word"), and the child tries again. Only a second
///    miss reveals the answer. A check of only two options has no second try —
///    the second pick would be a guess — so a wrong pick there reveals at once.
///  * **A hint, then the teaching.** The first miss gets the [hint] (pointing);
///    a reveal gets the [explain] (teaching).
///  * **Feedback that says why.** With an [explain], both a right and a wrong
///    answer end on a short explanation the child reads at their own pace and
///    dismisses with Next — never on a colour alone. Without one the card
///    moves on by itself after a beat, as every check used to.
///
/// [onDone] reports whether it was right on the FIRST try — stars are computed
/// from that, so a second try can never inflate them. [onMiss] fires at the
/// first wrong pick, so the review queue hears about a miss when it happens.
class KidsChoiceCard extends StatefulWidget {
  final String prompt;

  /// What is being asked about — a verse, a letter — above the options.
  final Widget? display;

  /// The contents of each option tile (the card frames and colours them).
  final List<Widget> options;
  final int correct;

  /// Tile columns; 1 stacks full-width tiles.
  final int columns;
  final double aspect;
  final String? hint;
  final String? explain;

  /// Whether a wrong first pick earns a second try (when there are three or
  /// more options to choose between).
  final bool retry;

  /// How long a resolved card with no [explain] waits before moving on.
  final Duration settle;
  final void Function(int picked)? onMiss;
  final void Function(bool firstTry) onDone;
  const KidsChoiceCard({
    super.key,
    required this.prompt,
    required this.options,
    required this.correct,
    required this.onDone,
    this.display,
    this.columns = 2,
    this.aspect = 1.7,
    this.hint,
    this.explain,
    this.retry = true,
    this.settle = const Duration(milliseconds: 900),
    this.onMiss,
  }) : assert(
         correct >= 0 && correct < options.length,
         'the right answer must be one of the options',
       );

  @override
  State<KidsChoiceCard> createState() => _KidsChoiceCardState();
}

class _KidsChoiceCardState extends State<KidsChoiceCard> {
  final Set<int> _tried = {};
  bool _firstTry = true;
  bool _resolved = false;

  /// Resolved by picking the right one (on either try), as opposed to being
  /// shown it after two misses.
  bool _solved = false;
  bool _reported = false;

  bool get _canRetry => widget.retry && widget.options.length >= 3;

  void _tap(int i) {
    if (_resolved || _tried.contains(i)) return;
    if (i == widget.correct) {
      setState(() {
        _resolved = true;
        _solved = true;
      });
      _finish();
      return;
    }
    if (_firstTry) widget.onMiss?.call(i);
    _firstTry = false;
    _tried.add(i);
    if (_canRetry && _tried.length == 1) {
      setState(() {}); // dim the tile, show the hint, keep going
      return;
    }
    setState(() => _resolved = true);
    _finish();
  }

  void _report() {
    if (_reported) return;
    _reported = true;
    widget.onDone(_firstTry);
  }

  void _finish() {
    if (widget.explain != null) return; // waits for Next
    Future.delayed(widget.settle, () {
      if (mounted) _report();
    });
  }

  /// An option as the design's answer cell (kb_components.dart `KbGlyphCell`):
  /// idle on the surface; a wrong pick in the "bad" colours, faded (UI_SPEC
  /// §1.7: fade, never go transparent); the right one, once revealed, in the
  /// "good" colours.
  Widget _tile(BuildContext context, int i) {
    final ui = kbUi(context);
    final tried = _tried.contains(i);
    final isRight = i == widget.correct;
    final revealed = _resolved && isRight;
    final cell = KbGlyphCell(
      ui: ui,
      state: revealed
          ? KbCellState.good
          : tried
              ? KbCellState.bad
              : KbCellState.idle,
      elev: KbElev.option,
      square: false,
      onTap: _resolved || tried ? null : () => _tap(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Opacity(
          opacity: tried && !revealed ? .5 : 1,
          child: widget.options[i],
        ),
      ),
    );
    return widget.columns == 1
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64), child: cell)
        : cell;
  }

  Widget _options(BuildContext context) {
    final tiles = [
      for (var i = 0; i < widget.options.length; i++) _tile(context, i),
    ];
    if (widget.columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            t,
          ],
        ],
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Room for the cells' edges and rings, which sit outside their boxes.
      clipBehavior: Clip.none,
      crossAxisCount: widget.columns,
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      childAspectRatio: widget.aspect,
      children: tiles,
    );
  }

  Widget _panel(BuildContext context) {
    final ui = kbUi(context);
    final right = _solved;
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            right ? context.l10n.kidsCheckYes : context.l10n.kidsCheckNotQuite,
            style: kbText(20, kbC(right ? KbUi.goodEdge : ui.linkInk)),
          ),
          if (!right) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: KbGlyphCell(
                ui: ui,
                state: KbCellState.good,
                elev: KbElev.edge3,
                square: false,
                child: widget.options[widget.correct],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(widget.explain!,
              style: kbText(17, kbC(ui.ink),
                  weight: FontWeight.w600, height: 1.35)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final explaining = _resolved && widget.explain != null;
    final retrying = _tried.isNotEmpty && !_resolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The question, on the sky — the design's quiz prompt.
                KbSubtitle(widget.prompt,
                    ui: ui, fontSize: 22, height: 1.3, align: TextAlign.center),
                const SizedBox(height: 18),
                if (widget.display != null) ...[
                  widget.display!,
                  const SizedBox(height: 24),
                ],
                if (retrying)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: KbSurface(
                      color: ui.surface,
                      edge: ui.edge,
                      elev: KbElev.edge4,
                      radius: 18,
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      child: Row(
                        children: [
                          KbDot('lightbulb',
                              bg: ui.reward, ink: ui.rewardInk, size: 30,
                              iconSize: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.hint ?? context.l10n.kidsCheckTryAgain,
                              style: kbText(17, kbC(ui.ink),
                                  weight: FontWeight.w700, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                explaining ? _panel(context) : _options(context),
              ],
            ),
          ),
        ),
        if (explaining) ...[
          const SizedBox(height: 18),
          KidsNextButton(context.l10n.kidsNextCard, onTap: _report),
        ],
      ],
    );
  }
}
