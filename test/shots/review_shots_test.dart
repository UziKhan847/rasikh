// Renders review mode — the muṣḥaf with a mark in focus, and a verse card —
// to PNGs, to check its look by eye. Off by default; run with
//   flutter test test/shots/review_shots_test.dart --dart-define=SHOTS=/some/dir
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
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/review_cards_screen.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

void main() {
  if (_out.isEmpty) {
    test('review shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  for (final (name, cards, size) in [
    ('review_mushaf', false, const Size(393, 852)),
    ('review_card', true, const Size(393, 852)),
    ('review_mushaf_desktop', false, const Size(1400, 900)),
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
      final m = MarksStore(
          persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
      final b = m.ensureActiveBook('Me').id;
      m.addMark(b, const WordRef(2, 255, 3), MarkType.mistake,
          comment: 'Lengthen the madd: al-ḥayyu');
      m.addMark(b, const WordRef(2, 255, 8), MarkType.doubt);
      m.addMark(b, const WordRef(2, 255, 14), MarkType.tajwid);
      m.addMark(b, const WordRef(2, 256, 2), MarkType.hesitation);
      final c = ReviewController.start(m, b, const ReviewQuery());
      final page = MushafRepo.pageOfWord('uthmani',
          const WordRef(2, 255, 3).globalAyah, 2);
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
                key: key,
                child: cards
                    ? ReviewCardsScreen(controller: c, script: 'uthmani')
                    : MushafPageScreen(
                        startPage: page, script: 'uthmani', review: c),
              ),
            ),
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
      c.end();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
