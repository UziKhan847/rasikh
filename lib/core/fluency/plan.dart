import '../../data/fluency_tiers.dart';
import '../../data/mushaf.dart';
import 'fluency_store.dart';

/// The fluency plan's twelve weeks, in four phases, each with a check
/// before moving on; and where its cold reads come from: passages the
/// reader hasn't heard (in the Reader) or marked as known by heart.

enum PlanPhase { foundation, building, transfer, independence }

PlanPhase phaseOfWeek(int week) => week <= 3
    ? PlanPhase.foundation
    : week <= 6
        ? PlanPhase.building
        : week <= 9
            ? PlanPhase.transfer
            : PlanPhase.independence;

/// The sūrahs each phase's cold reads come from: the later Juz ʿAmma, Juz
/// Tabārak, the narrative sūrahs, then the whole muṣḥaf.
List<int> coldSurahsOf(PlanPhase p) => switch (p) {
      PlanPhase.foundation => [for (var s = 78; s <= 100; s++) s],
      PlanPhase.building => [for (var s = 67; s <= 77; s++) s],
      PlanPhase.transfer => const [12, 19, 20],
      PlanPhase.independence => [for (var s = 2; s <= 114; s++) s],
    };

/// A passage (first and last global āyah) long enough for a minute's read.
typedef Passage = (int, int);

/// Unseen passages for [week]'s cold read, in order: each about [words]
/// words from an āyah's start, none heard, used or known.
Iterable<Passage> coldPassages(FluencyStore store, String script, int week, {int words = 150}) sync* {
  final used = [for (final c in store.coldReads) (c.firstTok, c.lastTok)];
  bool unseen(int from, int to) {
    for (var g = from; g <= to; g++) {
      if (store.heard(g)) return false;
    }
    final a = MushafRepo.tokenOf(script, from, 0), b = MushafRepo.tokenOf(script, to, -1);
    for (final (x, y) in used) {
      if (a <= y && x <= b) return false;
    }
    return !store.known.contains(a);
  }

  for (final s in coldSurahsOf(phaseOfWeek(week))) {
    final first = MushafRepo.globalAyahOf(s, 1);
    final count = MushafRepo.ayahCountOf(s);
    var g = first;
    while (g < first + count) {
      var to = g, n = 0;
      while (to < first + count && n < words) {
        n += MushafRepo.ayahTokens(script, to).$2.where((w) => !w.isMarker).length;
        to++;
      }
      to--;
      if (n >= words ~/ 2 && unseen(g, to)) yield (g, to);
      g = to + 1;
    }
  }
}

/// One check before moving on: what it asks, and whether it's met (null:
/// not measurable yet).
typedef PlanCheck = ({String id, bool? met});

/// [phase]'s checks, from the reader's cards and cold reads.
List<PlanCheck> checksOf(PlanPhase phase, FluencyStore store, String script) {
  double instantShare(int tier) {
    final ws = tierWords(script).where((w) => w.tier == tier).toList();
    if (ws.isEmpty) return 0;
    final n = ws.where((w) {
      final p = store.progressOf(w.cardId);
      return p != null && (p.retired || p.last == Recall.instant);
    }).length;
    return n / ws.length;
  }

  final reads = store.coldReads;
  final base = reads.isEmpty ? null : reads.first;
  final last = reads.length < 2 ? null : reads.last;
  double stallsPerMin(ColdRead c) => c.stalls * 60 / c.seconds;
  final scored = reads.where((c) => c.perception != null);
  return switch (phase) {
    PlanPhase.foundation => [
        (id: 'tier1', met: instantShare(1) >= .9),
        (
          id: 'stalls',
          met: base == null || last == null ? null : stallsPerMin(last) <= stallsPerMin(base) / 2
        ),
      ],
    PlanPhase.building => [
        (id: 'tier2', met: instantShare(2) >= .8),
        (id: 'perception', met: scored.isEmpty ? null : scored.last.perception! >= 8),
      ],
    PlanPhase.transfer => [
        (id: 'cold25', met: base == null || last == null ? null : last.perMinute >= base.perMinute * 1.25),
      ],
    PlanPhase.independence => [
        (
          id: 'three',
          met: base == null || reads.length < 4
              ? null
              : reads.skip(reads.length - 3).every((c) => c.perMinute >= base.perMinute * 1.25)
        ),
      ],
  };
}
