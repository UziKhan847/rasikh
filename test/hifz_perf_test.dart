import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rasikh/screens/mushaf/tool_circles.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/hifz_layout.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

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
      // (Desktop's tooltips carry the key; its row may leave no ⋯.)
      Finder tip(String t) => find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message == t || (w.message ?? '').startsWith('$t (')));
      for (final (tool, done) in [('Mark', 'End'), ('Recitation', 'Done'), ('More', null)]) {
        if (tip(tool).evaluate().isEmpty) continue;
        await tester.tap(tip(tool));
        await settle(tester);
        expect(lineRects(tester), before, reason: '$tool on: the pages moved');
        if (done != null) {
          await tester.tap(find.text(done));
        } else {
          await tester.tap(tip(tool), warnIfMissed: false);
        }
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
    double dockX() => tester.getTopLeft(find.byType(ToolCircles)).dx;
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

  /// The page under [at].
  int pageAt(WidgetTester tester, Offset at) => tester
      .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
      .firstWhere((r) =>
          r.attached && (r.localToGlobal(Offset.zero) & r.size).contains(at))
      .spec
      .page;

  group('the mouse wheel', () {
    const mid = Offset(196, 400);
    Future<void> wheel(WidgetTester tester, double dy, {Offset at = mid}) async {
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(at));
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      // Past the cooldown between notches (it runs on the real clock).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    }

    double scale(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    Future<void> ctrlWheel(WidgetTester tester, double dy) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await wheel(tester, dy);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }

    testWidgets('down is the next page, up the one before', (tester) async {
      await pump(tester, const Size(393, 852));
      final start = pageAt(tester, mid);
      await wheel(tester, 100);
      expect(pageAt(tester, mid), start + 1);
      await wheel(tester, 100);
      expect(pageAt(tester, mid), start + 2);
      await wheel(tester, -100);
      expect(pageAt(tester, mid), start + 1);
    });

    testWidgets('zoom needs no mode: Ctrl and the wheel from anywhere; the wheel '
        'then moves about the page and stops at its edge; the keys keep the zoom',
        (tester) async {
      await pump(tester, const Size(393, 852));
      final start = pageAt(tester, mid);
      await ctrlWheel(tester, -100);
      expect(pageAt(tester, mid), start, reason: 'Ctrl and the wheel turn nothing');
      expect(scale(tester), greaterThan(1));
      expect(find.byTooltip('Exit zoom'), findsOneWidget);
      final viewer = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;

      // Down the page, then far past its foot: never a turn.
      final y0 = viewer.value.getTranslation().y;
      await wheel(tester, 100);
      expect(viewer.value.getTranslation().y, lessThan(y0), reason: 'moved down the page');
      for (var i = 0; i < 12; i++) {
        await wheel(tester, 100);
      }
      expect(pageAt(tester, mid), start, reason: 'stops at the edge');

      // The arrows turn, at the same zoom.
      final zoom = scale(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(scale(tester), zoom);
      final turned = tester.state(find.byType(MushafPageScreen));
      expect(turned.mounted, isTrue);

      // Out to where it began: as if never zoomed, and the wheel turns again.
      for (var i = 0; i < 12 && find.byType(InteractiveViewer).evaluate().isNotEmpty; i++) {
        await ctrlWheel(tester, 100);
      }
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byTooltip('Exit zoom'), findsNothing);
      final here = pageAt(tester, mid);
      await wheel(tester, 100);
      expect(pageAt(tester, mid), here + 1);
    });

    testWidgets('quick notches add up, each a page on from the last', (tester) async {
      await pump(tester, const Size(393, 852));
      final start = pageAt(tester, mid);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(mid));
      for (var i = 0; i < 3; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
        // Mid-turn, past the cooldown.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      }
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(pageAt(tester, mid), start + 3);
    });

    testWidgets('down then straight back up mid-turn ends where it began', (tester) async {
      await pump(tester, const Size(393, 852));
      final start = pageAt(tester, mid);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(mid));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      // Barely begun: it still rounds to the page it left.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(pageAt(tester, mid), start);
    });

    testWidgets('sideways scrolling turns once a swipe, and never shakes the page',
        (tester) async {
      await pump(tester, const Size(393, 852));
      final start = pageAt(tester, mid);
      final view = tester.widget<PageView>(find.byType(PageView).first);
      final begin = view.controller!.page;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(mid));
      await tester.sendEventToBinding(mouse.scroll(const Offset(10, 0)));
      await tester.pump();
      expect(view.controller!.page, begin, reason: 'not nudged');
      for (var i = 0; i < 12; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(-10, 0)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(pageAt(tester, mid), start + 1, reason: 'one turn, for one swipe');
    });

    group('a trackpad', () {
      Future<void> pan(WidgetTester tester, Offset by, {int steps = 6}) async {
        final pad = TestPointer(2, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pad.panZoomStart(mid));
        for (var i = 1; i <= steps; i++) {
          await tester.sendEventToBinding(pad.panZoomUpdate(mid, pan: by * (i / steps)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.sendEventToBinding(pad.panZoomEnd());
        await tester.pump();
      }

      testWidgets('Ctrl and two fingers zoom, up in and down out, and don\'t move the page',
          (tester) async {
        await pump(tester, const Size(393, 852));
        final start = pageAt(tester, mid);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await pan(tester, const Offset(0, 120));
        await settle(tester);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        final viewer = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        final zoomed = viewer.value.getMaxScaleOnAxis();
        expect(zoomed, greaterThan(1.5));
        await pan(tester, const Offset(0, -40));
        await settle(tester);
        expect(viewer.value.getMaxScaleOnAxis(), lessThan(zoomed));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
        expect(pageAt(tester, mid), start);
      });

      testWidgets('a pinch zooms, with no mode', (tester) async {
        await pump(tester, const Size(393, 852));
        final pad = TestPointer(2, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pad.panZoomStart(mid));
        await tester.sendEventToBinding(pad.panZoomUpdate(mid, scale: 1.5));
        await tester.pump();
        await tester.sendEventToBinding(pad.panZoomEnd());
        await settle(tester);
        expect(find.byType(InteractiveViewer), findsOneWidget);
      });

      testWidgets('two fingers up and down turn the page, once a swipe', (tester) async {
        await pump(tester, const Size(393, 852));
        final start = pageAt(tester, mid);
        await pan(tester, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        expect(pageAt(tester, mid), start + 1);
      });
    });

        testWidgets('a mouse drags a zoomed page about', (tester) async {
      await pump(tester, const Size(393, 852));
      await ctrlWheel(tester, -100);
      await ctrlWheel(tester, -100);
      final viewer = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final y0 = viewer.value.getTranslation().y;
      final x0 = viewer.value.getTranslation().x;
      await tester.dragFrom(mid, const Offset(-30, -40), kind: PointerDeviceKind.mouse);
      await settle(tester);
      final moved = viewer.value.getTranslation();
      expect(moved.y != y0 || moved.x != x0, isTrue);
    });

    testWidgets('a page that scrolls has the wheel first: the turn comes at its end',
        (tester) async {
      final (s, _) = await pump(tester, const Size(914, 412));
      s.update(() => s.hifzLandscapePages = 'wide');
      await settle(tester);
      const at = Offset(400, 200);
      final start = tester
          .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
          .first
          .spec
          .page;
      await wheel(tester, 100, at: at);
      expect(
          tester.renderObjectList<RenderMushafLine>(find.byType(MushafLineView)).first.spec.page,
          start,
          reason: 'scrolled the page, not turned it');
      var turned = false;
      for (var i = 0; i < 30 && !turned; i++) {
        await wheel(tester, 100, at: at);
        turned = tester
            .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
            .any((r) => r.attached && r.spec.page == start + 1 &&
                (r.localToGlobal(Offset.zero) & r.size).contains(at));
      }
      expect(turned, isTrue, reason: 'at its foot, the next page');
    });

    testWidgets('with a finger the Zoom button is there; a mouse has no need of it',
        (tester) async {
      await pump(tester, const Size(393, 852));
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      expect(find.byTooltip('Zoom'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.addPointer(location: mid));
      await tester.sendEventToBinding(mouse.hover(mid));
      addTearDown(() async => tester.sendEventToBinding(mouse.removePointer()));
      await tester.pump();
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      expect(find.byTooltip('Zoom'), findsNothing);
    });
  });

  for (final (name, size) in [('portrait', const Size(393, 852)), ('landscape', const Size(914, 412))]) {
    testWidgets('$name: zoomed, one tap on the page\'s button comes out and it swipes again',
        (tester) async {
      await pump(tester, size);
      final mid = Offset(size.width / 2, size.height / 2);
      final before = pageAt(tester, mid);
      expect(find.byTooltip('Exit zoom'), findsNothing);
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.byTooltip('Zoom'));
      await settle(tester);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.byTooltip('Zoom'), findsNothing, reason: 'the fan is shut');
      final exit = tester.getRect(find.byTooltip('Exit zoom'));
      expect(exit.top, lessThan(size.height * .2), reason: 'at the top');
      if (size.width < size.height) {
        // In the line: the sūrah, this, the page number. It stays put zoomed.
        final page = tester.widget<MushafPageScreen>(find.byType(MushafPageScreen)).startPage;
        final number = tester.getRect(find.text('$page').first);
        expect(exit.right, lessThanOrEqualTo(number.left + 8), reason: 'before the page number');
        expect(exit.center.dy, closeTo(number.center.dy, 8), reason: 'on its line');
        final meta = (await tester.runAsync(QuranRepo.meta))!;
        final surah = MushafRepo.firstVerseOfPage('uthmani', page).$1;
        final name = meta.firstWhere((m) => m.n == surah).tname;
        expect(tester.getRect(find.text(name).first).right, lessThanOrEqualTo(exit.left),
            reason: 'after the sūrah');
      }

      await tester.tap(find.byTooltip('Exit zoom'));
      await settle(tester);
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byTooltip('Exit zoom'), findsNothing);
      await tester.flingFrom(mid.translate(-110, 0), const Offset(300, 0), 2000);
      await settle(tester);
      expect(pageAt(tester, mid), isNot(before));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('zoom stops the swipe for the pinch; off again, it swipes',
      (tester) async {
    await pump(tester, const Size(393, 852));
    const mid = Offset(196, 400);
    final before = pageAt(tester, mid);
    // In the ⋯ fan.
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.byTooltip('Zoom'));
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.flingFrom(const Offset(80, 400), const Offset(300, 0), 2000);
    await settle(tester);
    expect(pageAt(tester, mid), before, reason: 'zoomed, a swipe turned the page');
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.byTooltip('Zoom'));
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.flingFrom(const Offset(80, 400), const Offset(300, 0), 2000);
    await settle(tester);
    expect(pageAt(tester, mid), isNot(before));
  });

  testWidgets('a desktop: Ctrl and the wheel zoom, Esc goes back', (tester) async {
    await pump(tester, const Size(1400, 900));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(const PointerScrollEvent(
        position: Offset(500, 450), scrollDelta: Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('landscape, one page: no spread, the page scrolls', (tester) async {
    final (s, _) = await pump(tester, const Size(914, 412));
    s.update(() => s.hifzLandscapePages = 'wide');
    await settle(tester);
    final rects = lineRects(tester);
    expect(rects.map((r) => r.left.round()).toSet().length, lessThan(3),
        reason: 'one column of lines, not two pages');
    // Its line above it, as in portrait.
    expect(find.textContaining('Juz'), findsWidgets);
    // Taller than the window: it scrolls.
    expect(rects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b),
        greaterThan(412));
    await tester.pump(const Duration(milliseconds: 400)); // the save
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

    test('one page as wide as the spread keeps the side slot; the whole '
        'width puts the bar over its foot', () {
      final one = HifzLayout.resolve(const Size(1600, 900), EdgeInsets.zero,
          pageBox: box, pages: 'one');
      final two = HifzLayout.resolve(const Size(1600, 900), EdgeInsets.zero,
          pageBox: box);
      expect(one.slot, two.slot);
      expect(one.spreadWidth, two.spreadWidth);
      final wide = HifzLayout.resolve(const Size(1600, 900), EdgeInsets.zero,
          pageBox: box, pages: 'wide');
      expect(wide.slotAxis, Axis.horizontal);
      expect(wide.pagesInset, EdgeInsets.zero);
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
