import 'dart:io';

import 'package:flutter/foundation.dart';

/// Checking Follow my recitation end to end on a desktop, without a
/// microphone: set in the environment, ignored everywhere else.
///
///   RASIKH_FOLLOW_PCM=FILE    a recording (16 kHz mono 16-bit PCM, or a
///                             WAV) heard in place of the microphone, in real
///                             time; Follow starts by itself on the muṣḥaf,
///                             and what it follows is logged
///   RASIKH_FOLLOW_MEMO=1      with it: memorizing, revealing what's recited
abstract final class FollowDebug {
  static bool get _desktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// The recording to hear in place of the microphone, if one is set.
  static String? get feedFile {
    if (!_desktop) return null;
    final f = Platform.environment['RASIKH_FOLLOW_PCM'];
    return f == null || f.isEmpty ? null : f;
  }

  /// Whether the muṣḥaf starts memorizing (revealing what's recited) rather
  /// than plain following, when fed a recording.
  static bool get memorize =>
      feedFile != null && Platform.environment['RASIKH_FOLLOW_MEMO'] != null;

  /// Logged only when fed a recording.
  static void log(String Function() message) {
    if (feedFile != null) debugPrint(message());
  }
}
