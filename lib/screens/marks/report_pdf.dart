import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'export_delivery.dart' show ExportOut, deliverExport;
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/report.dart';
import '../../core/marks/review.dart';
import '../../core/marks/word_ref.dart';
import '../../core/profiles.dart' show ProfileScope;
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/quran.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../mushaf/mushaf_line.dart';
import '../mushaf/verse_view.dart';
import 'export_sheet.dart';
import 'marking.dart';
import '../../ui/bidi.dart';

// ─────────────────────────── the options sheet ───────────────────────────

/// The export sheet on Report, its marks in [query]'s status.
Future<void> showReportSheet(
  BuildContext context, {
  required MarksStore store,
  required String bookId,
  required String script,
  ReviewQuery? query,
}) =>
    showExportSheet(context,
        store: store,
        bookId: bookId,
        script: script,
        kind: ExportKind.report,
        status: query?.status ?? ReviewStatus.any);

// ─────────────────────────── making the report ───────────────────────────

/// An export's file name: `[name]_marks_[first]-[last]_[date].pdf`, with
/// [name] kept as it's written (Arabic too), less what a file name can't hold.
/// Exported by verses, those are the range ([verses], `2.255-3.10`).
String marksPdfName(String name, int first, int last, DateTime date, {String? verses}) {
  final safe = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return '${safe.isEmpty ? 'Rasikh' : safe}_marks_${verses ?? '$first-$last'}_'
      '${DateFormat('yyyy-MM-dd').format(date)}.pdf';
}

/// Whose an export is: the profile's name, else the mark book's (the default
/// profile has none of its own).
String exportOwnerName(BuildContext context, String bookName) {
  final profile = ProfileScope.maybeOf(context)?.active.name.trim() ?? '';
  return profile.isEmpty ? bookName : profile;
}

/// Each mark of [report], numbered in the report's order (by mark id).
Map<String, int> reportNumbers(Report report) {
  var n = 0;
  return {
    for (final g in report.groups)
      for (final a in g.ayahs)
        for (final m in a.marks) m.mark.id: ++n,
  };
}

/// A fixed mark's colour, in the report and on the pages.
const kFixedMarkColour = 0xFF6E8F7A;

/// The pages [report]'s marks are on, in order.
List<int> reportPages(Report report) => <int>{
      for (final g in report.groups)
        for (final a in g.ayahs) a.page,
    }.toList()
      ..sort();

/// Paints [report]'s verses (a few per frame, with a progress dialog), lays
/// the PDF out off the UI thread, then hands it on as [out] asks.
///
/// [pageRange]: what it was asked for, for its name; else where its marks are.
Future<void> makeReport(BuildContext context, Report report, String script,
    {required ExportOut out, (int, int)? pageRange, String? verses}) async {
  final progress = ValueNotifier<(int, int)>((0, report.ayahCount));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (d, v, _) => Row(children: [
          const SizedBox.square(
              dimension: 22, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(d.l10n.rpMaking(v.$1, v.$2))),
        ]),
      ),
    ),
  );
  Uint8List? bytes;
  Object? error;
  try {
    final input = await prepareReport(context, report, script,
        onProgress: (done) => progress.value = (done, report.ayahCount));
    bytes = await compute(buildReportPdf, input);
  } catch (e) {
    error = e;
    debugPrint('[report] $e');
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (bytes == null) {
    showQToast(context, '$error');
    return;
  }
  final marked = reportPages(report);
  final (first, last) = pageRange ?? (marked.first, marked.last);
  final name = marksPdfName(
      exportOwnerName(context, report.bookName), first, last, DateTime.now(), verses: verses);
  await deliverExport(context, bytes, name, out);
}

/// Everything the PDF needs, as plain data: the verse images already
/// painted, every string already in the reader's language — and any string
/// in Arabic script already painted too (see [PdfText]). It crosses to
/// another isolate.
class ReportPdfInput {
  final bool rtl; // the reader's language runs right to left
  final PdfText title;
  final List<PdfText> coverLines;
  final List<PdfText> totalsHead; // kind, open, fixed
  final List<(PdfText, int, int, int)> totals; // label, colour, open, fixed
  final PdfText totalLine;
  final List<PdfGroup> groups;
  final Uint8List regular, bold;
  const ReportPdfInput(this.rtl, this.title, this.coverLines, this.totalsHead,
      this.totals, this.totalLine, this.groups, this.regular, this.bold);
}

