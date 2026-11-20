import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A download was stopped.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// A downloaded file wasn't what it should be (and was thrown away): its
/// SHA-256 or its size didn't match.
class DownloadBadFile implements Exception {
  final String name;
  const DownloadBadFile(this.name);
  @override
  String toString() => '$name: not the expected file';
}

/// Downloads [url] to [out], exactly [bytes] long with the SHA-256 [sha256]:
/// resumed from a `.part` left by an earlier try (a `Range` request), never
/// past the size expected, and checked before it takes its name — a file
/// that doesn't match is deleted. [onProgress] gets this file's bytes so
/// far. Only `https` (a test's client may say otherwise).
///
/// What's trusted is the hash, not the server or the connection: a changed
/// file is refused whoever changed it.
Future<void> downloadVerified(
  Uri url,
  File out, {
  required int bytes,
  required String sha256,
  required http.Client Function() client,
  void Function(int done)? onProgress,
  Future<void>? cancel,
  bool allowHttp = false,
}) async {
  if (url.scheme != 'https' && !allowHttp) {
    throw ArgumentError.value(url, 'url', 'only https');
  }
  if (out.existsSync() && out.lengthSync() == bytes) {
    onProgress?.call(bytes);
    return;
  }
  out.parent.createSync(recursive: true);
  var cancelled = false;
  cancel?.then((_) => cancelled = true);
  final part = File('${out.path}.part');
  var have = part.existsSync() ? part.lengthSync() : 0;
  if (have > bytes) {
    part.deleteSync();
    have = 0;
  }
  if (have < bytes) {
    final c = client();
    try {
      final req = http.Request('GET', url);
      if (have > 0) req.headers['Range'] = 'bytes=$have-';
      final res = await c.send(req);
      if (res.statusCode == 200) {
        have = 0; // the whole file, from the start
      } else if (res.statusCode != 206) {
        throw HttpException('HTTP ${res.statusCode}', uri: url);
      }
      final sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in res.stream) {
          if (cancelled) throw const DownloadCancelled();
          have += chunk.length;
          // More than it should be: not this file.
          if (have > bytes) throw DownloadBadFile(out.uri.pathSegments.last);
          sink.add(chunk);
          onProgress?.call(have);
        }
      } finally {
        await sink.close();
      }
    } on DownloadBadFile {
      if (part.existsSync()) part.deleteSync();
      rethrow;
    } finally {
      c.close();
    }
  }
  final path = part.path;
  final sha = await Isolate.run(
      () async => (await sha256Of(File(path).openRead())).toString());
  if (part.lengthSync() != bytes || sha != sha256) {
    part.deleteSync();
    throw DownloadBadFile(out.uri.pathSegments.last);
  }
  part.renameSync(out.path);
}

Future<Digest> sha256Of(Stream<List<int>> data) => sha256.bind(data).first;
