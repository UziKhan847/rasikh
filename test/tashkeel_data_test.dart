import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';

/// Every tashkīl example must be built entirely from the bundled Uthmani
/// text — [TashkilItem.example] a verbatim substring of
/// `assets/quran/u/{s}.json` at [TashkilItem.ref], and [TashkilItem.highlight]
/// a verbatim substring of that example. This pins down a real bug: the
/// original data used plain (Imlāʾī) orthography that never matched the
/// Uthmani script the rest of the app renders, and one highlight spanned a
/// word boundary, lighting up two disconnected regions at once.
void main() {
  test('every tashkīl example is a verbatim substring of its Uthmani āyah', () {
    for (final item in tashkil) {
      final parts = item.ref.split(':');
      final surah = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      final ayah = ayahs[ayahNum - 1];
      expect(ayah.contains(item.example), isTrue,
          reason: 'Mark "${item.id}" example (${item.ref}) is not a '
              'substring of the bundled Uthmani āyah.\n  example: ${item.example}\n'
              '  āyah:    $ayah');
    }
  });

  test('every tashkīl highlight is a substring of its own example', () {
    for (final item in tashkil) {
      expect(item.example.contains(item.highlight), isTrue,
          reason: 'Mark "${item.id}" highlight is not inside its example.\n'
              '  highlight: ${item.highlight}\n  example:   ${item.example}');
    }
  });

  test('no highlight spans a word boundary (a space)', () {
    // A highlight containing a literal space would light up two
    // disconnected regions when rendered — the exact "multiple things
    // highlighted" bug this data was fixed for.
    for (final item in tashkil) {
      expect(item.highlight.contains(' '), isFalse,
          reason: 'Mark "${item.id}" highlight spans a word boundary: '
              '${item.highlight}');
    }
  });
}
