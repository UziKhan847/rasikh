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
  final VerseExample example;

  const TajwidRule({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.color,
    required this.trigger,
    required this.how,
    required this.example,
  });
}

const tajwidRules = <TajwidRule>[
  TajwidRule(
    id: 'ghunnah',
    name: 'Ghunnah',
    arabicName: 'غُنَّة',
    color: AppColors.tjGhunnah,
    trigger: 'Nūn or mīm with shaddah (نّ / مّ).',
    how: 'A full nasal hum from the nose, held two counts.',
    example: VerseExample('108:1', [
      Seg('إِ'), Seg('نَّ', 'ghunnah'), Seg('ا أَعْطَيْنَاكَ الْكَوْثَرَ'),
    ]),
  ),
  TajwidRule(
    id: 'izhar',
    name: 'Iẓhār',
    arabicName: 'إِظْهَار',
    color: AppColors.tjIzhar,
    trigger: 'Nūn sākinah or tanwīn before a throat letter (ء ه ع ح غ خ).',
    how: 'Pronounce the nūn clearly and quickly — no nasalization, no pause.',
    example: VerseExample('106:4', [
      Seg('وَآمَنَهُم '), Seg('مِّنْ خَ', 'izhar'), Seg('وْفٍ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_g',
    name: 'Idghām with Ghunnah',
    arabicName: 'إِدْغَام بِغُنَّة',
    color: AppColors.tjIdghamG,
    trigger: 'Nūn sākinah / tanwīn before ي ن م و (across two words).',
    how: 'Merge the nūn into the next letter while humming two counts.',
    example: VerseExample('99:7', [
      Seg('فَمَ'), Seg('ن يَ', 'idgham_g'), Seg('عْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_ng',
    name: 'Idghām without Ghunnah',
    arabicName: 'إِدْغَام بِلَا غُنَّة',
    color: AppColors.tjIdghamNoG,
    trigger: 'Nūn sākinah / tanwīn before ل or ر.',
    how: 'Merge completely into the lām or rā’ — the nūn disappears.',
    example: VerseExample('2:5', [
      Seg('أُولَٰئِكَ عَلَىٰ هُدًى '), Seg('مِّن رَّ', 'idgham_ng'), Seg('بِّهِمْ'),
    ]),
  ),
  TajwidRule(
    id: 'iqlab',
    name: 'Iqlāb',
    arabicName: 'إِقْلَاب',
    color: AppColors.tjIqlab,
    trigger: 'Nūn sākinah / tanwīn before ب.',
    how: 'Flip the nūn into a light mīm, hidden with ghunnah, two counts.',
    example: VerseExample('104:4', [
      Seg('كَلَّا ۖ لَيُ'), Seg('نۢبَ', 'iqlab'), Seg('ذَنَّ فِي الْحُطَمَةِ'),
    ]),
  ),
  TajwidRule(
    id: 'ikhfa',
    name: 'Ikhfā’',
    arabicName: 'إِخْفَاء',
    color: AppColors.tjIkhfa,
    trigger: 'Nūn sākinah / tanwīn before the remaining 15 letters.',
    how: 'Hide the nūn between iẓhār and idghām — a soft hum shaped toward the next letter.',
    example: VerseExample('103:2', [
      Seg('إِنَّ الْإِ'), Seg('نسَ', 'ikhfa'), Seg('انَ لَفِي خُسْرٍ'),
    ]),
  ),
  TajwidRule(
    id: 'qalqalah',
    name: 'Qalqalah',
    arabicName: 'قَلْقَلَة',
    color: AppColors.tjQalqalah,
    trigger: 'ق ط ب ج د with sukūn — or at a stop. Remember: قُطْبُ جَدٍّ.',
    how: 'An echoing bounce: release the letter with a small pop, strongest when stopping.',
    example: VerseExample('113:1', [
      Seg('قُلْ أَعُوذُ بِرَبِّ الْفَلَ'), Seg('قِ', 'qalqalah'),
    ]),
  ),
  TajwidRule(
    id: 'ikhfa_shafawi',
    name: 'Ikhfā’ Shafawī',
    arabicName: 'إِخْفَاء شَفَوِي',
    color: AppColors.tjIkhfa,
    trigger: 'Mīm sākinah before ب.',
    how: 'Hide the mīm at the lips with ghunnah.',
    example: VerseExample('105:4', [
      Seg('تَرْمِي'), Seg('هِم بِ', 'ikhfa_shafawi'), Seg('حِجَارَةٍ مِّن سِجِّيلٍ'),
    ]),
  ),
  TajwidRule(
    id: 'idgham_shafawi',
    name: 'Idghām Shafawī',
    arabicName: 'إِدْغَام شَفَوِي',
    color: AppColors.tjIdghamG,
    trigger: 'Mīm sākinah before another mīm.',
    how: 'Merge the two mīms with a full ghunnah.',
    example: VerseExample('106:4', [
      Seg('الَّذِي أَطْعَمَ'), Seg('هُم مِّ', 'idgham_shafawi'), Seg('ن جُوعٍ'),
    ]),
  ),
  TajwidRule(
    id: 'madd2',
    name: 'Madd Ṭabī‘ī (2)',
    arabicName: 'مَدّ طَبِيعِي',
    color: AppColors.tjMadd2,
    trigger: 'A plain madd letter (ا و ي) with nothing after it.',
    how: 'Exactly two counts.',
    example: VerseExample('1:4', [
      Seg('مَ'), Seg('ا', 'madd2'), Seg('لِكِ يَوْمِ الدِّينِ'),
    ]),
  ),
  TajwidRule(
    id: 'madd4',
    name: 'Madd Muttaṣil (4–5)',
    arabicName: 'مَدّ مُتَّصِل',
    color: AppColors.tjMadd4,
    trigger: 'Madd letter + hamzah in the same word.',
    how: 'Four to five counts — obligatory.',
    example: VerseExample('110:1', [
      Seg('إِذَا '), Seg('جَآءَ', 'madd4'), Seg(' نَصْرُ اللَّهِ وَالْفَتْحُ'),
    ]),
  ),
  TajwidRule(
    id: 'madd45',
    name: 'Madd Munfaṣil (4–5)',
    arabicName: 'مَدّ مُنْفَصِل',
    color: AppColors.tjMadd4,
    trigger: 'Madd at a word end, hamzah begins the next word.',
    how: 'Four to five counts in Ḥafṣ (other transmissions differ — see Qirā’āt).',
    example: VerseExample('97:1', [
      Seg('إِ'), Seg('نَّ', 'ghunnah'), Seg('آ أَ', 'madd45'), Seg('نزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ'),
    ]),
  ),
  TajwidRule(
    id: 'madd6',
    name: 'Madd Lāzim (6)',
    arabicName: 'مَدّ لَازِم',
    color: AppColors.tjMadd6,
    trigger: 'Madd letter followed by a permanent sukūn or shaddah.',
    how: 'Six full counts — including the opening letters like الٓمٓ.',
    example: VerseExample('1:7', [
      Seg('وَلَا ال'), Seg('ضَّآلِّ', 'madd6'), Seg('ينَ'),
    ]),
  ),
  TajwidRule(
    id: 'shamsiyya',
    name: 'Lām Shamsiyyah',
    arabicName: 'لَام شَمْسِيَّة',
    color: AppColors.tjShamsiyya,
    trigger: '“ال” before a sun letter — the lām is written but silent.',
    how: 'Jump straight to the doubled sun letter.',
    example: VerseExample('91:1', [
      Seg('وَ'), Seg('الشَّ', 'shamsiyya'), Seg('مْسِ وَضُحَاهَا'),
    ]),
  ),
  TajwidRule(
    id: 'qamariyya',
    name: 'Lām Qamariyyah',
    arabicName: 'لَام قَمَرِيَّة',
    color: AppColors.tjQamariyya,
    trigger: '“ال” before a moon letter — the lām is pronounced with sukūn.',
    how: 'Say the lām clearly: al-qamar.',
    example: VerseExample('91:2', [
      Seg('وَ'), Seg('الْقَ', 'qamariyya'), Seg('مَرِ إِذَا تَلَاهَا'),
    ]),
  ),
  TajwidRule(
    id: 'tafkhim',
    name: 'Tafkhīm & Tarqīq',
    arabicName: 'تَفْخِيم وَتَرْقِيق',
    color: AppColors.tjMadd4,
    trigger: 'Heavy letters (خ ص ض غ ط ق ظ), the rā’, and the lām of اللّٰه.',
    how: 'Heavy letters fill the mouth; rā’ and the lām of Allāh are heavy or light depending on the vowel before them.',
    example: VerseExample('1:2', [
      Seg('الْحَمْدُ لِ'), Seg('لَّهِ', 'tafkhim'), Seg(' رَبِّ الْعَالَمِينَ'),
    ]),
  ),
];

TajwidRule ruleById(String id) => tajwidRules.firstWhere((r) => r.id == id);
