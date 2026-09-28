// Renders every theme x mode x style with the Dart painter and compares it to the
// browser-rendered reference PNG in reference/backdrops/. Pixel-exact match is impossible
// (different rasterisers), so we check mean channel difference and the worst 8x8 block.
//
//   flutter test test/kb_backdrop_compare_test.dart
//
// Rendered output + a diff heat-map for any failure are written to test/_out/.
// Adjust the relative paths below if you move the reference folder.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:YOUR_APP/kids_backdrops/kb_scene.dart';
import 'package:YOUR_APP/kids_backdrops/kb_themes.dart';

const refRoot = 'reference/backdrops';
const w = 390, h = 844;
const maxMeanDiff = 4.0; // 0-255 per channel
const maxBlockDiff = 40.0; // worst 8x8 block average

Future<ByteData> _render(KbTheme th, KbMode m, KbStyle s) async {
  final rec = ui.PictureRecorder();
  kbPaintScene(Canvas(rec), const Size(390, 844), th, m, s);
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

Future<ByteData> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final img = (await codec.getNextFrame()).image;
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

Future<void> _savePng(ByteData rgba, String path) async {
  final buf = await ui.ImmutableBuffer.fromUint8List(rgba.buffer.asUint8List());
  final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final img = (await (await desc.instantiateCodec()).getNextFrame()).image;
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)..createSync(recursive: true)..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  for (final style in KbStyle.values) {
    for (final mode in KbMode.values) {
      for (final th in kbThemes) {
        final name = '${style.name}/${mode.name}/${th.id}';
        testWidgets(name, (tester) async {
          await tester.runAsync(() async {
            final a = await _render(th, mode, style);
            final b = await _load('$refRoot/$name.png');
            var sum = 0.0, worst = 0.0;
            final diff = ByteData(w * h * 4);
            for (var by = 0; by < h; by += 8) {
              for (var bx = 0; bx < w; bx += 8) {
                var bs = 0.0, n = 0;
                for (var y = by; y < by + 8 && y < h; y++) {
                  for (var x = bx; x < bx + 8 && x < w; x++) {
                    final o = (y * w + x) * 4;
                    var d = 0;
                    for (var c = 0; c < 3; c++) {
                      d += (a.getUint8(o + c) - b.getUint8(o + c)).abs();
                    }
                    bs += d / 3;
                    n++;
                    final v = (d / 3 * 4).clamp(0, 255).toInt();
                    diff..setUint8(o, v)..setUint8(o + 1, 0)..setUint8(o + 2, 0)..setUint8(o + 3, 255);
                  }
                }
                sum += bs;
                if (bs / n > worst) worst = bs / n;
              }
            }
            final mean = sum / (w * h);
            await _savePng(a, 'test/_out/$name.png');
            if (mean > maxMeanDiff || worst > maxBlockDiff) await _savePng(diff, 'test/_out/$name.diff.png');
            expect(mean, lessThan(maxMeanDiff), reason: '$name mean diff ${mean.toStringAsFixed(2)}');
            expect(worst, lessThan(maxBlockDiff), reason: '$name worst block ${worst.toStringAsFixed(1)} — open test/_out/$name.diff.png');
          });
        });
      }
    }
  }
}
