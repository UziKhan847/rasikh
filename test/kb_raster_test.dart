import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_app.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_raster.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';

/// The pre-drawn scene images (kb_raster.dart): drawn once, shared, never
/// re-drawn for the keyboard, capped at a size every GPU can hold.

/// The image each on-screen KbRaster shows, in tree order.
List<ui.Image> _images(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(KbRaster),
            matching: find.byType(CustomPaint),
          )
          .evaluate())
    // ignore: avoid_dynamic_calls
    ((e.widget as CustomPaint).painter as dynamic).e.image as ui.Image,
];

Widget _backdrop({Key? key}) => KbBackdrop(
  key: key,
  theme: kbDefaultTheme,
  mode: KbMode.light,
  style: KbStyle.vivid,
  motion: false,
);

void main() {
  testWidgets('two screens showing the same scene share one image', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(child: _backdrop()),
            Positioned.fill(child: _backdrop()),
          ],
        ),
      ),
    );
    final images = _images(tester);
    expect(images, hasLength(2));
    expect(identical(images[0], images[1]), isTrue);
  });

  testWidgets('the keyboard sliding in does not re-draw the scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _backdrop())));
    final before = _images(tester).single;
    // A resizing Scaffold shrinks its body by the inset, frame by frame.
    for (final inset in [60.0, 150.0, 240.0, 300.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
      expect(
        identical(_images(tester).single, before),
        isTrue,
        reason: 'redrawn at inset $inset',
      );
    }
    tester.view.resetViewInsets();
  });

  testWidgets('a resize waits until the size holds still before re-drawing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: _backdrop()),
    );
    final before = _images(tester).single;
    for (final w in [420.0, 460.0, 500.0]) {
      tester.view.physicalSize = Size(w, 844);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(_images(tester).single, before), isTrue);
    }
    await tester.pump(KbRaster.settle);
    await tester.pump();
    final after = _images(tester).single;
    expect(identical(after, before), isFalse);
    expect(after.width, 500);
  });

  testWidgets('no image side goes past the GPU texture limit', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: KbRaster(
            size: const Size(3000, 100),
            cacheKey: 'wide',
            paint: (c, s) => c.drawRect(Offset.zero & s, Paint()),
          ),
        ),
      ),
    );
    final img = _images(tester).single;
    expect(img.width, lessThanOrEqualTo(KbRaster.maxTexture));
    expect(img.width, greaterThan(4000), reason: 'as sharp as the cap allows');
  });

  testWidgets('only the part with something in it is stored', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: KbRaster(
            size: const Size(200, 400),
            cacheKey: 'crop',
            content: const Rect.fromLTRB(0, 300, 200, 400),
            paint: (c, s) => c.drawRect(Offset.zero & s, Paint()),
          ),
        ),
      ),
    );
    final img = _images(tester).single;
    expect((img.width, img.height), (400, 200));
  });
}
