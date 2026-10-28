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
import 'package:qiraah_arabiyyah/data/mushaf_search.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/marks/word_marks_sheet.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/memorize_bar.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_index_sheet.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/words_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/ui/adaptive_sheet.dart';

import 'test_support.dart';

/// The Hifẓ home (Mode 1): its toolbar, each word tool, memorize all on
/// buttons, the View popover, and searching the text.
const _ref = WordRef(44, 25, 2); // a word on page 497 (ad-Dukhān)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<(AppSettings, ProgressStore, MarksStore)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..appMode = 'hifz'
      ..desktopMode = 'off';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (s, p, m);
  }

  Future<void> pump(WidgetTester tester, AppSettings s, ProgressStore p, MarksStore m) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = MushafRepo.pageOfWord('uthmani', _ref.globalAyah, _ref.word0);
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
            home: MushafPageScreen(home: true, startPage: page, script: 'uthmani'),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Where to touch [ref]'s word.
  Offset wordAt(WidgetTester tester, WordRef ref) {
    for (final el in find.byType(MushafLineView).evaluate()) {
      final r = el.renderObject! as RenderMushafLine;
      final laid = r.laidLine;
      if (laid == null) continue;
      final words = r.spec.line.words;
      for (var i = 0; i < words.length; i++) {
        final w = words[i];
        if (w.ayah == ref.globalAyah && w.wordIdx == ref.word0) {
          final (left, right) = laid.boxes[i];
          return r.localToGlobal(r.textOffset + Offset((left + right) / 2, laid.height / 2));
        }
      }
    }
    throw StateError('word not on screen');
  }

  testWidgets('the toolbar: settings · index · pen · comment · eraser · audio · '
      'memorize · view; the header names sūrah, page, juzʼ', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    for (final t in ['Settings', 'Index', 'Mark recitation', 'Comment', 'Eraser',
        'Recitation', 'Memorize', 'View']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('25'), findsWidgets);
    expect(find.text('Ad-Dukhan'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'the home has nothing to close');
  });

  testWidgets('comment: a tap opens the word\'s bubble', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Comment'));
    await tester.pump();
    expect(find.text('Tap a word for its comments'), findsOneWidget);
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pumpAndSettle();
    expect(find.byType(WordMarksPanel), findsOneWidget);
  });

  testWidgets('eraser: a tap wipes the word\'s marks; Undo brings them back',
      (tester) async {
    final (s, p, m) = await boot();
    final b = m.ensureActiveBook('Me');
    m.addMark(b.id, _ref, MarkType.mistake);
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pump();
    expect(m.marksAt(b.id, _ref), isEmpty);
    await tester.pump(const Duration(milliseconds: 600)); // the snackbar in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(m.marksAt(b.id, _ref), hasLength(1));
    await m.flush();
  });

  testWidgets('audio: a tap plays the word', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Recitation'));
    await tester.pump();
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pump();
    final playing = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .any((r) => r.spec.playAyah == _ref.globalAyah && r.spec.playWord == _ref.word0);
    expect(playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30)); // the word audio's timeout
  });

  testWidgets('memorize: the page hides; its bar, and no thumb pad even when set',
      (tester) async {
    final (s, p, m) = await boot();
    s.memorizeTap = 'pad';
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Memorize'));
    await tester.pump();
    expect(find.byType(MemorizeBar), findsOneWidget);
    expect(find.byType(MemorizePad), findsNothing);
    final hidden = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .any((r) => r.spec.hideFrom >= 0);
    expect(hidden, isTrue);
  });

  testWidgets('view: script, colouring (Nabr not yet), brightness', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    // At the end of the dock's scroll.
    await tester.ensureVisible(find.byTooltip('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    expect(find.text('Colouring'), findsOneWidget);
    await tester.tap(find.text('Tajwīd').last);
    await tester.pump();
    expect(s.mushafTajwid, isTrue);
    await tester.tap(find.text('OLED'));
    await tester.pump();
    expect(s.appTheme, 'oled');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('the header\'s page opens its list there; a pick goes to it',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    final page = MushafRepo.pageOfWord('uthmani', _ref.globalAyah, _ref.word0);
    await tester.tap(find.text('$page').first);
    await tester.pumpAndSettle();
    expect(find.text('Page $page'), findsOneWidget, reason: 'opened on the current page');
    await tester.tap(find.text('Page ${page + 2}'));
    await tester.pumpAndSettle();
    expect(find.text('${page + 2}'), findsWidgets);
  });

  testWidgets('landscape: the index comes in from the side', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<AdaptiveSheet>(find.byType(AdaptiveSheet));
    expect(sheet.side, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the index searches by mark; a pick goes to the word once the '
      'sheet has gone', (tester) async {
    final (s, p, m) = await boot();
    final b = m.ensureActiveBook('Me');
    m.addMark(b.id, _ref, MarkType.mistake);
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Mistake'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mistake · Ad-Dukhan 44:25'), findsOneWidget);
    expect(find.byType(WordsLine), findsOneWidget);
    await tester.tap(find.textContaining('Mistake · Ad-Dukhan 44:25'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsNothing);
    await m.flush();
  });

  test('search: by letters, whatever the vowels', () {
    final hits = searchMushaf('uthmani', 'الرحمن الرحيم');
    expect(hits.first.surah, 1);
    expect(hits.any((h) => h.surah == 1 && h.ayahInSurah == 3), isTrue);
    expect(searchMushaf('uthmani', 'قُلْ هُوَ اللَّهُ أَحَدٌ').single.surah, 112);
    expect(bareArabic('ٱلْحَمْدُ'), 'الحمد');
    // The words a match covers.
    final h = searchMushaf('uthmani', 'ملك يوم').firstWhere((h) => h.surah == 1);
    expect((h.firstWord, h.lastWord), (0, 1));
  });
}
