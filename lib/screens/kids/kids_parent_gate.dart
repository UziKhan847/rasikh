import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kBlack, kbC;

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
  // Kids Mode's own look, not the grown-up app's — this dialog shows while
  // still visually inside Kids Mode (it's what decides whether the child
  // actually leaves): the design's hero card, answer cells and pills.
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final ui = kbUi(dialogContext);
      return Dialog(
        backgroundColor: kbC(kBlack, 0),
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: KbSurface(
          color: ui.surface,
          edge: ui.edge,
          elev: KbElev.hero,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(dialogContext.l10n.kidsParentGateTitle,
                  style: kbText(22, kbC(ui.ink), height: 1.15)),
              const SizedBox(height: 4),
              Text(dialogContext.l10n.kidsParentGateSub,
                  style: kbText(16, kbC(ui.inkSoft),
                      weight: FontWeight.w600, height: 1.35)),
              const SizedBox(height: 16),
              Center(
                child: Text('$a + $b = ?', style: kbText(34, kbC(ui.ink))),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final c in choices)
                    SizedBox(
                      width: 66,
                      height: 58,
                      child: KbGlyphCell(
                        ui: ui,
                        square: false,
                        elev: KbElev.option,
                        onTap: () => Navigator.pop(dialogContext, c == answer),
                        child: Text('$c', style: kbText(22, kbC(ui.ink))),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: KbPill(dialogContext.l10n.cancel,
                    ui: ui,
                    kind: KbPillKind.outlined,
                    fontSize: 16,
                    padding: const EdgeInsets.fromLTRB(20, 7, 20, 5),
                    onTap: () => Navigator.pop(dialogContext, false)),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
