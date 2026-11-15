import 'dart:math' as math;
import 'dart:typed_data';

import 'follow_text.dart';

/// What following has found, from one transcript.
sealed class FollowEvent {
  const FollowEvent();
}

/// The reciter has moved on: [word] (an index into the muṣḥaf's words) is
/// the last one heard for sure.
class FollowProgress extends FollowEvent {
  final int word;
  const FollowProgress(this.word);
}

/// The reciter started somewhere else (another āyah, page or sūrah, or went
/// back): they're at [word].
class FollowJump extends FollowEvent {
  final int word;
  const FollowJump(this.word);
}

/// Several transcripts matched nothing near where they were: now looking
/// through the whole Qurʼān.
class FollowLost extends FollowEvent {
  const FollowLost();
}

class FollowAlignerSettings {
  /// The transcript's last words matched against the muṣḥaf.
  final int tailWords;

  /// How far ahead of the last word heard tracking looks.
  final int lookahead;
  final double matchThreshold;

  /// A little off each word jumped forward, so the nearest match wins a tie.
  final double jumpPenalty;

  /// Transcripts that must agree before the newest word counts as heard.
  final int confirmHits;

  /// Transcripts matching nothing nearby before looking everywhere.
  final int lostAfter;

  /// When lost, first looked for this far back and on.
  final int nearBack, nearAhead;
  final int discoveryTailWords;
  final double discoveryThreshold;

  /// A pair of words more common than this says nothing about where it is.
  final int maxPairFanout;
  final double surahBonus;

  const FollowAlignerSettings({
    this.tailWords = 4,
    this.lookahead = 12,
    this.matchThreshold = .62,
    this.jumpPenalty = .015,
    this.confirmHits = 2,
    this.lostAfter = 6,
    this.nearBack = 20,
    this.nearAhead = 80,
    this.discoveryTailWords = 6,
    this.discoveryThreshold = .72,
    this.maxPairFanout = 300,
    this.surahBonus = .05,
  });
}

/// Turns transcripts of the last few seconds into "the reciter is at word
/// N". The text is fixed, so this only asks which run of the muṣḥaf's words
/// the end of a transcript matches — near where they were, or, when that
/// fails, anywhere (by pairs of words). It says nothing of mistakes: the
/// model hears what it expects, so it can't judge them.
class FollowAligner {
  final FollowAlignerSettings settings;

  /// The muṣḥaf's words, bare ([FollowText.word]), in reading order.
  final List<String> words;

  /// Each word's sūrah.
  final Uint8List surahOf;
  final Map<String, List<int>> _pairs = {};
  final _d = WordDistance();

  int _heard = -1;
  bool _placed = false;
  int _pending = -1, _hits = 0, _misses = 0;
  bool _lost = false;
  int? _surah;

  /// Where discovery last pointed, waiting for a second transcript to agree.
  int? _candidate;

  FollowAligner(this.words, this.surahOf, {this.settings = const FollowAlignerSettings()}) {
    for (var i = 1; i < words.length; i++) {
      (_pairs['${words[i - 1]} ${words[i]}'] ??= []).add(i);
    }
  }

  /// The last word heard for sure (-1: none yet).
  int get heard => _heard;
  bool get lost => _lost;

  /// They're about to recite from [word] (a page shown, a word tapped).
  void setPosition(int word) {
    final w = word.clamp(0, words.length - 1);
    _heard = w - 1;
    _placed = true;
    _surah = surahOf[w];
    _resetTracking();
  }

  /// No idea where they are: the first transcripts are looked up anywhere.
  void clearPosition({int? surah}) {
    _heard = -1;
    _placed = false;
    _surah = surah;
    _resetTracking();
  }

  void _resetTracking() {
    _candidate = null;
    _pending = -1;
    _hits = 0;
    _misses = 0;
    _lost = false;
  }

