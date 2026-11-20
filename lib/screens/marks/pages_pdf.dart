import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat, PdfPoint;
import 'package:pdf/widgets.dart' as pw;

import '../../core/fluency/fluency_store.dart' show FluencyVisual;
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/review.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/original/original_atlas.dart';
import '../../data/quran.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../mushaf/mushaf_line.dart';
import '../mushaf/mushaf_marks_layer.dart';
import '../mushaf/original_page.dart';
import '../mushaf_screen.dart' show mushafPageForPrint;
import 'marking.dart' show markTypeLabel;
import 'export_sheet.dart';
import '../../ui/bidi.dart';
import 'export_delivery.dart' show ExportOut, deliverExport;
import 'report_pdf.dart'
    show PdfImage, ReportPdfInput, addReportPages, exportOwnerName, marksPdfName, numberBadge, paintTextImage;

// The muṣḥaf's pages as a PDF, to hand to a student: each page as the app
// draws it, its marks on it, and in the margin beside each mark its comment
// (else its kind) on a dotted line led from the word to the nearer side.

/// The export sheet on Pages, at [currentPage].
Future<void> showPagesExportSheet(
  BuildContext context, {
  required MarksStore store,
  required String bookId,
  required String script,
  required int currentPage,
}) =>
    showExportSheet(context,
        store: store,
        bookId: bookId,
        script: script,
        currentPage: currentPage,
        kind: ExportKind.pages);

/// The pages [surah] is printed on.
List<int> pagesOfSurah(String script, int surah) =>
    _pagesWhere(script, (lo, hi) {
      final (s0, _) = surahAyahFromGlobal(lo);
      final (s1, _) = surahAyahFromGlobal(hi);
      return s0 <= surah && surah <= s1;
    });

/// The pages juzʼ [juz] is printed on.
List<int> pagesOfJuz(String script, int juz) => _pagesWhere(script, (lo, hi) {
      final (s0, a0) = surahAyahFromGlobal(lo);
      final (s1, a1) = surahAyahFromGlobal(hi);
      return juzOfRubAyah(s0, a0) <= juz && juz <= juzOfRubAyah(s1, a1);
    });

/// The pages whose first and last āyah (global) pass [test].
List<int> _pagesWhere(String script, bool Function(int lo, int hi) test) {
  final out = <int>[];
  for (var p = 1; p <= MushafRepo.pageCountSync(script); p++) {
    final (first, end) = MushafRepo.pageTokens(script, p);
    if (end <= first) continue;
    final lo = MushafRepo.tokenAt(script, first).$1;
    final hi = MushafRepo.tokenAt(script, end - 1).$1;
    if (test(lo, hi)) out.add(p);
  }
  return out;
}

// ─────────────────────────── what goes in ───────────────────────────

/// What to export: [pages] of [bookId]'s muṣḥaf, with its marks of
/// [types] (none: every kind) in [status].
class PagesExport {
  final MarksStore store;
  final String bookId;
  final String script;
  final List<int> pages;
  final Set<MarkType> types;
  final ReviewStatus status;
  final bool onlyMarked;

  /// A faint line from each marked word out to its note in the margin.
  final bool lines;

  /// Only these marks (by id; null: all the filters let through) — a
  /// report's, when the pages go before it.
  final Set<String>? ids;

  /// Only marks in these verses (global āyahs, inclusive; null: anywhere).
  final (int, int)? ayahs;
  PagesExport({
    required this.store,
    required this.bookId,
    required this.script,
    required this.pages,
    this.types = const {},
    this.status = ReviewStatus.any,
    this.onlyMarked = false,
    this.lines = false,
    this.ids,
    this.ayahs,
  });

