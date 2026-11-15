import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/export_sheet.dart';
import 'package:rasikh/screens/marks/pages_pdf.dart';
import 'package:rasikh/screens/marks/report_pdf.dart' show marksPdfName;

import 'test_support.dart';

/// The muṣḥaf's pages as a PDF: which pages a sūrah or juzʼ takes, which
/// marks go on them, and each mark's note in the nearer margin.
void main() {
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('a sūrah\'s and a juzʼ\'s pages', () {
    expect(pagesOfSurah('uthmani', 1), [1]);
    expect(pagesOfSurah('uthmani', 2), [for (var p = 2; p <= 49; p++) p]);
    expect(pagesOfJuz('uthmani', 1), [for (var p = 1; p <= 21; p++) p]);
  });

  test('an export\'s name: whose, marks, its pages, the date', () {
    final d = DateTime(2026, 11, 4);
    expect(marksPdfName('Zayd', 570, 573, d), 'Zayd_marks_570-573_2026-11-04.pdf');
    expect(marksPdfName('Zayd', 7, 7, d), 'Zayd_marks_7-7_2026-11-04.pdf');
    expect(marksPdfName('زيد علي', 1, 2, d), 'زيد_علي_marks_1-2_2026-11-04.pdf');
    expect(marksPdfName('a/b: c?', 1, 2, d), 'a_b_c_marks_1-2_2026-11-04.pdf');
    expect(marksPdfName(' ', 1, 2, d), 'Rasikh_marks_1-2_2026-11-04.pdf');
  });

  testWidgets('Pages + report, the default, can choose "only pages with marks" '
      'too', (tester) async {
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
                showExportSheet(c, store: m, bookId: b, script: 'uthmani', currentPage: 570),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('The pages numbered, then the report'), findsOneWidget);
    expect(find.text('Only pages with marks'), findsOneWidget);
    await m.flush();
  });

  testWidgets('typing one end of the range leaves the other be', (tester) async {
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
            onPressed: () => showPagesExportSheet(c,
                store: m, bookId: b, script: 'uthmani', currentPage: 450),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final from = find.widgetWithText(TextField, 'From page');
    final to = find.widgetWithText(TextField, 'To page');
    String text(Finder f) => tester.widget<TextField>(f).controller!.text;
    // On the way from 450 to 455: 45, then 455.
    await tester.enterText(to, '45');
    await tester.pump();
    expect(text(from), '450');
    expect(find.text('6 pages'), findsNothing);
    await tester.enterText(to, '455');
    await tester.pump();
    expect(text(from), '450');
    expect(find.text('6 pages'), findsOneWidget);
    // Either way round.
    await tester.enterText(from, '460');
    await tester.pump();
    expect(find.text('6 pages'), findsOneWidget);
    await tester.enterText(to, '700');
    await tester.pump();
    expect(find.text('1–604'), findsOneWidget);
    expect(find.text('No pages to export'), findsOneWidget);
    await m.flush();
  });

  testWidgets('each mark on the pages is numbered on its word and listed '
      'beside the page; filters and "only marked" hold', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Zayd').id;
    m.addMark(b, const WordRef(2, 33, 2), MarkType.tajwid, comment: '2 counts');
    m.addMark(b, const WordRef(2, 31, 4), MarkType.mistake);
    m.addMark(b, const WordRef(2, 34, 0), MarkType.hesitation); // the āyah
    m.addMark(b, const WordRef(2, 255, 3), MarkType.doubt); // page 42
    late BuildContext ctx;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
    final e = PagesExport(store: m, bookId: b, script: 'uthmani', pages: [5, 6, 7]);
    expect(e.marksByPage[6]!.length, 3);
    expect(PagesExport(store: m, bookId: b, script: 'uthmani', pages: [5, 6, 7],
            onlyMarked: true)
        .chosenPages(), [6]);
    expect(PagesExport(store: m, bookId: b, script: 'uthmani', pages: [6],
            types: {MarkType.tajwid}).marksByPage[6]!.length, 1);
    expect(PagesExport(store: m, bookId: b, script: 'uthmani', pages: [6],
            status: ReviewStatus.fixed).marksByPage[6], isNull);

    await tester.runAsync(() async {
      final sheets = await preparePages(ctx, e, [6]);
      final sheet = sheets.single;
      // Each mark numbered on its word, in reading order (2:31, 2:33, 2:34),
      // and listed beside the page under its number; no lines between.
      expect([for (final b in sheet.badges) b.$3], [1, 2, 3]);
      expect([for (final n in sheet.notes) n.$1], [1, 2, 3]);
      final ys = [for (final b in sheet.badges) b.$2];
      expect(ys[0], lessThanOrEqualTo(ys[1]), reason: 'down the page in order');
      for (final (bx, by, _, _) in sheet.badges) {
        expect(bx, inInclusiveRange(sheet.pageX, sheet.pageX + sheet.page.width + 6));
        expect(by, inInclusiveRange(sheet.pageY, sheet.pageY + sheet.page.height));
      }
      final panel = sheet.panel!;
      expect(panel.left, greaterThanOrEqualTo(sheet.pageX + sheet.page.width),
          reason: 'beside the page, not over it');
      expect(panel.right, lessThanOrEqualTo(595));
      expect(sheet.page.height, greaterThan(560));
      final bytes = await buildPagesPdf(sheets);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      const keep = String.fromEnvironment('PAGES_PDF');
      if (keep.isNotEmpty) File(keep).writeAsBytesSync(bytes);
    });
    await m.flush();
  });
}
