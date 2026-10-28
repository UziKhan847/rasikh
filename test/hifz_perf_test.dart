import 'package:flutter/material.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/hifz_dock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/hifz_layout.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import 'test_support.dart';

/// The Hifẓ home's budgets: a tool turned on swaps what a slot shows —
/// the pages keep their place and size and aren't rebuilt; a mark repaints
/// its own page's lines and rebuilds nothing; an unrelated setting leaves
/// the pages be. (Landscape used to resize both pages for a tool's row.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<(AppSettings, MarksStore)> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..appMode = 'hifz'
      ..desktopMode = size.width > 1000 ? 'on' : 'off';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
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
            home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
          ),
        ),
      ),
    ));
    await settle(tester);
    return (s, m);
  }

  /// Where each line on screen is, and how big.
  List<Rect> lineRects(WidgetTester tester) => [
        for (final e in find.byType(MushafLineView).evaluate())
          if ((e.renderObject! as RenderBox).attached)
            (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
                (e.renderObject! as RenderBox).size,
      ];

  for (final (label, size) in [
    ('portrait', const Size(393, 852)),
    ('phone landscape', const Size(914, 412)),
    ('desktop', const Size(1400, 900)),
  ]) {
    testWidgets('$label: tools come and go; the pages stay put', (tester) async {
      await pump(tester, size);
      final before = lineRects(tester);
      expect(before, isNotEmpty);
      var builds = 0;
      debugOnRebuildDirtyWidget = (e, _) {
        if (e.widget.runtimeType.toString() == '_MushafPageView') builds++;
      };
      for (final tool in ['Comment', 'Eraser', 'Recitation']) {
        await tester.tap(find.byTooltip(tool));
        await settle(tester);
        expect(lineRects(tester), before, reason: '$tool on: the pages moved');
        await tester.tap(find.text('Done'));
        await settle(tester);
      }
      expect(builds, 0, reason: 'a tool rebuilt the pages');
      await tester.tap(find.byTooltip('Memorize'));
      await settle(tester);
      expect(lineRects(tester), before, reason: 'memorize moved the pages');
    });
  }

  testWidgets('landscape: a swipe in the empty margin turns the page', (tester) async {
    await pump(tester, const Size(1400, 900));
    final before = lineRects(tester).length;
    expect(before, greaterThan(0));
    // The page under a point in the middle of the spread.
    int pageAt(Offset at) => tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .firstWhere((r) =>
            r.attached && (r.localToGlobal(Offset.zero) & r.size).contains(at))
        .spec
        .page;
    const mid = Offset(500, 450);
    final pageBefore = pageAt(mid);
    // Right of the spread, left of the dock: no page there, still the pager.
    await tester.flingFrom(const Offset(1300, 450), const Offset(400, 0), 2000);
    await settle(tester);
    expect(pageAt(mid), isNot(pageBefore), reason: 'the spread turned');
  });

  testWidgets('turned straight from one side to the other (same window '
      'size), the dock follows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('qiraah/display');
    var rotation = 1; // camera on the left
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => rotation);
    await pump(tester, const Size(914, 412));
    double dockX() => tester.getTopLeft(find.byType(HifzDock)).dx;
    expect(dockX(), greaterThan(400), reason: 'on the right');
    // Android reports the turn; nothing else changes.
    rotation = 3;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('rotation', 3)),
        (_) {});
    await settle(tester);
    expect(dockX(), lessThan(10), reason: 'on the left');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a mark repaints its own page, rebuilding nothing', (tester) async {
    final (_, m) = await pump(tester, const Size(1400, 900));
    var builds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget.runtimeType.toString() == '_MushafPageView') builds++;
    };
    // A word on page 50.
    final (first, _) = MushafRepo.pageTokens('uthmani', 50);
    final (g, w) = MushafRepo.tokenAt('uthmani', first + 3);
    RenderMushafLine.debugPaints = 0;
    m.addMark(m.activeBook!.id, WordRef.fromGlobal(g, w), MarkType.mistake);
    await tester.pump();
    expect(builds, 0, reason: 'a mark rebuilt a page');
    // The marked line's page repaints (its lines share a layer); the
    // facing page doesn't.
    expect(RenderMushafLine.debugPaints, inInclusiveRange(1, 15),
        reason: 'more than one page repainted');
    await m.flush();
  });

  testWidgets('a setting the pages don\'t show leaves them be', (tester) async {
    final (s, _) = await pump(tester, const Size(1400, 900));
    var builds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget.runtimeType.toString() == '_MushafPageView') builds++;
    };
    s.update(() => s.playbackSpeed = 1.25);
    await tester.pump();
    expect(builds, 0);
    await tester.pump(const Duration(milliseconds: 400)); // the save
  });

  group('HifzLayout', () {
    Size box(Size a) {
      // Pages 0.62 as wide as tall, bound by whichever runs out first.
      final w = a.height * .62 < a.width ? a.height * .62 : a.width;
      return Size(w, w / .62);
    }

    test('a laptop: the bar\'s slot is beside the dock', () {
      final l = HifzLayout.resolve(const Size(1400, 900), EdgeInsets.zero, pageBox: box);
      expect(l.landscape, isTrue);
      expect(l.slotAxis, Axis.vertical);
      expect(l.slot.right, lessThanOrEqualTo(l.dock.left));
      // The pages' area runs to the dock (a swipe anywhere turns the page);
      // the spread keeps clear of the slot.
      expect(l.pager.right, lessThanOrEqualTo(l.dock.left));
      expect(l.pager.right - l.pagesInset.right, lessThanOrEqualTo(l.slot.left));
    });

    test('held with the camera on the right: the dock on the left', () {
      final l = HifzLayout.resolve(const Size(1400, 900), EdgeInsets.zero,
          pageBox: box, dockLeft: true);
      expect(l.dock.left, 0);
      expect(l.slot.left, greaterThanOrEqualTo(l.dock.right));
      expect(l.pagesInset.left, greaterThan(0));
    });

    test('a square window: the slot is under the pages, kept', () {
      final l = HifzLayout.resolve(const Size(1000, 940), EdgeInsets.zero, pageBox: box);
      expect(l.landscape, isTrue);
      expect(l.slotAxis, Axis.horizontal);
      expect(l.pager.bottom - l.pagesInset.bottom, lessThanOrEqualTo(l.slot.top));
    });

    test('portrait: header, page, dock; a bar takes the dock\'s place', () {
      final l = HifzLayout.resolve(
          const Size(393, 852), const EdgeInsets.only(top: 24, bottom: 20),
          pageBox: box);
      expect(l.landscape, isFalse);
      expect(l.header, isNull, reason: 'each page has its own line');
      expect(l.pager.top, 24);
      expect(l.pager.bottom, l.dock.top);
      expect(l.slot, l.dock);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}
