import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_review_recap.dart';

import 'kids_test_support.dart';

/// A "look how far you've come" recap of every stage cleared, not the stale
/// grown-up table of contents (which predates waṣl and the muqaṭṭaʿāt
/// existing as their own stages, and mentions neither).
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
      home:
          child, // no Scaffold here: the widget itself must supply its own Material
      // ancestor (KidsLessonScaffold), exactly like pushKidsOverlay hosts it.
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows every major stage, including waṣl and the muqaṭṭaʿāt', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(settings, prog, const KidsReviewRecap()));
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining("how far you've come"), findsOneWidget);
    for (final title in [
      'The Letters',
      'Joining Shapes',
      'Ḥarakāt',
      'Sukūn',
      'Shaddah',
      'Madd & Līn',
      'Tanwīn',
      'Ḥurūf Muqaṭṭaʿāt',
      'Reading Words',
      'Waṣl',
      'Sun and Moon Letters',
      'Waqf & Stopping',
    ]) {
      expect(find.textContaining(title), findsWidgets, reason: title);
    }
  });
}
