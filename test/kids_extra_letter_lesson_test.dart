import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';

import 'kids_test_support.dart';

/// A single "meet this character" card for a letter the 28-letter alphabet
/// doesn't cover (hamza carriers, tāʼ marbūṭah, alif maqṣūrah, alif
/// al-waṣl) — not `LetterDetail`, the full grown-up letter screen this
/// stage used to push straight into Kids Mode.
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
      home: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the hamza carrier, its name, and a real example', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsExtraLetterLesson(char: 'أ')),
    );
    await tester.pump();

    expect(find.byType(Material), findsWidgets);
    expect(find.text('Hamzah on Alif'), findsOneWidget);
    expect(find.textContaining('أُنزِلَ', findRichText: true), findsOneWidget);
  });

  testWidgets('shows tāʼ marbūṭah with its stopping note', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsExtraLetterLesson(char: 'ة')),
    );
    await tester.pump();

    expect(find.text('Tā’ Marbūṭah'), findsOneWidget);
    expect(find.textContaining('soft'), findsOneWidget);
  });
}
