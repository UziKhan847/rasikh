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

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

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
    ('classic_border_madani', 'uthmani', 50, const Size(1400, 900), 'spread', 'light'),
    ('classic_border_indopak', 'indopak', 50, const Size(1400, 900), 'spread', 'light'),
    ('classic_indopak', 'indopak', 51, const Size(1400, 900), 'spread', 'light'),
    ('phone_classic_border_madani', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('phone_classic_border_indopak', 'indopak', 50, const Size(393, 852), null, 'light'),
    ('classic_indopak_tawbah', 'indopak', 187, const Size(1400, 900), 'single', 'light'),
    ('phone_classic_indopak_fatiha', 'indopak', 1, const Size(393, 852), null, 'light'),
    ('phone_modern_indopak_fatiha', 'indopak', 1, const Size(393, 852), null, 'light'),
    ('darkmono_border_spread', 'uthmani', 50, const Size(1400, 900), 'spread', 'night'),
    ('phone_darkmono_border_indopak', 'indopak', 50, const Size(393, 852), null, 'oled'),
    ('tile1_spread', 'uthmani', 50, const Size(1400, 900), 'spread', 'light'),
    ('phone_tile2', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('tile3_indopak_spread', 'indopak', 50, const Size(1400, 900), 'spread', 'light'),
    ('mix_spread', 'uthmani', 50, const Size(1400, 900), 'spread', 'light'),
    ('phone_mix_indopak', 'indopak', 50, const Size(393, 852), null, 'light'),
    ('classic_border_madani_tawbah', 'uthmani', 187, const Size(1400, 900), 'single', 'light'),
    ('thin1_coloured_spread', 'uthmani', 50, const Size(1400, 900), 'spread', 'light'),
    ('phone_thin2', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('monotile_spread', 'uthmani', 50, const Size(1400, 900), 'spread', 'light'),
    ('phone_monotile_night', 'indopak', 50, const Size(393, 852), null, 'night'),
    // Each script's printed look, as it comes (5: a ḥizb quarter on it).
    ('print_madani_spread', 'uthmani', 5, const Size(1400, 900), 'spread', 'light'),
    ('print_madani_phone', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('print_madani_lantern2', 'uthmani', 5, const Size(1400, 900), 'spread', 'light'),
    ('print_indopak_spread', 'indopak', 50, const Size(1400, 900), 'spread', 'light'),
    ('print_indopak_phone', 'indopak', 50, const Size(393, 852), null, 'light'),
    // The Madani default, the printed Madani preset, and edge to edge.
    ('default_madani_phone', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('default_madani_opening', 'uthmani', 2, const Size(393, 852), null, 'light'),
    ('madaniprint_phone', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('edge_madani_phone', 'uthmani', 50, const Size(393, 852), null, 'light'),
    ('edge_indopak_phone', 'indopak', 50, const Size(393, 852), null, 'light'),
    ('edge_madani_single', 'uthmani', 50, const Size(1400, 900), 'single', 'light'),
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
      // The look being set below is the shot's script's.
      s.mushafScript = script;
      if (RegExp(r'^(print|default|edge|madaniprint)').hasMatch(name)) {
        if (name.contains('lantern2')) s.orMargin = 'lantern2';
        final st = s.styleFor(script);
        if (name.startsWith('edge')) st.edge = true;
        if (name.startsWith('madaniprint')) {
          st
            ..header = 'madaniColoured'
            ..border = 'thinnest3'
            ..margin = 'lantern1'
            ..head = 'frame'
            ..paper = 'madani';
        }
      } else {
      s.orBorder = name.contains('border') ? 'auto' : 'none';
      if (name.contains('_modern')) {
        s.orHeader = 'rosette';
        s.orMarker = 'font';
        s.orMargin = 'none';
      }
      // The tiled presets: their header, frame and colours, the lantern.
      final tile = RegExp(r'tile(\d)').firstMatch(name)?.group(1);
      if (tile != null) {
        s.orHeader = 'tile$tile';
        s.orBorder = 'tile$tile';
        s.orMargin = 'lantern1';
        s.mushafPaper = 'tile$tile';
      }
      // The thin frames, the coloured header, and Mono with colour artwork.
      final thin = RegExp(r'thin(\d)').firstMatch(name)?.group(1);
      if (thin != null) {
        s.orBorder = 'thin$thin';
        s.mushafPaper = 'tile$thin';
      }
      if (name.contains('coloured')) s.orHeader = 'madaniColoured';
      if (name.contains('monotile')) {
        s.orHeader = 'tile1';
        s.orBorder = 'tile1';
        s.mushafPaper = 'mono';
        s.mushafPaperDark = 'mono';
      }
      // A mixed set: the other script's header and circle in a tiled frame.
      if (name.contains('mix')) {
        final other = script == 'indopak' ? 'madani' : 'indopak';
        s.orHeader = other;
        s.orMarker = other;
        s.orBorder = 'tile1';
        s.orMargin = 'text';
        s.mushafPaper = 'madani';
      }
      if (name.contains('darkmono')) s.mushafPaperDark = 'mono';
      if (name.contains('border_madani')) s.mushafPaper = 'madani';
      }
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
