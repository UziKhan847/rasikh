import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/screens/settings_screen.dart';

/// Reachability check for the new Downloads screen: Settings → "Manage
/// downloads" → the Downloads screen. Doesn't wait for [DownloadsScreen]'s
/// own async load (which tokenizes every sūrah's word count for the
/// word-by-word status column) to finish — that's real asset/isolate work
/// better left to a manual pass, per the project's existing "verify on a
/// real device" note for anything asset-heavy. This only pins that the
/// entry point exists and the screen opens.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress, Widget child) {
  return SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: progress,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Settings: "Manage downloads" opens the Downloads screen, loading state first',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Manage downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage downloads'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Downloads'), findsWidgets); // AppBar title
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
