// Replays a recording through "Follow my recitation", as the app would hear
// it from the microphone (in real time, 100 ms at a time), and prints where
// it follows. For tuning on a desktop:
//
//   ffmpeg -i in.mp3 -ar 16000 -ac 1 -f s16le in.pcm   (or a 16 kHz mono WAV)
//   dart run tool/follow_replay.dart in.pcm assets/follow/high [2:1|any]
//
// The model folder holds model.int8.onnx, tokens.txt and silero_vad.onnx.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rasikh/core/follow/follow_worker.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: follow_replay <audio.pcm|.wav> <model dir> [surah:ayah|any]');
    exit(2);
  }
  var pcm = File(args[0]).readAsBytesSync();
  if (args[0].endsWith('.wav')) pcm = Uint8List.sublistView(pcm, 44);
  final dir = args[1];

  // The muṣḥaf's words, as the app lists them (its 'uthmani' tokens without
  // the āyah markers), and each word's place.
  final text = (jsonDecode(File('assets/quran/mushaf_u_text.json').readAsStringSync()) as List)
      .cast<String>();
  final meta = (jsonDecode(File('assets/quran/meta.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final words = <String>[], surahs = <int>[], refs = <String>[];
  final firstWordOf = <String, int>{};
  var g = 0;
  for (final m in meta) {
    for (var a = 1; a <= (m['ayahs'] as int); a++) {
      final toks = text[g++].split('‌').where((t) => t.isNotEmpty).toList();
      firstWordOf['${m['n']}:$a'] = words.length;
      for (var w = 0; w < toks.length - 1; w++) {
        words.add(toks[w]);
        surahs.add(m['n'] as int);
        refs.add('${m['n']}:$a:${w + 1}');
      }
    }
  }

  final port = ReceivePort();
  final ready = Completer<SendPort>();
  SendPort? worker;
  final passes = <int>[];
  port.listen((msg) {
    switch (msg) {
      case SendPort p:
        worker = p;
      case FollowReady():
        ready.complete(worker!);
      case FollowFailed(:final message):
        stderr.writeln('failed: $message');
        exit(1);
      case FollowHeard(:final text, :final decodeMs, :final seconds):
        passes.add(decodeMs);
        stdout.writeln('  heard (${seconds.toStringAsFixed(1)} s, $decodeMs ms): $text');
      case (String kind, int word):
        stdout.writeln('${kind.toUpperCase()} ${word >= 0 ? '${refs[word]} ${words[word]}' : ''}');
    }
  });
  final sw = Stopwatch()..start();
  await Isolate.spawn(followWorkerMain, <Object>[
    port.sendPort,
    FollowWorkerConfig(
      modelPath: '$dir/model.int8.onnx',
      tokensPath: '$dir/tokens.txt',
      vadPath: '$dir/silero_vad.onnx',
      wordsText: words.join('\n'),
      surahOf: Uint8List.fromList(surahs),
      windowSeconds: dir.endsWith('low') ? 3 : 4,
    ),
  ]);
  final to = await ready.future;
  stdout.writeln('ready in ${sw.elapsedMilliseconds} ms; ${words.length} words');

  final from = args.length > 2 ? args[2] : 'any';
  to.send(from == 'any' ? const FollowClearPosition(null) : FollowSetPosition(firstWordOf[from]!));
  const chunk = 3200; // 100 ms
  for (var i = 0; i < pcm.length; i += chunk) {
    final end = i + chunk < pcm.length ? i + chunk : pcm.length;
    to.send(FollowAudio(TransferableTypedData.fromList([Uint8List.sublistView(pcm, i, end)])));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await Future<void>.delayed(const Duration(seconds: 2));
  passes.sort();
  if (passes.isNotEmpty) {
    stdout.writeln('${passes.length} passes; median ${passes[passes.length ~/ 2]} ms, '
        'max ${passes.last} ms');
  }
  to.send(const FollowShutdown());
  await Future<void>.delayed(const Duration(milliseconds: 200));
  exit(0);
}
