import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';

/// [ProgressStore.dayIndexFor] anchors "today" to the device's LOCAL
/// calendar date, not UTC midnight — a streak/review-due day must flip at
/// the user's own midnight, not Greenwich's (see the doc comment on
/// `dayIndexFor` for the UTC-anchoring bug this replaced, and why building
/// it from calendar fields rather than converting the instant sidesteps
/// DST entirely).
void main() {
  test('the same local calendar date always gives the same day index', () {
    final morning = DateTime(2026, 3, 15, 0, 1);
    final night = DateTime(2026, 3, 15, 23, 59);
    expect(ProgressStore.dayIndexFor(morning),
        ProgressStore.dayIndexFor(night));
  });

  test('consecutive local calendar dates differ by exactly one', () {
    final today = ProgressStore.dayIndexFor(DateTime(2026, 3, 15, 12));
    final tomorrow = ProgressStore.dayIndexFor(DateTime(2026, 3, 16, 12));
    final yesterday = ProgressStore.dayIndexFor(DateTime(2026, 3, 14, 12));
    expect(tomorrow, today + 1);
    expect(yesterday, today - 1);
  });

  test('1970-01-01 is day 0, per the weekday formula\'s own assumption', () {
    expect(ProgressStore.dayIndexFor(DateTime(1970, 1, 1, 12)), 0);
  });

  test('a US "spring forward" DST day still advances the index by exactly one',
      () {
    // 2026-03-08 is DST start in the US (a 23-hour local day); a naive
    // instant-based day index (converting local midnight to a UTC instant
    // and dividing by a fixed 86400000ms) can misround days like this —
    // dayIndexFor is built from calendar fields precisely to avoid that.
    final before = ProgressStore.dayIndexFor(DateTime(2026, 3, 7, 12));
    final after = ProgressStore.dayIndexFor(DateTime(2026, 3, 9, 12));
    expect(after, before + 2);
  });
}
