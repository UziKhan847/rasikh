import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/screens/desktop/desktop_shell.dart';
import 'package:qiraah_arabiyyah/screens/home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_desktop_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// [RootScreen] is the one place that decides adult-mobile vs. desktop vs.
/// Kids Mode, and — since Kids Mode desktop shipped — which of the two Kids
/// Mode shells a kidsMode window gets.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress) {
  return SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: progress,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const RootScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kidsMode + mobile -> KidsShell', (tester) async {
    useReducedMotion(tester);
    final (settings, progress) = await _boot();
    settings.desktopMode = 'off';
    settings.kidsMode = true;
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(KidsShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(DesktopShell), findsNothing);
    expect(find.byType(KidsDesktopShell), findsNothing);
  });

  testWidgets(
      'kidsMode + a desktop-sized window -> KidsDesktopShell, not the grown-up DesktopShell',
      (tester) async {
    useReducedMotion(tester);
    // The default 800x600 test surface is wide enough to satisfy
    // canUseDesktopShell's tablet-size check, but too small for the desktop
    // shell's own layout (see the 1440x900 test surface every other
    // "Desktop:" test in round13_navigation_test.dart already uses).
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final (settings, progress) = await _boot();
    settings.desktopMode = 'on';
    settings.kidsMode = true;
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(KidsDesktopShell), findsOneWidget);
    expect(find.byType(DesktopShell), findsNothing);
    expect(find.byType(KidsShell), findsNothing);
  });

  testWidgets(
      'kidsMode off + a desktop-sized window -> the grown-up DesktopShell, unaffected',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final (settings, progress) = await _boot();
    settings.desktopMode = 'on';
    settings.kidsMode = false;
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(KidsDesktopShell), findsNothing);
  });

  testWidgets('kidsMode off + mobile -> the grown-up HomeScreen', (tester) async {
    useReducedMotion(tester);
    final (settings, progress) = await _boot();
    settings.desktopMode = 'off';
    settings.kidsMode = false;
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(KidsShell), findsNothing);
  });
}
