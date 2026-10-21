import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_stats.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/memorize.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../shell/app_shell.dart';
import '../mushaf/memorize_cards_screen.dart';
import '../mushaf/mushaf_index_sheet.dart';
import '../mushaf_screen.dart' show MushafPageScreen;
import 'charts.dart';
import 'mark_books_screen.dart';
import 'marking.dart';
import 'marks_stats_screen.dart';
import 'mutashabihat_screen.dart';
import 'report_pdf.dart';
import 'review_cards_screen.dart';
import 'sync_section.dart';

/// The Hifz section: whose recitation (the active mark book), "Start
/// listening", a summary of the marks, recent sessions, and — once signed in —
/// sharing books with listeners.
/// The muṣḥaf index over the Hifz screen: its count pills show where the
/// active book's marks are; a pick opens the muṣḥaf there.
Future<void> _openIndex(BuildContext context) async {
  final script = SettingsScope.of(context).mushafScript;
  final prog = ProgressScope.read(context);
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  final here = prog.lastMushafScript == script ? prog.lastMushafPage ?? 1 : 1;
  await showMushafIndex(
    context,
    script: script,
    currentPage: here,
    initial: Division.juz,
    onPage: (p) => openMushaf(context, page: p, script: script),
    onWord: (w) => openMushaf(context,
        page: MushafRepo.pageOfWord(
            script, w.globalAyah, w.word <= 0 ? 0 : w.word - 1),
        script: script),
  );
}

/// Memorize as verse cards from the last page read.
Future<void> _openMemorizeCards(BuildContext context) async {
  final script = SettingsScope.of(context).mushafScript;
  final prog = ProgressScope.read(context);
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  final page = prog.lastMushafScript == script ? prog.lastMushafPage ?? 1 : 1;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MemorizeCardsScreen(
          controller: MemorizeController.startAt(script, page))));
}

/// Memorize in the muṣḥaf from a sūrah, juzʼ, page… chosen in the index.
Future<void> _openMemorizeFrom(BuildContext context) async {
  final script = SettingsScope.of(context).mushafScript;
  final prog = ProgressScope.read(context);
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  final here = prog.lastMushafScript == script ? prog.lastMushafPage ?? 1 : 1;
  final t =
      await chooseMemorizeStart(context, script: script, currentPage: here);
  if (t == null || !context.mounted) return;
  final c = MemorizeController.startAtToken(script, t);
  await Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(
          builder: (_) => MushafPageScreen(
              startPage: c.viewPage, script: script, memorize: c)));
}

/// Review the active book's marks, around the last page read.
Future<void> _openReview(BuildContext context) async {
  final script = SettingsScope.of(context).mushafScript;
  final prog = ProgressScope.read(context);
  await MushafRepo.ensure(script);
  if (!context.mounted) return;
  final page = prog.lastMushafScript == script ? prog.lastMushafPage ?? 1 : 1;
  await startReview(context, script: script, page: page);
}

class HifzScreen extends StatelessWidget {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final p = pal(context);
    if (store == null || !store.ready) {
      return QPage(title: context.l10n.mkHifzTitle, children: [
        const SizedBox(height: 40),
        Center(child: CircularProgressIndicator(color: p.acc)),
      ]);
    }
    final mp = markPaletteFor(p,
        mono: SettingsScope.of(context).appTheme == 'mono');
    final book = store.activeBook;
    final sessions =
        book == null ? const <RecitationSession>[] : store.sessionsOf(book.id);
    final st = book == null
        ? null
        : computeStats(
            marks: store.marksOf(book.id),
            fixes: store.fixesOf(book.id),
            sessions: sessions,
            q: const MarkQuery(),
            pageCount: 0,
            pageOf: (_) => 0,
            juzOf: MushafRepo.juzOfAyah,
          );

