import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/original/mushaf_packs.dart';
import '../../data/original/original_atlas.dart' show OriginalTier;
import '../verified_download.dart';
import 'pack_catalog.dart';

/// A pack's zip held something it shouldn't (a name outside its folder, a
/// file it doesn't need), or unpacked into something that isn't its print.
class PackRefused implements Exception {
  final String why;
  const PackRefused(this.why);
  @override
  String toString() => 'pack refused: $why';
}

/// Downloading a printed muṣḥaf's pack into the app's own folder
/// (`<app support>/packs/<edition>/`), where [MushafPacks] finds it.
///
/// The zip is checked twice before anything of it is used: its SHA-256
/// against the signed catalog, and each name in it against the few a pack
/// may hold (no `..`, nothing outside its folder, nothing executable).
/// Unpacked into a folder of its own first, checked as a pack of the right
/// print, and only then moved into place.
abstract final class PackInstall {
  /// `<app support>/packs` (set at startup; null in tests until given).
  static String? root;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      root = '${(await getApplicationSupportDirectory()).path}/packs';
      MushafPacks.downloadRoot = root;
    } catch (_) {}
  }

  @visibleForTesting
  static http.Client Function() client = http.Client.new;

  /// Where [edition] is unpacked to (whether or not it's there yet).
  static String? dirOf(String edition) => root == null ? null : '$root/$edition';

  /// Whether [edition] has something downloaded.
  static bool downloaded(String edition) {
    final d = dirOf(edition);
    return d != null && File('$d/pages.json').existsSync();
  }

  /// Downloads [p], checks it, and unpacks it into place. [onProgress]: the
  /// zip's bytes so far, of [PackEntry.bytes].
  static Future<void> install(PackEntry p,
      {void Function(int done, int total)? onProgress,
      Future<void>? cancel,
      bool allowHttp = false}) async {
    final r = root;
    if (r == null) throw StateError('no folder for packs');
    final zip = File('$r/.downloads/${p.file.split('/').last}');
    await downloadVerified(p.url, zip,
        bytes: p.bytes,
        sha256: p.sha256,
        client: client,
        cancel: cancel,
        allowHttp: allowHttp,
        onProgress: (d) => onProgress?.call(d, p.bytes));

    final tmp = Directory('$r/.unpack-${p.edition}-${p.tier}');
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    try {
      final zipPath = zip.path, tmpPath = tmp.path, tier = p.tier;
      await Isolate.run(() => _unpack(zipPath, tmpPath, tier));
      // A pack of the print it says it is, with the tier it says.
      final (pack, problem) = MushafPacks.check(tmp.path, p.edition);
      if (pack == null || !pack.tiers.any((t) => t.name == p.tier)) {
        throw PackRefused('not a ${p.edition} ${p.tier} pack ($problem)');
      }
      _moveIn(tmp, Directory('$r/${p.edition}'), p);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
    if (zip.existsSync()) zip.deleteSync();
    MushafPacks.forgetChecks();
    MushafPacks.changes.value++;
  }

  /// Removes [edition]'s downloaded files.
  static Future<void> remove(String edition) async {
    final d = dirOf(edition);
    if (d != null && Directory(d).existsSync()) await Directory(d).delete(recursive: true);
    MushafPacks.forgetChecks();
    MushafPacks.changes.value++;
  }

  /// The names a pack's zip may hold for [tier].
  static bool allowedName(String name, String tier) {
    if (name.contains('\\') || name.startsWith('/') || name.split('/').contains('..')) {
      return false;
    }
    return name == 'pages.json' ||
        name == 'signs.json' ||
        RegExp('^$tier/(mushaf_manifest\\.bin|shared\\.webp|atlas_info\\.json|pages/[0-9]{1,4}\\.webp)\$')
            .hasMatch(name);
  }

  static void _unpack(String zipPath, String outPath, String tier) {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var files = 0;
      for (final f in archive) {
        if (!f.isFile) continue;
        if (!allowedName(f.name, tier)) throw PackRefused('unexpected file ${f.name}');
        if (++files > 2000) throw const PackRefused('too many files');
        final out = File('$outPath/${f.name}');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(f.content, flush: false);
      }
    } finally {
      input.closeSync();
    }
  }

  /// [from]'s tier into [to] (replacing that tier, if there was one), with
  /// its data; what was there of the other tier stays.
  static void _moveIn(Directory from, Directory to, PackEntry p) {
    to.createSync(recursive: true);
    final tierFrom = Directory('${from.path}/${p.tier}');
    final tierTo = Directory('${to.path}/${p.tier}');
    if (tierTo.existsSync()) tierTo.deleteSync(recursive: true);
    tierFrom.renameSync(tierTo.path);
    for (final name in ['pages.json', 'signs.json']) {
      final f = File('${from.path}/$name');
      if (f.existsSync()) f.renameSync('${to.path}/$name');
    }
    // What's here, for knowing an update when the catalog has one.
    final installed = File('${to.path}/installed.json');
    Map<String, dynamic> was = {};
    try {
      if (installed.existsSync()) was = jsonDecode(installed.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
    was[p.tier] = p.version;
    installed.writeAsStringSync(jsonEncode(was));
  }

  /// The version of [edition] at [tier] that's here, or 0.
  static int installedVersion(String edition, OriginalTier tier) {
    final d = dirOf(edition);
    if (d == null) return 0;
    try {
      final j = jsonDecode(File('$d/installed.json').readAsStringSync());
      return (j as Map)[tier.name] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
