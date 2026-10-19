import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/review.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// Where review shows its marks: on the muṣḥaf page, or as verse cards.
enum ReviewView { mushaf, cards }

/// Asks what to review — which kinds, where (around [page]), open or fixed,
/// and in which view — with the count each choice would give. Null if
/// dismissed. [script] must be loaded.
Future<(ReviewQuery, ReviewView)?> showReviewSetup(
  BuildContext context, {
  required MarksStore store,
  required String bookId,
  required String script,
  required int page,
  ReviewView view = ReviewView.mushaf,
}) {
  return showModalBottomSheet<(ReviewQuery, ReviewView)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _ReviewSetup(
        store: store, bookId: bookId, script: script, page: page, view: view),
  );
}

class _ReviewSetup extends StatefulWidget {
  final MarksStore store;
  final String bookId;
  final String script;
  final int page;
  final ReviewView view;
  const _ReviewSetup({
    required this.store,
    required this.bookId,
    required this.script,
    required this.page,
    required this.view,
  });

  @override
  State<_ReviewSetup> createState() => _ReviewSetupState();
}

class _ReviewSetupState extends State<_ReviewSetup> {
  late ReviewQuery _q = ReviewQuery(script: widget.script);
  late ReviewView _view = widget.view;

  int _pageOf(WordRef r) => MushafRepo.pageOfWord(
      widget.script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1);

  int _count(ReviewQuery q) =>
      buildReviewQueue(widget.store, widget.bookId, q, pageOf: _pageOf).length;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final mp = markPaletteFor(p,
        mono: SettingsScope.of(context).appTheme == 'mono');
    final (s, a) = MushafRepo.firstVerseOfPage(widget.script, widget.page);
    // Where: the whole book, or the divisions around the page.
    final scopes = <(Division?, int, String)>[
      (null, 0, context.l10n.rvWholeBook),
      (Division.page, widget.page, context.l10n.pageN(widget.page)),
      (Division.surah, s, '${context.l10n.idxSurah} $s'),
      (Division.juz, divisionOf(Division.juz, s, a),
          context.l10n.juzN(divisionOf(Division.juz, s, a))),
      (Division.hizb, hizbOf(s, a), context.l10n.idxHizbN(hizbOf(s, a))),
      (Division.rub, rubOf(s, a), context.l10n.idxRubN(rubOf(s, a))),
    ];
    final total = _count(_q);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.rvSetupTitle,
                style: displayStyle(context, size: 24)),
            QSectionLabel(context.l10n.rvTypes),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                label: Text(context.l10n.rvAll),
                selected: _q.types.isEmpty,
                onSelected: (_) =>
                    setState(() => _q = _q.copyWith(types: const {})),
              ),
              for (final t in MarkType.values)
                FilterChip(
                  avatar: MarkSwatch(type: t, pal: mp, size: 14),
                  label: Text('${markTypeLabel(context, t)} · '
                      '${_count(_q.copyWith(types: {t}))}'),
                  selected: _q.types.contains(t),
                  onSelected: (on) => setState(() {
                    final ts = {..._q.types};
                    on ? ts.add(t) : ts.remove(t);
                    _q = _q.copyWith(types: ts);
                  }),
                ),
            ]),
            QSectionLabel(context.l10n.rvScope),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (d, n, label) in scopes)
                ChoiceChip(
                  label: Text(
                      '$label · ${_count(d == null ? _q.copyWith(everywhere: true) : _q.copyWith(division: d, number: n))}'),
                  selected: _q.division == d && (d == null || _q.number == n),
                  onSelected: (_) => setState(() => _q = d == null
                      ? _q.copyWith(everywhere: true)
                      : _q.copyWith(division: d, number: n)),
                ),
            ]),
            QSectionLabel(context.l10n.rvStatus),
            QSegmented<ReviewStatus>(
              options: [
                (ReviewStatus.open, context.l10n.rvOpen, null),
                (ReviewStatus.fixed, context.l10n.rvFixed, null),
                (ReviewStatus.any, context.l10n.rvAny, null),
              ],
              value: _q.status,
              onChanged: (v) => setState(() => _q = _q.copyWith(status: v)),
            ),
            QSectionLabel(context.l10n.rvView),
            QSegmented<ReviewView>(
              options: [
                (ReviewView.mushaf, context.l10n.rvViewMushaf, AppIcons.mushaf),
                (ReviewView.cards, context.l10n.rvViewCards, AppIcons.cards),
              ],
              value: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
            const SizedBox(height: 18),
            QPrimaryButton(
              total == 0
                  ? context.l10n.rvNone
                  : '${context.l10n.rvStart} · ${context.l10n.rvCountN(total)}',
              onTap: total == 0
                  ? null
                  : () => Navigator.pop(context, (_q, _view)),
            ),
          ],
        ),
      ),
    );
  }
}
