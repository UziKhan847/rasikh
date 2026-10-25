import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// The Nabr (Qurʾānic stress) module's teaching content
/// (`assets/nabr/nabr_content.json`, after *Ṣawn al-Lisān ʿan al-Laḥn fī
/// al-Qurʾān* by Shaykh ʿAlī ʿAbd al-Tawwāb Aḥmad): lessons in parts and
/// chapters, tap-the-stressed-letter drills, a quiz and the colour guide —
/// every text in Arabic and English. Strings use markdown-lite (`**bold**`,
/// `*italic*`, `***both***`); Qurʾān quotes are in ﴿ ﴾ (see [NabrText]).
///
/// The module ships behind [kNabrEnabled] (core/settings.dart) until it has
/// been reviewed and permission confirmed.

/// A text in both languages.
class Bi {
  final String ar, en;
  const Bi(this.ar, this.en);
  factory Bi.of(Object? m) {
    final j = (m as Map?) ?? const {};
    return Bi('${j['ar'] ?? ''}', '${j['en'] ?? ''}');
  }
  bool get isEmpty => ar.isEmpty && en.isEmpty;
}

/// A word split into its letters (each with its marks; a doubled letter is
/// one token, `ـ` separates words), and which carry the stress.
class NabrExample {
  final String word;
  final List<String> tokens;
  final List<int> stressed;
  final Bi stressOn, why;
  const NabrExample(this.word, this.tokens, this.stressed, this.stressOn, this.why);

  factory NabrExample.fromJson(Map<String, dynamic> j) => NabrExample(
        '${j['word'] ?? ''}',
        [for (final t in (j['tokens'] as List? ?? const [])) '$t'],
        [for (final i in (j['stressedTokenIndices'] as List? ?? const [])) (i as num).toInt()],
        Bi.of(j['stressOn']),
        Bi('${j['whyAr'] ?? ''}', '${j['whyEn'] ?? ''}'),
      );
}

/// One block of a lesson; [type] says which fields it has.
sealed class NabrBlock {
  const NabrBlock();
  factory NabrBlock.fromJson(Map<String, dynamic> j) {
    Bi bi() => Bi('${j['ar'] ?? ''}', '${j['en'] ?? ''}');
    List<NabrExample> ex(String key) => [
          for (final e in (j[key] as List? ?? const []))
            NabrExample.fromJson((e as Map).cast<String, dynamic>()),
        ];
    return switch (j['type']) {
      'section' => NabrSection(Bi('${j['titleAr'] ?? ''}', '${j['titleEn'] ?? ''}')),
      'rule' => NabrRule('${j['num'] ?? ''}', bi()),
      'note' => NabrNote('${j['kind'] ?? 'tip'}', bi()),
      'examples' => NabrExamples(ex('items')),
      'table' => NabrTable(
          [for (final c in (j['columns'] as List? ?? const [])) Bi.of(c)],
          [
            for (final r in (j['rows'] as List? ?? const []))
              [for (final c in (r as List)) Bi.of(c)],
          ],
        ),
      'takeaways' => NabrTakeaways(
          [for (final i in (j['items'] as List? ?? const [])) Bi.of(i)]),
      'practice' => NabrPractice(
          '${j['set'] ?? ''}',
          [for (final i in (j['items'] as List? ?? const [])) '$i'],
          ex('answers'),
        ),
      _ => NabrParagraph(bi()),
    };
  }
}

class NabrParagraph extends NabrBlock {
  final Bi text;
  const NabrParagraph(this.text);
}

class NabrSection extends NabrBlock {
  final Bi title;
  const NabrSection(this.title);
}

/// A rule card — the ones to memorise.
class NabrRule extends NabrBlock {
  final String num;
  final Bi text;
  const NabrRule(this.num, this.text);
}

/// A callout: 'warning', 'tip' or 'summary'.
class NabrNote extends NabrBlock {
  final String kind;
  final Bi text;
  const NabrNote(this.kind, this.text);
}

class NabrExamples extends NabrBlock {
  final List<NabrExample> items;
  const NabrExamples(this.items);
}

class NabrTable extends NabrBlock {
  final List<Bi> columns;
  final List<List<Bi>> rows;
  const NabrTable(this.columns, this.rows);
}

class NabrTakeaways extends NabrBlock {
  final List<Bi> items;
  const NabrTakeaways(this.items);
}

/// A worksheet: the words to try, then their answers. Set B is from
/// al-Baqarah 102, set C from ʿAbasa ([ayahRef]).
class NabrPractice extends NabrBlock {
  final String set;
  final List<String> items;
  final List<NabrExample> answers;
  const NabrPractice(this.set, this.items, this.answers);

  /// Where the set's words come from in the muṣḥaf: (sūrah, āyah).
  (int, int)? get ayahRef => switch (set) {
        'B' => (2, 102),
        'C' => (80, 1),
        _ => null,
      };
}

class NabrChapter {
  final String id;
  final String? ruleId;
  final Bi title;
  final List<NabrBlock> blocks;
  const NabrChapter(this.id, this.ruleId, this.title, this.blocks);
}

class NabrPart {
  final String id;
  final Bi title;
  final List<NabrChapter> chapters;
  const NabrPart(this.id, this.title, this.chapters);
}

