import 'divisions_data.dart';
import 'mushaf.dart';

/// What a printed muṣḥaf page carries around its text: the Madani
/// muṣḥaf's juzʼ names and ḥizb-quarter lanterns, the Indo-Pak muṣḥaf's
/// para names, rukūʿ marks and manzil.

/// The Madani running head's juzʼ: «الجزء الأول» … «الجزء الثلاثون».
String madaniJuzName(int juz) {
  const ones = [
    '', 'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع',
    'الثامن', 'التاسع', 'العاشر',
  ];
  const tens = ['', 'الحادي', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
    'السادس', 'السابع', 'الثامن', 'التاسع'];
  final String n;
  if (juz <= 10) {
    n = ones[juz];
  } else if (juz < 20) {
    n = '${tens[juz - 10]} عشر';
  } else if (juz == 20) {
    n = 'العشرون';
  } else if (juz < 30) {
    n = '${tens[juz - 20]} والعشرون';
  } else {
    n = 'الثلاثون';
  }
  return 'الجزء $n';
}

/// The Indo-Pak para's name: its opening words, as those muṣḥafs head it.
String indopakParaName(int juz) => const [
  'الٓمّٓ', 'سَيَقُوْلُ', 'تِلْكَ الرُّسُلُ', 'لَنْ تَنَالُوْا', 'وَالْمُحْصَنٰتُ',
  'لَا يُحِبُّ اللّٰهُ', 'وَاِذَا سَمِعُوْا', 'وَلَوْ اَنَّنَا', 'قَالَ الْمَلَاُ',
  'وَاعْلَمُوْٓا', 'يَعْتَذِرُوْنَ', 'وَمَا مِنْ دَآبَّةٍ', 'وَمَآ اُبَرِّئُ',
  'رُبَمَا', 'سُبْحٰنَ الَّذِيْٓ', 'قَالَ اَلَمْ', 'اِقْتَرَبَ لِلنَّاسِ',
  'قَدْ اَفْلَحَ', 'وَقَالَ الَّذِيْنَ', 'اَمَّنْ خَلَقَ', 'اُتْلُ مَآ اُوْحِيَ',
  'وَمَنْ يَّقْنُتْ', 'وَمَا لِيَ', 'فَمَنْ اَظْلَمُ', 'اِلَيْهِ يُرَدُّ', 'حٰمٓ',
  'قَالَ فَمَا خَطْبُكُمْ', 'قَدْ سَمِعَ اللّٰهُ', 'تَبٰرَكَ الَّذِيْ', 'عَمَّ',
][(juz - 1).clamp(0, 29)];

/// A ḥizb quarter's lantern text, [quarter] 1…240: «الحزب N» where a
/// ḥizb starts, then «ربع الحزب N», «نصف الحزب N», «ثلاثة أرباع الحزب N».
String hizbQuarterText(int quarter) {
  final hizb = (quarter - 1) ~/ 4 + 1;
  final n = _ar(hizb);
  return switch ((quarter - 1) % 4) {
    0 => 'الحزب\n$n',
    1 => 'ربع الحزب\n$n',
    2 => 'نصف الحزب\n$n',
    _ => 'ثلاثة أرباع\nالحزب $n',
  };
}

/// The ḥizb quarters starting on [lines] (a page): each quarter (1…240)
/// and the line its first word is on.
List<(int quarter, int line)> hizbQuartersOn(List<MushafLine> lines) {
  final starts = _rubIndex ??= {
    for (var i = 0; i < rubStarts.length; i++) rubStarts[i]: i + 1,
  };
  final out = <(int, int)>[];
  for (var i = 0; i < lines.length; i++) {
    for (final w in lines[i].words) {
      if (w.wordIdx != 0) continue;
      final q = starts[MushafRepo.surahAyahOf(w.ayah)];
      if (q != null) out.add((q, i));
    }
  }
  return out;
}

Map<(int, int), int>? _rubIndex;

/// The rukūʿ ending on [lines] (a page): the line holding the ۝ of each
/// one's last āyah, its number within its sūrah, and how many āyāt it has.
List<(int line, int number, int ayahs)> rukuEndsOn(List<MushafLine> lines) {
  final ends = _rukuEnds ??= _buildRukuEnds();
  final out = <(int, int, int)>[];
  for (var i = 0; i < lines.length; i++) {
    for (final w in lines[i].words) {
      if (!w.isMarker) continue;
      final r = ends[MushafRepo.surahAyahOf(w.ayah)];
      if (r != null) out.add((i, r.$1, r.$2));
    }
  }
  return out;
}

Map<(int, int), (int, int)>? _rukuEnds;

Map<(int, int), (int, int)> _buildRukuEnds() {
  final out = <(int, int), (int, int)>{};
  var inSurah = 0;
  for (var k = 0; k < rukuStarts.length; k++) {
    final (s, a) = rukuStarts[k];
    inSurah = k > 0 && rukuStarts[k - 1].$1 == s ? inSurah + 1 : 1;
    final next = k + 1 < rukuStarts.length ? rukuStarts[k + 1] : null;
    final last = next != null && next.$1 == s
        ? next.$2 - 1
        : MushafRepo.ayahCountOf(s);
    out[(s, last)] = (inSurah, last - a + 1);
  }
  return out;
}

/// The sūrahs with text on [lines] (a page), in order.
List<int> surahsOn(List<MushafLine> lines) {
  final out = <int>[];
  for (final l in lines) {
    final s = l.isHeader
        ? l.surah
        : (l.words.isEmpty ? 0 : MushafRepo.surahAyahOf(l.words.first.ayah).$1);
    if (s > 0 && !out.contains(s)) out.add(s);
  }
  return out;
}

String _ar(int n) => [
  for (final d in '$n'.runes) String.fromCharCode(0x0660 + d - 0x30),
].join();
