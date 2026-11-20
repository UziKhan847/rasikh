import '../../core/bookmarks.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_index.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_query.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_search.dart';
import '../../data/quran.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../marks/marking.dart';
import 'words_line.dart';
import '../../ui/bidi.dart';

/// The muṣḥaf's index: go to a page, or pick a page, sūrah, juzʼ, ḥizb, rubʿ
/// or manzil (and rukūʿ in Indo-Pak) from swipeable tabs. With an active
/// mark book every entry shows how many marks it holds, by type; tapping a
/// count goes to the first such mark in it ([onWord]). With [onStart] it
/// picks where memorizing starts instead: each entry gives its first word's
/// token (no counts). What's picked happens once the sheet has gone, so
/// the pages it opens aren't built under its closing.
Future<void> showMushafIndex(
  BuildContext context, {
  required String script,
  required int currentPage,
  required ValueChanged<int> onPage,
  ValueChanged<WordRef>? onWord,
  ValueChanged<int>? onStart,
  Division initial = Division.surah,
  ValueListenable<bool>? fromLeft,
  bool focusField = false,
  bool bookmarks = false,
}) async {
  final pick = await showAdaptiveSheet<_Pick>(
    context,
    waitForExit: true,
    fromLeft: fromLeft,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: AdaptiveSheet.isSide(sheet) ? 1 : .9,
      child: MushafIndex(
        script: script,
        currentPage: currentPage,
        initial: initial,
        focusField: focusField,
        openBookmarks: bookmarks,
        onPage: (p) => Navigator.pop(sheet, (page: p, word: null, start: null)),
        onWord: onWord == null
            ? null
            : (w) => Navigator.pop(sheet, (page: null, word: w, start: null)),
        onStart: onStart == null
            ? null
            : (t) => Navigator.pop(sheet, (page: null, word: null, start: t)),
      ),
    ),
  );
  if (pick == null) return;
  if (pick.start case final t?) return onStart?.call(t);
  if (pick.word case final w?) return onWord?.call(w);
  if (pick.page case final p?) onPage(p);
}

typedef _Pick = ({int? page, WordRef? word, int? start});

/// Where to start memorizing: the index, each sūrah, juzʼ, ḥizb, rubʿ,
/// manzil or page giving its first word's token. Null: dismissed.
Future<int?> chooseMemorizeStart(
  BuildContext context, {
  required String script,
  required int currentPage,
  ValueListenable<bool>? fromLeft,
}) async {
  int? token;
  await showMushafIndex(
    context,
    fromLeft: fromLeft,
    script: script,
    currentPage: currentPage,
    onPage: (_) {},
    onStart: (t) => token = t,
  );
  return token;
}

/// The page of [script] that [d] number [n] opens on.
int divisionFirstPage(String script, Division d, int n) {
  if (d == Division.page) return n;
  if (d == Division.surah) return MushafRepo.surahPageSync(script, n);
  final (s, a) = firstAyahOf(d, n);
  // A division that opens a sūrah opens on its header's page.
  if (a == 1) return MushafRepo.surahPageSync(script, s);
  return MushafRepo.pageForGlobalAyah(script, MushafRepo.globalAyahOf(s, a));
}

/// The index itself (the sheet's content; see [showMushafIndex]).
class MushafIndex extends StatefulWidget {
  final String script;
  final int currentPage;
  final Division initial;

  /// Opened on the bookmarks (its last tab).
  final bool openBookmarks;

  /// Ready to type a page or a search (a keyboard's way in).
  final bool focusField;
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
    this.openBookmarks = false,
    this.focusField = false,
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
  /// The āyāt bookmarked while reading, as the last tab (not when picking
  /// where memorizing starts).
  bool get _withBookmarks => widget.onStart == null;

  late final TabController _tab = TabController(
      length: _tabs.length + (_withBookmarks ? 1 : 0),
      vsync: this,
      initialIndex: widget.openBookmarks && _withBookmarks
          ? _tabs.length
          : _tabs.contains(widget.initial)
              ? _tabs.indexOf(widget.initial)
              : 1);
  final _field = TextEditingController();
  List<SurahMeta> _meta = const [];

  /// The query searched (the field, once typing pauses).
  String _query = '';
  Timer? _debounce;

  /// Searching by mark: the kinds wanted (none: not searching by mark).
  final Set<MarkType> _kinds = {};
  MarkState _state = MarkState.open;

