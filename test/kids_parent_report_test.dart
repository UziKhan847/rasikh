import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_me_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_parent_report.dart';

import 'kids_test_support.dart';

/// The grown-up's read-only view. Derived entirely from what is already
/// stored on-device; reached only through the parent gate.
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
  AppSettings settings,
  ProgressStore prog,
  Widget child,
) => tester.pumpWidget(
  SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: prog,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every stage maps to one of the five conversation prompts', () {
    expect(KidsParentReport.talkKey('letters'), 'shapes');
    expect(KidsParentReport.talkKey('forms.more'), 'shapes');
    expect(KidsParentReport.talkKey('special.quiz'), 'shapes');
    expect(KidsParentReport.talkKey('harakat'), 'sounds');
    expect(KidsParentReport.talkKey('muqattaat'), 'sounds');
    expect(KidsParentReport.talkKey('waqf'), 'rules');
    expect(KidsParentReport.talkKey('tajwid.nun'), 'rules');
    expect(KidsParentReport.talkKey('words.two'), 'reading');
    expect(KidsParentReport.talkKey('capstone'), 'reading');
    expect(KidsParentReport.talkKey('review'), 'general');
  });

  testWidgets('a brand-new child: first stage, nothing to revisit', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(tester, settings, prog, const KidsParentReport());
    await tester.pump();

    expect(find.byType(Material), findsWidgets);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Learning now: The Letters'), findsOneWidget);
    expect(find.textContaining('0 of '), findsOneWidget);
    expect(find.text('0 days in a row'), findsOneWidget);
    expect(
      find.textContaining('nothing to revisit', findRichText: true),
      findsNothing,
    );
    expect(
      find.text('Nothing to revisit yet — that is a good sign.'),
      findsOneWidget,
    );
    // A shape-stage prompt, not a rule or reading one.
    expect(find.textContaining('trace it in the air'), findsOneWidget);
  });

  testWidgets('shows real progress, the shakiest items, and the queue', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.report('kids.letter.ا', 3);
    prog.report('kids.letter.ب', 3);
    prog.recordMiss(
      'letter.ت',
      'ت',
      answer: 'Tā’',
      distractors: const ['Bā’', 'Thā’'],
    );
    prog.recordMiss(
      'letter.ت',
      'ت',
      answer: 'Tā’',
      distractors: const ['Bā’', 'Thā’'],
    );
    prog.recordMiss(
      'letter.ث',
      'ث',
      answer: 'Thā’',
      distractors: const ['Bā’', 'Tā’'],
    );
    await _pump(tester, settings, prog, const KidsParentReport());
    await tester.pump();

    // The first two tiles are done, so the report is past zero.
    expect(find.textContaining('2 of '), findsOneWidget);
    // Most-missed first (lapses), both due today.
    expect(find.text('ت'), findsOneWidget);
    expect(find.text('ث'), findsOneWidget);
    expect(find.text('2 waiting in the Warm-up'), findsOneWidget);
  });

  testWidgets('the Me tab puts the report behind the parent gate', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(tester, settings, prog, const KidsMeScreen());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Progress report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Progress report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The gate, not the report itself.
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.byType(KidsParentReport), findsNothing);
  });
}
