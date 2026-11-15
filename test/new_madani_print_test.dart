import 'package:flutter/foundation.dart';
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
import 'package:rasikh/screens/mushaf/pack_sheet.dart';
import 'package:rasikh/screens/mushaf_screen.dart' show MushafPageScreen;

import 'test_support.dart';

/// The new Madani print (QPC V2, 1421H), drawn from its own page atlases as
/// Old Madani is — and each print's folder only ever its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const newDir = 'assets/quran/new_madani', oldDir = 'assets/quran/old_madani';

  tearDown(() {
    MushafPacks.dirs = {};
    OriginalAtlas.reset();
  });

  group('one print\'s folder isn\'t the other\'s', () {
    test('each folder is its own print', () {
      expect(MushafPacks.editionAt(newDir), kNewMadaniPrint);
      expect(MushafPacks.editionAt(oldDir), kOldMadani);
      expect(MushafPacks.check(newDir, kNewMadaniPrint).$1!.tiers,
          {OriginalTier.high, OriginalTier.low});
      expect(MushafPacks.check(oldDir, kOldMadani).$1, isNotNull);
    });

    test('New Madani\'s for Old Madani, Old Madani\'s for New: refused, '
        'the whole set or a tier\'s folder', () {
      expect(MushafPacks.check(newDir, kOldMadani), (null, PackProblem.otherEdition));
      expect(MushafPacks.check(oldDir, kNewMadaniPrint), (null, PackProblem.otherEdition));
      expect(MushafPacks.check('$newDir/low', kOldMadani), (null, PackProblem.otherEdition));
      expect(MushafPacks.check('$oldDir/high', kNewMadaniPrint), (null, PackProblem.otherEdition));
    });

    test('set the wrong way round, neither opens', () async {
      MushafPacks.dirs = {kOldMadani: newDir, kNewMadaniPrint: oldDir};
      expect(MushafPacks.available(kOldMadani), isFalse);
      expect(MushafPacks.available(kNewMadaniPrint), isFalse);
      await expectLater(OriginalAtlas.open(kNewMadaniPrint, OriginalTier.high),
          throwsA(isA<OriginalPackMissing>()));
    });

    testWidgets('choosing the other print\'s folder says so, and isn\'t kept', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final prev = pickPackFolder;
      pickPackFolder = () async => oldDir;
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      final picked = <String>[];
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SettingsScope(
          settings: s,
          child: Scaffold(body: MushafEditionPicker(value: 'uthmani', onChanged: picked.add)),
        ),
      ));
      await tester.tap(find.text('New Madani').last);
      await tester.pumpAndSettle();
      expect(find.text("New Madani isn't on this device"), findsOneWidget);
      expect(find.textContaining('147 MB'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pack-folder')));
      await tester.pumpAndSettle();
      expect(find.text('That folder holds Old Madani, not New Madani.'), findsOneWidget);
      expect(picked, isEmpty);
      expect(s.packDirs, isEmpty);

      pickPackFolder = () async => newDir;
      await tester.tap(find.byKey(const ValueKey('pack-folder')));
      await tester.pumpAndSettle();
      expect(picked, [kNewMadaniPrint]);
      expect(s.packDirs, {kNewMadaniPrint: newDir});
      pickPackFolder = prev;
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('the print', () {
    late OriginalAtlas high, low;
    setUpAll(() async {
      mockAudioPlugins();
      await QuranRepo.meta();
      await MushafRepo.ensure('uthmani');
      await MushafRepo.ensure(kNewMadaniPrint);
    });
    setUp(() async {
      MushafPacks.dirs = {kNewMadaniPrint: newDir};
      high = await OriginalAtlas.open(kNewMadaniPrint, OriginalTier.high);
      low = await OriginalAtlas.open(kNewMadaniPrint, OriginalTier.low);
    });

    test('its own scale: the same page in pixels as Old Madani\'s', () {
      expect(high.pxPerMm, 13.6);
      expect(low.pxPerMm, 8.5);
      expect(high.script, kNewMadaniPrint);
      expect(high.classicCircle, isNull, reason: 'its own ornate frame only');
    });

    test('every token of the muṣḥaf has its place on its page, in both sets', () {
      for (final atlas in [high, low]) {
        var seen = 0;
        for (var p = 1; p <= 604; p++) {
          final d = atlas.dataOf(p);
          final (first, end) = MushafRepo.pageTokens(kNewMadaniPrint, p);
          for (var t = first; t < end; t++) {
            expect(d.tokens[t], isNotNull, reason: '${atlas.tier} p.$p token $t');
            expect(d.tokens[t]!.right, greaterThan(d.tokens[t]!.left));
            seen++;
          }
        }
        expect(seen, MushafRepo.tokenCount(kNewMadaniPrint));
      }
    });

    test('its ۞ and sajdah signs are its own, drawn from the page', () {
      var signs = 0;
      for (var p = 1; p <= 604; p++) {
        final manifest = high.reader.page(p);
        final d = high.dataOf(p);
        expect(d.pageToken.length, manifest.sprites.length, reason: 'p.$p: all of them');
        expect(d.sharedToken.length, manifest.instances.length);
        signs += manifest.sprites.where((r) {
          final t = (r.id >> 16) & 0xF;
          return t == 3 || t == 5;
        }).length;
      }
      expect(signs, 199 + 15, reason: 'each ۞ and sajdah sign');
    });

    test('every page has its lines, each word on its line; the opening pages their own', () {
      for (var p = 3; p <= 604; p++) {
        expect(MushafRepo.pageSync(kNewMadaniPrint, p)!.length, 15, reason: 'p.$p');
      }
      expect(MushafRepo.pageSync(kNewMadaniPrint, 1)!.length, 8);
      expect(MushafRepo.pageSync(kNewMadaniPrint, 2)!.length, 8);
      for (final p in [3, 50, 254, 300, 604]) {
        final d = high.dataOf(p);
        final lines = MushafRepo.pageSync(kNewMadaniPrint, p)!;
        for (final e in lines.indexed) {
          final (row, line) = e;
          for (final w in line.words) {
            final t = MushafRepo.tokenOf(kNewMadaniPrint, w.ayah, w.wordIdx);
            expect(d.tokens[t]!.row, row, reason: 'p.$p line $row');
          }
        }
      }
    });

    test('the same words as the generated New Madani, and its pages but one '
        '(p.254, where the print sets 18:… a word up)', () {
      expect(MushafRepo.tokensSync(kNewMadaniPrint), MushafRepo.tokensSync('uthmani'));
      final differ = <int>[];
      for (var p = 1; p <= 604; p++) {
        if (MushafRepo.pageTokens(kNewMadaniPrint, p) != MushafRepo.pageTokens('uthmani', p)) {
          differ.add(p);
        }
      }
      expect(differ, isEmpty, reason: 'the same words on every page');
      expect(MushafRepo.matchingPage('uthmani', 254, kNewMadaniPrint), 254);
    });

    testWidgets('on the muṣḥaf: its page is drawn from its own atlas', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      final p = ProgressStore();
      await s.load();
      await p.load();
      MushafPacks.dirs = {kNewMadaniPrint: newDir};
      s
        ..onboarded = true
        ..toolHintSeen = true
        ..desktopMode = 'off';
      final tier = await tester.runAsync(() => originalTierOfDevice(lite: false));
      final a = await tester.runAsync(() => OriginalAtlas.open(kNewMadaniPrint, tier!));
      await tester.pumpWidget(SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const MushafPageScreen(startPage: 100, script: kNewMadaniPrint),
          ),
        ),
      ));
      for (var i = 0; i < 40 && a!.window.imageOf(100) == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(a!.window.imageOf(100), isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
