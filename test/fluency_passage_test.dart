import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/fluency/madd_screen.dart';
import 'package:qiraah_arabiyyah/screens/fluency/passage_screen.dart';

import 'test_support.dart';

/// Passage practice: words → pairs → half-verses → verses → three timed
/// readings; the plan's modeling by week.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('modeling fades with the weeks', () {
    expect(modelingOfWeek(2), Modeling.first);
    expect(modelingOfWeek(8), Modeling.after);
    expect(modelingOfWeek(11), Modeling.none);
  });

  test('madd counts: words with a madd, the long ones first', () async {
    SharedPreferences.setMockInitialValues({});
    final f = FluencyStore();
    await f.load();
    final ws = maddWords(f, 'uthmani');
    expect(ws, isNotEmpty);
    expect(ws.first.$2.kind, isNot('natural'));
  });

  test('a passage stays in its sūrah, about 40 words', () {
    final g = MushafRepo.globalAyahOf(1, 7);
    expect(passageFrom('uthmani', g), (g, g), reason: 'al-Fātiḥah ends there');
    final (a, b) = passageFrom('uthmani', MushafRepo.globalAyahOf(2, 30));
    var n = 0;
    for (var x = a; x <= b; x++) {
      n += MushafRepo.ayahTokens('uthmani', x).$2.where((w) => !w.isMarker).length;
    }
    expect(n, lessThanOrEqualTo(40));
  });

  testWidgets('the steps in order, then three timed readings', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final f = FluencyStore();
    await f.load();
    // Week 11: no modeling (nothing to play in a test).
    f.planStart = DateTime.now().subtract(const Duration(days: 72)).millisecondsSinceEpoch;
    final g = MushafRepo.globalAyahOf(112, 1); // short: قُلْ هُوَ ٱللَّهُ أَحَدٌ
    await tester.pumpWidget(FluencyScope(
      store: f,
      child: SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: PassageScreen(from: g, to: g),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    Future<void> through(String step) async {
      expect(find.text(step), findsOneWidget);
      while (find.text(step).evaluate().isNotEmpty) {
        await tester.tap(find.text('Next').last);
        await tester.pump();
      }
    }

    await through('Words alone');
    await through('Pairs');
    await through('Half-verses');
    // Whole verses: a silent preview first (word by word), then aloud.
    expect(find.text('Whole verses'), findsOneWidget);
    while (find.text('Whole verses').evaluate().isNotEmpty) {
      await tester.tap(find.textContaining(RegExp(r'^(Next|Now aloud)$')).last);
      await tester.pump();
    }
    expect(find.text('Read it three times'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.text('Start reading $i'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('Done ·'));
      await tester.pump();
    }
    expect(f.blocksDoneToday, contains('buildup'));
    await f.flush();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
