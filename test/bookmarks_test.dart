import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/bookmarks.dart';
import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/profiles.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_index_sheet.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/reader/reader_host.dart' show ReaderViewSwitch;

import 'test_support.dart';

/// Bookmarks of āyāt, pages and sūrahs, and the two small toggles above the
/// page: the page's bookmark, and switching profile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  group('the store', () {
    test('all three kinds persist; a page goes by its first verse', () async {
      SharedPreferences.setMockInitialValues({});
      final p = ProgressStore();
      await p.load();
      p.toggleBookmark(36, 58);
      p.togglePageBookmark('uthmani', 42);
      p.toggleSurahBookmark(18);
      expect(p.isPageBookmarked('uthmani', 42), isTrue);
      expect(p.isPageBookmarked('uthmani', 43), isFalse);
      expect(p.isSurahBookmarked(18), isTrue);
      await Future<void>.delayed(Duration.zero);

      final again = ProgressStore();
      await again.load();
      expect(again.bookmarkItems.map((b) => b.kind),
          [BookmarkKind.surah, BookmarkKind.page, BookmarkKind.verse],
          reason: 'newest first');
      expect(again.bookmarks, [(36, 58)]);
      expect(again.isPageBookmarked('uthmani', 42), isTrue);
      final b = again.bookmarkItems[1];
      expect((b.surah, b.ayah), MushafRepo.firstVerseOfPage('uthmani', 42));
      again.togglePageBookmark('uthmani', 42);
      expect(again.isPageBookmarked('uthmani', 42), isFalse);
    });

    test('bookmarks saved before pages could be still load', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProgressStore();
      await first.load();
      first.toggleBookmark(2, 255);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().firstWhere((k) => (prefs.getString(k) ?? '').contains('bookmarks'));
      final old = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>
        ..remove('bookmarks')
        ..['marks'] = [
          [2, 255],
          [1, 5],
        ];
      await prefs.setString(key, jsonEncode(old));
      final again = ProgressStore();
      await again.load();
      expect(again.bookmarks, [(2, 255), (1, 5)]);
    });

    test('a page bookmark is the same place in another muṣḥaf', () {
      const b = Bookmark(BookmarkKind.page, 2, 255);
      expect(pageOfBookmark('uthmani', b),
          MushafRepo.pageForGlobalAyah('uthmani', MushafRepo.globalAyahOf(2, 255)));
      expect(pageOfBookmark('uthmani', const Bookmark(BookmarkKind.surah, 18, 1)),
          MushafRepo.surahPageSync('uthmani', 18));
    });
  });

  Future<(AppSettings, ProgressStore, ProfileStore, MarksStore)> pump(WidgetTester tester,
      {Size size = const Size(420, 900), double top = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: top);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..toolHintSeen = true
      ..immersive = top > 0
      ..desktopMode = 'off';
    final disks = <String, MarksPersistence>{};
    final profiles =
        ProfileStore(persistenceFor: (d) => disks.putIfAbsent(d, MemoryMarksPersistence.new));
    await profiles.load(s);
    await profiles.add('Zayd');
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    await tester.pumpWidget(ProfileScope(
      profiles: profiles,
      child: MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: FluencyScope(
              store: FluencyStore(),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
              ),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
    return (s, p, profiles, m);
  }

  const chip = ValueKey('profile-chip');

  testWidgets('the line above the page: sūrah, its profile toggle, the bookmark, the page '
      'number in the middle', (tester) async {
    final (_, p, _, m) = await pump(tester);
    final number = tester.getCenter(find.text('50').first);
    expect(number.dx, closeTo(210, 2), reason: 'still the middle');
    final meta = (await tester.runAsync(QuranRepo.meta))!;
    final surah = MushafRepo.firstVerseOfPage('uthmani', 50).$1;
    final name = tester.getRect(find.text(meta[surah - 1].tname).first);
    expect(find.text(meta[surah - 1].tname).first, findsOneWidget);
    expect(name.width, greaterThan(70), reason: 'the name whole, not cut short');
    final profile = tester.getRect(find.byKey(chip));
    final mark = tester.getRect(find.byKey(const ValueKey('page-bookmark-50')).first);
    expect(profile.left, greaterThanOrEqualTo(name.right - 1), reason: 'right of the sūrah');
    expect(mark.right, lessThanOrEqualTo(number.dx), reason: 'left of the number');
    expect(mark.left, greaterThanOrEqualTo(profile.right - 1));
    expect(mark.height, lessThan(30), reason: 'small');

    await tester.tap(find.byKey(const ValueKey('page-bookmark-50')).first);
    await tester.pump();
    expect(p.isPageBookmarked('uthmani', 50), isTrue);
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('immersive: the toggles go up into the band; the line stays', (tester) async {
    final (_, _, _, m) = await pump(tester, top: 40);
    final y = tester.getCenter(find.byKey(chip)).dy;
    expect(y, lessThan(40), reason: 'in the band');
    final mark = find.byKey(const ValueKey('page-bookmark-50'));
    expect(mark, findsOneWidget, reason: 'there, not also in the line');
    expect(tester.getCenter(mark).dy, lessThan(40));
    expect(tester.getCenter(find.text('50').first).dy, greaterThan(40), reason: 'the line stays');
    await m.flush();
  });

  testWidgets('side by side: the profile toggle under the view switch, by the dock, '
      'not on a page\'s rail', (tester) async {
    final (s, _, _, m) = await pump(tester, size: const Size(2000, 1170));
    s.update(() => s.desktopMode = 'on');
    await settle(tester);
    final profile = find.byKey(chip);
    expect(profile, findsOneWidget, reason: 'once, not also on a rail');
    final sw = tester.getRect(find.byType(ReaderViewSwitch).first);
    final at = tester.getRect(profile);
    expect(at.top, greaterThanOrEqualTo(sw.bottom), reason: 'under the switch');
    expect(at.top - sw.bottom, lessThan(20), reason: 'just under it');
    expect(at.center.dx, closeTo(sw.center.dx, 2), reason: 'lined up with it');
    // And the bookmarks under it: a tap opens them, in the index.
    final bm = tester.getRect(find.byKey(const ValueKey('bookmarks-chip')));
    expect(bm.top, greaterThanOrEqualTo(at.bottom));
    expect(bm.center.dx, closeTo(at.center.dx, 3));
    await tester.tap(find.byKey(const ValueKey('bookmarks-chip')));
    await tester.pumpAndSettle();
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.controller!.index, tabs.tabs.length - 1, reason: 'on the Bookmarks tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('two clicks: the toggle, then the name', (tester) async {
    final (_, _, profiles, m) = await pump(tester);
    final before = profiles.active.id;
    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();
    expect(find.text('Manage profiles…'), findsOneWidget);
    await tester.tap(find.text('Zayd'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(profiles.active.id, isNot(before));
    expect(profiles.active.name, 'Zayd');
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('the index: a sūrah\'s bookmark, and all three in its tab, each going there',
      (tester) async {
    final (_, p, _, m) = await pump(tester);
    p.toggleBookmark(2, 255);
    p.togglePageBookmark('uthmani', 100);
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('surah-bookmark-2')));
    await tester.pump();
    expect(p.isSurahBookmarked(2), isTrue);
    final tabs = find.descendant(of: find.byType(MushafIndex), matching: find.byType(TabBar));
    await tester.dragUntilVisible(find.text('Bookmarks'), tabs, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Al-Baqarah 2:255'), findsOneWidget);
    expect(find.text('Page 100'), findsOneWidget);
    await tester.tap(find.text('Page 100'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.byType(MushafIndex), findsNothing);
    expect(find.byKey(const ValueKey('page-bookmark-100')), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('B bookmarks the page', (tester) async {
    final (_, p, _, m) = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(p.isPageBookmarked('uthmani', 50), isTrue);
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });
}
