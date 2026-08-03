import 'package:flutter/widgets.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import 'letters.dart';
import 'strokes.dart';
import 'tashkeel.dart';
import 'tajweed.dart';

/// Localized display names for traced glyphs.
///
/// The datasets carry an English name per glyph ('Alif · Alone', 'Bā’ · Start')
/// — 422 of them across the five levels. Translating each one would mean 422
/// strings per language, so they are COMPOSED instead: every glyph id already
/// encodes the letter and the joining form ('ب.med'), which means 28 letter
/// names + 4 form labels cover all of them in any language.
///
/// Word glyphs ('w.بسم') keep the name from the dataset, which carries its own
/// authored label.

/// The letter's name on its own — 'Bā’' / 'باء' / 'بے'.
String letterNameOf(BuildContext context, String char) => switch (char) {
      'ا' => context.l10n.ltrAlif,
      'ب' => context.l10n.ltrBa,
      'ت' => context.l10n.ltrTa,
      'ث' => context.l10n.ltrTha,
      'ج' => context.l10n.ltrJim,
      'ح' => context.l10n.ltrHha,
      'خ' => context.l10n.ltrKha,
      'د' => context.l10n.ltrDal,
      'ذ' => context.l10n.ltrDhal,
      'ر' => context.l10n.ltrRa,
      'ز' => context.l10n.ltrZay,
      'س' => context.l10n.ltrSin,
      'ش' => context.l10n.ltrShin,
      'ص' => context.l10n.ltrSad,
      'ض' => context.l10n.ltrDad,
      'ط' => context.l10n.ltrTta,
      'ظ' => context.l10n.ltrZza,
      'ع' => context.l10n.ltrAyn,
      'غ' => context.l10n.ltrGhayn,
      'ف' => context.l10n.ltrFa,
      'ق' => context.l10n.ltrQaf,
      'ك' => context.l10n.ltrKaf,
      'ل' => context.l10n.ltrLam,
      'م' => context.l10n.ltrMim,
      'ن' => context.l10n.ltrNun,
      'ه' => context.l10n.ltrHa,
      'و' => context.l10n.ltrWaw,
      'ي' => context.l10n.ltrYa,
      _ => char,
    };

/// 'iso' | 'ini' | 'med' | 'fin' → 'Alone' / 'Start' / 'Middle' / 'End'.
String formLabelOf(BuildContext context, String form) => switch (form) {
      'ini' => context.l10n.formStart,
      'med' => context.l10n.formMiddle,
      'fin' => context.l10n.formEnd,
      _ => context.l10n.formAlone,
    };

/// The glyph's full display name, composed for the current language.
String glyphNameOf(BuildContext context, TracedGlyph g) {
  final parts = g.id.split('.');
  // Word glyphs carry an authored label — leave it exactly as written.
  if (parts.first == 'w' || parts.length < 2) return g.name;
  return '${letterNameOf(context, parts.first)} · '
      '${formLabelOf(context, parts.last)}';
}

/// Level name for the current language, keyed by [TracingLevel.id].
String levelNameOf(BuildContext context, String id) => switch (id) {
      'naskh_few' => context.l10n.lvlNaskhFew,
      'naskh_words' => context.l10n.lvlNaskhWords,
      'ruqaa_letters' => context.l10n.lvlRuqaaLetters,
      'ruqaa_words' => context.l10n.lvlRuqaaWords,
      _ => context.l10n.lvlNaskhMore,
    };

/// Difficulty tier for the current language.
String tierLabelOf(BuildContext context, String tier) => switch (tier) {
      'Intermediate' => context.l10n.tierIntermediate,
      'Advanced' => context.l10n.tierAdvanced,
      _ => context.l10n.tierBeginner,
    };

/// Mode label for the current language ('guided' | 'outline' | 'memory').
String modeLabelOf(BuildContext context, String mode) => switch (mode) {
      'outline' => context.l10n.outline,
      'memory' => context.l10n.memory,
      _ => context.l10n.guided,
    };

/// 'above' | 'below' | 'inside' → the reader's language.
String dotPosLabel(BuildContext context, String pos) => switch (pos) {
      'below' => context.l10n.dotPosBelow,
      'inside' => context.l10n.dotPosInside,
      _ => context.l10n.dotPosAbove,
    };

/// Descriptive: 'no dots' / '2 dots below'.
String dotsDesc(BuildContext context, int count, String pos) => count == 0
    ? context.l10n.noDots
    : context.l10n.dotsWithPos(count, dotPosLabel(context, pos));

/// Terse, for quiz answers and their option pool: 'No dots' / '2 below'.
/// Answers and options MUST come from here so they compare equal.
String dotsShort(BuildContext context, int count, String pos) =>
    count == 0 ? context.l10n.noDots : '$count ${dotPosLabel(context, pos)}';

/// [dotsDesc] plus a caveat for letters whose dotted form the muṣḥaf doesn't
/// always show — currently just yā', which renders dotless when isolated or
/// final (see UthmanicHafs's `fina` GSUB lookup). Without this the letter
/// card's "2 dots below" caption visibly contradicts the dotless glyph
/// drawn above it.
String dotsDescForLetter(BuildContext context, ArabicLetter l) {
  final base = dotsDesc(context, l.dotCount, l.dotPos);
  return l.char == 'ي' ? '$base ${context.l10n.yaDotlessNote}' : base;
}

/// A letter's spoken name for the current language, from its data record.
/// Wraps [letterNameOf] so display sites and quiz answers all agree.
String letterName(BuildContext context, ArabicLetter l) =>
    letterNameOf(context, l.char);

