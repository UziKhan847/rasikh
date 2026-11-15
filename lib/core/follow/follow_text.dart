import 'dart:typed_data';

/// The text that following a recitation compares: the muṣḥaf's words and the
/// model's transcripts, both brought down to the bare letters of the rasm.
///
/// Pure Dart (no Flutter, no FFI): it runs in the worker isolate and in tests.
abstract final class FollowText {
  /// Ḥarakāt, tanwīn, shaddah, sukūn, the dagger alif, the small high and
  /// low Quranic marks, waqf signs, tatweel and the extended mark block.
  static final RegExp _marks =
      RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ࣓-ࣿ]');

  /// Letter shapes folded to the model's 28 letters (its vocabulary has no
  /// ة, ى or hamza seats; a lone ء is dropped on both sides, as the model
  /// writes it only sometimes).
  static const Map<int, int> _fold = {
    0x0671: 0x0627, // ٱ
    0x0623: 0x0627, // أ
    0x0625: 0x0627, // إ
    0x0622: 0x0627, // آ
    0x0672: 0x0627, // ٲ
    0x0673: 0x0627, // ٳ
    0x0649: 0x064A, // ى
    0x0626: 0x064A, // ئ
    0x06CC: 0x064A, // ی
    0x0624: 0x0648, // ؤ
    0x0629: 0x0647, // ة
    0x06A9: 0x0643, // ک
  };

  /// Word separators: spaces, the model's ▁, a CTC |, and the muṣḥaf
  /// text's zero-width non-joiner.
  static final RegExp _separators = RegExp('[\\s▁|‌]+');

  /// [w]'s bare letters (ا…ي, no ء).
  static String word(String w) {
    final s = w.replaceAll(_marks, '');
    final out = StringBuffer();
    for (final r in s.runes) {
      final c = _fold[r] ?? r;
      // Only the basic letters, without the lone hamza.
      if (c >= 0x0627 && c <= 0x064A && !(c > 0x063A && c < 0x0641)) {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  /// [text] split into bare words, dropping what's left empty (waqf signs,
  /// āyah numbers, stray marks).
  static List<String> words(String text) => [
        for (final w in text.split(_separators))
          if (word(w) case final b when b.isNotEmpty) b,
      ];
}

/// Edit distance, reusing its two rows (they only grow).
class WordDistance {
  Int32List _prev = Int32List(32), _cur = Int32List(32);

  int levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    if (_prev.length <= n) {
      _prev = Int32List(n + 16);
      _cur = Int32List(n + 16);
    }
    var prev = _prev, cur = _cur;
    for (var j = 0; j <= n; j++) {
      prev[j] = j;
    }
    for (var i = 1; i <= m; i++) {
      cur[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= n; j++) {
        final del = prev[j] + 1, ins = cur[j - 1] + 1;
        final sub = prev[j - 1] + (ca == b.codeUnitAt(j - 1) ? 0 : 1);
        cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[n];
  }

  /// 1 for the same word, 0 for nothing in common.
  double similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final longest = a.length > b.length ? a.length : b.length;
    return 1 - levenshtein(a, b) / longest;
  }

  /// For a word still being said: [heard] against as much of [expected] as
  /// has been heard (discounted a little), or the whole, whichever is closer.
  double partial(String heard, String expected) {
    final full = similarity(heard, expected);
    if (heard.length < 2 || heard.length >= expected.length) return full;
    final prefix = similarity(heard, expected.substring(0, heard.length)) * .9;
    return prefix > full ? prefix : full;
  }
}
