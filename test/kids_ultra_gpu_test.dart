import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_hifi.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_raster.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_themes.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

/// Ultra's GPU budget: its light (and the sun's bloom) is screened onto the
/// scene with cheap blends only — no `screen` draw, no offscreen layer — the god
/// rays come from an image re-drawn 4 times a second, and a lesson on Ultra
/// gets the still touches baked into its one scene image.
final _ocean = kbThemes.firstWhere((t) => t.id == 'ocean');
const _size = Size(390, 844);

/// Counts what the light painter asks of the canvas.
class _CountingCanvas implements Canvas {
  final layers = <BlendMode>[];
  final blends = <BlendMode>[];
  final images = <ui.Image>{};

  /// Images drawn at least a screen wide: the god rays.
  final rays = <ui.Image>{};

  /// The blend of every image draw that carried a colour filter. Impeller draws
  /// an image with a colour matrix through a fast path that IGNORES the blend
  /// mode (always normal blending), so any other blend here is a bug on
  /// phones that the Skia-based tests cannot show: the halos came out as black
  /// squares.
  final filtered = <BlendMode>[];

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers.add(paint.blendMode);

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    images.add(image);
    // (the light itself — its inverse is drawn alongside it)
    if (dst.width >= _size.width && paint.blendMode == BlendMode.plus) {
      rays.add(image);
    }
    blends.add(paint.blendMode);
    if (paint.colorFilter != null) filtered.add(paint.blendMode);
  }

  @override
  void drawOval(Rect rect, Paint paint) => blends.add(paint.blendMode);

  @override
  void drawPath(Path path, Paint paint) => blends.add(paint.blendMode);

  @override
  void drawAtlas(
    ui.Image atlas,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    blends.add(paint.blendMode);
    if (paint.colorFilter != null) filtered.add(paint.blendMode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

KbFxSystem _lit({double t = 3}) {
  final fx = KbFxSystem()
    ..ultra = true
    ..t = t
    ..sun = const Offset(300, 120);
  fx.ensure(
    _ocean,
    KbMode.light,
    kbPalette(_ocean, KbMode.light, KbStyle.vivid),
    _size.width,
    _size.height,
  );
  return fx;
}

Future<Uint8List> _render(void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  return (await img.toByteData())!.buffer.asUint8List();
}

void main() {
  group('the Ultra light pass', () {
    test('uses only cheap blends, and no offscreen layer', () {
      for (final t in [3.0, 3.3, 7.1]) {
        final fx = _lit(t: t);
        final c = _CountingCanvas();
        KbFxLightPainter(fx, _ocean).paint(c, _size);
        expect(c.layers, isEmpty, reason: 'an offscreen layer per frame');
        expect(c.rays, isNotEmpty, reason: 'the rays are drawn');
        expect(c.images.length, greaterThan(1), reason: 'and glints or halos');
        expect(
          c.blends.toSet().difference({BlendMode.modulate, BlendMode.plus}),
          isEmpty,
          reason: 'an advanced blend has to read the screen back',
        );
        expect(c.filtered, isEmpty, reason: 'see _CountingCanvas.filtered');
        fx.dispose();
      }
    });

    test('the god rays are re-drawn 4 times a second', () {
      final fx = _lit(t: 0);
      final c = _CountingCanvas();
      final painter = KbFxLightPainter(fx, _ocean, dpr: 3);
      for (var f = 0; f <= 120; f++) {
        fx.t = f / 120; // a 120 Hz screen, one second
        painter.paint(c, _size);
      }
      expect(c.rays.length, inInclusiveRange(4, 5));
      fx.dispose();
    });

    test('a sunless scene (dark) draws no rays, only the halos', () {
      final fx = _lit()..sun = null;
      final c = _CountingCanvas();
      KbFxLightPainter(fx, _ocean).paint(c, _size);
      expect(c.rays, isEmpty);
      expect(c.layers, isEmpty);
      fx.dispose();
    });

    for (final (fade, tint) in [
      (1.0, false),
      (.5, false),
      (1.0, true),
      (.5, true),
    ]) {
      testWidgets('a screen layer gives screen\'s pixels from two cheap draws, '
          'with no colour filter on either (opacity $fade, shimmer $tint)', (
        tester,
      ) async {
        // A light of colour s and alpha a over an opaque backdrop d.
        const d = Color(0xFF406080), s = Color(0xFFFFD0A0), a = .6;
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: d)),
                      Positioned.fill(
                        child: KbRaster(
                          cacheKey: 'screen-test',
                          blendMode: BlendMode.screen,
                          opacity: ValueNotifier(fade),
                          liveMatrix: tint
                              ? ValueNotifier(kbHueBright(0, 1))
                              : null,
                          paint: (c, sz) => c.drawRect(
                            Offset.zero & sz,
                            Paint()..color = s.withValues(alpha: a),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final px = (await tester.runAsync(() async {
          final img = await boundary.toImage();
          return (await img.toByteData())!.buffer.asUint8List();
        }))!;
        final i = (20 * 40 + 20) * 4;
        for (final (ch, dv, sv) in [
          (0, d.r, s.r),
          (1, d.g, s.g),
          (2, d.b, s.b),
        ]) {
          final sp = sv * a * fade, want = sp + dv * (1 - sp);
          expect(px[i + ch], closeTo(want * 255, 2), reason: 'channel $ch');
        }

        final c = _CountingCanvas();
        tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(KbRaster),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
            .paint(c, const Size(40, 40));
        expect(c.blends, [BlendMode.modulate, BlendMode.plus]);
        expect(c.filtered, isEmpty, reason: 'see _CountingCanvas.filtered');
      });
    }
  });

  group('a lesson on Ultra', () {
    test('its still scene adds rim, mist and vignette to High\'s', () async {
      final high = await _render(
        (c) => kbPaintScene(c, _size, _ocean, KbMode.light, KbStyle.vivid),
      );
      final still = await _render(
        (c) => kbPaintSceneStill(c, _size, _ocean, KbMode.light, KbStyle.vivid),
      );
      var changed = 0;
      for (var i = 0; i < high.length; i += 4) {
        if ((high[i] - still[i]).abs() > 2) changed++;
      }
      expect(changed, greaterThan(high.length ~/ 4 ~/ 20));
    });

    Future<void> pumpLesson(WidgetTester tester, KidsDetail detail) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.load();
      s.kidsMode = true;
      s.kidsDetail = detail;
      await tester.pumpWidget(
        SettingsScope(
          settings: s,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const KidsBackdrop(child: Text('lesson')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('paints the still scene, with nothing of Ultra that moves', (
      tester,
    ) async {
      await pumpLesson(tester, KidsDetail.ultra);
      expect(
        tester.widget<KbBackdrop>(find.byType(KbBackdrop)).ultraStill,
        isTrue,
      );
      for (final k in ['kb.fx', 'kb.fxLight', 'kb.grain', 'kb.vignette']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      expect(find.byType(ColorFiltered), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('High keeps the plain scene', (tester) async {
      await pumpLesson(tester, KidsDetail.high);
      expect(
        tester.widget<KbBackdrop>(find.byType(KbBackdrop)).ultraStill,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
