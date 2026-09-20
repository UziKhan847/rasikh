import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart' show TapScale;

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

  Widget _tile(BuildContext context, int i) {
    final p = kidsPal(context);
    final tried = _tried.contains(i);
    final isRight = i == widget.correct;
    final revealed = _resolved && isRight;
    final tile = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: widget.columns == 1
          ? const BoxConstraints(minHeight: 56)
          : null,
      decoration: BoxDecoration(
        color: revealed
            ? AppColors.ok.withValues(alpha: .18)
            : tried
            ? AppColors.bad.withValues(alpha: .14)
            : p.surface,
        borderRadius: BorderRadius.circular(Geo.radiusLg),
        border: Border.all(
          color: revealed ? AppColors.ok : Colors.transparent,
          width: 2,
        ),
      ),
      child: Opacity(
        opacity: tried && !revealed ? .5 : 1,
        child: widget.options[i],
      ),
    );
    // A tile that has been tried is no longer a target, and stops being a
    // TapScale, so the ones still in play are the only tappable things left.
    return _resolved || tried
        ? tile
        : TapScale(onTap: () => _tap(i), child: tile);
  }

  Widget _options(BuildContext context) {
    final tiles = [
      for (var i = 0; i < widget.options.length; i++) _tile(context, i),
    ];
    if (widget.columns == 1) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final t in tiles)
              Padding(
                padding: const EdgeInsets.only(bottom: Geo.gapSm),
                child: t,
              ),
          ],
        ),
      );
    }
    return GridView.count(
      crossAxisCount: widget.columns,
      mainAxisSpacing: Geo.gapMd,
      crossAxisSpacing: Geo.gapMd,
      childAspectRatio: widget.aspect,
      children: tiles,
    );
  }

  /// The end of a check with an explanation: was it right, what was right if
  /// not, and why — replacing the options, which have done their job.
  Widget _panel(BuildContext context) {
    final p = kidsPal(context);
    final right = _solved;
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(Geo.gapMd),
        decoration: kidsCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              right
                  ? context.l10n.kidsCheckYes
                  : context.l10n.kidsCheckNotQuite,
              style: kidsStyle(
                context,
                size: 16,
                weight: FontWeight.w800,
                color: right ? AppColors.ok : p.accent,
              ),
            ),
            if (!right) ...[
              const SizedBox(height: Geo.gapSm),
              Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: AppColors.ok.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(Geo.radiusLg),
                  border: Border.all(color: AppColors.ok, width: 2),
                ),
                child: widget.options[widget.correct],
              ),
            ],
            const SizedBox(height: Geo.gapSm),
            Text(widget.explain!, style: kidsStyle(context, size: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final explaining = _resolved && widget.explain != null;
    final retrying = _tried.isNotEmpty && !_resolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.prompt,
          style: kidsStyle(context, size: 17, weight: FontWeight.w800),
        ),
        const SizedBox(height: Geo.gapMd),
        // Flexible and scrollable rather than fixed: a real verse can be as
        // long as a whole āyah.
        if (widget.display != null)
          Flexible(child: SingleChildScrollView(child: widget.display)),
        const SizedBox(height: Geo.gapMd),
        if (retrying)
          Container(
            margin: const EdgeInsets.only(bottom: Geo.gapMd),
            padding: const EdgeInsets.all(Geo.gapSm),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(Geo.radiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, size: 20, color: p.amber),
                const SizedBox(width: Geo.gapSm),
                Expanded(
                  child: Text(
                    widget.hint ?? context.l10n.kidsCheckTryAgain,
                    style: kidsStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: explaining ? _panel(context) : _options(context)),
        if (explaining) ...[
          const SizedBox(height: Geo.gapMd),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _report,
            child: Text(context.l10n.kidsNextCard),
          ),
        ],
      ],
    );
  }
}
