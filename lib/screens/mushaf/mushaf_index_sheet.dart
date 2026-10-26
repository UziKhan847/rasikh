import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_index.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_search.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../marks/marking.dart';

/// The muṣḥaf's index: go to a page, or pick a page, sūrah, juzʼ, ḥizb, rubʿ
/// or manzil (and rukūʿ in Indo-Pak) from swipeable tabs. With an active
/// mark book every entry shows how many marks it holds, by type; tapping a
/// count goes to the first such mark in it ([onWord]). With [onStart] it
/// picks where memorizing starts instead: each entry gives its first word's
/// token (no counts).
Future<void> showMushafIndex(
  BuildContext context, {
  required String script,
  required int currentPage,
  required ValueChanged<int> onPage,
  ValueChanged<WordRef>? onWord,
  ValueChanged<int>? onStart,
  Division initial = Division.surah,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: .9,
      child: MushafIndex(
        script: script,
        currentPage: currentPage,
        initial: initial,
        onPage: (p) {
          Navigator.pop(sheet);
          onPage(p);
        },
        onWord: onWord == null
            ? null
            : (w) {
                Navigator.pop(sheet);
                onWord(w);
              },
        onStart: onStart == null
            ? null
            : (t) {
                Navigator.pop(sheet);
                onStart(t);
              },
      ),
    ),
  );
}

/// Where to start memorizing: the index, each sūrah, juzʼ, ḥizb, rubʿ,
/// manzil or page giving its first word's token. Null: dismissed.
Future<int?> chooseMemorizeStart(
  BuildContext context, {
  required String script,
  required int currentPage,
}) async {
  int? token;
  await showMushafIndex(
    context,
    script: script,
    currentPage: currentPage,
    onPage: (_) {},
    onStart: (t) => token = t,
  );
  return token;
}

/// The index itself (the sheet's content; see [showMushafIndex]).
class MushafIndex extends StatefulWidget {
  final String script;
  final int currentPage;
  final Division initial;
  final ValueChanged<int> onPage;
  final ValueChanged<WordRef>? onWord;

  /// Picking where memorizing starts: an entry's first word's token.
  final ValueChanged<int>? onStart;
  const MushafIndex({
    super.key,
    required this.script,
    required this.currentPage,
    required this.onPage,
    this.onWord,
    this.onStart,
    this.initial = Division.surah,
  });

  @override
  State<MushafIndex> createState() => _MushafIndexState();
}

