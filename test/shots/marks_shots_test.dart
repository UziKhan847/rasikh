// Renders muṣḥaf pages carrying every kind of word mark, in both scripts and
// a light and a dark paper, for a visual check that the underlines clear the
// kasrahs and the colours read. Off by default; run with
//   flutter test test/shots/marks_shots_test.dart --dart-define=SHOTS=/some/dir
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

void main() {
  if (_out.isEmpty) {
    test('marks shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    await MushafRepo.ensure('indopak');
  });

  // Āyat al-Kursī: one word of each kind — all words with a kasrah, the
  // risk for an underline — a fixed one and a whole-āyah mark.
  void seed(MarksStore m) {
    final b = m.ensureActiveBook('Shots').id;
    m.addMark(b, const WordRef(2, 255, 3), MarkType.mistake);
    m.addMark(b, const WordRef(2, 255, 10), MarkType.tajwid);
    m.addMark(b, const WordRef(2, 255, 15), MarkType.hesitation);
    m.addMark(b, const WordRef(2, 255, 16), MarkType.doubt);
    m.addMark(b, const WordRef(2, 255, 14), MarkType.note, comment: 'x');
    m.addMark(b, const WordRef(2, 255, 19), MarkType.mistake);
    m.fix(b, const WordRef(2, 255, 19));
    m.addMark(b, const WordRef(2, 254, 0), MarkType.mistake);
  }

  for (final script in ['uthmani', 'indopak']) {
    for (final theme in ['light', 'night']) {
      final name = 'marks_${script}_$theme';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final s = AppSettings();
        final p = ProgressStore();
        await s.load();
        await p.load();
        s.onboarded = true;
        s.appTheme = theme;
        s.desktopMode = 'off';
        final m = MarksStore(
            persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
        await m.load();
        seed(m);
        final page = MushafRepo.pageOfWord(
            script, const WordRef(2, 255, 2).globalAyah, 1);
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
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: RepaintBoundary(
                    key: key,
                    child: MushafPageScreen(startPage: page, script: script)),
              ),
            ),
          ),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 2);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('$_out/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
        await m.flush();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
