import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The developer unlock: ten taps on the mascot (or, from a fresh install
/// where no mascot has been earned yet, the Me tab's avatar), then a code.
///
/// It lifts **locks only**. Nothing about it may award progress, XP, gems or
/// badges, or make an unplayed stage look played — a testing switch that
/// forges progress would corrupt the very thing it exists to let you inspect.
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

/// Ten taps in a row on the secret target, then whatever the code box gets.
Future<void> _enter(WidgetTester tester, String code) async {
  for (var i = 0; i < 10; i++) {
    await tester.tap(find.byType(KidsSecretUnlock).first);
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.text('Unlock everything?'), findsOneWidget);
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unlockAll lifts every lock and only the locks', () async {
    SharedPreferences.setMockInitialValues({});
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    expect(kidsLocked(prog, 4, 0), isTrue);
    prog.setUnlockAll(true);
    expect(kidsLocked(prog, 4, 0), isFalse);
    expect(kidsLocked(prog, 99, 0), isFalse);
    // Nothing was granted: the switch is about reachability, not progress.
    expect(prog.xp, 0);
    expect(prog.gems, 0);
    expect(prog.badges, isEmpty);
    expect(prog.kidsLettersLearned, 0);

    prog.setUnlockAll(false);
    expect(kidsLocked(prog, 4, 0), isTrue);
  });

  test('the unlock survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProgressStore(profileId: 'p1');
    await first.load();
    first.setUnlockAll(true);
    await Future<void>.delayed(Duration.zero);

    final second = ProgressStore(profileId: 'p1');
    await second.load();
    expect(second.unlockAll, isTrue,
        reason: 'a tester should not have to re-enter the code every launch');
    // Per profile, like every other thing the store holds.
    final other = ProgressStore(profileId: 'p2');
    await other.load();
    expect(other.unlockAll, isFalse);
  });

  testWidgets('ten taps and the code open the whole path', (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final prog = ProgressScope.of(tester.element(find.text('Me')));
    expect(prog.unlockAll, isFalse);

    await _enter(tester, 'nope');
    expect(prog.unlockAll, isFalse, reason: 'a wrong code unlocks nothing');

    await _enter(tester, kKidsUnlockCode);
    expect(prog.unlockAll, isTrue);
    expect(find.text('Every stage unlocked for testing.'), findsOneWidget);
  });

  testWidgets('a locked stage opens once the unlock is on', (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    // Nothing has been learned, so stage two is shut.
    await tester.tap(find.byKey(const ValueKey('kids.block.letters.quiz')));
    await tester.pumpAndSettle();
    expect(find.text('Finish the stage before this one first!'), findsOneWidget);

    // Let that snackbar go before asking whether a second one appears.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    ProgressScope.of(tester.element(find.text('Me'))).setUnlockAll(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.block.letters.quiz')));
    await tester.pumpAndSettle();
    expect(find.text('Finish the stage before this one first!'), findsNothing);
    // ...and the stage it opened still says nothing has been done in it.
    expect(find.text('0 / 1'), findsOneWidget);
  });
}
