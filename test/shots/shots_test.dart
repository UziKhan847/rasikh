// Renders the main screens to PNGs for a visual check against the design
// prototype. Off by default; run with
//   flutter test test/shots/shots_test.dart --dart-define=SHOTS=/some/dir
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';
import 'package:qiraah_arabiyyah/screens/tajweed_screen.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/learn_screen.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart';
import 'package:qiraah_arabiyyah/screens/dyslexia_screen.dart';
import 'package:qiraah_arabiyyah/screens/tashkeel_screen.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';
import 'package:qiraah_arabiyyah/screens/onboarding_screen.dart';
import 'package:qiraah_arabiyyah/screens/settings_screen.dart';
import 'package:qiraah_arabiyyah/screens/shell/modules.dart';
import 'package:qiraah_arabiyyah/screens/downloads_screen.dart';

import '../test_support.dart';

const _out = String.fromEnvironment('SHOTS');

/// Shots to take: name → (screen, width, height, theme).
typedef Shot = (String, Widget Function(), double, double, String);

late List<SurahMeta> _meta;

/// Per-shot setting tweaks.
final tweaks = <String, void Function(AppSettings)>{
  'reader_phone_grid': (s) {
    s.wordByWord = true;
    s.wbwGroup = 2;
  },
  'reader_desk_night_tajwid': (s) => s.tajwidColors = true,
  'reader_phone_float': (s) => s.playerDock = 'floating',
  'mushaf_desk_single_oled': (s) => s.mushafView = 'single',
  'mushaf_desk_fill_night': (s) => s.mushafView = 'fill',
  'mushaf_phone_white_plain': (s) {
    s.mushafPaper = 'white';
    s.orHeader = 'plain';
    s.orMarker = 'font';
    s.orMargin = 'none';
  },
};

final shotList = <Shot>[
  ('today_phone_light', () => const RootScreen(), 390, 844, 'light'),
  ('today_phone_night', () => const RootScreen(), 390, 844, 'night'),
  ('today_desk_light', () => const RootScreen(), 1440, 900, 'light'),
  ('today_desk_oled', () => const RootScreen(), 1440, 900, 'oled'),
  ('learn_phone_light', () => const LearnScreen(), 390, 844, 'light'),
  ('settings_phone_light', () => const SettingsScreen(), 390, 1800, 'light'),
  ('settings_desk_mono', () => const SettingsScreen(), 1440, 1400, 'mono'),
  ('onboarding_phone', () => const OnboardingScreen(), 390, 844, 'light'),
  ('quran_phone_light', () => const SurahListScreen(), 390, 844, 'light'),
  ('quran_desk_light', () => const SurahListScreen(), 1440, 900, 'light'),
  ('reader_phone_light', () => SurahReaderScreen(meta: _meta[0]), 390, 844, 'light'),
  ('reader_phone_grid', () => SurahReaderScreen(meta: _meta[0]), 390, 844, 'light'),
  ('reader_phone_float', () => SurahReaderScreen(meta: _meta[111]), 390, 844, 'oled'),
  ('reader_desk_night_tajwid', () => SurahReaderScreen(meta: _meta[1]), 1440, 900, 'night'),
  ('mushaf_phone_light', () => const MushafPageScreen(startPage: 2), 390, 844, 'light'),
  ('mushaf_phone_white_plain', () => const MushafPageScreen(startPage: 1), 390, 844, 'light'),
  ('mushaf_phone_night', () => const MushafPageScreen(startPage: 3), 390, 844, 'night'),
  ('mushaf_phone_landscape', () => const MushafPageScreen(startPage: 3), 844, 390, 'light'),
  ('mushaf_desk_spread_light', () => const MushafPageScreen(startPage: 1), 1440, 900, 'light'),
  ('mushaf_desk_single_oled', () => const MushafPageScreen(startPage: 50), 1440, 900, 'oled'),
  ('mushaf_desk_fill_night', () => const MushafPageScreen(startPage: 50), 1440, 900, 'night'),
  for (final m in LearnModule.values) ...[
    ('mod_${m.name}_phone', () => Builder(builder: m.screen), 390, 844, 'light'),
    ('mod_${m.name}_desk', () => Builder(builder: m.screen), 1440, 900, 'light'),
  ],
  ('qaidah_unit_phone', () => Builder(builder: (c) => QaidahUnitHub(unit: qaidahUnits(c)[2])), 390, 844, 'light'),
  ('letters_phone', () => const LettersExplorer(), 390, 844, 'light'),
  ('letters_desk', () => const LettersExplorer(), 1440, 900, 'night'),
  ('letter_phone', () => LetterDetail(letter: letters[2]), 390, 1300, 'light'),
  ('letter_desk', () => LetterDetail(letter: letters[2]), 1440, 1000, 'light'),
  ('quiz_phone', () => Builder(builder: (c) => letterQuizScreen(c)), 390, 844, 'light'),
  ('quiz_desk', () => Builder(builder: (c) => letterQuizScreen(c)), 1440, 900, 'night'),
  ('tajwid_rule_phone', () => TajwidRuleScreen(rule: tajwidRules.firstWhere((r) => r.id == 'madd4')), 390, 1200, 'light'),
  ('tajwid_rule_night', () => TajwidRuleScreen(rule: tajwidRules.firstWhere((r) => r.id == 'ikhfa')), 390, 1000, 'night'),
  ('trace_desk_night', () => Builder(builder: LearnModule.tracing.screen), 1440, 900, 'night'),
  ('spot_phone', () => const SpotTheLetterDrill(), 390, 844, 'light'),
  ('spot_desk', () => const SpotTheLetterDrill(), 1440, 900, 'light'),
  ('sprint_phone', () => const FluencySprint(), 390, 844, 'light'),
  ('sprint_desk', () => const FluencySprint(), 1440, 900, 'light'),
  ('downloads_desk', () => const DownloadsScreen(), 1440, 900, 'light'),
  ('counts_phone', () => const CountsStudio(initialCounts: 4), 390, 844, 'light'),
  ('counts_desk', () => const CountsStudio(initialCounts: 4), 1440, 900, 'night'),
  ('downloads_phone', () => const DownloadsScreen(), 390, 844, 'light'),
];

