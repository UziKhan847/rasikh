import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/makharij.dart';
import 'package:qiraah_arabiyyah/data/script_diff.dart';
import 'package:qiraah_arabiyyah/data/sifat.dart';
import 'package:qiraah_arabiyyah/data/tajwid_cases.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';
import 'package:qiraah_arabiyyah/data/tanwin_forms.dart';
import 'package:qiraah_arabiyyah/data/waqf.dart';
import 'package:qiraah_arabiyyah/data/wasl.dart';

/// Data-integrity guards for the Tajwīd path (Rounds 6-9): waṣl, makhārij,
/// ṣifāt, special cases, waqf marks, and the Madani/Indo-Pak script
/// differences. Every corpus-sourced example must be a verbatim substring of
/// the bundled text — nothing here was hand-typed; every word was found by
/// scanning assets/quran/u/ (and assets/quran/i/ for the Indo-Pak side)
/// programmatically. The two authored datasets (makhārij, ṣifāt) can't be
/// pinned to the corpus, so they're pinned to internal consistency instead.
void main() {
  List<String> ayahsForU(int surah) => (jsonDecode(
          File('assets/quran/u/$surah.json').readAsStringSync()) as List)
      .cast<String>();
  List<String> ayahsForI(int surah) => (jsonDecode(
          File('assets/quran/i/$surah.json').readAsStringSync()) as List)
      .cast<String>();

  String ayahAtU(String ref) {
    final parts = ref.split(':');
    return ayahsForU(int.parse(parts[0]))[int.parse(parts[1]) - 1];
  }

  String ayahAtI(String ref) {
    final parts = ref.split(':');
    return ayahsForI(int.parse(parts[0]))[int.parse(parts[1]) - 1];
  }

  const core28 = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي';
  final func29 = '${String.fromCharCode(0x0621)}$core28';

  group('waslItems', () {
    test('every example is a verbatim substring of its Uthmani āyah', () {
      for (final w in waslItems) {
        final ayah = ayahAtU(w.ref);
        expect(ayah.contains(w.example), isTrue,
            reason: 'Wasl item "${w.id}" example is not verbatim in ${w.ref}.'
                '\n  example: ${w.example}\n  āyah: $ayah');
      }
    });

    test('every highlight is a substring of its own example', () {
      for (final w in waslItems) {
        expect(w.example.contains(w.highlight), isTrue,
            reason: 'Wasl item "${w.id}" highlight is not inside its example.');
      }
    });

    test('exactly 14 solar and 14 lunar letters, disjoint, matching the '
        'classical mnemonics', () {
      final solar = waslOfKind('solar').map((w) => w.letter).toSet();
      final lunar = waslOfKind('lunar').map((w) => w.letter).toSet();
      expect(solar.length, 14);
      expect(lunar.length, 14);
      expect(solar.intersection(lunar), isEmpty);
      expect(solar, 'تثدذرزسشصضطظلن'.split('').toSet());
      expect(lunar, 'ءبجحخعغفقكمهوي'.split('').toSet());
    });

    test('zero_rect examples carry U+06E0; zero_round examples carry U+0652', () {
      for (final w in waslOfKind('zero_rect')) {
        expect(w.example.contains('۠'), isTrue, reason: w.id);
      }
      for (final w in waslOfKind('zero_round')) {
        expect(w.example.contains('ْ'), isTrue, reason: w.id);
      }
    });

    test('the 76:15/76:16 contrast pair is present', () {
      final refs = waslItems.map((w) => w.ref).toSet();
      expect(refs.contains('76:15'), isTrue);
      expect(refs.contains('76:16'), isTrue);
    });
  });

  group('makharij', () {
    test('exactly 17 makhārij points', () {
      expect(makharij.length, 17);
    });

    test('makhrajOfLetter maps every core letter + hamzah, exactly once', () {
      expect(makhrajOfLetter.length, 29);
      expect(makhrajOfLetter.keys.toSet(), func29.split('').toSet());
    });

    test('every mapped id is a real makhraj', () {
      final ids = makharij.map((m) => m.id).toSet();
      for (final entry in makhrajOfLetter.entries) {
        expect(ids.contains(entry.value), isTrue,
            reason: '${entry.key} points at unknown makhraj ${entry.value}');
      }
    });

    test('makhrajZones (Round 12) has exactly the 5 classical zones, and '
        'every makhraj belongs to exactly one, none orphaned', () {
      expect(makhrajZones.map((z) => z.id).toSet(),
          {'jawf', 'halq', 'lisan', 'shafatan', 'khayshum'});
      final zoneIds = makhrajZones.map((z) => z.id).toSet();
      for (final m in makharij) {
        expect(zoneIds.contains(m.zone), isTrue, reason: m.id);
      }
      final total =
          makhrajZones.fold<int>(0, (n, z) => n + makharijOfZone(z.id).length);
      expect(total, makharij.length);
    });

    test('every point in the Tongue zone carries a sub-group (back/middle/'
        'edge/tip); every point outside it does not', () {
      const validGroups = {'back', 'middle', 'edge', 'tip'};
      for (final m in makharij) {
        if (m.zone == 'lisan') {
          expect(validGroups.contains(m.group), isTrue, reason: m.id);
        } else {
          expect(m.group, '', reason: m.id);
        }
      }
      expect(makharijOfZone('lisan').length, 10);
    });

    test('every makhraj has a non-empty how (2-3 sentences on producing the '
        'sound, distinct from the where-focused note)', () {
      for (final m in makharij) {
        expect(m.how, isNotEmpty, reason: m.id);
        expect(m.how, isNot(m.note), reason: m.id);
      }
    });
  });

  group('sifat', () {
    Set<String> lettersOf(String id) =>
        sifat.firstWhere((s) => s.id == id).letters.split('').toSet();

    test('the five opposed-pair axes partition the 29 letters', () {
      for (final pair in [
        ['hams', 'jahr'],
        ['istila', 'istifal'],
        ['itbaq', 'infitah'],
        ['idhlaq', 'ismat'],
      ]) {
        final a = lettersOf(pair[0]);
        final b = lettersOf(pair[1]);
        expect(a.intersection(b), isEmpty, reason: '${pair[0]}/${pair[1]}');
        expect(a.union(b), func29.split('').toSet(),
            reason: '${pair[0]}/${pair[1]} does not cover all 29 letters');
      }
      final sh = lettersOf('shidda');
      final ta = lettersOf('tawassut');
      final ra = lettersOf('rakhawa');
      expect(sh.intersection(ta), isEmpty);
      expect(sh.intersection(ra), isEmpty);
      expect(ta.intersection(ra), isEmpty);
      expect({...sh, ...ta, ...ra}, func29.split('').toSet());
    });

    test('iṭbāq is a subset of isti‘lā’', () {
      expect(lettersOf('itbaq').difference(lettersOf('istila')), isEmpty);
    });

    test('qalqalah ṣifah letters match the qalqalah rule; isti‘lā’ matches tafkhīm', () {
      final qalqalahRule = tajwidRules.firstWhere((r) => r.id == 'qalqalah');
      final tafkhimRule = tajwidRules.firstWhere((r) => r.id == 'tafkhim');
      expect(lettersOf('qalqalah_sifah'), qalqalahRule.letters.split('').toSet());
      expect(lettersOf('istila'), tafkhimRule.letters.split('').toSet());
    });

    test('every opposite id, where set, points at a real sifah', () {
      final ids = sifat.map((s) => s.id).toSet();
      for (final s in sifat) {
        if (s.opposite.isEmpty) continue;
        expect(ids.contains(s.opposite), isTrue, reason: s.id);
      }
    });
  });

  group('tajwidCases', () {
    test('every example is a verbatim substring of its Uthmani āyah', () {
      for (final c in tajwidCases) {
        final ayah = ayahAtU(c.ref);
        expect(ayah.contains(c.example), isTrue,
            reason: 'Case "${c.id}" example is not verbatim in ${c.ref}.');
      }
    });

    test('every highlight is a substring of its own example', () {
      for (final c in tajwidCases) {
        expect(c.example.contains(c.highlight), isTrue, reason: c.id);
      }
    });

    test('moreExamples are verbatim substrings of their own āyah, with a '
        'substring highlight', () {
      for (final c in tajwidCases) {
        for (final (text, ref, hl) in c.moreExamples) {
          expect(ayahAtU(ref).contains(text), isTrue,
              reason: 'Case "${c.id}" moreExample is not verbatim in $ref.');
          expect(text.contains(hl), isTrue, reason: c.id);
        }
      }
    });

    test('category counts match the codepoint census — several genuinely '
        'recurring cases (saktah, sīn/ṣād, al-ān) are ONE entry each with '
        'moreExamples, not near-duplicate entries', () {
      int total(String id) =>
          1 + tajwidCases.firstWhere((c) => c.id == id).moreExamples.length;
      expect(tajwidCases.where((c) => c.id == 'ishmam' || c.id == 'tashil').length, 2);
      expect(total('saktah'), 5);
      expect(total('sin_over_sad'), 3);
      expect(total('al_an'), 2);
      expect(tajwidCases.where((c) => c.id == 'imalah').length, 1);
      expect(tajwidCases.where((c) => c.id == 'single_nun').length, 1);
      expect(tajwidCases.length, 7);
      expect(tajwidCases.fold<int>(0, (n, c) => n + 1 + c.moreExamples.length), 14);
    });

    test('every ids is unique', () {
      final ids = tajwidCases.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('waqfMarks', () {
    test('every example is verbatim in the script(s) it claims', () {
      for (final m in waqfMarks) {
        final ayah = m.scripts == 'indopak' ? ayahAtI(m.ref) : ayahAtU(m.ref);
        expect(ayah.contains(m.example), isTrue,
            reason: 'Waqf mark "${m.id}" example is not verbatim (${m.scripts}) '
                'in ${m.ref}.\n  example: ${m.example}\n  āyah: $ayah');
      }
    });

    test('mamnū‘ (لا) is Indo-Pak only — absent from the bundled Madani corpus', () {
      final m = waqfMarkById('mamnu');
      expect(m.scripts, 'indopak');
    });

    test('sajdah has exactly 15 places in the Madani corpus', () {
      var count = 0;
      for (var s = 1; s <= 114; s++) {
        for (final a in ayahsForU(s)) {
          if (a.contains('۩')) count++;
        }
      }
      expect(count, 15);
    });
  });

  group('scriptDifferences', () {
    test('madaniWord/indopakWord are the full, exact āyah from each corpus', () {
      for (final d in scriptDifferences) {
        expect(d.madaniWord, ayahAtU(d.ref), reason: '${d.id} madani');
        expect(d.indopakWord, ayahAtI(d.ref), reason: '${d.id} indopak');
      }
    });

    test('76:15 vs 76:16 silent-alif contrast: Madani distinguishes the two '
        'marks, Indo-Pak collapses them to the same one', () {
      final u15 = ayahAtU('76:15');
      final u16 = ayahAtU('76:16');
      final i15 = ayahAtI('76:15');
      final i16 = ayahAtI('76:16');
      expect(u15.contains('۠'), isTrue);
      expect(u16.contains('ْ'), isTrue);
      expect(u16.contains('۠'), isFalse);
      expect(i15.contains('۠'), isTrue);
      expect(i16.contains('۠'), isTrue);
    });
  });

  group('tanwinForms (Round 12)', () {
    test('exactly the 3 writing-form cases fatḥatān alone has', () {
      expect(tanwinForms.map((f) => f.id).toSet(),
          {'with_alif', 'teh_marbuta', 'hamzah_alif'});
    });

    test('every example and moreExample is a verbatim substring of its '
        'Uthmani āyah, with a substring highlight', () {
      for (final f in tanwinForms) {
        final ayah = ayahAtU(f.ref);
        expect(ayah.contains(f.example), isTrue,
            reason: 'TanwinForm "${f.id}" example is not verbatim in ${f.ref}.'
                '\n  example: ${f.example}\n  āyah: $ayah');
        expect(f.example.contains(f.highlight), isTrue, reason: f.id);
        for (final (text, ref, hl) in f.moreExamples) {
          expect(ayahAtU(ref).contains(text), isTrue,
              reason: 'TanwinForm "${f.id}" moreExample is not verbatim in $ref.');
          expect(text.contains(hl), isTrue, reason: f.id);
        }
      }
    });

    test('waqfNote is set for all three — the on-stopping behaviour the '
        'user specifically asked to see', () {
      for (final f in tanwinForms) {
        expect(f.waqfNote, isNotEmpty, reason: f.id);
      }
    });

    test('tāʼ marbūṭah is the one case that does NOT become a two-count '
        'fatḥah on stopping', () {
      final tm = tanwinFormById('teh_marbuta');
      expect(tm.waqfNote.toLowerCase(), contains('silent'));
    });
  });
}
