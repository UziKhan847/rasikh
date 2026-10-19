// Renders memorize mode mid-page — phone and desktop spread — to PNGs, to
// check its look by eye. Off by default; run with
//   flutter test test/shots/memorize_shots_test.dart --dart-define=SHOTS=/some/dir
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
    test('memorize shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  for (final (name, size, script, verses, words) in [
    ('memorize_phone', const Size(393, 852), 'uthmani', 2, 3),
    ('memorize_spread', const Size(1400, 900), 'uthmani', 9, 2),
    ('memorize_indopak', const Size(393, 852), 'indopak', 3, 4),
  ]) {
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
      s.desktopMode = size.width > 1000 ? 'on' : 'off';
      s.mushafView = 'spread';
      s.mushafScript = script;
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
                child: MushafPageScreen(startPage: 50, script: script)),
          ),
        ),
      ));
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)));
          await tester.pump(const Duration(milliseconds: 80));
        }
      }

      await settle();
      await tester.tap(find.byTooltip('Muṣḥaf settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Memorize from this page'));
      await tester.pumpAndSettle();
      for (var i = 0; i < verses; i++) {
        await tester.tap(find.byTooltip('Rest of the āyah'));
        await tester.pump();
      }
      for (var i = 0; i < words; i++) {
        await tester.tap(find.text('Next word'));
        await tester.pump();
      }
      await settle();
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
