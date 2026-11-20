import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/history_screen.dart';
import 'package:rasikh/screens/marks/marks_stats_screen.dart';
import 'package:rasikh/screens/marks/mutashabihat_screen.dart';
import 'package:rasikh/screens/mushaf/mushaf_zoom.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Everything over the muṣḥaf is an overlay on it, and whatever leads to a
/// page goes back to the home muṣḥaf — never a second, older one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  const far = WordRef(18, 60, 1); // al-Kahf: far from page 50

  Future<(ProgressStore, MarksStore, String)> home(WidgetTester tester) async {
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
    final b = m.ensureActiveBook('Me').id;
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
    await settle(tester);
    return (p, m, b);
  }

  int pageOf(WordRef r) => MushafRepo.pageOfWord('uthmani', r.globalAyah, r.word0);

  testWidgets('a session in History: back to the home muṣḥaf at its place, '
      'no second muṣḥaf', (tester) async {
    final (p, m, b) = await home(tester);
    final ses = m.startSession(bookId: b, script: 'uthmani');
    m.endSession(b, ses.id, fromGlobalAyah: far.globalAyah, toGlobalAyah: far.globalAyah);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.tap(find.textContaining('18:60'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsNothing, reason: 'closed');
    expect(find.byType(MushafPageScreen), findsOneWidget, reason: 'the home one only');
    expect(p.lastMushafPage, anyOf(pageOf(far), pageOf(far) - 1, pageOf(far) + 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('statistics and mutashābihāt open over the page, wide on desktop, '
      'and a mutashābih goes back to the home muṣḥaf', (tester) async {
    final (p, m, b) = await home(tester);
    m.addMark(b, far, MarkType.mutashabih);
    m.addMark(b, const WordRef(2, 10, 1), MarkType.mistake);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    // The statistics card at the top of History.
    await tester.tap(find.textContaining('Total'));
    await tester.pumpAndSettle();
    expect(find.byType(MarksStatsScreen), findsOneWidget);
    expect(find.byType(MushafPageScreen), findsOneWidget, reason: 'still under it');
    expect(tester.getSize(find.byType(MarksStatsScreen)).width, greaterThan(700),
        reason: 'a wide panel, not a phone in a frame');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MarksStatsScreen), findsNothing);
    expect(find.byType(HistoryScreen), findsOneWidget, reason: 'back to History');

    await tester.scrollUntilVisible(find.text('My mutashābihāt'), 200,
        scrollable: find.descendant(
            of: find.byType(HistoryScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('My mutashābihāt'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MutashabihatScreen), findsOneWidget);
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(tester.getSize(find.byType(MutashabihatScreen)).width, greaterThan(700));

    // Its muṣḥaf button: the home page, at that word, every overlay gone.
    await tester.tap(find.byTooltip('Open in the muṣḥaf').first);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MutashabihatScreen), findsNothing);
    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(p.lastMushafPage, anyOf(pageOf(far), pageOf(far) - 1, pageOf(far) + 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('zoomed all the way, zooming on leaves the page where it is', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final held = MushafZoom.zoomHeld;
    MushafZoom.zoomHeld = () => true;
    addTearDown(() => MushafZoom.zoomHeld = held);
    final t = TransformationController();
    var active = false;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, set) => MaterialApp(
        home: MushafZoom(
          active: active,
          onActive: (v) => set(() => active = v),
          controller: t,
          child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
        ),
      ),
    ));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    const at = Offset(300, 300);
    Future<void> wheelIn() async {
      await tester.sendEventToBinding(mouse.hover(at));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.pump();
    }

    // In until it's all the way in, and no further yet.
    while (t.value.getMaxScaleOnAxis() < MushafZoom.maxScale - 1e-9) {
      await wheelIn();
    }
    expect(t.value.getMaxScaleOnAxis(), closeTo(MushafZoom.maxScale, 1e-6));
    final there = t.value.getTranslation();
    for (var i = 0; i < 10; i++) {
      await wheelIn();
    }
    expect(t.value.getTranslation().x, closeTo(there.x, 1e-6), reason: 'no drift sideways');
    expect(t.value.getTranslation().y, closeTo(there.y, 1e-6));
    // The point under the pointer is still under it.
    final under = MatrixUtils.transformPoint(Matrix4.inverted(t.value), at);
    final again = MatrixUtils.transformPoint(t.value, under);
    expect((again - at).distance, lessThan(1e-6));
  });

  testWidgets('zoomed: the wheel\'s button comments, only with Ctrl does it move the page',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var ctrl = false;
    final held = MushafZoom.zoomHeld;
    MushafZoom.zoomHeld = () => ctrl;
    addTearDown(() => MushafZoom.zoomHeld = held);
    final t = TransformationController(Matrix4.identity()
      ..translateByDouble(-500, -400, 0, 1)
      ..scaleByDouble(2, 2, 1, 1));
    // What a word does with the press (the comment): sees it whatever wins.
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      home: MushafZoom(
        active: true,
        onActive: (_) {},
        controller: t,
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == kMiddleMouseButton) presses++;
          },
          child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
        ),
      ),
    ));
    Offset where() => Offset(t.value.getTranslation().x, t.value.getTranslation().y);
    final start = where();
    Future<void> drag(int buttons) async {
      final g = await tester.startGesture(const Offset(500, 400),
          kind: PointerDeviceKind.mouse, buttons: buttons);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(12, 9));
        await tester.pump();
      }
      await g.up();
      await tester.pump();
    }

    await drag(kMiddleMouseButton);
    expect(presses, 1, reason: 'the comment, once');
    expect(where(), start, reason: 'the page stays put under the comment');

    ctrl = true;
    await drag(kMiddleMouseButton);
    expect(where().dx, greaterThan(start.dx), reason: 'Ctrl and the wheel\'s button: across');
    expect(where().dy, greaterThan(start.dy), reason: 'and up and down');
    ctrl = false;

    final before = where();
    await drag(kPrimaryButton);
    expect(where(), isNot(before), reason: 'a plain drag still moves the zoomed page');
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}
