import 'dart:io';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/report.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/mushaf_atlas.dart';
import 'package:rasikh/ui/mark_style.dart' show markPaletteForPaper;
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/pages_pdf.dart';
import 'package:rasikh/screens/marks/report_pdf.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The marks report: which marks, grouped how, and a real PDF made from
/// verse images painted off the glyph atlas.
///
/// Set REPORT_PDF=/some/file.pdf to keep the PDF for a look.
const _keep = String.fromEnvironment('REPORT_PDF');

/// The last prepared Pages + report's sheets.
List<PrintSheet> _sheets = const [];

class _Clock {
  int t = DateTime(2026, 10, 1).millisecondsSinceEpoch;
  int call() => t;
}

Future<(MarksStore, String, _Clock)> _store() async {
  final clock = _Clock();
  final m = MarksStore(
      persistence: MemoryMarksPersistence(),
      saveDelay: Duration.zero,
      clock: clock.call);
  await m.load();
  final b = m.ensureActiveBook('Zayd').id;
  m.addMark(b, const WordRef(2, 255, 3), MarkType.mistake,
      comment: 'Lengthen the madd');
  m.addMark(b, const WordRef(2, 255, 8), MarkType.doubt);
  m.addMark(b, const WordRef(1, 2, 2), MarkType.tajwid);
  m.fix(b, const WordRef(1, 2, 2));
  clock.t = DateTime(2026, 10, 15).millisecondsSinceEpoch;
  m.addMark(b, const WordRef(3, 2, 1), MarkType.hesitation,
      comment: 'تردد عند الكلمة');
  m.addComment(m.marksAt(b, const WordRef(3, 2, 1)).single, 'Again tomorrow');
  return (m, b, clock);
}

