// Exports every piece of teaching content the app shows — as users see it,
// in each of its languages — for the content review page
// (tools/content_review/index.html), and builds the single-file page to send
// to a reviewer (build/content_review/qiraah_review.html).
//
//   flutter test tool/content_review/gen_content_test.dart
//
// The lesson trees are built with a real localized BuildContext, once per
// language, so the export holds exactly the text each screen shows. Items are
// keyed by stable ids ('lesson:<node id>', 'letter:<char>', 'nabr:drill:<id>',
// …) so a review made today still lines up after the content changes; each
// item's hash tells the page what changed since it was reviewed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/extra_letters.dart';
import 'package:qiraah_arabiyyah/data/glyph_names.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/qiraat.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';
import 'package:qiraah_arabiyyah/data/tajwid_path.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/data/tracing_levels.dart';
import 'package:qiraah_arabiyyah/data/votd.dart';
import 'package:qiraah_arabiyyah/screens/dyslexia_screen.dart' show sprintWords;
import 'package:qiraah_arabiyyah/screens/lessons/forms_lessons.dart';
import 'package:qiraah_arabiyyah/screens/lessons/qaidah_lessons.dart';
import 'package:qiraah_arabiyyah/screens/lessons/script_lessons.dart';
import 'package:qiraah_arabiyyah/screens/lessons/tajwid_lessons.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart'
    show qaidahUnits, quranWords;
import 'package:qiraah_arabiyyah/screens/script_screen.dart' show scriptUnits;
import 'package:qiraah_arabiyyah/screens/tajweed_screen.dart' show tajwidUnits;
import 'package:qiraah_arabiyyah/widgets/lesson.dart';

const _locales = ['en', 'ar', 'ur', 'fr', 'es'];
const _outJs = 'tools/content_review/content.js';
const _page = 'tools/content_review/index.html';
const _outHtml = 'build/content_review/qiraah_review.html';

/// One reviewable item: its localized fields (field → language → text), the
/// Arabic it shows, its Qur'ān references and examples, and where it appears.
class _Item {
  final String id;
  final String kind;
  final String section;
  final List<String> path;
  final Map<String, Map<String, String>> fields = {};
  final List<String> order = [];
  String arabic = '';
  final List<Map<String, String>> examples = [];
  final Set<String> appearsIn = {};
  String? svg;
  Object? raw; // structured content (the Nabr blocks), shown as is
  final Set<String> flags = {};
  _Item(this.id, this.kind, this.section, this.path);

  void set(String field, String loc, String text) {
    if (text.isEmpty) return;
    if (!fields.containsKey(field)) order.add(field);
    (fields[field] ??= {})[loc] = text;
  }

  /// The same text in every language (data written once, e.g. in Arabic).
  void same(String field, String text) {
    for (final l in _locales) {
      set(field, l, text);
    }
  }

  Map<String, Object?> toJson() {
    final body = <String, Object?>{
      'id': id,
      'kind': kind,
      'section': section,
      'path': path,
      'fields': [
        for (final f in order)
          {
            'key': f,
            'text': fields[f],
            if (_englishOnly(fields[f]!)) 'englishOnly': true,
          },
      ],
      if (arabic.isNotEmpty) 'arabic': arabic,
      if (examples.isNotEmpty) 'examples': examples,
      if (svg != null) 'svg': svg,
      if (raw != null) 'raw': raw,
      if (appearsIn.length > 1) 'appearsIn': appearsIn.toList()..sort(),
    };
    final f = {...flags};
    if (order.any((k) => _englishOnly(fields[k]!))) f.add('englishOnly');
    if (f.isNotEmpty) body['flags'] = f.toList()..sort();
    body['hash'] = _hash(jsonEncode({...body}..remove('appearsIn')));
    return body;
  }
}

