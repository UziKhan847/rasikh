import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/data/kids_sentences.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/quran.dart' show stripTashkil;

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _FakePathProvider(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Kids Mode verification, per the implementation plan's checklist:
///  * no network fonts (Kids Mode's display face is bundled, like every
///    other font in the app — see CREDITS.md)
///  * gems are earned only — no purchase entry point anywhere
///  * per-profile progress isolation, including through a backup round-trip
///  * the "Read the sentence" content is internally consistent
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('no network fonts', () {
    test('no source file references a web font host', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if (src.contains('fonts.googleapis.com') ||
            src.contains('fonts.gstatic.com')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Kids Mode\'s design links Google Fonts; this app bundles '
              'every face instead (see docs/privacy-policy.html and '
              'CREDITS.md). Offending files: $offenders');
    });

    test('the Kids Mode display face is bundled in pubspec.yaml, not fetched',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      // Static weight instances, not the upstream variable font — a
      // variable (gvar) font is a known trigger for Skia text-shaper hangs
      // on some Android GPU/driver combinations.
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ]) {
        expect(pubspec.contains('Baloo2-$weight.ttf'), isTrue,
            reason: 'pubspec.yaml is missing the Baloo2-$weight.ttf entry');
        expect(File('assets/fonts/Baloo2-$weight.ttf').existsSync(), isTrue,
            reason: 'assets/fonts/Baloo2-$weight.ttf is missing on disk');
      }
      expect(File('assets/fonts/Baloo2-Variable.ttf').existsSync(), isFalse,
          reason: 'the variable font should have been replaced, not kept '
              'alongside the static instances');
      expect(File('LICENSES/Baloo2-OFL.txt').existsSync(), isTrue);
    });
  });

  group('gems are earned only', () {
    test('buyShopItem only ever spends gems, never grants them', () {
      final prog = ProgressStore(profileId: 'p_test_gems');
      prog.awardGems(200);
      expect(prog.gems, 200);

      final bought = prog.buyShopItem('golden_frame', 150);
      expect(bought, isTrue);
      expect(prog.gems, 50);
      expect(prog.shopOwned.contains('golden_frame'), isTrue);

      // Insufficient balance: refused, no partial spend, no debt.
      final tooExpensive = prog.buyShopItem('emerald_frame', 250);
      expect(tooExpensive, isFalse);
      expect(prog.gems, 50);

      // Already owned: refused even with enough gems.
      prog.awardGems(1000);
      final again = prog.buyShopItem('golden_frame', 150);
      expect(again, isFalse);
    });

    test('no in-app-purchase / billing package is wired in', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('in_app_purchase'), isFalse);
      expect(pubspec.contains('billing'), isFalse);
    });
  });

  group('per-profile progress isolation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stars/xp/gems written under one profile are invisible to another',
        () async {
      final a = ProgressStore(profileId: 'sibling_a');
      await a.load();
      a.report('kids.letter.ب', 3);
      a.awardXp(30);
      a.awardGems(20);

      final b = ProgressStore(profileId: 'sibling_b');
      await b.load();
      expect(b.starsFor('kids.letter.ب'), 0);
      expect(b.xp, 0);
      expect(b.gems, 0);
      expect(b.kidsLettersLearned, 0);

      // Re-loading sibling_a's own store from disk still sees its data.
      final aReload = ProgressStore(profileId: 'sibling_a');
      await aReload.load();
      expect(aReload.starsFor('kids.letter.ب'), 3);
      expect(aReload.xp, 30);
      expect(aReload.gems, 20);
      expect(aReload.kidsLettersLearned, 1);
    });

    test('the adult store (no profileId) is unaffected by Kids Mode profiles',
        () async {
      final adult = ProgressStore();
      await adult.load();
      adult.report('letter.ب', 3);

      final kid = ProgressStore(profileId: 'sibling_a');
      await kid.load();
      expect(kid.starsFor('letter.ب'), 0);
      expect(kid.lettersLearned, 0); // adult-only getter, adult-prefixed id
    });
  });

  group('backup round-trip', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PathProviderPlatform.instance =
          _FakePathProvider(Directory.systemTemp.createTempSync().path);
    });

    test('BackupService.export includes every Kids Mode profile', () async {
      final settings = AppSettings();
      await settings.load();
      settings.addKidsProfile(KidsProfile(id: 'k1', name: 'Yusuf'));
      settings.addKidsProfile(KidsProfile(id: 'k2', name: 'Maryam'));

      final k1 = ProgressStore(profileId: 'k1');
      await k1.load();
      k1.awardXp(50);
      k1.awardGems(30);

      final path = await BackupService.export(settings);
      expect(path, isNotNull);
      final contents = File(path!).readAsStringSync();
      expect(contents.contains('"k1"'), isTrue);
      expect(contents.contains('"k2"'), isTrue);
    });
  });

  group('kids sentence content', () {
    test('every sentence\'s target word is a real substring of the sentence',
        () {
      for (final s in kidsSentences) {
        expect(s.sentence.contains(s.targetWord), isTrue,
            reason: 'letter ${s.letter}: "${s.targetWord}" is not found '
                'inside "${s.sentence}"');
        expect(s.gloss, isNotEmpty);
        expect(s.translit, isNotEmpty);
      }
    });

    test('every letter on the kids path has its OWN sentence, teaching it',
        () {
      // This used to accept whatever `sentenceForLetter` returned, because it
      // fell back to `kidsSentences.first` — so 16 of the 28 letters, Alif
      // included, silently taught بَيْتٌ (the بـ sentence) and the test passed.
      // The lookup is nullable now, and this asserts the real invariant: a
      // letter's sentence must actually contain that letter.
      for (final letter in kidsLetterPath) {
        final s = sentenceForLetter(letter.char);
        expect(s, isNotNull,
            reason: 'no sentence authored for ${letter.char} (${letter.name})');
        expect(s!.sentence.contains(s.targetWord), isTrue);
        // Hamza carriers normalise to a bare alif: أَحْمَدُ teaches ا just as
        // well as ٱلْبَابُ does.
        final bare = stripTashkil(s.targetWord)
            .replaceAll(RegExp('[أإآٱ]'), 'ا');
        expect(bare.contains(letter.char), isTrue,
            reason: 'letter ${letter.char}: target word "${s.targetWord}" '
                'does not contain it');
      }
    });

    test('kids sentences avoid U+0622 (alef with madda)', () {
      // The file header's stated constraint — none of this beginner
      // vocabulary needs it, and it keeps the set renderable everywhere.
      for (final s in kidsSentences) {
        expect(s.sentence.contains('آ'), isFalse,
            reason: 'letter ${s.letter}');
      }
    });

    test('kidsPraiseArabic covers boy/girl/neutral distinctly', () {
      expect(kidsPraiseArabic('m'), 'أَحْسَنْتَ!');
      expect(kidsPraiseArabic('f'), 'أَحْسَنْتِ!');
      expect(kidsPraiseArabic(''), isNot(anyOf('أَحْسَنْتَ!', 'أَحْسَنْتِ!')));
    });
  });

  group('kids letter path', () {
    test('reuses the same 28-letter data the rest of the app teaches', () {
      expect(kidsLetterPath, letters);
    });
  });

  group('palette sweep (the 14th Palette field)', () {
    test('every existing family x mode combination still resolves', () {
      for (final family in ['mint', 'noor']) {
        for (final mode in ['light', 'dark', 'oled']) {
          final p = paletteFor(family, mode);
          expect(p.amber, const Color(0xFFF4B23E),
              reason: '$family.$mode should keep the default amber');
        }
      }
    });

    test('every Kids Mode family x mode combination resolves distinctly', () {
      for (final mode in ['light', 'dark', 'oled']) {
        final p = paletteFor('kids', mode);
        expect(p.accent, const Color(0xFFEC6A4B));
        expect(p.accent2, const Color(0xFF1FA89B));
      }
      // light/dark/oled must actually differ from each other.
      final surfaces = {
        for (final mode in ['light', 'dark', 'oled'])
          mode: paletteFor('kids', mode).bg,
      };
      expect(surfaces.values.toSet(), hasLength(3));
    });

    test('an unknown combination still falls back instead of throwing', () {
      expect(paletteFor('kids', 'nonsense'), paletteFor('mint', 'light'));
    });
  });
}
