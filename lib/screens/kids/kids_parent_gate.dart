import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';

/// A simple arithmetic challenge that gates leaving Kids Mode. This is UX,
/// not a compliance control — the app collects nothing either way, in Kids
/// Mode or out of it (see docs/privacy-policy.html) — it just stops a child
/// from wandering back into the grown-up app / settings by accident.
Future<bool> showKidsParentGate(BuildContext context) async {
  final rng = math.Random();
  final a = 3 + rng.nextInt(7);
  final b = 3 + rng.nextInt(7);
  final answer = a + b;
  final options = <int>{answer};
  while (options.length < 4) {
    options.add((answer + rng.nextInt(9) - 4).clamp(1, 99));
  }
  final choices = options.toList()..shuffle(rng);
  // kidsPal/kidsStyle, not pal/uiStyle — this dialog shows while still
  // visually inside Kids Mode (it's what decides whether the child actually
  // leaves), so it should carry Kids Mode's palette, not the grown-up app's.
  final p = kidsPal(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(context.l10n.kidsParentGateTitle,
          style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.kidsParentGateSub,
              style: kidsStyle(context, size: 13, color: p.textDim)),
          const SizedBox(height: 14),
          Center(
            child: Text('$a + $b = ?',
                style: kidsStyle(context, size: 26, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in choices)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 44),
                      foregroundColor: p.text,
                      side: BorderSide(color: p.surfaceHigh)),
                  onPressed: () =>
                      Navigator.pop(dialogContext, c == answer),
                  child: Text('$c',
                      style: kidsStyle(context,
                          size: 16, weight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            style: TextButton.styleFrom(foregroundColor: p.textDim),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel,
                style: kidsStyle(context, color: p.textDim))),
      ],
    ),
  );
  return result ?? false;
}
