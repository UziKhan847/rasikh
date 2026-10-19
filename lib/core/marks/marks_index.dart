import '../../data/divisions.dart';
import 'marks_model.dart';
import 'marks_store.dart';
import 'word_ref.dart';

/// One division's marks: open ones by type, and how many are fixed.
class TypeCounts {
  final List<int> open = List<int>.filled(MarkType.values.length, 0);
  int fixed = 0;

  int openOf(MarkType t) => open[t.index];
  int get openTotal => open.fold(0, (a, b) => a + b);
  bool get isEmpty => fixed == 0 && openTotal == 0;

  static final empty = TypeCounts();
}

/// Marks counted per division (page, sūrah, juzʼ, ḥizb, rubʿ, manzil,
/// rukūʿ) — what the index's count pills show. Pages are in one script's
/// numbering; the other divisions are the same in both.
class MarkCounts {
  final Map<Division, Map<int, TypeCounts>> _by;
  MarkCounts._(this._by);

  /// [d] number [n]'s counts (empty if it has no marks).
  TypeCounts of(Division d, int n) => _by[d]?[n] ?? TypeCounts.empty;

  /// The division numbers of [d] that have any marks, ascending.
  List<int> marked(Division d) => (_by[d]?.keys.toList() ?? <int>[])..sort();

  /// Counts [marks]; [isFixed] says which are fixed, [pageOf] which page a
  /// word is printed on.
  static MarkCounts build(
    Iterable<Mark> marks, {
    required bool Function(Mark) isFixed,
    required int Function(WordRef) pageOf,
  }) {
    final by = {for (final d in Division.values) d: <int, TypeCounts>{}};
    for (final m in marks) {
      final r = m.ref;
      final fixed = isFixed(m);
      void add(Division d, int n) {
        final c = by[d]!.putIfAbsent(n, TypeCounts.new);
        if (fixed) {
          c.fixed++;
        } else {
          c.open[m.type.index]++;
        }
      }

      add(Division.page, pageOf(r));
      add(Division.surah, r.surah);
      final rub = rubOf(r.surah, r.ayah);
      add(Division.rub, rub);
      add(Division.hizb, (rub - 1) ~/ 4 + 1);
      add(Division.juz, (rub - 1) ~/ 8 + 1);
      add(Division.manzil, manzilOf(r.surah, r.ayah));
      add(Division.ruku, rukuOf(r.surah, r.ayah));
    }
    return MarkCounts._(by);
  }

  static (String, int, String)? _key;
  static MarkCounts? _memo;

  /// [bookId]'s counts with pages in [script], from [pageOf]; rebuilt only
  /// when the marks change ([MarksStore.version]) or the script does.
  static MarkCounts forBook(MarksStore store, String bookId, String script,
      int Function(WordRef) pageOf) {
    final key = (bookId, store.version, script);
    final memo = _memo;
    if (memo != null && _key == key) return memo;
    _key = key;
    return _memo = build(store.marksOf(bookId),
        isFixed: store.isFixed, pageOf: pageOf);
  }
}
