import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/fluency/joins.dart';
import 'package:rasikh/core/fluency/words.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/fluency/fluency_tools.dart';
import 'package:rasikh/screens/marks/marking.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Fluency marks: one tap stepping a word on, undo, Alt and a click, the
/// right-click menu, the split by letters, and Review going over them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<FluencyStore> fluency() async {
    SharedPreferences.setMockInitialValues({});
    final f = FluencyStore();
    await f.load();
    return f;
  }

  const ref = WordRef(2, 255, 3);

  test('a tap steps the word: not fluent, paired, a chunk, off', () async {
    final f = await fluency();
    expect(fluencyKindAt(f, ref), isNull);
    cycleFluency(f, 'uthmani', ref);
    expect(fluencyKindAt(f, ref), FluencyKind.word);
    cycleFluency(f, 'uthmani', ref);
    expect(fluencyKindAt(f, ref), FluencyKind.pair);
    expect(f.isSlow(ref), isFalse, reason: 'one step at a time');
    cycleFluency(f, 'uthmani', ref);
    expect(fluencyKindAt(f, ref), FluencyKind.chunk);
    expect(f.markAt(FluencyKind.pair, ref), isNull);
    final c = f.markAt(FluencyKind.chunk, ref)!;
    expect(c.prefix + c.suffix, greaterThan(0), reason: 'a split to start from');
    cycleFluency(f, 'uthmani', ref);
    expect(fluencyKindAt(f, ref), isNull);
  });

  test('undo takes a step back, redo puts it back', () async {
    final f = await fluency();
    final s1 = cycleFluency(f, 'uthmani', ref)!;
    final s2 = cycleFluency(f, 'uthmani', ref)!;
    expect(fluencyKindAt(f, ref), FluencyKind.pair);
    final redo2 = f.restoreSnapshot(s2.before);
    expect(fluencyKindAt(f, ref), FluencyKind.word);
    f.restoreSnapshot(redo2);
    expect(fluencyKindAt(f, ref), FluencyKind.pair);
    f.restoreSnapshot(s2.before);
    f.restoreSnapshot(s1.before);
    expect(fluencyKindAt(f, ref), isNull);
  });

  group('Review', () {
    late MarksStore m;
    late String b;
    late FluencyStore f;
    setUp(() async {
      f = await fluency();
      m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
      b = m.ensureActiveBook('Me').id;
      m.addMark(b, const WordRef(2, 255, 1), MarkType.mistake);
      cycleFluency(f, 'uthmani', ref);
      cycleFluency(f, 'uthmani', const WordRef(2, 256, 2));
    });

    test('memorization marks, fluency marks, or all, in the muṣḥaf\'s order', () {
      List<Mark> q(ReviewScope s) =>
          buildReviewQueue(m, b, ReviewQuery(scope: s, status: ReviewStatus.any), fluency: f);
      expect(q(ReviewScope.marks).map((x) => x.type), [MarkType.mistake]);
      expect(q(ReviewScope.fluency).map((x) => x.type),
          [MarkType.fluencySlow, MarkType.fluencySlow]);
      final all = q(ReviewScope.all);
      expect(all, hasLength(3));
      expect(all.first.type, MarkType.mistake, reason: '2:255 word 1 comes first');
    });

    test('a fluency mark is rated, not fixed, and the review moves on', () {
      final c = ReviewController.start(m, b, const ReviewQuery(scope: ReviewScope.fluency),
          fluency: f, session: false);
      expect(c.onFluency, isTrue);
      expect(c.markFixed(), isFalse);
      final id = c.current!.id;
      expect(c.rate(Recall.instant), isTrue);
      expect(c.current!.id, isNot(id));
      final mark = f.marks.firstWhere((x) => 'fl:${x.id}' == id);
      expect(f.progressOf(mark.cardId)?.instantDays, isNotEmpty);
    });
  });

  testWidgets('the split: a tap between letters moves the chosen edge', (tester) async {
    final f = await fluency();
    final s = AppSettings();
    await s.load();
    final form = formOf('uthmani', ref);
    final n = clustersOf(form).length;
    late BuildContext ctx;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: FluencyScope(
        store: f,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold();
          }),
        ),
      ),
    ));
    showChunkEditor(ctx, 'uthmani', ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gap-1')));
    await tester.pump();
    await tester.tap(find.text('Suffix starts'));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('gap-${n - 1}')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final c = f.markAt(FluencyKind.chunk, ref)!;
    expect((c.prefix, c.suffix), (1, 1));
  });

  group('on the page, desktop', () {
    Future<(AppSettings, FluencyStore, MarksStore)> pump(WidgetTester tester) async {
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
      final f = FluencyStore();
      await f.load();
      final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
      m.ensureActiveBook('Me');
      await tester.pumpWidget(MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: FluencyScope(
              store: f,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
              ),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 80));
      }
      return (s, f, m);
    }

    (Offset, WordRef) word(WidgetTester tester) {
      final line = tester
          .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
          .firstWhere((r) => r.attached && r.spec.page == 50 && r.spec.line.words.length > 3);
      final i = line.spec.line.words.indexWhere((w) => !w.isMarker);
      final wd = line.spec.line.words[i];
      return (line.localToGlobal(line.wordRect(i)!.center), WordRef.fromGlobal(wd.ayah, wd.wordIdx));
    }

    testWidgets('Alt and a click steps its fluency; Ctrl+Z takes it back', (tester) async {
      final (_, f, m) = await pump(tester);
      final (at, r) = word(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      expect(fluencyKindAt(f, r), FluencyKind.pair);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(fluencyKindAt(f, r), FluencyKind.word);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('the right-click menu has the three, each a tick when on', (tester) async {
      final (_, f, m) = await pump(tester);
      final (at, r) = word(tester);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      for (final t in ['Not fluent', 'Pair', 'Chunk']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      expect(f.markAt(FluencyKind.pair, r), isNotNull);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  test('the controller keeps fluency steps for undo too', () async {
    final f = await fluency();
    final c = MarkingController();
    c.recordStep(cycleFluency(f, 'uthmani', ref)!);
    expect(c.canUndo, isTrue);
  });
}
