import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/report.dart';
import '../../core/marks/review.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/quran.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'export_delivery.dart';
import 'marking.dart';
import 'pages_pdf.dart';
import 'report_pdf.dart';

/// What the export makes: the marks as a report, the muṣḥaf's pages with
/// their notes in the margin, or the pages (each mark numbered on them)
/// then the report, numbered to match.
enum ExportKind { report, pages, both }

enum _Scope { pages, surah, verses, juz, all }

enum _Period { all, week, month, custom }

/// What picking on the muṣḥaf chooses: pages, sūrahs or verses.
enum ExportPickUnit { page, surah, verse }

/// What was picked: pages, sūrah numbers or global āyahs, [a] <= [b].
typedef ExportPicked = ({ExportPickUnit unit, int a, int b});

/// The one export: what ([kind]), where (pages, a sūrah, a juzʼ, or
/// everything), which marks, and for a report its period and grouping —
/// then printed or shared.
Future<void> showExportSheet(
  BuildContext context, {
  required MarksStore store,
  required String bookId,
  required String script,
  int? currentPage,
  int? toPage,
  ExportKind kind = ExportKind.both,
  ReviewStatus status = ReviewStatus.any,
  Future<ExportPicked?> Function(ExportPickUnit unit)? pickRange,
  ValueListenable<bool>? fromLeft,
}) async {
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  // Picking the pages on the muṣḥaf: the sheet steps aside, and comes back as
  // it was with the pages chosen.
  _ExportDraft? draft;
  while (true) {
    final current = draft;
    final next = await showAdaptiveSheet<_ExportDraft>(
      context,
      isScrollControlled: true,
      fromLeft: fromLeft,
      // An overlay, as the index is: the page stays in view above it.
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: AdaptiveSheet.isSide(sheet)
              ? double.infinity
              // (What the index takes, its handle above this.)
              : (MediaQuery.sizeOf(sheet).height - kMinInteractiveDimension) * .9,
        ),
        child: _ExportSheet(
          store: store,
          bookId: bookId,
          script: script,
          currentPage: currentPage,
          toPage: toPage ?? currentPage,
          kind: kind,
          status: status,
          host: context,
          canPick: pickRange != null,
          draft: current,
        ),
      ),
    );
    if (next == null || pickRange == null || !context.mounted) return;
    final picked = await pickRange(switch (next.scope) {
      _Scope.surah => ExportPickUnit.surah,
      _Scope.verses => ExportPickUnit.verse,
      _ => ExportPickUnit.page,
    });
    if (!context.mounted) return;
    if (picked != null) next.apply(picked);
    draft = next;
  }
}

/// The sheet's choices while it steps aside.
class _ExportDraft {
  final ExportKind kind;
  final Set<MarkType> types;
  final ReviewStatus status;
  final bool onlyMarked;
  final _Period period;
  final DateTimeRange? range;
  final ReportGrouping group;
  final int juz;
  final ExportFormat format;
  _Scope scope;
  int surah;
  String from, to;
  int fromSurah, toSurah;
  String fromAyah, toAyah;
  _ExportDraft(this.kind, this.types, this.status, this.onlyMarked, this.period,
      this.range, this.group, this.juz, this.format,
      {required this.scope,
      required this.surah,
      required this.from,
      required this.to,
      required this.fromSurah,
      required this.toSurah,
      required this.fromAyah,
      required this.toAyah});

  /// Takes what was picked. One sūrah is a sūrah; several, their verses.
  void apply(ExportPicked p) {
    void verses(int s0, int a0, int s1, int a1) {
      scope = _Scope.verses;
      fromSurah = s0;
      fromAyah = '$a0';
      toSurah = s1;
      toAyah = '$a1';
    }

    switch (p.unit) {
      case ExportPickUnit.page:
        scope = _Scope.pages;
        from = '${p.a}';
        to = '${p.b}';
      case ExportPickUnit.surah:
        if (p.a == p.b) {
          scope = _Scope.surah;
          surah = p.a;
        } else {
          verses(p.a, 1, p.b, MushafRepo.ayahCountOf(p.b));
        }
      case ExportPickUnit.verse:
        final (s0, a0) = MushafRepo.surahAyahOf(p.a);
        final (s1, a1) = MushafRepo.surahAyahOf(p.b);
        verses(s0, a0, s1, a1);
    }
  }
}