/// A piece of text for the PDF: plain [text] where the `pdf` package can
/// set it (Latin script), else an [image] Flutter painted — the package
/// can't join Arabic letters or order a right-to-left line properly.
class PdfText {
  final String? text;
  final PdfImage? image;
  const PdfText.plain(String this.text) : image = null;
  const PdfText.painted(PdfImage this.image) : text = null;
}

class PdfGroup {
  final PdfText title;
  final PdfImage? name; // the sūrah's name in Qurʼanic script
  final List<PdfAyah> ayahs;
  const PdfGroup(this.title, this.name, this.ayahs);
}

class PdfAyah {
  final PdfText ref;
  final PdfText where;
  final PdfImage verse;
  final List<PdfMark> marks;
  const PdfAyah(this.ref, this.where, this.verse, this.marks);
}

class PdfImage {
  final Uint8List png;
  final double width, height; // points
  const PdfImage(this.png, this.width, this.height);
}

class PdfMark {
  final PdfText label;
  final int color;
  final bool fixed;
  final PdfText line;
  final PdfText? comment;
  final List<PdfText> replies;

  /// Its number on the pages before the report (Pages + report).
  final int? number;
  const PdfMark(this.label, this.color, this.fixed, this.line, this.comment,
      this.replies, {this.number});
}

/// The PDF page's text width, points (A4 less 40 pt margins).
const _textWidth = 595.0 - 80;

/// Pixels per point the images are painted at.
const _scale = 2.5;

bool _hasArabic(String s) => s.runes.any((c) =>
    (c >= 0x0600 && c <= 0x06FF) ||
    (c >= 0x0750 && c <= 0x077F) ||
    (c >= 0x08A0 && c <= 0x08FF) ||
    (c >= 0xFB50 && c <= 0xFEFF));