    return QPage(
      title: context.l10n.mkHifzTitle,
      actions: [
        QIconButton(
          icon: AppIcons.indexList,
          tooltip: context.l10n.idxIndex,
          onTap: () => _openIndex(context),
        ),
        QIconButton(
          icon: AppIcons.group,
          tooltip: context.l10n.mkManageBooks,
          onTap: () => pushAdaptive(context, const MarkBooksScreen()),
        ),
      ],
      children: [
        QHeroCard(
          onTap: () => openMushaf(context, startMarking: true),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.mkStartListening,
                        style: displayStyle(context,
                            size: 24, color: kHeroInk)),
                    const SizedBox(height: 4),
                    Text(context.l10n.mkStartListeningSub,
                        style: uiStyle(context, size: 13.5, color: kHeroInk2)),
                  ]),
            ),
            const SizedBox(width: 12),
            const Icon(AppIcons.pen, color: kHeroGold, size: 30),
          ]),
        ),
        const SizedBox(height: 10),
        QGroup(children: [
          QRow(
            leading: Icon(AppIcons.memorize, color: p.acc),
            title: context.l10n.mzStartFrom,
            subtitle: context.l10n.mzStartFromSub,
            chevron: true,
            onTap: () => _openMemorizeFrom(context),
          ),
          QRow(
            leading: Icon(AppIcons.link, color: p.acc),
            title: context.l10n.mtTitle,
            subtitle: context.l10n.mtTitleSub,
            chevron: true,
            onTap: () => pushAdaptive(context, const MutashabihatScreen()),
          ),
          QRow(
            leading: Icon(AppIcons.cards, color: p.acc),
            title: context.l10n.mzStartCards,
            subtitle: context.l10n.mzStartCardsSub,
            chevron: true,
            onTap: () => _openMemorizeCards(context),
          ),
        ]),
        if (book != null) ...[
          QSectionLabel(
            context.l10n.mkReciter,
            trailing: store.books.length > 1
                ? PopupMenuButton<String>(
                    tooltip: context.l10n.mkMarkBook,
                    onSelected: store.setActiveBook,
                    itemBuilder: (_) => [
                      for (final b in store.books)
                        PopupMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(book.name,
                          style: uiStyle(context,
                              size: 13, weight: FontWeight.w700, color: p.accInk)),
                      Icon(AppIcons.chevronDown, size: 16, color: p.accInk),
                    ]),
                  )
                : null,
          ),
          QCard(
            onTap: () => pushAdaptive(context, MarksStatsScreen(bookId: book.id)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(book.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiStyle(context,
                              size: 16, weight: FontWeight.w700)),
                    ),
                    Icon(AppIcons.chart, size: 20, color: p.ink3),
                  ]),
                  const SizedBox(height: 10),
                  if (st == null || st.isEmpty)
                    Text(context.l10n.mkNoMarksYetSub,
                        style: uiStyle(context, size: 13.5, color: p.ink3))
                  else ...[
                    StackedBar(
                        values: st.byBucket, max: st.total, mp: mp, height: 12),
                    const SizedBox(height: 10),
                    Text(
                      '${context.l10n.mkTotal} ${st.total} · '
                      '${context.l10n.mkOpen} ${st.open} · '
                      '${context.l10n.mkFixed} ${st.fixed}',
                      style: uiStyle(context, size: 13.5, color: p.ink2),
                    ),
                    const SizedBox(height: 8),
                    BucketLegend(pal: mp, buckets: {
                      for (var b = 0; b < st.byBucket.length; b++)
                        if (st.byBucket[b] > 0) b
                    }),
                  ],
                ]),
          ),
          if (st != null && !st.isEmpty) ...[
            const SizedBox(height: 10),
            QGroup(children: [
              QRow(
                leading: Icon(AppIcons.review, color: p.acc),
                title: context.l10n.rvSetupTitle,
                subtitle: context.l10n.rvTapHint,
                chevron: true,
                onTap: () => _openReview(context),
              ),
              QRow(
                leading: Icon(AppIcons.pdf, color: p.acc),
                title: context.l10n.rpExport,
                chevron: true,
                onTap: () => showReportSheet(context,
                    store: store,
                    bookId: book.id,
                    script: SettingsScope.of(context).mushafScript),
              ),
            ]),
          ],
        ],
        QSectionLabel(context.l10n.mkRecentSessions),
        if (sessions.isEmpty)
          Text(context.l10n.mkNoSessions,
              style: uiStyle(context, size: 13.5, color: p.ink3))
        else
          QGroup(children: [
            for (final s in sessions.take(12))
              _SessionRow(store: store, session: s),
          ]),
        const SyncSection(),
        QSectionLabel(context.l10n.mkYourName),
        QGroup(children: [
          QRow(
            title: store.me.displayName.isEmpty
                ? context.l10n.mkYou
                : store.me.displayName,
            subtitle: context.l10n.mkYourNameSub,
            leading: Icon(AppIcons.person, color: p.ink3),
            chevron: true,
            onTap: () async {
              final n = await askText(context,
                  title: context.l10n.mkYourName,
                  initial: store.me.displayName,
                  hint: context.l10n.mkYourName);
              if (n != null) store.renameMe(n);
            },
          ),
        ]),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final MarksStore store;
  final RecitationSession session;
  const _SessionRow({required this.store, required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final count =
        store.marksOf(s.bookId).where((m) => m.sessionId == s.id).length;
    String ref(int g) {
      final (su, a) = surahAyahFromGlobal(g);
      return '$su:$a';
    }

    final parts = [
      if (s.kind != SessionKind.none) sessionKindLabel(context, s.kind),
      if (s.listenerName.isNotEmpty) s.listenerName,
      if (s.fromGlobalAyah != null && s.toGlobalAyah != null)
        '${ref(s.fromGlobalAyah!)}–${ref(s.toGlobalAyah!)}',
      if (s.isOpen) context.l10n.mkActive,
    ];
    return QRow(
      title: context.l10n.mkSessionLine(shortDate(context, s.startedAt), count),
      subtitle: parts.isEmpty ? null : parts.join(' · '),
      chevron: true,
      onTap: () async {
        final g = s.fromGlobalAyah;
        if (g == null) {
          openMushaf(context, script: s.script);
          return;
        }
        await MushafRepo.ensure(s.script);
        if (!context.mounted) return;
        openMushaf(context,
            page: MushafRepo.pageForGlobalAyah(s.script, g), script: s.script);
      },
    );
  }
}
