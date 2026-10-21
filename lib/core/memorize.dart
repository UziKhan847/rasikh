import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset, Size;

import '../data/mushaf.dart';

/// Memorize mode's state: a cursor in the muṣḥaf's token stream. Every
/// token before [revealedEnd] shows; every token from it on is hidden —
/// fully blank, with the page's layout unchanged. The reader reveals word
/// by word (the ۝ comes with its āyah's last word), āyah by āyah, or the
/// rest of the page, and can hide again.
///
/// [viewToken] is the token the screen should be showing: the last one
/// revealed — so a completed page stays in view. Once everything on the
/// screen shows (on a two-page spread, both pages), the next word or āyah
/// first just turns to the next page, blank, like a swipe; revealing goes
/// on from there. Going back mirrors it: hiding stops at the screen's first
/// word, leaving the page blank, and the next step back turns back to the
/// page before, as it was. Verse cards do the same with their āyah.
class MemorizeController extends ChangeNotifier {
  final String script;
  int _end;
  int _view;

  /// The pages on screen with [page]: (first, last) — a two-page spread's
  /// right and left pages; unset, a page is alone. Set by the muṣḥaf.
  (int, int) Function(int page)? screenOf;

  /// Verse cards are showing: the āyah in view is the screen.
  bool cards = false;

  MemorizeController._(this.script, this._end) : _view = _end;

  /// Starts with everything from [page] on hidden (pages before it show).
  factory MemorizeController.startAt(String script, int page) {
    final (first, _) = MushafRepo.pageTokens(script, page);
    return MemorizeController._(script, first);
  }

  /// Starts with everything from token [token] on hidden: memorizing from
  /// a sūrah, juzʼ or any āyah, the words before it on its page showing.
  factory MemorizeController.startAtToken(String script, int token) =>
      MemorizeController._(script, token);

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

  /// The tokens on the screen in view, [first, end): its page or spread,
  /// or (verse cards) its āyah.
  (int, int) _screen() {
    if (cards) {
      return (
        MushafRepo.tokenOf(script, viewAyah, 0),
        MushafRepo.tokenOf(script, viewAyah, -1) + 1,
      );
    }
    final p = viewPage;
    final (a, b) = screenOf?.call(p) ?? (p, p);
    return (
      MushafRepo.pageTokens(script, a).$1,
      MushafRepo.pageTokens(script, b).$2,
    );
  }

  /// When everything on the screen shows, turns to the next page (or card)
  /// with nothing revealed on it, and says so: that step is the turn.
  bool _turnFirst() {
    if (atEnd) return false;
    final (_, end) = _screen();
    if (_end < end || _view >= end) return false;
    _set(_end, view: _end);
    return true;
  }

  /// Going back, with nothing on the screen showing: turns back to the
  /// page (or card) before, as it was, and says so.
  bool _turnBackFirst() {
    if (atStart) return false;
    final (first, _) = _screen();
    if (_end > first) return false;
    _set(_end, view: _end - 1);
    return true;
  }

  /// Hides from [e] on, but not past the screen's first word: the page
  /// stays in view, blank, until the next step back turns it.
  void _hideTo(int e) {
    final (first, _) = _screen();
    if (e < first) e = first;
    _set(e, view: e > first ? e - 1 : first);
  }

  /// Reveals the next word (and the ۝ after an āyah's last word) — or, with
  /// the screen all revealed, turns to the next page first.
  void nextWord() {
    if (atEnd || _turnFirst()) return;
    var e = _end + 1;
    if (_marker(e)) e++;
    _set(e);
  }

  /// Hides the last revealed word again (with its ۝, if it ended an āyah)
  /// — or, the screen blank, turns back a page.
  void prevWord() {
    if (atStart || _turnBackFirst()) return;
    var e = _end - 1;
    if (_marker(e) && e > 0) e--;
    _hideTo(e);
  }

  /// Reveals the rest of the āyah being memorized, its ۝ included — or,
  /// with the screen all revealed, turns to the next page first.
  void nextVerse() {
    if (atEnd || _turnFirst()) return;
    final (g, _) = MushafRepo.tokenAt(script, _end);
    _set(MushafRepo.tokenOf(script, g, -1) + 1);
  }

  /// Hides the last revealed āyah (or what of it shows on this screen)
  /// again — or, the screen blank, turns back a page.
  void prevVerse() {
    if (atStart || _turnBackFirst()) return;
    final (g, _) = MushafRepo.tokenAt(script, _end - 1);
    _hideTo(MushafRepo.tokenOf(script, g, 0));
  }

  /// Reveals the rest of the page in view and turns to the next one.
  void nextPage() {
    final (_, end) = MushafRepo.pageTokens(script, viewPage);
    final e = end > _end ? end : _end;
    _set(e, view: e < _total ? e : _total - 1);
  }

  /// Shows everything up to the end of [page] (default: the page in view)
  /// — the page on screen, even if the reader turned to it — and stays
  /// there.
  void revealPage([int? page]) {
    final (_, end) = MushafRepo.pageTokens(script, page ?? viewPage);
    _set(end > _end ? end : _end, view: end - 1);
  }

  /// Hides [page] (default: the page in view) and everything after it
  /// again, staying on it; pages before it are left as they are.
  void hidePage([int? page]) {
    final (first, _) = MushafRepo.pageTokens(script, page ?? viewPage);
    _set(first < _end ? first : _end, view: first);
  }

  /// A tap's step with "tap to reveal" [mode] ('word', 'verse', 'split'),
  /// at [at] on a [screen]: the left half goes on (as the text runs), the
  /// right half goes back; split, the top half by words and the bottom
  /// half by āyāt.
  void tapStep(String mode, Offset at, Size screen) {
    final back = at.dx > screen.width / 2;
    final verse = mode == 'verse' || (mode == 'split' && at.dy > screen.height / 2);
    switch ((verse, back)) {
      case (false, false):
        nextWord();
      case (false, true):
        prevWord();
      case (true, false):
        nextVerse();
      case (true, true):
        prevVerse();
    }
  }

  // ── verse cards: one āyah at a time ──

  /// The āyah in view (verse cards show it alone).
  int get viewAyah => MushafRepo.tokenAt(script, _view).$1;

  /// Shows the whole āyah in view.
  void revealAyah() {
    final end = MushafRepo.tokenOf(script, viewAyah, -1) + 1;
    if (end > _end) _set(end);
  }

  /// Hides the whole āyah in view again.
  void hideAyah() {
    final first = MushafRepo.tokenOf(script, viewAyah, 0);
    if (first < _end) _set(first, view: first);
  }

  /// Whether any of the āyah in view is still hidden.
  bool get ayahHidden =>
      _end <= MushafRepo.tokenOf(script, viewAyah, -1);

  /// For verse cards: the āyah before the one being memorized, whole, then
  /// this one up to the last revealed word.
  List<(int, int)> ayahClips() {
    final c = currentClip;
    if (c == null) return const [];
    final (g, w) = c;
    return [if (g > 0 && w >= 0) (g - 1, -1), c];
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
