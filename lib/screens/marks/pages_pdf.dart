import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat, PdfPoint;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
import '../../data/quran.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../mushaf/mushaf_line.dart';
import '../mushaf/mushaf_marks_layer.dart';
import '../mushaf_screen.dart' show mushafPageForPrint;
import 'marking.dart' show markTypeLabel;
import 'report_pdf.dart' show PdfImage, paintTextImage, saveAndOpenPdf;

// The muṣḥaf's pages as a PDF, to hand to a student: each page as the app
// draws it, its marks on it, and in the margin beside each mark its comment
// (else its kind) on a dotted line led from the word to the nearer side.

// ─────────────────────────── the options sheet ───────────────────────────

/// Asks which pages (a range, a sūrah or a juzʼ) and which marks, then
/// makes the PDF — to share or to print.
Future<void> showPagesExportSheet(
  BuildContext context, {
  required MarksStore store,
  required String bookId,
  required String script,
  required int currentPage,
}) async {
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  await showAdaptiveSheet<void>(
    context,
    isScrollControlled: true,
    builder: (sheet) => _PagesSheet(
      store: store,
      bookId: bookId,
      script: script,
      currentPage: currentPage,
      host: context,
    ),
  );
}

enum _Range { pages, surah, juz }

class _PagesSheet extends StatefulWidget {
  final MarksStore store;
  final String bookId;
  final String script;
  final int currentPage;
  final BuildContext host;
  const _PagesSheet({
    required this.store,
    required this.bookId,
    required this.script,
    required this.currentPage,
    required this.host,
  });

  @override
  State<_PagesSheet> createState() => _PagesSheetState();
}

class _PagesSheetState extends State<_PagesSheet> {
  _Range _range = _Range.pages;
  // What's typed in each field, left as typed: neither moves the other
  // (typing 45 on the way to 450 would). The range is the two numbers
  // either way round.
  late final _fromText = TextEditingController(text: '${widget.currentPage}');
  late final _toText = TextEditingController(text: '${widget.currentPage}');
  late int _surah = MushafRepo.firstVerseOfPage(widget.script, widget.currentPage).$1;
  late int _juz = MushafRepo.juzOfPage(widget.script, widget.currentPage);
  Set<MarkType> _types = const {};
  ReviewStatus _status = ReviewStatus.open;
  bool _onlyMarked = false;
  Map<int, String> _tnames = const {};

  @override
  void dispose() {
    _fromText.dispose();
    _toText.dispose();
    super.dispose();
  }

  /// [c]'s page, if it's one of the muṣḥaf's.
  int? _pageIn(TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n != null && n >= 1 && n <= MushafRepo.pageCountSync(widget.script)
        ? n
        : null;
  }

