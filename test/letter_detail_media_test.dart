import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/extra_letters.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart' show TracingBoard;

/// The adult Qaidah Path's Letters had no audio control at all before this —
/// Listen (the letter's own sound, via [LetterAudio], never a verse) and
/// Watch (a real stroke-by-stroke replay, via [TracingBoard]'s watch mode).
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  return settings;
}

Widget _harness(AppSettings settings, Widget child) => SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a core letter offers both Listen and Watch', (tester) async {
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, LetterDetail(letter: letterFor('ب'))));
    await tester.pumpAndSettle();

    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
  });

  testWidgets('Watch opens a real stroke replay, not a coming-soon stub',
      (tester) async {
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, LetterDetail(letter: letterFor('ب'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch'));
    await tester.pump(); // open the bottom sheet
    await tester.pump(const Duration(milliseconds: 300)); // its entry animation

    expect(find.byType(TracingBoard), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
  });

  testWidgets('Listen says so honestly when no clip is bundled yet',
      (tester) async {
    LetterAudio.log = null; // exercise the real path
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, LetterDetail(letter: letterFor('ب'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets('an extra letter with no stroke data offers Listen but not Watch',
      (tester) async {
    final settings = await _boot();
    final hamza = extraLetters.firstWhere((l) => l.char == 'ء');
    await tester.pumpWidget(_harness(settings, LetterDetail(letter: hamza)));
    await tester.pumpAndSettle();

    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Watch'), findsNothing,
        reason: 'hamza has no bundled tracing stroke data to animate');
  });
}
