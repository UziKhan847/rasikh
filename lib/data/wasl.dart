/// What happens at the seam between two words — hamzat waṣl, the solar/lunar
/// lām, and the two silent-letter "zero" signs. Every [example] is verbatim
/// Uthmani from assets/quran/u/ (see test/wasl_data_test.dart). Solar and lunar
/// letters are derived mechanically from the corpus (ٱل + letter + shaddah for
/// solar, ٱلۡ + letter for lunar) — not hand-picked — and hamzah's two written
/// seats (أ above-alif, إ below-alif) are merged into one 'ء' entry, matching
/// the classical 14/14 mnemonic.
class WaslItem {
  final String id;
  final String kind; // 'wasl' | 'solar' | 'lunar' | 'zero_rect' | 'zero_round' | 'tanwin_wasl'
  final String letter; // the letter this item names; '' when not letter-specific
  final String example;
  final String ref;
  final String highlight;

  const WaslItem(this.id, this.kind, this.letter, this.example, this.ref, this.highlight);
}

const waslItems = <WaslItem>[
  WaslItem('wasl_alif', 'wasl', 'ٱ', 'ٱهۡدِنَا', '1:6', 'ٱ'),
  WaslItem('solar_062a', 'solar', 'ت', 'ٱلتَّوَّابُ', '2:37', 'ٱلتّ'),
  WaslItem('solar_062b', 'solar', 'ث', 'ٱلثَّمَرَٰتِ', '2:22', 'ٱلثّ'),
  WaslItem('solar_062f', 'solar', 'د', 'ٱلدِّينِ', '1:4', 'ٱلدّ'),
  WaslItem('solar_0630', 'solar', 'ذ', 'ٱلذِّلَّةُ', '2:61', 'ٱلذّ'),
  WaslItem('solar_0631', 'solar', 'ر', 'ٱلرَّحۡمَٰنِ', '1:1', 'ٱلرّ'),
  WaslItem('solar_0632', 'solar', 'ز', 'ٱلزَّكَوٰةَ', '2:43', 'ٱلزّ'),
  WaslItem('solar_0633', 'solar', 'س', 'ٱلسُّفَهَآءُۗ', '2:13', 'ٱلسّ'),
  WaslItem('solar_0634', 'solar', 'ش', 'ٱلشَّجَرَةَ', '2:35', 'ٱلشّ'),
  WaslItem('solar_0635', 'solar', 'ص', 'ٱلصِّرَٰطَ', '1:6', 'ٱلصّ'),
  WaslItem('solar_0636', 'solar', 'ض', 'ٱلضَّآلِّينَ', '1:7', 'ٱلضّ'),
  WaslItem('solar_0637', 'solar', 'ط', 'ٱلطُّورَ', '2:63', 'ٱلطّ'),
  WaslItem('solar_0638', 'solar', 'ظ', 'ٱلظَّـٰلِمِينَ', '2:35', 'ٱلظّ'),
  WaslItem('solar_0644', 'solar', 'ل', 'ٱللَّهِ', '1:1', 'ٱللّ'),
  WaslItem('solar_0646', 'solar', 'ن', 'ٱلنَّاسِ', '2:8', 'ٱلنّ'),
  WaslItem('lunar_0621', 'lunar', 'ء', 'ٱلۡأٓخِرِ', '2:8', 'ٱلۡأ'),
  WaslItem('lunar_0628', 'lunar', 'ب', 'ٱلۡبَرۡقُ', '2:20', 'ٱلۡب'),
  WaslItem('lunar_062c', 'lunar', 'ج', 'ٱلۡجَنَّةَ', '2:35', 'ٱلۡج'),
  WaslItem('lunar_062d', 'lunar', 'ح', 'ٱلۡحَمۡدُ', '1:2', 'ٱلۡح'),
  WaslItem('lunar_062e', 'lunar', 'خ', 'ٱلۡخَٰسِرُونَ', '2:27', 'ٱلۡخ'),
  WaslItem('lunar_0639', 'lunar', 'ع', 'ٱلۡعَٰلَمِينَ', '1:2', 'ٱلۡع'),
  WaslItem('lunar_063a', 'lunar', 'غ', 'ٱلۡغَمَامَ', '2:57', 'ٱلۡغ'),
  WaslItem('lunar_0641', 'lunar', 'ف', 'ٱلۡفَٰسِقِينَ', '2:26', 'ٱلۡف'),
  WaslItem('lunar_0642', 'lunar', 'ق', 'ٱلۡقَرۡيَةَ', '2:58', 'ٱلۡق'),
  WaslItem('lunar_0643', 'lunar', 'ك', 'ٱلۡكِتَٰبُ', '2:2', 'ٱلۡك'),
  WaslItem('lunar_0645', 'lunar', 'م', 'ٱلۡمُسۡتَقِيمَ', '1:6', 'ٱلۡم'),
  WaslItem('lunar_0647', 'lunar', 'ه', 'ٱلۡهُدَىٰۗ', '2:120', 'ٱلۡه'),
  WaslItem('lunar_0648', 'lunar', 'و', 'ٱلۡوَصِيَّةُ', '2:180', 'ٱلۡو'),
  WaslItem('lunar_064a', 'lunar', 'ي', 'ٱلۡيَهُودُ', '2:113', 'ٱلۡي'),
  WaslItem('zero_rect_ana', 'zero_rect', '', 'أَنَا۠', '2:258', 'ا۠'),
  WaslItem('zero_rect_qawarira', 'zero_rect', '', 'قَوَارِيرَا۠', '76:15', 'ا۠'),
  WaslItem('zero_round_kafaru', 'zero_round', '', 'كَفَرُواْ', '2:6', 'اْ'),
  WaslItem('zero_round_qawarira', 'zero_round', '', 'قَوَارِيرَاْ', '76:16', 'اْ'),
  WaslItem('tanwin_wasl', 'tanwin_wasl', '', 'خَيۡرًا ٱلۡوَصِيَّةُ', '2:180', 'ًا ٱل'),
];

List<WaslItem> waslOfKind(String kind) =>
    waslItems.where((w) => w.kind == kind).toList();
