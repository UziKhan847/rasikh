// Screenshots of the design kit's own template screens (kb_screens.dart), laid
// out exactly as `KbGallery` lays them out — CLAUDE_CODE.md step 6, without
// swapping the app's `home:`. Compare each against the HTML prototype at the
// same screen, theme and mode.
//
//   KB_GALLERY=home:sunset:light,me:ocean:dark flutter test test/shots/kb_gallery_shots_test.dart
//
// Each entry is screen:theme:mode[:style]. Output lands in
// test/_out/gallery/<screen>_<theme>_<mode>.png.

import 'dart:io';
import 'dart:ui' as dui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_screens.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_themes.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_ui.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';

import 'shots_support.dart';

Widget _page(String screen, KbUi ui, String themeId) => switch (screen) {
  'home' => KbHomeScreen(ui: ui),
  'learn' => KbLearnScreen(ui: ui),
  'rank' => KbRankScreen(ui: ui),
  'rewards' => KbRewardsScreen(
    ui: ui,
    currentThemeId: themeId,
    onApplyTheme: (_) {},
  ),
  'me' => KbMeScreen(
    ui: ui,
    textSize: 'large',
    onMode: (_) {},
    onStyle: (_) {},
    onTextSize: (_) {},
  ),
  'profile' => KbProfileScreen(ui: ui),
  'lesson' => KbLessonScreen(ui: ui),
  'write' => KbWriteScreen(ui: ui),
  'bingo' => KbBingoScreen(ui: ui),
  'ttt' => KbTttScreen(ui: ui),
  'memory' => KbMemoryScreen(ui: ui),
  'quiz' => KbQuizScreen(ui: ui),
  _ => KbHamzahScreen(ui: ui),
};

void main() {
  final spec = Platform.environment['KB_GALLERY'];
  testWidgets('kit gallery screenshots', (tester) async {
    if (spec == null || spec.isEmpty) return;
    await tester.runAsync(loadShotFonts);
    // The test binding draws shadows unblurred; screenshots need the real thing.
    debugDisableShadows = false;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    for (final entry in spec.split(',')) {
      final parts = entry.split(':');
      final screen = parts[0], themeId = parts[1];
      final mode = KbMode.values.byName(parts[2]);
      final style = parts.length > 3
          ? KbStyle.values.byName(parts[3])
          : KbStyle.vivid;
      final th = kbThemes.firstWhere((t) => t.id == themeId);
      final ui = KbUi(th, mode, style);
      final tab = kbNavItems.any((n) => n.id == screen);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: Material(
                color: kbC(kBlack),
                child: KbBackdrop(
                  theme: th,
                  mode: mode,
                  style: style,
                  motion: false,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _page(screen, ui, themeId)),
                      if (tab)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: KbNavBar(
                            ui: ui,
                            current: screen,
                            onSelect: (_) {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await tester.runAsync(() => boundary.toImage());
      final png = await tester.runAsync(
        () => img!.toByteData(format: dui.ImageByteFormat.png),
      );
      final out = File(
        'test/_out/gallery/${screen}_${themeId}_${mode.name}.png',
      )..createSync(recursive: true);
      out.writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote ${out.path}');
    }
    debugDisableShadows = true; // before the binding checks it — tear-downs run after
  });
}
