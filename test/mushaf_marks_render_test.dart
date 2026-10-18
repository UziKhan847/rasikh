import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';

import 'test_support.dart';

/// A mark is stored once, by (sūrah, āyah, word), and must be drawn on the
/// same word whichever script the muṣḥaf is in.
// The mistake tint behind the word (the pattern line is painted separately).
final _mistakeTint = const Color(0xFFC8402F).withValues(alpha: .16);
const _ref = WordRef(2, 255, 3); // ٱلْحَىُّ in Āyat al-Kursī

Future<(AppSettings, ProgressStore, MarksStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.desktopMode = 'off';
  final m = MarksStore(
      persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
  await m.load();
  return (s, p, m);
}

Future<void> _pump(WidgetTester tester, AppSettings s, ProgressStore p,
    MarksStore m, String script) async {
  final page = MushafRepo.pageOfWord(script, _ref.globalAyah, _ref.word0);
  await tester.pumpWidget(
    MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MushafPageScreen(
                key: ValueKey(script), startPage: page, script: script),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every word span on screen.
List<TextSpan> _wordSpans(WidgetTester tester) {
  final out = <TextSpan>[];
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    rt.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) out.add(span);
      return true;
    });
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    await MushafRepo.ensure('indopak');
    // The reader decodes off-isolate; warm its caches outside fake async.
    for (final f in ['DigitalKhattV2', 'UthmanicHafs']) {
      await QuranRepo.ayahs(15, 'uthmani', font: f);
      await QuranRepo.words(15, 'uthmani', font: f);
    }
  });

  for (final script in ['uthmani', 'indopak']) {
    testWidgets('a mark is drawn on the same word in $script', (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (s, p, m) = await _boot();
      final b = m.ensureActiveBook('Test');
      m.addMark(b.id, _ref, MarkType.mistake);

      await _pump(tester, s, p, m, script);
      final marked = _wordSpans(tester)
          .where((t) => t.style?.backgroundColor == _mistakeTint)
          .toList();
      expect(marked, hasLength(1));
      expect(marked.single.text,
          MushafRepo.wordText(script, _ref.globalAyah, _ref.word0));
      // No text decoration: it would cut through the kasrahs.
      expect(marked.single.style!.decoration, isNull);

      // Hidden with "show marks" off.
      s.update(() => s.showMarks = false);
      await tester.pump(const Duration(milliseconds: 300)); // + save debounce
      expect(
          _wordSpans(tester)
              .where((t) => t.style?.backgroundColor == _mistakeTint),
          isEmpty);
      await m.flush();
    });
  }

  testWidgets('marking mode: tap marks a word, undo takes it off',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    await _pump(tester, s, p, m, 'uthmani');

    await tester.tap(find.byTooltip('Mark recitation'));
    await tester.pumpAndSettle();
    // First time: no book yet → "New mark book" is preselected.
    await tester.enterText(find.byType(TextField).first, 'Zayd');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(m.activeBook!.name, 'Zayd');
    expect(find.byTooltip('Undo'), findsOneWidget);

    final word = MushafRepo.wordText('uthmani', _ref.globalAyah, _ref.word0);
    final span = _wordSpans(tester).firstWhere((t) => t.text == word);
    (span.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    final marks = m.marksAt(m.activeBookId!, _ref);
    expect(marks, hasLength(1));
    expect(marks.single.type, MarkType.mistake);
    expect(marks.single.sessionId, m.openSession(m.activeBookId!)!.id);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(m.marksAt(m.activeBookId!, _ref), isEmpty);

    // End → summary → Save closes the session with the page's range.
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final session = m.sessionsOf(m.activeBookId!).single;
    expect(session.isOpen, isFalse);
    expect(session.fromGlobalAyah, lessThanOrEqualTo(_ref.globalAyah));
    expect(session.toGlobalAyah, greaterThanOrEqualTo(_ref.globalAyah));
    await m.flush();
  });

  testWidgets('card reader: a muṣḥaf word mark tints the card word covering it',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    final b = m.ensureActiveBook('Test');
    // 15:7 — the muṣḥaf prints لَّوْ | مَا, the card text لَّوۡمَا as one word.
    m.addMark(b.id, const WordRef(15, 7, 2), MarkType.doubt);
    final meta = (await QuranRepo.meta())[14];
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
            home: SurahReaderScreen(meta: meta, startAyah: 7),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final doubtTint = const Color(0xFF7A4FD0).withValues(alpha: .16);
    // Walk every span — visitChildren skips spans without text of their own,
    // and the tint sits on a parent span around the word's (tajwīd) pieces.
    final tinted = <String>[];
    void walk(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.style?.backgroundColor == doubtTint) {
        tinted.add(span.toPlainText());
      }
      for (final c in span.children ?? const <InlineSpan>[]) {
        walk(c);
      }
    }

    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      walk(rt.text);
    }
    expect(tinted, hasLength(1));
    // The reader's own first word of 15:7 (لَّوۡمَا).
    final card = await QuranRepo.words(15, 'uthmani', font: 'DigitalKhattV2');
    expect(tinted.single, card[6][0]);
    await m.flush();
  });
}
