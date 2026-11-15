import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// A portrait page fills the screen, the same box on every page; on its side
/// pages take the scanned Madani muṣḥaf's proportions, a phone can show two
/// facing pages, and the one-page landscape view scrolls the
/// whole page (paper and frame), not a window inside it.
Future<(AppSettings, ProgressStore)> _boot({bool spread = false}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.desktopMode = 'off';
  s.mushafPhoneSpread = spread;
  return (s, p);
}

Widget _app(AppSettings s, ProgressStore p, Widget home) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 400 && !MushafLineScheduler.idle; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Set<int> _pagesShown(WidgetTester tester) => {
  for (final r in tester.renderObjectList<RenderMushafLine>(
    find.byType(MushafLineView),
  ))
    if (r.hasSize && r.attached) r.spec.page,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  setUp(() {
    MushafLineCache.clear();
    MushafLineScheduler.reset();
  });

  test('every Madani page has a shape from the scan', () {
    for (var p = 1; p <= 604; p++) {
      final r = MushafGeometry.pageRatio('uthmani', p);
      expect(r, isNotNull, reason: 'page $p');
      // The scanned shape, reshaped where DigitalKhatt's lines need it.
      expect(r, inInclusiveRange(.52, .73), reason: 'page $p');
    }
    expect(MushafGeometry.pageRatio('indopak', 10), isNull);
    // The box's text area has exactly that shape.
    for (final p in [1, 50, 575]) {
      final box = MushafGeometry.pageBox(
        const Size(380, 700),
        'uthmani',
        look: MushafLook.framed,
        header: true,
        page: p,
      );
      final area = MushafGeometry.textArea(box, look: MushafLook.framed, header: true);
      expect(
        area.width / area.height,
        closeTo(MushafGeometry.pageRatio('uthmani', p)!, 1e-6),
      );
    }
  });

  testWidgets('every portrait page takes one box, filling the height: a wide '
      'page and a narrow one share their line grid', (tester) async {
    _view(tester, const Size(393, 852));
    final (s, p) = await _boot();
    Future<(double, double)> gridOf(int page) async {
      await tester.pumpWidget(_app(s, p, MushafPageScreen(key: ValueKey(page), startPage: page)));
      await _settle(tester);
      final line = tester
          .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
          .firstWhere((r) => r.spec.page == page);
      return (line.spec.slotH, line.spec.targetW);
    }

    final (slot30, _) = await gridOf(30);
    final (slot31, _) = await gridOf(31);
    expect(slot31, closeTo(slot30, .01));
    expect(slot30 * 15, greaterThan(852 * .8), reason: 'fills the screen');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('page 2 draws al-Fātiḥah\'s basmala, out of reach of taps', (tester) async {
    _view(tester, const Size(393, 852));
    final (s, p) = await _boot();
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 2)));
    await _settle(tester);
    final view = find.byWidgetPredicate((w) =>
        w is MushafLineView && w.spec.page == 2 && w.spec.index == 1);
    expect(view, findsOneWidget);
    expect(tester.widget<MushafLineView>(view).spec.line.firstTok,
        MushafRepo.pageSync('uthmani', 1)![1].firstTok);
    expect(find.ancestor(of: view, matching: find.byType(IgnorePointer)), findsWidgets);
    expect(find.text(MushafRepo.bismillahChar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a phone on its side shows two facing pages and swipes both', (
    tester,
  ) async {
    _view(tester, const Size(852, 393));
    final (s, p) = await _boot(spread: true);
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 50)));
    await _settle(tester);
    expect(_pagesShown(tester), containsAll([49, 50]));
    expect(find.textContaining('Pages 49 – 50'), findsOneWidget);

    // Pages turn right to left: dragging rightwards goes forward a spread.
    await tester.fling(find.byType(PageView), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 51);
    expect(_pagesShown(tester), containsAll([51, 52]));

    // Back to one page across the width, on the same page.
    await tester.tap(find.byTooltip('Fill width — scroll down'));
    await _settle(tester);
    expect(s.mushafPhoneSpread, isFalse);
    expect(_pagesShown(tester), contains(51));
    expect(mushafLastViewport!.$2, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one page on its side scrolls paper and frame together', (
    tester,
  ) async {
    _view(tester, const Size(852, 393));
    final (s, p) = await _boot();
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 50)));
    await _settle(tester);
    final (area, fitWidth) = mushafLastViewport!;
    expect(fitWidth, isTrue);
    // The page's text is the scanned shape at the full width, far taller
    // than the screen…
    final line = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .firstWhere((r) => r.spec.page == 50);
    final textH = line.spec.slotH * MushafRepo.pageSync('uthmani', 50)!.length;
    expect(
      area.width / textH,
      closeTo(MushafGeometry.pageRatio('uthmani', 50)!, .01),
    );
    expect(textH, greaterThan(393));
    // …and the scroll view holds the whole paper, not just the text.
    final scroll = find.byType(SingleChildScrollView).first;
    final paperH = tester.getSize(
      find.descendant(of: scroll, matching: find.byType(Container)).first,
    );
    expect(paperH.height, greaterThan(textH));
    await tester.pumpWidget(const SizedBox());
  });
}
