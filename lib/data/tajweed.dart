import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A verse split into segments; segments with a ruleId get the rule color.
class Seg {
  final String text;
  final String? ruleId;
  const Seg(this.text, [this.ruleId]);
}

class VerseExample {
  final String ref;
  final List<Seg> segs;
  const VerseExample(this.ref, this.segs);
  String get plain => segs.map((s) => s.text).join();
}

class TajwidRule {
  final String id;
  final String name;
  final String arabicName;
  final Color color;
  final String trigger; // when the rule applies
  final String how; // how to perform it
  final String letters; // trigger/associated letters, bare (no tashkīl); '' if not letter-keyed
  final VerseExample example;

  const TajwidRule({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.color,
    required this.trigger,
    required this.how,
    required this.letters,
    required this.example,
  });
}

const tajwidRules = <TajwidRule>[
  TajwidRule(
    id: 'ghunnah',
    name: 'Ghunnah',
    arabicName: 'غُنَّة',
    letters: 'نم',
    color: AppColors.tjGhunnah,
    trigger: 'Nūn or mīm with shaddah (نّ / مّ).',
    how: 'A full nasal hum from the nose, held two counts.',
    example: VerseExample('108:1', [
      Seg('إِ'), Seg('نَّ', 'ghunnah'), Seg('آ أَعۡطَيۡنَٰكَ ٱلۡكَوۡثَرَ'),
    ]),
  ),
  TajwidRule(
    id: 'izhar',
    name: 'Iẓhār',
    arabicName: 'إِظْهَار',
    letters: 'ءهعحغخ',
    color: AppColors.tjIzhar,
    trigger: 'Nūn sākinah or tanwīn before a throat letter (ء ه ع ح غ خ).',
    how: 'Pronounce the nūn clearly and quickly — no nasalization, no pause.',
    example: VerseExample('106:4', [
      Seg('ٱلَّذِيٓ أَطۡعَمَهُم مِّن جُوعٖ وَءَامَنَهُم '), Seg('مِّنۡ خَ', 'izhar'), Seg('وۡفِۭ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_g',
    name: 'Idghām with Ghunnah',
    arabicName: 'إِدْغَام بِغُنَّة',
    letters: 'ينمو',
    color: AppColors.tjIdghamG,
    trigger: 'Nūn sākinah / tanwīn before ي ن م و (across two words).',
    how: 'Merge the nūn into the next letter while humming two counts.',
    example: VerseExample('99:7', [
      Seg('فَمَ'), Seg('ن يَ', 'idgham_g'), Seg('عۡمَلۡ مِثۡقَالَ ذَرَّةٍ خَيۡرٗا يَرَهُۥ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_ng',
    name: 'Idghām without Ghunnah',
    arabicName: 'إِدْغَام بِلَا غُنَّة',
    letters: 'لر',
    color: AppColors.tjIdghamNoG,
    trigger: 'Nūn sākinah / tanwīn before ل or ر.',
    how: 'Merge completely into the lām or rā’ — the nūn disappears.',
    example: VerseExample('2:5', [
      Seg('أُوْلَـٰٓئِكَ عَلَىٰ هُدٗى '), Seg('مِّن رَّ', 'idgham_ng'), Seg('بِّهِمۡۖ وَأُوْلَـٰٓئِكَ هُمُ ٱلۡمُفۡلِحُونَ'),
    ]),
  ),
  TajwidRule(
    id: 'iqlab',
    name: 'Iqlāb',
    arabicName: 'إِقْلَاب',
    letters: 'ب',
    color: AppColors.tjIqlab,
    trigger: 'Nūn sākinah / tanwīn before ب.',
    how: 'Flip the nūn into a light mīm, hidden with ghunnah, two counts.',
    example: VerseExample('104:4', [
      Seg('كَلَّاۖ لَيُ'), Seg('نۢبَ', 'iqlab'), Seg('ذَنَّ فِي ٱلۡحُطَمَةِ'),
    ]),
  ),
  TajwidRule(
    id: 'ikhfa',
    name: 'Ikhfā’',
    arabicName: 'إِخْفَاء',
    letters: 'تثجدذزسشصضطظفقك',
    color: AppColors.tjIkhfa,
    trigger: 'Nūn sākinah / tanwīn before the remaining 15 letters.',
    how: 'Hide the nūn between iẓhār and idghām — a soft hum shaped toward the next letter.',
    example: VerseExample('103:2', [
      Seg('إِنَّ ٱلۡإِ'), Seg('نسَ', 'ikhfa'), Seg('ٰنَ لَفِي خُسۡرٍ'),
    ]),
  ),
  TajwidRule(
    id: 'qalqalah',
    name: 'Qalqalah',
    arabicName: 'قَلْقَلَة',
    letters: 'قطبجد',
    color: AppColors.tjQalqalah,
    trigger: 'ق ط ب ج د with sukūn — or at a stop. Remember: قُطْبُ جَدٍّ.',
    how: 'An echoing bounce: release the letter with a small pop, strongest when stopping.',
    example: VerseExample('113:1', [
      Seg('قُلۡ أَعُوذُ بِرَبِّ ٱلۡفَلَ'), Seg('قِ', 'qalqalah'),
    ]),
  ),
  TajwidRule(
    id: 'ikhfa_shafawi',
    name: 'Ikhfā’ Shafawī',
    arabicName: 'إِخْفَاء شَفَوِي',
    letters: 'ب',
    color: AppColors.tjIkhfa,
    trigger: 'Mīm sākinah before ب.',
    how: 'Hide the mīm at the lips with ghunnah.',
    example: VerseExample('105:4', [
      Seg('تَرۡمِي'), Seg('هِم بِ', 'ikhfa_shafawi'), Seg('حِجَارَةٖ مِّن سِجِّيلٖ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_shafawi',
    name: 'Idghām Shafawī',
    arabicName: 'إِدْغَام شَفَوِي',
    letters: 'م',
    color: AppColors.tjIdghamG,
    trigger: 'Mīm sākinah before another mīm.',
    how: 'Merge the two mīms with a full ghunnah.',
    example: VerseExample('106:4', [
      Seg('ٱلَّذِيٓ أَطۡعَمَ'), Seg('هُم مِّ', 'idgham_shafawi'), Seg('ن جُوعٖ وَءَامَنَهُم مِّنۡ خَوۡفِۭ'),
    ]),
  ),
  TajwidRule(
    id: 'izhar_shafawi',
    name: 'Iẓhār Shafawī',
    arabicName: 'إِظْهَار شَفَوِي',
    letters: 'ءتثجحخدذرزسشصضطظعغفقكلنهوي',
    color: AppColors.tjIzhar,
    trigger: 'Mīm sākinah before any letter except م or ب.',
    how: 'Pronounce the mīm clearly with closed lips — no hiding, no merging.',
    example: VerseExample('1:7', [
      Seg('صِرَٰطَ ٱلَّذِينَ أَنۡعَمۡتَ عَلَيۡهِ'), Seg('مۡ غَ', 'izhar_shafawi'), Seg('يۡرِ ٱلۡمَغۡضُوبِ عَلَيۡهِمۡ وَلَا ٱلضَّآلِّينَ'),
    ]),
  ),
  TajwidRule(
    id: 'madd2',
    name: 'Madd Ṭabī‘ī (2)',
    arabicName: 'مَدّ طَبِيعِي',
    letters: 'اوي',
    color: AppColors.tjMadd2,
    trigger: 'A plain madd letter (ا و ي) with nothing after it.',
    how: 'Exactly two counts.',
    example: VerseExample('1:4', [
      Seg('مَٰ', 'madd2'), Seg('لِكِ يَوۡمِ ٱلدِّينِ'),
    ]),
  ),
  TajwidRule(
    id: 'madd4',
    name: 'Madd Muttaṣil (4–5)',
    arabicName: 'مَدّ مُتَّصِل',
    letters: 'اوي',
    color: AppColors.tjMadd4,
    trigger: 'Madd letter + hamzah in the same word.',
    how: 'Four to five counts — obligatory.',
    example: VerseExample('110:1', [
      Seg('إِذَا '), Seg('جَآءَ', 'madd4'), Seg(' نَصۡرُ ٱللَّهِ وَٱلۡفَتۡحُ'),
    ]),
  ),
  TajwidRule(
    id: 'madd45',
    name: 'Madd Munfaṣil (4–5)',
    arabicName: 'مَدّ مُنْفَصِل',
    letters: 'اوي',
    color: AppColors.tjMadd4,
    trigger: 'Madd at a word end, hamzah begins the next word.',
    how: 'Four to five counts in Ḥafṣ (other transmissions differ — see Qirā’āt).',
    example: VerseExample('97:1', [
      Seg('إِ'), Seg('نَّ', 'ghunnah'), Seg('آ أَ', 'madd45'), Seg('نزَلۡنَٰهُ فِي لَيۡلَةِ ٱلۡقَدۡرِ'),
    ]),
  ),
  TajwidRule(
    id: 'madd6',
    name: 'Madd Lāzim (6)',
    arabicName: 'مَدّ لَازِم',
    letters: 'اوي',
    color: AppColors.tjMadd6,
    trigger: 'Madd letter followed by a permanent sukūn or shaddah.',
    how: 'Six full counts — including the opening letters like الٓمٓ.',
    example: VerseExample('1:7', [
      Seg('صِرَٰطَ ٱلَّذِينَ أَنۡعَمۡتَ عَلَيۡهِمۡ غَيۡرِ ٱلۡمَغۡضُوبِ عَلَيۡهِمۡ وَلَا ٱل'), Seg('ضَّآلّ', 'madd6'), Seg('ِينَ'),
    ]),
  ),
  TajwidRule(
    id: 'shamsiyya',
    name: 'Lām Shamsiyyah',
    arabicName: 'لَام شَمْسِيَّة',
    letters: 'تثدذرزسشصضطظلن',
    color: AppColors.tjShamsiyya,
    trigger: '“ال” before a sun letter — the lām is written but silent.',
    how: 'Jump straight to the doubled sun letter.',
    example: VerseExample('91:1', [
      Seg('وَ'), Seg('ٱلشَّ', 'shamsiyya'), Seg('مۡسِ وَضُحَىٰهَا'),
    ]),
  ),
  TajwidRule(
    id: 'qamariyya',
    name: 'Lām Qamariyyah',
    arabicName: 'لَام قَمَرِيَّة',
    letters: 'ءبجحخعغفقكمهوي',
    color: AppColors.tjQamariyya,
    trigger: '“ال” before a moon letter — the lām is pronounced with sukūn.',
    how: 'Say the lām clearly: al-qamar.',
    example: VerseExample('91:2', [
      Seg('وَ'), Seg('ٱلۡقَ', 'qamariyya'), Seg('مَرِ إِذَا تَلَىٰهَا'),
    ]),
  ),
  TajwidRule(
    id: 'raa_tafkhim',
    name: 'Tafkhīm of Rā’',
    arabicName: 'تَفْخِيم الرَّاء',
    letters: 'ر',
    color: AppColors.tjRaa,
    trigger: 'Rā’ with fatḥah or ḍammah, or sākinah after one.',
    how: 'A heavy, full-mouthed rā’ — round the back of the tongue.',
    example: VerseExample('1:2', [
      Seg('ٱلۡحَمۡدُ لِلَّهِ '), Seg('رَ', 'raa_tafkhim'), Seg('بِّ ٱلۡعَٰلَمِينَ'),
    ]),
  ),
  TajwidRule(
    id: 'raa_tarqiq',
    name: 'Tarqīq of Rā’',
    arabicName: 'تَرْقِيق الرَّاء',
    letters: 'ر',
    color: AppColors.tjRaa,
    trigger: 'Rā’ with kasrah, or sākinah after one.',
    how: 'A light, thin rā’ — no rounding, no heaviness.',
    example: VerseExample('1:7', [
      Seg('صِرَٰطَ ٱلَّذِينَ أَنۡعَمۡتَ عَلَيۡهِمۡ غَيۡ'), Seg('رِ', 'raa_tarqiq'), Seg(' ٱلۡمَغۡضُوبِ عَلَيۡهِمۡ وَلَا ٱلضَّآلِّينَ'),
    ]),
  ),
  TajwidRule(
    id: 'tafkhim',
    name: 'Tafkhīm',
    arabicName: 'تَفْخِيم',
    letters: 'خصضغطقظ',
    color: AppColors.tjMadd4,
    trigger: 'The seven heavy letters: خ ص ض غ ط ق ظ.',
    how: 'Fill the mouth with the sound — these letters are heavy at every vowel.',
    example: VerseExample('112:2', [
      Seg('ٱللَّهُ ٱل'), Seg('صّ', 'tafkhim'), Seg('َمَدُ'),
    ]),
  ),
  TajwidRule(
    id: 'lam_jalalah',
    name: 'Lām al-Jalālah',
    arabicName: 'لَام الْجَلَالَة',
    letters: 'ل',
    color: AppColors.tjQamariyya,
    trigger: 'The lām of ٱللَّٰه — Allāh’s name.',
    how: 'Heavy after fatḥah/ḍammah, light after kasrah.',
    example: VerseExample('1:2', [
      Seg('ٱلۡحَمۡدُ لِ'), Seg('لَّهِ', 'lam_jalalah'), Seg(' رَبِّ ٱلۡعَٰلَمِينَ'),
    ]),
  ),
];

TajwidRule ruleById(String id) => tajwidRules.firstWhere((r) => r.id == id);
