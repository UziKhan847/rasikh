import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/original/mushaf_packs.dart';
import 'package:rasikh/data/original/original_atlas.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/edition_picker.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart' show MushafTapHandlers;
import 'package:rasikh/screens/mushaf_screen.dart' show MushafPageScreen;
import 'package:rasikh/screens/mushaf/original_page.dart';
import 'package:rasikh/ui/mark_style.dart' show markPaletteForPaper;
import 'package:rasikh/core/theme.dart';

import 'test_support.dart';

Future<ui.Image> _image() async {
  final r = ui.PictureRecorder();
  ui.Canvas(r).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
  final p = r.endRecording();
  final i = await p.toImage(1, 1);
  p.dispose();
  return i;
}

/// A window whose images are all kept, to see which were disposed.
class _Rig {
  final made = <int, ui.Image>{};
  late final window = PageImageWindow((page) async {
    final i = await _image();
    made[page] = i;
    return i;
  });

  /// Holds what a reader on [first]..[last] holds, and waits for it.
  Future<void> at(int first, int last, {int total = 604}) async {
    final (a, b) = originalWindow(first, last, total);
    window.hold(this, a, b, focus: first);
    for (var i = 0; i < 300 && !(window.loaded.length == b - a + 1 && window.loading.isEmpty); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  List<int> get pages => window.loaded.toList()..sort();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The print isn't bundled: its files are the repo's folder of them.
  setUpAll(() => MushafPacks.debugDir = 'assets/quran/old_madani');
  tearDownAll(() => MushafPacks.debugDir = null);

  group('the window', () {
    test('one page: it and 3 each way; a swipe frees the far side, loads the near',
        () async {
      final r = _Rig();
      await r.at(100, 100);
      expect(r.pages, [97, 98, 99, 100, 101, 102, 103]);
      final far = r.made[97]!;
      await r.at(101, 101);
      expect(r.pages, [98, 99, 100, 101, 102, 103, 104]);
      expect(far.debugDisposed, isTrue);
      final near = r.made[104]!;
      await r.at(100, 100);
      expect(r.pages, [97, 98, 99, 100, 101, 102, 103]);
      expect(near.debugDisposed, isTrue);
      r.window.dispose();
    });

    test('two pages: a swipe changes two', () async {
      final r = _Rig();
      await r.at(101, 102);
      expect(r.pages, [98, 99, 100, 101, 102, 103, 104, 105]);
      final a = r.made[98]!, b = r.made[99]!;
      await r.at(103, 104);
      expect(r.pages, [100, 101, 102, 103, 104, 105, 106, 107]);
      expect(a.debugDisposed && b.debugDisposed, isTrue);
      expect(r.made[100]!.debugDisposed, isFalse);
      r.window.dispose();
    });

    test('at the book\'s ends it stays inside it', () async {
      final r = _Rig();
      await r.at(1, 1);
      expect(r.pages, [1, 2, 3, 4]);
      await r.at(604, 604);
      expect(r.pages, [601, 602, 603, 604]);
      r.window.dispose();
    });

    test('a jump frees all the old pages', () async {
      final r = _Rig();
      await r.at(100, 100);
      final old = r.made.values.toList();
      await r.at(400, 400);
      expect(old.every((i) => i.debugDisposed), isTrue);
      expect(r.pages, [397, 398, 399, 400, 401, 402, 403]);
      r.window.dispose();
    });

    test('a page that arrives after it left the window is disposed', () async {
      final gate = Completer<void>();
      final made = <ui.Image>[];
      final w = PageImageWindow((p) async {
        final i = await _image();
        made.add(i);
        await gate.future;
        return i;
      });
      final owner = Object();
      w.hold(owner, 10, 10, focus: 10);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      w.release(owner);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(w.loaded, isEmpty);
      expect(made.single.debugDisposed, isTrue);
      w.dispose();
    });

    test('the visible page loads first, then the way the reader is heading',
        () async {
      final order = <int>[];
      final w = PageImageWindow((p) async {
        order.add(p);
        return _image();
      });
      w.hold(Object(), 97, 103, focus: 100);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(order.first, 100);
      expect(order[1], 101, reason: 'ahead before behind');
      w.dispose();
    });

    test('a few load at once, no more, and the visible page first', () async {
      final waiting = <Completer<void>>[];
      final order = <int>[];
      final w = PageImageWindow((p) async {
        order.add(p);
        final c = Completer<void>();
        waiting.add(c);
        await c.future;
        return _image();
      });
      w.hold(Object(), 97, 103, focus: 100);
      expect(order, [100, 101, 99]);
      expect(w.loading.length, PageImageWindow.maxLoads);
      waiting.first.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(order.length, 4, reason: 'one done, one more starts');
      expect(w.loading.length, PageImageWindow.maxLoads);
      w.dispose();
      for (final c in waiting.where((c) => !c.isCompleted)) {
        c.complete();
      }
    });

    test('the far page stays until the near one has arrived, then goes', () async {
      final gate = <int, Completer<void>>{};
      final made = <int, ui.Image>{};
      final w = PageImageWindow((p) async {
        final c = gate[p];
        if (c != null) await c.future;
        return made[p] = await _image();
      });
      final me = Object();
      w.hold(me, 97, 103, focus: 100);
      for (var i = 0; i < 100 && w.loaded.length < 7; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      gate[104] = Completer<void>();
      w.hold(me, 98, 104, focus: 101);
      expect(made[97]!.debugDisposed, isFalse, reason: 'still loading the near one');
      expect(w.imageOf(97), isNotNull);
      gate[104]!.complete();
      for (var i = 0; i < 100 && w.imageOf(104) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(made[97]!.debugDisposed, isTrue);
      expect(w.loaded.length, 7);
      w.dispose();
    });

    test('a page that failed gets another try at the next hold', () async {
      var failing = true;
      final w = PageImageWindow((p) async {
        if (failing) throw StateError('no');
        return _image();
      });
      final me = Object();
      w.hold(me, 10, 10, focus: 10);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(w.imageOf(10), isNull);
      failing = false;
      w.hold(me, 10, 10, focus: 10);
      for (var i = 0; i < 100 && w.imageOf(10) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(w.imageOf(10), isNotNull);
      w.dispose();
    });

    test('a page on screen with no image asks for itself, and hears it came', () async {
      final w = PageImageWindow((_) => _image());
      var pinged = 0;
      w.signal(55).addListener(() => pinged++);
      w.hold(Object(), 10, 12, focus: 10);
      w.ask(55);
      for (var i = 0; i < 100 && w.imageOf(55) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(w.imageOf(55), isNotNull);
      expect(pinged, 1);
      w.dispose();
    });

    test('two holders keep both their pages', () async {
      final w = PageImageWindow((_) => _image());
      final a = Object(), b = Object();
      w.hold(a, 10, 10, focus: 10);
      w.hold(b, 50, 50, focus: 50);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(w.loaded.toSet(), {10, 50});
      w.release(a);
      expect(w.loaded.toSet(), {50});
      w.dispose();
    });
  });

  test('which set: Lite, little memory and small screens get low', () {
    OriginalTier t({bool lite = false, int? ram, int s = 1440, int l = 3120}) =>
        originalTierFor(lite: lite, shortPx: s, longPx: l, ramMb: ram);
    expect(t(), OriginalTier.high);
    expect(t(lite: true), OriginalTier.low);
    expect(t(ram: 4096), OriginalTier.low);
    expect(t(ram: 8192), OriginalTier.high);
    expect(t(s: 1080, l: 2400), OriginalTier.low);
    expect(t(s: 1600, l: 2560), OriginalTier.high, reason: 'a tablet');
  });

  group('the print', () {
    late OriginalAtlas high, low;
    setUpAll(() async {
      mockAudioPlugins();
      await QuranRepo.meta();
      await MushafRepo.ensure(kOldMadani);
      high = await OriginalAtlas.open(kOldMadani, OriginalTier.high);
      low = await OriginalAtlas.open(kOldMadani, OriginalTier.low);
    });

    test('۞ and the sajdah sign come from the shared atlas, every one, centred '
        'where the print\'s stood', () {
      for (final atlas in [high, low]) {
        var hizb = 0, sajdah = 0;
        for (var p = 1; p <= 604; p++) {
          final manifest = atlas.reader.page(p);
          final d = atlas.dataOf(p);
          final signs = manifest.sprites.where((r) {
            final t = (r.id >> 16) & 0xF;
            return t == 3 || t == 5;
          }).toList();
          expect(d.pageToken.length, manifest.sprites.length - signs.length,
              reason: 'p.$p draws none of the old ones');
          expect(d.sharedToken.length, manifest.instances.length + signs.length);
          for (final e in signs.indexed) {
            final (k, r) = e;
            final i = manifest.instances.length + k;
            final isHizb = (r.id >> 16) & 0xF == 5;
            isHizb ? hizb++ : sajdah++;
            final c = isHizb ? atlas.hizbSign! : atlas.sajdahSign!;
            expect(d.sharedRects[i * 4], c.x);
            expect(d.sharedRects[i * 4 + 1], c.y);
            final oldY = d.sharedY[i] + c.h / 2, oldX = d.sharedX[i] + c.w / 2;
            final (cx, y0) = atlas.pages.pages[p]!;
            final mm = atlas.pxPerMm;
            if (!d.opening) {
              expect(oldX - (d.blockW / 2 - cx * mm), closeTo(r.left + r.width / 2, .01));
              expect(oldY - (d.pitch / 2 - y0 * mm), closeTo(r.top + r.height / 2, .01));
            }
          }
        }
        expect(hizb, 199);
        expect(sajdah, 15);
      }
    });

    test('every token of the muṣḥaf has its place on its page, in both sets', () {
      for (final atlas in [high, low]) {
        var seen = 0;
        for (var p = 1; p <= 604; p++) {
          final d = atlas.dataOf(p);
          final (first, end) = MushafRepo.pageTokens(kOldMadani, p);
          for (var t = first; t < end; t++) {
            expect(d.tokens[t], isNotNull, reason: '${atlas.tier} p.$p token $t');
            seen++;
          }
        }
        expect(seen, MushafRepo.tokenCount(kOldMadani));
      }
    });

    test('every page has its lines; the opening pages their own', () {
      for (var p = 3; p <= 604; p++) {
        expect(MushafRepo.pageSync(kOldMadani, p)!.length, 15, reason: 'p.$p');
      }
      expect(MushafRepo.pageSync(kOldMadani, 1)!.length, 8);
      expect(MushafRepo.pageSync(kOldMadani, 2)!.length, 8);
    });

    test('its own pages: 5:77 is on page 121, not New Madani\'s 120', () async {
      await MushafRepo.ensure('uthmani');
      final g = MushafRepo.globalAyahOf(5, 77);
      expect(MushafRepo.pageForGlobalAyah(kOldMadani, g), 121);
      expect(MushafRepo.pageForGlobalAyah('uthmani', g), 120);
    });

    test('the same words as New Madani, so marks carry over', () async {
      await MushafRepo.ensure('uthmani');
      expect(MushafRepo.tokensSync(kOldMadani), MushafRepo.tokensSync('uthmani'));
    });

    test('where the print divides words differently', () {
      final d254 = high.dataOf(254), d451 = high.dataOf(451);
      // بعدما: one word in the print, two tokens in one place.
      final g = MushafRepo.globalAyahOf(13, 37);
      final a = MushafRepo.tokenOf(kOldMadani, g, 7), b = MushafRepo.tokenOf(kOldMadani, g, 8);
      expect(d254.tokens[a]!.left, d254.tokens[b]!.left);
      expect(d254.tokens[a]!.right, d254.tokens[b]!.right);
      // إل ياسين: two words in the print, one token over both.
      final y = MushafRepo.tokenOf(kOldMadani, MushafRepo.globalAyahOf(37, 130), 2);
      final box = d451.tokens[y]!;
      expect(box.right - box.left, greaterThan(150), reason: 'both words');
    });

    test('7:58 has its لَا (page 158, from the corrected SVG)', () {
      final t = MushafRepo.tokenOf(kOldMadani, MushafRepo.globalAyahOf(7, 58), 8);
      expect(MushafRepo.pageOfToken(kOldMadani, t), 158);
      final box = high.dataOf(158).tokens[t]!;
      expect(box.right, greaterThan(box.left));
    });

    test('the classic circle: the same opening, on the shared atlas, in both sets',
        () {
      for (final atlas in [high, low]) {
        final plain = atlas.dataOf(3), classic = atlas.dataOf(3, classic: true);
        expect(classic.sharedX.length, plain.sharedX.length);
        final c = atlas.classicCircle!;
        var swapped = 0;
        for (var i = 0; i < plain.sharedX.length; i++) {
          final isClassic = classic.sharedRects[i * 4 + 1] == c.y;
          if (!isClassic) {
            // Everything else, the digits too, stays exactly where it was.
            expect(classic.sharedX[i], plain.sharedX[i]);
            expect(classic.sharedY[i], plain.sharedY[i]);
            continue;
          }
          swapped++;
          final s = classic.sharedScale[i];
          // Its centre is where the frame's opening centre is.
          expect(classic.sharedX[i] + c.w * s / 2, closeTo(plain.sharedX[i] + c.cx * s, .01));
          expect(classic.sharedY[i] + c.h * s / 2, closeTo(plain.sharedY[i] + c.cy * s, .01));
        }
        expect(swapped, greaterThan(0));
        expect(classic.sharedRow, plain.sharedRow, reason: 'the same lines');
      }
    });

    group('on the muṣḥaf', () {
      Future<(OriginalAtlas, AppSettings)> open(WidgetTester tester, int page) async {
        tester.view.physicalSize = const Size(430, 900);
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
          ..desktopMode = 'off';
        final tier = await originalTierOfDevice(lite: false);
        final a = tier == OriginalTier.high ? high : low;
        await tester.pumpWidget(SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: MushafPageScreen(startPage: page, script: kOldMadani),
            ),
          ),
        ));
        for (var i = 0; i < 40 && a.window.imageOf(page) == null; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 60));
        }
        await tester.pump(const Duration(milliseconds: 300));
        return (a, s);
      }

      Future<void> close(WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
      }

      testWidgets('its page is ready when it\'s shown', (tester) async {
        final (a, _) = await open(tester, 100);
        expect(a.window.imageOf(100), isNotNull);
        expect(a.window.held, {for (var p = 97; p <= 103; p++) p});
        await close(tester);
      });

      testWidgets('half-way through a swipe the window has already moved',
          (tester) async {
        final (a, _) = await open(tester, 100);
        // The pages run right to left: a drag to the right turns on.
        final g = await tester.startGesture(const Offset(60, 450));
        await g.moveBy(const Offset(20, 0));
        await tester.pump();
        await g.moveBy(const Offset(280, 0));
        await tester.pump();
        expect(a.window.held, {for (var p = 98; p <= 104; p++) p}, reason: 'finger still down');
        await g.up();
        await tester.pumpAndSettle();
        await close(tester);
      });

      testWidgets('a memory warning keeps the next pages; the next page change '
          'widens it again', (tester) async {
        final (a, _) = await open(tester, 100);
        tester.binding.handleMemoryPressure();
        await tester.pump();
        expect(a.window.held, {99, 100, 101});
        await tester.flingFrom(const Offset(60, 450), const Offset(330, 0), 1500);
        await tester.pumpAndSettle();
        expect(a.window.held, {for (var p = 98; p <= 104; p++) p});
        await close(tester);
      });
    });

    testWidgets('a tap on a word and on an āyah\'s marker reach their handlers',
        (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final paper = kMushafPapers['white']!;
      final words = <int>[], verses = <int>[];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: OriginalPageView(
          handlers: MushafTapHandlers()
            ..onTapWord = ((w) => words.add(w.wordIdx))
            ..onTapVerse = verses.add,
          spec: OriginalPageSpec(
            atlas: high,
            page: 3,
            ink: paper.ink,
            ornament: paper.frame,
            accent: paper.acc,
            strongBg: paper.hl2,
            verseBg: paper.hl,
            markPal: markPaletteForPaper(paper),
          ),
        ),
      ));
      final r = tester.renderObject<RenderOriginalPage>(find.byType(OriginalPageView));
      final (first, _) = MushafRepo.pageTokens(kOldMadani, 3);
      await tester.tapAt(r.tokenRect(first)!.center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(words, [MushafRepo.wordAtToken(kOldMadani, first)!.wordIdx]);
      final g = MushafRepo.globalAyahOf(2, 6);
      await tester.tapAt(r.tokenRect(MushafRepo.tokenOf(kOldMadani, g, -1))!.center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(verses, [g]);
    });

    testWidgets('every page shares one scale and one grid', (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final paper = kMushafPapers['white']!;
      Rect first(int page) {
        final r = tester.renderObject<RenderOriginalPage>(find.byType(OriginalPageView));
        final (t, _) = MushafRepo.pageTokens(kOldMadani, page);
        return r.tokenRect(t)!;
      }

      Future<void> show(int page) => tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: OriginalPageView(
              handlers: MushafTapHandlers(),
              spec: OriginalPageSpec(
                  atlas: high,
                  page: page,
                  ink: paper.ink,
                  ornament: paper.frame,
                  accent: paper.acc,
                  strongBg: paper.hl2,
                  verseBg: paper.hl),
            ),
          ));
      await show(30);
      final a = first(30);
      await show(31);
      final b = first(31);
      expect(b.top, closeTo(a.top, .01));
      expect(b.height, closeTo(a.height, .01));
    });
  });

  testWidgets('the picker: two styles; what isn\'t ready can\'t be picked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: SettingsScope(
        settings: AppSettings(),
        child: Scaffold(body: MushafEditionPicker(value: 'uthmani', onChanged: picked.add)),
      ),
    ));
    expect(find.text('Generated'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips, hasLength(5));
    expect([for (final c in chips) c.onSelected != null], [true, true, true, true, false],
        reason: 'only the original Indo-Pak is greyed out');
    await tester.tap(find.text('Old Madani'));
    await tester.pump();
    expect(picked, [kOldMadani]);
    // The original New Madani, its files not here (Old Madani's folder isn't
    // its): asked for, not picked.
    await tester.tap(find.text('New Madani').last);
    await tester.pumpAndSettle();
    expect(picked, [kOldMadani]);
    expect(find.text("New Madani isn't on this device"), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Old Madani, held: which circle.
    final s = SettingsScope.of(tester.element(find.byType(MushafEditionPicker)));
    expect(s.oldMadaniCircle, 'classic', reason: 'the default');
    expect(find.text('Classic circle'), findsNothing, reason: 'no label: holding is for those who know');
    await tester.longPress(find.text('Old Madani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modern circle'));
    await tester.pumpAndSettle();
    expect(s.oldMadaniCircle, 'modern');
    expect(picked, [kOldMadani, kOldMadani]);
  });
}
