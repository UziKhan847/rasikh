import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/fluency/plan.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/fluency/cold_read_screen.dart';

import 'test_support.dart';

/// The 12-week plan: cold reads only on unseen passages, its phases'
/// checks, and a cold read from start to tracker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('cold passages: the phase\'s sūrahs, none heard, known or used', () async {
    SharedPreferences.setMockInitialValues({});
    final f = FluencyStore();
    await f.load();
    final first = coldPassages(f, 'uthmani', 1).first;
    expect(MushafRepo.surahAyahOf(first.$1).$1, 78);
    // Heard: the next one instead.
    f.markHeard(first.$1);
    final second = coldPassages(f, 'uthmani', 1).first;
    expect(second, isNot(first));
    // Known by heart, and used: skipped too.
    f.setKnown(MushafRepo.tokenOf('uthmani', second.$1, 0), true);
    final third = coldPassages(f, 'uthmani', 1).first;
    f.addColdRead(ColdRead(
        at: 1,
        firstTok: MushafRepo.tokenOf('uthmani', third.$1, 0),
        lastTok: MushafRepo.tokenOf('uthmani', third.$2, -1),
        script: 'uthmani',
        wordsCorrect: 30));
    expect(coldPassages(f, 'uthmani', 1).first, isNot(third));
    // Weeks 7–9: the narrative sūrahs.
    expect(MushafRepo.surahAyahOf(coldPassages(f, 'uthmani', 8).first.$1).$1, 12);
  });

  test('checks: the cold read up 25% on the baseline', () async {
    SharedPreferences.setMockInitialValues({});
    final f = FluencyStore();
    await f.load();
    ColdRead read(int w) => ColdRead(at: w, firstTok: 0, lastTok: 1, script: 'uthmani', wordsCorrect: w);
    f.addColdRead(read(40));
    expect(checksOf(PlanPhase.transfer, f, 'uthmani').single.met, isNull);
    f.addColdRead(read(45));
    expect(checksOf(PlanPhase.transfer, f, 'uthmani').single.met, isFalse);
    f.addColdRead(read(52));
    expect(checksOf(PlanPhase.transfer, f, 'uthmani').single.met, isTrue);
  });

  testWidgets('a cold read: the last word reached, a misread, saved', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final f = FluencyStore();
    await f.load();
    await tester.pumpWidget(FluencyScope(
      store: f,
      child: SettingsScope(
        settings: s,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: ColdReadScreen(seconds: 1),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Start the minute'), findsOneWidget);
    await tester.tap(find.byType(Switch).last); // no recording in a test
    await tester.pump();
    await tester.tap(find.text('Start the minute'));
    await tester.pump(const Duration(seconds: 3)); // 3, 2, 1
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Tap the last word you read'), findsOneWidget);
    // The text's 6th word, then the 2nd as misread.
    final text = find.byType(RichText).evaluate().map((e) => e.renderObject! as RenderParagraph)
        .firstWhere((r) => r.text.toPlainText().length > 50);
    Offset wordAt(int i) {
      final plain = text.text.toPlainText();
      final starts = <int>[0];
      for (var k = 0; k < plain.length; k++) {
        if (plain[k] == ' ') starts.add(k + 1);
      }
      final end = i + 1 < starts.length ? starts[i + 1] - 1 : plain.length;
      final boxes = text.getBoxesForSelection(
          TextSelection(baseOffset: starts[i], extentOffset: end));
      return text.localToGlobal(boxes.first.toRect().center);
    }

    await tester.tapAt(wordAt(5));
    await tester.pump();
    expect(find.text('6 words correct'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tapAt(wordAt(1));
    await tester.pump();
    expect(find.text('5 words correct'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(f.coldReads.single.wordsCorrect, 5);
    expect(f.blocksDoneToday, contains('cold'));
    await f.flush();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
