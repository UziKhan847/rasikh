import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_stats.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import '../shell/app_shell.dart';
import 'charts.dart';
import 'export_sheet.dart';
import 'marking.dart' show askText;
import 'marks_stats_screen.dart';
import 'mutashabihat_screen.dart';
import 'sync_section.dart';
import '../../ui/overlay_screen.dart';

/// History: the profile's marks at a glance, and every marking and review
/// session — kept by itself, by its date and time, when it ended. A tap
/// opens the muṣḥaf where it was; holding one, a note or delete.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    final p = pal(context);
    final l = context.l10n;
    if (store == null || !store.ready) {
      return QPage(
        title: l.hsTitle,
        children: [
          const SizedBox(height: 40),
          Center(child: CircularProgressIndicator(color: p.acc)),
        ],
      );
    }
    final mp = markPaletteFor(
      p,
      mono: SettingsScope.of(context).appTheme == 'mono',
    );
    final book = store.activeBook;
    final sessions = book == null
        ? const <RecitationSession>[]
        : [
            for (final s in store.sessionsOf(book.id))
              if (!s.isOpen) s,
          ];
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
      title: l.hsTitle,
      children: [
        if (book != null && st != null && !st.isEmpty)
          QCard(
            onTap: () => showOverlayScreen(
              context,
              MarksStatsScreen(bookId: book.id),
              wide: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.mkTotal} ${st.total} · ${l.mkOpen} ${st.open} · ${l.mkFixed} ${st.fixed}',
                        style: uiStyle(
                          context,
                          size: 14.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(AppIcons.chart, size: 20, color: p.ink3),
                  ],
                ),
                const SizedBox(height: 10),
                StackedBar(
                  values: st.byBucket,
                  max: st.total,
                  mp: mp,
                  height: 12,
                ),
                const SizedBox(height: 8),
                BucketLegend(
                  pal: mp,
                  buckets: {
                    for (var b = 0; b < st.byBucket.length; b++)
                      if (st.byBucket[b] > 0) b,
                  },
                ),
              ],
            ),
          ),
        QSectionLabel(l.hsSessions),
        if (sessions.isEmpty)
          Text(l.hsNone, style: uiStyle(context, size: 13.5, color: p.ink3))
        else
          QGroup(
            children: [
              for (final s in sessions) _SessionRow(store: store, session: s),
            ],
          ),
        const SizedBox(height: 10),
        QGroup(
          children: [
            QRow(
              leading: Icon(AppIcons.link, color: p.acc),
              title: l.mtTitle,
              subtitle: l.mtTitleSub,
              chevron: true,
              onTap: () => showOverlayScreen(
                context,
                const MutashabihatScreen(),
                wide: true,
              ),
            ),
          ],
        ),
        const SyncSection(),
        QSectionLabel(l.mkYourName),
        QGroup(
          children: [
            QRow(
              title: store.me.displayName.isEmpty
                  ? l.mkYou
                  : store.me.displayName,
              subtitle: l.mkYourNameSub,
              leading: Icon(AppIcons.person, color: p.ink3),
              chevron: true,
              onTap: () async {
                final n = await askText(
                  context,
                  title: l.mkYourName,
                  initial: store.me.displayName,
                  hint: l.mkYourName,
                );
                if (n != null) store.renameMe(n);
              },
            ),
          ],
        ),
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
    final l = context.l10n;
    final s = session;
    final review = s.kind == SessionKind.review;
    final marks = store
        .marksOf(s.bookId)
        .where((m) => m.sessionId == s.id)
        .length;
    final fixes = store
        .fixesOf(s.bookId)
        .where((f) => f.sessionId == s.id)
        .length;
    String ref(int g) {
      final (su, a) = surahAyahFromGlobal(g);
      return '$su:$a';
    }

    final when = DateFormat.yMMMEd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(s.startedAt));
    final parts = [
      review ? l.hsReview : l.hsMarking,
      if (s.fromGlobalAyah != null && s.toGlobalAyah != null)
        '${ref(s.fromGlobalAyah!)}–${ref(s.toGlobalAyah!)}',
      review ? l.hsFixedN(fixes) : l.hsMarksN(marks),
      if (s.note.isNotEmpty) s.note,
    ];
    return QRow(
      leading: Icon(
        review ? AppIcons.review : AppIcons.pen,
        color: pal(context).acc,
      ),
      title: when,
      subtitle: parts.join(' · '),
      chevron: true,
      onTap: () async {
        final g = s.fromGlobalAyah;
        if (g == null) return openMushaf(context, script: s.script);
        await MushafRepo.ensure(s.script);
        if (!context.mounted) return;
        openMushaf(
          context,
          page: MushafRepo.pageForGlobalAyah(s.script, g),
          script: s.script,
        );
      },
      onLongPress: () => _options(context),
    );
  }

  Future<void> _options(BuildContext context) async {
    final l = context.l10n;
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.pdf),
              title: Text(l.tcExport),
              onTap: () => Navigator.pop(c, 'export'),
            ),
            ListTile(
              leading: const Icon(AppIcons.comment),
              title: Text(l.hsNote),
              onTap: () => Navigator.pop(c, 'note'),
            ),
            ListTile(
              leading: const Icon(AppIcons.delete),
              title: Text(l.hsDelete),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (pick == 'note') {
      final n = await askText(
        context,
        title: l.hsNote,
        initial: session.note,
        hint: l.hsNote,
      );
      if (n != null) store.updateSession(session.bookId, session.id, note: n);
    } else if (pick == 'delete') {
      store.deleteSession(session.bookId, session.id);
    } else if (pick == 'export') {
      // On the pages the session went over.
      final s = session;
      await MushafRepo.ensure(s.script);
      if (!context.mounted) return;
      int? page(int? g) =>
          g == null ? null : MushafRepo.pageForGlobalAyah(s.script, g);
      await showExportSheet(
        context,
        store: store,
        bookId: s.bookId,
        script: s.script,
        currentPage: page(s.fromGlobalAyah),
        toPage: page(s.toGlobalAyah),
      );
    }
  }
}
