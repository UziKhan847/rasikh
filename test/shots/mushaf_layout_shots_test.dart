// Renders the 15-line muṣḥaf in each view and script to PNGs, to check the
// page layout by eye. Off by default; run with
//   flutter test test/shots/mushaf_layout_shots_test.dart --dart-define=SHOTS=/some/dir
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
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

void main() {
  if (_out.isEmpty) {
    test('mushaf layout shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  // (name, script, page, size, desktop view or null for phone, theme)
  final shots = [
    ('spread_uthmani', 'uthmani', 51, const Size(1400, 900), 'spread', 'light'),
    ('spread_indopak', 'indopak', 51, const Size(1400, 900), 'spread', 'light'),
    ('spread_uthmani_night', 'uthmani', 300, const Size(1400, 900), 'spread', 'night'),
    ('single_uthmani', 'uthmani', 50, const Size(1400, 900), 'single', 'light'),
    ('fill_uthmani', 'uthmani', 50, const Size(1400, 900), 'fill', 'light'),
    ('phone_uthmani', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('phone_indopak', 'indopak', 50, const Size(393, 852), null, 'light'),
    ('phone_landscape', 'uthmani', 22, const Size(914, 412), null, 'light'),
    ('phone_tajwid', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('phone_tajwid_night', 'indopak', 50, const Size(393, 852), null, 'night'),
    ('phone_landscape_two', 'uthmani', 22, const Size(914, 412), null, 'light'),
    ('opening_uthmani', 'uthmani', 1, const Size(1400, 900), 'spread', 'light'),
    ('opening_indopak', 'indopak', 1, const Size(1400, 900), 'spread', 'light'),
    ('phone_opening', 'uthmani', 1, const Size(393, 852), null, 'light'),
    ('phone_opening_2', 'uthmani', 2, const Size(393, 852), null, 'light'),
  ];
  for (final (name, script, page, size, view, theme) in shots) {
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
      s.appTheme = theme;
      s.desktopMode = view == null ? 'off' : 'on';
      if (view != null) s.mushafView = view;
      s.mushafPhoneSpread = name.endsWith('_two');
      s.mushafTajwid = name.contains('tajwid');
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
                child: MushafPageScreen(startPage: page, script: script)),
          ),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
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
