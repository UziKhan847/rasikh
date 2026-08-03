import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';

/// Every example verse must be built entirely from the bundled Uthmani text —
/// [VerseExample.plain] is the exact substring of `assets/quran/u/{s}.json`
/// at [VerseExample.ref], not a hand-retyped/simplified transcription. This
/// pins down a real bug: the original data used plain (Imlāʾī) orthography
/// that never matched the Uthmani script the rest of the app renders.
void main() {
  test('every tajwīd example is a verbatim substring of its Uthmani āyah', () {
    for (final rule in tajwidRules) {
      final ref = rule.example.ref;
      final parts = ref.split(':');
      final surah = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      final ayah = ayahs[ayahNum - 1];
      expect(ayah.contains(rule.example.plain), isTrue,
          reason: 'Rule "${rule.id}" example ($ref) is not a substring of '
              'the bundled Uthmani āyah.\n  example: ${rule.example.plain}\n'
              '  āyah:    $ayah');
    }
  });
}
