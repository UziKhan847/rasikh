import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// Regression guard for the bug that made the Kids Mode letter path
/// unwinnable: on **mobile**, a lesson opened with `pushKidsOverlay` is a
/// route under the ROOT navigator, which sits above the child profile's
/// `ProgressScope` (provided by `KidsProfileGate`, inside `RootScreen`) and
/// below the grown-up one (`main.dart:38`). So every lesson reported its
/// stars, XP, gems and badges into the ADULT store while the Learn tab read
/// the child's and saw nothing — Alif stayed "current" forever.
///
/// Desktop never had it: its overlay keeps the lesson in-tree. That is also
/// why nothing caught this — `kids_shell_navigation_test.dart` deliberately
/// "stops short of entering the Trace step".
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off'; // the mobile push path is the one under test
  settings.kidsMode = true;
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  return settings;
}

/// Mirrors `main.dart`'s real tree: the grown-up store is provided ABOVE the
/// MaterialApp, so a pushed route finds it unless something re-provides the
/// child's. Testing against a bare `KidsShell` would hide the whole bug.
Widget _harness(AppSettings settings, ProgressStore adult) => SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: adult,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: buildTheme(settings),
          home: const KidsShell(),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a lesson pushed on mobile reports to the CHILD store, '
      'not the grown-up one', (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    final adult = ProgressStore();
    await adult.load();

    await tester.pumpWidget(_harness(settings, adult));
    await tester.pumpAndSettle();

    // Learn tab → the first stage → the first letter, the only unlocked one.
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.letter.ا')));
    // Not pumpAndSettle: TracingBoard runs a repeating pulse, which never
    // lets it return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(KidsLetterFlow), findsOneWidget);
    final flow = tester.element(find.byType(KidsLetterFlow));

    expect(ProgressScope.of(flow).profileId, 'p1',
        reason: 'the pushed lesson resolved the grown-up ProgressStore — '
            'every star it reports would land in the wrong profile');
    expect(identical(ProgressScope.of(flow), adult), isFalse);
  });

  testWidgets('a pushed lesson keeps the Kids Mode theme', (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    final adult = ProgressStore();
    await adult.load();

    await tester.pumpWidget(_harness(settings, adult));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.letter.ا')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final flow = tester.element(find.byType(KidsLetterFlow));
    // The same escape that dropped the ProgressScope dropped `Theme(kidsTheme)`
    // too, so pushed kids screens were painting in the adult ThemeData.
    expect(Theme.of(flow).scaffoldBackgroundColor, kidsPal(flow).bg);
    expect(Theme.of(flow).scaffoldBackgroundColor,
        isNot(buildTheme(settings).scaffoldBackgroundColor));
  });

  testWidgets('a cleared letter advances the Learn path to the next one',
      (tester) async {
    useReducedMotion(tester);
    // The display half of the same bug: with progress landing in the right
    // store, clearing Alif has to unlock Bāʾ. Reported directly rather than
    // driven through TracingBoard's gesture path, which is what the lesson
    // does on completion (`kids.letter.<char>`).
    final settings = await _boot();
    final adult = ProgressStore();
    await adult.load();

    await tester.pumpWidget(_harness(settings, adult));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
    await tester.pumpAndSettle();

    final learn = tester.element(find.byKey(const ValueKey('kids.letter.ا')));
    final kids = ProgressScope.of(learn);
    expect(kids.kidsLettersLearned, 0);

    kids.report('kids.letter.${kidsLetterPath.first.char}', 3);
    await tester.pumpAndSettle();

    expect(kids.kidsLettersLearned, 1);
    // Bāʾ is now the current letter, so it renders its glyph and name — a
    // locked tile draws only a padlock.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('kids.letter.ب')),
            matching: find.text(kidsLetterPath[1].char)),
        findsOneWidget);
  });
}
