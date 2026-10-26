import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/mushaf_atlas.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The muṣḥaf's swipe path stays cheap: every line is shaped once, nothing
/// is shaped while a finger drags the page (the next pages were prepared in
/// the background), a page change mid-swipe doesn't rebuild the screen or
/// notify progress listeners, word and āyah-marker taps still land, and the
/// precomputed line widths match the fonts. Plus the desktop ↔ phone toggle.
Future<(AppSettings, ProgressStore)> _boot({String desktop = 'off'}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.appMode = 'reader';
  s.desktopMode = desktop;
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

Future<void> _settleAsync(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets the background preparation run to the end.
Future<void> _drainBackground(WidgetTester tester) async {
  for (var i = 0; i < 400 && !MushafLineScheduler.idle; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  expect(MushafLineScheduler.idle, isTrue, reason: 'background work left');
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  setUp(() {
    MushafLineCache.clear();
    MushafLineCache.debugShapesPerKey.clear();
    MushafLineScheduler.reset();
  });

  testWidgets('with the glyph atlas, opening and swiping shapes nothing', (
    tester,
  ) async {
    _phone(tester);
    final (s, p) = await _boot();
    final before = MushafLineCache.debugShaped;
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 50)));
    await _settleAsync(tester);
    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
    }
    expect(MushafLineCache.debugShaped, before);
    expect(MushafLineScheduler.idle, isTrue, reason: 'nothing to prepare');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without the atlas: no line is ever shaped twice', (
    tester,
  ) async {
    MushafAtlas.debugDisabled = true;
    addTearDown(() => MushafAtlas.debugDisabled = false);
    _phone(tester);
    final (s, p) = await _boot();
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 50)));
    await _settleAsync(tester);
    await _drainBackground(tester);
    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
      await _drainBackground(tester);
    }
    expect(MushafLineCache.debugShapesPerKey, isNotEmpty);
    final twice = MushafLineCache.debugShapesPerKey.entries
        .where((e) => e.value > 1)
        .map((e) => e.key);
    expect(twice, isEmpty, reason: 'shaped more than once: $twice');
    // The page sizes came from the precomputed widths, not from shaping.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a drag shapes nothing and rebuilds nothing until it settles', (
    tester,
  ) async {
    _phone(tester);
    final (s, p) = await _boot();
    await tester.pumpWidget(_app(s, p, const MushafPageScreen(startPage: 50)));
    await _settleAsync(tester);
    await _drainBackground(tester);

    var notified = 0;
    p.addListener(() => notified++);
    final before = MushafLineCache.debugShaped;
    // Pages turn right to left: dragging rightwards goes forward.
    final g = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      MushafLineCache.debugShaped,
      before,
      reason: 'lines were shaped mid-drag',
    );
    expect(p.lastMushafPage, isNot(51), reason: 'settled before the end');
    await g.up();
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 51);
    expect(notified, 0, reason: 'a page turn notified progress listeners');
    await tester.pumpWidget(const SizedBox());
  });

  group('taps on a line', () {
    late List<String> calls;
    late MushafTapHandlers handlers;

    setUp(() {
      calls = [];
      handlers = MushafTapHandlers()
        ..onTapWord = ((w) => calls.add('word ${w.ayah}:${w.wordIdx}'))
        ..onLongPressWord = ((w) => calls.add('long ${w.ayah}:${w.wordIdx}'))
        ..onTapVerse = ((a) => calls.add('verse $a'));
    });

    Future<RenderMushafLine> pumpLine(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final lines = MushafRepo.pageSync('uthmani', 2)!;
      final i = lines.indexWhere(
        (l) => l.isText && l.words.any((w) => w.isMarker),
      );
      final line = lines[i];
      final (fs, slotH, _) = mushafPageGeometry(
        'uthmani',
        2,
        lines,
        380,
        600,
        fitWidth: false,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => calls.add('page'),
            child: Center(
              child: MushafLineView(
                handlers: handlers,
                spec: MushafLineSpec(
                  script: 'uthmani',
                  page: 2,
                  index: i,
                  line: line,
                  fontSize: fs,
                  slotH: slotH,
                  targetW: 380,
                  ink: const Color(0xFF000000),
                  accent: const Color(0xFF00AA00),
                  strongBg: const Color(0x3300AA00),
                  verseBg: const Color(0x1100AA00),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.renderObject(find.byType(MushafLineView));
    }

    Offset at(RenderMushafLine r, int token, {double dx = 0}) {
      final (left, right) = r.laidLine!.boxes[token];
      return r.localToGlobal(
        r.textOffset + Offset((left + right) / 2 + dx, r.laidLine!.height / 2),
      );
    }

    // The word's handler fires first, straight from the pointer-up; the
    // page's own tap may follow (the screen ignores that one — see
    // _MushafPageScreenState._onPageTap), so only the first call counts.
    testWidgets('a word, its āyah marker, and the gap beside the marker', (
      tester,
    ) async {
      final r = await pumpLine(tester);
      final words = r.spec.line.words;
      final w = words.indexWhere((x) => !x.isMarker);
      final m = words.indexWhere((x) => x.isMarker);

      calls.clear();
      await tester.tapAt(at(r, w));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.firstOrNull, 'word ${words[w].ayah}:${words[w].wordIdx}');

      calls.clear();
      await tester.tapAt(at(r, m));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.firstOrNull, 'verse ${words[m].ayah}');

      // Just beside the circle still counts as the circle.
      final (left, right) = r.laidLine!.boxes[m];
      calls.clear();
      await tester.tapAt(at(r, m, dx: (right - left) / 2 + 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.firstOrNull, 'verse ${words[m].ayah}');

      calls.clear();
      await tester.longPressAt(at(r, w));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.firstOrNull, 'long ${words[w].ayah}:${words[w].wordIdx}');
    });

    testWidgets('a tap away from the text reaches the page', (tester) async {
      await pumpLine(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, ['page']);
    });
  });

  // The Madani table holds the justified atlas's widths (gen_atlas.py
  // writes it), not the text font's.
  test('the precomputed line widths match the fonts', () {
    for (final script in ['indopak']) {
      for (final page in [1, 2, 50, 300, 600]) {
        final lines = MushafRepo.pageSync(script, page)!;
        MushafGeometry.widestEm(script, page, lines);
        for (final l in lines.where((l) => l.isText)) {
          final live = MushafGeometry.measureLineEm(script, l);
          expect(
            MushafGeometry.lineEm(l),
            closeTo(live, .002),
            reason:
                '$script page $page: regenerate the tables with '
                'flutter test tool/gen_mushaf_widths_test.dart',
          );
        }
      }
    }
  });

  group('desktop ↔ phone layout', () {
    // The modes' homes have no sidebar: the shortcut switches layouts.
    testWidgets('Ctrl+Shift+L switches layouts', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (s, p) = await _boot(desktop: 'on');
      await tester.pumpWidget(_app(s, p, const RootScreen()));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(s.desktopMode, 'off');
      await tester.pump(const Duration(milliseconds: 300)); // settings save
    });

    testWidgets('a phone has no desktop button', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (s, p) = await _boot();
      await tester.pumpWidget(_app(s, p, const RootScreen()));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Switch to the desktop layout (Ctrl+Shift+L)'),
        findsNothing,
      );
    });
  });
}
