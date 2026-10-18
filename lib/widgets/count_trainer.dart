import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/kit.dart';

/// The count trainer: press and hold for exactly [counts] beats, then let go
/// and see how close you came. One count is one ḥarakah ([beatMs]); the
/// segments fill as the beats pass, with a light tick on each.
class HoldCountTrainer extends StatefulWidget {
  final int counts;
  final int beatMs;
  const HoldCountTrainer({super.key, required this.counts, this.beatMs = 600});

  @override
  State<HoldCountTrainer> createState() => _HoldCountTrainerState();
}

class _HoldCountTrainerState extends State<HoldCountTrainer> {
  final _watch = Stopwatch();
  Timer? _tick;
  int _beat = 0;
  double? _held;

  bool get _holding => _watch.isRunning;

  void _down() {
    _tick?.cancel();
    _watch
      ..reset()
      ..start();
    setState(() {
      _beat = 0;
      _held = null;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final b = _watch.elapsedMilliseconds ~/ widget.beatMs;
      if (b != _beat) {
        if (SettingsScope.of(context).haptics) HapticFeedback.selectionClick();
        setState(() => _beat = b);
      }
    });
  }

  void _up() {
    if (!_holding) return;
    _watch.stop();
    _tick?.cancel();
    setState(() => _held = _watch.elapsedMilliseconds / widget.beatMs);
  }

  @override
  void didUpdateWidget(HoldCountTrainer old) {
    super.didUpdateWidget(old);
    if (old.counts != widget.counts) {
      _tick?.cancel();
      _watch
        ..stop()
        ..reset();
      _beat = 0;
      _held = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.counts;
    final held = _held;
    String? result;
    Color resultColour = kHeroInk2;
    if (held != null) {
      final shown = held.toStringAsFixed(1);
      if ((held - n).abs() <= .5) {
        result = context.l10n.heldExact(shown);
        resultColour = const Color(0xFF8FD3B6);
      } else if (held < n) {
        result = context.l10n.heldShort(shown);
        resultColour = kHeroGold;
      } else {
        result = context.l10n.heldLong(shown);
        resultColour = kHeroGold;
      }
    }
    final shownCount = _holding ? _beat : (held == null ? 0 : held.round());
    final upper = const {
      'en',
      'fr',
      'es',
    }.contains(SettingsScope.of(context).language);
    return QHeroCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upper
                          ? context.l10n.countTrainer.toUpperCase()
                          : context.l10n.countTrainer,
                      style: uiStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w600,
                        letterSpacing: 1,
                        color: const Color(0xFF9CC5B6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.holdForCounts(n),
                      style: displayStyle(context, size: 20, color: kHeroInk),
                    ),
                  ],
                ),
              ),
              Text(
                '$shownCount',
                style: displayStyle(context, size: 40, color: kHeroGold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 10,
                    margin: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i < shownCount
                          ? kHeroGold
                          : Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: i < shownCount
                            ? kHeroGold
                            : Colors.white.withValues(alpha: .25),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: context.l10n.pressAndHold,
            child: Listener(
              onPointerDown: (_) => _down(),
              onPointerUp: (_) => _up(),
              onPointerCancel: (_) => _up(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _holding ? kHeroGold : kHeroInk,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  _holding
                      ? context.l10n.releaseAt(n)
                      : context.l10n.pressAndHold,
                  style: uiStyle(
                    context,
                    size: 15,
                    weight: FontWeight.w700,
                    color: const Color(0xFF0F3B32),
                  ),
                ),
              ),
            ),
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: uiStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: resultColour,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The count trainer on its own screen: pick 2, 4 or 6 counts.
class CountTrainerScreen extends StatefulWidget {
  final int initial;
  const CountTrainerScreen({super.key, this.initial = 2});
  @override
  State<CountTrainerScreen> createState() => _CountTrainerScreenState();
}

class _CountTrainerScreenState extends State<CountTrainerScreen> {
  late int _n = widget.initial;

  @override
  Widget build(BuildContext context) => QScreen(
    title: context.l10n.countTrainer,
    subtitle: context.l10n.countTrainerSub,
    children: [
      QSegmented<int>(
        options: [
          for (final n in const [2, 4, 6]) (n, context.l10n.countsN(n), null),
        ],
        value: _n,
        onChanged: (v) => setState(() => _n = v),
      ),
      const SizedBox(height: 16),
      HoldCountTrainer(counts: _n),
    ],
  );
}
