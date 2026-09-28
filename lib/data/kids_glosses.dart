import 'package:flutter/widgets.dart';

import '../core/l10n.dart';
import 'kids_sentences.dart';
import 'small_letters.dart';
import 'special_shapes.dart';

/// Kid-worded text for content whose own data file is written for the
/// grown-up Qāʿidah — [specialShapes], [extraLetterNotes] and
/// [smallLetters] — plus a plain-language "meaning" for each
/// [kidsSentences] word. Kept as l10n-key resolver switches here, the same
/// shape [tashkilNote]/[tajwidHow] already use in `glyph_names.dart`, so the
/// data files themselves stay exactly as precise as the grown-up Qāʿidah
/// needs and a child gets a second, simpler voice in all five languages.
///
/// The grown-up strings this replaces on a Kids Mode screen — `.note`,
/// `.tellApart`, `extraLetterNotes[..]`, `SmallLetter.note` and
/// `KidsSentence.gloss` — are NOT deleted: `special_shapes_test.dart` and the
/// adult Joining Forms lesson still read them, and English text authored
/// for an adult must go on being that, unedited, while a child reads
/// something written for a child.

/// A special shape's kid-worded title. Falls through to the data's own
/// `.title` for the two tails-group shapes with no separate kid title yet.
String kidsShapeTitle(BuildContext context, SpecialShape s) => switch (s.id) {
      'lam_alif' => context.l10n.kidsShapeLamAlifTitle,
      'lam_hamza' => context.l10n.kidsShapeLamHamzaTitle,
      'kaf_wraps' => context.l10n.kidsShapeKafWrapsTitle,
      'kaf_elongated' => context.l10n.kidsShapeKafElongatedTitle,
      'mim_over_jim' => context.l10n.kidsShapeMimOverJimTitle,
      'lam_over_jim' => context.l10n.kidsShapeLamOverJimTitle,
      'tooth_over_jim' => context.l10n.kidsShapeToothOverJimTitle,
      'tooth_over_mim' => context.l10n.kidsShapeToothOverMimTitle,
      'ayn_over_jim' => context.l10n.kidsShapeAynOverJimTitle,
      'faqaf_over_jim' => context.l10n.kidsShapeFaqafOverJimTitle,
      'mim_over_mim' => context.l10n.kidsShapeMimOverMimTitle,
      'mim_final_after_tooth' => context.l10n.kidsShapeMimFinalAfterToothTitle,
      'haa_medial' => context.l10n.kidsShapeHaaMedialTitle,
      'ra_za_elongated_final' => context.l10n.kidsShapeRaZaElongatedFinalTitle,
      _ => s.title,
    };

/// A special shape's kid-worded teaching note — one idea, one short sentence.
String kidsShapeNote(BuildContext context, SpecialShape s) => switch (s.id) {
      'lam_alif' => context.l10n.kidsShapeLamAlifNote,
      'lam_hamza' => context.l10n.kidsShapeLamHamzaNote,
      'kaf_wraps' => context.l10n.kidsShapeKafWrapsNote,
      'kaf_elongated' => context.l10n.kidsShapeKafElongatedNote,
      'mim_over_jim' => context.l10n.kidsShapeMimOverJimNote,
      'lam_over_jim' => context.l10n.kidsShapeLamOverJimNote,
      'tooth_over_jim' => context.l10n.kidsShapeToothOverJimNote,
      'tooth_over_mim' => context.l10n.kidsShapeToothOverMimNote,
      'ayn_over_jim' => context.l10n.kidsShapeAynOverJimNote,
      'faqaf_over_jim' => context.l10n.kidsShapeFaqafOverJimNote,
      'mim_over_mim' => context.l10n.kidsShapeMimOverMimNote,
      'mim_final_after_tooth' => context.l10n.kidsShapeMimFinalAfterToothNote,
      'haa_medial' => context.l10n.kidsShapeHaaMedialNote,
      'ra_za_elongated_final' => context.l10n.kidsShapeRaZaElongatedFinalNote,
      _ => s.note,
    };