  List<int> get _typedPages {
    final a = _pageIn(_fromText), b = _pageIn(_toText);
    if (a == null || b == null) return const [];
    return [for (var p = a < b ? a : b; p <= (a < b ? b : a); p++) p];
  }

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _tnames = {for (final x in m) x.n: x.tname});
    });
  }

  PagesExport get _export => PagesExport(
        store: widget.store,
        bookId: widget.bookId,
        script: widget.script,
        pages: switch (_range) {
          _Range.pages => _typedPages,
          _Range.surah => pagesOfSurah(widget.script, _surah),
          _Range.juz => pagesOfJuz(widget.script, _juz),
        },
        types: _types,
        status: _status,
        onlyMarked: _onlyMarked,
      );

  Future<void> _make({required bool print}) async {
    final e = _export;
    final host = widget.host;
    Navigator.pop(context);
    await makePagesPdf(host, e, print: print);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final mp = markPaletteFor(p, mono: SettingsScope.of(context).appTheme == 'mono');
    final total = MushafRepo.pageCountSync(widget.script);
    final pages = _export.chosenPages();
    Widget pageField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              // Only once something's typed that isn't a page.
              errorText: c.text.isEmpty || _pageIn(c) != null ? null : '1–$total',
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.ppTitle, style: displayStyle(context, size: 24)),
            QSectionLabel(l.ppWhich),
            QSegmented<_Range>(
              options: [
                (_Range.pages, l.ppPages, null),
                (_Range.surah, l.idxSurah, null),
                (_Range.juz, l.idxJuz, null),
              ],
              value: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            const SizedBox(height: 10),
            switch (_range) {
              _Range.pages => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pageField(_fromText, l.ppFrom),
                    const SizedBox(width: 12),
                    pageField(_toText, l.ppTo),
                  ],
                ),
              _Range.surah => DropdownButton<int>(
                  isExpanded: true,
                  value: _surah,
                  items: [
                    for (var n = 1; n <= 114; n++)
                      DropdownMenuItem(value: n, child: Text('$n. ${_tnames[n] ?? ''}')),
                  ],
                  onChanged: (n) => setState(() => _surah = n ?? _surah),
                ),
              _Range.juz => DropdownButton<int>(
                  isExpanded: true,
                  value: _juz,
                  items: [
                    for (var j = 1; j <= 30; j++)
                      DropdownMenuItem(value: j, child: Text(l.juzN(j))),
                  ],
                  onChanged: (j) => setState(() => _juz = j ?? _juz),
                ),
            },
            QSectionLabel(l.rvTypes),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                label: Text(l.rvAll),
                selected: _types.isEmpty,
                onSelected: (_) => setState(() => _types = const {}),
              ),
              for (final t in MarkType.values)
                FilterChip(
                  avatar: MarkSwatch(type: t, pal: mp, size: 14),
                  label: Text(markTypeLabel(context, t)),
                  selected: _types.contains(t),
                  onSelected: (on) => setState(() {
                    final ts = {..._types};
                    on ? ts.add(t) : ts.remove(t);
                    _types = ts;
                  }),
                ),
            ]),
            QSectionLabel(l.rvStatus),
            QSegmented<ReviewStatus>(
              options: [
                (ReviewStatus.any, l.rvAny, null),
                (ReviewStatus.open, l.rvOpen, null),
                (ReviewStatus.fixed, l.rvFixed, null),
              ],
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.ppOnlyMarked, style: uiStyle(context, size: 14.5)),
              value: _onlyMarked,
              onChanged: (v) => setState(() => _onlyMarked = v),
            ),
            const SizedBox(height: 8),
            Text(pages.isEmpty ? l.ppNone : l.ppPagesN(pages.length),
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 13.5, color: p.ink2)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: QOutlineButton(l.rpPrint,
                    onTap: pages.isEmpty ? null : () => _make(print: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QPrimaryButton(l.rpShare,
                    onTap: pages.isEmpty ? null : () => _make(print: false)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

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
  PagesExport({
    required this.store,
    required this.bookId,
    required this.script,
    required this.pages,
    this.types = const {},
    this.status = ReviewStatus.any,
    this.onlyMarked = false,
  });

  /// The marks to show, by the page they're on.
  late final Map<int, List<Mark>> marksByPage = () {
    final out = <int, List<Mark>>{};
    for (final m in store.marksOf(bookId)) {
      if (types.isNotEmpty && !types.contains(m.type)) continue;
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
        (byWord[m.ref.key] ??= []).add(m);
      }
    }
    return {
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
              count: e.value.length);
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

/// The outer margin, each side's note column, and the gap between a column
/// and the page.
const _outer = 26.0, _noteW = 96.0, _gap = 12.0;
const _pageX = _outer + _noteW + _gap;
const _pageW = _paperW - 2 * _pageX;
const _pageY = 52.0;

/// Pixels per point the muṣḥaf page is painted at (about 216 dpi).
const _scale = 3.0;

/// One sheet: the page painted, its running head and foot, and the notes
/// with their dotted leaders.
class PrintSheet {
  final PdfImage page;
  final double pageX, pageY;
  final List<(PdfImage, double x, double y)> texts;

  /// Each a polyline (x0, y0, x1, y1 …, from the top left) in its colour.
  final List<(List<double>, int)> leaders;
  const PrintSheet(this.page, this.pageX, this.pageY, this.texts, this.leaders);
}

/// Paints every page of [e], with a progress dialog, lays the PDF out off
/// the UI thread, then shares it ([print]: print preview).
Future<void> makePagesPdf(BuildContext context, PagesExport e,
    {required bool print}) async {
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
  final name = 'mushaf-${book.replaceAll(RegExp(r'[^\w-]+'), '_')}-'
      'p${pages.first}-${pages.last}.pdf';
  if (print) {
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes!);
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    final path = await saveAndOpenPdf(bytes, name);
    if (context.mounted) {
      showQToast(context,
          path == null ? context.l10n.rpShare : context.l10n.rpSavedTo(path));
    }
  } else {
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}

/// Each of [pages] painted and annotated, for [buildPagesPdf].
Future<List<PrintSheet>> preparePages(
    BuildContext context, PagesExport e, List<int> pages,
    {void Function(int done)? onProgress}) async {
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

  final arabicUi = lang == 'ar' || lang == 'ur';
  final uiFamily = lang == 'ur'
      ? 'NotoNastaliqUrdu'
      : (arabicUi ? 'NotoNaskhArabic' : 'Inter');
  Future<PdfImage> text(String s,
          {double size = 8, int color = 0xFF1F2522, bool bold = false, double width = _noteW}) =>
      paintTextImage(s,
          size: size,
          family: _hasArabic(s) ? (lang == 'ur' ? 'NotoNastaliqUrdu' : 'NotoNaskhArabic') : uiFamily,
          bold: bold,
          color: Color(color),
          maxWidth: width);

  final head = paper.acc.toARGB32();
  const sub = 0xFF6B716D;
  final sheets = <PrintSheet>[];
  var done = 0;
  for (final page in pages) {
    final box = MushafGeometry.pageBox(
        const Size(_pageW, _paperH - _pageY - 40), e.script,
        look: look, header: false, page: page);
    final size = Size(_pageW, box.height);
    if (atlas != null) {
      final fs = _pageW / MushafGeometry.refEmOf(e.script);
      final tier = atlas.tiers[atlas.tierFor(fs * _scale)];
      if (tier.images == null) await tier.load();
    }
    final (image, words) = await _paintOffscreen(
      wrap.wrap(mushafPageForPrint(
        page: page,
        script: e.script,
        names: names,
        paper: paper,
        look: look,
        marks: marks,
      ), settings),
      size,
    );
    final texts = <(PdfImage, double, double)>[];
    final leaders = <(List<double>, int)>[];

    // ── the running head: sūrah · page · juzʼ, across the page ──
    final (s, _) = MushafRepo.firstVerseOfPage(e.script, page);
    final juz = MushafRepo.juzOfPage(e.script, page);
    final left = await text(metas[s - 1].tname, size: 9.5, color: head, bold: true, width: _pageW / 2);
    final mid = await text('$page', size: 9.5, color: head, bold: true, width: 60);
    final right = await text(l.juzN(juz), size: 9.5, color: head, bold: true, width: _pageW / 2);
    const headY = _pageY - 24;
    texts
      ..add((left, _pageX, headY))
      ..add((mid, _pageX + (_pageW - mid.width) / 2, headY))
      ..add((right, _pageX + _pageW - right.width, headY));
    // ── the foot: whose marks, and when ──
    final foot = await text('$book · $today', size: 7.5, color: sub, width: _pageW);
    texts.add((foot, _pageX, _paperH - 26));

    // ── the notes, each in the nearer margin ──
    final notes = <_Note>[];
    for (final m in e.marksByPage[page] ?? const <Mark>[]) {
      final r = m.ref;
      final at = words[(r.globalAyah, r.isWholeAyah ? -1 : r.word0)];
      if (at == null) continue;
      final fixed = e.store.isFixed(m);
      final colour = fixed ? 0xFF6E8F7A : mp.colorOf(m.type).toARGB32();
      final label = m.comment.trim().isEmpty ? typeLabel[m.type]! : m.comment.trim();
      final img = await text(label, size: 8, width: _noteW);
      notes.add(_Note(at, img, colour, at.center.dx < size.width / 2));
    }
    for (final leftSide in [true, false]) {
      final side = notes.where((n) => n.left == leftSide).toList()
        ..sort((a, b) => a.at.top.compareTo(b.at.top));
      var below = _pageY - 6; // the last note's line, page coordinates
      for (final n in side) {
        final top = _pageY + n.at.top;
        // Its text sits on its line, clear of the one above.
        final lineY = top > below + n.img.height + 3 ? top : below + n.img.height + 3;
        below = lineY;
        final textY = lineY - n.img.height - 1;
        if (leftSide) {
          final edge = _pageX - 2;
          leaders.add(([
            _pageX + n.at.left, top,
            edge, top,
            edge - _gap + 4, lineY,
            _outer, lineY,
          ], n.colour));
          texts.add((n.img, _outer, textY));
        } else {
          final edge = _pageX + _pageW + 2;
          leaders.add(([
            _pageX + n.at.right, top,
            edge, top,
            edge + _gap - 4, lineY,
            _paperW - _outer, lineY,
          ], n.colour));
          texts.add((n.img, _paperW - _outer - n.img.width, textY));
        }
      }
    }
    sheets.add(PrintSheet(image, _pageX, _pageY, texts, leaders));
    onProgress?.call(++done);
    await Future<void>.delayed(Duration.zero);
  }
  return sheets;
}

bool _hasArabic(String s) => s.runes.any((c) =>
    (c >= 0x0600 && c <= 0x06FF) ||
    (c >= 0x0750 && c <= 0x077F) ||
    (c >= 0x08A0 && c <= 0x08FF) ||
    (c >= 0xFB50 && c <= 0xFEFF));

class _Note {
  final Rect at; // the word, page coordinates
  final PdfImage img;
  final int colour;
  final bool left;
  _Note(this.at, this.img, this.colour, this.left);
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
  final doc = pw.Document(creator: 'Qiraah Arabiyyah');
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
        // The leaders, over everything: dotted, from the word out.
        pw.Positioned.fill(
          child: pw.CustomPaint(
            size: const PdfPoint(_paperW, _paperH),
            painter: (canvas, size) {
              for (final (pts, colour) in s.leaders) {
                canvas
                  ..setStrokeColor(PdfColor.fromInt(colour))
                  ..setLineWidth(.7)
                  ..setLineDashPattern([1.2, 1.6])
                  ..moveTo(pts[0], size.y - pts[1]);
                for (var i = 2; i < pts.length; i += 2) {
                  canvas.lineTo(pts[i], size.y - pts[i + 1]);
                }
                canvas.strokePath();
              }
            },
          ),
        ),
      ]),
    ));
  }
  return doc.save();
}