/// Paints every verse of [report] and gathers the strings, for
/// [buildReportPdf]. The verses are drawn exactly as the muṣḥaf draws them:
/// atlas lines (with each mark's tint and pattern) on a picture recorder.
/// [numbers]: each mark's number, by id (the report's own order if not given:
/// the pages it follows give theirs). It's on the mark's word and by its entry.
Future<ReportPdfInput> prepareReport(
    BuildContext context, Report report, String script,
    {void Function(int done)? onProgress, Map<String, int>? numbers}) async {
  // Everything taken from the context before the first await.
  final l = context.l10n;
  final store = MarksScope.maybeOf(context);
  final markNumbers = numbers ?? reportNumbers(report);
  final lang = Localizations.localeOf(context).languageCode;
  final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  final typeLabel = {for (final t in MarkType.values) t: markTypeLabel(context, t)};
  String who(String id, String name) => store != null &&
          (id == store.authorId || id == store.me.id)
      ? l.mkYou
      : (name.isEmpty ? '—' : name);
  final rtl = lang == 'ar' || lang == 'ur';
  // Arabic-script text is painted in the app's own face for the language.
  final family = lang == 'ur' ? 'NotoNastaliqUrdu' : 'NotoNaskhArabic';
  Future<PdfText> t(String s,
      {double size = 10, bool bold = false, int color = 0xFF1F2522,
      double width = _textWidth}) async {
    if (!_hasArabic(s)) return PdfText.plain(s);
    return PdfText.painted(await paintTextImage(s,
        size: size,
        family: family,
        bold: bold,
        color: Color(color),
        maxWidth: width));
  }

  const sub = 0xFF6B716D;
  final atlas = MushafAtlas.of(script) ??
      await MushafAtlas.load(script, MushafRepo.tokensSync(script));
  if (atlas == null) throw StateError('no glyph atlas for $script');
  final metas = await QuranRepo.meta();
  final paper = kMushafPapers['white']!;
  final mp = markPaletteForPaper(paper);
  final visuals =
      store?.visuals(report.bookId) ?? const <int, MarkVisual>{};

  final groups = <PdfGroup>[];
  var done = 0;
  for (final g in report.groups) {
    final ayahs = <PdfAyah>[];
    for (final a in g.ayahs) {
      final (s, n) = surahAyahFromGlobal(a.globalAyah);
      final badges = <int, List<(int, int)>>{};
      for (final m in a.marks) {
        final n = markNumbers[m.mark.id];
        if (n == null) continue;
        (badges[m.mark.ref.key] ??= []).add(
            (n, m.fix != null ? kFixedMarkColour : mp.colorOf(m.mark.type).toARGB32()));
      }
      final verse = await paintVerseImage(atlas, script, a.globalAyah,
          visuals: visuals, mp: mp, paper: paper, badges: badges);
      final marks = <PdfMark>[];
      for (final m in a.marks) {
        final line = [
          m.mark.ref.isWholeAyah ? l.rpWholeAyah : l.rpWordN(m.mark.ref.word),
          who(m.mark.authorId, m.mark.authorName),
          date.format(DateTime.fromMillisecondsSinceEpoch(m.mark.createdAt)),
          if (m.fix != null)
            l.rpFixedOn(date
                .format(DateTime.fromMillisecondsSinceEpoch(m.fix!.fixedAt))),
        ].join(' · ');
        marks.add(PdfMark(
          await t(typeLabel[m.mark.type]!, bold: true),
          mp.colorOf(m.mark.type).toARGB32(),
          m.fix != null,
          await t(line, size: 9, color: sub, width: _textWidth - 120),
          m.mark.comment.isEmpty
              ? null
              : await t(m.mark.comment, width: _textWidth - 20),
          [
            for (final c in m.replies)
              await t('${who(c.authorId, c.authorName)}: ${c.text}',
                  size: 9, color: sub, width: _textWidth - 30),
          ],
          number: markNumbers[m.mark.id],
        ));
      }
      ayahs.add(PdfAyah(
        await t('${metas[s - 1].tname} $s:$n', size: 10.5, bold: true),
        await t(l.rpWhere(a.page, juzOfRubAyah(s, n), hizbOf(s, n)),
            size: 9, color: sub),
        verse,
        marks,
      ));
      onProgress?.call(++done);
      // Let the progress dialog draw between verses.
      await Future<void>.delayed(Duration.zero);
    }
    final surah = report.options.grouping == ReportGrouping.surah;
    groups.add(PdfGroup(
      await t(
          surah
              ? '${metas[g.number - 1].tname} · ${l.rpSurahN(g.number)}'
              : l.pageN(g.number),
          size: 14,
          bold: true),
      surah
          ? await paintTextImage(metas[g.number - 1].name,
              family: 'UthmanicHafs', size: 20)
          : null,
      ayahs,
    ));
  }

  final o = report.options;
  String day(int ms) => date.format(DateTime.fromMillisecondsSinceEpoch(ms));
  Future<Uint8List> font(String f) async =>
      (await rootBundle.load('assets/fonts/$f')).buffer.asUint8List();
  return ReportPdfInput(
    rtl,
    await t(l.rpTitle, size: 22, bold: true),
    [
      await t('${l.rpBook}: ${report.bookName}', size: 11, color: sub),
      await t(
          '${l.rpPeriod}: ${o.fromMs == null && o.toMs == null ? l.rpAllTime : l.rpRange(o.fromMs == null ? '…' : day(o.fromMs!), day(o.toMs ?? report.generatedAt))}',
          size: 11,
          color: sub),
      await t(l.rpGenerated(day(report.generatedAt)), size: 11, color: sub),
    ],
    [
      const PdfText.plain(''),
      await t(l.rpOpenCol, size: 9, color: sub, bold: true),
      await t(l.rpFixedCol, size: 9, color: sub, bold: true),
    ],
    [
      for (final ty in MarkType.values)
        if ((report.openByType[ty] ?? 0) + (report.fixedByType[ty] ?? 0) > 0)
          (
            await t(typeLabel[ty]!),
            mp.colorOf(ty).toARGB32(),
            report.openByType[ty] ?? 0,
            report.fixedByType[ty] ?? 0,
          ),
    ],
    await t('${l.rvCountN(report.total)} · ${l.rpAyahsN(report.ayahCount)}',
        color: sub),
    groups,
    await font('Inter-Regular.ttf'),
    await font('Inter-Bold.ttf'),
  );
}