  /// Reads the text for the search once the sheet is open (not on the
  /// first letter typed, nor while it slides in).
  Timer? _warm;

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _meta = m);
    });
    _warm = Timer(const Duration(milliseconds: 400), () => warmSearch(widget.script));
  }

  @override
  void dispose() {
    _warm?.cancel();
    _debounce?.cancel();
    _tab.dispose();
    _field.dispose();
    super.dispose();
  }

  void _typed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = _field.text.trim());
    });
  }

  static final _noStore = ValueNotifier(0);

  int get _pages => MushafRepo.pageCountSync(widget.script);

  int _pageOf(WordRef r) => MushafRepo.pageOfWord(
      widget.script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1);

  int _firstPage(Division d, int n) => divisionFirstPage(widget.script, d, n);

  String _tabLabel(Division d) => switch (d) {
        Division.page => context.l10n.idxPage,
        Division.surah => context.l10n.idxSurah,
        Division.juz => context.l10n.idxJuz,
        Division.hizb => context.l10n.idxHizb,
        Division.rub => context.l10n.idxRub,
        Division.manzil => context.l10n.idxManzil,
        Division.ruku => context.l10n.idxRuku,
      };

  /// Words in the field (not a page number), or kinds of mark picked: the
  /// search shows instead of the tabs.
  bool get _searching {
    final t = _query;
    return _kinds.isNotEmpty || (t.length >= 2 && int.tryParse(t) == null);
  }

  /// The āyāt containing the words (Arabic), or the sūrahs by name; with
  /// kinds of mark picked, only āyāt holding such marks — or, without
  /// words, the marks themselves, in muṣḥaf order. Built row by row.
  Widget _results(BuildContext context, MarksStore? store, String? bookId,
      MarkPalette mp) {
    final p = pal(context);
    final q = _query;
    final hasText = q.length >= 2 && int.tryParse(q) == null;
    final latin = hasText && !RegExp('[\u0600-\u06FF]').hasMatch(q);
    final marks = _kinds.isEmpty || store == null || bookId == null
        ? null
        : queryMarks(store, bookId, types: _kinds, state: _state);
    final visuals = store == null || bookId == null
        ? const <int, MarkVisual>{}
        : store.visuals(bookId, showFixed: true);
    final surahs = [
      if (latin && marks == null)
        for (final m in _meta)
          if (m.tname.toLowerCase().contains(q.toLowerCase())) m
    ];
    var hits = hasText && !latin ? searchMushaf(widget.script, q) : const <MushafHit>[];
    if (marks != null && hasText) {
      final ayat = {for (final m in marks) m.ref.globalAyah};
      hits = [for (final h in hits) if (ayat.contains(h.ayah)) h];
    }
    final markRows = marks != null && !hasText ? marks : const <Mark>[];
    final count = surahs.length + hits.length + markRows.length;
    if (count == 0) {
      return Center(
          child: Text(context.l10n.idxNoResults,
              style: uiStyle(context, size: 14, color: p.ink3)));
    }
    Widget card({required VoidCallback onTap, required Widget child}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: p.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.line2)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6), child: child),
            ),
          ),
        );
    String where(int g) {
      final (su, a) = MushafRepo.surahAyahOf(g);
      return '${su - 1 < _meta.length ? _meta[su - 1].tname : ''} $su:$a';
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: count + (hits.isNotEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < surahs.length) {
          final m = surahs[i];
          return card(
            onTap: () => _pick(Division.surah, m.n, _firstPage(Division.surah, m.n)),
            child: Row(children: [
              Expanded(
                  child: Text('${m.n}. ${m.tname}',
                      style: uiStyle(context, size: 15, weight: FontWeight.w700))),
              _surahGlyph(m.n, p.ink),
            ]),
          );
        }
        i -= surahs.length;
        if (hits.isNotEmpty) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(context.l10n.idxResults(hits.length),
                  style: uiStyle(context, size: 12.5, color: p.ink3)),
            );
          }
          i--;
          if (i < hits.length) {
            final h = hits[i];
            return card(
              onTap: () {
                final start = widget.onStart;
                if (start != null) {
                  start(MushafRepo.tokenOf(widget.script, h.ayah, 0));
                } else if (widget.onWord case final onWord?) {
                  onWord(WordRef.fromGlobal(h.ayah, h.firstWord));
                } else {
                  widget.onPage(MushafRepo.pageForGlobalAyah(widget.script, h.ayah));
                }
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(where(h.ayah),
                    style: uiStyle(context,
                        size: 12.5, weight: FontWeight.w700, color: p.accInk)),
                WordsLine(
                  script: widget.script,
                  ayah: h.ayah,
                  from: h.firstWord,
                  to: h.lastWord + 1,
                  match: true,
                  marks: visuals,
                  markPal: mp,
                  ink: p.ink,
                  accent: p.acc,
                  strongBg: p.accSoft,
                  verseBg: p.accSoft,
                ),
              ]),
            );
          }
          i -= hits.length;
        }
        final m = markRows[i];
        final r = m.ref;
        final w0 = r.isWholeAyah ? -1 : r.word0;
        return card(
          onTap: () {
            if (widget.onWord case final onWord?) {
              onWord(r);
            } else {
              widget.onPage(MushafRepo.pageOfWord(widget.script, r.globalAyah, w0));
            }
          },
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              MarkSwatch(type: store!.isFixed(m) ? null : m.type, pal: mp, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${markTypeLabel(context, m.type)} · ${where(r.globalAyah)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: uiStyle(context,
                        size: 12.5, weight: FontWeight.w700, color: p.accInk)),
              ),
            ]),
            WordsLine(
              script: widget.script,
              ayah: r.globalAyah,
              from: w0 < 0 ? 1 << 20 : w0,
              to: w0 < 0 ? 1 << 20 : w0 + 1,
              focus: r.key,
              marks: visuals,
              markPal: mp,
              ink: p.ink,
              accent: p.acc,
              strongBg: p.accSoft,
              verseBg: p.accSoft,
            ),
            if (m.comment.isNotEmpty)
              CommentText(m.comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 12.5, color: p.ink2)),
          ]),
        );
      },
    );
  }

  /// The kinds of mark to search by, and open / fixed.
  Widget _markFilters(BuildContext context, MarkPalette mp) {
    final p = pal(context);
    Widget chip(String label, bool on, VoidCallback onTap, {Widget? lead}) =>
        FilterChip(
          selected: on,
          showCheckmark: false,
          avatar: lead,
          label: Text(label, style: uiStyle(context, size: 12.5)),
          onSelected: (_) => onTap(),
          selectedColor: p.accSoft,
          side: BorderSide(color: on ? p.acc : p.line2),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    // All of them in sight: what doesn't fit goes on a second line.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final t in MarkType.values)
            chip(markTypeLabel(context, t), _kinds.contains(t),
                () => setState(() => _kinds.contains(t) ? _kinds.remove(t) : _kinds.add(t)),
                lead: MarkSwatch(type: t, pal: mp, size: 12)),
          if (_kinds.isNotEmpty) ...[
            const SizedBox(width: 2),
            for (final (st, label) in [
              (MarkState.open, context.l10n.mkOpen),
              (MarkState.fixed, context.l10n.mkFixed),
              (MarkState.all, context.l10n.rvAll),
            ])
              chip(label, _state == st, () => setState(() => _state = st)),
          ],
        ],
      ),
    );
  }

  /// A sūrah's name in the SurahNames face (no shaping), or its number.
  Widget _surahGlyph(int n, Color ink) {
    if (n < 1 || n > surahGlyphCodes.length) return Text('$n');
    return Text(String.fromCharCodes([surahGlyphCodes[n - 1], 0xe903]),
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'SurahNames', fontSize: 26, color: ink));
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
                  autofocus: widget.focusField,
                  textInputAction: TextInputAction.go,
                  onChanged: _typed,
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
          if (book != null && widget.onStart == null) _markFilters(context, mp),
          if (_searching)
            Expanded(child: _results(context, store, book?.id, mp))
          else ...[
          // Wider than the sheet on a phone: it fades at the end it scrolls
          // to, and a mouse can drag it too.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
              begin: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
              end: AlignmentDirectional.centerEnd.resolve(Directionality.of(context)),
              colors: const [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 1 - 28 / r.width.clamp(28, double.infinity), 1],
            ).createShader(r),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              }),
              child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            // Room past the last tab, under the fade.
            padding: const EdgeInsetsDirectional.only(end: 24),
            tabs: [
              for (final d in _tabs)
                d == Division.page
                    // Held (or right-clicked): a grid or a list.
                    ? Tab(
                        child: Builder(
                          builder: (tab) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _pagesView(tab),
                            onSecondaryTap: () => _pagesView(tab),
                            child: Text(_tabLabel(d), key: const ValueKey('pages-tab')),
                          ),
                        ),
                      )
                    : Tab(text: _tabLabel(d)),
              if (_withBookmarks) Tab(text: context.l10n.bookmarksTab),
            ],
          ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                for (final d in _tabs)
                  d == Division.page && !SettingsScope.of(context).indexPagesList
                      ? _pageGrid(context, counts, mp)
                      : _list(context, d, counts, mp, store, book?.id),
                if (_withBookmarks) Builder(builder: _bookmarks),
              ],
            ),
          ),
          ],
        ]);
      },
    );
  }

  /// What's bookmarked, newest first: a tap goes there.
  Widget _bookmarks(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.read(context);
    return ValueListenableBuilder<int>(
      valueListenable: prog.readingSignal,
      builder: (context, _, _) {
        final marks = prog.bookmarkItems;
        if (marks.isEmpty) {
          return Center(
            child: QEmptyState(
              icon: AppIcons.bookmark,
              title: context.l10n.noBookmarks,
              hint: context.l10n.noBookmarksHint,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemExtent: 60,
          itemCount: marks.length,
          itemBuilder: (context, i) {
            final b = marks[i];
            final page = pageOfBookmark(widget.script, b);
            final name = _meta.length >= b.surah ? _meta[b.surah - 1].tname : '';
            final l = context.l10n;
            final (title, sub) = switch (b.kind) {
              BookmarkKind.verse => ('$name ${b.surah}:${b.ayah}', l.pageN(page)),
              BookmarkKind.page => (l.pageN(page), '$name ${b.surah}:${b.ayah}'),
              BookmarkKind.surah => (name, '${l.idxSurah} ${b.surah}'),
            };
            return ListTile(
              leading: Icon(AppIcons.bookmarkFilled, color: p.acc),
              title: Text(title, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              subtitle: Text(sub, style: uiStyle(context, size: 12.5, color: p.ink3)),
              onTap: () => widget.onPage(page),
            );
          },
        );
      },
    );
  }

  /// The Pages tab's view: a grid of numbers, or a list with each page's
  /// marks by kind (as the other tabs).
  Future<void> _pagesView(BuildContext tab) async {
    final s = SettingsScope.of(context);
    final box = tab.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay);
    final l = context.l10n;
    final pick = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, overlay.size.width - at.dx, 0),
      items: [
        CheckedPopupMenuItem(value: false, checked: !s.indexPagesList, child: Text(l.idxPagesGrid)),
        CheckedPopupMenuItem(value: true, checked: s.indexPagesList, child: Text(l.idxPagesList)),
      ],
    );
    if (pick == null || !mounted) return;
    s.update(() => s.indexPagesList = pick);
    _tab.animateTo(_tabs.indexOf(Division.page));
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
    // Opens with the current division about a third of the way down.
    final here0 = _currentOf(d);
    return ListView.builder(
      controller: ScrollController(
          initialScrollOffset: ((here0 - 3) * _rowGuess).clamp(0.0, double.infinity)),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: divisionCount(d, pages: _pages),
      itemBuilder: (context, i) {
        final n = i + 1;
        final page = _firstPage(d, n);
        final (s, a) = switch (d) {
          Division.surah => (n, 1),
          Division.page => MushafRepo.firstVerseOfPage(widget.script, n),
          _ => firstAyahOf(d, n),
        };
        final meta = s - 1 < _meta.length ? _meta[s - 1] : null;
        final c = counts?.of(d, n) ?? TypeCounts.empty;
        final title = switch (d) {
          Division.surah => meta?.tname ?? '',
          Division.juz => context.l10n.juzN(n),
          Division.hizb => context.l10n.idxHizbN(n),
          Division.rub => _rubTitle(context, n),
          Division.manzil => context.l10n.idxManzilN(n),
          Division.ruku => context.l10n.idxRukuN(n),
          Division.page => context.l10n.pageN(n),
        };
        final ref = '${meta?.tname ?? ''} $s:$a';
        final here = page == widget.currentPage;
        // Light rows (no clip, no shadow): a long list scrolls them fast.
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: here ? p.accSoft : p.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: here ? p.acc : p.line2)),
            child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pick(d, n, page),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                            : d == Division.page
                            ? ref
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
              if (d == Division.surah && _withBookmarks) _SurahBookmark(n),
              if (d == Division.surah) _surahGlyph(n, p.ink),
            ]),
          ),
          ),
          ),
        );
      },
    );
  }

  /// A row's height, near enough, for opening the list where it should.
  static const _rowGuess = 64.0;

  /// The current page's division [d] number.
  int _currentOf(Division d) {
    if (d == Division.page) return widget.currentPage;
    final (s, a) = MushafRepo.firstVerseOfPage(widget.script, widget.currentPage);
    return d == Division.surah ? s : divisionOf(d, s, a);
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

/// A sūrah's bookmark, on its row in the index.
class _SurahBookmark extends StatelessWidget {
  final int surah;
  const _SurahBookmark(this.surah);

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.read(context);
    return ValueListenableBuilder<int>(
      valueListenable: prog.readingSignal,
      builder: (context, _, _) {
        final on = prog.isSurahBookmarked(surah);
        return IconButton(
          key: ValueKey('surah-bookmark-$surah'),
          tooltip: on ? context.l10n.removeBookmark : context.l10n.bmSurah,
          visualDensity: VisualDensity.compact,
          onPressed: () => prog.toggleSurahBookmark(surah),
          icon: Icon(on ? AppIcons.bookmarkFilled : AppIcons.bookmark,
              size: 17, color: on ? p.gold : p.ink3),
        );
      },
    );
  }
}
