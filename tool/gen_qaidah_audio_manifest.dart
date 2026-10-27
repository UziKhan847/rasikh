// Writes docs/qaidah_audio_manifest.md and .csv: the Qāʿidah's recordings
// to make (see lib/learn/qaidah/audio_manifest.dart).
//
//     dart run tool/gen_qaidah_audio_manifest.dart
import 'dart:io';

import 'package:qiraah_arabiyyah/learn/qaidah/audio_manifest.dart';

void main() {
  File('docs/qaidah_audio_manifest.md').writeAsStringSync(qaidahAudioMarkdown());
  File('docs/qaidah_audio_manifest.csv').writeAsStringSync(qaidahAudioCsv());
  stdout.writeln('${qaidahAudioClips().length} clips → docs/qaidah_audio_manifest.{md,csv}');
}