  /// The marks to show, by the page they're on.
  late final Map<int, List<Mark>> marksByPage = () {
    final out = <int, List<Mark>>{};
    for (final m in store.marksOf(bookId)) {
      if (types.isNotEmpty && !types.contains(m.type)) continue;
      if (ids != null && !ids!.contains(m.id)) continue;
      if (ayahs case (final lo, final hi)
          when m.ref.globalAyah < lo || m.ref.globalAyah > hi) {
        continue;
      }
      final fixed = store.isFixed(m);
      if (status == ReviewStatus.open && fixed) continue;
      if (status == ReviewStatus.fixed && !fixed) continue;
      final r = m.ref;
      // A whole āyah's mark sits on its ۝.
      final tok = MushafRepo.tokenOf(script, r.globalAyah, r.isWholeAyah ? -1 : r.word0);
      if (tok < 0) continue;
      (out[MushafRepo.pageOfToken(script, tok)] ??= []).add(m);
    }
    return out;
  }();

  List<int> chosenPages() =>
      onlyMarked ? [for (final p in pages) if (marksByPage[p] != null) p] : pages;

  /// How the marked words are drawn, as the muṣḥaf draws them.
  late final Map<int, MarkVisual> visuals = () {
    final byWord = <int, List<Mark>>{};
    for (final ms in marksByPage.values) {
      for (final m in ms) {
        // A mark over several words: on each of them, as on screen.
        for (final w in m.spanWords(MarksStore.ayahWords) ?? [m.ref]) {
          (byWord[w.key] ??= []).add(m);
        }
      }
    }
    final breath = store.visuals(bookId, showFixed: false, showMarks: false);
    return {
      // Breath marks show on the pages whatever the filters.
      for (final e in breath.entries)
        if (!byWord.containsKey(e.key)) e.key: e.value,
      for (final e in byWord.entries)
        e.key: () {
          MarkType? open;
          var fixed = false;
          for (final m in e.value) {
            if (store.isFixed(m)) {
              fixed = true;
            } else if (open == null ||
                MarkVisual.priority.indexOf(m.type) < MarkVisual.priority.indexOf(open)) {
              open = m.type;
            }
          }
          return MarkVisual(
              open: open,
              fixed: fixed,
              hasComment: e.value.any((m) => m.comment.isNotEmpty),
              count: e.value.length,
              stop: breath[e.key]?.stop ?? false,
              start: breath[e.key]?.start ?? false);
        }(),
    };
  }();
}

/// The export's marks, fixed: nothing changes while it's drawn.
class _FixedMarks implements MushafMarksSource {
  @override
  final Map<int, MarkVisual> visuals;
  _FixedMarks(this.visuals);
  @override
  Map<int, FluencyVisual> get fluency => const {};
  @override
  Listenable pageSignal(int page) => const _Never();
}

class _Never implements Listenable {
  const _Never();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

// ─────────────────────────── the sheet of paper ───────────────────────────

/// A4, points.
const _paperW = 595.0, _paperH = 842.0;

/// The outer margin, a margin's notes, and the gap between them and the
/// page — notes on both sides of it, each in the one nearer its word.
const _outer = 26.0, _noteW = 96.0, _gap = 12.0;
const _pageY = 52.0;

/// A note's number, above its text.
const _badge = 12.0;

/// Pixels per point the muṣḥaf page is painted at (about 216 dpi).
const _scale = 3.0;

/// Pages + report: the page nearly the paper's width, each mark numbered
/// on it rather than noted in a margin.
const _compactX = 18.0, _compactY = 40.0;

/// One sheet: the page painted, its running head and foot, each mark's
/// numbered badge on its word, and (unless the report carries them) the
/// notes in the margins, each under the same number.
class PrintSheet {
  final PdfImage page;
  final double pageX, pageY;

  /// The running head and foot, and the notes' text.
  final List<(PdfImage, double x, double y)> texts;

  /// Each number, centred at (x, y), in its mark's colour: on the words,
  /// and above the notes.
  final List<(double x, double y, int n, int colour)> badges;

  /// Each note: its number, its margin, and where it is (number and text).
  final List<(int n, bool left, Rect box)> notes;

