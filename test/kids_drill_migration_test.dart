import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Each ḥarakah drill used to be ONE tile per mark (`kids.harakat.fatha`);
/// it is [kidsDrillSessions] short sessions now (`kids.harakat.fatha.1..3`).
/// A finished old drill covered all of them, so its stars carry onto each new
/// session — nothing a child already earned may be orphaned by the path being
/// split into shorter pieces.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an old whole-alphabet drill star lands on every new session id',
    () async {
      SharedPreferences.setMockInitialValues({
        'noor.progress.v1.p1':
            '{"kids.harakat.fatha": 3, "kids.sukun.sukun": 2}',
      });
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();

      for (var n = 1; n <= kidsDrillSessions; n++) {
        expect(prog.starsFor('kids.harakat.fatha.$n'), 3);
        expect(prog.starsFor('kids.sukun.sukun.$n'), 2);
      }
      // A mark that was never finished stays untouched.
      expect(prog.starsFor('kids.harakat.kasra.1'), 0);
    },
  );

  test('the migration never downgrades a session already earned', () async {
    SharedPreferences.setMockInitialValues({
      'noor.progress.v1.p1':
          '{"kids.harakat.damma": 1, "kids.harakat.damma.1": 3}',
    });
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    expect(prog.starsFor('kids.harakat.damma.1'), 3);
    expect(prog.starsFor('kids.harakat.damma.2'), 1);
    expect(prog.starsFor('kids.harakat.damma.3'), 1);
  });

  test('it never touches the stage Tests, which keep their ids', () async {
    SharedPreferences.setMockInitialValues({
      'noor.progress.v1.p1': '{"kids.harakat.test": 2}',
    });
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    expect(prog.starsFor('kids.harakat.test'), 2);
    expect(prog.starsFor('kids.harakat.test.1'), 0);
  });

  test('settings.dart\'s session count matches the path\'s', () {
    // `core/` cannot import `screens/kids`, so the migration hardcodes 3.
    // Migrating onto a different number of ids than the path opens would
    // leave a session looking un-done, so pin them together.
    expect(kidsDrillSessions, 3);
  });

  testWidgets('a session walks only its own slice of the alphabet', (
    tester,
  ) async {
    useReducedMotion(tester);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    final prog = ProgressStore(profileId: 'p1');
    await settings.load();
    await prog.load();
    settings.kidsMode = true;
    settings.desktopMode = 'off';
    final fatha = tashkil.firstWhere((t) => t.id == 'fatha');
    final (from, to) = kidsDrillRanges()[1];

    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: KidsSyllableDrill(
              mark: fatha,
              progressId: 'kids.harakat.fatha.2',
              start: from,
              end: to,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // It opens on the first letter OF THIS SLICE, not on Bāʼ.
    final firstOfSlice = kidsSyllableLetters[from].char;
    expect(
      find.text('$firstOfSlice${fatha.mark.substring(1)}'),
      findsOneWidget,
    );
    expect(find.text('بَ'), findsNothing);

    // ...and finishes after exactly its own letters plus its check-ups.
    var letterSteps = 0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Continue').evaluate().isNotEmpty) break;
      final said = find.text('I said it!');
      if (said.evaluate().isNotEmpty) {
        letterSteps++;
        await tester.tap(said);
      } else if (find.byType(TapScale).evaluate().isNotEmpty) {
        await tester.tap(find.byType(TapScale).first);
        await tester.pump(const Duration(milliseconds: 800));
      }
    }
    expect(letterSteps, to - from);
    expect(prog.starsFor('kids.harakat.fatha.2'), greaterThan(0));
    expect(prog.starsFor('kids.harakat.fatha.1'), 0);
  });
}
