import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/history_screen.dart';
import 'package:rasikh/screens/mushaf/hifz_layout.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Where the pages stand, monochrome, History over the page, and its key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Size box(Size a) {
    final w = a.height * .62 < a.width ? a.height * .62 : a.width;
    return Size(w, w / .62);
  }

  group('the pages on a wide window', () {
    const size = Size(1600, 900);
    HifzLayout at(String align, {bool dockLeft = false}) =>
        HifzLayout.resolve(size, EdgeInsets.zero, pageBox: box, align: align, dockLeft: dockLeft);

    test('left: the slot by the dock; right: the slot on the left', () {
      final left = at('left');
      expect(left.slot.left, greaterThan(size.width / 2));
      expect(left.pagesInset.right, greaterThan(0));
      final right = at('right');
      expect(right.slot.right, lessThan(size.width / 2));
      expect(right.pagesInset.left, greaterThan(0));
      expect(right.pagesInset.right, 0);
    });

    test('centre: the pages in the middle, the slot in a margin', () {
      final c = at('center');
      expect(c.pagesInset, EdgeInsets.zero);
      expect(c.slotAxis, Axis.vertical);
      expect(c.slot.left, greaterThan(size.width / 2));
    });

    test('auto is away from the dock, either side', () {
      expect(at('auto').slot.left, greaterThan(size.width / 2));
      expect(at('auto', dockLeft: true).slot.right, lessThan(size.width / 2));
      // Left means the screen's left whichever side the dock's on.
      expect(at('left', dockLeft: true).pagesInset.right, greaterThan(0));
    });
  });

  test('monochrome, light and dark, kept by the dark/light switch', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.setMonochrome(true);
    expect(s.appTheme, 'mono');
    expect(s.isMonochrome, isTrue);
    s.toggleDark();
    expect(s.isDarkTheme, isTrue);
    expect(s.mushafPaperDark, 'mono');
    expect(s.isMonochrome, isTrue);
    s.toggleDark();
    expect(s.appTheme, 'mono');
    s.setMonochrome(false);
    expect(s.appTheme, 'light');
  });

  testWidgets('History opens over the page, and Esc or H closes and opens it', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..toolHintSeen = true
      ..desktopMode = 'on';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.byType(MushafPageScreen), findsOneWidget, reason: 'still under it');
    expect(tester.takeException(), isNull, reason: 'a Material under its text');
    await tester.tapAt(const Offset(10, 450));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsNothing, reason: 'a click beside it closes it');
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });
}
