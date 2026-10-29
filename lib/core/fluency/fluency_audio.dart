import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../data/mushaf.dart';
import '../audio.dart';
import '../marks/qc_words.dart';
import '../marks/word_ref.dart';

/// Plays words as Ḥuṣarī recites them, joined as read: the āyah's own file
/// from the first word's start, stopped just after the last word, by
/// quran.com's word timings — so a pair's join (an idghām, a hamzat
/// al-waṣl dropped) is heard as it's recited. Not cut to the millisecond,
/// but connected. Words across an āyah's end play as each āyah's part in
/// turn. Without timings (offline before they were fetched): the
/// word-by-word clips.
class FluencyAudio {
  FluencyAudio._();
  static final FluencyAudio instance = FluencyAudio._();

  static const reciter = 'husary';

  /// A little before the first word and after the last: the timings sit
  /// right on the sound.
  static const leadMs = 60, tailMs = 110;

  int _run = 0;

  Future<void> stop() async {
    _run++;
    await WbwAudio.instance.stop();
    await AyahAudio.instance.stop();
  }

  /// Plays [words] (in reading order).
  Future<void> play(List<WordRef> words) async {
    if (words.isEmpty) return;
    final run = ++_run;
    await WbwAudio.instance.stop();
    // Each āyah's run of words.
    final spans = <(int, int, int)>[]; // global āyah, first word0, last word0
    for (final w in words) {
      final g = w.globalAyah;
      if (spans.isNotEmpty && spans.last.$1 == g) {
        spans[spans.length - 1] = (g, spans.last.$2, w.word0);
      } else {
        spans.add((g, w.word0, w.word0));
      }
    }
    for (final (g, a, b) in spans) {
      if (run != _run) return;
      await _span(run, g, a, b);
    }
  }

  /// The timing row of quran.com word [qc] (0-based): its own, else the
  /// one it was run together into.
  @visibleForTesting
  static List<int>? rowOf(List<List<int>> segs, int qc) {
    List<int>? best;
    for (final s in segs) {
      if (s[0] <= qc && (best == null || s[0] > best[0])) best = s;
    }
    return best;
  }

  Future<void> _span(int run, int g, int a, int b) async {
    final (s, v) = MushafRepo.surahAyahOf(g);
    final qa = qcWordOf(g, a), qb = qcWordOf(g, b);
    final audio = AyahAudio.instance;
    audio.setRate(1);
    final err = await audio.play(s, v, reciter: reciter);
    final segs = audio.segments;
    if (run != _run) return;
    if (err != null || segs == null || segs.isEmpty) {
      await audio.stop();
      if (run != _run) return;
      final done = Completer<void>();
      WbwAudio.instance.playWords(s, v, qa + 1, qb + 1, (i) {
        if (i == -1 && !done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      return;
    }
    final start = rowOf(segs, qa)?[1] ?? 0;
    final end = rowOf(segs, qb)?[2];
    if (start > leadMs) await audio.seek(Duration(milliseconds: start - leadMs));
    final finished = Completer<void>();
    final sub = audio.onComplete.listen((_) {
      if (!finished.isCompleted) finished.complete();
    });
    Timer? stopper;
    void onPos() {
      if (end == null || stopper != null) return;
      final left = end + tailMs - audio.pos.value.inMilliseconds;
      if (left > 400) return;
      stopper = Timer(Duration(milliseconds: left.clamp(0, 400)), () {
        audio.stop();
        if (!finished.isCompleted) finished.complete();
      });
    }

    audio.pos.addListener(onPos);
    final cancel = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (run != _run && !finished.isCompleted) finished.complete();
    });
    try {
      await finished.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    } finally {
      cancel.cancel();
      stopper?.cancel();
      audio.pos.removeListener(onPos);
      await sub.cancel();
    }
  }
}
