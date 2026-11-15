import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/report.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/marking.dart';
import 'package:rasikh/screens/marks/marking_bar.dart';
import 'package:rasikh/screens/marks/quick_insert.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Mark mode's tools: desktop mode's pens, breath marks, and the quick buttons
/// in a comment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<(MarksStore, String)> store() async {
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (m, m.ensureActiveBook('Me').id);
  }

  group('a pen', () {
    const w = WordRef(2, 255, 3);

    test('puts itself on, comes off with a second tap, and changes another pen\'s mark',
        () async {
      final (m, b) = await store();
      final s = m.startSession(bookId: b, script: 'uthmani').id;
      expect(m.applyPen(b, w, MarkType.tajwid, sessionId: s).$2, MarkType.tajwid);
      expect(m.marksAt(b, w).single.type, MarkType.tajwid);
      expect(m.applyPen(b, w, MarkType.tajwid, sessionId: s).$2, isNull);
      expect(m.marksAt(b, w), isEmpty);
      m.applyPen(b, w, MarkType.mistake, sessionId: s);
      final (op, type) = m.applyPen(b, w, MarkType.doubt, sessionId: s);
      expect(type, MarkType.doubt);
      expect(m.marksAt(b, w).single.type, MarkType.doubt);
      m.undo(op);
      expect(m.marksAt(b, w).single.type, MarkType.mistake);
      await m.flush();
    });

    test('a note pen keeps its words', () async {
      final (m, b) = await store();
      m.applyPen(b, w, MarkType.note, comment: 'look again');
      expect(m.marksAt(b, w).single.comment, 'look again');
      await m.flush();
    });
  });

  group('on the home', () {
    Future<(AppSettings, MarksStore)> pump(WidgetTester tester, String mode) async {
      tester.view.physicalSize = const Size(1000, 700);
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
        ..desktopMode = mode;
      final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
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
        await tester.pump(const Duration(milliseconds: 60));
      }
      return (s, m);
    }

    testWidgets('desktop: the keys choose a pen, the bar shows the pens', (tester) async {
      final (s, m) = await pump(tester, 'on');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(find.byType(MarkingBar), findsOneWidget);
      expect(s.markMethod, 'tap');
      expect(find.byTooltip('Tajwīd (2)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(s.markMethod, 'pen');
      expect(s.markPen, 'tajwid');
      expect(find.byTooltip('Note (5)'), findsOneWidget, reason: 'the pens, the note too');

      // A swatch's tap is a pen too.
      await tester.tap(find.byTooltip('Doubt (4)'));
      await tester.pump();
      expect(s.markPen, 'doubt');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('mobile: no pens, whatever\'s pressed', (tester) async {
      final (s, m) = await pump(tester, 'off');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Note (5)'), findsNothing);
      expect(find.byTooltip('Tajwīd'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(s.markMethod, 'tap');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  group('breath marks', () {
    const a = WordRef(2, 255, 3), c = WordRef(2, 255, 4);

    test('are no marks: not on the word\'s list, in review, the report, or the export',
        () async {
      final (m, b) = await store();
      m.breathTap(b, a, MarkType.breathStop);
      m.breathTap(b, c, MarkType.breathStart);
      expect(m.marksOf(b), isEmpty);
      expect(m.marksAt(b, a), isEmpty);
      expect(m.breathAt(b, a).single.type, MarkType.breathStop);
      expect(buildReviewQueue(m, b, const ReviewQuery(status: ReviewStatus.any)), isEmpty);
      final report = buildReport(m, b, const ReportOptions(), pageOf: (_) => 1, now: 0);
      expect(report.isEmpty, isTrue);
      expect(MarkType.marking, isNot(contains(MarkType.breathStop)));
      await m.flush();
    });

    test('draw on their words, with marks or without, and hide on their own', () async {
      final (m, b) = await store();
      m.breathTap(b, a, MarkType.breathStop);
      m.addMark(b, a, MarkType.mistake);
      m.breathTap(b, c, MarkType.breathStart);
      final all = m.visuals(b);
      expect(all[a.key]!.stop, isTrue);
      expect(all[a.key]!.open, MarkType.mistake);
      expect(all[a.key]!.count, 1, reason: 'one mark');
      expect(all[c.key]!.start, isTrue);
      expect(all[c.key]!.hasMark, isFalse, reason: 'no line under it');
      // Marks hidden: the plan for the breath stays.
      final plan = m.visuals(b, showMarks: false);
      expect(plan[a.key]!.open, isNull);
      expect(plan[a.key]!.stop, isTrue);
      expect(m.visuals(b, showBreath: false)[c.key], isNull);
      await m.flush();
    });

    test('a tap on a sign takes it off; undo puts it back', () async {
      final (m, b) = await store();
      final (add, none) = m.breathTap(b, a, MarkType.breathStop);
      expect(none, isNull);
      final (off, removed) = m.breathTap(b, a, MarkType.breathStart);
      expect(removed, MarkType.breathStop);
      expect(m.breathAt(b, a), isEmpty);
      m.undo(off);
      expect(m.breathAt(b, a).single.type, MarkType.breathStop);
      m.undo(add);
      expect(m.breathAt(b, a), isEmpty);
      await m.flush();
    });

    testWidgets('the tool\'s taps go by turns', (tester) async {
      final (m, b) = await store();
      final c0 = MarkingController();
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.load();
      late BuildContext ctx;
      await tester.pumpWidget(MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(builder: (x) {
              ctx = x;
              return const SizedBox();
            }),
          ),
        ),
      ));
      await c0.start(ctx, script: 'uthmani');
      expect(c0.breathNext, MarkType.breathStop);
      c0.applyBreath(ctx, a);
      expect(c0.breathNext, MarkType.breathStart);
      c0.applyBreath(ctx, c);
      expect(c0.breathNext, MarkType.breathStop);
      expect(m.breathAt(b, a).single.type, MarkType.breathStop);
      expect(m.breathAt(b, c).single.type, MarkType.breathStart);
      // Off again: that one's next once more.
      c0.applyBreath(ctx, c);
      expect(m.breathAt(b, c), isEmpty);
      expect(c0.breathNext, MarkType.breathStart);
      c0.undo(ctx);
      expect(m.breathAt(b, c).single.type, MarkType.breathStart);
      c0.redo(ctx);
      expect(m.breathAt(b, c), isEmpty);
      // They outlive a session with no marks.
      await c0.end(ctx);
      expect(m.breathAt(b, a), hasLength(1));
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  group('a comment\'s quick buttons', () {
    test('a word\'s letters: each place, without its ḥarakāt', () {
      final word = MushafRepo.wordText('uthmani', MushafRepo.globalAyahOf(1, 2), 1);
      expect(word, isNotEmpty);
      expect(wordLetters('بِسْمِ'), ['ب', 'س', 'م']);
      expect(wordLetters('ٱلْحَمْدُ'), ['ٱ', 'ل', 'ح', 'م', 'د']);
      expect(wordLetters('رَبِّ'), ['ر', 'ب'], reason: 'its shaddah a sign');
    });

    Future<Future<String?>> open(WidgetTester tester, {WordRef? word, MarkType? type}) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.load();
      s.mushafScript = 'uthmani';
      late BuildContext ctx;
      await tester.pumpWidget(SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (x) {
            ctx = x;
            return const Scaffold();
          }),
        ),
      ));
      final r = askText(ctx, title: 'Comment', comment: true, word: word, markType: type);
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('the word, its letters and the terms go in at the cursor', (tester) async {
      const ref = WordRef(1, 2, 2);
      final word = MushafRepo.wordText('uthmani', ref.globalAyah, ref.word0);
      final result = await open(tester, word: ref, type: MarkType.mistake);
      expect(tester.takeException(), isNull, reason: 'fits a phone\'s dialog');
      await tester.tap(find.text(word));
      await tester.pump();
      await tester.ensureVisible(find.text('kasrah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kasrah'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '$word kasrah');
      // In the middle too.
      field.controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.tap(find.text(wordLetters(word).first).first);
      await tester.pump();
      expect(field.controller!.text, startsWith(wordLetters(word).first));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await result, contains('kasrah'));
    });

    testWidgets('a tajwīd mark\'s comment starts with tajwīd\'s terms; a whole āyah has '
        'no word', (tester) async {
      await open(tester, word: const WordRef(1, 2, 0), type: MarkType.tajwid);
      final madd = tester.getTopLeft(find.text('madd')).dx;
      final wrong = find.text('wrong letter');
      if (wrong.evaluate().isNotEmpty) {
        expect(madd, lessThan(tester.getTopLeft(wrong).dx));
      }
      expect(find.text('fatḥah'), findsOneWidget);
    });
  });
}
