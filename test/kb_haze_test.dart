import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_themes.dart';

/// The far ridge's haze used to end at full strength in the unlit palettes (all
/// dark/OLED ones, Rain and Night in light): a hard horizontal line across the
/// whole screen. This scans a render for any row where the colour jumps across
/// nearly the full width — what that line looked like.
const _w = 390, _h = 844;

Future<ByteData> _render(KbTheme th, KbMode m) async {
  final rec = ui.PictureRecorder();
  kbPaintScene(Canvas(rec), const Size(390, 844), th, m, KbStyle.vivid);
  final img = await rec.endRecording().toImage(_w, _h);
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

/// The largest share of columns, over any one row of the lower scene, where
/// the colour steps by more than a hair to the next row down.
double _worstRowStep(ByteData px) {
  var worst = 0.0;
  for (var y = (_h * .45).round(); y < (_h * .95).round(); y++) {
    var hits = 0, n = 0;
    for (var x = 0; x < _w; x += 3) {
      final a = (y * _w + x) * 4, b = ((y + 1) * _w + x) * 4;
      var d = 0;
      for (var c = 0; c < 3; c++) {
        d += (px.getUint8(a + c) - px.getUint8(b + c)).abs();
      }
      if (d > 6) hits++;
      n++;
    }
    if (hits / n > worst) worst = hits / n;
  }
  return worst;
}

void main() {
  for (final th in kbThemes) {
    for (final mode in KbMode.values) {
      testWidgets('${th.id} ${mode.name}: no hard line across the far hills', (
        tester,
      ) async {
        await tester.runAsync(() async {
          // A full-width step was 0.7–1.0 of the columns; hills alone stay
          // near 0.3.
          expect(_worstRowStep(await _render(th, mode)), lessThan(.6));
        });
      });
    }
  }
}
