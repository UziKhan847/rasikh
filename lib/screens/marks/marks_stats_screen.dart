import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/responsive.dart';
import '../../core/marks/marks_stats.dart';
import '../../core/marks/marks_store.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../shell/app_shell.dart';
import 'charts.dart';
import 'marking.dart';
import 'report_pdf.dart';

/// Counts of marks by type, sūrah, juzʼ and page, over sessions and time —
/// for one mark book, with the filters in a row above the charts.
class MarksStatsScreen extends StatefulWidget with DesktopAware {
  final String? bookId;
  const MarksStatsScreen({super.key, this.bookId});

  @override
  State<MarksStatsScreen> createState() => _MarksStatsScreenState();
}

class _MarksStatsScreenState extends State<MarksStatsScreen> {
  String? _bookId;
  int _days = 0; // 0 = all time
  Set<MarkType> _types = const MarkQuery().types;
  MarkStatus _status = MarkStatus.all;
  late String _script;
  bool _surahByCount = true;
  bool _pagesReady = false;
  List<SurahMeta> _meta = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pagesReady || _meta.isNotEmpty) return;
    _script = SettingsScope.of(context).mushafScript;
    _bookId = widget.bookId;
    _loadPages();
  }

  Future<void> _loadPages() async {
    final meta = await QuranRepo.meta();
    await MushafRepo.ensure(_script);
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _pagesReady = true;
    });
  }

  void _setScript(String v) {
    setState(() {
      _script = v;
      _pagesReady = false;
    });
    _loadPages();
  }

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final p = pal(context);
    final mp = markPaletteFor(p,
        mono: SettingsScope.of(context).appTheme == 'mono');
    if (store == null || !store.ready || !_pagesReady) {
      return QScreen(
          title: context.l10n.mkStatistics,
          children: [
            const SizedBox(height: 40),
            Center(child: CircularProgressIndicator(color: p.acc)),
          ]);
    }
    final books = store.books;
    final bookId = (_bookId != null && store.book(_bookId!) != null)
        ? _bookId!
        : store.activeBookId;
    if (bookId == null) {
      return QScreen(title: context.l10n.mkStatistics, children: [
        QEmptyState(
            icon: AppIcons.chart,
            title: context.l10n.mkNoMarksYet,
            hint: context.l10n.mkNoMarksYetSub),
      ]);
    }
    final since = _days == 0
        ? null
        : DateTime.now()
            .subtract(Duration(days: _days))
            .millisecondsSinceEpoch;
    final script = _script;
    final st = computeStats(
      marks: store.marksOf(bookId),
      fixes: store.fixesOf(bookId),
      sessions: store.sessionsOf(bookId),
      q: MarkQuery(since: since, types: _types, status: _status),
      pageCount: MushafRepo.pageCountSync(script),
      pageOf: (r) => MushafRepo.pageOfWord(
          script, r.globalAyah, r.isWholeAyah ? 0 : r.word0),
      juzOf: MushafRepo.juzOfAyah,
    );
    final usedBuckets = {
      for (var b = 0; b < st.byBucket.length; b++)
        if (st.byBucket[b] > 0) b
    };

    final filters = Wrap(spacing: 8, runSpacing: 8, children: [
      if (books.length > 1)
        _Drop<String>(
          value: bookId,
          items: [for (final b in books) (b.id, b.name)],
          onChanged: (v) => setState(() => _bookId = v),
        ),
      _Drop<int>(
        value: _days,
        items: [
          (0, context.l10n.mkAllTime),
          (7, context.l10n.mk7d),
          (30, context.l10n.mk30d),
          (90, context.l10n.mk90d),
        ],
        onChanged: (v) => setState(() => _days = v),
      ),
      _Drop<MarkStatus>(
        value: _status,
        items: [
          (MarkStatus.all, context.l10n.mkStatusAll),
          (MarkStatus.open, context.l10n.mkOpen),
          (MarkStatus.fixed, context.l10n.mkFixed),
        ],
        onChanged: (v) => setState(() => _status = v),
      ),
      _Drop<String>(
        value: script,
        items: [
          ('uthmani', context.l10n.madani),
          ('indopak', context.l10n.indoPak),
        ],
        onChanged: _setScript,
      ),
      for (final t in statTypes)
        FilterChip(
          avatar: MarkSwatch(type: t, pal: mp, size: 13),
          label: Text(markTypeLabel(context, t)),
          selected: _types.contains(t),
          showCheckmark: false,
          onSelected: (on) => setState(() {
            final next = {..._types};
            on ? next.add(t) : next.remove(t);
            if (next.isNotEmpty) _types = next;
          }),
        ),
    ]);

    final children = <Widget>[filters, const SizedBox(height: 16)];
    if (st.isEmpty) {
      children.add(QEmptyState(
          icon: AppIcons.chart,
          title: context.l10n.mkNoMarksYet,
          hint: context.l10n.mkNoMarksYetSub));
    } else {
      final surahRows = [
        for (var i = 0; i < 114; i++)
          if (st.bySurah[i].any((v) => v > 0)) i
      ];
      if (_surahByCount) {
        int tot(int i) => st.bySurah[i].fold<int>(0, (a, b) => a + b);
        surahRows.sort((a, b) => tot(b) != tot(a) ? tot(b) - tot(a) : a - b);
      }
      final juzRows = [
        for (var j = 0; j < 30; j++)
          if (st.byJuz[j].any((v) => v > 0)) j
      ];
      children.addAll([
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth >= 560 ? (c.maxWidth - 30) / 4 : (c.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
                width: w,
                child: StatTile(
                    label: context.l10n.mkTotal, value: '${st.total}')),
            SizedBox(
                width: w,
                child: StatTile(
                    label: context.l10n.mkOpen, value: '${st.open}')),
            SizedBox(
                width: w,
                child: StatTile(
                    label: context.l10n.mkFixed,
                    value: '${st.fixed}',
                    swatch: MarkSwatch(type: null, pal: mp, size: 13))),
            SizedBox(
                width: w,
                child: StatTile(
                    label: context.l10n.mkFixRate,
                    value: '${(st.fixRate * 100).round()}%')),
          ]);
        }),
        QSectionLabel(context.l10n.mkByType),
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StackedBar(values: st.byBucket, max: st.total, mp: mp, height: 16),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 8, children: [
              for (final b in usedBuckets)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  MarkSwatch(type: statBuckets[b], pal: mp, size: 13),
                  const SizedBox(width: 6),
                  Text('${bucketLabel(context, b)} ',
                      style: uiStyle(context, size: 13, color: p.ink2)),
                  Text('${st.byBucket[b]}',
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w700)),
                ]),
            ]),
          ]),
        ),
        QSectionLabel(
          context.l10n.mkBySurah,
          trailing: QSegmented<bool>(
            expand: false,
            height: 30,
            options: [
              (true, context.l10n.mkSortCount, null),
              (false, context.l10n.mkSortOrder, null),
            ],
            value: _surahByCount,
            onChanged: (v) => setState(() => _surahByCount = v),
          ),
        ),
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (usedBuckets.length > 1) ...[
              BucketLegend(pal: mp, buckets: usedBuckets),
              const SizedBox(height: 10),
            ],
            BarRows(
              mp: mp,
              rows: [
                for (final i in surahRows)
                  ('${i + 1}. ${_meta[i].tname}', st.bySurah[i])
              ],
              onTap: (k) async {
                final pg = await MushafRepo.pageForSurah(script, surahRows[k] + 1);
                if (context.mounted) {
                  openMushaf(context, page: pg, script: script);
                }
              },
            ),
          ]),
        ),
        QSectionLabel(context.l10n.mkByJuz),
        QCard(
          child: BarRows(
            mp: mp,
            rows: [
              for (final j in juzRows)
                (context.l10n.mkJuzN(j + 1), st.byJuz[j])
            ],
          ),
        ),
        QSectionLabel(context.l10n.mkByPage),
        QCard(
          child: PageHeatmap(
            counts: st.byPage,
            onOpen: (pg) => openMushaf(context, page: pg, script: script),
          ),
        ),
        if (st.sessions.isNotEmpty) ...[
          QSectionLabel(context.l10n.mkPerSession),
          QCard(
            child: TrendChart(
              bars: true,
              // All marks, not one type: a neutral colour, not a mark's.
              color: p.acc,
              points: [
                for (final s in st.sessions) (s.session.startedAt, s.marks)
              ],
            ),
          ),
        ],
        if (st.openOverTime.length > 1) ...[
          QSectionLabel(context.l10n.mkOpenOverTime),
          QCard(
            child: TrendChart(
                color: p.acc, points: st.openOverTime),
          ),
        ],
        if (st.problemWords.isNotEmpty) ...[
          QSectionLabel(context.l10n.mkProblemWords),
          QGroup(children: [
            for (final w in st.problemWords)
              QRow(
                title: '${w.ref.surah}:${w.ref.ayah}'
                    '${w.ref.isWholeAyah ? '' : ' · ${w.ref.word}'}'
                    '  ×${w.count}',
                subtitle: context.l10n.mkPageN(MushafRepo.pageOfWord(
                    script, w.ref.globalAyah, w.ref.isWholeAyah ? 0 : w.ref.word0)),
                leading: SizedBox(
                  width: 92,
                  child: Text(
                    w.ref.isWholeAyah
                        ? '۝'
                        : MushafRepo.wordText(script, w.ref.globalAyah, w.ref.word0),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: MushafRepo.fontFamily(script),
                        fontSize: 24,
                        height: 1.6,
                        color: p.ink),
                  ),
                ),
                chevron: true,
                onTap: () => openMushaf(context,
                    page: MushafRepo.pageOfWord(script, w.ref.globalAyah,
                        w.ref.isWholeAyah ? 0 : w.ref.word0),
                    script: script),
              ),
          ]),
        ],
      ]);
    }
    return QScreen(
      title: context.l10n.mkStatistics,
      subtitle: store.book(bookId)?.name,
      maxWidth: 900,
      actions: [
        QIconButton(
          icon: AppIcons.pdf,
          tooltip: context.l10n.rpExport,
          onTap: () => showReportSheet(context,
              store: store, bookId: bookId, script: script),
        ),
      ],
      children: children,
    );
  }
}

/// A compact dropdown for the filter row.
class _Drop<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const _Drop(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          style: uiStyle(context, size: 13, weight: FontWeight.w600),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(value: v, child: Text(label)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
