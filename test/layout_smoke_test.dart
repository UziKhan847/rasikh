import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/reader_size.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/main.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/onboarding_screen.dart';
import 'package:rasikh/screens/quran_screen.dart';
import 'package:rasikh/screens/settings_screen.dart';

import 'test_support.dart';

/// Every main screen at a small phone (320×568), a small desktop (1024×768)
/// and a large one (1440×900), in all four themes: no overflow, no
/// exception. (Rendering errors fail the test on their own.)
late List<SurahMeta> _meta;

final _screens = <String, Widget Function()>{
  'home': () => const RootScreen(),
  'reader': () => SurahReaderScreen(meta: _meta[1]),
  'mushaf': () => const MushafPageScreen(startPage: 2),
  'settings': () => const SettingsScreen(),
  'onboarding': () => const OnboardingScreen(),
};

const _sizes = <(String, Size)>[
  ('320', Size(320, 568)),
  ('1024', Size(1024, 768)),
  ('1440', Size(1440, 900)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    _meta = await QuranRepo.meta();
    for (final f in ['DigitalKhattV2', 'UthmanicHafs']) {
      await QuranRepo.ayahs(2, 'uthmani', font: f);
      await QuranRepo.words(2, 'uthmani', font: f);
    }
    await QuranRepo.tajwid(2, 'uthmani');
    await MushafRepo.ensure('uthmani');
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Size size,
    Widget screen, {
    void Function(AppSettings)? tweak,
    String theme = 'light',
  }) async {
    useReducedMotion(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.appTheme = theme;
    s.desktopMode = size.width >= 1024 ? 'on' : 'off';
    tweak?.call(s);
    await tester.pumpWidget(
      SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            theme: buildTheme(s),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: screen,
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('largest Arabic', () {
    for (final (name, size, px) in [
      ('desktop 120px', const Size(1440, 900), kReaderMaxDesktop),
      // The desktop cap grows with the window: a sixth of its width.
      ('desktop max (240px)', const Size(1440, 900), readerMaxDesktopFor(1440)),
      ('big screen max (427px)', const Size(2560, 1440),
          readerMaxDesktopFor(2560)),
      ('phone 64px', const Size(360, 780), kReaderMaxMobile),
    ]) {
      for (final grid in [false, true]) {
        testWidgets('reader at $name${grid ? ' (word grid)' : ''}', (
          tester,
        ) async {
          await pumpScreen(
            tester,
            size,
            SurahReaderScreen(meta: _meta[1]),
            tweak: (s) {
              s.quranFontScale = px / kReaderBase;
              s.wordByWord = grid;
            },
          );
          await unmount(tester);
        });
      }
    }
  });

  for (final dock in ['pinned', 'floating', 'hidden']) {
    testWidgets('reader with the player $dock', (tester) async {
      await pumpScreen(
        tester,
        const Size(390, 844),
        SurahReaderScreen(meta: _meta[1]),
        tweak: (s) => s.playerDock = dock,
      );
      await unmount(tester);
    });
  }

  for (final (sizeName, size) in _sizes) {
    for (final theme in AppTheme.values) {
      for (final e in _screens.entries) {
        testWidgets('${e.key} · $sizeName · ${theme.name}', (tester) async {
          useReducedMotion(tester);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({});
          final s = AppSettings();
          final p = ProgressStore();
          await s.load();
          await p.load();
          s.onboarded = true;
          s.appTheme = theme.name;
          s.desktopMode = size.width >= 1024 ? 'on' : 'off';
          await tester.pumpWidget(
            SettingsScope(
              settings: s,
              child: ProgressScope(
                progress: p,
                child: MaterialApp(
                  theme: buildTheme(s),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  locale: const Locale('en'),
                  home: e.value(),
                ),
              ),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