  /// Lines from a word to its note (points x, y, …), in a faint colour.
  final List<(List<double>, int colour)> leaders;
  const PrintSheet(this.page, this.pageX, this.pageY, this.texts,
      [this.badges = const [], this.notes = const [], this.leaders = const []]);
}

/// Paints every page of [e], with a progress dialog, lays the PDF out off
/// the UI thread, then shares it ([print]: print preview).
Future<void> makePagesPdf(BuildContext context, PagesExport e,
    {required ExportOut out, String? verses}) async {
  final pages = e.chosenPages();
  final progress = ValueNotifier<(int, int)>((0, pages.length));
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
          Expanded(child: Text(d.l10n.ppMaking(v.$1, v.$2))),
        ]),
      ),
    ),
  );
  Uint8List? bytes;
  Object? error;
  try {
    final sheets = await preparePages(context, e, pages,
        onProgress: (done) => progress.value = (done, pages.length));
    bytes = await compute(buildPagesPdf, sheets);
  } catch (err, st) {
    error = err;
    debugPrint('[pages] $err\n$st');
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (bytes == null) {
    showQToast(context, '$error');
    return;
  }
  final book = e.store.books.where((b) => b.id == e.bookId).firstOrNull?.name ?? '';
  final name = marksPdfName(
      exportOwnerName(context, book), pages.first, pages.last, DateTime.now(), verses: verses);
  await deliverExport(context, bytes, name, out, pages: pages);
}

