import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart' show TapScale;

/// Tap [items] in their right order — the words of an āyah, the āyāt of a
/// sūrah, the letters of a word. The tiles are offered shuffled and never
/// already in order; a right tap moves its tile up into what is being built,
/// a wrong tap flashes and costs the step its first-try mark but never undoes
/// what is placed, so the child keeps building until it is right.
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

  Widget _tile(BuildContext context, String text, Color color, Color? border) {
    return Container(
      width: widget.wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: Geo.gapMd,
        vertical: Geo.gapSm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Geo.radiusLg),
        border: Border.all(color: border ?? Colors.transparent, width: 2),
      ),
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: quranicStyle(context, size: widget.size),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final ok = AppColors.ok.withValues(alpha: .18);
    final placed = [for (var i = 0; i < _placed; i++) widget.items[i]];
    // The tiles still on offer, as slots of [_bank].
    final open = [
      for (var s = 0; s < _bank.length; s++)
        if (!_taken.contains(s)) s,
    ];
    Widget offered(int s) => TapScale(
      onTap: () => _tap(s),
      child: _tile(
        context,
        _all[_bank[s]],
        _flash == s ? AppColors.bad.withValues(alpha: .16) : p.surface,
        null,
      ),
    );
    final built = _finished && widget.joined != null
        ? Center(child: _tile(context, widget.joined!, ok, AppColors.ok))
        : widget.wide
        ? Column(
            children: [
              for (final t in placed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _tile(context, t, ok, AppColors.ok),
                ),
            ],
          )
        : Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: Geo.gapSm,
            runSpacing: Geo.gapSm,
            children: [
              for (final t in placed) _tile(context, t, ok, AppColors.ok),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Geo.gapMd),
          child: Text(
            widget.prompt,
            style: kidsStyle(context, size: 17, weight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) ...[
                  widget.header!,
                  const SizedBox(height: Geo.gapMd),
                ],
                // What has been built so far, in reading order.
                Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(Geo.gapSm),
                  decoration: kidsCard(context),
                  child: built,
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
          ),
        ),
      ],
    );
  }
}
