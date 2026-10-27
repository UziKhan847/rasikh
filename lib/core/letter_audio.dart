import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/services.dart' show rootBundle;

import '../data/letters.dart';
import 'l10n.dart';

/// The sound of a **single letter** — one short clip, said aloud, as opposed
/// to the verse recitation `AyahAudio` streams.
///
/// This used to fall back to `letter.exampleRef` — the whole āyah the
/// letter's example word comes from — when no clip was bundled. That is a
/// real recitation of a real verse, but it is not the sound of the letter,
/// and a lesson that asks a child to say "Bāʼ" five times was not reinforced
/// by playing sūrah al-Fātiḥah five times instead. Nothing in the repo has
/// ever shipped a bundled clip, so in practice every "Listen" in the app was
/// silently playing an unrelated verse. [play] now does one thing honestly:
/// play the real clip if it exists, or report that it doesn't so the caller
/// can say so, rather than substitute something that sounds plausible but
/// teaches the wrong thing.
///
/// A bundled per-letter clip lives at
/// `assets/audio/letters/<variant>/<codepoint>.mp3`, e.g.
/// `assets/audio/letters/adult/0628.mp3` for بـ. Adding
/// clips needs **no code change**: drop the files in, list the folder under
/// `assets:` in `pubspec.yaml`, and every call site here picks them up.
/// Naming is by Unicode codepoint rather than by letter name or `glyphId`
/// because a name is language-dependent and `glyphId` is shared (ب ت ث are
/// all `ba`), while a codepoint is unique, stable and filesystem-safe — and,
/// since [assetName] joins multiple codepoints with `-`, the same convention
/// already covers a marked syllable like بَ (`0628-064e`) with no change.
class LetterAudio {
  LetterAudio._();

  /// Which recording of a letter to reach for.
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

  /// Says [letter] out loud. Returns whether a real clip was found and
  /// played — false means nothing played at all, so a caller can show a
  /// "coming soon" message instead of leaving a silent tap unexplained.
  /// Never throws: a failed play is a missing sound, not a crash in the
  /// middle of a lesson.
  /// Whether a recording of [text] is bundled (lessons offer listening
  /// only where one is).
  static Future<bool> has(String text, {String variant = adult}) =>
      log != null ? Future.value(true) : _bundled(assetPath(text, variant));

  static Future<bool> play(ArabicLetter letter, {String variant = adult}) =>
      playRaw(letter.char, variant: variant);

  /// [play], for text that isn't a single bare letter — a marked syllable
  /// like بَ (letter + ḥarakah), built by the caller via plain string
  /// concatenation. [assetName] already joins every codepoint in [text] with
  /// `-`, so بَ resolves to the same `<letter>-<mark>` naming a bundled clip
  /// for it would use, with no convention change.
  static Future<bool> playRaw(String text, {String variant = adult}) async {
    final sink = log;
    if (sink != null) {
      sink.add(text);
      return true;
    }
    try {
      final path = assetPath(text, variant);
      if (!await _bundled(path)) return false;
      await _player.stop();
      await _player.play(AssetSource(path));
      return true;
    } catch (e) {
      debugPrint('[LetterAudio] $text: $e');
      return false;
    }
  }

  /// [play], plus the one honest thing to do when it returns false: say so.
  /// For a button whose whole job is "make a sound happen" — a Listen icon,
  /// a Listening-practice row — a silent no-op reads as broken, not as
  /// "nothing to play yet". Not for the ambient reinforcement plays (every
  /// "I said it!" tap, every finished trace): those already got their own
  /// feedback from the action that triggered them, so a missing clip there
  /// stays quiet rather than adding a toast to something that already felt
  /// complete.
  static Future<void> playOrComingSoon(
    BuildContext context,
    ArabicLetter letter, {
    String variant = adult,
  }) => playOrComingSoonRaw(context, letter.char, variant: variant);

  /// [playOrComingSoon], for a composed syllable — see [playRaw].
  static Future<void> playOrComingSoonRaw(
    BuildContext context,
    String text, {
    String variant = adult,
  }) async {
    final played = await playRaw(text, variant: variant);
    if (!played && context.mounted) {
      comingSoon(context, context.l10n.audio);
    }
  }
}
