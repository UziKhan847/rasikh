import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/original/mushaf_packs.dart';
import 'package:rasikh/data/original/original_atlas.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/edition_picker.dart';
import 'package:rasikh/screens/mushaf/pack_sheet.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Old Madani isn't bundled: its files are a folder chosen (or, later,
/// downloaded), checked before they're used, and asked for when it's picked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const full = 'assets/quran/old_madani';
  late Directory tmp;
  late String lowOnly, empty;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('rasikh_packs');
    // Only the low set (linked, not copied) and the two JSONs.
    lowOnly = '${tmp.path}/old_madani_low';
    Directory(lowOnly).createSync();
    for (final f in ['pages.json', 'signs.json']) {
      File('$full/$f').copySync('$lowOnly/$f');
    }
    Link('$lowOnly/low').createSync(Directory('$full/low').absolute.path);
    empty = '${tmp.path}/empty';
    Directory(empty).createSync();
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  tearDown(() {
    MushafPacks.debugDir = null;
    MushafPacks.dirs = {};
    OriginalAtlas.reset();
  });

  group('what a folder holds', () {
    test('the whole set: both tiers', () {
      final (pack, problem) = MushafPacks.check(full, kOldMadani);
      expect(problem, isNull);
      expect(pack!.tiers, {OriginalTier.high, OriginalTier.low});
    });

    test('only low; and a tier\'s own folder stands for its set', () {
      expect(MushafPacks.check(lowOnly, kOldMadani).$1!.tiers, {OriginalTier.low});
      final (pack, _) = MushafPacks.check('$full/high', kOldMadani);
      expect(pack!.tiers, {OriginalTier.high});
      expect(pack.root, Directory(full).absolute.path);
    });

    test('not a pack: says what\'s missing', () {
      expect(MushafPacks.check(empty, kOldMadani), (null, PackProblem.noData));
      expect(MushafPacks.check('${tmp.path}/nowhere', kOldMadani), (null, PackProblem.missing));
      final noTier = '${tmp.path}/no_tier';
      Directory(noTier).createSync();
      for (final f in ['pages.json', 'signs.json']) {
        File('$full/$f').copySync('$noTier/$f');
      }
      expect(MushafPacks.check(noTier, kOldMadani), (null, PackProblem.noTier));
    });

    test('with only low there, low is what opens, whatever was asked', () async {
      MushafPacks.dirs = {kOldMadani: lowOnly};
      final a = await OriginalAtlas.open(kOldMadani, OriginalTier.high);
      expect(a.tier, OriginalTier.low);
    });

    test('no folder: nothing opens', () async {
      expect(MushafPacks.available(kOldMadani), isFalse);
      expect(MushafPacks.available('uthmani'), isTrue);
      await expectLater(OriginalAtlas.open(kOldMadani, OriginalTier.low), throwsA(isA<OriginalPackMissing>()));
    });
  });

  Future<AppSettings> picker(WidgetTester tester, List<String> picked) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: SettingsScope(
        settings: s,
        child: Scaffold(body: MushafEditionPicker(value: 'uthmani', onChanged: picked.add)),
      ),
    ));
    return s;
  }

  testWidgets('picking Old Madani without its files: the prompt, with sizes, '
      'and a folder chosen picks it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final folders = [empty, lowOnly];
    final prev = pickPackFolder;
    pickPackFolder = () async => folders.removeAt(0);
    addTearDown(() => pickPackFolder = prev);
    final picked = <String>[];
    final s = await picker(tester, picked);

    await tester.tap(find.text('Old Madani'));
    await tester.pumpAndSettle();
    expect(find.text("Old Madani isn't on this device"), findsOneWidget);
    expect(find.textContaining('124 MB'), findsOneWidget);
    expect(find.textContaining('73 MB'), findsOneWidget);
    // (The recommendation once the device's memory has been asked.)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Recommended'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('pack-high'))).enabled, isFalse,
        reason: 'no download yet');
    expect(picked, isEmpty);

    // A folder that isn't one: said, and the prompt stays.
    await tester.tap(find.byKey(const ValueKey('pack-folder')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pack-problem')), findsOneWidget);
    expect(picked, isEmpty);

    await tester.tap(find.byKey(const ValueKey('pack-folder')));
    await tester.pumpAndSettle();
    expect(find.text("Old Madani isn't on this device"), findsNothing);
    expect(picked, [kOldMadani]);
    expect(s.packDirs[kOldMadani], lowOnly, reason: 'kept');
    await tester.runAsync(() async {
      await s.save();
      MushafPacks.dirs = {};
      await AppSettings().load();
    });
    expect(MushafPacks.dirs, {kOldMadani: lowOnly}, reason: 'saved, and back on loading');

    // Now it's there: picked at once.
    await tester.tap(find.text('Old Madani'));
    await tester.pumpAndSettle();
    expect(picked, [kOldMadani, kOldMadani]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on a phone: no folder to choose and no download yet, so the chip is '
      'greyed out (no prompt with nothing to press)', (tester) async {
    final picked = <String>[];
    await picker(tester, picked);
    await tester.tap(find.text('Old Madani'));
    await tester.pumpAndSettle();
    expect(find.text("Old Madani isn't on this device"), findsNothing);
    expect(find.byKey(const ValueKey('edition-soon-$kOldMadani')), findsOneWidget);
    expect(picked, isEmpty);
  });

  testWidgets('its files gone: the muṣḥaf goes back to New Madani and says so',
      (tester) async {
    mockAudioPlugins();
    await tester.runAsync(() async {
      await QuranRepo.meta();
      await MushafRepo.ensure('uthmani');
      await MushafRepo.ensure(kOldMadani);
    });
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
      ..mushafScript = kOldMadani;
    MushafPacks.dirs = {kOldMadani: '${tmp.path}/moved'};
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
            home: const MushafPageScreen(home: true, startPage: 50, script: kOldMadani),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(s.mushafScript, 'uthmani');
    expect(find.text("Old Madani's files weren't found"), findsOneWidget);
    expect(find.text('Choose…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });
}