class _ExportSheet extends StatefulWidget {
  final MarksStore store;
  final String bookId;
  final String script;
  /// The range's two ends, to start with (none: everything).
  final int? currentPage, toPage;
  final ExportKind kind;
  final ReviewStatus status;

  /// The screen below the sheet (the progress dialog and share sheet show
  /// over it once the sheet has closed).
  final BuildContext host;

  /// Offers picking the range on the muṣḥaf; what was chosen before it did.
  final bool canPick;
  final _ExportDraft? draft;
  const _ExportSheet({
    required this.store,
    required this.bookId,
    required this.script,
    required this.currentPage,
    required this.toPage,
    required this.kind,
    required this.status,
    required this.host,
    this.canPick = false,
    this.draft,
  });

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportKind _kind = widget.draft?.kind ?? widget.kind;
  // From the muṣḥaf: its page; from elsewhere, everything.
  late _Scope _scope =
      widget.draft?.scope ?? (widget.currentPage == null ? _Scope.all : _Scope.pages);
  late final int _here = widget.currentPage ?? 1;
  // What's typed in each field, left as typed: neither moves the other
  // (typing 45 on the way to 450 would). The range is the two numbers
  // either way round.
  late final _fromText = TextEditingController(text: widget.draft?.from ?? '$_here');
  late final _toText =
      TextEditingController(text: widget.draft?.to ?? '${widget.toPage ?? _here}');
  late int _surah = widget.draft?.surah ?? MushafRepo.firstVerseOfPage(widget.script, _here).$1;
  late int _juz = widget.draft?.juz ?? MushafRepo.juzOfPage(widget.script, _here);
  late ExportFormat _format = widget.draft?.format ?? ExportFormat.pdf;
  // The verses' two ends: to start with, the pages' first and last verses.
  late final (int, int) _startVerse = MushafRepo.firstVerseOfPage(widget.script, _here);
  late final (int, int) _endVerse = () {
    final (first, end) = MushafRepo.pageTokens(widget.script, widget.toPage ?? _here);
    return end <= first
        ? _startVerse
        : MushafRepo.surahAyahOf(MushafRepo.tokenAt(widget.script, end - 1).$1);
  }();
  late int _fromSurah = widget.draft?.fromSurah ?? _startVerse.$1;
  late int _toSurah = widget.draft?.toSurah ?? _endVerse.$1;
  late final _fromAyah = TextEditingController(text: widget.draft?.fromAyah ?? '${_startVerse.$2}');
  late final _toAyah = TextEditingController(text: widget.draft?.toAyah ?? '${_endVerse.$2}');
  late Set<MarkType> _types = widget.draft?.types ?? const {};
  late ReviewStatus _status = widget.draft?.status ?? widget.status;
  late bool _onlyMarked = widget.draft?.onlyMarked ?? false;