Future<void> loadFonts() async {
  final fonts = <String, List<String>>{
    'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
    'SourceSerif4': ['SourceSerif4-Regular', 'SourceSerif4-Medium'],
    'NotoNaskhArabic': [
      'NotoNaskhArabic-Regular', 'NotoNaskhArabic-SemiBold',
      'NotoNaskhArabic-Bold'
    ],
    'UthmanicHafs': ['UthmanicHafs'],
    'QiraahIcons': ['QiraahIcons'],
    'DigitalKhattV2': ['DigitalKhattV2'],
    'DigitalKhattIndoPak': ['DigitalKhattIndoPak'],
    'ScheherazadeNew': ['ScheherazadeNew'],
    'SurahNames': ['SurahNames'],
    'Bismillah': ['Bismillah'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      final file = File('assets/fonts/$f.ttf').existsSync()
          ? File('assets/fonts/$f.ttf')
          : File('assets/fonts/$f.otf');
      loader.addFont(Future.value(ByteData.view(
          Uint8List.fromList(file.readAsBytesSync()).buffer)));
    }
    await loader.load();
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final mi = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (mi.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          ByteData.view(Uint8List.fromList(mi.readAsBytesSync()).buffer)));
    await l.load();
  }
}

void main() {
  if (_out.isEmpty) {
    test('shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    _meta = await QuranRepo.meta();
    for (final n in [1, 2, 112]) {
      for (final f in ['DigitalKhattV2', 'UthmanicHafs']) {
        await QuranRepo.ayahs(n, 'uthmani', font: f);
        await QuranRepo.words(n, 'uthmani', font: f);
      }
      await QuranRepo.tajwid(n, 'uthmani');
    }
    await MushafRepo.ensure('uthmani');
  });

  for (final (name, build, w, h, theme) in shotList) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      final p = ProgressStore();
      await s.load();
      await p.load();
      s.onboarded = true;
      s.appTheme = theme;
      s.desktopMode = w >= 1024 ? 'on' : 'off';
      tweaks[name]?.call(s);
      final key = GlobalKey();
      await tester.pumpWidget(SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(s),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: RepaintBoundary(key: key, child: build()),
          ),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() async {
        // let image assets decode
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 100));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
