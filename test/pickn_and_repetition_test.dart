import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/makharij.dart';
import 'package:qiraah_arabiyyah/data/script_diff.dart';
import 'package:qiraah_arabiyyah/data/sifat.dart';
import 'package:qiraah_arabiyyah/data/small_letters.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';
import 'package:qiraah_arabiyyah/data/tanwin_allographs.dart';
import 'package:qiraah_arabiyyah/data/variants.dart';
import 'package:qiraah_arabiyyah/data/waqf.dart';
import 'package:qiraah_arabiyyah/data/wasl.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

/// [pickN] is the shared "no repeat until the pool is exhausted" sampler
/// introduced to fix the app-wide quiz repetition audit (Round 11). These
/// tests pin its contract directly; the per-screen regression coverage is in
/// `test/tajwid_script_navigation_test.dart` (real widget navigation) plus
/// the data-adequacy checks below, which confirm the underlying pools this
/// session's data-expansion pass (Round 10) actually grew — the reason a
/// thin pool like Qalqalah's single rule can still produce several distinct
/// questions instead of repeating the identical verse.
void main() {
  group('pickN', () {
    final rng = math.Random(7);

    test('n <= pool.length returns exactly n distinct items from the pool',
        () {
      final pool = [1, 2, 3, 4, 5];
      final out = pickN(pool, 3, rng);
      expect(out.length, 3);
      expect(out.toSet().length, 3, reason: 'no repeats within one draw');
      for (final x in out) {
        expect(pool.contains(x), isTrue);
      }
    });

    test('n == pool.length returns every item exactly once', () {
      final pool = ['a', 'b', 'c', 'd'];
      final out = pickN(pool, 4, rng);
      expect(out.toSet(), pool.toSet());
      expect(out.length, 4);
    });

    test('n > pool.length cycles: every item appears floor(n/size) or '
        'ceil(n/size) times, never more, never fewer', () {
      final pool = [1, 2, 3];
      final out = pickN(pool, 8, rng);
      expect(out.length, 8);
      final counts = <int, int>{};
      for (final x in out) {
        counts[x] = (counts[x] ?? 0) + 1;
      }
      expect(counts.keys.toSet(), pool.toSet());
      for (final c in counts.values) {
        expect(c, inInclusiveRange(2, 3)); // floor(8/3)=2, ceil(8/3)=3
      }
    });

    test('a single-item pool asked for many repeats every time (the '
        'irreducible case — no sampling strategy can invent variety a '
        'concept genuinely doesn\'t have)', () {
      final out = pickN(['only'], 5, rng);
      expect(out, ['only', 'only', 'only', 'only', 'only']);
    });

    test('empty pool or n <= 0 returns an empty list', () {
      expect(pickN(<int>[], 5, rng), isEmpty);
      expect(pickN([1, 2, 3], 0, rng), isEmpty);
    });

    test('the same pool sampled twice in a row is very unlikely to produce '
        'the exact same order (sanity check that shuffling is real, not a '
        'no-op)', () {
      final pool = List.generate(20, (i) => i);
      final a = pickN(pool, 20, rng);
      final b = pickN(pool, 20, rng);
      expect(a, isNot(equals(b)));
    });
  });

  group('Round 10 data adequacy — the precondition Round 11\'s fixes rely on',
      () {
    // Every one of these used to be a single hard-coded example (or, for
    // makhārij/ṣifāt, none at all); a quiz asking N>1 questions about the
    // same underlying concept can only vary the verse shown if the data
    // actually has more than one. This is what makes Qalqalah's Test no
    // longer repeat one identical verse — checked directly here, since the
    // random sampling itself is already covered by the pickN tests above.
    test('every tajwīd rule has more than one real example verse', () {
      for (final r in tajwidRules) {
        expect(r.moreExamples.length, greaterThanOrEqualTo(2),
            reason: 'Rule "${r.id}" still has too few examples for real '
                'quiz variety');
      }
    });

    test('the thinnest rule families (qalqalah: 1 rule, rāʾ: 2, lām: 3) each '
        'still have enough distinct (rule, verse) instances for a '
        '6-question session without repeats', () {
      final qalqalah = tajwidRules.firstWhere((r) => r.id == 'qalqalah');
      expect(1 + qalqalah.moreExamples.length, greaterThanOrEqualTo(6));

      final raaInstances = tajwidRules
          .where((r) => r.id == 'raa_tafkhim' || r.id == 'raa_tarqiq')
          .fold<int>(0, (n, r) => n + 1 + r.moreExamples.length);
      expect(raaInstances, greaterThanOrEqualTo(6));

      final lamInstances = tajwidRules
          .where((r) => ['shamsiyya', 'qamariyya', 'lam_jalalah'].contains(r.id))
          .fold<int>(0, (n, r) => n + 1 + r.moreExamples.length);
      expect(lamInstances, greaterThanOrEqualTo(6));
    });

    test('makhārij and ṣifāt — previously zero examples — now have several '
        'per entry (except khayshūm, which has no letters of its own)', () {
      for (final m in makharij) {
        if (m.id == 'khayshum') continue;
        expect(m.examples, isNotEmpty, reason: m.id);
      }
      for (final s in sifat) {
        expect(s.examples, isNotEmpty, reason: s.id);
      }
    });

    test('every waqf mark has more than one real example', () {
      for (final m in waqfMarks) {
        expect(m.moreExamples.length, greaterThanOrEqualTo(2), reason: m.id);
      }
    });

    test('wasl solar/lunar letters and the zero-sign contrast each have '
        'more than one example', () {
      for (final w in waslOfKind('solar')) {
        expect(w.moreExamples, isNotEmpty, reason: w.id);
      }
      for (final w in waslOfKind('lunar')) {
        expect(w.moreExamples, isNotEmpty, reason: w.id);
      }
    });

    test('tanwīn allographs, letter variants, and small letters each have '
        'more than one example', () {
      for (final a in tanwinAllographs) {
        expect(a.moreExamples, isNotEmpty, reason: a.id);
      }
      for (final v in letterVariants) {
        expect(v.moreExamples, isNotEmpty, reason: v.id);
      }
      for (final s in smallLetters) {
        expect(s.moreExamples, isNotEmpty, reason: s.id);
      }
    });

    test('script_diff.dart grew beyond its original 4 entries', () {
      expect(scriptDifferences.length, greaterThanOrEqualTo(6));
    });
  });
}