/// Text shown the same, in Latin letters, in every language: written in
/// English only, never translated.
bool _englishOnly(Map<String, String> t) {
  final en = t['en'];
  if (en == null || !RegExp('[A-Za-z]{3}').hasMatch(en)) return false;
  return _locales.every((l) => t[l] == en);
}

/// FNV-1a (64-bit) of [s]'s UTF-8: a content fingerprint, not security.
String _hash(String s) {
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in utf8.encode(s)) {
    h = ((h ^ BigInt.from(b)) * prime) & mask;
  }
  return h.toRadixString(16).padLeft(16, '0');
}

class _Export {
  final items = <String, _Item>{};
  final sections = <Map<String, Object?>>[];
  final _sectionItems = <String, List<String>>{};

  _Item item(String id, String kind, String section, List<String> path) {
    final it = items.putIfAbsent(id, () => _Item(id, kind, section, path));
    it.appearsIn.add([section, ...path].join(' › '));
    final list = _sectionItems[section] ??= [];
    if (!list.contains(id)) list.add(id);
    return it;
  }

  /// A section in the sidebar ([parent] null: top level), titled per
  /// language.
  void section(String id, Map<String, String> title, {String? parent}) {
    if (sections.any((s) => s['id'] == id)) return;
    sections.add({'id': id, 'title': title, 'parent': ?parent});
  }

  void setSectionTitle(String id, String loc, String title) {
    final s = sections.firstWhere((s) => s['id'] == id);
    (s['title'] as Map<String, String>)[loc] = title;
  }

  /// A lesson tree as users see it: every node an item, its children under
  /// it.
  void lesson(LessonNode n, String section, String loc, List<String> path) {
    final it = item('lesson:${n.id}', 'lesson', section, path);
    it.set('title', loc, n.title);
    it.set('summary', loc, n.summary);
    if (n.group.isNotEmpty) it.set('group', loc, n.group);
    if (n.arabicName.isNotEmpty) it.arabic = n.arabicName;
    if (it.arabic.isEmpty && n.glyph.isNotEmpty) it.arabic = n.glyph;
    if (n.locked) it.flags.add('locked');
    if (n.customDetail != null) it.flags.add('customDetail');
    if (n.svg.isNotEmpty) it.svg ??= _svg(n.svg);
    final d = n.detail;
    if (d != null) {
      if (d.hero.isNotEmpty) it.arabic = d.hero;
      it.set('intro', loc, d.intro);
      for (final (i, (label, value)) in d.facts.indexed) {
        it.set('fact$i', loc, '$label: $value');
      }
      if (d.letters.isNotEmpty) it.same('letters', d.letters);
      final b = d.build;
      if (b != null) {
        it.set('build', loc, b.caption);
        final cells = [
          for (final (op, glyph, caption) in b.cells)
            '${op.isEmpty ? '' : '$op '}$glyph ($caption)',
          for (final c in b.shapeCells)
            '${c.op.isEmpty ? '' : '${c.op} '}${c.glyph} (${c.caption})',
        ];
        if (cells.isNotEmpty) it.set('buildCells', loc, cells.join('  ·  '));
      }
      if (d.heroSvg.isNotEmpty) it.svg ??= _svg(d.heroSvg);
      if (loc == 'en') {
        for (final e in d.examples) {
          it.examples.add({
            'text': e.text,
            'ref': e.ref,
            if (e.highlight != null) 'highlight': e.highlight!,
          });
        }
        for (final e in d.shapeExamples) {
          it.examples.add({
            'text': e.text,
            'ref': e.ref,
            if (e.highlight != null) 'highlight': e.highlight!,
          });
        }
      }
    }
    for (final c in n.children) {
      lesson(c, section, loc, [...path, if (n.title.isNotEmpty) n.title]);
    }
  }

  Map<String, Object?> toJson() => {
        'app': 'qiraah_arabiyyah',
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'locales': _locales,
        'sections': [
          for (final s in sections) {...s, 'items': _sectionItems[s['id']] ?? []},
        ],
        'items': {for (final e in items.entries) e.key: e.value.toJson()},
      };
}

