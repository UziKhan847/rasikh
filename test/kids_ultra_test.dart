import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_hifi.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_parallax.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_themes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_me_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// Ultra: the design's High + Ultra effects on the five tabs, and the pages
/// leaning with the tilt (UI tilt).
final _ocean = kbThemes.firstWhere((t) => t.id == 'ocean');

Widget _backdrop({
  KbFidelity fidelity = KbFidelity.ultra,
  bool motion = true,
  double uiTilt = 1,
  bool reduce = false,
  Widget? child,
}) => MediaQuery(
  data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduce),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: KbParallaxBackdrop(
      theme: _ocean,
      mode: KbMode.light,
      cameraX: ValueNotifier(0),
      scrollY: ValueNotifier(0),
      fidelity: fidelity,
      motion: motion,
      uiTilt: uiTilt,
      child: child,
    ),
  ),
);

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

/// A page with state of its own and a button, to see that it survives.
class _Page extends StatefulWidget {
  final VoidCallback onTap;
  const _Page({required this.onTap});
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: widget.onTap,
      child: const SizedBox(
        key: ValueKey('button'),
        width: 120,
        height: 60,
        child: ColoredBox(color: Color(0xFF000000)),
      ),
    ),
  );
}

Future<AppSettings> _boot(KidsDetail detail) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  settings.kidsMode = true;
  settings.kidsDetail = detail;
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  return settings;
}

Widget _shell(AppSettings settings) => SettingsScope(
  settings: settings,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const KidsShell(),
  ),
);

void main() {
  group('the Ultra backdrop', () {
    testWidgets('paints the effects and keeps them moving', (tester) async {
      await tester.pumpWidget(_backdrop());
      await _frames(tester);
      expect(find.byKey(const ValueKey('kb.fx')), findsOneWidget);
      expect(find.byKey(const ValueKey('kb.fxLight')), findsOneWidget);
      expect(find.byKey(const ValueKey('kb.grain')), findsOneWidget);
      expect(find.byKey(const ValueKey('kb.vignette')), findsOneWidget);
      expect(find.byKey(const ValueKey('kb.mist0')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('kb.motes')),
        findsNothing,
        reason: 'the effects replace the motes',
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Standard (High on the dial) has none of it', (tester) async {
      await tester.pumpWidget(_backdrop(fidelity: KbFidelity.standard));
      await _frames(tester, 3);
      for (final k in ['kb.fx', 'kb.grain', 'kb.vignette', 'kb.mist0']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      expect(find.byKey(const ValueKey('kb.motes')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduce-motion stops every ticker', (tester) async {
      await tester.pumpWidget(_backdrop(reduce: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('kb.fx')), findsNothing);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'something is still ticking under reduce-motion',
      );
    });

    testWidgets('motion off stops the effects\' clock and the tilt', (
      tester,
    ) async {
      await tester.pumpWidget(_backdrop(motion: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('UI tilt', () {
    testWidgets('the page keeps its state as the tilt passes level, and taps '
        'land while it leans', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_backdrop(child: _Page(onTap: () => taps++)));
      await _frames(tester, 3);
      final state = tester.state(find.byType(_Page));

      // A mouse drives the tilt on desktop (and in tests): edge, centre, edge.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      for (final x in [10.0, 400.0, 790.0, 400.0]) {
        await mouse.moveTo(Offset(x, 300));
        await _frames(tester, 12);
        expect(
          identical(tester.state(find.byType(_Page)), state),
          isTrue,
          reason: 'the page was rebuilt as the tilt moved',
        );
      }
      await mouse.moveTo(const Offset(790, 590));
      await _frames(tester, 12);
      final lean = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byType(_Page),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      expect(lean.isIdentity(), isFalse, reason: 'it should be leaning');

      await tester.tap(find.byKey(const ValueKey('button')));
      await tester.pump();
      expect(taps, 1);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('off means the page never leans', (tester) async {
      await tester.pumpWidget(_backdrop(uiTilt: 0, child: _Page(onTap: () {})));
      await _frames(tester, 3);
      expect(
        find.ancestor(of: find.byType(_Page), matching: find.byType(Transform)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the Me tab', () {
    testWidgets('offers Screen tilt only while Detail is Ultra, and saves it', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(360, 2300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot(KidsDetail.high);
      await tester.pumpWidget(_shell(settings));
      await tester.pumpAndSettle();
      await tester.tap(kidsTab('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Screen tilt'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('kidsDetail.ultra')));
      await tester.pumpAndSettle();
      expect(settings.kidsDetail, KidsDetail.ultra);
      expect(find.text('Screen tilt'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kidsUiTilt.1.6')));
      await tester.pumpAndSettle();
      expect(settings.kidsUiTilt, 1.6);
      await tester.runAsync(settings.flush);
      final again = AppSettings();
      await tester.runAsync(again.load);
      expect(again.kidsDetail, KidsDetail.ultra);
      expect(again.kidsUiTilt, 1.6);
    });

    testWidgets('switching to Ultra keeps the page where it was', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot(KidsDetail.high);
      await tester.pumpWidget(_shell(settings));
      await _frames(tester);
      await tester.tap(kidsTab('Me'));
      await _frames(tester);
      ScrollableState scroll() => tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(KidsMeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final before = scroll();
      before.position.jumpTo(200);
      await _frames(tester);
      settings.update(() => settings.kidsDetail = KidsDetail.ultra);
      await _frames(tester);
      expect(identical(scroll(), before), isTrue);
      expect(before.position.pixels, 200);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Ultra fits a 320×568 phone at the largest text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = await _boot(KidsDetail.ultra);
      settings.kidsTextScale = 1.2;
      await tester.pumpWidget(_shell(settings));
      await _frames(tester);
      for (final tab in ['Learn', 'Rank', 'Rewards', 'Me', 'Home']) {
        await tester.tap(kidsTab(tab));
        await _frames(tester);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