/// A tashkīl mark's name for the current language, keyed by its id.
///
/// When [AppSettings.tashkilTerms] is `'indopak'`, the 8 marks with a
/// distinct Urdu Qaidah name (Zabar/Zair/Paish/Jazm/Shad + the 3 tanwīn)
/// use that name instead. The madd family and hamzat al-waṣl have no
/// separate Indo-Pak name — Urdu teaching uses the same Arabic terms for
/// those — so they always fall through to the switch below.
String tashkilName(BuildContext context, TashkilItem m) {
  if (SettingsScope.of(context).tashkilTerms == 'indopak') {
    switch (m.id) {
      case 'fatha':
        return context.l10n.ipZabar;
      case 'kasra':
        return context.l10n.ipZair;
      case 'damma':
        return context.l10n.ipPaish;
      case 'sukun':
        return context.l10n.ipJazm;
      case 'shadda':
        return context.l10n.ipShad;
      case 'fathatan':
        return context.l10n.ipDoZabar;
      case 'kasratan':
        return context.l10n.ipDoZair;
      case 'dammatan':
        return context.l10n.ipDoPaish;
    }
  }
  return switch (m.id) {
    'kasra' => context.l10n.mkKasra,
    'damma' => context.l10n.mkDamma,
    'sukun' => context.l10n.mkSukun,
    'shadda' => context.l10n.mkShadda,
    'fathatan' => context.l10n.mkFathatan,
    'kasratan' => context.l10n.mkKasratan,
    'dammatan' => context.l10n.mkDammatan,
    'madd2' => context.l10n.mkMadd2,
    'lin' => context.l10n.mkLin,
    'maddah' => context.l10n.mkMaddah,
    'madd4' => context.l10n.mkMadd4,
    'madd45' => context.l10n.mkMadd45,
    'madd6' => context.l10n.mkMadd6,
    'madd246' => context.l10n.mkMadd246,
    'wasl' => context.l10n.mkWasl,
    _ => context.l10n.mkFatha,
  };
}

/// A tashkīl mark's teaching note for the current language.
String tashkilNote(BuildContext context, TashkilItem m) => switch (m.id) {
      'kasra' => context.l10n.mnKasra,
      'damma' => context.l10n.mnDamma,
      'sukun' => context.l10n.mnSukun,
      'shadda' => context.l10n.mnShadda,
      'fathatan' => context.l10n.mnFathatan,
      'kasratan' => context.l10n.mnKasratan,
      'dammatan' => context.l10n.mnDammatan,
      'madd2' => context.l10n.mnMadd2,
      'lin' => context.l10n.mnLin,
      'maddah' => context.l10n.mnMaddah,
      'madd4' => context.l10n.mnMadd4,
      'madd45' => context.l10n.mnMadd45,
      'madd6' => context.l10n.mnMadd6,
      'madd246' => context.l10n.mnMadd246,
      'wasl' => context.l10n.mnWasl,
      _ => context.l10n.mnFatha,
    };

// ── Tajwīd rules ──────────────────────────────────────────────────────────
// The rule's NAME is the Arabic term itself (إقلاب, غُنَّة …). Arabic and Urdu
// readers see it in Arabic script; the Latin languages keep the scholarly
// transliteration (Iqlāb, Ghunnah) that their tajwīd literature uses. The
// English `name` in the data is that transliteration.

/// The rule's display name for the current language.
String tajwidName(BuildContext context, TajwidRule r) {
  final lang = Localizations.localeOf(context).languageCode;
  return (lang == 'ar' || lang == 'ur') ? r.arabicName : r.name;
}

/// "When the rule applies", localized, keyed by rule id.
String tajwidTrigger(BuildContext context, TajwidRule r) => switch (r.id) {
      'izhar' => context.l10n.tjIzharTrig,
      'idgham_g' => context.l10n.tjIdghamGTrig,
      'idgham_ng' => context.l10n.tjIdghamNgTrig,
      'iqlab' => context.l10n.tjIqlabTrig,
      'ikhfa' => context.l10n.tjIkhfaTrig,
      'qalqalah' => context.l10n.tjQalqalahTrig,
      'ikhfa_shafawi' => context.l10n.tjIkhfaShafawiTrig,
      'idgham_shafawi' => context.l10n.tjIdghamShafawiTrig,
      'madd2' => context.l10n.tjMadd2Trig,
      'madd4' => context.l10n.tjMadd4Trig,
      'madd45' => context.l10n.tjMadd45Trig,
      'madd6' => context.l10n.tjMadd6Trig,
      'shamsiyya' => context.l10n.tjShamsiyyaTrig,
      'qamariyya' => context.l10n.tjQamariyyaTrig,
      'tafkhim' => context.l10n.tjTafkhimTrig,
      _ => context.l10n.tjGhunnahTrig,
    };

/// "How to perform it", localized, keyed by rule id.
String tajwidHow(BuildContext context, TajwidRule r) => switch (r.id) {
      'izhar' => context.l10n.tjIzharHow,
      'idgham_g' => context.l10n.tjIdghamGHow,
      'idgham_ng' => context.l10n.tjIdghamNgHow,
      'iqlab' => context.l10n.tjIqlabHow,
      'ikhfa' => context.l10n.tjIkhfaHow,
      'qalqalah' => context.l10n.tjQalqalahHow,
      'ikhfa_shafawi' => context.l10n.tjIkhfaShafawiHow,
      'idgham_shafawi' => context.l10n.tjIdghamShafawiHow,
      'madd2' => context.l10n.tjMadd2How,
      'madd4' => context.l10n.tjMadd4How,
      'madd45' => context.l10n.tjMadd45How,
      'madd6' => context.l10n.tjMadd6How,
      'shamsiyya' => context.l10n.tjShamsiyyaHow,
      'qamariyya' => context.l10n.tjQamariyyaHow,
      'tafkhim' => context.l10n.tjTafkhimHow,
      _ => context.l10n.tjGhunnahHow,
    };
