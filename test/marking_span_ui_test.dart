import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/divisions.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/review_bar.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf/mushaf_zoom.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/ui/mark_style.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    MarksStore.ayahWords = (g) => MushafRepo.wordCount('uthmani', g);
  });

  Future<(MarksStore, String)> home(WidgetTester tester) async {
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
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    return (m, b);
  }

  /// Where each word of page 50's lines is on the screen.
  Map<(int, int), Offset> wordsOnScreen(WidgetTester tester) {
    final out = <(int, int), Offset>{};
    void visit(RenderObject o) {
      if (o is RenderMushafLine && o.attached && o.spec.page == 50) {
        final ws = o.spec.line.words;
        for (var i = 0; i < ws.length; i++) {
          final r = o.wordRect(i);
          if (r != null && !ws[i].isMarker) {
            out[(ws[i].ayah, ws[i].wordIdx)] = o.localToGlobal(r.center);
          }
        }
      }
      o.visitChildren(visit);
    }

    visit(tester.binding.rootElement!.renderObject!);
    return out;
  }

  testWidgets('Shift and a drag from one word to one in the next āyah: one '
      'mistake over all of them; Shift and a click, one word as ever', (tester) async {
    final (m, b) = await home(tester);
    final words = wordsOnScreen(tester);
    // Two āyāt on screen, one after the other.
    final g = words.keys
        .map((k) => k.$1)
        .firstWhere((g) => words.containsKey((g, 0)) && words.containsKey((g, 1)) &&
            words.containsKey((g + 1, 1)) && words.containsKey((g + 1, 3)));
    final from = words[(g, 1)]!, to = words[(g + 1, 1)]!;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final mouse = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await mouse.moveTo(Offset.lerp(from, to, .5)!);
    await mouse.moveTo(to);
    await tester.pump();
    expect(find.byKey(const ValueKey('span-label')), findsOneWidget, reason: 'where it runs');
    await mouse.up();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('span-label')), findsNothing);

    final mark = m.marksOf(b).single;
    expect(mark.type, MarkType.mistake);
    expect(mark.ref, WordRef.fromGlobal(g, 1));
    expect(mark.to, WordRef.fromGlobal(g + 1, 1));
    final n = MushafRepo.wordCount('uthmani', g);
    for (var w = 1; w < n; w++) {
      expect(m.marksAt(b, WordRef.fromGlobal(g, w)), hasLength(1));
    }
    expect(m.marksAt(b, WordRef.fromGlobal(g + 1, 0)), hasLength(1));
    expect(m.marksAt(b, WordRef.fromGlobal(g, 0)), isEmpty);

    // A click (no drag) with Shift: that word alone, as before.
    final other = words[(g + 1, 3)]!;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final click = await tester.startGesture(other, kind: PointerDeviceKind.mouse);
    await click.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(m.marksOf(b), hasLength(2));
    expect(m.marksAt(b, WordRef.fromGlobal(g + 1, 3)).single.to, isNull);
    await tester.pump(const Duration(seconds: 3));
    await m.flush();
  });

  testWidgets('the review bar: next on the left, previous on the right, as '
      'the text reads', (tester) async {
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Me').id;
    m.addMark(b, const WordRef(2, 10, 1), MarkType.mistake);
    m.addMark(b, const WordRef(2, 20, 1), MarkType.mistake);
    final c = ReviewController.start(m, b, const ReviewQuery(), session: false);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ReviewBar(
          controller: c,
          pal: markPaletteFor(paletteOf(AppTheme.light)),
          bg: Colors.white,
          ink: Colors.black,
          sub: Colors.grey,
          line: Colors.grey,
          accent: Colors.teal,
          onRepeatWord: () {},
          onRepeatVerse: () {},
          onOpenWord: () {},
          onEnd: () {},
        ),
      ),
    ));
    final next = tester.getCenter(find.byTooltip('Next')).dx;
    final prev = tester.getCenter(find.byTooltip('Previous')).dx;
    expect(next, lessThan(prev));
    // And where: the menu of places.
    await tester.tap(find.byKey(const ValueKey('review-where')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('where-surah')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('where-surah')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('where-surah-2')));
    await tester.pumpAndSettle();
    expect(c.where, (Division.surah, 2));
    expect(find.text('Sūrah 2'), findsOneWidget);
  });

  testWidgets('Ctrl and the wheel\'s button, dragged: the zoomed page moves', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1)..translateByDouble(-200, -200, 0, 1));
    await tester.pumpWidget(MaterialApp(
      home: MushafZoom(
        active: true,
        onActive: (_) {},
        controller: t,
        child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
      ),
    ));
    final before = t.value.getTranslation();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final g = await tester.startGesture(const Offset(500, 400),
        kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await g.moveBy(const Offset(60, 30));
    await g.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final after = t.value.getTranslation();
    expect(after.x - before.x, closeTo(60, .01));
    expect(after.y - before.y, closeTo(30, .01));
  });
}