/// Each of [pages] painted and annotated, for [buildPagesPdf]. With
/// [numbers] (each mark's, by id), compact: the page nearly the paper's
/// width and each mark a numbered badge, for the report that follows.
Future<List<PrintSheet>> preparePages(
    BuildContext context, PagesExport e, List<int> pages,
    {void Function(int done)? onProgress, Map<String, int>? numbers}) async {
  final compact = numbers != null;
  // With notes: the page between the two margins.
  final pageX = compact ? _compactX : _outer + _noteW + _gap;
  final pageW = _paperW - 2 * pageX;
  final pageY = compact ? _compactY : _pageY;
  // Everything taken from the context before the first await.
  final l = context.l10n;
  final settings = SettingsScope.of(context);
  final paper = mushafPrintPaperOf(settings, e.script);
  final look = settings.mushafLook(e.script, focus: false);
  final mp = markPaletteForPaper(paper);
  final typeLabel = {for (final t in MarkType.values) t: markTypeLabel(context, t)};
  final lang = Localizations.localeOf(context).languageCode;
  final today = DateFormat.yMMMd(Localizations.localeOf(context).toString())
      .format(DateTime.now());
  final book = e.store.books.where((b) => b.id == e.bookId).firstOrNull?.name ?? '';
  final wrap = _Context(context);

  final metas = await QuranRepo.meta();
  final names = {for (final m in metas) m.n: m.name};
  final atlas = MushafAtlas.of(e.script) ??
      await MushafAtlas.load(e.script, MushafRepo.tokensSync(e.script));
  final marks = _FixedMarks(e.visuals);
  // The original print: its best set, a page at a time.
  final original =
      isOriginalScript(e.script) ? await OriginalAtlas.open(e.script, OriginalTier.high) : null;
  final holder = Object();

  final arabicUi = lang == 'ar' || lang == 'ur';
  final uiFamily = lang == 'ur'
      ? 'NotoNastaliqUrdu'
      : (arabicUi ? 'NotoNaskhArabic' : 'Inter');
  Future<PdfImage> text(String s,
          {double size = 8,
          int color = 0xFF1F2522,
          bool bold = false,
          double width = _noteW,
          String? family}) =>
      paintTextImage(s,
          size: size,
          family: family ??
              (hasArabic(s) ? (lang == 'ur' ? 'NotoNastaliqUrdu' : 'NotoNaskhArabic') : uiFamily),
          bold: bold,
          color: Color(color),
          maxWidth: width,
          rtlUi: arabicUi);

  final head = paper.acc.toARGB32();
  const sub = 0xFF6B716D;
  final sheets = <PrintSheet>[];
  var done = 0;
  for (final page in pages) {
    final box = MushafGeometry.pageBox(
        Size(pageW, _paperH - pageY - 40), e.script,
        look: look, header: false, page: page);
    // Bound by the height: as wide as that leaves it, centred.
    final size = Size(box.width, box.height);
    final x = pageX + (pageW - size.width) / 2;
    // At the top of the sheet, under its running head.
    final y = pageY;
    if (atlas != null) {
      final fs = size.width / MushafGeometry.refEmOf(e.script);
      final tier = atlas.tiers[atlas.tierFor(fs * _scale)];
      if (tier.images == null) await tier.load();
    }
    if (original != null) {
      original.hold(holder, page, page, reach: 0);
      await original.whenReady(page);
    }
    final (image, words) = await _paintOffscreen(
      wrap.wrap(mushafPageForPrint(
        page: page,
        script: e.script,
        names: names,
        paper: paper,
        look: look,
        marks: marks,
        original: original,
        classicCircle: settings.oldMadaniCircle == 'classic',
      ), settings),
      size,
    );
    final texts = <(PdfImage, double, double)>[];

    // ── the running head: sūrah · page · juzʼ, across the page ──
    final (s, _) = MushafRepo.firstVerseOfPage(e.script, page);
    final juz = MushafRepo.juzOfPage(e.script, page);
    final left = await text(metas[s - 1].tname, size: 9.5, color: head, bold: true, width: size.width / 2);
    final mid = await text('$page', size: 9.5, color: head, bold: true, width: 60);
    final right = await text(l.juzN(juz), size: 9.5, color: head, bold: true, width: size.width / 2);
    final headY = y - 24;
    texts
      ..add((left, x, headY))
      ..add((mid, x + (size.width - mid.width) / 2, headY))
      ..add((right, x + size.width - right.width, headY));
    // ── the foot: whose marks, and when ──
    final foot = await text('$book · $today', size: 7.5, color: sub, width: size.width);
    texts.add((foot, x, _paperH - 26));

    // ── compact: a numbered badge at each mark's word ──
    if (compact) {
      final badges = <(double, double, int, int)>[];
      for (final m in e.marksByPage[page] ?? const <Mark>[]) {
        final n = numbers[m.id];
        final r = m.ref;
        final at = words[(r.globalAyah, r.isWholeAyah ? -1 : r.word0)];
        if (n == null || at == null) continue;
        final colour = e.store.isFixed(m) ? 0xFF6E8F7A : mp.colorOf(m.type).toARGB32();
        badges.add((x + at.right, pageY + at.top, n, colour));
      }
      sheets.add(PrintSheet(image, x, pageY, texts, badges));
      onProgress?.call(++done);
      await Future<void>.delayed(Duration.zero);
      continue;
    }

    // ── the notes: each mark numbered on its word, in reading order, and
    // noted in the margin nearer it under the same number ──
    final ms = [
      for (final m in e.marksByPage[page] ?? const <Mark>[])
        if (words[(m.ref.globalAyah, m.ref.isWholeAyah ? -1 : m.ref.word0)] != null) m,
    ]..sort((a, b) {
        final ta = MushafRepo.tokenOf(e.script, a.ref.globalAyah, a.ref.isWholeAyah ? -1 : a.ref.word0);
        final tb = MushafRepo.tokenOf(e.script, b.ref.globalAyah, b.ref.isWholeAyah ? -1 : b.ref.word0);
        return ta != tb ? ta.compareTo(tb) : a.createdAt.compareTo(b.createdAt);
      });
    final badges = <(double, double, int, int)>[];
    final pending = <_Note>[];
    final onWord = <(int, int), int>{};
    for (final (k, m) in ms.indexed) {
      final r = m.ref;
      final key = (r.globalAyah, r.isWholeAyah ? -1 : r.word0);
      final at = words[key]!.shift(Offset(x, y));
      final colour = e.store.isFixed(m) ? 0xFF6E8F7A : mp.colorOf(m.type).toARGB32();
      // A second mark on a word: its badge beside the first.
      final nth = onWord[key] = (onWord[key] ?? -1) + 1;
      badges.add((at.right - nth * 11, at.top, k + 1, colour));
      final comment = m.comment.trim();
      pending.add(_Note(k + 1, at, colour, comment.isEmpty ? typeLabel[m.type]! : comment,
          left: at.center.dx < x + size.width / 2));
    }
    final notes = <(int, bool, Rect)>[];
    final leaders = <(List<double>, int)>[];
    final bottom = _paperH - 40;
    for (final leftSide in [true, false]) {
      final side = pending.where((n) => n.left == leftSide).toList()
        ..sort((a, b) => a.at.top != b.at.top ? a.at.top.compareTo(b.at.top) : a.n.compareTo(b.n));
      if (side.isEmpty) continue;
      // Each as level with its word as the ones above leave it; as many as
      // there are fit the margin: smaller if need be (to 5.5 pt), then the
      // longest shortened.
      var fontSize = 8.0;
      var cut = 0; // characters a note keeps; 0: all of it
      final laid = <(_Note, PdfImage, double)>[];
      while (true) {
        laid.clear();
        var below = y - 8;
        for (final n in side) {
          final shown = cut > 0 && n.label.length > cut ? '${n.label.substring(0, cut)}…' : n.label;
          // The notes in Noto Naskh Arabic, Arabic or not: all alike.
          final img = await text(shown, size: fontSize, width: _noteW, family: 'NotoNaskhArabic');
          final top = math.max(n.at.top - _badge / 2, below);
          laid.add((n, img, top));
          below = top + _badge + 2 + img.height + 6;
        }
        if (below - 6 <= bottom || (fontSize <= 5.5 && cut > 0 && cut <= 24)) break;
        if (fontSize > 5.5) {
          fontSize = math.max(5.5, fontSize * .88);
        } else {
          cut = cut == 0 ? 120 : (cut * .7).round();
        }
      }
      // Still past the foot: the last ones moved up, as little as will do.
      var limit = bottom;
      for (var i = laid.length - 1; i >= 0; i--) {
        final (n, img, top) = laid[i];
        final h = _badge + 2 + img.height;
        if (top + h > limit) laid[i] = (n, img, limit - h);
        limit = laid[i].$3 - 6;
      }
      for (final (n, img, top) in laid) {
        final colX = leftSide ? _outer : _paperW - _outer - _noteW;
        // The number at the outer edge; the text under it, from that edge.
        final badgeX = leftSide ? _outer + _badge / 2 : _paperW - _outer - _badge / 2;
        final badgeY = top + _badge / 2;
        badges.add((badgeX, badgeY, n.n, n.colour));
        texts.add((img, leftSide ? _outer : _paperW - _outer - img.width, top + _badge + 2));
        notes.add((n.n, leftSide, Rect.fromLTWH(colX, top, _noteW, _badge + 2 + img.height)));
        if (e.lines) {
          // Along the top of the word's line, out past the page's edge,
          // then across the gap to the note's number.
          final faint = _faint(n.colour);
          leaders.add((
            leftSide
                ? [n.at.left, n.at.top, x - 3, n.at.top, _outer + _noteW, badgeY, badgeX + _badge / 2 + 2, badgeY]
                : [n.at.right, n.at.top, x + size.width + 3, n.at.top, _paperW - _outer - _noteW, badgeY,
                    badgeX - _badge / 2 - 2, badgeY],
            faint,
          ));
        }
      }
    }
    sheets.add(PrintSheet(image, x, y, texts, badges, notes, leaders));
    onProgress?.call(++done);
    await Future<void>.delayed(Duration.zero);
  }
  original?.release(holder);
  return sheets;
}


