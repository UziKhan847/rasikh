import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// Reachability checks for Kids Mode's shell: first-run profile creation,
/// the 5-tab bottom nav, and the locked-letter gate on the Learn tab. Stops
/// short of entering the Trace step itself — [TracingBoard] runs a
/// repeating pulse animation, which never lets `pumpAndSettle()` return.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  settings.kidsMode = true;
  return settings;
}

Widget _harness(AppSettings settings) {
  return SettingsScope(
    settings: settings,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const KidsShell(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a brand-new install asks who is learning, then opens Home',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    // A brand-new install has no profile yet, so this skips the "Who's
    // learning?" picker grid and opens straight onto profile creation.
    expect(find.text('New Profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Yusuf');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Yusuf!'), findsOneWidget);
    expect(settings.kidsProfiles, hasLength(1));
    expect(settings.activeKidsProfileId, settings.kidsProfiles.single.id);
  });

  testWidgets('switching to Kids Mode does not raise the keyboard',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    // The name field is the only text input in the whole app, and it used to
    // autofocus — so turning Kids Mode on for the first time threw the
    // keyboard up over the avatar row, which is the form's actual first step.
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('the bottom nav reaches all 5 tabs without throwing',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    for (final label in ['Learn', 'Rank', 'Rewards', 'Me', 'Home']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a locked tile on the Learn tab explains itself instead of opening',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    // Learn opens on the list of stages now; the letter tiles are one level
    // in, inside the first one.
    await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
    await tester.pumpAndSettle();

    // Letter index 0 (ا) is "current" on a brand-new profile; index 1 (ب) is
    // locked, and — unlike the last letter — is guaranteed to already be
    // built within the grid's initial viewport. Found by key rather than by
    // text: a locked tile deliberately renders only a padlock (see the
    // design), so there is no "ب" glyph on it to tap.
    await tester.tap(find.byKey(const ValueKey('kids.letter.ب')));
    await tester.pump();
    // Stage-neutral wording: a locked tile may be a quiz or a reading, not
    // only a letter.
    expect(find.text('Finish the one before this first!'), findsOneWidget);
  });

  testWidgets('Rank shows the need-siblings hint with a single profile',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rank'));
    await tester.pumpAndSettle();

    expect(
        find.text('Add another profile to start a family leaderboard!'),
        findsOneWidget);
  });
}
