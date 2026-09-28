import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_reading_screen.dart';

import 'kids_test_support.dart';

/// The reading ladder: az-Zalzalah (99) to an-Nās (114), one stage each.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the data', () {
    test('sixteen sūrahs, 99 to 114, in muṣḥaf order', () {
      expect(kidsReadingSurahs.map((s) => s.n), [
        for (var n = 99; n <= 114; n++) n,
      ]);
    });

    test('every name is the one in the bundled sūrah list', () {
      final meta =
          jsonDecode(File('assets/quran/meta.json').readAsStringSync()) as List;
      String plain(String t) => t
          .toLowerCase()
          .replaceAll('ʿ', "'")
          .replaceAll(RegExp('[āĀ]'), 'a')
          .replaceAll(RegExp('[īĪ]'), 'i')
          .replaceAll(RegExp('[ūŪ]'), 'u')
          .replaceAll('ṣ', 's');
      for (final s in kidsReadingSurahs) {
        final m = meta[s.n - 1] as Map<String, dynamic>;
        expect(m['n'], s.n);
        expect(s.arabic, m['name'], reason: 'sūrah ${s.n}');
        expect(
          plain(s.translit),
          plain(m['tname'] as String),
          reason: 'sūrah ${s.n}',
        );
      }
    });

    test('the lines get longer to shorter: 3-word lines, then whole āyāt', () {
      // Only ever one switch: a run of three-word stages, and later ones whole.
      final modes = kidsReadingSurahs.map((s) => s.wordsPerChunk).toList();
      expect(modes.toSet(), {0, 3});
      expect(modes.first, 3, reason: 'it opens with the easier chunks');
      expect(modes.last, 0, reason: 'and ends on whole āyāt');
    });

    test('al-Ikhlāṣ keeps the id it had as the one closing sūrah', () {
      expect(kidsReadingProgressId(112), 'kids.capstone.read');
      expect(kidsReadingProgressId(99), 'kids.read.99.read');
      final ids = {
        for (final s in kidsReadingSurahs) kidsReadingProgressId(s.n),
      };
      expect(ids, hasLength(16), reason: 'one progress id per sūrah');
    });

    test(
      'titles: Arabic for an Arabic or Urdu reader, else transliterated',
      () {
        // (Exercised through a widget below; the mapping itself is one line.)
        expect(kidsReadingSurahs.first.translit, 'Az-Zalzalah');
        expect(kidsReadingSurahs.last.arabic, 'الناس');
      },
    );

    test(
      'every ladder sūrah is offered to Find it, Build the word, Listen',
      () {
        for (final s in kidsReadingSurahs) {
          expect(kidsFindSurahs, contains(s.n), reason: 'sūrah ${s.n}');
        }
      },
    );
  });

  group('the stages', () {
    testWidgets('each opens its own sūrah, in its own chunking', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final path = kidsPath(ctx);
      for (final s in kidsReadingSurahs) {
        final block = path.firstWhere(
          (b) => b.id == (s.n == 112 ? 'capstone' : 'read.${s.n}'),
        );
        expect(block.title(ctx), s.translit);
        expect(block.badge, hasLength('${s.n}'.length));
        final item = block.items(ctx).single;
        expect(item.id, kidsReadingProgressId(s.n));
        final screen = item.open(ctx) as KidsReadingScreen;
        expect(screen.surah, s.n);
        expect(screen.wordsPerChunk, s.wordsPerChunk);
        expect(screen.wholeAyahs, s.wordsPerChunk == 0);
        expect(screen.progressId, item.id);
        expect(
          block.subtitle(ctx),
          s.wordsPerChunk == 0
              ? 'Read it, āyah by āyah'
              : 'Read it three words at a time',
        );
      }
    });

    testWidgets('an Arabic reader sees the sūrah names in Arabic', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final path = kidsPath(ctx);
      expect(path.firstWhere((b) => b.id == 'read.99').title(ctx), 'الزلزلة');
      expect(path.firstWhere((b) => b.id == 'read.114').title(ctx), 'الناس');
    });

    // Every sūrah of the ladder can actually be read to the end: its text is
    // in the bundle and the stage reports done when the last line is read.
    for (final s in kidsReadingSurahs) {
      testWidgets('sūrah ${s.n} reads through to a finished stage', (
        tester,
      ) async {
        useReducedMotion(tester);
        final (settings, prog) = await _boot();
        await tester.runAsync(() => QuranRepo.words(s.n, 'uthmani'));
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsReadingScreen(
              surah: s.n,
              wordsPerChunk: s.wordsPerChunk,
              wholeAyahs: s.wordsPerChunk == 0,
              progressId: kidsReadingProgressId(s.n),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final ayahs = await tester.runAsync(
          () => QuranRepo.words(s.n, 'uthmani'),
        );
        var lines = 0;
        for (final a in ayahs!) {
          lines += s.wordsPerChunk == 0
              ? 1
              : (a.length / s.wordsPerChunk).ceil();
        }
        expect(find.text('0 / $lines'), findsOneWidget);
        for (var i = 0; i < lines; i++) {
          await tester.tap(kidsIcon('arrow_forward', Icons.arrow_forward_rounded).first);
          await tester.pumpAndSettle();
        }
        expect(prog.starsFor(kidsReadingProgressId(s.n)), 3);
      });
    }
  });

  group('the badges', () {
    test('the first sūrah read earns "Read a Sūrah", whichever it is', () {
      final prog = ProgressStore(profileId: 'p_badge_a');
      expect(kidsSurahsRead(prog), 0);
      prog.report(kidsReadingProgressId(99), 3);
      expect(kidsSurahsRead(prog), 1);
      kidsSyncBadges(prog);
      expect(prog.badges, contains('read_a_surah'));
      expect(prog.badges, isNot(contains('read_five_surahs')));
    });

    test('five, ten and all sixteen', () {
      final prog = ProgressStore(profileId: 'p_badge_b');
      for (final s in kidsReadingSurahs.take(5)) {
        prog.report(kidsReadingProgressId(s.n), 3);
      }
      kidsSyncBadges(prog);
      expect(prog.badges, contains('read_five_surahs'));
      expect(prog.badges, isNot(contains('read_ten_surahs')));
      for (final s in kidsReadingSurahs.take(10)) {
        prog.report(kidsReadingProgressId(s.n), 3);
      }
      kidsSyncBadges(prog);
      expect(prog.badges, contains('read_ten_surahs'));
      expect(prog.badges, isNot(contains('read_all_surahs')));
      for (final s in kidsReadingSurahs) {
        prog.report(kidsReadingProgressId(s.n), 3);
      }
      kidsSyncBadges(prog);
      expect(prog.badges, contains('read_all_surahs'));
    });

    test('the old capstone progress still counts as a sūrah read', () {
      final prog = ProgressStore(profileId: 'p_badge_c');
      prog.report(
        'kids.capstone.read',
        3,
      ); // recorded before the ladder existed
      expect(kidsSurahsRead(prog), 1);
      kidsSyncBadges(prog);
      expect(prog.badges, contains('read_a_surah'));
    });
  });
}
