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

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/memorize.dart';
import 'package:rasikh/screens/mushaf/memorize_cards_screen.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

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

  testWidgets('memorize_cards', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    final m = MarksStore(
        persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Me').id;
    m.addMark(b, const WordRef(2, 255, 3), MarkType.mistake);
    m.addMark(b, const WordRef(2, 255, 6), MarkType.doubt);
    final c = MemorizeController.startAt('uthmani', 42);
    final key = GlobalKey();
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
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
                key: key, child: MemorizeCardsScreen(controller: c)),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    // Into Āyat al-Kursī, eight words in.
    while (c.viewAyah < MushafRepo.globalAyahOf(2, 255)) {
      c.nextVerse();
    }
    c.prevVerse();
    for (var i = 0; i < 9; i++) {
      c.nextWord();
    }
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 1.5);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$_out/memorize_cards.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
