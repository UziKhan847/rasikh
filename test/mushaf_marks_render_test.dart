import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/reader/ayah_text.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';
import 'package:qiraah_arabiyyah/ui/mark_style.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// A mark is stored once, by (sūrah, āyah, word), and must be drawn on the
/// same word whichever script the muṣḥaf is in.
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

/// A word as drawn: its text, the highlight behind it (if any), whether it
/// carries a text decoration, the line it's on and its index.
typedef _Word = (String text, Color? bg, bool decorated, RenderMushafLine, int);

/// Every word on screen — from the glyph atlas line or the text line,
/// whichever drew it.
List<_Word> _words(WidgetTester tester) {
  final out = <_Word>[];
  for (final el in find.byType(MushafLineView).evaluate()) {
    final r = el.renderObject! as RenderMushafLine;
    final laid = r.laidLine;
    if (laid == null) continue;
    // Only lines on screen (the pager keeps its neighbours laid out too).
    final at = r.localToGlobal(r.size.center(Offset.zero));
    if (!(Offset.zero & tester.view.physicalSize).contains(at)) continue;
    final words = r.spec.line.words;
    if (laid is AtlasLine) {
      for (var i = 0; i < words.length; i++) {
        final (left, right) = laid.boxes[i];
        Color? bg;
        for (final (l, rr, c) in laid.backgrounds) {
          if (l == left && rr == right) bg = c;
        }
        out.add((words[i].text, bg, false, r, i));
      }
    } else if (laid is LaidLine) {
      final spans = (laid.painter.text! as TextSpan).children!;
      // Words and the gaps between them alternate.
      for (var i = 0; i < words.length; i++) {
        final t = spans[i * 2] as TextSpan;
        out.add((
          t.text!,
          t.style?.backgroundColor,
          t.style?.decoration != null,
          r,
          i,
        ));
      }
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    // Real glyph widths: the page is sized from the bundled fonts' widths.
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
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
      // In the paper's mark colours (greys on Indo-Pak's Mono paper).
      final tint = markPaletteForPaper(mushafPaperOf(s, script))
          .tintOf(MarkType.mistake);
      final marked = _words(tester).where((w) => w.$2 == tint).toList();
      expect(marked, hasLength(1));
      expect(marked.single.$1,
          MushafRepo.wordText(script, _ref.globalAyah, _ref.word0));
      // No text decoration: it would cut through the kasrahs.
      expect(marked.single.$3, isFalse);

      // Hidden with "show marks" off.
      s.update(() => s.showMarks = false);
      await tester.pump(const Duration(milliseconds: 300)); // + save debounce
      expect(_words(tester).where((w) => w.$2 == tint), isEmpty);
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
    final (_, _, _, line, i) = _words(tester).firstWhere((w) => w.$1 == word);
    final (left, right) = line.laidLine!.boxes[i];
    final pos = line.localToGlobal(
        line.textOffset + Offset((left + right) / 2, line.laidLine!.height / 2));
    await tester.tapAt(pos);
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

  /// Where to touch [ref]'s word on screen.
  Offset wordCentre(WidgetTester tester, WordRef ref) {
    final word = MushafRepo.wordText('uthmani', ref.globalAyah, ref.word0);
    final (_, _, _, line, i) = _words(tester).firstWhere((w) => w.$1 == word);
    final (left, right) = line.laidLine!.boxes[i];
    return line.localToGlobal(
        line.textOffset + Offset((left + right) / 2, line.laidLine!.height / 2));
  }

  testWidgets('marking: each tap steps the mark; holding opens its actions',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    await _pump(tester, s, p, m, 'uthmani');
    await tester.tap(find.byTooltip('Mark recitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Zayd');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    final at = wordCentre(tester, _ref);
    List<MarkType> types() =>
        [for (final x in m.marksAt(m.activeBookId!, _ref)) x.type];
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
    expect(types(), [MarkType.mistake]);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
    expect(types(), [MarkType.tajwid]);
    expect(find.textContaining('Tajw'), findsWidgets); // the bar says so

    // Holding opens the sheet with the mark's actions as buttons.
    await tester.longPressAt(at);
    await tester.pumpAndSettle();
    for (final label in ['Comment', 'Reply', 'Delete']) {
      expect(find.widgetWithText(TextButton, label), findsOneWidget,
          reason: label);
    }
    await tester.tap(find.widgetWithText(TextButton, 'Mark fixed'));
    await tester.pump();
    expect(m.isFixed(m.marksAt(m.activeBookId!, _ref).single), isTrue);
    await m.flush();
  });

  testWidgets('the held word\'s sheet steps to the words either side',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    m.ensureActiveBook('Me');
    await _pump(tester, s, p, m, 'uthmani');
    await tester.longPressAt(wordCentre(tester, _ref));
    await tester.pumpAndSettle();
    expect(find.textContaining('2:255  ·  word 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next word'));
    await tester.pump();
    expect(find.textContaining('2:255  ·  word 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous word'));
    await tester.pump();
    await tester.tap(find.byTooltip('Previous word'));
    await tester.pump();
    expect(find.textContaining('2:255  ·  word 2'), findsOneWidget);
    await m.flush();
  });

    testWidgets('mutashābih: the pen starts link mode; taps link; Done needs '
      'one; cancel with none drops it', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    final b = m.ensureActiveBook('Me').id;
    await _pump(tester, s, p, m, 'uthmani');

    Future<void> pickPen(Offset at) async {
      await tester.longPressAt(at);
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(ActionChip, 'Mutashābih');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await pickPen(wordCentre(tester, _ref));
    expect(find.textContaining('Tap the passages'), findsOneWidget);
    final mark = m.mutashabihatOf(b).single;
    FilledButton done() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Done (0)').evaluate().isEmpty
            ? find.widgetWithText(FilledButton, 'Done (1)')
            : find.widgetWithText(FilledButton, 'Done (0)'));
    expect(done().onPressed, isNull, reason: 'nothing linked yet');

    // Another word on the page: linked.
    final other = WordRef(_ref.surah, _ref.ayah, _ref.word + 2);
    await tester.tapAt(wordCentre(tester, other));
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.linksOf(mark), hasLength(1));
    expect(done().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Done (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap the passages'), findsNothing);
    expect(m.linksOf(mark), hasLength(1));

    // A second one, cancelled with nothing linked, is gone.
    await pickPen(wordCentre(tester, WordRef(_ref.surah, _ref.ayah, 1)));
    expect(m.mutashabihatOf(b), hasLength(2));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(m.mutashabihatOf(b), hasLength(1));
    await m.flush();
  });

  testWidgets('reading: a tap plays the word; holding also opens its sheet',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m) = await _boot();
    await _pump(tester, s, p, m, 'uthmani');
    bool playing() => tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .any((r) => r.spec.playAyah == _ref.globalAyah);

    final at = wordCentre(tester, _ref);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
    expect(playing(), isTrue, reason: 'the tap played the word');
    expect(find.byType(BottomSheet), findsNothing);

    await tester.longPressAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(playing(), isTrue);
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
    // The card paints its marks around its paragraph (see AyahText): the
    // one marked word is the doubt.
    final tinted = <String>[];
    for (final a in tester.widgetList<AyahText>(find.byType(AyahText))) {
      for (var w = 0; w < a.marks.length; w++) {
        if (a.marks[w]?.open == MarkType.doubt) {
          tinted.add(a.words[w].toPlainText());
        }
      }
    }
    expect(tinted, hasLength(1));
    // The reader's own first word of 15:7 (لَّوۡمَا).
    final card = await QuranRepo.words(15, 'uthmani', font: 'DigitalKhattV2');
    expect(tinted.single, card[6][0]);
    await m.flush();
  });
}