  /// Lines from the marks to their notes: as last chosen (this run).
  static bool _lines = false;
  late _Period _period = widget.draft?.period ?? _Period.all;
  late DateTimeRange? _range = widget.draft?.range;
  late ReportGrouping _group = widget.draft?.group ?? ReportGrouping.surah;
  Map<int, String> _tnames = const {};

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _tnames = {for (final x in m) x.n: x.tname});
    });
  }

  @override
  void dispose() {
    _fromText.dispose();
    _toText.dispose();
    _fromAyah.dispose();
    _toAyah.dispose();
    super.dispose();
  }

  int get _total => MushafRepo.pageCountSync(widget.script);

  /// [c]'s page, if it's one of the muṣḥaf's.
  int? _pageIn(TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n != null && n >= 1 && n <= _total ? n : null;
  }

  /// [c]'s āyah of [surah], if it has one.
  int? _ayahIn(int surah, TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n != null && n >= 1 && n <= MushafRepo.ayahCountOf(surah) ? n : null;
  }

  /// The verses chosen (global āyahs, either way round), if both ends are.
  (int, int)? get _verses {
    if (_scope != _Scope.verses) return null;
    final a = _ayahIn(_fromSurah, _fromAyah), b = _ayahIn(_toSurah, _toAyah);
    if (a == null || b == null) return null;
    final x = MushafRepo.globalAyahOf(_fromSurah, a), y = MushafRepo.globalAyahOf(_toSurah, b);
    return x <= y ? (x, y) : (y, x);
  }

  /// The verses for the file's name: `2.255-3.10`.
  String? get _versesName {
    final v = _verses;
    if (v == null) return null;
    final (s0, a0) = MushafRepo.surahAyahOf(v.$1);
    final (s1, a1) = MushafRepo.surahAyahOf(v.$2);
    return '$s0.$a0-$s1.$a1';
  }

  /// The pages chosen, before "only pages with marks".
  List<int> get _pages => switch (_scope) {
        _Scope.pages => () {
            final a = _pageIn(_fromText), b = _pageIn(_toText);
            if (a == null || b == null) return const <int>[];
            return [for (var p = a < b ? a : b; p <= (a < b ? b : a); p++) p];
          }(),
        _Scope.surah => pagesOfSurah(widget.script, _surah),
        _Scope.verses => () {
            final v = _verses;
            if (v == null) return const <int>[];
            final a = MushafRepo.pageForGlobalAyah(widget.script, v.$1);
            final b = MushafRepo.pageForGlobalAyah(widget.script, v.$2);
            return [for (var p = a; p <= b; p++) p];
          }(),
        _Scope.juz => pagesOfJuz(widget.script, _juz),
        _Scope.all => [for (var p = 1; p <= _total; p++) p],
      };

  int _pageOf(WordRef r) => MushafRepo.pageOfWord(
      widget.script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1);

  Report _report(List<int> pages) {
    final now = DateTime.now();
    final (from, to) = switch (_period) {
      _Period.all => (null, null),
      _Period.week => (now.subtract(const Duration(days: 7)), null),
      _Period.month => (now.subtract(const Duration(days: 30)), null),
      _Period.custom => (
          _range?.start,
          _range?.end.add(const Duration(days: 1, milliseconds: -1))
        ),
    };
    return buildReport(
        widget.store,
        widget.bookId,
        ReportOptions(
          query: ReviewQuery(script: widget.script, types: _types, status: _status),
          fromMs: from?.millisecondsSinceEpoch,
          toMs: to?.millisecondsSinceEpoch,
          grouping: _group,
          pages: _scope == _Scope.all || _verses != null ? null : pages.toSet(),
          ayahs: _verses,
        ),
        pageOf: _pageOf,
        now: now.millisecondsSinceEpoch);
  }

  PagesExport _pagesExport(List<int> pages, {Set<String>? ids}) => PagesExport(
        store: widget.store,
        bookId: widget.bookId,
        script: widget.script,
        pages: pages,
        types: _types,
        status: _status,
        // Everything: only the pages with marks (not 604 bare ones).
        onlyMarked: _onlyMarked || _scope == _Scope.all || ids != null,
        lines: _lines,
        ids: ids,
        ayahs: _verses,
      );

  Future<void> _make(ExportAction action) async {
    final out = ExportOut(action, _format);
    final pages = _pages;
    final host = widget.host;
    final verses = _versesName;
    switch (_kind) {
      case ExportKind.report:
        final r = _report(pages);
        Navigator.pop(context);
        await makeReport(host, r, widget.script,
            out: out,
            pageRange: _scope == _Scope.all || pages.isEmpty ? null : (pages.first, pages.last),
            verses: verses);
      case ExportKind.pages:
        final e = _pagesExport(pages);
        Navigator.pop(context);
        await makePagesPdf(host, e, out: out, verses: verses);
      case ExportKind.both:
        final r = _report(pages);
        Navigator.pop(context);
        // The pages asked for, as typed: the marks' own only if that's asked.
        await makePagesReportPdf(host, widget.store, r, widget.script,
            out: out,
            chosen: _onlyMarked || _scope == _Scope.all ? null : pages,
            verses: verses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final mp = markPaletteFor(p, mono: SettingsScope.of(context).appTheme == 'mono');
    final pages = _pages;
    final report = _kind == ExportKind.pages ? null : _report(pages);
    final sheets = _kind == ExportKind.pages ? _pagesExport(pages).chosenPages() : const <int>[];
    final empty = report?.isEmpty ?? sheets.isEmpty;
    Widget pageField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              // Only once something's typed that isn't a page.
              errorText: c.text.isEmpty || _pageIn(c) != null ? null : '1–$_total',
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
    Widget pickButton() => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: QOutlineButton(l.exPick,
              icon: AppIcons.mushaf,
              onTap: () => Navigator.pop(
                  context,
                  _ExportDraft(_kind, _types, _status, _onlyMarked, _period, _range, _group, _juz, _format,
                      scope: _scope,
                      surah: _surah,
                      from: _fromText.text,
                      to: _toText.text,
                      fromSurah: _fromSurah,
                      toSurah: _toSurah,
                      fromAyah: _fromAyah.text,
                      toAyah: _toAyah.text))),
        );
    Widget verseEnd(String label, int surah, ValueChanged<int> onSurah,
            TextEditingController ayah) =>
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('$label$surah'),
                isExpanded: true,
                initialValue: surah,
                decoration: InputDecoration(labelText: label, isDense: true),
                items: [
                  for (var n = 1; n <= 114; n++)
                    DropdownMenuItem(
                        value: n,
                        child: Text('$n. ${_tnames[n] ?? ''}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (n) => setState(() => onSurah(n ?? surah)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: TextField(
                controller: ayah,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.exAyah,
                  isDense: true,
                  errorText: ayah.text.isEmpty || _ayahIn(surah, ayah) != null
                      ? null
                      : '1–${MushafRepo.ayahCountOf(surah)}',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: math.max(0, keyboard)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.tcExport, style: displayStyle(context, size: 24)),
            const SizedBox(height: 12),
            QSegmented<ExportKind>(
              options: [
                (ExportKind.report, l.exReport, null),
                (ExportKind.pages, l.exPages, null),
                (ExportKind.both, l.exBoth, null),
              ],
              value: _kind,
              onChanged: (v) => setState(() => _kind = v),
            ),
            if (_kind == ExportKind.both)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.exBothSub,
                    textAlign: TextAlign.center,
                    style: uiStyle(context, size: 12.5, color: p.ink3)),
              ),
            const SizedBox(height: 10),
            QSegmented<ExportFormat>(
              options: const [
                (ExportFormat.pdf, 'PDF', null),
                (ExportFormat.png, 'PNG', null),
                (ExportFormat.jpg, 'JPG', null),
              ],
              value: _format,
              onChanged: (v) => setState(() => _format = v),
            ),
            QSectionLabel(l.rvScope),
            QSegmented<_Scope>(
              options: [
                (_Scope.pages, l.ppPages, null),
                (_Scope.surah, l.idxSurah, null),
                (_Scope.verses, l.exVerses, null),
                (_Scope.juz, l.idxJuz, null),
                (_Scope.all, l.exAll, null),
              ],
              value: _scope,
              onChanged: (v) => setState(() => _scope = v),
            ),
            const SizedBox(height: 10),
            switch (_scope) {
              _Scope.pages => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        pageField(_fromText, l.ppFrom),
                        const SizedBox(width: 12),
                        pageField(_toText, l.ppTo),
                      ],
                    ),
                    if (widget.canPick) pickButton(),
                  ],
                ),
              _Scope.surah => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _surah,
                      items: [
                        for (var n = 1; n <= 114; n++)
                          DropdownMenuItem(value: n, child: Text('$n. ${_tnames[n] ?? ''}')),
                      ],
                      onChanged: (n) => setState(() => _surah = n ?? _surah),
                    ),
                    if (widget.canPick) pickButton(),
                  ],
                ),
              _Scope.verses => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    verseEnd(l.exFrom, _fromSurah, (n) => _fromSurah = n, _fromAyah),
                    const SizedBox(height: 12),
                    verseEnd(l.exTo, _toSurah, (n) => _toSurah = n, _toAyah),
                    if (widget.canPick) pickButton(),
                  ],
                ),
              _Scope.juz => DropdownButton<int>(
                  isExpanded: true,
                  value: _juz,
                  items: [
                    for (var j = 1; j <= 30; j++)
                      DropdownMenuItem(value: j, child: Text(l.juzN(j))),
                  ],
                  onChanged: (j) => setState(() => _juz = j ?? _juz),
                ),
              _Scope.all => const SizedBox.shrink(),
            },
            QSectionLabel(l.rvTypes),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                label: Text(l.rvAll),
                selected: _types.isEmpty,
                onSelected: (_) => setState(() => _types = const {}),
              ),
              for (final t in MarkType.marking)
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
            if (_kind != ExportKind.report && _scope != _Scope.all) ...[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.ppOnlyMarked, style: uiStyle(context, size: 14.5)),
                value: _onlyMarked,
                onChanged: (v) => setState(() => _onlyMarked = v),
              ),
            ],
            // Notes in the margins (not with the report): lines to them.
            if (_kind == ExportKind.pages)
              SwitchListTile(
                key: const ValueKey('pp-lines'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.ppLines, style: uiStyle(context, size: 14.5)),
                subtitle: Text(l.ppLinesSub, style: uiStyle(context, size: 12.5)),
                value: _lines,
                onChanged: (v) => setState(() => _lines = v),
              ),
            if (_kind != ExportKind.pages) ...[
              QSectionLabel(l.rpPeriod),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (v, label) in [
                  (_Period.all, l.rpAllTime),
                  (_Period.week, l.rpLast7),
                  (_Period.month, l.rpLast30),
                  (
                    _Period.custom,
                    _range == null
                        ? l.rpCustom
                        : l.rpRange(shortDate(context, _range!.start.millisecondsSinceEpoch),
                            shortDate(context, _range!.end.millisecondsSinceEpoch))
                  ),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _period == v,
                    onSelected: (_) async {
                      if (v == _Period.custom) {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: now,
                            initialDateRange: _range);
                        if (picked == null) return;
                        _range = picked;
                      }
                      setState(() => _period = v);
                    },
                  ),
              ]),
              QSectionLabel(l.rpGroupBy),
              QSegmented<ReportGrouping>(
                options: [
                  (ReportGrouping.surah, l.rpBySurah, null),
                  (ReportGrouping.page, l.rpByPage, null),
                ],
                value: _group,
                onChanged: (v) => setState(() => _group = v),
              ),
            ],
          ],
        ),
              ),
            ),
            // What it comes to and the buttons stay in view as the rest scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
            Text(
                report != null
                    ? (report.isEmpty
                        ? l.rpNoMarks
                        : '${l.rvCountN(report.total)} · ${l.rpAyahsN(report.ayahCount)}')
                    : (sheets.isEmpty ? l.ppNone : l.ppPagesN(sheets.length)),
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 13.5, color: p.ink2)),
            const SizedBox(height: 10),
            Row(children: [
              // Images can't go to a printer from here: the PDF does that.
              if (_format == ExportFormat.pdf) ...[
                Expanded(
                  child: QOutlineButton(l.rpPrint,
                      onTap: empty ? null : () => _make(ExportAction.print)),
                ),
                const SizedBox(width: 10),
              ],
              if (isDesktopPlatform()) ...[
                Expanded(
                  child: QOutlineButton(l.exSaveAs,
                      onTap: empty ? null : () => _make(ExportAction.saveAs)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: QPrimaryButton(isDesktopPlatform() ? l.exOpen : l.rpShare,
                    onTap: empty ? null : () => _make(ExportAction.send)),
              ),
            ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pages [report]'s marks are on, each mark a numbered badge, then the
/// report with the same numbers: one PDF, printed ([print]) or shared.
/// [chosen]: the pages asked for, marked or not; null, just the marked ones.
Future<void> makePagesReportPdf(
    BuildContext context, MarksStore store, Report report, String script,
    {required ExportOut out, List<int>? chosen, String? verses}) async {
  final numbers = reportNumbers(report);
  final pages = chosen ?? reportPages(report);
  final e = PagesExport(
    store: store,
    bookId: report.bookId,
    script: script,
    pages: pages,
    ids: numbers.keys.toSet(),
  );
  final total = pages.length + report.ayahCount;
  final progress = ValueNotifier<(int, int)>((0, total));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (d, v, _) => Row(children: [
          const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(d.l10n.rpMaking(v.$1, v.$2))),
        ]),
      ),
    ),
  );
  Uint8List? bytes;
  Object? error;
  try {
    final sheets = await preparePages(context, e, pages,
        numbers: numbers, onProgress: (done) => progress.value = (done, total));
    if (!context.mounted) return;
    final input = await prepareReport(context, report, script,
        numbers: numbers,
        onProgress: (done) => progress.value = (pages.length + done, total));
    bytes = await compute(buildPagesReportPdf, (sheets, input));
  } catch (err, st) {
    error = err;
    debugPrint('[export] $err\n$st');
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();
  if (bytes == null) {
    showQToast(context, '$error');
    return;
  }
  final name = marksPdfName(exportOwnerName(context, report.bookName), pages.first,
      pages.last, DateTime.now(), verses: verses);
  await deliverExport(context, bytes, name, out);
}
