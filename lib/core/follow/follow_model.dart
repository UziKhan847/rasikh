import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../display_rotation.dart' show deviceRamMb;

/// High: quran-asr-small (33M parameters); Low: quran-asr-tiny (16M), for
/// older phones — faster and cooler, but it loses its place more often.
enum FollowTier { high, low }

/// One file of a model: where it comes from and what it must be.
class FollowFile {
  final String name, url, sha256;
  final int bytes;
  const FollowFile(this.name, this.url, this.sha256, this.bytes);
}

/// The model's files are downloaded on first use (none are in the app) or,
/// on a desktop, found in a chosen folder. Pinned to one version of each,
/// every file checked by its SHA-256 before it's used.
abstract final class FollowModel {
  static const model = 'model.int8.onnx', tokens = 'tokens.txt', vad = 'silero_vad.onnx';

  // Hugging Face, pinned to a commit (an upstream change can't reach the
  // app); later a mirror: only these change.
  static const _small =
      'https://huggingface.co/Abdou/quran-asr-small/resolve/004f898639f3127a74eac1b898a2cb3ef0b5268d';
  static const _tiny =
      'https://huggingface.co/Abdou/quran-asr-tiny/resolve/cf7186827059357dacbf896c92c11e80d9ba0c65';
  static const _vad = FollowFile(
      vad,
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
      '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
      643854);
  static const _tokensSha = '75b53814499cee84a07c7b7a318524d30bcaf84273c0f8b28a04176023e8c74f';

  /// Tests: the files a tier downloads, in place of [files].
  @visibleForTesting
  static Map<FollowTier, List<FollowFile>>? debugFiles;

  static List<FollowFile> filesOf(FollowTier t) => (debugFiles ?? files)[t]!;

  static const files = {
    FollowTier.high: [
      FollowFile(model, '$_small/$model',
          '88f9df290d57b8890275d79187b77515aeeb12626a42bc76cbd0f8bfcaff00f0', 36081762),
      FollowFile(tokens, '$_small/$tokens', _tokensSha, 180),
      _vad,
    ],
    FollowTier.low: [
      FollowFile(model, '$_tiny/$model',
          '58de6db034bb4f6516b3bc1c68e7a0ac4e77abffe603a550ee87b39dcd0c7ac6', 18850806),
      FollowFile(tokens, '$_tiny/$tokens', _tokensSha, 180),
      _vad,
    ],
  };

  /// What a tier downloads, in MB (shown in the prompt).
  static int sizeMb(FollowTier t) =>
      (filesOf(t).fold<int>(0, (n, f) => n + f.bytes) / 1e6).round();

  /// The model's vocabulary: tokens.txt, each line "token id".
  static const vocabulary = '<blk>ءابتثجحخدذرزسشصضطظعغفقكلمنهوي▁';

  /// Tests: the app's own folder for downloads.
  @visibleForTesting
  static String? debugRoot;

  /// Tests: the HTTP client downloads go through.
  @visibleForTesting
  static http.Client Function() client = http.Client.new;

  static Future<String> _root() async =>
      debugRoot ?? '${(await getApplicationSupportDirectory()).path}/follow';

  /// Where [t] is downloaded to.
  static Future<String> dirOf(FollowTier t) async => '${await _root()}/${t.name}';

  /// This device's tier: Low with Lite mode or ≤ 4 GB of memory.
  static Future<FollowTier> recommended({required bool lite}) async {
    if (lite) return FollowTier.low;
    final ram = await deviceRamMb();
    return ram != null && ram <= 4096 ? FollowTier.low : FollowTier.high;
  }

  /// What [dir] holds: the three files, and tokens.txt this model's. The
  /// tier is told by the model's size (an unknown one counts as High).
  static FollowTier? check(String dir) {
    final m = File('$dir/$model'), t = File('$dir/$tokens'), v = File('$dir/$vad');
    if (!m.existsSync() || !t.existsSync() || !v.existsSync()) return null;
    try {
      final vocab = [
        for (final line in t.readAsLinesSync())
          if (line.trim().isNotEmpty) line.split(' ').first,
      ].join();
      if (vocab != vocabulary) return null;
    } on FileSystemException {
      return null;
    }
    final size = m.lengthSync();
    return size == files[FollowTier.low]!.first.bytes ? FollowTier.low : FollowTier.high;
  }

  /// The model to use: the chosen folder ([chosenDir]), else [preferred]
  /// downloaded, else the other downloaded; null if there's none.
  static Future<({String dir, FollowTier tier})?> locate(
      {String? chosenDir, FollowTier? preferred}) async {
    if (chosenDir != null) {
      final t = check(chosenDir);
      if (t != null) return (dir: chosenDir, tier: t);
    }
    final order = preferred == FollowTier.low
        ? [FollowTier.low, FollowTier.high]
        : [FollowTier.high, FollowTier.low];
    for (final t in order) {
      final d = await dirOf(t);
      if (check(d) == t) return (dir: d, tier: t);
    }
    return null;
  }

  /// Which tiers are downloaded.
  static Future<Set<FollowTier>> downloaded() async => {
        for (final t in FollowTier.values)
          if (check(await dirOf(t)) == t) t,
      };

  /// Downloads [t]'s missing files: resumed where a try left off, each
  /// checked by its SHA-256 before it takes its name. [onProgress] gets the
  /// bytes so far and in all. Cancelled when [cancel] completes.
  static Future<void> download(FollowTier t,
      {void Function(int done, int total)? onProgress, Future<void>? cancel}) async {
    final dir = Directory(await dirOf(t));
    await dir.create(recursive: true);
    final all = filesOf(t);
    final total = all.fold<int>(0, (n, f) => n + f.bytes);
    var before = 0;
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    for (final f in all) {
      final out = File('${dir.path}/${f.name}');
      if (out.existsSync() && out.lengthSync() == f.bytes) {
        before += f.bytes;
        onProgress?.call(before, total);
        continue;
      }
      final part = File('${out.path}.part');
      var have = part.existsSync() ? part.lengthSync() : 0;
      if (have > f.bytes) {
        part.deleteSync();
        have = 0;
      }
      if (have < f.bytes) {
        final c = client();
        try {
          final req = http.Request('GET', Uri.parse(f.url));
          if (have > 0) req.headers['Range'] = 'bytes=$have-';
          final res = await c.send(req);
          if (res.statusCode == 200) {
            have = 0; // the whole file, from the start
          } else if (res.statusCode != 206) {
            throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(f.url));
          }
          final sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
          try {
            await for (final chunk in res.stream) {
              if (cancelled) throw const FollowCancelled();
              sink.add(chunk);
              have += chunk.length;
              onProgress?.call(before + have, total);
            }
          } finally {
            await sink.close();
          }
        } finally {
          c.close();
        }
      }
      final path = part.path;
      final sha = await Isolate.run(() async => (await sha256.bind(File(path).openRead()).first).toString());
      if (sha != f.sha256) {
        part.deleteSync();
        throw FollowBadFile(f.name);
      }
      part.renameSync(out.path);
      before += f.bytes;
    }
  }

  /// Removes [t]'s downloaded files.
  static Future<void> remove(FollowTier t) async {
    final d = Directory(await dirOf(t));
    if (d.existsSync()) await d.delete(recursive: true);
  }
}

/// A download was stopped.
class FollowCancelled implements Exception {
  const FollowCancelled();
}

/// A downloaded file wasn't what it should be (and was thrown away).
class FollowBadFile implements Exception {
  final String name;
  const FollowBadFile(this.name);
  @override
  String toString() => '$name: checksum mismatch';
}
