import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart'
    show KbToggle;
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// Kids Mode's Full screen switch (Me tab): it is the app-wide immersive
/// setting, the one main.dart applies to the system bars, so it persists and
/// survives leaving Kids Mode like the grown-up app's own toggle does.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  settings.kidsMode = true;
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

final _card = find.byKey(const ValueKey('kids.immersive'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Me tab turns full screen on and off, and it is saved', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(kidsTab('Me'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_card);
    await tester.pumpAndSettle();
    expect(find.text('Full screen'), findsOneWidget);
    expect(settings.immersive, isFalse);

    final toggle = find.descendant(of: _card, matching: find.byType(KbToggle));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.immersive, isTrue);
    expect(tester.widget<KbToggle>(toggle).value, isTrue);

    // Saved like every other setting: a fresh load sees it.
    await tester.runAsync(settings.flush);
    final reloaded = AppSettings();
    await tester.runAsync(reloaded.load);
    expect(reloaded.immersive, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.immersive, isFalse);
    // Let the debounced save run rather than leave its timer pending.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('is not offered on desktop, which has no system bars', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(kidsTab('Me'));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
