import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_desktop_shell.dart';

import 'kids_test_support.dart';

/// Overflow guard for [KidsDesktopShell], modelled on `kids_layout_test.dart`
/// (its mobile counterpart). Before this file existed there was **no**
/// desktop overflow test at all in the app — the grown-up desktop shell's
/// own `_stat` overflow (`desktop_pages.dart:484`) is masked only by every
/// existing "Desktop:" test picking a 1440x900 window.
Future<AppSettings> _boot({double arabicScale = 1.0}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  // 'on' rather than 'auto': the shell itself doesn't gate on useDesktop(),
  // but every tab screen's `_desktopBuild` branch does, so the setting must
  // actually resolve to desktop for the two halves to agree.
  settings.desktopMode = 'on';
  settings.kidsMode = true;
  settings.kidsTextScale = arabicScale;
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  return settings;
}

Widget _harness(AppSettings settings, {String locale = 'en'}) => SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: const KidsDesktopShell(),
      ),
    );

/// The sidebar's five tabs, by the kit symbol each shows.
const _tabIcons = ['home', 'menu_book', 'emoji_events', 'redeem', 'face'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (label, size) in [
    ('1440x900', const Size(1440, 900)),
    ('1024x768', const Size(1024, 768)),
    ('800x600', const Size(800, 600)),
  ]) {
    for (final scale in [1.0, 1.2]) {
      testWidgets('every tab lays out cleanly at $label, text size $scale',
          (tester) async {
    useReducedMotion(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final settings = await _boot(arabicScale: scale);
        await tester.pumpWidget(_harness(settings));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Home overflowed');

        for (final icon in _tabIcons.skip(1)) {
          await tester.tap(kidsIcon(icon));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'tab with icon $icon overflowed');
        }
      });
    }
  }

  testWidgets('every tab lays out cleanly in Arabic (RTL) at 1440x900',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, locale: 'ar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final icon in _tabIcons.skip(1)) {
      await tester.tap(kidsIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the sidebar collapses to icon-only below ~900px wide',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget,
        reason: 'nav labels should be visible on a wide window');

    tester.view.physicalSize = const Size(800, 700);
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing,
        reason: 'nav labels should be hidden on a narrow window');
    expect(kidsIcon('home'), findsOneWidget);
  });

  testWidgets(
      'starting a letter lesson keeps the sidebar and swaps to the back button',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The sidebar (identified by its nav icons) is still there...
    expect(kidsIcon('home'), findsOneWidget);
    // ...and the top bar now shows a back control instead of the greeting.
    expect(kidsIcon('arrow_back', Icons.arrow_back_rounded), findsOneWidget);
    expect(find.textContaining('Marhaba'), findsNothing);

    await tester.tap(kidsIcon('arrow_back', Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Marhaba'), findsOneWidget);
  });

  testWidgets(
      'switching profiles opens inside the shell, not a second full-window Scaffold',
      (tester) async {
    useReducedMotion(tester);
    // Taller than a real desktop window on purpose: the Me tab carries a full
    // four-way Detail dial now, which pushes "Switch profile" below 900px,
    // and this test is about what switching does — not about scrolling to it.
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    settings.addKidsProfile(KidsProfile(id: 'p2', name: 'Yusuf'));
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    await tester.tap(kidsIcon('face'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The sidebar and its Home nav item are still on screen — a second
    // pushed Scaffold would have covered them.
    expect(kidsIcon('home'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Yusuf'), findsOneWidget);

    await tester.tap(find.text('Yusuf'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(settings.activeKidsProfileId, 'p2');
  });

  testWidgets('in Arabic the trail fills from the right, where it starts', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, locale: 'ar'));
    await tester.pumpAndSettle();
    final line = find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_TrailLinePainter' &&
        // ignore: avoid_dynamic_calls
        (w.painter as dynamic).axis == Axis.horizontal);
    expect(line, findsOneWidget);
    // ignore: avoid_dynamic_calls
    expect((tester.widget<CustomPaint>(line).painter as dynamic).direction,
        TextDirection.rtl);
  });
}
