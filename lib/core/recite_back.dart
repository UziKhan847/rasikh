import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio.dart';
import 'marks/qc_words.dart';
import '../data/mushaf.dart';

/// Plays back just what memorize mode has revealed, in Ḥuṣarī's voice:
/// each āyah's own file from its start, cut off right after the last
/// revealed word using quran.com's word timings for that very file. An
/// āyah fully revealed plays whole.
///
/// Where the timings can't be had (offline before they were ever fetched),
/// a cut-off āyah plays from the word-by-word clips instead — another voice,
/// but only the revealed words: a hidden word is never given away.
class ReciteBack {
  ReciteBack._();
  static final ReciteBack instance = ReciteBack._();

  static const reciter = 'husary';

  /// Stop this much after a word's recorded end — Ḥuṣarī's words fade out a
  /// little past their timing.
  static const tailMs = 90;

  int _run = 0;
  final ValueNotifier<bool> playing = ValueNotifier(false);

  /// The cut-off point (ms into the āyah's file) after word [lastWord]
  /// (0-based, quran.com positions): the end of its timing row — or, when it
  /// was run together with the next word and has no row of its own, the end
  /// of the row that carries it. Null: play to the end.
  @visibleForTesting
  static int? cutMs(List<List<int>>? segments, int lastWord) {
    if (segments == null) return null;
    List<int>? best;
    for (final s in segments) {
      if (s[0] >= lastWord && (best == null || s[0] < best[0])) best = s;
    }
    // The last word, or one past every row: the whole file.
    if (best == null) return null;
    final isLast = segments.every((s) => s[0] <= best![0]);
    return isLast ? null : best[2];
  }

  /// Plays [clips] — (global āyah, last revealed word index or -1 for the
  /// whole āyah) — one after the other. A new call (or [stop]) cancels the
  /// one before. Returns an error message, or null.
  Future<String?> play(List<(int, int)> clips, {double rate = 1}) async {
    final run = ++_run;
    playing.value = true;
    try {
      for (final (g, w) in clips) {
        if (run != _run) return null;
        final err = await _clip(run, g, w, rate);
        if (err != null) return err;
      }
      return null;
    } finally {
      if (run == _run) playing.value = false;
    }
  }

  Future<void> stop() async {
    _run++;
    playing.value = false;
    await WbwAudio.instance.stop();
    await AyahAudio.instance.stop();
  }

  Future<String?> _clip(int run, int g, int w, double rate) async {
    final (s, a) = MushafRepo.surahAyahOf(g);
    final audio = AyahAudio.instance;
    audio.setRate(rate);
    final err = await audio.play(s, a, reciter: reciter);
    if (err != null) return err;
    if (run != _run) return null;
    final whole = w < 0 || w >= MushafRepo.wordCount('uthmani', g) - 1;
    final cut = whole ? null : cutMs(audio.segments, qcWordOf(g, w));
    if (!whole && audio.segments == null) {
      // No timings: the revealed words from the word-by-word clips.
      await audio.stop();
      if (run != _run) return null;
      final done = Completer<void>();
      WbwAudio.instance.playWords(s, a, 1, qcWordOf(g, w) + 1, (i) {
        if (i == -1 && !done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
      return null;
    }
    final finished = Completer<void>();
    late final StreamSubscription<void> sub;
    sub = audio.onComplete.listen((_) {
      if (!finished.isCompleted) finished.complete();
    });
    Timer? stopper;
    void onPos() {
      if (cut == null || stopper != null || run != _run) return;
      // Positions arrive every ~200 ms: close to the cut, a timer stops it
      // on the dot rather than a poll late into the next word.
      final left = (cut + tailMs - audio.pos.value.inMilliseconds) / rate;
      if (left > 400) return;
      stopper = Timer(Duration(milliseconds: left.clamp(0, 400).round()), () {
        audio.stop();
        if (!finished.isCompleted) finished.complete();
      });
    }

    audio.pos.addListener(onPos);
    final cancel = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (run != _run && !finished.isCompleted) finished.complete();
    });
    try {
      await finished.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    } finally {
      cancel.cancel();
      stopper?.cancel();
      audio.pos.removeListener(onPos);
      await sub.cancel();
    }
    return null;
  }
}
