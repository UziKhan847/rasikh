import 'marks_model.dart';
import 'marks_store.dart';

/// Which marks a search wants: still open, fixed, or both.
enum MarkState { open, fixed, all }

/// [bookId]'s marks of [types] (every type when empty) in [state], in
/// muṣḥaf order — what the index's search lists when looking by mark.
List<Mark> queryMarks(MarksStore store, String bookId,
    {Set<MarkType> types = const {}, MarkState state = MarkState.open}) {
  final out = [
    for (final m in store.marksOf(bookId))
      if ((types.isEmpty || types.contains(m.type)) &&
          switch (state) {
            MarkState.open => !store.isFixed(m),
            MarkState.fixed => store.isFixed(m),
            MarkState.all => true,
          })
        m,
  ]..sort((a, b) => a.ref.compareTo(b.ref));
  return out;
}
