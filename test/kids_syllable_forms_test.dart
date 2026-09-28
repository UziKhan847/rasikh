import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';

/// [kidsSyllableForms] is what fixed the drill: sukūn and shaddah used to
/// print an unsayable bare glyph (`بۡ`, `بّ`) and claim it sounded like `b` /
/// `bb`. A form must be something a child can actually say, so every form
/// here is checked against the SAME corpus convention the real muṣḥaf uses
/// (`assets/quran/u/*.json`): a mushaddad letter is written shaddah-then-
/// vowel, and its own sukūn glyph is U+06E1, not the plain Arabic sukūn
/// U+0652.
void main() {
  final ba = letters.firstWhere((l) => l.char == 'ب');
  final tha = letters.firstWhere((l) => l.char == 'ث'); // multi-letter translit
  TashkilItem mark(String id) => tashkil.firstWhere((t) => t.id == id);

  group('vowels and tanwīn keep their single form', () {
    for (final id in [
      'fatha',
      'kasra',
      'damma',
      'fathatan',
      'kasratan',
      'dammatan',
    ]) {
      test(id, () {
        final forms = kidsSyllableForms(ba, mark(id));
        expect(forms, hasLength(1));
        expect(forms.single.arabic, '${ba.char}${mark(id).mark.substring(1)}');
        expect(
          forms.single.sound,
          '${ba.translit}${mark(id).sound.substring(1)}',
        );
      });
    }
  });

  group('sukūn', () {
    late List<KidsForm> forms;
    setUp(() => forms = kidsSyllableForms(ba, mark('sukun')));

    test('three forms — one per carrier vowel', () {
      expect(forms, hasLength(3));
      expect(forms.map((f) => f.sound), ['ab', 'ib', 'ub']);
    });

    test('every form ends the drilled letter with the sukūn glyph', () {
      for (final f in forms) {
        expect(f.arabic, endsWith('${ba.char}ۡ'));
      }
    });

    test(
      'never the plain Arabic sukūn — it would silently mismatch the corpus',
      () {
        for (final f in forms) {
          expect(f.arabic.contains('ْ'), isFalse, reason: f.arabic);
        }
      },
    );

    test('the letter itself carries no vowel — it is sākin in all three', () {
      for (final f in forms) {
        // Exactly one vowel/tanwīn mark in the whole string: the carrier's.
        final marks = f.arabic.runes.where((r) => r >= 0x064B && r <= 0x0652);
        expect(marks.length, 1, reason: f.arabic);
      }
    });

    test('a multi-letter translit (ث → th) still composes cleanly', () {
      final thaForms = kidsSyllableForms(tha, mark('sukun'));
      expect(thaForms.map((f) => f.sound), ['ath', 'ith', 'uth']);
    });
  });

  group('shaddah', () {
    late List<KidsForm> forms;
    setUp(() => forms = kidsSyllableForms(ba, mark('shadda')));

    test('six forms — the three ḥarakāt and the three tanwīn', () {
      expect(forms, hasLength(6));
      expect(forms.map((f) => f.sound), [
        'abba',
        'abbi',
        'abbu',
        'abban',
        'abbin',
        'abbun',
      ]);
    });

    test(
      'every form doubles the letter — the "two letters" of one shaddah',
      () {
        for (final f in forms) {
          expect(f.sound, startsWith('a'));
          expect(f.sound.contains('${ba.translit}${ba.translit}'), isTrue);
        }
      },
    );

    test('shaddah is written BEFORE the vowel, matching the bundled corpus '
        '(ذَرَّةٍ → ر + shaddah + fatḥah)', () {
      for (final f in forms) {
        final shaddaAt = f.arabic.runes.toList().indexOf(0x0651);
        expect(shaddaAt, greaterThan(-1), reason: f.arabic);
        final after = f.arabic.runes.elementAt(shaddaAt + 1);
        expect(
          {0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650}.contains(after),
          isTrue,
          reason: '${f.arabic}: nothing vowel-like follows the shaddah',
        );
      }
    });

    test('a multi-letter translit (ث → th) still composes cleanly', () {
      final thaForms = kidsSyllableForms(tha, mark('shadda'));
      expect(thaForms.map((f) => f.sound), [
        'aththa',
        'aththi',
        'aththu',
        'aththan',
        'aththin',
        'aththun',
      ]);
    });
  });

  test('kidsSyllableSound answers with the FIRST form, for every mark', () {
    for (final t in tashkil) {
      if (kidsSyllableForms(ba, t).isEmpty) continue;
      expect(kidsSyllableSound(ba, t), kidsSyllableForms(ba, t).first.sound);
    }
  });

  test('no mark composes an empty or blank form', () {
    for (final t in tashkil) {
      for (final f in kidsSyllableForms(ba, t)) {
        expect(f.arabic.trim(), isNotEmpty, reason: t.id);
        expect(f.sound.trim(), isNotEmpty, reason: t.id);
      }
    }
  });
}