/// A mark's note, before it's placed in its margin.
class _Note {
  final int n;
  final Rect at; // the word, on the paper
  final int colour;
  final String label;
  final bool left;
  _Note(this.n, this.at, this.colour, this.label, {required this.left});
}

/// [argb] most of the way to white: a line that's there without crossing
/// out the words it passes.
int _faint(int argb) {
  int mix(int c) => (c + (255 - c) * .55).round();
  return 0xFF000000 |
      mix((argb >> 16) & 0xFF) << 16 |
      mix((argb >> 8) & 0xFF) << 8 |
      mix(argb & 0xFF);
}

/// What the page needs from the app around it, carried to the off-screen
/// tree: theme, localizations, settings.
class _Context {
  final BuildContext context;
  _Context(this.context);

  Widget wrap(Widget page, AppSettings settings) => InheritedTheme.captureAll(
        context,
        Localizations.override(
          context: context,
          child: SettingsScope(
            settings: settings,
            child: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: _scale),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Material(type: MaterialType.transparency, child: page),
              ),
            ),
          ),
        ),
      );
}

/// [widget] laid out at [size] and painted off screen; with where each
/// word on it is drawn, by (global āyah, word index; -1 for the ۝).
Future<(PdfImage, Map<(int, int), Rect>)> _paintOffscreen(
    Widget widget, Size size) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.implicitView ??
      WidgetsBinding.instance.platformDispatcher.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * _scale),
      devicePixelRatio: _scale,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final build = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: SizedBox.fromSize(size: size, child: widget),
  ).attachToRenderTree(build);
  build
    ..buildScope(root)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  final words = <(int, int), Rect>{};
  void visit(RenderObject o) {
    if (o is RenderMushafLine) {
      final ws = o.spec.line.words;
      final at = o.localToGlobal(Offset.zero, ancestor: boundary);
      for (var i = 0; i < ws.length; i++) {
        final r = o.wordRect(i);
        if (r != null) words[(ws[i].ayah, ws[i].wordIdx)] = r.shift(at);
      }
    }
    if (o is RenderOriginalPage) {
      final at = o.localToGlobal(Offset.zero, ancestor: boundary);
      o.wordRects.forEach((k, r) => words[k] = r.shift(at));
    }
    o.visitChildren(visit);
  }

  boundary.visitChildren(visit);
  final img = await boundary.toImage(pixelRatio: _scale);
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  img.dispose();
  // Taken down again.
  RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
      .attachToRenderTree(build, root);
  build.finalizeTree();
  return (PdfImage(png, size.width, size.height), words);
}

