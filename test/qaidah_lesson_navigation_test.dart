import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart';

/// Widget-interaction checks for the Round 12 Learn-phase restructure: a
/// unit holding a single concept opens its explanation directly (no one-row
/// menu), and Tanwīn's 12-card flat list became a real 3-entry drill-down.
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
      'Shaddah\'s Learn opens the explanation directly — no intermediate '
      'one-row menu, since the unit holds exactly one concept', (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Shaddah'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Shaddah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    // Landed straight on the detail page: its build strip (سākin + voweled
    // = doubled) and examples are visible immediately, not a 1-row list
    // that still needs one more tap.
    expect(find.textContaining('Shaddah'), findsWidgets);
    expect(find.textContaining('Examples'), findsOneWidget);
  });

  testWidgets(
      'Tanwīn\'s Learn lists exactly 3 (Fatḥatān/Kasratān/Ḍammatān), not the '
      'old flat 12-card list', (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Tanwīn'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Tanwīn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.text('Fatḥatān'), findsOneWidget);
    expect(find.text('Kasratān'), findsOneWidget);
    expect(find.text('Ḍammatān'), findsOneWidget);

    // Fatḥatān alone has the "how it's written" breakdown (3 spellings) —
    // tapping it opens an index, not a detail page, since it has more than
    // one child.
    await tester.tap(find.text('Fatḥatān'));
    await tester.pumpAndSettle();
    expect(find.text('With a Trailing Alif'), findsOneWidget);
    expect(find.text('On Tāʼ Marbūṭah'), findsOneWidget);
    expect(find.text('After a Hamzah Already Seated on an Alif'), findsOneWidget);
  });
}
