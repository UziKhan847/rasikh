import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/review.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/marks/pages_pdf.dart';

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

  testWidgets('each mark on the pages gets its note and leader, on the '
      'nearer side; filters and "only marked" hold', (tester) async {
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
      expect(sheet.leaders.length, 3, reason: 'one leader per mark');
      for (final (pts, _) in sheet.leaders) {
        // From the word out to the margin it's nearer to.
        final wordX = pts[0], endX = pts[pts.length - 2];
        final toLeft = endX < wordX;
        expect(toLeft, wordX < 595 / 2);
      }
      final bytes = await buildPagesPdf(sheets);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
    await m.flush();
  });
}
