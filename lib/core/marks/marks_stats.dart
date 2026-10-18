import 'marks_model.dart';
import 'word_ref.dart';

/// Which marks a stats view counts.
enum MarkStatus { all, open, fixed }

class MarkQuery {
  /// Only marks made at or after this time (ms since epoch); null = all time.
  final int? since;
  final Set<MarkType> types;
  final MarkStatus status;
  final SessionKind? kind;
  const MarkQuery({
    this.since,
    this.types = const {
      MarkType.mistake,
      MarkType.tajwid,
      MarkType.hesitation,
      MarkType.doubt,
    },
    this.status = MarkStatus.all,
    this.kind,
  });
}

/// The stacked-bar buckets, in their fixed colour order: each open mark
/// counts under its type; a fixed one under "fixed" whatever its type.
const statBuckets = <MarkType?>[
  MarkType.mistake,
  MarkType.tajwid,
  MarkType.hesitation,
  MarkType.doubt,
  MarkType.note,
  null, // fixed
];

int bucketOf(MarkType type, bool fixed) =>
    fixed ? statBuckets.length - 1 : statBuckets.indexOf(type);

class SessionStat {
  final RecitationSession session;
  final int marks;
  final int fixes;
  const SessionStat(this.session, this.marks, this.fixes);
}

class ProblemWord {
  final WordRef ref;
  final int count;
  final bool open;
  const ProblemWord(this.ref, this.count, this.open);
}

class MarkStats {
  final int total, open, fixed;

  /// Counts per bucket ([statBuckets] order).
  final List<int> byBucket;
  final List<List<int>> bySurah; // [114][bucket]
  final List<List<int>> byJuz; // [30][bucket]
  final List<int> byPage; // [pageCount] totals
  final List<SessionStat> sessions; // oldest first
  /// (day start ms, open marks at the end of that day), oldest first.
  final List<(int, int)> openOverTime;
  final List<ProblemWord> problemWords;

  const MarkStats({
    required this.total,
    required this.open,
    required this.fixed,
    required this.byBucket,
    required this.bySurah,
    required this.byJuz,
    required this.byPage,
    required this.sessions,
    required this.openOverTime,
    required this.problemWords,
  });

  double get fixRate => total == 0 ? 0 : fixed / total;
  bool get isEmpty => total == 0;
}

/// Pure: everything a stats screen shows, from one book's records.
/// [pageOf] maps a word to its page in the chosen script (pages differ
/// between the Madani and Indo-Pak muṣḥaf); [pageCount] is that script's.
MarkStats computeStats({
  required Iterable<Mark> marks,
  required Iterable<MarkFix> fixes,
  required Iterable<RecitationSession> sessions,
  required MarkQuery q,
  required int pageCount,
  required int Function(WordRef) pageOf,
  required int Function(int surah, int ayah) juzOf,
  int? now,
}) {
  final fixAt = <String, int>{};
  for (final f in fixes) {
    if (f.deleted) continue;
    final prev = fixAt[f.markId];
    if (prev == null || f.fixedAt < prev) fixAt[f.markId] = f.fixedAt;
  }
  final sessionById = {for (final s in sessions) s.id: s};

  final nb = statBuckets.length;
  final byBucket = List<int>.filled(nb, 0);
  final bySurah = List.generate(114, (_) => List<int>.filled(nb, 0));
  final byJuz = List.generate(30, (_) => List<int>.filled(nb, 0));
  final byPage = List<int>.filled(pageCount, 0);
  final perSession = <String, int>{};
  final perWord = <int, (int, bool)>{};
  final events = <(int, int)>[]; // (time, +1 open / -1 fixed)
  var total = 0, open = 0, fixed = 0;

  for (final m in marks) {
    if (m.deleted || !q.types.contains(m.type)) continue;
    if (q.since != null && m.createdAt < q.since!) continue;
    if (q.kind != null) {
      final s = m.sessionId == null ? null : sessionById[m.sessionId];
      if (s?.kind != q.kind) continue;
    }
    final isFixed = fixAt.containsKey(m.id);
    if (q.status == MarkStatus.open && isFixed) continue;
    if (q.status == MarkStatus.fixed && !isFixed) continue;

    total++;
    isFixed ? fixed++ : open++;
    final b = bucketOf(m.type, isFixed);
    byBucket[b]++;
    bySurah[m.ref.surah - 1][b]++;
    final j = juzOf(m.ref.surah, m.ref.ayah);
    byJuz[j - 1][b]++;
    final p = pageOf(m.ref);
    if (p >= 1 && p <= pageCount) byPage[p - 1]++;
    if (m.sessionId != null) {
      perSession[m.sessionId!] = (perSession[m.sessionId!] ?? 0) + 1;
    }
    if (m.type != MarkType.note) {
      final cur = perWord[m.ref.key];
      perWord[m.ref.key] =
          ((cur?.$1 ?? 0) + 1, (cur?.$2 ?? false) || !isFixed);
      events.add((m.createdAt, 1));
      if (isFixed) events.add((fixAt[m.id]!, -1));
    }
  }

  final fixesPerSession = <String, int>{};
  for (final f in fixes) {
    if (f.deleted || f.sessionId == null) continue;
    fixesPerSession[f.sessionId!] = (fixesPerSession[f.sessionId!] ?? 0) + 1;
  }
  final sessionStats = [
    for (final s in sessions)
      if (!s.deleted &&
          (q.since == null || s.startedAt >= q.since!) &&
          (q.kind == null || s.kind == q.kind))
        SessionStat(s, perSession[s.id] ?? 0, fixesPerSession[s.id] ?? 0)
  ]..sort((a, b) => a.session.startedAt.compareTo(b.session.startedAt));

  // Open marks at the end of each day with activity.
  events.sort((a, b) => a.$1.compareTo(b.$1));
  final overTime = <(int, int)>[];
  var running = 0;
  for (final (t, d) in events) {
    running += d;
    final day = DateTime.fromMillisecondsSinceEpoch(t);
    final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    if (overTime.isNotEmpty && overTime.last.$1 == key) {
      overTime[overTime.length - 1] = (key, running);
    } else {
      overTime.add((key, running));
    }
  }

  final problems = [
    for (final e in perWord.entries)
      if (e.value.$1 >= 2)
        ProblemWord(WordRef.fromKey(e.key), e.value.$1, e.value.$2)
  ]..sort((a, b) => b.count != a.count
      ? b.count.compareTo(a.count)
      : a.ref.key.compareTo(b.ref.key));

  return MarkStats(
    total: total,
    open: open,
    fixed: fixed,
    byBucket: byBucket,
    bySurah: bySurah,
    byJuz: byJuz,
    byPage: byPage,
    sessions: sessionStats,
    openOverTime: overTime,
    problemWords: problems.take(30).toList(),
  );
}
