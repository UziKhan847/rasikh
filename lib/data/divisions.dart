import 'divisions_data.dart';

export 'divisions_data.dart';

/// The ways the muṣḥaf is divided, for the index and for review scopes.
/// Pages depend on the script (see MushafRepo); the rest are the same in
/// both.
enum Division { page, surah, juz, hizb, rub, manzil, ruku }

/// How many [d] there are (pages: pass the script's page count).
int divisionCount(Division d, {int pages = 604}) => switch (d) {
      Division.page => pages,
      Division.surah => 114,
      Division.juz => 30,
      Division.hizb => 60,
      Division.rub => rubStarts.length,
      Division.manzil => manzilStarts.length,
      Division.ruku => rukuStarts.length,
    };

bool _before((int, int) x, int s, int a) =>
    x.$1 < s || (x.$1 == s && x.$2 <= a);

/// 1-based index of the last of [starts] at or before [s]:[a].
int _within(List<(int, int)> starts, int s, int a) {
  var lo = 0, hi = starts.length - 1, ans = 0;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (_before(starts[mid], s, a)) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans + 1;
}

/// 1..240: the quarter-ḥizb [s]:[a] is in.
int rubOf(int s, int a) => _within(rubStarts, s, a);

/// 1..60: the ḥizb [s]:[a] is in.
int hizbOf(int s, int a) => (rubOf(s, a) - 1) ~/ 4 + 1;

/// 1..30: the juzʼ [s]:[a] is in (eight quarters to a juzʼ).
int juzOfRubAyah(int s, int a) => (rubOf(s, a) - 1) ~/ 8 + 1;

/// 1..7: the manzil [s]:[a] is in.
int manzilOf(int s, int a) => _within(manzilStarts, s, a);

/// 1..558: the rukūʿ [s]:[a] is in.
int rukuOf(int s, int a) => _within(rukuStarts, s, a);

/// How many rukūʿ sūrah [s] has (the Indo-Pak header prints it).
int rukuCountOf(int s) => rukuStarts.where((r) => r.$1 == s).length;

/// [d] number [n] of [s]:[a] (not pages, whose numbers depend on the
/// script).
int divisionOf(Division d, int s, int a) => switch (d) {
      Division.page => throw ArgumentError('pages depend on the script'),
      Division.surah => s,
      Division.juz => juzOfRubAyah(s, a),
      Division.hizb => hizbOf(s, a),
      Division.rub => rubOf(s, a),
      Division.manzil => manzilOf(s, a),
      Division.ruku => rukuOf(s, a),
    };

/// The first (sūrah, āyah) of [d] number [n] (not pages).
(int, int) firstAyahOf(Division d, int n) => switch (d) {
      Division.page => throw ArgumentError('pages depend on the script'),
      Division.surah => (n, 1),
      Division.juz => rubStarts[(n - 1) * 8],
      Division.hizb => rubStarts[(n - 1) * 4],
      Division.rub => rubStarts[n - 1],
      Division.manzil => manzilStarts[n - 1],
      Division.ruku => rukuStarts[n - 1],
    };
