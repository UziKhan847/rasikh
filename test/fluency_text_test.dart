import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/fluency/chunks.dart';
import 'package:rasikh/core/fluency/joins.dart';
import 'package:rasikh/core/fluency/madd.dart';

/// The fluency marks' text work: how two words join, and where a word's
/// prefix and suffix come off.
void main() {
  test('joins', () {
    expect(joinOf('رَبِّ', 'ٱلْعَٰلَمِينَ'), 'wasl');
    expect(joinOf('هُدًى', 'لِّلْمُتَّقِينَ'), 'idgham');
    expect(joinOf('مِن', 'رَّبِّهِمْ'), 'idgham');
    expect(joinOf('مِنۢ', 'بَعْدِ'), 'iqlab');
    expect(joinOf('مِن', 'قَبْلِكَ'), 'ikhfa');
    expect(joinOf('عَذَابٌ', 'أَلِيمٌ'), 'join');
    expect(joinOf('لَهُمْ', 'مَّا'), 'idgham');
    // Indo-Pak: a bare alif before the lām.
    expect(joinOf('رَبِّ', 'الْعٰلَمِيْنَ'), 'wasl');
  });

  test('prefixes and suffixes', () {
    String shown(String w) {
      final (p, s) = suggestSplit(w);
      final (a, b, c) = splitText(w, p, s);
      return '$a|$b|$c';
    }

    expect(shown('وَقَالَ'), 'وَ|قَالَ|');
    expect(shown('فَقَالَ'), 'فَ|قَالَ|');
    expect(shown('بِٱللَّهِ'), 'بِ|ٱللَّهِ|');
    expect(shown('ٱلْكِتَٰبِ'), 'ٱلْ|كِتَٰبِ|');
    expect(shown('رَبُّهُمْ'), '|رَبُّ|هُمْ');
    expect(shown('رَبُّكُمْ'), '|رَبُّ|كُمْ');
    expect(shown('رَبَّنَا'), '|رَبَّ|نَا');
    expect(shown('سَيَعْلَمُونَ'), 'سَ|يَعْلَمُونَ|');
    // Left whole.
    expect(shown('فِيهَا'), '|فِيهَا|');
    expect(shown('ٱللَّهِ'), '|ٱللَّهِ|');
    expect(shown('وَجَدَ'), '|وَجَدَ|');
    expect(shown('كَانَ'), '|كَانَ|');
  });

  test('madd counts', () {
    String first(String w) => maddsIn(w).map((m) => m.counts).join(',');
    expect(first('ٱلضَّآلِّينَ'), startsWith('6'));
    expect(first('جَآءَ'), startsWith('4–5'));
    expect(first('قَالَ'), '2');
    expect(first('يَقُولُ'), '2');
    expect(first('فِيهَا'), '2,2');
  });
}