  /// One transcript ([FollowText.words]): what it moves.
  List<FollowEvent> update(List<String> hyp) {
    if (hyp.isEmpty) return const [];
    if (!_placed) return _discover(hyp);
    if (_lost) {
      // Lost, but most likely still close by: there first, then anywhere.
      if (hyp.length >= 2) {
        final near = _near(hyp);
        if (near != null) return near;
      }
      return _discover(hyp);
    }

    final t = math.min(settings.tailWords, hyp.length);
    final tail = hyp.sublist(hyp.length - t);
    // One word alone is too common to place: only "still here" or "next".
    final reach = t == 1 ? 1 : settings.lookahead;
    final from = math.max(0, _heard);
    final to = math.min(words.length - 1, _heard + reach);

    var best = -1;
    var bestScore = -1.0;
    for (var j = from; j <= to; j++) {
      final s = _tailScore(tail, j) - settings.jumpPenalty * math.max(0, j - (_heard + 1));
      if (s > bestScore) {
        bestScore = s;
        best = j;
      }
    }

    if (bestScore < settings.matchThreshold) {
      // One word (a long madd, a held letter) is no sign of being lost.
      if (hyp.length >= 2) _misses++;
      if (_misses >= settings.lostAfter && hyp.length >= 3) {
        // Nearby first: a few words back to a few lines on.
        final near = _near(hyp);
        if (near != null) return near;
        _lost = true;
        return [const FollowLost(), ..._discover(hyp)];
      }
      return const [];
    }
    _misses = 0;
    if (best == _pending) {
      _hits++;
    } else {
      _pending = best;
      _hits = 1;
    }
    // The newest word needs agreeing transcripts; the ones before it are
    // heard as soon as two words have gone past them.
    final target = _hits >= settings.confirmHits ? best : (t >= 2 ? best - 1 : _heard);
    if (target <= _heard) return const [];
    _heard = target;
    _surah = surahOf[target];
    return [FollowProgress(target)];
  }

  /// How well [tail] matches the words ending at [end], 0..1.
  double _tailScore(List<String> tail, int end) {
    final t = tail.length;
    var sum = 0.0;
    for (var i = 0; i < t; i++) {
      final r = end - (t - 1) + i;
      if (r < 0) continue;
      sum += i == t - 1 ? _d.partial(tail[i], words[r]) : _d.similarity(tail[i], words[r]);
    }
    return sum / t;
  }

  /// Where the transcript's end matches from [nearBack] words back to
  /// [nearAhead] on: on ahead it's progress, back it's a jump.
  List<FollowEvent>? _near(List<String> hyp) {
    final t = math.min(settings.tailWords, hyp.length);
    final tail = hyp.sublist(hyp.length - t);
    final from = math.max(0, _heard - settings.nearBack);
    final to = math.min(words.length - 1, _heard + settings.nearAhead);
    var best = -1;
    var bestScore = -1.0;
    for (var j = from; j <= to; j++) {
      final s = _tailScore(tail, j);
      if (s > bestScore) {
        bestScore = s;
        best = j;
      }
    }
    if (bestScore < settings.matchThreshold + .08) return null;
    // Where they were, or on: going on. Further back: a jump (a repeat).
    final on = best >= _heard - 1;
    _heard = on ? math.max(best, _heard) : best;
    _surah = surahOf[_heard];
    _resetTracking();
    return [on ? FollowProgress(_heard) : FollowJump(_heard)];
  }

  List<FollowEvent> _discover(List<String> hyp) {
    final t = math.min(settings.discoveryTailWords, hyp.length);
    if (t < 3) return const [];
    final tail = hyp.sublist(hyp.length - t);
    final votes = <int, int>{};
    var usable = 0;
    for (var k = 1; k < t; k++) {
      final hits = _pairs['${tail[k - 1]} ${tail[k]}'];
      if (hits == null || hits.length > settings.maxPairFanout) continue;
      usable++;
      for (final i in hits) {
        final end = i + (t - 1 - k);
        if (end < words.length) votes[end] = (votes[end] ?? 0) + 1;
      }
    }
    if (votes.isEmpty) return const [];
    final minVotes = usable >= 2 ? 2 : 1;
    final candidates = [
      for (final e in votes.entries)
        if (e.value >= minVotes) e,
    ]..sort((a, b) => b.value.compareTo(a.value));

    var bestEnd = -1;
    var bestScore = -1.0;
    for (final c in candidates.take(12)) {
      var s = _tailScore(tail, c.key);
      if (_surah != null && surahOf[c.key] == _surah) s += settings.surahBonus;
      // A little for staying near where they were.
      if (_placed && (c.key - _heard).abs() < 300) s += .03;
      if (s > bestScore) {
        bestScore = s;
        bestEnd = c.key;
      }
    }
    if (bestScore < settings.discoveryThreshold) return const [];
    // Found a little further on: that's just going on.
    final onward = _placed && bestEnd > _heard && bestEnd - _heard <= settings.nearAhead;
    // Anywhere else, only once a second transcript agrees (the same place,
    // or a few words on): one alone too often matches a look-alike.
    if (!onward) {
      final c = _candidate;
      if (c == null || bestEnd < c || bestEnd - c > 12) {
        _candidate = bestEnd;
        return const [];
      }
    }
    _heard = bestEnd;
    _placed = true;
    _surah = surahOf[bestEnd];
    _resetTracking();
    return [onward ? FollowProgress(bestEnd) : FollowJump(bestEnd)];
  }
}
