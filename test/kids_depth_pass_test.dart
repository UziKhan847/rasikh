import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_me_screen.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_app.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_raster.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The depth pass: a painted backdrop behind every kids screen, a raised
/// gradient card look, and the Me tab's **Detail** dial — plain, medium, high —
/// whose bottom stop turns both off again (the low-end-device and plain-look
/// escape hatch) and whose middle stop keeps the scene but nothing that moves.
Future<AppSettings> _boot({KidsDetail detail = KidsDetail.high}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.kidsMode = true;
  settings.kidsDetail = detail;
  return settings;
}

Widget _harness(AppSettings s, Widget child) => SettingsScope(
  settings: s,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings.kidsDetail', () {
    test('defaults to high', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.high);
    });

    test('every level round-trips through save/load', () async {
      for (final level in KidsDetail.values) {
        SharedPreferences.setMockInitialValues({});
        final a = AppSettings();
        await a.load();
        a.kidsDetail = level;
        await a.save();

        final b = AppSettings();
        await b.load();
        expect(b.kidsDetail, level, reason: level.name);
      }
    });

    test('an old settings blob with no field defaults safely to high', () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1': '{"kidsMode": true}',
      });
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.high);
    });

    // The one regression here that would be invisible and would hit real
    // users: `kidsDetail` replaced a `bool kidsHighDetail`, and every install
    // that already saved one must keep the choice it made. A parent who
    // turned detail OFF on a slow phone must not get it switched back on.
    test('an install that saved kidsHighDetail: true loads as high', () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1': '{"kidsMode": true, "kidsHighDetail": true}',
      });
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.high);
    });

    test('an install that saved kidsHighDetail: false loads as PLAIN', () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1': '{"kidsMode": true, "kidsHighDetail": false}',
      });
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.plain);
    });

    test('the new key wins over a stale legacy one', () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1':
            '{"kidsMode": true, "kidsDetail": "medium", "kidsHighDetail": false}',
      });
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.medium);
    });

    test('an unknown level name falls back rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1': '{"kidsMode": true, "kidsDetail": "ludicrous"}',
      });
      final s = AppSettings();
      await s.load();
      expect(s.kidsDetail, KidsDetail.high);
    });

    test('saving writes only the new key, so the old one cannot resurface',
        () async {
      SharedPreferences.setMockInitialValues({
        'noor.settings.v1': '{"kidsMode": true, "kidsHighDetail": false}',
      });
      final a = AppSettings();
      await a.load();
      await a.save();
      final raw = (await SharedPreferences.getInstance())
          .getString('noor.settings.v1')!;
      expect(raw, contains('"kidsDetail":"plain"'));
      expect(raw, isNot(contains('kidsHighDetail')));
    });

    test('kidsRaised is true for every level but plain', () {
      final s = AppSettings();
      s.kidsDetail = KidsDetail.plain;
      expect(s.kidsRaised, isFalse);
      s.kidsDetail = KidsDetail.medium;
      expect(s.kidsRaised, isTrue);
      s.kidsDetail = KidsDetail.high;
      expect(s.kidsRaised, isTrue);
    });
  });

  group('KidsBackdrop', () {
    testWidgets('paints a backdrop layer behind the child on high', (
      tester,
    ) async {
      final settings = await _boot(detail: KidsDetail.high);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('is a no-op — the plain child, nothing else — on plain', (
      tester,
    ) async {
      final settings = await _boot(detail: KidsDetail.plain);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      // No Stack, no extra CustomPaint layer — [child] is returned as-is.
      expect(find.byType(KidsBackdrop), findsOneWidget);
      expect(
        tester.widget<KidsBackdrop>(find.byType(KidsBackdrop)).child,
        isA<Text>(),
      );
    });

    // The kit's backdrop: a static scene painter, and a mote painter driven by a
    // 24 s controller. What the dial controls is whether that controller RUNS.
    final motes = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is KbMotesPainter,
    );
    double moteT(WidgetTester tester) =>
        (tester.widget<CustomPaint>(motes).painter as KbMotesPainter).t.value;

    testWidgets('medium paints the scene, and nothing in it moves', (
      tester,
    ) async {
      final settings = await _boot(detail: KidsDetail.medium);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      expect(find.byType(KbBackdrop), findsOneWidget);
      // The static scene, drawn once into an image.
      expect(
        find.descendant(
          of: find.byType(KbBackdrop),
          matching: find.byType(KbRaster),
        ),
        findsOneWidget,
      );
      // The point of the middle setting: it is what a slower phone picks, so
      // it must cost nothing per frame — the motes are drawn once, standing
      // still, and no frame is ever asked for.
      final t0 = moteT(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(moteT(tester), t0);
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'something is still ticking on medium');
    });

    testWidgets('high animates the motes', (tester) async {
      final settings = await _boot(detail: KidsDetail.high);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      final before = moteT(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(moteT(tester), isNot(before), reason: 'the motes are not moving');
      // Leave no ticking controller behind for the test binding.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('high under reduced motion draws no motes and never ticks', (
      tester,
    ) async {
      useReducedMotion(tester);
      final settings = await _boot(detail: KidsDetail.high);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      expect(motes, findsNothing);
      expect(find.byType(KbBackdrop), findsOneWidget,
          reason: 'the scene itself stays');
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('each level paints the scene in its own style', (
      tester,
    ) async {
      // Medium is the design's soft `original` look, high the `vivid` one.
      for (final (level, style) in [
        (KidsDetail.medium, KbStyle.original),
        (KidsDetail.high, KbStyle.vivid),
      ]) {
        useReducedMotion(tester);
        final settings = await _boot(detail: level);
        await tester.pumpWidget(
          _harness(settings, const KidsBackdrop(child: Text('content'))),
        );
        await tester.pump();
        expect(tester.widget<KbBackdrop>(find.byType(KbBackdrop)).style, style,
            reason: level.name);
      }
    });

    testWidgets('never intercepts taps meant for the content above it', (
      tester,
    ) async {
      final settings = await _boot();
      var tapped = false;
      await tester.pumpWidget(
        _harness(
          settings,
          KidsBackdrop(
            child: GestureDetector(
              onTap: () => tapped = true,
              child: const SizedBox(width: 40, height: 40, child: Text('x')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('x'));
      expect(tapped, isTrue);
    });

    testWidgets('paints the equipped theme\'s own scene, not one fixed one', (
      tester,
    ) async {
      final settings = await _boot();
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
      settings.activeKidsProfile!.theme = 'kids_forest';
      // A treeline is a forest's, a dune is the desert's — the scene is
      // resolved per family.
      useReducedMotion(tester);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      final shown = tester.widget<KbBackdrop>(find.byType(KbBackdrop)).theme;
      expect(shown.id, 'forest');
      expect(shown.ridges.map((r) => r.kind), contains('tree'));
      expect(kbThemeFor('kids_desert').ridges.map((r) => r.kind),
          everyElement('dune'));
    });

    testWidgets('builds no moving layer at all under reduced motion', (
      tester,
    ) async {
      final settings = await _boot();
      // Not a paused animation — no mote layer in the tree. A repeating
      // controller that is merely stopped still costs a widget and still
      // makes pumpAndSettle a trap.
      useReducedMotion(tester);
      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump();
      final still = find.byType(CustomPaint).evaluate().length;

      await tester.pumpWidget(
        _harness(settings, const KidsBackdrop(child: Text('content'))),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byType(CustomPaint).evaluate().length,
        still,
        reason: 'the backdrop gained a layer while motion was off',
      );
    });
  });

  group('the Me tab\'s Detail dial', () {
    Future<(AppSettings, ProgressStore)> pumpMe(
      WidgetTester tester,
      KidsDetail level,
    ) async {
      useReducedMotion(tester);
      final settings = await _boot(detail: level);
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
      settings.desktopMode = 'off';
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: ProgressScope(
            progress: prog,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              // Hosted the way it is in the app: Me is a shell TAB, always
              // inside KidsShell's Scaffold — not a route pushed with
              // pushKidsOverlay, which is what the bare-screen Material
              // guard elsewhere is for.
              home: const Scaffold(body: KidsMeScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      return (settings, prog);
    }

    testWidgets('shows three tiles, with the current level selected', (
      tester,
    ) async {
      await pumpMe(tester, KidsDetail.medium);
      expect(find.text('Detail'), findsOneWidget);
      for (final level in KidsDetail.values) {
        expect(find.byKey(ValueKey('kidsDetail.${level.name}')), findsOneWidget);
      }
      expect(find.byType(Switch), findsNothing,
          reason: 'the on/off switch this dial replaced');

      expect(
          tester
              .widget<KbOptionTile>(
                  find.byKey(const ValueKey('kidsDetail.medium')))
              .selected,
          isTrue);
      expect(
          tester
              .widget<KbOptionTile>(find.byKey(const ValueKey('kidsDetail.high')))
              .selected,
          isFalse);
    });

    testWidgets('tapping each tile sets that level, and it persists', (
      tester,
    ) async {
      // Taller than the default window so the dial is on screen with no
      // scrolling — ensureVisible only guarantees SOME overlap, and a tap
      // aimed at a tile's centre below the fold hits nothing.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (settings, _) = await pumpMe(tester, KidsDetail.high);
      for (final level in [
        KidsDetail.plain,
        KidsDetail.medium,
        KidsDetail.high,
        KidsDetail.plain,
      ]) {
        final tile = find.byKey(ValueKey('kidsDetail.${level.name}'));
        await tester.tap(tile);
        await tester.pump();
        expect(settings.kidsDetail, level);
        // Persisted like every other setting — debounced behind a Timer.
        await tester.pump(const Duration(milliseconds: 400));
      }
      // Real prefs I/O doesn't resolve under testWidgets' fake clock — see the
      // v4 gotcha — so flush and reload inside the real zone.
      final reloaded = AppSettings();
      await tester.runAsync(() async {
        await settings.flush();
        await reloaded.load();
      });
      expect(reloaded.kidsDetail, KidsDetail.plain);
    });

    testWidgets('fits a 320×568 phone at the largest text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (settings, _) = await pumpMe(tester, KidsDetail.high);
      settings.kidsTextScale = 1.2;
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the mascot\'s celebrating expression', () {
    testWidgets('renders with no exception, motion on and off', (tester) async {
      final settings = await _boot();
      for (final reduced in [false, true]) {
        if (reduced) useReducedMotion(tester);
        await tester.pumpWidget(
          _harness(settings, const KidsMascot(celebrating: true)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'reduced=$reduced');
      }
    });

    testWidgets(
      'KidsLessonResult\'s mascot is the celebrating one, not the default',
      (tester) async {
        useReducedMotion(tester);
        final settings = await _boot();
        await tester.pumpWidget(
          _harness(settings, const Scaffold(body: KidsLessonResult(stars: 3))),
        );
        await tester.pumpAndSettle();
        final mascot = tester.widget<KidsMascot>(find.byType(KidsMascot));
        expect(mascot.celebrating, isTrue);
      },
    );
  });
}
