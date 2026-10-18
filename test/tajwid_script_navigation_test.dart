import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/script_screen.dart';
import 'package:qiraah_arabiyyah/screens/tajweed_screen.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

/// Widget-interaction checks for the Round 6-9 restructure: the Tajwīd path
/// (Learn/Letters/Test/Practice/Recite, with Recite always "coming soon"),
/// the new Script & Symbols section, and [MediaRow]'s Listen/Watch buttons —
/// things a data-file test can't see: real navigation, real taps, and that a
/// null-builder phase dims and shows a snackbar instead of pushing a route.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress, Widget child) {
  return SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: progress,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Tajwīd path: a rule-family unit opens a 5-phase hub, and Recite is '
      'coming-soon rather than navigating', (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const TajweedScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Nūn Sākinah & Tanwīn'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Nūn Sākinah & Tanwīn'));
    await tester.pumpAndSettle();

    // All five phases are listed, including the disabled Recite.
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Letters'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Recite'), findsOneWidget);

    // Tapping Recite shows a coming-soon snackbar and does NOT navigate —
    // the hub (with all five phase labels) is still on screen.
    await tester.ensureVisible(find.text('Recite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recite'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Learn opens a real lesson screen.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Nūn Sākinah & Tanwīn'), findsWidgets); // AppBar title
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Test opens a real graded quiz.
    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  testWidgets(
      'Tajwīd path: Makhārij\'s Learn drills down (5 zones → Tongue\'s points → '
      'a point\'s detail page), which carries real examples and a MediaRow',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const TajweedScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Makhārij'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Makhārij'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    // The Learn phase now opens a 5-zone index — Oral Cavity, Throat,
    // Tongue, Lips, Nasal Cavity — not a flat list of 17 makhārij.
    expect(find.text('The Tongue'), findsOneWidget);
    expect(find.text('The Throat'), findsOneWidget);

    // The Tongue has 10 points grouped into 4 sub-headings — tapping it
    // opens that grouped index, not a single detail page (10 points, so the
    // single-child collapse rule does not apply here).
    await tester.tap(find.text('The Tongue'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tongue Tip — Nūn'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Tongue Tip — Nūn'), findsOneWidget);

    // Tapping one point reaches its detail page: real corpus examples and a
    // MediaRow that can really play audio (Round 10 gave every makhraj real
    // examples).
    await tester.tap(find.text('Tongue Tip — Nūn'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(MediaRow), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(MediaRow), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);

    // Watch is always coming-soon, regardless of ref — no video pipeline
    // exists anywhere in the app.
    await tester.tap(find.text('Watch'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('MediaRow: Listen falls back to coming-soon when there is no ref',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(
        settings, progress, const Scaffold(body: MediaRow(ref: null))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('MediaRow: Watch is always coming-soon, even with a real ref',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(
        settings, progress, const Scaffold(body: MediaRow(ref: '1:1'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Script & Symbols: Waqf & Stopping unit reaches all three phases',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const ScriptScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Waqf & Stopping'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Waqf & Stopping'));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Waqf & Stopping'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  testWidgets('Script & Symbols: all four units are reachable from the list',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const ScriptScreen()));
    await tester.pumpAndSettle();

    for (final title in [
      'Script Families',
      'Marks & Signs',
      'Waqf & Stopping',
      'Page Marks',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });
}