final _svgCache = <String, String?>{};

/// An SVG asset's markup, inlined (null if it isn't there).
String? _svg(String asset) => _svgCache.putIfAbsent(asset, () {
      final f = File(asset);
      return f.existsSync() ? f.readAsStringSync() : null;
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export the app\'s teaching content', (tester) async {
    final x = _Export();
    for (final loc in _locales) {
      late BuildContext ctx;
      final settings = AppSettings()..language = loc;
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(loc),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));
      await tester.pumpAndSettle();
      // ignore: use_build_context_synchronously
      _exportLocale(x, ctx, loc);
    }
    _exportNabr(x);

    final json = const JsonEncoder.withIndent(' ').convert(x.toJson());
    File(_outJs).writeAsStringSync(
        '// Generated by tool/content_review/gen_content_test.dart — do not '
        'edit.\nwindow.CONTENT = $json;\n');
    _buildSingleFile(json);
    // ignore: avoid_print
    print('${x.items.length} items in ${x.sections.length} sections → '
        '$_outJs, $_outHtml');
    expect(x.items, isNotEmpty);
  });
}

void _exportLocale(_Export x, BuildContext ctx, String loc) {
  final l = ctx.l10n;
  void top(String id, String title) {
    x.section(id, {});
    x.setSectionTitle(id, loc, title);
  }

  void sub(String id, String parent, String title) {
    x.section(id, {}, parent: parent);
    x.setSectionTitle(id, loc, title);
  }

  // ── Qāʿidah path ──
  top('qaidah', l.qaidahPath);
  final qRoots = <String, LessonNode Function()>{
    'qaidah.forms': () => specialShapesLessonRoot(ctx),
    'qaidah.harakat': () => harakatLessonRoot(ctx),
    'qaidah.tanwin': () => tanwinLessonRoot(ctx),
    'qaidah.sukun': () => sukunLessonRoot(ctx),
    'qaidah.shadda': () => shaddaLessonRoot(ctx),
    'qaidah.madd': () => tashkilLessonRoot(ctx, focusCounts: true),
    'qaidah.wasl': () => waslLessonRoot(ctx),
    'qaidah.muqattaat': () => muqattaatLessonRoot(ctx),
    'qaidah.review': () => reviewLessonRoot(ctx),
  };
  // The letters, taught family by family (lib/learn/qaidah): their data.
  sub('qaidah.letters', 'qaidah', l.qcSectionLetters);
  _letters(x, ctx, loc, 'qaidah.letters');
  for (final (i, u) in qaidahUnits(ctx).indexed) {
    final sec = u.progressId;
    sub(sec, 'qaidah', '${i + 1} · ${u.title}');
    final card = x.item('unit:${u.progressId}', 'unit', sec, const []);
    card
      ..set('title', loc, u.title)
      ..set('subtitle', loc, u.subtitle)
      ..arabic = u.arabicBadge;
    final root = qRoots[u.progressId];
    if (root != null) x.lesson(root(), sec, loc, const []);
    if (u.progressId == 'qaidah.words') {
      for (final (ar, tr) in quranWords) {
        x.item('word:$tr', 'word', sec, const [])
          ..arabic = ar
          ..same('translit', tr);
      }
    }
  }

  // ── Tajwīd Academy ──
  top('tajwid', l.tajwidAcademy);
  for (final (i, u) in tajwidUnits(ctx).indexed) {
    final sec = u.progressId;
    sub(sec, 'tajwid', '${i + 1} · ${u.title}');
    x.item('unit:${u.progressId}', 'unit', sec, const [])
      ..set('title', loc, u.title)
      ..set('subtitle', loc, u.subtitle)
      ..arabic = u.arabicBadge;
    final topicId = u.progressId.substring('tajwid.'.length);
    final LessonNode root = switch (topicId) {
      'makharij' => makharijLessonRoot(ctx),
      'sifat' => sifatLessonRoot(ctx),
      'madd' => maddLessonRoot(ctx),
      'cases' => casesLessonRoot(ctx),
      _ => ruleFamilyLessonRoot(ctx, topicId, u.title,
          tajwidTopicById(topicId).ruleIds.map(ruleById).toList()),
    };
    x.lesson(root, sec, loc, const []);
  }

  // ── Tashkīl Lab ──
  top('tashkil', l.tashkilLab);
  x.lesson(tashkilLessonRoot(ctx), 'tashkil', loc, const []);

  // ── Script & Symbols ──
  top('script', l.scriptSymbols);
  final sRoots = <String, LessonNode Function()>{
    'script.families': () => familiesLessonRoot(ctx),
    'script.marks': () => marksLessonRoot(ctx),
    'script.waqf': () => waqfLessonRoot(ctx),
    'script.page': () => pageLessonRoot(ctx),
  };
  for (final (i, u) in scriptUnits(ctx).indexed) {
    final sec = u.progressId;
    sub(sec, 'script', '${i + 1} · ${u.title}');
    x.item('unit:${u.progressId}', 'unit', sec, const [])
      ..set('title', loc, u.title)
      ..set('subtitle', loc, u.subtitle)
      ..arabic = u.arabicBadge;
    x.lesson(sRoots[u.progressId]!(), sec, loc, const []);
  }

  // ── Tracing Studio ──
  top('tracing', l.tracingStudio);
  for (final lv in tracingLevels) {
    x.item('tracing:${lv.id}', 'tracing', 'tracing', const [])
      ..set('title', loc, levelNameOf(ctx, lv.id))
      ..set('tier', loc, tierLabelOf(ctx, lv.tier))
      ..set('glyphs', loc,
          [for (final g in lv.glyphs) glyphNameOf(ctx, g)].join(' · '))
      ..arabic = [for (final g in lv.glyphs) g.char].join(' ');
  }

  // ── Reading Coach ──
  top('coach', l.readingCoach);
  for (final e in similarFamilies.entries) {
    x.item('family:${e.key}', 'family', 'coach', const [])
      ..same('title', e.key)
      ..arabic = e.value.join(' ');
  }
  for (final (i, w) in sprintWords.indexed) {
    x.item('sprint:$i', 'word', 'coach', const []).arabic = w;
  }

  // ── Qirāʾāt Hall ──
  top('qiraat', l.qiraHallAdvanced);
  for (final q in qiraat) {
    x.item('qiraah:${q.reader}', 'qiraah', 'qiraat', const [])
      ..arabic = q.arabic
      ..same('title', q.reader)
      ..same('city', q.city)
      ..same('died', '${q.died} AH')
      ..same('rawis', '${q.rawi1} · ${q.rawi2}')
      ..same('signatures', q.signatures.join(' · '))
      ..same('bio', q.bio);
  }
  for (final d in qiraatDifferences) {
    x.item('qiraatDiff:${d.ref}', 'qiraatDiff', 'qiraat', const [])
      ..same('topic', d.topic)
      ..same('hafs', d.hafs)
      ..same('variant', d.variant)
      ..same('readBy', d.readBy)
      ..same('note', d.note)
      ..examples.add({'text': d.hafs, 'ref': d.ref});
  }

  // ── Today ──
  top('today', l.navToday);
  for (final v in votdPool) {
    x.item('votd:${v.s}:${v.v}', 'votd', 'today', const [])
      ..arabic = v.ar
      ..same('ref', v.ref);
  }

  // ── Text kept twice: the Dart copy and the translation files differ ──
  if (loc == 'en') {
    top('drift', 'Text kept twice');
    x.setSectionTitle('drift', 'ar', 'نصوص مكرّرة بنسختين');
    for (final m in tashkil) {
      final arb = tashkilNote(ctx, m);
      if (m.note.isNotEmpty && arb.isNotEmpty && m.note != arb) {
        x.item('drift:tashkil:${m.id}', 'drift', 'drift', const [])
          ..arabic = m.mark
          ..same('dart', m.note)
          ..same('arb', arb)
          ..flags.add('dartArbDiffer');
      }
    }
    for (final r in tajwidRules) {
      for (final (field, dart, arb) in [
        ('trigger', r.trigger, tajwidTrigger(ctx, r)),
        ('how', r.how, tajwidHow(ctx, r)),
      ]) {
        if (dart.isNotEmpty && arb.isNotEmpty && dart != arb) {
          x.item('drift:tajwid:${r.id}:$field', 'drift', 'drift', const [])
            ..arabic = r.arabicName
            ..same('dart', dart)
            ..same('arb', arb)
            ..flags.add('dartArbDiffer');
        }
      }
    }
  }
}