/// [globalAyah] painted from the glyph atlas, wrapped to the PDF's text
/// width, every mark in it tinted and underlined as in the muṣḥaf. [badges]:
/// numbers to set over words, by [WordRef.key] (number, colour).
Future<PdfImage> paintVerseImage(
  MushafAtlas atlas,
  String script,
  int globalAyah, {
  required Map<int, MarkVisual> visuals,
  required MarkPalette mp,
  required MushafPaper paper,
  double fontSize = 21,
  double width = _textWidth,
  Map<int, List<(int, int)>> badges = const {},
}) async {
  final tier = atlas.tierFor(fontSize * _scale);
  if (atlas.tiers[tier].images == null) await atlas.tiers[tier].load();
  final (first, words) = MushafRepo.ayahTokens(script, globalAyah);
  final rows = VerseView.wrap(atlas, first, words, width, fontSize);
  final slotH = VerseView.rowHeight(fontSize);
  // Room over the first row for a badge standing above its word.
  final top = badges.isEmpty ? 0.0 : _verseBadge * .6;
  final height = top + slotH * rows.length;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)
    ..scale(_scale)
    ..translate(0, top);
  for (var r = 0; r < rows.length; r++) {
    final last = r == rows.length - 1;
    final natural =
        VerseView.naturalWidth(atlas, rows[r].$1, rows[r].$2.length, fontSize);
    final spec = MushafLineSpec(
      script: script,
      page: -1 - globalAyah,
      index: r,
      line: MushafLine.text(rows[r].$2, firstTok: rows[r].$1),
      fontSize: fontSize,
      slotH: slotH,
      targetW: last ? (natural / .44 > width ? natural / .44 : width) : width,
      ink: paper.ink,
      accent: paper.acc,
      strongBg: paper.hl2,
      verseBg: paper.hl,
      marks: visuals,
      markPal: mp,
      rewrap: true,
    );
    final line = buildAtlasLine(spec, atlas, tier);
    // Right-aligned like the text (a short last row starts at the right).
    final at = Offset(width - line.width, r * slotH);
    paintAtlasLine(canvas, at, line, atlas, spec);
    // Over the word's top right, where the pages put them; a word's several
    // run on to its left.
    for (final (i, wd) in rows[r].$2.indexed) {
      final marks = badges[WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx).key];
      if (marks == null || i >= line.boxes.length) continue;
      var x = at.dx + line.boxes[i].$2;
      for (final (n, colour) in marks) {
        _paintBadge(canvas, Offset(verseBadgeX(x, width), at.dy + _verseBadge * .1), n,
            Color(colour));
        x -= _verseBadge + 1;
      }
    }
  }
  final img = await rec
      .endRecording()
      .toImage((width * _scale).ceil(), (height * _scale).ceil());
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  img.dispose();
  return PdfImage(png, width, height);
}

/// A number's badge on a verse's image, points across.
const _verseBadge = 12.0;

/// A badge's middle, kept whole inside an image [width] across (a line's first
/// word runs right up to its edge).
double verseBadgeX(double x, double width) =>
    x.clamp(_verseBadge / 2 + .5, width - _verseBadge / 2 - .5);

