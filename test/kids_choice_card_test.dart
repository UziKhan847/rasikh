import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_choice_card.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// The shared check: a second try before it counts, a hint then the teaching,
/// and an explanation the child dismisses — with stars from the first try.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> done;
  late List<int> missed;
  setUp(() {
    done = [];
    missed = [];
  });

  KidsChoiceCard card({
    int options = 4,
    String? hint = 'Look at the sign.',
    String? explain,
    bool retry = true,
  }) => KidsChoiceCard(
    prompt: 'Which one?',
    display: const Text('DISPLAY'),
    options: [for (var i = 0; i < options; i++) Text('opt$i')],
    correct: 2 % options,
    hint: hint,
    explain: explain,
    retry: retry,
    onMiss: missed.add,
    onDone: done.add,
  );

  Future<void> pump(WidgetTester tester, Widget w) async {
    useReducedMotion(tester);
    // A phone, not the 800×600 default, whose wide tiles push a second row
    // below the fold.
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot();
    await tester.pumpWidget(_harness(s, p, w));
    await tester.pump();
  }

  testWidgets('a right first pick moves on by itself, counted right', (
    tester,
  ) async {
    await pump(tester, card());
    expect(find.text('Which one?'), findsOneWidget);
    await tester.tap(find.text('opt2'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(done, isEmpty, reason: 'a beat to see it');
    await tester.pump(const Duration(milliseconds: 500));
    expect(done, [true]);
    expect(missed, isEmpty);
  });

  testWidgets('a first miss dims that tile, shows the hint, and lets the '
      'child try again', (tester) async {
    await pump(tester, card());
    await tester.tap(find.text('opt0'));
    await tester.pump();

    expect(missed, [0], reason: 'the queue hears about it at once');
    expect(done, isEmpty, reason: 'not over yet');
    expect(find.text('Look at the sign.'), findsOneWidget);
    // The tried tile is no longer a target; the others still are.
    expect(find.byType(TapScale), findsNWidgets(3));

    await tester.tap(find.text('opt2'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, [false], reason: 'right on the second try is not first-try');
    expect(missed, [0]);
  });

  testWidgets('a second miss reveals the right answer and moves on', (
    tester,
  ) async {
    await pump(tester, card());
    await tester.tap(find.text('opt0'));
    await tester.pump();
    await tester.tap(find.text('opt1'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, [false]);
    expect(missed, [0], reason: 'one miss is filed, not one per wrong tap');
  });

  testWidgets('two options have no second try', (tester) async {
    await pump(tester, card(options: 2));
    // correct = 0 for two options (2 % 2)
    await tester.tap(find.text('opt1'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, [false]);
    expect(find.text('Look at the sign.'), findsNothing);
  });

  testWidgets('retry can be turned off', (tester) async {
    await pump(tester, card(retry: false));
    await tester.tap(find.text('opt0'));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, [false]);
  });

  testWidgets('without a hint, a first miss still says to try again', (
    tester,
  ) async {
    await pump(tester, card(hint: null));
    await tester.tap(find.text('opt0'));
    await tester.pump();
    expect(find.text('Have another look and try again!'), findsOneWidget);
  });

  group('with an explanation', () {
    testWidgets('a right answer says yes, explains, and waits for Next', (
      tester,
    ) async {
      await pump(tester, card(explain: 'Because of the small sign.'));
      await tester.tap(find.text('opt2'));
      await tester.pump(const Duration(milliseconds: 2000));
      expect(done, isEmpty, reason: 'the child reads at their own pace');
      expect(find.text('Yes!'), findsOneWidget);
      expect(find.text('Because of the small sign.'), findsOneWidget);
      expect(find.byType(TapScale), findsNothing, reason: 'options are done');

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(done, [true]);
    });

    testWidgets('a reveal names the right answer and explains', (tester) async {
      await pump(tester, card(explain: 'Because of the small sign.'));
      await tester.tap(find.text('opt0'));
      await tester.pump();
      await tester.tap(find.text('opt1'));
      await tester.pump();
      expect(find.text("Not quite — it's this one:"), findsOneWidget);
      expect(find.text('opt2'), findsOneWidget, reason: 'the right one, shown');
      expect(find.text('Because of the small sign.'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(done, [false]);
    });

    testWidgets('Next reports once however often it is tapped', (tester) async {
      await pump(tester, card(explain: 'x'));
      await tester.tap(find.text('opt2'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pump();
      expect(done, hasLength(1));
    });
  });

  testWidgets('a long display and four options fit a 320×568 phone', (
    tester,
  ) async {
    await pump(
      tester,
      KidsChoiceCard(
        prompt: 'What does this mark mean?',
        display: Text('long verse ' * 30),
        options: [for (var i = 0; i < 4; i++) Text('An option number $i')],
        correct: 1,
        hint: 'A fairly long pointing hint that wraps onto a second line.',
        explain:
            'A longer explanation that goes on for a couple of lines so '
            'that the panel has to hold real text.',
        onDone: done.add,
      ),
    );
    // The smallest phone we support.
    tester.view.physicalSize = const Size(640, 1136);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('An option number 0'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('An option number 2'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
