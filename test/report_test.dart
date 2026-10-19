import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/report.dart';
import 'package:qiraah_arabiyyah/core/marks/review.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/marks/report_pdf.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The marks report: which marks, grouped how, and a real PDF made from
/// verse images painted off the glyph atlas.
///
/// Set REPORT_PDF=/some/file.pdf to keep the PDF for a look.
const _keep = String.fromEnvironment('REPORT_PDF');

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
  });

  Future<ReportPdfInput> prepare(WidgetTester tester, MarksStore m,
      Report report, String lang) async {
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
    return (await tester.runAsync(() => prepareReport(ctx, report, 'uthmani')))!;
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
    expect(kursi.marks.first.comment!.text, 'Lengthen the madd');
    expect(input.groups[0].ayahs.single.marks.single.fixed, isTrue);
    expect(input.groups[0].name, isNotNull, reason: 'the Arabic name');
    // A comment in Arabic goes in painted (the pdf package can't join it).
    final hes = input.groups[2].ayahs.single.marks.single;
    expect(hes.comment!.image, isNotNull);
    expect(hes.replies.single.text, 'You: Again tomorrow');

    final bytes = (await tester.runAsync(() => buildReportPdf(input)))!;
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(20000));
    if (_keep.isNotEmpty) File(_keep).writeAsBytesSync(bytes);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // the marks' save timer
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
