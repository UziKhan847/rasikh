// Renders the muṣḥaf index with marks to PNGs, to check its look by eye.
// Off by default; run with
//   flutter test test/shots/mushaf_index_shots_test.dart --dart-define=SHOTS=/some/dir
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
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/divisions.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_index_sheet.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

void main() {
  if (_out.isEmpty) {
    test('mushaf index shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  for (final (name, tab) in [
    ('index_juz', Division.juz),
    ('index_rub', Division.rub),
    ('index_page', Division.page),
    ('index_surah', Division.surah),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.load();
      s.onboarded = true;
      final m = MarksStore(
          persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
      final b = m.ensureActiveBook('Me').id;
      // A spread of marks over the first juzʼ and Āyat al-Kursī.
      for (final (r, t) in [
        (const WordRef(1, 2, 2), MarkType.tajwid),
        (const WordRef(2, 5, 1), MarkType.mistake),
        (const WordRef(2, 30, 4), MarkType.mistake),
        (const WordRef(2, 30, 6), MarkType.doubt),
        (const WordRef(2, 61, 3), MarkType.hesitation),
        (const WordRef(2, 102, 9), MarkType.note),
        (const WordRef(2, 255, 3), MarkType.mistake),
        (const WordRef(2, 255, 8), MarkType.tajwid),
      ]) {
        m.addMark(b, r, t);
      }
      m.fix(b, const WordRef(1, 2, 2));
      m.addMark(b, const WordRef(2, 3, 2), MarkType.mistake);
      m.fix(b, const WordRef(2, 3, 2));
      final key = GlobalKey();
      await tester.pumpWidget(MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(s),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: SafeArea(
                  child: MushafIndex(
                      script: 'uthmani',
                      currentPage: 22,
                      initial: tab,
                      onPage: (_) {}),
                ),
              ),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 4; i++) {
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
