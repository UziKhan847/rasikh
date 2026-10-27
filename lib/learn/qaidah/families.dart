import '../../data/letters.dart';

/// The letters in the families they're taught in: those written with one
/// shape (a skeleton) together, so the dots are learnt by telling them
/// apart — and Alif first, alone, with what joining means. Every letter is
/// in exactly one family (see test/qaidah_course_test.dart).
class LetterFamily {
  final String id;
  final List<String> chars;
  const LetterFamily(this.id, this.chars);

  List<ArabicLetter> get letters => [for (final c in chars) letterFor(c)];

  /// Where this family's lesson keeps its stars.
  String get progressId => 'qaidah.fam.$id';
}

const letterFamilies = <LetterFamily>[
  LetterFamily('alif', ['ا']),
  LetterFamily('ba', ['ب', 'ت', 'ث', 'ن', 'ي']),
  LetterFamily('jim', ['ج', 'ح', 'خ']),
  LetterFamily('dal', ['د', 'ذ']),
  LetterFamily('ra', ['ر', 'ز']),
  LetterFamily('sin', ['س', 'ش']),
  LetterFamily('sad', ['ص', 'ض']),
  LetterFamily('ta', ['ط', 'ظ']),
  LetterFamily('ayn', ['ع', 'غ']),
  LetterFamily('fa', ['ف', 'ق']),
  LetterFamily('kaf', ['ك', 'ل']),
  LetterFamily('mim', ['م', 'ه', 'و']),
];

LetterFamily familyById(String id) => letterFamilies.firstWhere((f) => f.id == id);

/// The family [char] is taught in.
LetterFamily familyOf(String char) =>
    letterFamilies.firstWhere((f) => f.chars.contains(char));