/// Unit 1's letters: each letter, its shapes' example words, and the
/// letters beyond the 28.
void _letters(_Export x, BuildContext ctx, String loc, String sec) {
  for (final l in letters) {
    final it = x.item('letter:${l.char}', 'letter', sec, const [])
      ..arabic = l.char
      ..set('title', loc, letterName(ctx, l))
      ..same('translit', l.translit)
      ..set('dots', loc, dotsDescForLetter(ctx, l));
    if (loc == 'en') {
      it.examples.add({'text': l.exampleWord, 'ref': l.exampleRef});
      for (final e in letterExamples[l.char] ?? const <LetterExample>[]) {
        it.examples.add({'text': e.word, 'ref': '', 'note': '${e.position} · ${e.translit}'});
      }
    }
  }
  for (final l in extraLetters) {
    final it = x.item('extraLetter:${l.char}', 'letter', sec, const [])
      ..arabic = l.char
      ..set('title', loc, letterName(ctx, l))
      ..same('note', extraLetterNotes[l.char] ?? '');
    if (loc == 'en') {
      it.examples.add({'text': l.exampleWord, 'ref': l.exampleRef});
      for (final (w, ref, hl) in extraLetterMoreExamples[l.char] ?? const <(String, String, String)>[]) {
        it.examples.add({'text': w, 'ref': ref, 'highlight': hl});
      }
    }
  }
}

