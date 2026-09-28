import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// The optional session-length reminder: off by default, a parent's own
/// choice when on, and never a lockout — one dialog, once, dismissed by a
/// single tap that changes nothing else.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('off by default: no reminder however long the session runs', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    expect(settings.kidsSessionMinutes, 0);
    await tester.pumpWidget(_harness(settings));
    await tester.pump();

    await tester.pump(const Duration(minutes: 45));

    expect(find.text('Time for a stretch?'), findsNothing);
  });

  testWidgets('once the set length passes, a dismissible reminder appears', (
    tester,
  ) async {
    useReducedMotion(tester);
    final settings = await _boot();
    settings.kidsSessionMinutes = 1;
    await tester.pumpWidget(_harness(settings));
    await tester.pump();

    expect(find.text('Time for a stretch?'), findsNothing);
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('Time for a stretch?'), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pump();

    expect(find.text('Time for a stretch?'), findsNothing);
    // Dismissing changes nothing else — the shell is exactly where it was.
    expect(find.text('Hello, Sara!'), findsOneWidget);
  });

  testWidgets(
    'the reminder never repeats within the same session',
    (tester) async {
      useReducedMotion(tester);
      final settings = await _boot();
      settings.kidsSessionMinutes = 1;
      await tester.pumpWidget(_harness(settings));
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
      await tester.tap(find.text('Keep going'));
      await tester.pump();

      // Waiting again, well past the same length a second time, raises
      // nothing more — the timer that raised it does not repeat.
      await tester.pump(const Duration(minutes: 5));

      expect(find.text('Time for a stretch?'), findsNothing);
    },
  );
}
