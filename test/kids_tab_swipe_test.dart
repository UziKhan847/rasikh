import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart'
    show KbNodeState, KbPathNode;
import 'package:qiraah_arabiyyah/kids_backdrops/kb_parallax.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_raster.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_me_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_rewards_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart'
    show KidsTabBackdrop;

import 'kids_test_support.dart';

/// The five tabs as the design moves between them — from the nav bar only (no
/// swiping): the backdrop eases across to the new tab, its layers slide at their
/// own speeds as a page scrolls, and none of it costs a tab its state.
Future<AppSettings> _boot({KidsDetail detail = KidsDetail.high}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  settings.kidsMode = true;
  settings.kidsDetail = detail;
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  return settings;
}

Widget _harness(AppSettings settings) => SettingsScope(
  settings: settings,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const KidsShell(),
  ),
);

int _tab(WidgetTester tester) => tester
    .widget<IndexedStack>(
      find
          .descendant(
            of: find.byType(KbSwipeTabs),
            matching: find.byType(IndexedStack),
          )
          .first,
    )
    .index!;

double _camera(WidgetTester tester) =>
    tester.widget<KbSwipeTabs>(find.byType(KbSwipeTabs)).camera.value;

/// Pumps a bounded time rather than to settle: at high detail the motes
/// never stop moving.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The outermost vertical scroll view of [page].
ScrollableState _pageScroll(WidgetTester tester, Type page) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(page),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.vertical,
            ),
          )
          .first,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a sideways swipe never changes tab: only the nav bar does', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);

    for (final dx in [-200.0, 200.0, -400.0]) {
      await tester.dragFrom(const Offset(400, 300), Offset(dx, 0));
      await tester.pumpAndSettle();
      expect(_tab(tester), 0, reason: 'a swipe of $dx moved the tab');
      expect(_camera(tester), 0, reason: 'nor does it move the backdrop');
    }

    await tester.tap(kidsTab('Learn'));
    await tester.pumpAndSettle();
    expect(_tab(tester), 1);
  });

  testWidgets('a nav-bar tap eases the camera across to that tab', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(KbSwipeTabs)).width;

    await tester.tap(kidsTab('Rank'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(_camera(tester), inExclusiveRange(0, 2 * width), reason: 'moving');
    await tester.pumpAndSettle();
    expect(_tab(tester), 2);
    expect(_camera(tester), moreOrLessEquals(2 * width));
  });

  testWidgets('a tab keeps its scroll position, and the backdrop follows it', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    await tester.tap(kidsTab('Me'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(KidsMeScreen), const Offset(0, -200));
    await tester.pumpAndSettle();
    final scrolled = _pageScroll(tester, KidsMeScreen).position.pixels;
    expect(scrolled, greaterThan(0));
    final backdrop = tester.widget<KidsTabBackdrop>(
      find.byType(KidsTabBackdrop),
    );
    expect(backdrop.scrollY.value, scrolled);

    await tester.tap(kidsTab('Home'));
    await tester.pumpAndSettle();
    expect(
      backdrop.scrollY.value,
      isNot(scrolled),
      reason: 'Home has its own scroll position',
    );

    await tester.tap(kidsTab('Me'));
    await tester.pumpAndSettle();
    expect(_pageScroll(tester, KidsMeScreen).position.pixels, scrolled);
    expect(backdrop.scrollY.value, scrolled);
  });

  testWidgets('a sideways list inside a tab still scrolls, and keeps the tab', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(kidsTab('Rewards'));
    await tester.pumpAndSettle();

    final row = find
        .descendant(
          of: find.byType(KidsRewardsScreen),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
          ),
        )
        .first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.drag(row, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(_tab(tester), 3, reason: 'the badge row took the drag');
    expect(tester.state<ScrollableState>(row).position.pixels, greaterThan(0));
  });

  group('the parallax backdrop', () {
    testWidgets('is what high detail paints behind the tabs', (tester) async {
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      expect(find.byType(KbParallaxBackdrop), findsOneWidget);
    });

    for (final detail in [KidsDetail.medium, KidsDetail.plain]) {
      testWidgets('is not used at ${detail.name} detail', (tester) async {
        final settings = await _boot(detail: detail);
        await tester.pumpWidget(_harness(settings));
        await _settle(tester);
        expect(find.byType(KbParallaxBackdrop), findsNothing);
        expect(
          find.byType(KbBackdrop),
          detail == KidsDetail.medium ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('scrolling a page slides the layers', (tester) async {
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      await tester.tap(kidsTab('Me'));
      await _settle(tester);

      List<Offset> shifts() => [
        for (final t in tester.widgetList<Transform>(
          find.descendant(
            of: find.byType(KbParallaxBackdrop),
            matching: find.byType(Transform),
          ),
        ))
          Offset(
            t.transform.getTranslation().x,
            t.transform.getTranslation().y,
          ),
      ];
      final before = shifts();
      await tester.drag(find.byType(KidsMeScreen), const Offset(0, -200));
      await _settle(tester);
      final after = shifts();
      expect(after, hasLength(before.length));
      expect(
        [
          for (var i = 0; i < after.length; i++)
            if (after[i].dy < before[i].dy) i,
        ],
        isNotEmpty,
        reason: 'the layers move up as the page scrolls down',
      );
    });

    testWidgets('never repaints its scenery on a scroll or a tab change', (
      tester,
    ) async {
      // Every layer is painted once and after that only moved: each static
      // layer must keep the very picture it first recorded (a repaint records
      // a new one).
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);

      List<RenderRepaintBoundary> scenery() => [
        for (final e
            in find
                .descendant(
                  of: find.byType(KbParallaxBackdrop),
                  matching: find.byType(CustomPaint),
                )
                .evaluate())
          if (const {
                '_SkyPainter',
                '_OrnPainter',
                '_RidgePainter',
                '_ImagePainter',
              }.contains(
                (e.widget as CustomPaint).painter.runtimeType.toString(),
              ) &&
              // The backdrop's own layers, not images inside the pages — and
              // not the bloom, which is screen-blended into whatever is beneath
              // it and so, by design, has no layer of its own (its image is
              // still drawn only once).
              e.findAncestorWidgetOfExactType<KbSwipeTabs>() == null &&
              !find
                  .ancestor(
                    of: find.byElementPredicate((x) => x == e),
                    matching: find.byKey(const ValueKey('kb.bloom')),
                  )
                  .evaluate()
                  .isNotEmpty)
            e.findAncestorRenderObjectOfType<RenderRepaintBoundary>()!,
      ];
      final layers = scenery();
      expect(
        layers.length,
        greaterThanOrEqualTo(4),
        reason: 'sky, sun, ridges',
      );
      final painted = [for (final b in layers) b.debugLayer!.firstChild];

      await tester.tap(kidsTab('Me'));
      await _settle(tester);
      await tester.drag(find.byType(KidsMeScreen), const Offset(0, -200));
      await _settle(tester);
      await tester.tap(kidsTab('Rewards'));
      await _settle(tester);
      expect(_tab(tester), 3);

      expect(scenery(), layers, reason: 'the same layers, not rebuilt ones');
      expect([for (final b in layers) b.debugLayer!.firstChild], painted);
    });

    testWidgets('stands still under reduce-motion', (tester) async {
      useReducedMotion(tester);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await tester.pumpAndSettle();
      await tester.tap(kidsTab('Me'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(KidsMeScreen), const Offset(0, -200));
      await tester.pumpAndSettle();
      for (final t in tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(KbParallaxBackdrop),
          matching: find.byType(Transform),
        ),
      )) {
        expect(t.transform.getTranslation().y, 0);
        expect(t.transform.getTranslation().x, 0);
      }
    });
  });

  group('the vertical parallax', () {
    /// How far the near ridge has moved up (its layer's translation), px.
    double nearShift(WidgetTester tester) => -tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(const ValueKey('kb.near')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .y;

    Future<void> jump(WidgetTester tester, Type page, double to) async {
      _pageScroll(tester, page).position.jumpTo(to);
      await _settle(tester);
    }

    testWidgets('runs the whole length of a long page, and reaches full travel '
        'exactly at the bottom', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);

      final home = find.byType(KidsHomeScreen);
      expect(home, findsOneWidget);
      final pos = _pageScroll(tester, KidsHomeScreen).position;
      expect(
        pos.maxScrollExtent,
        greaterThan(1200),
        reason: 'Home is the long page: the whole stage inline',
      );

      await jump(tester, KidsHomeScreen, 500);
      final at500 = nearShift(tester);
      await jump(tester, KidsHomeScreen, 900);
      expect(
        nearShift(tester),
        greaterThan(at500),
        reason: 'still moving well past the old 400 px stop',
      );
      await jump(tester, KidsHomeScreen, pos.maxScrollExtent);
      // Full travel: 400 px of scroll's worth, at the near ridge's .35 speed.
      expect(nearShift(tester), moreOrLessEquals(400 * .35, epsilon: .5));
    });

    testWidgets('moves 1:1 on a page shorter than 400 px', (tester) async {
      tester.view.physicalSize = const Size(360, 1700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      await tester.tap(kidsTab('Me'));
      await _settle(tester);
      final ext = _pageScroll(tester, KidsMeScreen).position.maxScrollExtent;
      expect(ext, inExclusiveRange(0, 400));
      await jump(tester, KidsMeScreen, ext);
      expect(nearShift(tester), moreOrLessEquals(ext * .35, epsilon: .5));
    });

    testWidgets('a tab gets its own travel back when you return to it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      await jump(tester, KidsHomeScreen, 1000);
      final homeShift = nearShift(tester);
      expect(homeShift, greaterThan(0));

      await tester.tap(kidsTab('Me'));
      await _settle(tester);
      expect(nearShift(tester), 0, reason: 'Me is at its top');
      await tester.tap(kidsTab('Home'));
      await _settle(tester);
      expect(nearShift(tester), moreOrLessEquals(homeShift, epsilon: .01));
    });
  });

  group('a tab keeps its state', () {
    testWidgets('when a theme with a different number of ridges is worn', (
      tester,
    ) async {
      // Night has two ridges, the default three: the backdrop's layers change
      // count, which used to slide the page into a new slot and rebuild it.
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      await tester.tap(kidsTab('Rewards'));
      await _settle(tester);
      final scroll = _pageScroll(tester, KidsRewardsScreen);
      scroll.position.jumpTo(300);
      await _settle(tester);

      settings.update(() => settings.activeKidsProfile!.theme = 'kids_night');
      await _settle(tester);
      expect(
        identical(_pageScroll(tester, KidsRewardsScreen), scroll),
        isTrue,
        reason: 'the Rewards page was rebuilt from scratch',
      );
      expect(scroll.position.pixels, 300);
    });

    testWidgets('when Detail switches between high and medium', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot();
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      await tester.tap(kidsTab('Me'));
      await _settle(tester);
      final scroll = _pageScroll(tester, KidsMeScreen);
      scroll.position.jumpTo(200);
      await _settle(tester);

      for (final d in [KidsDetail.medium, KidsDetail.high, KidsDetail.plain]) {
        settings.update(() => settings.kidsDetail = d);
        await _settle(tester);
        expect(
          identical(_pageScroll(tester, KidsMeScreen), scroll),
          isTrue,
          reason: 'the Me page was rebuilt switching to ${d.name}',
        );
        expect(scroll.position.pixels, 200);
      }
    });
  });

  testWidgets('a hidden tab is paused', (tester) async {
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await _settle(tester);
    bool ticking(Type page) => TickerMode.valuesOf(
      tester.element(find.byType(page, skipOffstage: false)),
    ).enabled;
    expect(ticking(KidsHomeScreen), isTrue);
    await tester.tap(kidsTab('Rewards'));
    await _settle(tester);
    expect(
      ticking(KidsHomeScreen),
      isFalse,
      reason: "Home's pulse kept ticking behind another tab",
    );
    expect(ticking(KidsRewardsScreen), isTrue);
  });

  testWidgets('the pulsing node repaints on its own, not the whole Home page', (
    tester,
  ) async {
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await _settle(tester);
    final node = find.byWidgetPredicate(
      (w) => w is KbPathNode && w.state == KbNodeState.current,
    );
    expect(node, findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: node, matching: find.byType(RepaintBoundary)).first,
    );
    expect(
      boundary.size.width,
      lessThan(200),
      reason: 'the nearest repaint boundary is the whole page',
    );
    expect(boundary.size.height, lessThan(200));
  });

  group('the v2.1 look', () {
    Future<AppSettings> pumpShell(
      WidgetTester tester, {
      String theme = 'kids',
      String mode = 'light',
      KidsDetail detail = KidsDetail.high,
    }) async {
      final settings = await _boot(detail: detail);
      settings.kidsThemeMode = mode;
      settings.activeKidsProfile!.theme = theme;
      if (theme != 'kids') {
        final store = ProgressStore(profileId: 'p1');
        await store.load();
        store.buyShopItem(theme, 0);
      }
      await tester.pumpWidget(_harness(settings));
      await _settle(tester);
      return settings;
    }

    testWidgets('a light sun theme gets the bloom, screened over the scene', (
      tester,
    ) async {
      await pumpShell(tester, theme: 'kids_ocean');
      final bloom = find.byKey(const ValueKey('kb.bloom'));
      expect(bloom, findsOneWidget);
      final raster = tester.widget<KbRaster>(
        find.descendant(of: bloom, matching: find.byType(KbRaster)),
      );
      expect(raster.blendMode, BlendMode.screen);
      // No repaint boundary of its own, or the screen blend has nothing under it.
      expect(
        find.descendant(of: bloom, matching: find.byType(RepaintBoundary)),
        findsNothing,
      );
    });

    testWidgets('no bloom in the dark, or without a sun', (tester) async {
      await pumpShell(tester, theme: 'kids_ocean', mode: 'dark');
      expect(find.byKey(const ValueKey('kb.bloom')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpShell(tester, theme: 'kids_night');
      expect(find.byKey(const ValueKey('kb.bloom')), findsNothing);
    });

    testWidgets('High bakes the saturation into the layers; Medium has none', (
      tester,
    ) async {
      await pumpShell(tester);
      final layers = tester.widgetList<KbRaster>(
        find.descendant(
          of: find.byType(KbParallaxBackdrop),
          matching: find.byType(KbRaster),
        ),
      );
      expect(layers, isNotEmpty);
      expect(layers.every((r) => r.colorFilter != null), isTrue);
      expect(
        find.descendant(
          of: find.byType(KbParallaxBackdrop),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
        reason: 'a filter over the scene is a full-screen pass every frame',
      );

      await tester.pumpWidget(const SizedBox());
      await pumpShell(tester, detail: KidsDetail.medium);
      final soft = tester.widgetList<KbRaster>(
        find.descendant(
          of: find.byType(KbBackdrop),
          matching: find.byType(KbRaster),
        ),
      );
      expect(soft.every((r) => r.colorFilter == null), isTrue);
    });
  });
}
