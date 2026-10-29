/// How two words of the muṣḥaf join when read without a stop — the joins
/// the fluency plan's pair practice drills: hamzat al-waṣl, idghām, iqlāb,
/// ikhfāʾ (and their mīm sākinah forms), else a plain join. From the text
/// as printed (both scripts), not a tajwīd engine.
library;

/// One letter of a word: its base and the marks on it.
typedef Cluster = ({String base, String marks});

const _fatha = 'َ', _damma = 'ُ', _kasra = 'ِ';
const _shadda = 'ّ', _sukun = 'ْ';
const _tanwin = {'ً', 'ٌ', 'ٍ', 'ࣰ', 'ࣱ', 'ࣲ'};

/// Is [c] a mark (a vowel, a sign, a small letter) rather than a letter?
bool isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED) ||
    (c >= 0x0897 && c <= 0x089F) ||
    (c >= 0x08D3 && c <= 0x08FF) ||
    c == 0x034F ||
    c == 0x200C;

/// [word]'s letters, each with its marks.
List<Cluster> clustersOf(String word) {
  final out = <Cluster>[];
  final runes = word.runes.toList();
  var i = 0;
  // Marks before any letter (shouldn't happen) go with the first.
  final lead = StringBuffer();
  while (i < runes.length && isMark(runes[i])) {
    lead.writeCharCode(runes[i++]);
  }
  while (i < runes.length) {
    final base = String.fromCharCode(runes[i++]);
    final m = StringBuffer(lead);
    lead.clear();
    while (i < runes.length && isMark(runes[i])) {
      m.writeCharCode(runes[i++]);
    }
    out.add((base: base, marks: m.toString()));
  }
  return out;
}

/// [word] without its marks.
String skeletonOf(String word) =>
    String.fromCharCodes(word.runes.where((c) => !isMark(c)));

bool _hasVowel(String marks) =>
    marks.contains(_fatha) || marks.contains(_damma) || marks.contains(_kasra) ||
    _tanwin.any(marks.contains);

/// The join from [a] to [b] (the word after it).
String joinOf(String a, String b) {
  final ca = clustersOf(a), cb = clustersOf(b);
  if (ca.isEmpty || cb.isEmpty) return 'join';
  final first = cb.first;
  // ٱ, or (Indo-Pak) a bare alif before lām: its hamzah is dropped.
  if (first.base == 'ٱ' ||
      (first.base == 'ا' && !_hasVowel(first.marks) && cb.length > 1 && cb[1].base == 'ل')) {
    return 'wasl';
  }
  // The last letter that's sounded: a bare final alif or yāʼ after a
  // tanwīn (its seat, هُدًى) carries nothing.
  var last = ca.last;
  if (ca.length > 1 &&
      'اى'.contains(last.base) &&
      !_hasVowel(last.marks) &&
      _tanwin.any(ca[ca.length - 2].marks.contains)) {
    last = ca[ca.length - 2];
  }
  final nextLetter = first.base;
  final tanwin = _tanwin.any(last.marks.contains);
  final nunSakin = last.base == 'ن' &&
      !last.marks.contains(_shadda) &&
      (last.marks.contains(_sukun) || !_hasVowel(last.marks));
  if (tanwin || nunSakin) {
    if ('يرملون'.contains(nextLetter)) return 'idgham';
    if (nextLetter == 'ب') return 'iqlab';
    if ('تثجدذزسشصضطظفقك'.contains(nextLetter)) return 'ikhfa';
    return 'join';
  }
  final mimSakin = last.base == 'م' &&
      !last.marks.contains(_shadda) &&
      (last.marks.contains(_sukun) || !_hasVowel(last.marks));
  if (mimSakin) {
    if (nextLetter == 'م') return 'idgham';
    if (nextLetter == 'ب') return 'ikhfa';
  }
  return 'join';
}
