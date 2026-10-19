import 'package:flutter/foundation.dart';

import '../data/mushaf.dart';

/// Memorize mode's state: a cursor in the muṣḥaf's token stream. Every
/// token before [revealedEnd] shows; every token from it on is hidden —
/// fully blank, with the page's layout unchanged. The reader reveals word
/// by word (the ۝ comes with its āyah's last word), āyah by āyah, or the
/// rest of the page, and can hide again.
///
/// [viewToken] is the token the screen should be showing: the last one
/// revealed — so a completed page stays in view until the next word is
/// revealed on the page after it, and the screen turns then (on a two-page
/// spread, only once both pages are done).
class MemorizeController extends ChangeNotifier {
  final String script;
  int _end;
  int _view;

  MemorizeController._(this.script, this._end) : _view = _end;

  /// Starts with everything from [page] on hidden (pages before it show).
  factory MemorizeController.startAt(String script, int page) {
    final (first, _) = MushafRepo.pageTokens(script, page);
    return MemorizeController._(script, first);
  }

  int get revealedEnd => _end;
  int get viewToken => _view;
  int get viewPage => MushafRepo.pageOfToken(script, _view);
  int get _total => MushafRepo.tokenCount(script);
  bool get atEnd => _end >= _total;
  bool get atStart => _end <= 0;

  bool _marker(int t) => t >= 0 && t < _total && MushafRepo.tokenAt(script, t).$2 < 0;

  /// Whether token [t] is showing.
  bool isRevealed(int t) => t < _end;

  /// The first hidden token on [page] for a line's `hideFrom`: -1 when the
  /// whole page shows.
  int hideFromOn(int page) {
    final (first, end) = MushafRepo.pageTokens(script, page);
    if (_end >= end) return -1;
    return _end < first ? first : _end;
  }

  void _set(int end, {int? view}) {
    end = end.clamp(0, _total);
    final v = view ?? (end > 0 ? end - 1 : 0);
    if (end == _end && v == _view) return;
    _end = end;
    _view = v.clamp(0, _total - 1);
    notifyListeners();
  }

  /// Reveals the next word (and the ۝ after an āyah's last word).
  void nextWord() {
    if (atEnd) return;
    var e = _end + 1;
    if (_marker(e)) e++;
    _set(e);
  }

  /// Hides the last revealed word again (with its ۝, if it ended an āyah).
  void prevWord() {
    if (atStart) return;
    var e = _end - 1;
    if (_marker(e) && e > 0) e--;
    _set(e);
  }

  /// Reveals the rest of the āyah being memorized, its ۝ included.
  void nextVerse() {
    if (atEnd) return;
    final (g, _) = MushafRepo.tokenAt(script, _end);
    _set(MushafRepo.tokenOf(script, g, -1) + 1);
  }

  /// Hides the last revealed āyah (or what of it shows) again.
  void prevVerse() {
    if (atStart) return;
    final (g, _) = MushafRepo.tokenAt(script, _end - 1);
    _set(MushafRepo.tokenOf(script, g, 0));
  }

  /// Reveals the rest of the page in view and turns to the next one.
  void nextPage() {
    final (_, end) = MushafRepo.pageTokens(script, viewPage);
    final e = end > _end ? end : _end;
    _set(e, view: e < _total ? e : _total - 1);
  }

  /// Shows the whole page in view.
  void revealPage() {
    final (_, end) = MushafRepo.pageTokens(script, viewPage);
    if (end > _end) _set(end);
  }

  /// Hides the whole page in view again.
  void hidePage() {
    final page = viewPage;
    final (first, _) = MushafRepo.pageTokens(script, page);
    if (first < _end) _set(first, view: first);
  }

  /// Starts over from [page] (everything on it hidden).
  void restartAt(int page) {
    final (first, _) = MushafRepo.pageTokens(script, page);
    _set(first, view: first);
  }

  /// What to recite back: the āyah being memorized from its start up to the
  /// last revealed word — (global āyah, last word index or -1 for all of it).
  /// Null before anything is revealed.
  (int, int)? get currentClip {
    if (atStart) return null;
    final (g, w) = MushafRepo.tokenAt(script, _end - 1);
    return (g, w);
  }

  /// The āyāt revealed on the page in view, in order, each with its last
  /// revealed word (-1: all of it) — for reciting the page so far.
  List<(int, int)> pageClips() {
    final (first, _) = MushafRepo.pageTokens(script, viewPage);
    if (_end <= first) return const [];
    final (g0, _) = MushafRepo.tokenAt(script, first);
    final (g1, w1) = MushafRepo.tokenAt(script, _end - 1);
    return [
      for (var g = g0; g < g1; g++) (g, -1),
      (g1, w1),
    ];
  }
}