/// The Nabr module's content (assets/nabr), item by item: each lesson block,
/// drill, quiz question, colour-guide level, the engine's golden tests, the
/// special locations and the intonation hints.
void _exportNabr(_Export x) {
  final c = jsonDecode(File('assets/nabr/nabr_content.json').readAsStringSync())
      as Map<String, dynamic>;
  Map<String, String> both(Object? ar, Object? en) =>
      {'en': '${en ?? ''}', 'ar': '${ar ?? ''}'};
  final meta = c['meta'] as Map<String, dynamic>;
  x.section('nabr', both((meta['title'] as Map)['ar'], (meta['title'] as Map)['en']));

  x.section('nabr.about', both('عن المادة', 'About'), parent: 'nabr');
  x.item('nabr:meta', 'nabr.meta', 'nabr.about', const []).raw = meta;

  x.section('nabr.colours', both('دليل الألوان', 'Colour guide'), parent: 'nabr');
  final guide = c['colourGuide'] as Map<String, dynamic>;
  x.item('nabr:colourGuide', 'nabr.guide', 'nabr.colours', const []).raw = {
    'principle': guide['principle'],
  };
  for (final lv in (guide['levels'] as List).cast<Map<String, dynamic>>()) {
    x.item('nabr:level:${lv['id']}', 'nabr.level', 'nabr.colours', const []).raw = lv;
  }
  for (final (i, m) in ((guide['modifiers'] as List?) ?? const []).indexed) {
    final id = (m as Map)['id'] ?? '$i';
    x.item('nabr:modifier:$id', 'nabr.level', 'nabr.colours', const []).raw = m;
  }

  for (final part in (c['lessons'] as List).cast<Map<String, dynamic>>()) {
    final pid = 'nabr.${part['id']}';
    x.section(pid, both(part['titleAr'], part['titleEn']), parent: 'nabr');
    for (final ch in (part['chapters'] as List).cast<Map<String, dynamic>>()) {
      final cid = 'nabr.${ch['id']}';
      x.section(cid, both(ch['titleAr'], ch['titleEn']), parent: pid);
      for (final (i, b) in (ch['blocks'] as List).indexed) {
        x.item('nabr:${ch['id']}#b$i', 'nabr.block', cid, const []).raw = {
          ...(b as Map<String, dynamic>),
          if (i == 0 && ch['ruleId'] != null) 'ruleId': ch['ruleId'],
        };
      }
    }
  }

  x.section('nabr.drills', both('تدريبات', 'Practice drills'), parent: 'nabr');
  for (final d in (c['drills'] as List).cast<Map<String, dynamic>>()) {
    x.item('nabr:drill:${d['id']}', 'nabr.drill', 'nabr.drills', const []).raw = d;
  }
  x.section('nabr.quiz', both('اختبار', 'Quiz'), parent: 'nabr');
  for (final q in (c['quiz'] as List).cast<Map<String, dynamic>>()) {
    x.item('nabr:quiz:${q['id']}', 'nabr.quiz', 'nabr.quiz', const []).raw = q;
  }

  final golden = jsonDecode(
      File('tool/nabr/nabr_golden_tests.json').readAsStringSync()) as Map<String, dynamic>;
  x.section('nabr.golden', both('أمثلة الكتاب للمحرّك', "The book's examples (engine tests)"),
      parent: 'nabr');
  for (final t in (golden['tests'] as List).cast<Map<String, dynamic>>()) {
    x.item('nabr:golden:${t['id']}', 'nabr.golden', 'nabr.golden', const []).raw = t;
  }

  final special = jsonDecode(
      File('tool/nabr/nabr_special_locations.json').readAsStringSync()) as Map<String, dynamic>;
  x.section('nabr.special', both('المواضع الخاصة', 'Special locations'), parent: 'nabr');
  for (final g in (special['groups'] as List).cast<Map<String, dynamic>>()) {
    x.item('nabr:special:${g['id']}', 'nabr.special', 'nabr.special', const []).raw = g;
  }

  final hints = jsonDecode(
      File('tool/nabr/nabr_intonation_hints.json').readAsStringSync()) as Map<String, dynamic>;
  x.section('nabr.intonation', both('التنغيم', 'Intonation hints'), parent: 'nabr');
  for (final e in hints.entries) {
    if (e.value is! List) continue;
    for (final (i, h) in (e.value as List).indexed) {
      x.item('nabr:tone:${e.key}:$i', 'nabr.tone', 'nabr.intonation', const []).raw = {
        'group': e.key,
        ...(h as Map<String, dynamic>),
      };
    }
  }
}

/// The page with its content, fonts and styles in one file — to send to a
/// reviewer. (JSZip, for zipped exports, still loads from cdnjs.)
void _buildSingleFile(String json) {
  var html = File(_page).readAsStringSync();
  html = html.replaceFirst('<script src="content.js"></script>',
      '<script>window.CONTENT = $json;</script>');
  html = html.replaceAllMapped(
      RegExp(r"url\('\.\./\.\./assets/fonts/([^']+)'\)"), (m) {
    final bytes = File('assets/fonts/${m[1]}').readAsBytesSync();
    final type = m[1]!.endsWith('.otf') ? 'font/otf' : 'font/ttf';
    return "url('data:$type;base64,${base64Encode(bytes)}')";
  });
  Directory('build/content_review').createSync(recursive: true);
  File(_outHtml).writeAsStringSync(html);
}