void _paintBadge(Canvas canvas, Offset centre, int n, Color colour) {
  canvas.drawCircle(centre, _verseBadge / 2, Paint()..color = colour);
  final tp = TextPainter(
    text: TextSpan(
        text: '$n',
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: _verseBadge * (n > 99 ? .42 : .55),
            fontWeight: FontWeight.w700,
            color: Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

/// [text] painted as an image, wrapped to [maxWidth] points — for what the
/// `pdf` package can't set: a sūrah's name in Qurʼanic script, and any
/// Arabic-script text.
Future<PdfImage> paintTextImage(
  String text, {
  double size = 10,
  String family = 'NotoNaskhArabic',
  bool bold = false,
  Color color = Colors.black,
  double maxWidth = _textWidth,
}) async {
  final rtl = _firstStrongIsArabic(text);
  final tp = TextPainter(
    text: TextSpan(
        // Arabic inline in another language's sentence stays in its place.
        text: isolateArabic(text),
        style: TextStyle(
            fontFamily: family,
            fontFamilyFallback: const ['Inter'],
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color)),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(_scale);
  tp.paint(canvas, Offset.zero);
  final w = tp.width, h = tp.height;
  final img = await rec
      .endRecording()
      .toImage((w * _scale).ceil().clamp(1, 1 << 14), (h * _scale).ceil());
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  img.dispose();
  tp.dispose();
  return PdfImage(png, w, h);
}

bool _firstStrongIsArabic(String s) {
  for (final c in s.runes) {
    if (_hasArabic(String.fromCharCode(c))) return true;
    if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c >= 0xC0 && c < 0x0600) {
      return false;
    }
  }
  return false;
}

/// Lays the report out as an A4 PDF. Pure: runs in another isolate.
Future<Uint8List> buildReportPdf(ReportPdfInput d) async {
  final doc = pw.Document(creator: 'Rāsikh');
  addReportPages(doc, d);
  return doc.save();
}

/// The report's pages, added to [doc].
void addReportPages(pw.Document doc, ReportPdfInput d) {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(d.regular)),
    bold: pw.Font.ttf(ByteData.sublistView(d.bold)),
  );
  const ink = PdfColor.fromInt(0xFF1F2522);
  const sub = PdfColor.fromInt(0xFF6B716D);
  const rule = PdfColor.fromInt(0xFFDDDDD6);

  pw.Widget swatch(int argb) => pw.Container(
        width: 9,
        height: 9,
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(argb),
          borderRadius: pw.BorderRadius.circular(2),
        ),
      );

  pw.Widget image(PdfImage i) =>
      pw.Image(pw.MemoryImage(i.png), width: i.width, height: i.height);

  pw.Widget text(PdfText t,
      {double size = 10, PdfColor color = ink, bool bold = false}) {
    final i = t.image;
    if (i != null) return image(i);
    return pw.Text(t.text!,
        style: pw.TextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));
  }

  List<pw.Widget> ordered(List<pw.Widget> cells) =>
      d.rtl ? cells.reversed.toList() : cells;

  // The count columns (and their headings) are centred: the same in either
  // direction, painted heading or set number.
  pw.Widget cell(PdfText t, {bool head = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Center(
          child: text(t,
              size: head ? 9 : 10, color: head ? sub : ink, bold: head)));

  /// An āyah's heading and verse.
  pw.Widget verse(PdfAyah a) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 10),
          pw.Row(children: [
            text(a.ref, size: 10.5, bold: true),
            pw.SizedBox(width: 8),
            text(a.where, size: 9, color: sub),
          ]),
          pw.SizedBox(height: 4),
          image(a.verse),
        ],
      );

  pw.Widget mark(PdfMark m) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, left: 4, right: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              if (m.number case final n?) ...[
                numberBadge(n, m.fixed ? 0xFF6E8F7A : m.color),
                pw.SizedBox(width: 6),
              ],
              swatch(m.fixed ? 0xFF6E8F7A : m.color),
              pw.SizedBox(width: 6),
              text(m.label, bold: true),
              pw.SizedBox(width: 6),
              pw.Flexible(child: text(m.line, size: 9, color: sub)),
            ]),
            if (m.comment case final c?)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 15, right: 15, top: 2),
                  child: text(c)),
            for (final r in m.replies)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 25, right: 25, top: 1),
                  child: text(r, size: 9, color: sub)),
          ],
        ),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    textDirection: d.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    margin: const pw.EdgeInsets.all(40),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: sub)),
    ),
    build: (ctx) => [
      // ── cover: title, book, period, totals ──
      text(d.title, size: 22, bold: true),
      pw.SizedBox(height: 6),
      for (final line in d.coverLines) text(line, size: 11, color: sub),
      pw.SizedBox(height: 14),
      // pw.Table lays its columns out left to right whatever the text
      // direction: in a right-to-left report they're put in reading order
      // here.
      pw.Table(
        border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: rule, width: .5)),
        columnWidths: {
          for (var i = 0; i < 3; i++)
            i: pw.FlexColumnWidth((d.rtl ? 2 - i : i) == 0 ? 3 : 1),
        },
        children: [
          pw.TableRow(
              children: ordered([
            for (final h in d.totalsHead) cell(h, head: true),
          ])),
          for (final (label, colour, open, fixed) in d.totals)
            pw.TableRow(
                children: ordered([
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(children: [
                  swatch(colour),
                  pw.SizedBox(width: 6),
                  text(label),
                ]),
              ),
              cell(PdfText.plain('$open')),
              cell(PdfText.plain('$fixed')),
            ])),
        ],
      ),
      pw.SizedBox(height: 6),
      text(d.totalLine, size: 10, color: sub),
      // ── the verses ──
      for (final g in d.groups) ...reportGroupBlocks(
        ctx,
        [
          // The group's heading stays with its first verse.
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: rule))),
            child: pw.Row(children: [
              text(g.title, size: 14, bold: true),
              pw.Spacer(),
              if (g.name case final n?) image(n),
            ]),
          ),
        ],
        [
          for (final a in g.ayahs)
            (() => verse(a), [for (final m in a.marks) () => mark(m)]),
        ],
      ),
    ],
  ));
}

