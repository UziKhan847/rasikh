// Screenshots of the real Kids Mode screens at the design's 390×844 @1x, with the
// app's real fonts loaded — for side-by-side comparison against the design
// prototype (design_handoff_flutter/source/Kids Backdrops.dc.html).
//
// Not part of the normal suite (it writes files and proves nothing on its own):
//
//   KIDS_SHOTS=home:sunset:light flutter test test/shots/kids_shots_test.dart
//
// Each entry is screen:theme:mode[:detail[:height]], comma-separated (a taller
// height shows a long page whole). Output lands in
// test/_out/shots/<screen>_<theme>_<mode>.png.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_desktop_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import '../kids_test_support.dart';
import 'kids_shots_screens.dart';
import 'shots_support.dart';

void main() {
  final spec = Platform.environment['KIDS_SHOTS'];
  testWidgets('kids screenshots', (tester) async {
    if (spec == null || spec.isEmpty) return;
    await tester.runAsync(loadShotFonts);
    // The test binding draws shadows unblurred; screenshots need the real thing.
    debugDisableShadows = false;
    useReducedMotion(tester);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final entry in spec.split(',')) {
      final parts = entry.split(':');
      final screen = parts[0], theme = parts[1], mode = parts[2];
      final detail = parts.length > 3 && parts[3].isNotEmpty ? KidsDetail.values.byName(parts[3]) : KidsDetail.high;
      final height = parts.length > 4 ? double.parse(parts[4]) : 844.0;
      // 'desk' is the desktop shell at a laptop size.
      final desk = screen == 'desk';
      tester.view.physicalSize = desk ? const Size(1280, 800) : Size(390, height);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings
        ..desktopMode = desk ? 'on' : 'off'
        ..kidsMode = true
        ..kidsThemeMode = mode
        ..kidsDetail = detail
        ..kidsTextScale = 1.0;
      // 'profile' is a brand-new install (the New Profile form); 'who' has
      // children but none chosen yet (the Who's learning grid).
      if (screen != 'profile') {
        settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Wazzup', avatar: '🐪'));
        settings.addKidsProfile(KidsProfile(id: 'p2', name: 'walla', avatar: '🐨'));
        for (final p in settings.kidsProfiles) {
          p.theme = theme == 'kids' ? 'kids' : 'kids_$theme';
        }
        settings.activeKidsProfileId = screen == 'who' ? null : 'p1';
        // The equipped theme is one the child bought — recorded before the
        // shell loads, which takes off anything a profile does not own.
        if (theme != 'kids') {
          for (final id in ['p1', 'p2']) {
            final store = ProgressStore(profileId: id);
            await store.load();
            store.buyShopItem('kids_$theme', 0);
          }
        }
      }

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: SettingsScope(
          settings: settings,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: desk ? const KidsDesktopShell() : const KidsShell(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await seedAndOpen(tester, screen);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200)); // SVG decode
      });
      await tester.pump();

      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await tester.runAsync(() => boundary.toImage());
      final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
      final out = File('test/_out/shots/${screen}_${theme}_$mode${height == 844 ? '' : '_tall'}.png')..createSync(recursive: true);
      out.writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote ${out.path}');
    }
    debugDisableShadows = true; // before the binding checks it — tear-downs run after
  });
}
