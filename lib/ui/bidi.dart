import 'package:flutter/widgets.dart';

/// Arabic in a line of another language (a comment, a note): each Arabic
/// phrase is set apart (a Unicode isolate), so it reads right to left in its
/// place while the numbers, spaces and punctuation around it stay with the
/// sentence — not drawn into the phrase and moved to its far side.

const _arabic = '؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿';

/// An Arabic phrase: Arabic words with only spaces between them.
final _phrase = RegExp('[$_arabic]+(?:[  ]+[$_arabic]+)*');
final _strong = RegExp('[$_arabic]|[A-Za-zÀ-ɏ]');

/// [s] with each Arabic phrase isolated (right to left, as one piece). A
/// text all Arabic, or none, is left as it is.
String isolateArabic(String s) {
  if (!_phrase.hasMatch(s)) return s;
  final bare = s.replaceAll(_phrase, '');
  if (!_strong.hasMatch(bare)) return s; // only Arabic: nothing to keep apart
  return s.replaceAllMapped(_phrase, (m) => '\u2067${m[0]}\u2069');
}

/// The direction [s] reads in: its first letter's (Arabic → right to left,
/// Latin → left to right); null when it has neither.
TextDirection? directionOf(String s) {
  final m = _strong.firstMatch(s);
  if (m == null) return null;
  return RegExp('[$_arabic]').hasMatch(m[0]!) ? TextDirection.rtl : TextDirection.ltr;
}

/// A comment as text: its own direction, its Arabic phrases inline.
class CommentText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  const CommentText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) => Text(
        isolateArabic(text),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: directionOf(text),
      );
}