/// The report's height to fill: an A4 page less its margins and footer.
const kReportPageHeight = 841.89 - 80 - 30;

/// A group's verses, each with its marks, comments and replies as blocks that
/// stay on one page: one that doesn't fit moves to the next page whole. One
/// taller than a page goes over several, its verse (with [lead], the group's
/// heading, on the first) at the top of each, so a comment is never apart from
/// its verse. Builders, not widgets: the verse is laid out in more than one.
List<pw.Widget> reportGroupBlocks(
  pw.Context ctx,
  List<pw.Widget> lead,
  List<(pw.Widget Function(), List<pw.Widget Function()>)> ayahs,
) {
  double heightOf(pw.Widget w) {
    w.layout(ctx, const pw.BoxConstraints(maxWidth: _textWidth));
    return w.box!.height;
  }

  final leadH = lead.isEmpty
      ? 0.0
      : heightOf(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, children: lead));

  pw.Widget block(List<pw.Widget> children, double height) {
    final column = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
    // Even alone it's over a page (a very long comment): made to fit.
    return pw.Inseparable(
      child: height <= kReportPageHeight
          ? column
          : pw.SizedBox(
              width: _textWidth,
              height: kReportPageHeight,
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.topLeft,
                child: pw.SizedBox(width: _textWidth, child: column),
              ),
            ),
    );
  }

  final out = <pw.Widget>[];
  var withLead = true;
  if (ayahs.isEmpty) {
    if (lead.isNotEmpty) out.add(block(lead, leadH));
    return out;
  }
  for (final (verse, marks) in ayahs) {
    final verseH = heightOf(verse());
    var parts = <pw.Widget>[if (withLead) ...lead, verse()];
    var height = verseH + (withLead ? leadH : 0);
    withLead = false;
    var any = false;
    for (final mark in marks) {
      final h = heightOf(mark());
      if (any && height + h > kReportPageHeight) {
        out.add(block(parts, height));
        parts = [verse()];
        height = verseH;
      }
      parts.add(mark());
      height += h;
      any = true;
    }
    out.add(block(parts, height));
  }
  return out;
}

/// A mark's number in a round badge of its colour (on the pages, and by
/// its entry in the report).
pw.Widget numberBadge(int n, int argb, {double size = 13}) => pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      // Filled in its colour, a white ring keeping it off the letters.
      decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(argb),
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: PdfColors.white, width: .9)),
      child: pw.Text('$n',
          style: pw.TextStyle(
              fontSize: size * (n > 99 ? .42 : .55),
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold)),
    );
