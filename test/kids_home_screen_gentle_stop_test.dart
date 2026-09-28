import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart' show kidsDailyGoal;
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';

import 'kids_test_support.dart';

/// The direct answer to the "hard to put down without crying" complaint the
/// v4 research turned up: once today's goal is met, the Home tab says so is
/// a good place to stop — never a lock, just said out loud.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Amina'));
  return (settings, progress);
}

Future<void> _pump(
  WidgetTester tester,
  AppSettings s,
  ProgressStore prog,
) => tester.pumpWidget(
  SettingsScope(
    settings: s,
    child: ProgressScope(
      progress: prog,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: KidsHomeScreen(onGoLearn: () {}),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('says nothing about stopping before the daily goal is met', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    for (var i = 0; i < kidsDailyGoal - 1; i++) {
      prog.report('kids.letter.a$i', 3);
    }
    await _pump(tester, settings, prog);
    await tester.pump();

    expect(find.text("You've done your day"), findsNothing);
  });

  testWidgets('offers a gentle stop once the daily goal is met', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    for (var i = 0; i < kidsDailyGoal; i++) {
      prog.report('kids.letter.a$i', 3);
    }
    await _pump(tester, settings, prog);
    await tester.pump();

    expect(find.text("You've done your day"), findsOneWidget);
    expect(
      find.text('A good place to stop — it will all still be here '
          'tomorrow.'),
      findsOneWidget,
    );
  });

  testWidgets('the desktop layout offers the same gentle stop', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    // 'on' rather than the mobile default: the default 800×600 test window
    // already clears the tablet breakpoint, so this alone is enough to
    // resolve to `_desktopBuild` (see kids_desktop_layout_test.dart).
    settings.desktopMode = 'on';
    for (var i = 0; i < kidsDailyGoal; i++) {
      prog.report('kids.letter.a$i', 3);
    }
    await _pump(tester, settings, prog);
    await tester.pump();

    expect(find.text("You've done your day"), findsOneWidget);
  });
}
