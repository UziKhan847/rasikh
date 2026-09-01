import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/letters.dart';
import 'audio.dart';

/// The sound of a **single letter** — one short clip, said aloud, as opposed
/// to the verse recitation [AyahAudio] streams.
///
/// Every "Listen" control in Kids Mode used to play `letter.exampleRef`: the
/// whole āyah the letter's example word comes from. That is a real recitation
/// of a real verse, but it is not the sound of the letter, and a lesson that
/// asks a child to say "Bāʼ" five times cannot reinforce that by playing
/// sūrah al-Fātiḥah five times.
///
/// So letter audio resolves in two steps:
///
///  1. **A bundled per-letter clip**, if one is present —
///     `assets/audio/letters/<variant>/<codepoint>.mp3`, e.g.
///     `assets/audio/letters/kids/0628.mp3` for بـ. Two variants ship side by
///     side: `kids` (a clear, slow, child-facing reading) and `adult`.
///  2. **The example verse**, as before, when that clip is not there.
///
/// Nothing in the repo ships those clips yet — the app therefore behaves
/// exactly as it did until they are added. Adding them needs **no code
/// change**: drop the files in, list the folder under `assets:` in
/// `pubspec.yaml`, and every call site here picks them up. Naming is by
/// Unicode codepoint rather than by letter name or `glyphId` because a name
/// is language-dependent and `glyphId` is shared (ب ت ث are all `ba`), while
/// a codepoint is unique, stable and filesystem-safe.
class LetterAudio {
  LetterAudio._();

  /// Which recording of a letter to reach for. Kids Mode asks for [kids];
  /// the grown-up screens ask for [adult].
  static const kids = 'kids';
  static const adult = 'adult';

  /// Relative to audioplayers' own `assets/` prefix, so the on-disk path is
  /// `assets/audio/letters/...`.
  static const _root = 'audio/letters';

  static final AudioPlayer _player = AudioPlayer();

  /// asset path → whether the bundle actually carries it. Probed once each:
  /// the answer cannot change while the app runs.
  static final Map<String, bool> _present = {};

  /// Test seam. When non-null, [play] appends the letter it was asked for and
  /// touches no audio plugin — widget tests finish traces and tap "I said it!"
  /// constantly, and none of them should be reaching for a media player.
  @visibleForTesting
  static List<String>? log;

  /// `'ب'` → `'0628'`. Multi-codepoint entries (none today) join with `-`.
  static String assetName(String char) =>
      char.runes.map((r) => r.toRadixString(16).padLeft(4, '0')).join('-');

  static String assetPath(String char, String variant) =>
      '$_root/$variant/${assetName(char)}.mp3';

  static Future<bool> _bundled(String path) async {
    final known = _present[path];
    if (known != null) return known;
    try {
      await rootBundle.load('assets/$path');
      return _present[path] = true;
    } catch (_) {
      return _present[path] = false;
    }
  }

  /// Says [letter] out loud. Falls back to its example verse while no clip is
  /// bundled. Never throws: a failed play is a missing sound, not a crash in
  /// the middle of a lesson.
  static Future<void> play(ArabicLetter letter,
      {String variant = kids}) async {
    final sink = log;
    if (sink != null) {
      sink.add(letter.char);
      return;
    }
    try {
      final path = assetPath(letter.char, variant);
      if (await _bundled(path)) {
        await AyahAudio.instance.stop();
        await _player.stop();
        await _player.play(AssetSource(path));
        return;
      }
      final parts = letter.exampleRef.split(':');
      final s = int.tryParse(parts.first);
      final a = int.tryParse(parts.length > 1 ? parts[1] : '');
      if (s == null || a == null) return;
      await AyahAudio.instance.play(s, a);
    } catch (e) {
      debugPrint('[LetterAudio] ${letter.char}: $e');
    }
  }
}