/// Lays the sheets out as an A4 PDF. Pure: runs in another isolate.
Future<Uint8List> buildPagesPdf(List<PrintSheet> sheets) async {
  final doc = pw.Document(creator: 'Rāsikh');
  addPageSheets(doc, sheets);
  return doc.save();
}

/// The marked pages, then the report numbered to match, in one PDF. Pure:
/// runs in another isolate.
Future<Uint8List> buildPagesReportPdf((List<PrintSheet>, ReportPdfInput) m) async {
  final doc = pw.Document(creator: 'Rāsikh');
  addPageSheets(doc, m.$1);
  addReportPages(doc, m.$2);
  return doc.save();
}

/// The sheets, added to [doc].
void addPageSheets(pw.Document doc, List<PrintSheet> sheets) {
  pw.Widget image(PdfImage i) =>
      pw.Image(pw.MemoryImage(i.png), width: i.width, height: i.height);
  for (final s in sheets) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        pw.Positioned(left: s.pageX, top: s.pageY, child: image(s.page)),
        for (final (i, x, y) in s.texts)
          pw.Positioned(left: x, top: y, child: image(i)),
        // The lines, under the numbers: fine, dotted, faint.
        if (s.leaders.isNotEmpty)
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: const PdfPoint(_paperW, _paperH),
              painter: (canvas, size) {
                for (final (pts, colour) in s.leaders) {
                  canvas
                    ..setStrokeColor(PdfColor.fromInt(colour))
                    ..setLineWidth(.45)
                    ..setLineDashPattern([1, 1.4])
                    ..moveTo(pts[0], size.y - pts[1]);
                  for (var i = 2; i < pts.length; i += 2) {
                    canvas.lineTo(pts[i], size.y - pts[i + 1]);
                  }
                  canvas.strokePath();
                }
              },
            ),
          ),
        for (final (x, y, n, colour) in s.badges)
          pw.Positioned(left: x - 6, top: y - 6, child: numberBadge(n, colour, size: 11)),
      ]),
    ));
  }
}
