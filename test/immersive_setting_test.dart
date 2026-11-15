import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/main.dart';
import 'package:rasikh/screens/settings_screen.dart';
import 'package:rasikh/ui/kit.dart';

import 'test_support.dart';

/// Immersive: the Reading section's switch, and the bars following it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  Future<(AppSettings, ProgressStore)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    return (s, p);
  }

  testWidgets('the switch in the settings turns it on', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const SettingsScreen(),
        ),
      ),
    ));
    await tester.pump();
    final row = find.ancestor(
        of: find.text('Immersive (hide system bars)'), matching: find.byType(QRow));
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(find.descendant(of: row, matching: find.byType(QSwitch)));
    await tester.pump();
    expect(s.immersive, isTrue);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('the app hides the bars, and brings them back', (tester) async {
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        modes.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final (s, p) = await boot();
    await tester.pumpWidget(QiraahArabiyyahApp(settings: s, progress: p));
    await tester.pump();
    s.update(() => s.immersive = true);
    await tester.pump();
    expect(modes.last, 'SystemUiMode.immersiveSticky');
    s.update(() => s.immersive = false);
    await tester.pump();
    expect(modes.last, 'SystemUiMode.edgeToEdge');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });
}