/// A special shape's kid-worded "how to tell it apart" tip — moved to answer
/// feedback rather than shown as a second paragraph before the question is
/// even asked (see `KidsChoiceCard`'s `explain`).
String kidsShapeTip(BuildContext context, SpecialShape s) => switch (s.id) {
      'lam_alif' => context.l10n.kidsShapeLamAlifTip,
      'lam_hamza' => context.l10n.kidsShapeLamHamzaTip,
      'kaf_wraps' => context.l10n.kidsShapeKafWrapsTip,
      'kaf_elongated' => context.l10n.kidsShapeKafElongatedTip,
      'mim_over_jim' => context.l10n.kidsShapeMimOverJimTip,
      'lam_over_jim' => context.l10n.kidsShapeLamOverJimTip,
      'tooth_over_jim' => context.l10n.kidsShapeToothOverJimTip,
      'tooth_over_mim' => context.l10n.kidsShapeToothOverMimTip,
      'ayn_over_jim' => context.l10n.kidsShapeAynOverJimTip,
      'faqaf_over_jim' => context.l10n.kidsShapeFaqafOverJimTip,
      'mim_over_mim' => context.l10n.kidsShapeMimOverMimTip,
      'mim_final_after_tooth' => context.l10n.kidsShapeMimFinalAfterToothTip,
      'haa_medial' => context.l10n.kidsShapeHaaMedialTip,
      'ra_za_elongated_final' => context.l10n.kidsShapeRaZaElongatedFinalTip,
      _ => s.tellApart,
    };

/// An extra letter's kid-worded note — [extraLetterNotes], in plain language.
String kidsExtraLetterNote(BuildContext context, String char) => switch (char) {
      'ء' => context.l10n.kidsExtraHamzah,
      'أ' => context.l10n.kidsExtraAlifHamzahAbove,
      'إ' => context.l10n.kidsExtraAlifHamzahBelow,
      'ؤ' => context.l10n.kidsExtraWawHamzah,
      'ئ' => context.l10n.kidsExtraYaHamzah,
      'ة' => context.l10n.kidsExtraTaMarbuta,
      'ى' => context.l10n.kidsExtraAlifMaqsura,
      'ٱ' => context.l10n.kidsExtraAlifWasl,
      _ => '',
    };

/// A small/superscript letter's kid-worded name and note.
String kidsSmallLetterName(BuildContext context, String id) => switch (id) {
      'dagger_alif' => context.l10n.kidsSmallDaggerAlifName,
      'small_waw' => context.l10n.kidsSmallWawName,
      'small_yeh' => context.l10n.kidsSmallYaName,
      _ => smallLetters.firstWhere((l) => l.id == id).name,
    };

String kidsSmallLetterNote(BuildContext context, String id) => switch (id) {
      'dagger_alif' => context.l10n.kidsSmallDaggerAlifNote,
      'small_waw' => context.l10n.kidsSmallWawNote,
      'small_yeh' => context.l10n.kidsSmallYaNote,
      _ => smallLetters.firstWhere((l) => l.id == id).note,
    };

/// A plain-language riddle for [s]'s target word — "we open it to go in" for
/// door — rather than a bare dictionary gloss, so it reads the same way in
/// every language, Arabic included (translating an Arabic word into Arabic
/// would say nothing).
String kidsWordGloss(BuildContext context, KidsSentence s) => switch (s.letter) {
      'ا' => context.l10n.kidsGlossDoor,
      'ب' => context.l10n.kidsGlossHouse,
      'ت' => context.l10n.kidsGlossApple,
      'ث' => context.l10n.kidsGlossFox,
      'ج' => context.l10n.kidsGlossCamel,
      'ح' => context.l10n.kidsGlossMilk,
      'خ' => context.l10n.kidsGlossBread,
      'د' => context.l10n.kidsGlossHen,
      'ذ' => context.l10n.kidsGlossGold,
      'ر' => context.l10n.kidsGlossMoon,
      'ز' => context.l10n.kidsGlossFlower,
      'س' => context.l10n.kidsGlossFish,
      'ش' => context.l10n.kidsGlossSun,
      'ص' => context.l10n.kidsGlossFalcon,
      'ض' => context.l10n.kidsGlossFrog,
      'ط' => context.l10n.kidsGlossBird,
      'ظ' => context.l10n.kidsGlossShade,
      'ع' => context.l10n.kidsGlossEye,
      'غ' => context.l10n.kidsGlossCrow,
      'ف' => context.l10n.kidsGlossElephant,
      'ق' => context.l10n.kidsGlossPen,
      'ك' => context.l10n.kidsGlossBook,
      'ل' => context.l10n.kidsGlossNight,
      'م' => context.l10n.kidsGlossWater,
      'ن' => context.l10n.kidsGlossBee,
      'ه' => context.l10n.kidsGlossCrescent,
      'و' => context.l10n.kidsGlossBoy,
      'ي' => context.l10n.kidsGlossHand,
      _ => s.gloss,
    };
