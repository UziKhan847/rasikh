import 'package:flutter/foundation.dart';

import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../data/mushaf.dart';

/// The marks the muṣḥaf's pages draw, and a signal per page: a mark added,
/// changed or wiped repaints the lines it touches on its own page — no page
/// widget is rebuilt (the pages take the layer, not the marks, as an input).
/// The screen [bind]s it to the store and the settings each build.
abstract interface class MushafMarksSource {
  /// How each marked word is drawn, by [WordRef.key] (word 0 = the ۝).
  Map<int, MarkVisual> get visuals;

  /// Fires when [page]'s marks change.
  Listenable pageSignal(int page);
}

class MushafMarksLayer implements MushafMarksSource {
  MarksStore? _store;
  String _script = 'uthmani';
  bool _show = true, _showFixed = true;
  Map<int, MarkVisual> _visuals = const {};
  final Map<int, _Signal> _pages = {};

  @override
  Map<int, MarkVisual> get visuals => _visuals;

  @override
  Listenable pageSignal(int page) => _pages.putIfAbsent(page, _Signal.new);

  /// Follows [store]'s active book, as the settings show it.
  void bind({
    required MarksStore? store,
    required String script,
    required bool show,
    required bool showFixed,
  }) {
    if (!identical(store, _store)) {
      _store?.removeListener(_onStore);
      _store = store;
      store?.addListener(_onStore);
    }
    // Another script numbers its pages differently: every page is new.
    final all = script != _script;
    _script = script;
    _show = show;
    _showFixed = showFixed;
    _refresh(all: all);
  }

  void _onStore() => _refresh();

  Map<int, MarkVisual> _compute() {
    final s = _store;
    if (s == null || !s.ready || !_show) return const {};
    final book = s.activeBookId;
    if (book == null) return const {};
    return s.visuals(book, showFixed: _showFixed);
  }

  void _refresh({bool all = false}) {
    final next = _compute();
    if (identical(next, _visuals) && !all) return;
    final old = _visuals;
    _visuals = next;
    if (all) {
      for (final s in _pages.values) {
        s.ping();
      }
      return;
    }
    final touched = <int>{};
    void add(int key) {
      final r = WordRef.fromKey(key);
      final t = MushafRepo.tokenOf(_script, r.globalAyah, r.word0);
      if (t >= 0) touched.add(MushafRepo.pageOfToken(_script, t));
    }

    next.forEach((k, v) {
      if (old[k] != v) add(k);
    });
    for (final k in old.keys) {
      if (!next.containsKey(k)) add(k);
    }
    for (final p in touched) {
      _pages[p]?.ping();
    }
  }

  void dispose() {
    _store?.removeListener(_onStore);
    _store = null;
    for (final s in _pages.values) {
      s.dispose();
    }
    _pages.clear();
  }
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
