import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../settings.dart' show ProgressStore;

/// Records the reader reading (a cold read), for the fluency plan's
/// recording check: played back, the madd errors they can't hear while
/// reading are heard. Each profile's recordings in its own folder; nothing
/// leaves the device.
class FluencyRecorder {
  /// Made when a recording starts (the plugin's set up on creation).
  AudioRecorder? _rec;
  String? _path;

  /// The folder for the profile in use.
  static Future<Directory> folder() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}${Platform.pathSeparator}fluency${ProgressStore.profileSuffix}');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Starts recording; false if there's no microphone or no permission.
  Future<bool> start() async {
    try {
      final rec = _rec ??= AudioRecorder();
      if (!await rec.hasPermission()) return false;
      final d = await folder();
      _path = '${d.path}${Platform.pathSeparator}cold-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 22050, bitRate: 64000),
          path: _path!);
      return true;
    } catch (e) {
      debugPrint('[recorder] $e');
      _path = null;
      return false;
    }
  }

  /// Stops; the recording's path (null if none).
  Future<String?> stop() async {
    final rec = _rec;
    if (rec == null) return null;
    try {
      final p = await rec.stop();
      return p ?? _path;
    } catch (e) {
      debugPrint('[recorder] $e');
      return null;
    }
  }

  Future<void> dispose() async => _rec?.dispose();
}
