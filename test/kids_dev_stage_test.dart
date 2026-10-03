import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The testing unlock's stage jump: once the mascot-tap unlock is on, the Me
/// tab gains a "Jump to stage" row that pins Home (and Learn's "current" row)
/// to any stage — see `ProgressStore.devStage` — so a tester can inspect a
/// stage deep in the path without actually clearing everything before it.
/// The unit-level rules (only honoured while unlocked, no progress touched,
/// cleared when the unlock is switched back off) are pinned in
/// kids_path_test.dart; this covers the UI path to get there.
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

Future<void> _unlock(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.tap(find.byType(KidsSecretUnlock).first);
    await tester.pump();
  }
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), kKidsUnlockCode);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('picking a stage from the Me tab points Home at it',
      (tester) async {
    useReducedMotion(tester);
    // Tall enough that the Me tab's dev-only rows aren't below the fold —
    // ensureVisible only knows about its own Scrollable, not the bottom nav
    // bar sitting outside it, so a cramped default test window can still
    // leave the "revealed" widget's tap point under that fixed chrome.
    tester.view.physicalSize = const Size(360, 2300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final prog = ProgressScope.of(tester.element(find.text('Me')));
    await _unlock(tester);

    // Off by default, and only offered once the testing unlock is on.
    expect(find.text('Jump to stage'), findsOneWidget);
    await tester.tap(find.text('Jump to stage'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('kids.devstage.forms.more')));
    await tester.pumpAndSettle();
    expect(prog.devStage, 'forms.more');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    // KidsSectionHeader over the trail names the current block.
    expect(find.text('Joining Shapes'), findsOneWidget);

    // Nothing about actual progress moved — only which stage Home displays.
    expect(prog.xp, 0);
    expect(prog.kidsLettersLearned, 0);
  });

  testWidgets('following real progress again clears the pin', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 2300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final prog = ProgressScope.of(tester.element(find.text('Me')));
    await _unlock(tester);
    prog.setDevStage('forms.more');
    await tester.pumpAndSettle();

    expect(find.textContaining('Pinned to:'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Pinned to:'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pinned to:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow real progress'));
    await tester.pumpAndSettle();

    expect(prog.devStage, isNull);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('The Letters'), findsOneWidget);
  });

  testWidgets('turning the unlock off also drops the pin', (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final prog = ProgressScope.of(tester.element(find.text('Me')));
    await _unlock(tester);
    prog.setDevStage('forms.more');
    await tester.pumpAndSettle();

    prog.setUnlockAll(false);
    await tester.pumpAndSettle();
    expect(prog.devStage, isNull);
    expect(find.text('Jump to stage'), findsNothing);
  });
}
