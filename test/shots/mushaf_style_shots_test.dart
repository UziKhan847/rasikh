// Renders the muṣḥaf style screen (presets and a live page) to PNGs, phone
// and desktop, after picking a preset. Off by default; run with
//   flutter test test/shots/mushaf_style_shots_test.dart --dart-define=SHOTS=/some/dir
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_style_screen.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

void main() {
  if (_out.isEmpty) {
    test('mushaf style shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  // (name, size, preset to tap or null)
  final shots = [
    ('style_phone', const Size(393, 852), null),
    ('style_phone_madani', const Size(393, 852), 'Classic Madani'),
    ('style_desk_indopak', const Size(1400, 900), 'Classic Indo-Pak'),
    ('style_desk_tall_tune', const Size(1400, 3000), 'Turquoise'),
  ];
  for (final (name, size, preset) in shots) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      final p = ProgressStore();
      await s.load();
      await p.load();
      s.onboarded = true;
      s.desktopMode = size.width > 900 ? 'on' : 'off';
      final key = GlobalKey();
      await tester.pumpWidget(SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(s),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: RepaintBoundary(
                key: key,
                child: const MushafStyleScreen()),
          ),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (preset != null) {
        await tester.tap(find.text(preset).first);
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(s.orBorder, isNot('none'));
      }
      if (name.contains('tune')) {
        await tester.tap(find.text('Tuning'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(MushafPagePreview), findsOneWidget);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
