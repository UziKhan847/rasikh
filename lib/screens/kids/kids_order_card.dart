import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../widgets/drag_kit.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_widgets.dart' show KidsCentered;

/// Put [items] in their right order — the words of an āyah, the āyāt of a
/// sūrah, the letters of a word. The tiles are offered shuffled and never
/// already in order; a right tile moves up into what is being built, a wrong
/// one flashes and costs the step its first-try mark but never undoes what is
/// placed, so the child keeps building until it is right.
///
/// A tile is either DRAGGED into the row being built or just TAPPED — the two
/// do exactly the same thing, so a child who cannot drag yet is not held back.
///
/// [decoys] are extra tiles that belong nowhere (a look-alike letter among a
/// word's own): tapping one is always wrong, and it stays on offer.
class KidsOrderCard extends StatefulWidget {
  final String prompt;

  /// Shown above the built row — the model to copy, when there is one.
  final Widget? header;
  final List<String> items;
  final List<String> decoys;
  final math.Random rng;
  final double size;

  /// Full-width rows (whole āyāt) instead of word-sized tiles.
  final bool wide;

  /// When set, the finished row becomes this text — the separate letters
  /// snapping together into the joined word.
  final String? joined;

  /// A wrong tap: the tile tapped and the one that was expected.
  final void Function(String tapped, String expected)? onWrong;
  final void Function(bool firstTry) onDone;
  const KidsOrderCard({
    super.key,
    required this.prompt,
    required this.items,
    required this.rng,
    required this.size,
    required this.wide,
    required this.onDone,
    this.header,
    this.decoys = const [],
    this.joined,
    this.onWrong,
  });

  @override
  State<KidsOrderCard> createState() => _KidsOrderCardState();
}

class _KidsOrderCardState extends State<KidsOrderCard> {
  /// Everything on offer: the items, then the decoys.
  late final List<String> _all = [...widget.items, ...widget.decoys];

  /// The tiles on offer, as indices into [_all], shuffled.
  late final List<int> _bank = () {
    final idx = List.generate(_all.length, (i) => i);
    // Never offered already in order: that would be a step with nothing to do.
    for (var tries = 0; tries < 10; tries++) {
      idx.shuffle(widget.rng);
      if (widget.decoys.isNotEmpty || idx.length < 2 || !_inOrder(idx)) break;
    }
    return idx;
  }();
  final Set<int> _taken = {};
  int _placed = 0;
  int _wrong = 0;
  int? _flash;
  bool _reported = false;

  bool _inOrder(List<int> idx) {
    for (var i = 0; i < idx.length; i++) {
      if (_all[idx[i]] != widget.items[i]) return false;
    }
    return true;
  }

  bool get _finished => _placed >= widget.items.length;

  void _tap(int slot) {
    if (_finished || _taken.contains(slot)) return;
    final tapped = _all[_bank[slot]];
    final expected = widget.items[_placed];
    if (tapped == expected) {
      setState(() {
        _taken.add(slot);
        _placed++;
      });
      if (_finished && !_reported) {
        _reported = true;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onDone(_wrong == 0);
        });
      }
    } else {
      _wrong++;
      widget.onWrong?.call(tapped, expected);
      setState(() => _flash = slot);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _flash = null);
      });
    }
  }

  /// A piece as the design's answer cell: idle on offer (bad for a moment
  /// after a wrong tap), good once placed.
  Widget _tile(BuildContext context, String text, KbCellState state,
      {VoidCallback? onTap}) {
    final ui = kbUi(context);
    final cell = KbGlyphCell(
      ui: ui,
      state: state,
      square: false,
      radius: 18,
      elev: state == KbCellState.good ? KbElev.edge3 : KbElev.option,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: kbText(widget.size, kbC(ui.ink),
              family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
    );
    return widget.wide ? SizedBox(width: double.infinity, child: cell) : cell;
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final placed = [for (var i = 0; i < _placed; i++) widget.items[i]];
    // The tiles still on offer, as slots of [_bank].
    final open = [
      for (var s = 0; s < _bank.length; s++)
        if (!_taken.contains(s)) s,
    ];
    Widget offered(int s) => DragTile<int>(
      data: s,
      enabled: !_finished,
      child: _tile(
        context,
        _all[_bank[s]],
        _flash == s ? KbCellState.bad : KbCellState.idle,
        onTap: () => _tap(s),
      ),
    );
    // The empty place the next tile goes: a drag needs somewhere to land, and a
    // child needs to see there IS a place.
    final ghost = SizedBox(
      width: widget.wide ? double.infinity : 64,
      height: (widget.size * 1.5).clamp(48.0, double.infinity),
      // The design's "open" cell: the selection ring says "this is next".
      child: KbGlyphCell(
        ui: ui,
        state: KbCellState.open,
        square: false,
        radius: 18,
        elev: KbElev.edge3,
        child: KbIcon('add', size: 28, color: kbC(ui.accent)),
      ),
    );
    final built = _finished && widget.joined != null
        ? Center(child: _tile(context, widget.joined!, KbCellState.good))
        : widget.wide
        ? Column(
            children: [
              for (final t in placed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _tile(context, t, KbCellState.good),
                ),
              if (!_finished) ghost,
            ],
          )
        : Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: Geo.gapSm,
            runSpacing: Geo.gapSm,
            children: [
              for (final t in placed) _tile(context, t, KbCellState.good),
              if (!_finished) ghost,
            ],
          );
    // One centred block — prompt, model, what has been built, what is left —
    // rather than a prompt at the top and a scroll view under it that packs to
    // the top and leaves the rest of the screen empty.
    return KidsCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The instruction, on the sky — the design's quiz prompt.
          KbSubtitle(widget.prompt,
              ui: ui, fontSize: 22, height: 1.3, align: TextAlign.center),
          const SizedBox(height: Geo.gapMd),
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: Geo.gapMd),
          ],
          // What has been built so far, in reading order — and where a dragged
          // tile lands.
          DropSlot<int>(
            enabled: !_finished,
            onDrop: _tap,
            builder: (context, hovering) => DropGlow(
              hovering: hovering != null,
              color: kbC(ui.accent),
              radius: 22,
              child: KbSurface(
                color: ui.surface,
                edge: ui.edge,
                radius: 22,
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: built,
                ),
              ),
            ),
          ),
          const SizedBox(height: Geo.gapLg),
          if (widget.wide) ...[
            for (final s in open)
              Padding(
                padding: const EdgeInsets.only(bottom: Geo.gapSm),
                child: offered(s),
              ),
          ] else
            Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: Geo.gapSm,
              runSpacing: Geo.gapSm,
              children: [for (final s in open) offered(s)],
            ),
        ],
      ),
    );
  }
}
