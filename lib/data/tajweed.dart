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
  // Additional real verses beyond `example` (word/phrase, ref, highlight
  // substring) — several examples make the rule's presence a demonstrated
  // fact rather than a single assertion, and let Test/Practice ask about
  // the same rule without repeating the identical verse every time.
  final List<(String, String, String)> moreExamples;

  const TajwidRule({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.color,
    required this.trigger,
    required this.how,
    required this.letters,
    required this.example,
    this.moreExamples = const [],
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
    moreExamples: [('وَمِمَّا', '2:3', 'مّ'), ('مِّن', '2:5', 'مّ'), ('إِنَّ', '2:6', 'نّ'), ('ٱلنَّاسِ', '2:8', 'نّ'), ('ءَامَنَّا', '2:8', 'نّ')],
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
    moreExamples: [('سَوَآءٌ عَلَيۡهِمۡ', '2:6', 'ءٌ عَ'), ('عَذَابٌ عَظِيمٞ', '2:7', 'بٌ عَ'), ('بُكۡمٌ عُمۡيٞ', '2:18', 'مٌ عُ'), ('شَيۡءٍ عَلِيمٞ', '2:29', 'ءٍ عَ'), ('لِبَعۡضٍ عَدُوّٞۖ', '2:36', 'ضٍ عَ')],
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
    moreExamples: [('مَن يَقُولُ', '2:8', 'َن يَ'), ('كَصَيِّبٖ مِّنَ', '2:19', 'بٖ مّ'), ('ظُلُمَٰتٞ وَرَعۡدٞ', '2:19', 'تٞ وَ'), ('وَرَعۡدٞ وَبَرۡقٞ', '2:19', 'دٞ وَ'), ('وَبَرۡقٞ يَجۡعَلُونَ', '2:19', 'قٞ يَ')],
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
    moreExamples: [('مِّن رَّبِّهِمۡۖ', '2:5', 'ِن رّ'), ('وَلَٰكِن لَّا', '2:12', 'ِن لّ'), ('وَلَٰكِن لَّا', '2:13', 'ِن لّ'), ('ظُلُمَٰتٖ لَّا', '2:17', 'تٖ لّ'), ('فَإِن لَّمۡ', '2:24', 'ِن لّ')],
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
    moreExamples: [('أَلِيمُۢ', '2:10', 'ُۢ'), ('صُمُّۢ', '2:18', 'ُۢ'), ('مُحِيطُۢ', '2:19', 'ُۢ'), ('مِنۢ', '2:27', 'نۢ'), ('أَنۢبِـُٔونِي', '2:31', 'نۢب')],
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
    moreExamples: [('مِن قَبۡلِكَ', '2:4', 'ِن قَ'), ('مَّرَضٞ فَزَادَهُمُ', '2:10', 'ضٞ فَ'), ('عَذَابٌ أَلِيمُۢ', '2:10', 'بٌ أَ'), ('عُمۡيٞ فَهُمۡ', '2:18', 'يٞ فَ'), ('شَيۡءٖ قَدِيرٞ', '2:20', 'ءٖ قَ')],
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
    moreExamples: [('رَزَقۡنَٰهُمۡ', '2:3', 'قۡ'), ('قَبۡلِكَ', '2:4', 'بۡ'), ('أَبۡصَٰرِهِمۡ', '2:7', 'بۡ'), ('يُبۡصِرُونَ', '2:17', 'بۡ'), ('يَجۡعَلُونَ', '2:19', 'جۡ')],
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
    moreExamples: [('هُم بِمُؤۡمِنِينَ', '2:8', 'ُم بِ'), ('أَنۢبِئۡهُم بِأَسۡمَآئِهِمۡۖ', '2:33', 'ُم بِ'), ('أَنۢبَأَهُم بِأَسۡمَآئِهِمۡ', '2:33', 'ُم بِ'), ('ذَٰلِكُم بَلَآءٞ', '2:49', 'ُم بَ'), ('أَنفُسَكُم بِٱتِّخَاذِكُمُ', '2:54', 'ُم بِ')],
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
    moreExamples: [('قُلُوبِهِم مَّرَضٞ', '2:10', 'ِم مّ'), ('ءَاذَانِهِم مِّنَ', '2:19', 'ِم مّ'), ('لَهُم مَّشَوۡاْ', '2:20', 'ُم مّ'), ('شُهَدَآءَكُم مِّن', '2:23', 'ُم مّ'), ('لَكُم مَّا', '2:29', 'ُم مّ')],
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
    moreExamples: [('عَلَيۡهِمۡ غَيۡرِ', '1:7', 'مۡ غَ'), ('عَلَيۡهِمۡ وَلَا', '1:7', 'مۡ وَ'), ('رَزَقۡنَٰهُمۡ يُنفِقُونَ', '2:3', 'مۡ يُ'), ('هُمۡ يُوقِنُونَ', '2:4', 'مۡ يُ'), ('عَلَيۡهِمۡ ءَأَنذَرۡتَهُمۡ', '2:6', 'مۡ ءَ')],
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
    moreExamples: [('ٱلرَّحِيمِ', '1:1', 'ي'), ('ٱلۡعَٰلَمِينَ', '1:2', 'ي'), ('ٱلرَّحِيمِ', '1:3', 'ي'), ('يَوۡمِ', '1:4', 'ي'), ('ٱلدِّينِ', '1:4', 'ي')],
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
    moreExamples: [('ٱهۡدِنَا', '1:6', 'ا'), ('وَلَا', '1:7', 'ا'), ('لَا', '2:2', 'ا'), ('وَمِمَّا', '2:3', 'ا'), ('لَا', '2:6', 'ا')],
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
    moreExamples: [('بَغۡيًا أَن', '2:90', 'ًا أ'), ('هُودًا أَوۡ', '2:111', 'ًا أ'), ('بَلَدًا ءَامِنٗا', '2:126', 'ًا ء'), ('هُودًا أَوۡ', '2:135', 'ًا أ'), ('هُودًا أَوۡ', '2:140', 'ًا أ')],
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
    moreExamples: [('يَوۡمِ', '1:4', 'وۡ'), ('إِيَّاكَ', '1:5', 'يّ'), ('وَإِيَّاكَ', '1:5', 'يّ'), ('عَلَيۡهِمۡ', '1:7', 'يۡ'), ('غَيۡرِ', '1:7', 'يۡ')],
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
    moreExamples: [('ٱلتَّوَّابُ', '2:37', 'ٱلتّ'), ('ٱلثَّمَرَٰتِ', '2:22', 'ٱلثّ'), ('ٱلدِّينِ', '1:4', 'ٱلدّ'), ('ٱلذِّلَّةُ', '2:61', 'ٱلذّ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'ٱلرّ'), ('ٱلزَّكَوٰةَ', '2:43', 'ٱلزّ')],
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
    moreExamples: [('ٱلۡأٓخِرِ', '2:8', 'ٱلۡأ'), ('ٱلۡبَرۡقُ', '2:20', 'ٱلۡب'), ('ٱلۡجَنَّةَ', '2:35', 'ٱلۡج'), ('ٱلۡحَمۡدُ', '1:2', 'ٱلۡح'), ('ٱلۡخَٰسِرُونَ', '2:27', 'ٱلۡخ'), ('ٱلۡعَٰلَمِينَ', '1:2', 'ٱلۡع')],
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
    moreExamples: [('رَبِّ', '1:2', 'رَ'), ('ٱلصِّرَٰطَ', '1:6', 'رَ'), ('صِرَٰطَ', '1:7', 'رَ'), ('رَيۡبَۛ', '2:2', 'رَ'), ('رَزَقۡنَٰهُمۡ', '2:3', 'رَ')],
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
    moreExamples: [('غَيۡرِ', '1:7', 'رِ'), ('أَبۡصَٰرِهِمۡ', '2:7', 'رِ'), ('ٱلۡأٓخِرِ', '2:8', 'رِ'), ('بِنُورِهِمۡ', '2:17', 'رِ'), ('بِٱلۡكَٰفِرِينَ', '2:19', 'رِ')],
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
    moreExamples: [('ٱلصِّرَٰطَ', '1:6', 'صّ'), ('ٱلضَّآلِّينَ', '1:7', 'ضّ'), ('ٱلصَّلَوٰةَ', '2:3', 'صّ'), ('ٱلضَّلَٰلَةَ', '2:16', 'ضّ'), ('ٱلصَّوَٰعِقِ', '2:19', 'صّ')],
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
    moreExamples: [('ٱللَّهِ', '1:1', 'للّ'), ('ٱللَّهُ', '2:7', 'للّ'), ('بِٱللَّهِ', '2:8', 'للّ'), ('ٱللَّهَ', '2:9', 'للّ'), ('ٱللَّهُ', '2:10', 'للّ')],
  ),
];

TajwidRule ruleById(String id) => tajwidRules.firstWhere((r) => r.id == id);
