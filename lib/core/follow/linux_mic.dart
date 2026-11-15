import 'dart:io';

/// On Linux (PulseAudio / PipeWire): whether an input is muted in the
/// system, and unmuting it — a muted input gives the app only silence.
abstract final class LinuxMic {
  /// Tests: what's muted, in place of the system (and nothing run).
  static Map<String?, bool>? debugMuted;

  static bool get available => debugMuted == null && Platform.isLinux;

  static String _source(String? id) => id ?? '@DEFAULT_SOURCE@';

  /// Whether input [id] (null: the default) is muted; null if it can't
  /// be told.
  static Future<bool?> isMuted(String? id) async {
    if (debugMuted case final m?) return m[id];
    if (!available) return null;
    try {
      final r = await Process.run('pactl', ['get-source-mute', _source(id)],
          environment: {'LC_ALL': 'C'});
      if (r.exitCode != 0) return null;
      return '${r.stdout}'.contains('yes');
    } on ProcessException {
      return null;
    }
  }

  static Future<void> unmute(String? id) async {
    if (debugMuted case final m?) {
      m[id] = false;
      return;
    }
    if (!available) return;
    try {
      await Process.run('pactl', ['set-source-mute', _source(id), '0']);
    } on ProcessException {
      // No pactl: nothing to do here.
    }
  }
}
