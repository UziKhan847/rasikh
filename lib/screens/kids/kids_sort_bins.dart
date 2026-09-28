import 'package:flutter/material.dart';

import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../kids_backdrops/kb_ui.dart';
import '../../widgets/drag_kit.dart';
import 'kids_widgets.dart' show KidsCentered;

/// One thing to be sorted: shown as [label] (Arabic), and belongs in bin [bin].
class KidsSortItem {
  final String id;
  final String label;
  final int bin;
  const KidsSortItem({
    required this.id,
    required this.label,
    required this.bin,
  });
}

/// One place things are sorted into.
class KidsSortBin {
  final String emoji;
  final String title;
  const KidsSortBin({required this.emoji, required this.title});
}

/// Sort [items] into [bins]: sun letters and moon letters, the shapes of a
/// tanwīn, the letters with a dot and the ones without.
///
/// A tile is DRAGGED into its bin, or TAPPED to pick it up and then a bin
/// TAPPED to put it down — the same result either way, so the activity is open
/// to a child who cannot drag yet. A right bin keeps the tile; a wrong one
/// flashes and hands the tile back, costing the round its first-try mark but
/// never blocking it: the child keeps sorting until every tile is home.
class KidsSortBins extends StatefulWidget {
  final String prompt;
  final List<KidsSortItem> items;
  final List<KidsSortBin> bins;

  /// Arabic size of a tile.
  final double size;

  /// A tile put in the wrong bin.
  final void Function(KidsSortItem item, int bin)? onWrong;

  /// Every tile is home; true if none was ever put in the wrong bin.
  final void Function(bool firstTry) onDone;

  const KidsSortBins({
    super.key,
    required this.prompt,
    required this.items,
    required this.bins,
    required this.onDone,
    this.size = 26,
    this.onWrong,
  });

  @override
  State<KidsSortBins> createState() => _KidsSortBinsState();
}

class _KidsSortBinsState extends State<KidsSortBins> {
  /// Tile id -> the bin it sits in.
  final Map<String, int> _home = {};
  String? _held; // picked up by a tap, waiting for a bin
  String? _flashItem;
  int? _flashBin;
  int _wrong = 0;
  bool _reported = false;

  KidsSortItem _item(String id) => widget.items.firstWhere((i) => i.id == id);

  void _pickUp(String id) => setState(() => _held = _held == id ? null : id);

  void _drop(String id, int bin) {
    if (_home.containsKey(id)) return;
    final item = _item(id);
    if (item.bin == bin) {
      setState(() {
        _home[id] = bin;
        _held = null;
      });
      if (_home.length == widget.items.length && !_reported) {
        _reported = true;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onDone(_wrong == 0);
        });
      }
    } else {
      _wrong++;
      widget.onWrong?.call(item, bin);
      setState(() {
        _flashItem = id;
        _flashBin = bin;
        _held = null;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _flashItem = null;
            _flashBin = null;
          });
        }
      });
    }
  }

  /// A word to sort, as the design's answer cell: [state] idle in the pool,
  /// `open` (the selection ring) while held, `bad` for a moment after a wrong
  /// bin, `good` once sorted.
  Widget _tile(
    BuildContext context,
    KidsSortItem item, {
    KbCellState state = KbCellState.idle,
    VoidCallback? onTap,
    double? size,
  }) {
    final ui = kbUi(context);
    return KbGlyphCell(
      ui: ui,
      state: state,
      square: false,
      radius: 18,
      elev: state == KbCellState.good ? KbElev.edge3 : KbElev.option,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Text(
          item.label,
          textDirection: TextDirection.rtl,
          style: kbText(size ?? widget.size, kbC(ui.ink),
              family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
    );
  }

  Widget _bin(BuildContext context, int i) {
    final ui = kbUi(context);
    final bin = widget.bins[i];
    final inside = [
      for (final item in widget.items)
        if (_home[item.id] == i) item,
    ];
    final flashing = _flashBin == i;
    final inviting = !flashing && _held != null;
    return DropSlot<String>(
      onDrop: (id) => _drop(id, i),
      builder: (context, hovering) => DropGlow(
        hovering: hovering != null,
        color: kbC(ui.accent),
        radius: 22,
        // A solid card; while a word is held, every bin wears the selection
        // ring to say "put it here", and a wrong one flashes the "bad" ring.
        child: KbSurface(
          key: ValueKey('sortBin.$i'),
          color: ui.surface,
          edge: flashing
              ? KbUi.badEdge
              : inviting
                  ? ui.accentEdge
                  : ui.edge,
          outline: flashing
              ? KbUi.badLine
              : inviting
                  ? ui.accent
                  : null,
          outlineWidth: 3,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          onTap: () {
            final held = _held;
            if (held != null) _drop(held, i);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bin.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 2),
                Text(
                  bin.title,
                  textAlign: TextAlign.center,
                  style: kbText(18, kbC(ui.ink), height: 1.15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (final item in inside)
                      _tile(context, item,
                          state: KbCellState.good, size: widget.size * .8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final pool = [
      for (final item in widget.items)
        if (!_home.containsKey(item.id)) item,
    ];
    return KidsCentered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The instruction, on the sky — the design's quiz prompt.
          KbSubtitle(widget.prompt,
              ui: ui, fontSize: 22, height: 1.3, align: TextAlign.center),
          const SizedBox(height: 18),
          // Everything still to sort. Emptied tile by tile; the round ends when
          // it is.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final item in pool)
                  DragTile<String>(
                    key: ValueKey('sortItem.${item.id}'),
                    data: item.id,
                    child: _tile(
                      context,
                      item,
                      state: _flashItem == item.id
                          ? KbCellState.bad
                          : _held == item.id
                              ? KbCellState.open
                              : KbCellState.idle,
                      onTap: () => _pickUp(item.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.bins.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _bin(context, i)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
