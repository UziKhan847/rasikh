import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/memorize.dart';
import 'package:qiraah_arabiyyah/ui/mark_style.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/memorize_cards_screen.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/verse_view.dart';
import 'package:qiraah_arabiyyah/core/recite_back.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/mushaf_atlas.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/memorize_bar.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// Memorize mode draws hidden words as nothing at all — on the glyph-atlas
/// path their sprites are left out of the drawRawAtlas lists (on the text
/// fallback they're transparent) — with every box where it was; a reveal
/// rebuilds one line; and the page turns only once the page (or both pages
/// of a spread) is done.
MushafLineSpec _spec(MushafLine line, {int hideFrom = -1}) => MushafLineSpec(
      script: 'uthmani',
      page: 2,
      index: 3,
      line: line,
      fontSize: 22,
      slotH: 40,
      targetW: 380,
      ink: const Color(0xFF000000),
      accent: const Color(0xFF00AA00),
      strongBg: const Color(0x3300AA00),
      verseBg: const Color(0x1100AA00),
      hideFrom: hideFrom,
    );

int _sprites(AtlasLine l) =>
    l.batches.fold(0, (n, b) => n + b.$4.length); // one colour per sprite

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  MushafLine textLine() =>
      MushafRepo.pageSync('uthmani', 2)!.firstWhere((l) => l.isText);

  test('atlas: hidden words get no sprites; boxes are unchanged', () {
    final atlas = MushafAtlas.of('uthmani')!;
    final line = textLine();
    final n = line.words.length;
    final all = buildAtlasLine(_spec(line), atlas, 0);
    final half = buildAtlasLine(
        _spec(line, hideFrom: line.firstTok + n ~/ 2), atlas, 0);
    final none = buildAtlasLine(_spec(line, hideFrom: line.firstTok), atlas, 0);

    expect(half.boxes, all.boxes, reason: 'nothing moves');
    expect(none.boxes, all.boxes);
    expect(half.width, all.width);
    expect(_sprites(none), 0, reason: 'a hidden line draws nothing');
    expect(_sprites(half), greaterThan(0));
    expect(_sprites(half), lessThan(_sprites(all)));
    for (var i = n ~/ 2; i < n; i++) {
      expect(half.tokenColors[i].a, 0);
    }
  });

  test('text fallback: hidden words are transparent', () {
    final line = textLine();
    final n = line.words.length;
    final laid =
        MushafLineCache.get(_spec(line, hideFrom: line.firstTok + n ~/ 2));
    final spans = (laid.painter.text! as TextSpan).children!;
    for (var i = 0; i < n; i++) {
      final c = (spans[i * 2] as TextSpan).style?.color;
      if (i < n ~/ 2) {
        expect(c?.a ?? 1, isNot(0));
      } else {
        expect(c!.a, 0);
      }
    }
  });

  test('only the line with the cursor changes its key', () {
    final line = textLine();
    final n = line.words.length;
    final plain = _spec(line).key;
    expect(_spec(line, hideFrom: line.firstTok + n).key, plain,
        reason: 'a cut after the line leaves it as it was');
    expect(_spec(line, hideFrom: line.firstTok + 1).key, isNot(plain));
    expect(_spec(line, hideFrom: line.firstTok + 1).key,
        isNot(_spec(line, hideFrom: line.firstTok + 2).key));
    // Wholly hidden lines share one look however far the cursor is.
    expect(_spec(line, hideFrom: 0).key, _spec(line, hideFrom: line.firstTok).key);
  });

  Future<(AppSettings, ProgressStore)> boot({bool desktop = false}) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.desktopMode = desktop ? 'on' : 'off';
    if (desktop) s.mushafView = 'spread';
    return (s, p);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Widget app(AppSettings s, ProgressStore p, int page) => SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MushafPageScreen(startPage: page, script: 'uthmani'),
          ),
        ),
      );

  List<RenderMushafLine> onScreen(WidgetTester tester) => [
        for (final el in find.byType(MushafLineView).evaluate())
          if ((el.renderObject! as RenderMushafLine).laidLine != null &&
              (Offset.zero & tester.view.physicalSize).contains(
                  (el.renderObject! as RenderMushafLine)
                      .localToGlobal(Offset.zero)))
            el.renderObject! as RenderMushafLine,
      ];

  Future<void> startMemorize(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Muṣḥaf settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Memorize from this page'));
    await tester.pumpAndSettle();
    await settle(tester);
  }

  testWidgets('phone: the page goes blank; a tap reveals one word, one line',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    await tester.pumpWidget(app(s, p, 50));
    await settle(tester);
    await startMemorize(tester);
    expect(find.byType(MemorizeBar), findsOneWidget);

    var lines = onScreen(tester);
    expect(lines, isNotEmpty);
    for (final r in lines) {
      final l = r.laidLine!;
      expect(l, isA<AtlasLine>());
      expect(_sprites(l as AtlasLine), 0, reason: 'everything hidden');
    }

    final before = {for (final r in lines) r.spec.index: r.spec.key};
    await tester.tap(find.text('Next word'));
    await settle(tester);
    lines = onScreen(tester);
    final changed = [
      for (final r in lines)
        if (before[r.spec.index] != r.spec.key) r.spec.index
    ];
    expect(changed, hasLength(1), reason: 'only the line with the word');
    final shown = lines.where((r) => _sprites(r.laidLine! as AtlasLine) > 0);
    expect(shown, hasLength(1));

    int revealed() => onScreen(tester)
        .fold<int>(0, (n, x) => n + _sprites(x.laidLine! as AtlasLine));
    final r = shown.first;
    final firstLen = revealed();

    // By default a tap on a revealed word plays it and reveals nothing; a
    // tap on the page does nothing.
    final w = r.spec.line.words.indexWhere((x) => !r.spec.isHidden(
        r.spec.line.words.indexOf(x)));
    final (left, right) = r.laidLine!.boxes[w];
    await tester.tapAt(r.localToGlobal(
        r.textOffset + Offset((left + right) / 2, r.laidLine!.height / 2)));
    await settle(tester);
    expect(revealed(), firstLen);
    expect(onScreen(tester).any((x) =>
            x.spec.playAyah == r.spec.line.words[w].ayah &&
            x.spec.playWord == r.spec.line.words[w].wordIdx),
        isTrue, reason: 'the tapped word plays');
    await tester.tapAt(r.localToGlobal(Offset(r.size.width / 2, -6)));
    await settle(tester);
    expect(revealed(), firstLen);

    // With "tap to reveal" on, a tap on the page reveals the next word.
    s.update(() => s.memorizeTap = 'word');
    await settle(tester);
    await tester.tapAt(r.localToGlobal(Offset(r.size.width / 2, -6)));
    await settle(tester);
    expect(revealed(), greaterThan(firstLen));

    await tester.tap(find.text('End'));
    await settle(tester);
    expect(find.byType(MemorizeBar), findsNothing);
    expect(
        onScreen(tester).every((x) => x.spec.hideFrom == -1), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30)); // the word audio's timeout
  });

  testWidgets('a revealed ۝: a tap recites the āyah, holding it opens the '
      'whole āyah to mark', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    await tester.pumpWidget(app(s, p, 50));
    await settle(tester);
    await startMemorize(tester);
    await tester.tap(find.byTooltip('Rest of the āyah'));
    await settle(tester);

    // The revealed āyah's ۝, on screen.
    final r = onScreen(tester).firstWhere((x) => x.spec.line.words.any(
        (w) => w.isMarker && !x.spec.isHidden(x.spec.line.words.indexOf(w))));
    final m = r.spec.line.words.indexWhere((w) => w.isMarker);
    final (left, right) = r.laidLine!.boxes[m];
    final at = r.localToGlobal(
        r.textOffset + Offset((left + right) / 2, r.laidLine!.height / 2));

    await tester.tapAt(at);
    await tester.pump();
    expect(ReciteBack.instance.playing.value, isTrue,
        reason: 'Ḥuṣarī recites the āyah');
    // Not awaited: the audio players' stops can wait on the last test's
    // fake clock.
    unawaited(ReciteBack.instance.stop());
    await tester.pump();

    await tester.longPressAt(at);
    await settle(tester);
    expect(find.textContaining('Whole āyah'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('"Show the page" shows the page on screen, not the first one',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    await tester.pumpWidget(app(s, p, 50));
    await settle(tester);
    await startMemorize(tester);

    // On to the next page (the pager turns right to left).
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(p.lastMushafPage, 51);

    await tester.tap(find.byTooltip('Show the page'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 51, reason: 'it stays on the page shown');
    final lines = onScreen(tester).where((r) => r.spec.page == 51).toList();
    expect(lines, isNotEmpty);
    expect(lines.every((r) => r.spec.hideFrom == -1), isTrue,
        reason: 'page 51 shows in full');

    await tester.tap(find.byTooltip('Hide the page'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 51);
    expect(
        onScreen(tester)
            .where((r) => r.spec.page == 51)
            .every((r) => r.spec.hideFrom >= 0 || r.spec.line.words.isEmpty),
        isTrue,
        reason: 'page 51 hidden again');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('one hand: the thumb pad steps by word and āyah, on and back',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    s.memorizeTap = 'pad';
    await tester.pumpWidget(app(s, p, 50));
    await settle(tester);
    await startMemorize(tester);
    final pad = find.byType(MemorizePad);
    expect(pad, findsOneWidget);
    final box = tester.getRect(pad);
    expect(box.right, greaterThan(430 - 100), reason: 'in the right corner');
    int revealed() => onScreen(tester)
        .fold<int>(0, (n, x) => n + _sprites(x.laidLine! as AtlasLine));
    // Zones: [next word, back a word] over [next āyah, back an āyah].
    Future<void> zone(int col, int row) async {
      await tester.tapAt(Offset(box.left + box.width * (col * 2 + 1) / 4,
          box.top + box.height * (row * 2 + 1) / 4));
      await settle(tester);
    }

    await zone(0, 0);
    final one = revealed();
    expect(one, greaterThan(0), reason: 'a word');
    await zone(0, 0);
    expect(revealed(), greaterThan(one));
    await zone(1, 0);
    expect(revealed(), one, reason: 'back a word');
    await zone(0, 1);
    final ayah = revealed();
    expect(ayah, greaterThan(one), reason: 'the rest of the āyah');
    await zone(1, 1);
    expect(revealed(), lessThan(ayah), reason: 'back an āyah');

    // The left corner, and no guide: the zones still work.
    s.update(() {
      s.memorizePadSide = 'left';
      s.memorizePadGuide = false;
    });
    await settle(tester);
    expect(tester.getRect(pad).left, lessThan(100));

    // Focus mode: one pad, over its pill (not the docked bar's too).
    s.update(() => s.focusMode = true);
    await settle(tester);
    expect(pad, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('spread: the page turns after both pages, not one',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot(desktop: true);
    await tester.pumpWidget(app(s, p, 50));
    await settle(tester);
    final start = p.lastMushafPage!;
    await startMemorize(tester);

    // The right-hand page done: the spread stays.
    await tester.tap(find.byTooltip('Rest of the page, then turn'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, anyOf(start, start + 1));
    final spreadAfterOne = onScreen(tester).map((r) => r.spec.page).toSet();
    expect(spreadAfterOne, contains(start));

    // Both pages done: the next spread, hidden.
    await tester.tap(find.byTooltip('Rest of the page, then turn'));
    await settle(tester);
    await tester.pumpAndSettle();
    final pages = onScreen(tester).map((r) => r.spec.page).toSet();
    expect(pages.contains(start), isFalse, reason: 'the spread turned');
    for (final r in onScreen(tester)) {
      expect(_sprites(r.laidLine! as AtlasLine), 0);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('marks come with their words: none on hidden ones', () {
    final atlas = MushafAtlas.of('uthmani')!;
    final line = textLine();
    final n = line.words.length;
    // Every word on the line marked.
    final marks = {
      for (final w in line.words)
        WordRef.fromGlobal(w.ayah, w.isMarker ? -1 : w.wordIdx).key:
            const MarkVisual(open: MarkType.mistake, fixed: false,
                hasComment: false, count: 1),
    };
    MushafLineSpec spec(int hideFrom) => MushafLineSpec(
          script: 'uthmani',
          page: 2,
          index: 3,
          line: line,
          fontSize: 22,
          slotH: 40,
          targetW: 380,
          ink: const Color(0xFF000000),
          accent: const Color(0xFF00AA00),
          strongBg: const Color(0x3300AA00),
          verseBg: const Color(0x1100AA00),
          marks: marks,
          markPal: markPaletteForPaper(kMushafPapers['cream']!),
          hideFrom: hideFrom,
        );
    final half = n ~/ 2;
    final l = buildAtlasLine(spec(line.firstTok + half), atlas, 0);
    expect(l.markLines, hasLength(half), reason: 'the revealed words only');
    expect(l.backgrounds, hasLength(half));
    final all = buildAtlasLine(spec(-1), atlas, 0);
    expect(all.markLines, hasLength(n));
  });

  testWidgets('verse cards: large āyah, word by word, marks, and the page view',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await boot();
    final m = MarksStore(
        persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Me').id;
    m.addMark(b, const WordRef(2, 2, 2), MarkType.doubt); // لَا of 2:2
    final c = MemorizeController.startAt('uthmani', 2);
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
            home: MemorizeCardsScreen(controller: c),
          ),
        ),
      ),
    ));
    await settle(tester);
    expect(find.byType(VerseView), findsOneWidget);
    expect(find.byType(MemorizeBar), findsOneWidget);
    var lines = onScreen(tester);
    expect(lines.every((r) => _sprites(r.laidLine! as AtlasLine) == 0), isTrue);
    expect(lines.first.spec.fontSize, s.memorizeCardFont);

    // 2:1 (one word and its ۝); then the card turns to 2:2, blank; then its
    // words — and the doubt on its second word shows once it's there.
    await tester.tap(find.text('Next word'));
    await settle(tester);
    expect(c.viewAyah, MushafRepo.globalAyahOf(2, 1));
    await tester.tap(find.text('Next word'));
    await settle(tester);
    expect(c.viewAyah, MushafRepo.globalAyahOf(2, 2));
    lines = onScreen(tester);
    expect(lines.every((r) => _sprites(r.laidLine! as AtlasLine) == 0), isTrue,
        reason: 'the turn reveals nothing');
    await tester.tap(find.text('Next word'));
    await settle(tester);
    lines = onScreen(tester);
    expect(lines.expand((r) => r.laidLine!.markLines), isEmpty,
        reason: 'the marked word is still hidden');
    await tester.tap(find.text('Next word'));
    await settle(tester);
    lines = onScreen(tester);
    expect(lines.expand((r) => r.laidLine!.markLines), hasLength(1));

    // Bigger text.
    final before = s.memorizeCardFont;
    await tester.tap(find.byTooltip('Larger text'));
    await settle(tester);
    expect(s.memorizeCardFont, before + 4);

    // To the muṣḥaf page, the same place.
    await tester.tap(find.byTooltip('Muṣḥaf page'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(find.byType(MemorizeBar), findsOneWidget);
    expect(p.lastMushafPage, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
