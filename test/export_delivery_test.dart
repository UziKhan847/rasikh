import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/export_delivery.dart';
import 'package:rasikh/screens/marks/export_sheet.dart';

import 'test_support.dart';

/// Export as images, and its choices in the sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('an image is named for the page it shows, else numbered', () {
    const pdf = 'Zayd_marks_10-13_2026-11-05.pdf';
    expect(exportImageName(pdf, 0, 4, 10, 'png'), 'Zayd_marks_10_2026-11-05.png');
    expect(exportImageName(pdf, 3, 4, 13, 'jpg'), 'Zayd_marks_13_2026-11-05.jpg');
    expect(exportImageName(pdf, 1, 3, null, 'png'), 'Zayd_marks_10-13_2026-11-05_2.png');
    expect(exportImageName(pdf, 0, 1, null, 'png'), 'Zayd_marks_10-13_2026-11-05.png');
    expect(exportImageName('زيد_علي_marks_2.255-3.10_2026-11-05.pdf', 0, 1, 42, 'png'),
        'زيد_علي_marks_42_2026-11-05.png');
  });

  test('a JPEG comes out the size it went in, on white', () {
    // Half transparent over half solid red.
    final px = Uint8List(4 * 4 * 4);
    for (var i = 0; i < 16; i++) {
      px[i * 4] = 255;
      px[i * 4 + 3] = i < 8 ? 0 : 255;
    }
    final out = img.decodeJpg(encodeExportJpg((px, 4, 4)))!;
    expect((out.width, out.height), (4, 4));
    expect(out.getPixel(0, 0).g, greaterThan(200), reason: 'transparent: white');
    expect(out.getPixel(0, 3).g, lessThan(90), reason: 'solid: red');
  });

  testWidgets('PDF has Print; an image has none, and the choice is kept', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Zayd').id;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () =>
                showExportSheet(c, store: m, bookId: b, script: 'uthmani', currentPage: 10),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget, reason: 'a phone shares');
    expect(find.text('Save As…'), findsNothing);
    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();
    expect(find.text('Print'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
    await m.flush();
  });

  testWidgets('a computer saves as, or opens', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Zayd').id;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () =>
                showExportSheet(c, store: m, bookId: b, script: 'uthmani', currentPage: 10),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Save As…'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    await m.flush();
  });
}
