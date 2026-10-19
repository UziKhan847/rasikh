import 'marks_model.dart';
import 'marks_store.dart';
import 'review.dart';
import 'word_ref.dart';

/// How the report's verses are grouped.
enum ReportGrouping { surah, page }

/// What goes in a marks report: the same choice as a review (kinds, open or
/// fixed, where), a period by when the marks were made, and the grouping.
class ReportOptions {
  final ReviewQuery query;

  /// Marks made from [fromMs] to [toMs] (inclusive; null: no limit).
  final int? fromMs, toMs;
  final ReportGrouping grouping;
  const ReportOptions({
    this.query = const ReviewQuery(status: ReviewStatus.any),
    this.fromMs,
    this.toMs,
    this.grouping = ReportGrouping.surah,
  });
}

/// One mark as reported: the mark, its fix (if fixed), and the replies.
class ReportMark {
  final Mark mark;
  final MarkFix? fix;
  final List<MarkComment> replies;
  const ReportMark(this.mark, this.fix, this.replies);
}

/// One āyah with marks, and its marks in word order.
class ReportAyah {
  final int globalAyah;
  final int page;
  final List<ReportMark> marks;
  const ReportAyah(this.globalAyah, this.page, this.marks);
}

/// A sūrah's (or a page's) āyāt with marks.
class ReportGroup {
  final int number; // sūrah or page, by the grouping
  final List<ReportAyah> ayahs;
  const ReportGroup(this.number, this.ayahs);
}

class Report {
  final String bookId;
  final String bookName;
  final ReportOptions options;
  final int generatedAt;
  final Map<MarkType, int> openByType;
  final Map<MarkType, int> fixedByType;
  final List<ReportGroup> groups;
  const Report(this.bookId, this.bookName, this.options, this.generatedAt, this.openByType,
      this.fixedByType, this.groups);

  int get total =>
      openByType.values.fold(0, (a, b) => a + b) +
      fixedByType.values.fold(0, (a, b) => a + b);
  bool get isEmpty => groups.isEmpty;
  int get ayahCount => groups.fold(0, (n, g) => n + g.ayahs.length);
}

/// The report for [bookId]: the marks [o] selects, in muṣḥaf order, grouped
/// by āyah and then by sūrah or page ([pageOf]: a word's page in the
/// script the report is for).
Report buildReport(
  MarksStore store,
  String bookId,
  ReportOptions o, {
  required int Function(WordRef) pageOf,
  required int now,
}) {
  final open = {for (final t in MarkType.values) t: 0};
  final fixed = {for (final t in MarkType.values) t: 0};
  final byAyah = <int, List<ReportMark>>{};
  for (final m in buildReviewQueue(store, bookId, o.query, pageOf: pageOf)) {
    if (o.fromMs != null && m.createdAt < o.fromMs!) continue;
    if (o.toMs != null && m.createdAt > o.toMs!) continue;
    final f = store.fixOf(m);
    (f == null ? open : fixed)[m.type] = (f == null ? open : fixed)[m.type]! + 1;
    byAyah
        .putIfAbsent(m.ref.globalAyah, () => [])
        .add(ReportMark(m, f, store.commentsOn(m)));
  }
  final groups = <ReportGroup>[];
  for (final g in byAyah.keys.toList()..sort()) {
    final marks = byAyah[g]!;
    final page = pageOf(marks.first.mark.ref);
    final key = o.grouping == ReportGrouping.surah
        ? surahAyahFromGlobal(g).$1
        : page;
    if (groups.isEmpty || groups.last.number != key) {
      groups.add(ReportGroup(key, []));
    }
    groups.last.ayahs.add(ReportAyah(g, page, marks));
  }
  return Report(
      bookId, store.book(bookId)?.name ?? '', o, now, open, fixed, groups);
}
