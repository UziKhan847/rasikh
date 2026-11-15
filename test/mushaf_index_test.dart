import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_index.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/divisions.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_index_sheet.dart';

import 'test_support.dart';

/// The muṣḥaf index: tabs per division, each entry with its marks counted
/// by type; a count goes to the first such mark.
const _kursi = WordRef(2, 255, 3); // juzʼ 3, ḥizb 5
const _kursi2 = WordRef(2, 255, 1);
const _fatiha = WordRef(1, 2, 2); // juzʼ 1

Future<(AppSettings, MarksStore, String)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  await s.load();
  s.onboarded = true;
  final m = MarksStore(
      persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
  await m.load();
  final b = m.ensureActiveBook('Me').id;
  m.addMark(b, _kursi, MarkType.mistake);
  m.addMark(b, _kursi2, MarkType.mistake);
  m.addMark(b, _kursi, MarkType.doubt);
  m.addMark(b, _fatiha, MarkType.tajwid);
  m.fix(b, _fatiha);
  return (s, m, b);
}

int _page(String script, WordRef r) =>
    MushafRepo.pageOfWord(script, r.globalAyah, r.word0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  test('marks are counted into every division, open by type and fixed',
      () async {
    final (_, m, b) = await _boot();
    final c = MarkCounts.forBook(m, b, 'uthmani', (r) => _page('uthmani', r));
    final juz3 = c.of(Division.juz, 3);
    expect(juz3.openOf(MarkType.mistake), 2);
    expect(juz3.openOf(MarkType.doubt), 1);
    expect(juz3.fixed, 0);
    final juz1 = c.of(Division.juz, 1);
    expect(juz1.openTotal, 0);
    expect(juz1.fixed, 1);
    expect(c.of(Division.hizb, hizbOf(2, 255)).openTotal, 3);
    expect(c.of(Division.page, _page('uthmani', _kursi)).openTotal, 3);
    expect(c.of(Division.surah, 2).openTotal, 3);
    expect(c.of(Division.manzil, 1).openTotal, 3);
    expect(c.of(Division.ruku, rukuOf(2, 255)).openTotal, 3);
    expect(c.marked(Division.juz), [1, 3]);
    expect(c.of(Division.juz, 30).isEmpty, isTrue);
    // Memoised until the marks change.
    expect(MarkCounts.forBook(m, b, 'uthmani', (r) => 0), same(c));
    m.addMark(b, _fatiha, MarkType.note);
    expect(MarkCounts.forBook(m, b, 'uthmani', (r) => _page('uthmani', r))
        .of(Division.juz, 1)
        .openOf(MarkType.note), 1);
  });

  Future<void> pumpIndex(WidgetTester tester, AppSettings s, MarksStore m,
      String script,
      {ValueChanged<int>? onPage, ValueChanged<WordRef>? onWord}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: MushafIndex(
              script: script,
              currentPage: 1,
              initial: Division.juz,
              onPage: onPage ?? (_) {},
              onWord: onWord ?? (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('tabs, count pills, and where a tap goes', (tester) async {
    final (s, m, _) = await _boot();
    int? page;
    WordRef? word;
    await pumpIndex(tester, s, m, 'uthmani',
        onPage: (p) => page = p, onWord: (w) => word = w);

    for (final t in ['Page', 'Sūrah', 'Juzʼ', 'Ḥizb', 'Rubʿ', 'Manzil']) {
      expect(find.widgetWithText(Tab, t), findsOneWidget);
    }
    expect(find.widgetWithText(Tab, 'Rukūʿ'), findsNothing); // Indo-Pak only

    // Juzʼ 3 holds two mistakes and a doubt.
    final juz3 = find.ancestor(
        of: find.text('Juzʼ 3'), matching: find.byType(Row)).first;
    expect(find.descendant(of: juz3, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: juz3, matching: find.text('1')), findsOneWidget);

    // The mistake pill goes to the first mistake in the juzʼ (muṣḥaf order).
    await tester.tap(find.descendant(of: juz3, matching: find.text('2')));
    expect(word, _kursi2);

    // The entry itself goes to the juzʼ's first page.
    await tester.tap(find.text('Juzʼ 3'));
    expect(page, MushafRepo.pageForGlobalAyah(
        'uthmani', MushafRepo.globalAyahOf(2, 253)));
    await tester.pump(const Duration(seconds: 2)); // the tooltip's timers
  });

  testWidgets('holding the Pages tab: a list with each page\'s marks, kept', (tester) async {
    final (s, m, _) = await _boot();
    int? page;
    await pumpIndex(tester, s, m, 'uthmani', onPage: (p) => page = p);
    await tester.longPress(find.byKey(const ValueKey('pages-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List, with marks'));
    await tester.pumpAndSettle();
    expect(s.indexPagesList, isTrue, reason: 'kept');

    final kursi = _page('uthmani', _kursi);
    final row = find.text('Page $kursi');
    await tester.scrollUntilVisible(row, 300,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    final r = find.ancestor(of: row, matching: find.byType(Row)).first;
    // Two mistakes and a doubt on the page.
    expect(find.descendant(of: r, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: r, matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: r, matching: find.textContaining('2:')), findsOneWidget,
        reason: 'where the page starts');
    await tester.tap(row);
    expect(page, kursi);

    // And back to the grid.
    await tester.longPress(find.byKey(const ValueKey('pages-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(s.indexPagesList, isFalse);
    expect(find.text('Page $kursi'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Indo-Pak adds the rukūʿ tab, pages in its own numbering',
      (tester) async {
    final (s, m, _) = await _boot();
    await pumpIndex(tester, s, m, 'indopak');
    expect(find.widgetWithText(Tab, 'Rukūʿ'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Page'));
    await tester.pumpAndSettle();
    expect(find.text('${MushafRepo.pageCountSync('indopak')}'), findsNothing,
        reason: 'the grid is lazy');
    expect(find.text('1'), findsWidgets);
  });
}
