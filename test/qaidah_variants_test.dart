import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/extra_letters.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/makharij.dart';
import 'package:qiraah_arabiyyah/data/muqattaat.dart';
import 'package:qiraah_arabiyyah/data/small_letters.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';
import 'package:qiraah_arabiyyah/data/tanwin_allographs.dart';
import 'package:qiraah_arabiyyah/data/variants.dart';

/// Data-integrity guards for the Round 2 Qaidah additions (letter variants,
/// tanwīn allographs, small letters, the extra alphabet characters, and the
/// ḥurūf muqaṭṭaʿāt) — mirrors the existing tashkeel/letters data tests.
/// Every example word must be a verbatim substring of the bundled Uthmani
/// corpus; nothing here was hand-typed, all of it was found by searching
/// assets/quran/u/ programmatically.
void main() {
  List<String> ayahsFor(int surah) => (jsonDecode(
          File('assets/quran/u/$surah.json').readAsStringSync()) as List)
      .cast<String>();

  String ayahAt(String ref) {
    final parts = ref.split(':');
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);
    return ayahsFor(surah)[ayah - 1];
  }

  group('letterVariants', () {
    test('every variant word is a verbatim substring of its Uthmani āyah', () {
      for (final v in letterVariants) {
        final ayah = ayahAt(v.ref);
        expect(ayah.split(' ').contains(v.word), isTrue,
            reason: 'Variant "${v.id}" word is not a verbatim word of '
                '${v.ref}.\n  word: ${v.word}\n  āyah: $ayah');
      }
    });

    test('every variant highlight is a substring of its own word', () {
      for (final v in letterVariants) {
        expect(v.word.contains(v.highlight), isTrue,
            reason: 'Variant "${v.id}" highlight is not inside its word.\n'
                '  highlight: ${v.highlight}\n  word: ${v.word}');
      }
    });

    test('every variant kind is one of the four documented categories', () {
      const kinds = {'positional', 'ligature', 'stacked', 'small'};
      for (final v in letterVariants) {
        expect(kinds.contains(v.kind), isTrue,
            reason: 'Variant "${v.id}" has an undocumented kind: ${v.kind}');
      }
    });

    test('every moreExamples entry is a verbatim substring of its āyah, with '
        'a substring highlight (Round 13)', () {
      for (final v in letterVariants) {
        for (final (word, ref, hl) in v.moreExamples) {
          final ayah = ayahAt(ref);
          expect(ayah.contains(word), isTrue,
              reason: 'Variant "${v.id}" moreExample is not verbatim in '
                  '$ref.\n  word: $word\n  āyah: $ayah');
          expect(word.contains(hl), isTrue,
              reason: 'Variant "${v.id}" moreExample highlight is not inside '
                  'its word.\n  highlight: $hl\n  word: $word');
        }
      }
    });

    test('every variant has a non-empty note — 13 are superseded by a '
        'hand-drawn shape in special_shapes.dart, the other 7 use it as '
        "their coming-soon row's summary until their own shape is drawn",
        () {
      for (final v in letterVariants) {
        expect(v.note, isNotEmpty, reason: 'Variant "${v.id}" has no note');
      }
    });

    test('variantById finds every id, and only real ids', () {
      for (final v in letterVariants) {
        expect(variantById(v.id).id, v.id);
      }
      expect(() => variantById('nope'), throwsStateError);
    });

    test('the lām-alif family (لا لأ لإ) are all kind ligature, letter '
        'length 2, and distinct', () {
      final ids = ['lam_alif.ligature', 'lam_alif.hamza_above', 'lam_alif.hamza_below'];
      final lettersSeen = <String>{};
      for (final id in ids) {
        final v = variantById(id);
        expect(v.kind, 'ligature', reason: id);
        expect(v.letter.length, 2, reason: id);
        lettersSeen.add(v.letter);
      }
      expect(lettersSeen.length, 3, reason: 'all three should be distinct shapes');
    });
  });

  group('tanwinAllographs', () {
    test('every example is a verbatim substring of its Uthmani āyah', () {
      for (final t in tanwinAllographs) {
        final ayah = ayahAt(t.ref);
        expect(ayah.split(' ').contains(t.example), isTrue,
            reason: 'Tanwīn allograph "${t.id}" example is not a verbatim '
                'word of ${t.ref}.\n  example: ${t.example}\n  āyah: $ayah');
      }
    });

    test('every highlight is a substring of its own example', () {
      for (final t in tanwinAllographs) {
        expect(t.example.contains(t.highlight), isTrue,
            reason: 'Tanwīn allograph "${t.id}" highlight is not inside its '
                'example.\n  highlight: ${t.highlight}\n  example: ${t.example}');
      }
    });

    test('ruleId matches a real tajweed.dart rule', () {
      final ids = tajwidRules.map((r) => r.id).toSet();
      for (final t in tanwinAllographs) {
        expect(ids.contains(t.ruleId), isTrue,
            reason:
                'Tanwīn allograph "${t.id}" points at an unknown rule: ${t.ruleId}');
      }
    });

    test('all three tanwīn are represented in all three forms', () {
      final byTanwin = <String, Set<String>>{};
      for (final t in tanwinAllographs) {
        byTanwin.putIfAbsent(t.tanwinId, () => {}).add(t.form);
      }
      for (final id in ['fathatan', 'dammatan', 'kasratan']) {
        expect(byTanwin[id], {'parallel', 'alternate', 'iqlab'},
            reason: '$id is missing one of its three forms');
      }
    });

    test('parallel forms signal iẓhār; alternate forms never do', () {
      // The correlation the whole file is built on: this is what makes the
      // shape distinction teachable rather than decorative.
      for (final t in tanwinAllographs) {
        if (t.form == 'parallel') {
          expect(t.ruleId, 'izhar', reason: '${t.id} should be iẓhār');
        } else if (t.form == 'alternate') {
          expect(t.ruleId, isNot('izhar'),
              reason: '${t.id} (alternate shape) must not be iẓhār');
        } else if (t.form == 'iqlab') {
          expect(t.ruleId, 'iqlab', reason: '${t.id} should be iqlāb');
        }
      }
    });
  });

  group('smallLetters', () {
    test('every example is a verbatim substring of its Uthmani āyah', () {
      for (final s in smallLetters) {
        final ayah = ayahAt(s.ref);
        expect(ayah.split(' ').contains(s.example), isTrue,
            reason: 'Small letter "${s.id}" example is not a verbatim word '
                'of ${s.ref}.\n  example: ${s.example}\n  āyah: $ayah');
      }
    });

    test('every highlight is a substring of its own example', () {
      for (final s in smallLetters) {
        expect(s.example.contains(s.highlight), isTrue,
            reason: 'Small letter "${s.id}" highlight is not inside its '
                'example.\n  highlight: ${s.highlight}\n  example: ${s.example}');
      }
    });
  });

  group('extraLetters', () {
    test('every exampleWord is a verbatim substring of its Uthmani āyah', () {
      for (final l in extraLetters) {
        final ayah = ayahAt(l.exampleRef);
        expect(ayah.split(' ').contains(l.exampleWord), isTrue,
            reason: 'Extra letter "${l.char}" exampleWord is not a verbatim '
                'word of ${l.exampleRef}.\n  word: ${l.exampleWord}\n  āyah: $ayah');
      }
    });

    test('letterForAny finds both the core 28 and the extras', () {
      expect(letterForAny('ب')?.char, 'ب');
      expect(letterForAny('ء')?.char, 'ء');
      expect(letterForAny('ٱ')?.char, 'ٱ');
      expect(letterForAny('X'), isNull);
    });

    test('extraLetters is disjoint from the core 28 (no duplicate chars)', () {
      final core = letters.map((l) => l.char).toSet();
      for (final l in extraLetters) {
        expect(core.contains(l.char), isFalse,
            reason: '${l.char} is in both letters and extraLetters');
      }
    });

    test('U+0622 (Imlāʾī ALEF WITH MADDA) is not among the extra letters', () {
      for (final l in extraLetters) {
        expect(l.char.codeUnitAt(0), isNot(0x0622),
            reason: 'U+0622 has zero occurrences in the Uthmani corpus and '
                'should stay decomposed, not modelled as its own letter');
      }
    });

    test('extraLetterMoreExamples: every entry is a verbatim substring of '
        'its āyah, with a substring highlight (Round 12)', () {
      for (final l in extraLetters) {
        final more = extraLetterMoreExamples[l.char] ?? const [];
        expect(more, isNotEmpty, reason: '${l.char} has no moreExamples');
        for (final (word, ref, hl) in more) {
          final ayah = ayahAt(ref);
          expect(ayah.contains(word), isTrue,
              reason: 'Extra letter "${l.char}" moreExample is not verbatim '
                  'in $ref.\n  word: $word\n  āyah: $ayah');
          expect(word.contains(hl), isTrue, reason: l.char);
        }
      }
    });

    test('makhrajOfExtraLetter maps exactly the 8 extra letters, each to a '
        'real makhraj id', () {
      final ids = makharij.map((m) => m.id).toSet();
      expect(makhrajOfExtraLetter.keys.toSet(),
          extraLetters.map((l) => l.char).toSet());
      for (final entry in makhrajOfExtraLetter.entries) {
        expect(ids.contains(entry.value), isTrue,
            reason: '${entry.key} points at unknown makhraj ${entry.value}');
      }
    });

    test('extraLetterNotes covers exactly the 8 extra letters', () {
      expect(extraLetterNotes.keys.toSet(),
          extraLetters.map((l) => l.char).toSet());
    });
  });

  group('muqattaatSets', () {
    test('every set has exactly 14 entries', () {
      expect(muqattaatSets.length, 14);
    });

    test('together they use exactly the 14 classical letters', () {
      final used = <String>{};
      for (final m in muqattaatSets) {
        used.addAll(m.letters.split(''));
      }
      expect(used, 'احرسصطعقكلمنهي'.split('').toSet());
    });

    test('every set opens every sūrah it claims', () {
      for (final m in muqattaatSets) {
        for (final s in m.surahs) {
          final first = ayahsFor(s).first;
          expect(first.contains(m.display), isTrue,
              reason: 'Muqaṭṭaʿāt set "${m.id}" claims sūrah $s but its '
                  'display text is not in that sūrah\'s first āyah.\n'
                  '  display: ${m.display}\n  1st āyah: $first');
        }
      }
    });

    test('the surah-42 set spans both of its āyāt verbatim', () {
      final m = muqattaatSets.firstWhere((m) => m.ref == '42:1-2');
      final parts = m.example.split(' | ');
      expect(parts.length, 2);
      final ay = ayahsFor(42);
      expect(parts[0], ay[0]);
      expect(parts[1], ay[1]);
    });

    test('every muqattaatCounts key is one of the 14 letters used', () {
      final used = muqattaatSets.expand((m) => m.letters.split('')).toSet();
      expect(muqattaatCounts.keys.toSet(), used);
    });
  });
}
