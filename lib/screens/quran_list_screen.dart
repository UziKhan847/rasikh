import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/quran.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import 'shell/app_mode.dart' show SettingsButton;
import 'quran_screen.dart';

/// The Qurʼān: search, Sūrahs | Bookmarks, the Last read card and the sūrah
/// list (number, names, Meccan/Medinan, āyah count).
class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

/// Lower-case, without diacritics, apostrophes or hyphens — "Al-Fātiḥah" and
/// "alfatihah" match.
String _norm(String s) {
  const from = 'āīūḥṣḍṭẓġāĀĪŪḤṢḌṬẒ';
  const to = 'aiuhsdtzgaaiuhsdtz';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    if (i >= 0) {
      b.write(to[i]);
    } else if (!"ʿʼ'’‘- ".contains(c)) {
      b.write(c);
    }
  }
  return b.toString();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _tab = 'surahs';
  List<SurahMeta>? _meta;

  @override
  void initState() {
    super.initState();
    QuranRepo.meta().then((m) {
      if (mounted) setState(() => _meta = m);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(SurahMeta m, {int? ayah}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SurahReaderScreen(meta: m, startAyah: ayah)));
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final prog = ProgressScope.of(context);
    final meta = _meta;
    final q = _norm(_q.trim());
    final rows = meta == null
        ? const <SurahMeta>[]
        : [
            for (final m in meta)
              if (q.isEmpty ||
                  '${m.n}' == q ||
                  _norm(m.tname).contains(q) ||
                  m.name.contains(_q.trim()))
                m
          ];
    final marks = prog.bookmarks;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: DecoratedBox(
        decoration: screenDecoration(context),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: QColumn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QPageHeader(
                        title: context.l10n.theQuran,
                        leading: canPop
                            ? QIconButton(
                                icon: AppIcons.back,
                                onTap: () => Navigator.of(context).maybePop())
                            : null,
                        actions: const [SettingsButton()],
                      ),
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _q = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: context.l10n.searchSurahHint,
                          prefixIcon: const Icon(AppIcons.search, size: 20),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(AppIcons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _q = '';
                                  }),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      QSegmented<String>(
                        options: [
                          ('surahs', context.l10n.surahsTab, null),
                          (
                            'marks',
                            marks.isEmpty
                                ? context.l10n.bookmarksTab
                                : '${context.l10n.bookmarksTab} · ${marks.length}',
                            null
                          ),
                        ],
                        value: _tab,
                        onChanged: (v) => setState(() => _tab = v),
                      ),
                      const SizedBox(height: 14),
                      if (_tab == 'surahs' && q.isEmpty && prog.lastRead != null && meta != null)
                        _LastRead(
                          meta: meta[prog.lastRead!.$1 - 1],
                          ayah: prog.lastRead!.$2,
                          onOpen: () => _open(meta[prog.lastRead!.$1 - 1],
                              ayah: prog.lastRead!.$2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (meta == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: p.acc)),
              )
            else if (_tab == 'marks')
              _bookmarks(context, meta)
            else if (rows.isEmpty)
              SliverToBoxAdapter(
                child: QColumn(
                  child: QEmptyState(
                    icon: AppIcons.search,
                    circle: 64,
                    title: context.l10n.noSurahMatches(_q.trim()),
                    hint: context.l10n.noSurahMatchesHint,
                    action: QOutlineButton(context.l10n.clearSearch,
                        onTap: () => setState(() {
                              _search.clear();
                              _q = '';
                            })),
                  ),
                ),
              )
            else if (MediaQuery.sizeOf(context).width >= 840)
              // Desktop: the sūrahs in a grid across the content width (two
              // columns at about 1100 px).
              SliverLayoutBuilder(builder: (context, c) {
                final maxW = contentMaxWidth(context, ContentKind.list);
                final side = ((c.crossAxisExtent - maxW) / 2).clamp(20.0, 1e9);
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 32),
                  sliver: SliverGrid.builder(
                    // Each tile is as tall as a row needs: two lines of text
                    // (at the reader's text scale) and the card's padding —
                    // the handoff's fixed 76 clipped them.
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 520,
                      mainAxisExtent:
                          MediaQuery.textScalerOf(context).scale(58) + 26,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) =>
                        _SurahRow(m: rows[i], onTap: () => _open(rows[i])),
                  ),
                );
              })
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => QColumn(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SurahRow(m: rows[i], onTap: () => _open(rows[i])),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _bookmarks(BuildContext context, List<SurahMeta> meta) {
    final marks = ProgressScope.of(context).bookmarks;
    if (marks.isEmpty) {
      return SliverToBoxAdapter(
        child: QColumn(
          child: QEmptyState(
            icon: AppIcons.bookmark,
            title: context.l10n.noBookmarks,
            hint: context.l10n.noBookmarksHint,
            action: QPrimaryButton(context.l10n.openAlFatihah,
                onTap: () => _open(meta[0])),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverList.builder(
        itemCount: marks.length,
        itemBuilder: (context, i) {
          final (s, a) = marks[i];
          return QColumn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QRiseIn(
                child: _BookmarkCard(
                    meta: meta[s - 1],
                    ayah: a,
                    onOpen: () => _open(meta[s - 1], ayah: a)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LastRead extends StatelessWidget {
  final SurahMeta meta;
  final int ayah;
  final VoidCallback onOpen;
  const _LastRead({required this.meta, required this.ayah, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onTap: onOpen,
      color: p.accSoft,
      borderColor: p.accSoft,
      child: Row(children: [
        Icon(AppIcons.bookmarkFilled, size: 18, color: p.accInk),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.lastRead,
                style: uiStyle(context,
                    size: 12, weight: FontWeight.w600, color: p.accInk)),
            Text('${meta.tname} · ${meta.n}:$ayah',
                style: uiStyle(context,
                    size: 15, weight: FontWeight.w700, color: p.ink)),
          ]),
        ),
        Text(context.l10n.open,
            style: uiStyle(context,
                size: 14, weight: FontWeight.w700, color: p.accInk)),
      ]),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final SurahMeta m;
  final VoidCallback onTap;
  const _SurahRow({required this.m, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      onTap: onTap,
      child: Row(children: [
        _NumberBadge(n: m.n),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.tname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(
                context.l10n.typeAyat(
                    m.type == 'meccan' ? context.l10n.meccan : context.l10n.medinan,
                    m.ayahs),
                style: uiStyle(context, size: 12.5, color: p.ink3)),
          ]),
        ),
        Text(m.name,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 22,
                height: 1.6,
                color: p.ink)),
      ]),
    );
  }
}

/// The sūrah number in an 8-point star outline.
class _NumberBadge extends StatelessWidget {
  final int n;
  const _NumberBadge({required this.n});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return SizedBox.square(
      dimension: 40,
      child: Stack(alignment: Alignment.center, children: [
        Transform.rotate(
          angle: .785398,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(color: p.line3),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(color: p.line3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Text('$n',
            style: uiStyle(context,
                size: 12.5, weight: FontWeight.w700, color: p.accInk)),
      ]),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final SurahMeta meta;
  final int ayah;
  final VoidCallback onOpen;
  const _BookmarkCard({required this.meta, required this.ayah, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(AppIcons.bookmarkFilled, size: 18, color: p.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${meta.tname} · ${meta.n}:$ayah',
                style: uiStyle(context, size: 14, weight: FontWeight.w700)),
          ),
          Text(context.l10n.open,
              style: uiStyle(context, size: 13.5, weight: FontWeight.w700, color: p.acc)),
        ]),
        const SizedBox(height: 10),
        FutureBuilder<List<String>>(
          future: QuranRepo.ayahs(meta.n, 'uthmani'),
          builder: (context, snap) {
            final list = snap.data;
            if (list == null || ayah > list.length) {
              return const SizedBox(height: 40);
            }
            return Text(list[ayah - 1],
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 24,
                    height: 1.9,
                    color: p.ink));
          },
        ),
      ]),
    );
  }
}

/// Opens the reader for [m] from anywhere (phone: full screen; desktop: inside
/// the section).
void openSurah(BuildContext context, SurahMeta m, {int? ayah}) {
  Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(builder: (_) => SurahReaderScreen(meta: m, startAyah: ayah)));
}