/// Tap the stressed letter(s) of [word]: [correct] token indices; tokens in
/// [nonSelectable] (the word separator) can't be picked. [multi]: pick all,
/// then check.
class NabrDrill {
  final String id, word, source;
  final List<String> tokens;
  final List<int> correct, nonSelectable;
  final Bi answer, explanation;
  final bool multi;
  const NabrDrill(this.id, this.word, this.source, this.tokens, this.correct,
      this.nonSelectable, this.answer, this.explanation, this.multi);

  factory NabrDrill.fromJson(Map<String, dynamic> j) {
    List<int> ints(String k) =>
        [for (final i in (j[k] as List? ?? const [])) (i as num).toInt()];
    return NabrDrill(
      '${j['id']}',
      '${j['word'] ?? ''}',
      '${j['source'] ?? ''}',
      [for (final t in (j['tokens'] as List? ?? const [])) '$t'],
      ints('correct'),
      ints('nonSelectable'),
      Bi('${j['answerAr'] ?? ''}', '${j['answerEn'] ?? ''}'),
      Bi('${j['explanationAr'] ?? ''}', '${j['explanationEn'] ?? ''}'),
      j['mode'] == 'multi',
    );
  }
}

class NabrQuestion {
  final String id, kind;
  final Bi prompt, explanation;
  final List<Bi> options;
  final int correct;
  final bool shuffle;
  const NabrQuestion(this.id, this.kind, this.prompt, this.options, this.correct,
      this.explanation, this.shuffle);

  factory NabrQuestion.fromJson(Map<String, dynamic> j) => NabrQuestion(
        '${j['id']}',
        '${j['kind'] ?? 'concept'}',
        Bi('${j['promptAr'] ?? ''}', '${j['promptEn'] ?? ''}'),
        [for (final o in (j['options'] as List? ?? const [])) Bi.of(o)],
        (j['correctIndex'] as num?)?.toInt() ?? 0,
        Bi('${j['explanationAr'] ?? ''}', '${j['explanationEn'] ?? ''}'),
        // 'Which letter' options are letters: their order doesn't matter.
        j['shuffleOptions'] == true || j['kind'] == 'whichLetter',
      );
}

/// A stress level (or a modifier): its colours in the light and dark
/// themes, what it covers, and example words.
class NabrLevel {
  final String id;
  final Bi name, desc;
  final int? light, dark;
  final List<String> examples;
  final String style;
  const NabrLevel(this.id, this.name, this.desc, this.light, this.dark,
      this.examples, this.style);

  factory NabrLevel.fromJson(Map<String, dynamic> j) {
    int? hex(Object? v) =>
        v is String && v.startsWith('#') ? int.parse('FF${v.substring(1)}', radix: 16) : null;
    return NabrLevel(
      '${j['id']}',
      Bi('${j['ar'] ?? ''}', '${j['en'] ?? ''}'),
      Bi('${j['descAr'] ?? ''}', '${j['descEn'] ?? ''}'),
      hex(j['light']),
      hex(j['dark']),
      [for (final e in (j['examples'] as List? ?? const [])) '$e'],
      '${j['style'] ?? ''}',
    );
  }
}

class NabrContent {
  final Bi title, basedOn;
  final String riwaya;
  final String principle;
  final List<NabrLevel> levels, modifiers;
  final List<NabrPart> parts;
  final List<NabrDrill> drills;
  final List<NabrQuestion> quiz;
  const NabrContent(this.title, this.basedOn, this.riwaya, this.principle,
      this.levels, this.modifiers, this.parts, this.drills, this.quiz);

  factory NabrContent.fromJson(Map<String, dynamic> j) {
    final meta = (j['meta'] as Map).cast<String, dynamic>();
    final guide = (j['colourGuide'] as Map).cast<String, dynamic>();
    List<Map<String, dynamic>> list(Object? v) =>
        [for (final e in (v as List? ?? const [])) (e as Map).cast<String, dynamic>()];
    return NabrContent(
      Bi.of(meta['title']),
      Bi.of(meta['basedOn']),
      '${meta['riwaya'] ?? ''}',
      '${guide['principle'] ?? ''}',
      [for (final l in list(guide['levels'])) NabrLevel.fromJson(l)],
      [for (final l in list(guide['modifiers'])) NabrLevel.fromJson(l)],
      [
        for (final p in list(j['lessons']))
          NabrPart('${p['id']}', Bi('${p['titleAr'] ?? ''}', '${p['titleEn'] ?? ''}'), [
            for (final c in list(p['chapters']))
              NabrChapter(
                '${c['id']}',
                c['ruleId'] as String?,
                Bi('${c['titleAr'] ?? ''}', '${c['titleEn'] ?? ''}'),
                [for (final b in list(c['blocks'])) NabrBlock.fromJson(b)],
              ),
          ]),
      ],
      [for (final d in list(j['drills'])) NabrDrill.fromJson(d)],
      [for (final q in list(j['quiz'])) NabrQuestion.fromJson(q)],
    );
  }

  NabrLevel? level(String id) {
    for (final l in levels) {
      if (l.id == id) return l;
    }
    return null;
  }

  static NabrContent? _cache;

  /// The content, parsed once from the bundled asset.
  static Future<NabrContent> load() async => _cache ??= NabrContent.fromJson(
      jsonDecode(await rootBundle.loadString('assets/nabr/nabr_content.json'))
          as Map<String, dynamic>);
}
