import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/display_rotation.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/report.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/pages_pdf.dart';
import 'package:rasikh/screens/marks/report_pdf.dart' show marksPdfName;
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// The export: an overlay in portrait, on the dock's side in landscape; by
/// verses as well as pages; its range picked on the muṣḥaf by page, sūrah or
/// verse. And dark mode, a tap away beside the theme button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<(AppSettings, ProgressStore, MarksStore)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..toolHintSeen = true
      ..desktopMode = 'off';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (s, p, m);
  }

  Future<void> pump(WidgetTester tester, AppSettings s, ProgressStore p, MarksStore m,
      {Size size = const Size(390, 800), int page = 497}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MushafPageScreen(home: true, startPage: page, script: 'uthmani'),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> tool(WidgetTester tester, String tip) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tip));
    await tester.pumpAndSettle();
  }

  /// What the picker's pill says.
  String range(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('export-pick-range')), matching: find.byType(Text)))
      .data!;

  // What was chosen, on the sheet: its title, as the route's top.
  final title = find.text('Export');

  testWidgets('portrait: an overlay; the page shows above it and its buttons stay',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tool(tester, 'Export');
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.top, greaterThanOrEqualTo(70), reason: 'the top stays in view, as over the index');
    expect(sheet.bottom, 800);
    final share = tester.getRect(find.text('Share'));
    expect(share.bottom, lessThanOrEqualTo(800), reason: 'the buttons are on screen');
    expect(tester.takeException(), isNull);
    await m.flush();
  });

  testWidgets('landscape: from the side the dock is on', (tester) async {
    final (s, p, m) = await boot();
    addTearDown(() => displayRotationChanges.value = -1);
    await pump(tester, s, p, m, size: const Size(800, 390));
    displayRotationChanges.value = 3;
    await tester.pump();
    await tester.pumpAndSettle();
    await tool(tester, 'Export');
    expect(tester.getTopLeft(title).dx, lessThan(400), reason: 'the dock is on the left');
    expect(tester.takeException(), isNull);
    await m.flush();
  });

  testWidgets('picking on the muṣḥaf: two verses make the range, and the sheet '
      'comes back on them', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tool(tester, 'Export');
    await tester.tap(find.text('Verses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    expect(find.text('Tap the first verse, swipe, tap the last'), findsOneWidget);
    final c = tester.getCenter(find.byType(MushafPageScreen));
    await tester.tapAt(c.translate(0, -200));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    final first = range(tester);
    expect(first, matches(RegExp(r'^\d+:\d+$')));
    await tester.tapAt(c.translate(0, 180));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    final both = range(tester);
    expect(both, matches(RegExp(r'^\d+:\d+ – \d+:\d+$')), reason: both);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);
    expect(find.text('Āyah'), findsNWidgets(2), reason: 'back on verses');
    final (a, b) = (both.split(' – ')[0], both.split(' – ')[1]);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, a.split(':')[1]);
    expect(fields[1].controller!.text, b.split(':')[1]);
    await m.flush();
  });

  testWidgets('picking: a sūrah counts by its word; the bare page chooses a page only',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tool(tester, 'Export');
    await tester.tap(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sūrah'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a word in the first sūrah, swipe, tap one in the last'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget, reason: 'cancelled: the sheet again');
    await m.flush();
  });

  testWidgets('the picker fits on a phone on its side', (tester) async {
    final (s, p, m) = await boot();
    addTearDown(() => displayRotationChanges.value = -1);
    await pump(tester, s, p, m, size: const Size(760, 360));
    await tool(tester, 'Export');
    await tester.ensureVisible(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    for (final t in ['Sūrah', 'Verses', 'Cancel']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await m.flush();
  });

  group('by verses', () {
    late MarksStore m;
    late String b;
    final g = MushafRepo.globalAyahOf;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
      b = m.ensureActiveBook('Zayd').id;
      m.addMark(b, const WordRef(2, 254, 1), MarkType.mistake);
      m.addMark(b, const WordRef(2, 255, 3), MarkType.doubt);
      m.addMark(b, const WordRef(2, 257, 1), MarkType.tajwid);
      m.addMark(b, const WordRef(2, 258, 1), MarkType.tajwid);
    });

    test('the report takes only the marks in them', () {
      final r = buildReport(
          m,
          b,
          ReportOptions(
            query: const ReviewQuery(script: 'uthmani', status: ReviewStatus.any),
            ayahs: (g(2, 255), g(2, 257)),
          ),
          pageOf: (w) => MushafRepo.pageOfWord('uthmani', w.globalAyah, w.word0),
          now: 0);
      expect(r.total, 2);
    });

    test('the pages show only the marks in them', () {
      final e = PagesExport(
          store: m,
          bookId: b,
          script: 'uthmani',
          pages: const [42],
          ayahs: (g(2, 255), g(2, 257)));
      final marks = e.marksByPage.values.expand((x) => x).toList();
      expect(marks.map((x) => x.ref.ayah).toSet(), {255, 257});
    });

    test('the file is named for them', () {
      expect(marksPdfName('Zayd', 42, 43, DateTime(2026, 11, 4), verses: '2.255-3.10'),
          'Zayd_marks_2.255-3.10_2026-11-04.pdf');
    });
  });

  testWidgets('dark mode: a button beside the theme\'s; a tap each way, back to '
      'the dark it was', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    Future<void> tap(String tip) async {
      await tester.tap(find.byTooltip(tip));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tap('Dark');
    expect(s.appTheme, 'night');
    expect(find.byTooltip('Light'), findsOneWidget, reason: 'the fan stays open');
    await tap('Light');
    expect(s.appTheme, 'light');

    s.update(() {
      s.appTheme = 'oled';
      s.darkTheme = 'oled';
    });
    await tester.pumpAndSettle();
    await tap('Light');
    expect(s.appTheme, 'light');
    await tap('Dark');
    expect(s.appTheme, 'oled');

    // In the theme's popover only which dark is left.
    await tap('Theme');
    expect(find.text('Light'), findsNothing);
    expect(find.text('OLED'), findsOneWidget);
    await m.flush();
  });
}