class _MushafIndexState extends State<MushafIndex>
    with SingleTickerProviderStateMixin {
  late final List<Division> _tabs = [
    Division.page,
    Division.surah,
    Division.juz,
    Division.hizb,
    Division.rub,
    Division.manzil,
    if (widget.script == 'indopak') Division.ruku,
  ];
  late final TabController _tab = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _tabs.contains(widget.initial)
          ? _tabs.indexOf(widget.initial)
          : 1);
  final _field = TextEditingController();
  List<SurahMeta> _meta = const [];

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _meta = m);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _field.dispose();
    super.dispose();
  }

  static final _noStore = ValueNotifier(0);

  int get _pages => MushafRepo.pageCountSync(widget.script);

  int _pageOf(WordRef r) => MushafRepo.pageOfWord(
      widget.script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1);

  /// The page [d] number [n] opens on.
  int _firstPage(Division d, int n) {
    if (d == Division.page) return n;
    if (d == Division.surah) return MushafRepo.surahPageSync(widget.script, n);
    final (s, a) = firstAyahOf(d, n);
    // A division that opens a sūrah opens on its header's page.
    if (a == 1) return MushafRepo.surahPageSync(widget.script, s);
    return MushafRepo.pageForGlobalAyah(
        widget.script, MushafRepo.globalAyahOf(s, a));
  }

  String _tabLabel(Division d) => switch (d) {
        Division.page => context.l10n.idxPage,
        Division.surah => context.l10n.idxSurah,
        Division.juz => context.l10n.idxJuz,
        Division.hizb => context.l10n.idxHizb,
        Division.rub => context.l10n.idxRub,
        Division.manzil => context.l10n.idxManzil,
        Division.ruku => context.l10n.idxRuku,
      };

  /// Words in the field (not a page number): the search shows instead of
  /// the tabs.
  bool get _searching {
    final t = _field.text.trim();
    return t.length >= 2 && int.tryParse(t) == null;
  }

  /// The āyāt containing the words (Arabic), or the sūrahs by name.
  Widget _results(BuildContext context) {
    final p = pal(context);
    final q = _field.text.trim();
    final latin = !RegExp('[\u0600-\u06FF]').hasMatch(q);
    final surahs = [
      for (final m in _meta)
        if (latin && m.tname.toLowerCase().contains(q.toLowerCase())) m
    ];
    final hits = latin ? const <MushafHit>[] : searchMushaf(widget.script, q);
    if (surahs.isEmpty && hits.isEmpty) {
      return Center(
          child: Text(context.l10n.idxNoResults,
              style: uiStyle(context, size: 14, color: p.ink3)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      for (final m in surahs)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: QCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            onTap: () => _pick(Division.surah, m.n, _firstPage(Division.surah, m.n)),
            child: Row(children: [
              Expanded(
                  child: Text('${m.n}. ${m.tname}',
                      style: uiStyle(context, size: 15, weight: FontWeight.w700))),
              Text(m.name,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'SurahNames', fontSize: 22)),
            ]),
          ),
        ),
      if (hits.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(context.l10n.idxResults(hits.length),
              style: uiStyle(context, size: 12.5, color: p.ink3)),
        ),
      for (final h in hits)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: QCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            onTap: () {
              final start = widget.onStart;
              if (start != null) {
                start(MushafRepo.tokenOf(widget.script, h.ayah, 0));
              } else {
                widget.onPage(MushafRepo.pageForGlobalAyah(widget.script, h.ayah));
              }
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                  '${h.surah - 1 < _meta.length ? _meta[h.surah - 1].tname : ''} '
                  '${h.surah}:${h.ayahInSurah}',
                  style: uiStyle(context, size: 12.5, weight: FontWeight.w700, color: p.accInk)),
              Text(h.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: MushafRepo.fontFamily(widget.script),
                      fontSize: 20,
                      height: 1.9,
                      color: p.ink)),
            ]),
          ),
        ),
    ]);
  }

  void _go() {
    final n = int.tryParse(_field.text.trim());
    if (n == null || n < 1 || n > _pages) return;
    _pick(Division.page, n, n);
  }

  /// Opens [page] — or, picking a start, gives [d] number [n]'s first
  /// word.
  void _pick(Division d, int n, int page) {
    final start = widget.onStart;
    if (start == null) return widget.onPage(page);
    if (d == Division.page) {
      return start(MushafRepo.pageTokens(widget.script, n).$1);
    }
    final (s, a) = d == Division.surah ? (n, 1) : firstAyahOf(d, n);
    start(MushafRepo.tokenOf(
        widget.script, MushafRepo.globalAyahOf(s, a), 0));
  }

  /// The first open mark of [t] in [d] number [n], in muṣḥaf order.
  WordRef? _firstMark(
      MarksStore store, String bookId, Division d, int n, MarkType t) {
    WordRef? best;
    for (final m in store.marksOf(bookId)) {
      if (m.type != t || store.isFixed(m)) continue;
      final r = m.ref;
      final inside = d == Division.page
          ? _pageOf(r) == n
          : divisionOf(d, r.surah, r.ayah) == n;
      if (inside && (best == null || r.compareTo(best) < 0)) best = r;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    return ListenableBuilder(
      listenable: store ?? _noStore,
      builder: (context, _) {
        final book = store != null && store.ready ? store.activeBook : null;
        final counts = book == null || widget.onStart != null
            ? null
            : MarkCounts.forBook(store!, book.id, widget.script, _pageOf);
        final p = pal(context);
        final mp = markPaletteFor(p,
            mono: SettingsScope.of(context).appTheme == 'mono');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.onStart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(context.l10n.mzStartFrom,
                  style: displayStyle(context, size: 22)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                // A page number goes there; words search the text (and
                // the sūrah names).
                child: TextField(
                  controller: _field,
                  textInputAction: TextInputAction.go,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _go(),
                  decoration: InputDecoration(
                      labelText: context.l10n.idxPageOrSearch,
                      hintText: context.l10n.pageNumberHint(_pages)),
                ),
              ),
              const SizedBox(width: 10),
              QPrimaryButton(context.l10n.go, onTap: _go),
            ]),
          ),
          if (_searching)
            Expanded(child: _results(context))
          else ...[
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final d in _tabs) Tab(text: _tabLabel(d))],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                for (final d in _tabs)
                  d == Division.page
                      ? _pageGrid(context, counts, mp)
                      : _list(context, d, counts, mp, store, book?.id),
              ],
            ),
          ),
          ],
        ]);
      },
    );
  }

  Widget _pageGrid(BuildContext context, MarkCounts? counts, MarkPalette mp) {
    final p = pal(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 72,
          mainAxisExtent: 52,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6),
      itemCount: _pages,
      itemBuilder: (context, i) {
        final n = i + 1;
        final c = counts?.of(Division.page, n) ?? TypeCounts.empty;
        final here = n == widget.currentPage;
        return Material(
          color: here ? p.accSoft : p.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: here ? p.acc : p.line2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(Division.page, n, n),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$n',
                    style: uiStyle(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: here ? p.accInk : p.ink)),
                const SizedBox(height: 4),
                // A dot per kind of mark on the page (no room for numbers).
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final t in MarkType.values)
                        if (c.openOf(t) > 0) _dot(mp.colorOf(t)),
                      if (c.fixed > 0) _dot(mp.fixed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(Color c) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _list(BuildContext context, Division d, MarkCounts? counts,
      MarkPalette mp, MarksStore? store, String? bookId) {
    final p = pal(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: divisionCount(d, pages: _pages),
      itemBuilder: (context, i) {
        final n = i + 1;
        final page = _firstPage(d, n);
        final (s, a) = d == Division.surah ? (n, 1) : firstAyahOf(d, n);
        final meta = s - 1 < _meta.length ? _meta[s - 1] : null;
        final c = counts?.of(d, n) ?? TypeCounts.empty;
        final title = switch (d) {
          Division.surah => meta?.tname ?? '',
          Division.juz => context.l10n.juzN(n),
          Division.hizb => context.l10n.idxHizbN(n),
          Division.rub => _rubTitle(context, n),
          Division.manzil => context.l10n.idxManzilN(n),
          Division.ruku => context.l10n.idxRukuN(n),
          Division.page => '',
        };
        final ref = '${meta?.tname ?? ''} $s:$a';
        final here = page == widget.currentPage;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: QCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            radius: 16,
            color: here ? p.accSoft : null,
            borderColor: here ? p.acc : null,
            onTap: () => _pick(d, n, page),
            child: Row(children: [
              SizedBox(
                width: 34,
                child: Text('$n',
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w700, color: p.accInk)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiStyle(context,
                            size: 15, weight: FontWeight.w700)),
                    Text(
                        d == Division.surah
                            ? context.l10n.pageN(page)
                            : context.l10n.idxStartsAt(ref, page),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: uiStyle(context, size: 12, color: p.ink3)),
                    if (!c.isEmpty) ...[
                      const SizedBox(height: 4),
                      _pills(context, c, mp, (t) {
                        final w = t == null || store == null || bookId == null
                            ? null
                            : _firstMark(store, bookId, d, n, t);
                        if (w != null && widget.onWord != null) {
                          widget.onWord!(w);
                        } else {
                          widget.onPage(page);
                        }
                      }),
                    ],
                  ],
                ),
              ),
              if (d == Division.surah && meta != null)
                Text(meta.name,
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context, size: 20, color: p.ink)),
            ]),
          ),
        );
      },
    );
  }

  /// "Rubʿ 6 · ½ of Ḥizb 2": where the quarter falls in its ḥizb.
  String _rubTitle(BuildContext context, int n) {
    final hizb = (n - 1) ~/ 4 + 1;
    final q = (n - 1) % 4;
    if (q == 0) return '${context.l10n.idxRubN(n)} · ${context.l10n.idxHizbN(hizb)}';
    return '${context.l10n.idxRubN(n)} · '
        '${context.l10n.idxQuarterOf(const ['', '¼', '½', '¾'][q], hizb)}';
  }

  /// A pill per kind of open mark, then the fixed ones. Tapping one goes to
  /// the first such mark; the fixed pill (null) just goes to the place.
  Widget _pills(BuildContext context, TypeCounts c, MarkPalette mp,
      void Function(MarkType? t) onTap) {
    Widget pill(Widget lead, String n, Color color, String tip,
            VoidCallback tap) =>
        Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: .5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                lead,
                const SizedBox(width: 4),
                Text(n,
                    style: uiStyle(context,
                        size: 11.5, weight: FontWeight.w700, color: color)),
              ]),
            ),
          ),
        );
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final t in MarkType.values)
        if (c.openOf(t) > 0)
          pill(MarkSwatch(type: t, pal: mp, size: 10), '${c.openOf(t)}',
              mp.colorOf(t), markTypeLabel(context, t), () => onTap(t)),
      if (c.fixed > 0)
        pill(Icon(AppIcons.check, size: 11, color: mp.fixed), '${c.fixed}',
            mp.fixed, context.l10n.idxFixedN(c.fixed), () => onTap(null)),
    ]);
  }
}