int _page(WordRef r) => MushafRepo.pageOfWord('uthmani', r.globalAyah, r.word0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('grouped by sūrah or page, āyāt in order, totals by kind', () async {
    final (m, b, clock) = await _store();
    final r = buildReport(m, b, const ReportOptions(),
        pageOf: _page, now: clock.t);
    expect(r.bookName, 'Zayd');
    expect([for (final g in r.groups) g.number], [1, 2, 3]);
    expect(r.groups[1].ayahs.single.marks.map((x) => x.mark.type),
        [MarkType.mistake, MarkType.doubt]);
    expect(r.openByType[MarkType.mistake], 1);
    expect(r.fixedByType[MarkType.tajwid], 1);
    expect(r.total, 4);
    expect(r.ayahCount, 3);
    expect(r.groups[2].ayahs.single.marks.single.replies.single.text,
        'Again tomorrow');

    final byPage = buildReport(
        m, b, const ReportOptions(grouping: ReportGrouping.page),
        pageOf: _page, now: clock.t);
    expect([for (final g in byPage.groups) g.number],
        [1, _page(const WordRef(2, 255, 3)), _page(const WordRef(3, 2, 1))]);

    // A period: only marks made from 10 Oct on.
    final recent = buildReport(
        m,
        b,
        ReportOptions(fromMs: DateTime(2026, 10, 10).millisecondsSinceEpoch),
        pageOf: _page,
        now: clock.t);
    expect(recent.total, 1);
    // Open only.
    final open = buildReport(m, b,
        const ReportOptions(query: ReviewQuery(status: ReviewStatus.open)),
        pageOf: _page, now: clock.t);
    expect(open.total, 3);
    // Only some pages: al-Fātiḥah's.
    final first = buildReport(m, b, const ReportOptions(pages: {1}),
        pageOf: _page, now: clock.t);
    expect([for (final g in first.groups) g.number], [1]);
  });

  Future<ReportPdfInput> prepare(WidgetTester tester, MarksStore m,
      Report report, String lang, {Map<String, int>? numbers}) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    late BuildContext ctx;
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(lang),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ),
    ));
    final input = (await tester.runAsync(
        () => prepareReport(ctx, report, 'uthmani', numbers: numbers)))!;
    if (numbers == null) return input;
    // The pages before it, each mark numbered at its word.
    final pages = <int>{
      for (final g in report.groups)
        for (final a in g.ayahs) a.page
    }.toList()
      ..sort();
    final e = PagesExport(
        store: m, bookId: report.bookId, script: 'uthmani', pages: pages,
        ids: numbers.keys.toSet());
    _sheets = (await tester.runAsync(() => preparePages(ctx, e, pages, numbers: numbers)))!;
    return input;
  }

  testWidgets('a PDF with atlas-painted verses', (tester) async {
    final (m, b, clock) = await _store();
    final report =
        buildReport(m, b, const ReportOptions(), pageOf: _page, now: clock.t);
    final input = await prepare(tester, m, report, 'en');
    expect(input.rtl, isFalse);
    expect(input.groups, hasLength(3));
    final kursi = input.groups[1].ayahs.single;
    expect(kursi.ref.text, 'Al-Baqarah 2:255');
    // Āyat al-Kursī wraps over several rows of the text width.
    expect(kursi.verse.width, closeTo(515, .5));
    expect(kursi.verse.height, greaterThan(150));
    expect(kursi.verse.png.sublist(1, 4), 'PNG'.codeUnits);
    expect(kursi.marks.first.line.text, startsWith('Word 3 · You'));
    // The comment, painted in Noto Naskh Arabic as every comment is.
    expect(kursi.marks.first.comment!.image, isNotNull);
    expect(input.groups[0].ayahs.single.marks.single.fixed, isTrue);
    expect(input.groups[0].name, isNotNull, reason: 'the Arabic name');
    // A comment in Arabic goes in painted (the pdf package can't join it).
    final hes = input.groups[2].ayahs.single.marks.single;
    expect(hes.comment!.image, isNotNull);
    expect(hes.replies.single.image, isNotNull, reason: 'replies too, in the same face');

    final bytes = (await tester.runAsync(() => compute(buildReportPdf, input)
        .timeout(const Duration(seconds: 60))))!;
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(20000));
    if (_keep.isNotEmpty) File(_keep).writeAsBytesSync(bytes);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // the marks' save timer
  });

  group('a verse and its comments on one page', () {
    pw.Widget box(double h) => pw.SizedBox(height: h, width: 100);

    List<pw.Widget> blocks(List<pw.Widget> lead, double verse, List<double> marks,
        {void Function()? onVerse}) {
      late List<pw.Widget> out;
      pw.Document().addPage(pw.MultiPage(
          build: (ctx) => out = reportGroupBlocks(ctx, lead, [
                (
                  () {
                    onVerse?.call();
                    return box(verse);
                  },
                  [for (final h in marks) () => box(h)],
                ),
              ])));
      return out;
    }

    test('a verse that fits is one block, whatever it has', () {
      final out = blocks([], 100, [50, 50, 50]);
      expect(out, hasLength(1));
      expect(out.single, isA<pw.Inseparable>());
      expect((out.single as pw.Inseparable).canSpan, isFalse,
          reason: 'moves to the next page whole');
    });

    test('too long for a page: the verse again at the top of the next, with the '
        'rest of its marks', () {
      final built = <int>[];
      var verses = 0;
      final out = blocks([], 100, [for (var i = 0; i < 12; i++) 100],
          onVerse: () => built.add(++verses));
      expect(out, hasLength(2));
      for (final b in out) {
        final column = (b as pw.Inseparable);
        expect(column.canSpan, isFalse);
      }
      // Once to measure, once in each block.
      expect(verses, 3);
    });

    test('a page\'s worth is never exceeded, and even one too tall for a page '
        'can be laid out', () async {
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          footer: (_) => pw.Text('1 / 1'),
          build: (ctx) => reportGroupBlocks(ctx, [box(40)], [
                (() => box(200), [() => box(2000), () => box(700), () => box(100)]),
                (() => box(600), [() => box(150)]),
              ])));
      expect(await doc.save(), isNotEmpty);
    });
  });

  test('a badge stays whole at the image\'s edges', () {
    expect(verseBadgeX(515, 515), lessThanOrEqualTo(515 - 6));
    expect(verseBadgeX(520, 515), lessThanOrEqualTo(515 - 6));
    expect(verseBadgeX(0, 515), greaterThanOrEqualTo(6));
    expect(verseBadgeX(200, 515), 200);
  });

  testWidgets('every report numbers its marks, in the verse as by its entry',
      (tester) async {
    final (m, b, clock) = await _store();
    final report =
        buildReport(m, b, const ReportOptions(), pageOf: _page, now: clock.t);
    final input = await prepare(tester, m, report, 'en');
    expect([
      for (final g in input.groups)
        for (final a in g.ayahs)
          for (final x in a.marks) x.number
    ], [1, 2, 3, 4]);
    final plain = await tester.runAsync(() async {
      final atlas = MushafAtlas.of('uthmani') ??
          await MushafAtlas.load('uthmani', MushafRepo.tokensSync('uthmani'));
      final paper = kMushafPapers['white']!;
      final mp = markPaletteForPaper(paper);
      final g = MushafRepo.globalAyahOf(2, 255);
      final none = await paintVerseImage(atlas!, 'uthmani', g,
          visuals: const {}, mp: mp, paper: paper);
      final some = await paintVerseImage(atlas, 'uthmani', g,
          visuals: const {},
          mp: mp,
          paper: paper,
          badges: {
            const WordRef(2, 255, 3).key: [(1, 0xFFAA0000), (2, 0xFF00AA00)],
          });
      return (none, some);
    });
    expect(plain!.$2.height, greaterThan(plain.$1.height), reason: 'headroom for a badge');
    expect(plain.$2.png.length, isNot(plain.$1.png.length), reason: 'drawn');
    await m.flush();
  });

  testWidgets('pages + report: compact pages, each mark a numbered badge, '
      'the report numbered to match, one PDF', (tester) async {
    final (m, b, clock) = await _store();
    final report =
        buildReport(m, b, const ReportOptions(), pageOf: _page, now: clock.t);
    final numbers = reportNumbers(report);
    expect(numbers.values, [1, 2, 3, 4]);
    final input = await prepare(tester, m, report, 'en', numbers: numbers);
    expect([
      for (final g in input.groups)
        for (final a in g.ayahs)
          for (final x in a.marks) x.number
    ], [1, 2, 3, 4]);
    final sheets = _sheets;
    expect(sheets, hasLength(3), reason: 'one page per marked page');
    expect([for (final s in sheets) for (final x in s.badges) x.$3]..sort(), [1, 2, 3, 4]);
    for (final s in sheets) {
      expect(s.notes, isEmpty, reason: 'no notes beside it: the report has them');
      // As tall as the paper allows: half as wide again as with notes.
      expect(s.page.width, greaterThan(450), reason: 'small margins');
    }
    final bytes = (await tester.runAsync(() => buildPagesReportPdf((sheets, input))))!;
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    if (_keep.isNotEmpty) {
      File(_keep.replaceFirst('.pdf', '_both.pdf')).writeAsBytesSync(bytes);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('in Arabic the report runs right to left, labels painted',
      (tester) async {
    final (m, b, clock) = await _store();
    final report =
        buildReport(m, b, const ReportOptions(), pageOf: _page, now: clock.t);
    final input = await prepare(tester, m, report, 'ar');
    expect(input.rtl, isTrue);
    expect(input.title.image, isNotNull);
    expect(input.coverLines.first.image, isNotNull, reason: 'سجل العلامات: …');
    final bytes = (await tester.runAsync(() => buildReportPdf(input)))!;
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    if (_keep.isNotEmpty) {
      File(_keep.replaceFirst('.pdf', '_ar.pdf')).writeAsBytesSync(bytes);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
