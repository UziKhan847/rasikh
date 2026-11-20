import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the printed muṣḥafs' packs are downloaded from: the server's
/// address, e.g. `https://dl.example.com` (empty: no downloads yet — the
/// prompt says "coming soon"). Set it here, or for one build with
/// `--dart-define=RASIKH_PACKS_URL=https://…`.
const kPacksBaseUrl = String.fromEnvironment('RASIKH_PACKS_URL', defaultValue: '');

/// The public half of the key the catalog is signed with
/// (`tool/packs/sign_catalog.dart keygen` prints it). Only a catalog signed
/// with its private half — which never leaves the signing computer — is
/// believed; the server itself isn't trusted.
const kPacksPublicKey = String.fromEnvironment('RASIKH_PACKS_KEY',
    defaultValue: 'wbOM40+O9IBFPEqGbxvbQoPf4QTsAdtP7rUOQNyLOpA=');

/// One downloadable pack: a printed muṣḥaf's tier, one zip.
class PackEntry {
  final String edition; // a script id: 'newmadani', 'oldmadani'
  final String tier; // 'high' | 'low'
  final int version;

  /// Relative to [kPacksBaseUrl].
  final String file;
  final int bytes;
  final String sha256;

  /// What it takes once unpacked.
  final int unpacked;

  const PackEntry({
    required this.edition,
    required this.tier,
    required this.version,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.unpacked,
  });

  static final _sha = RegExp(r'^[0-9a-f]{64}$');
  static final _file = RegExp(r'^packs/[a-z0-9-]+\.zip$');

  /// From the catalog; null if anything in it is off (a pack the app
  /// doesn't understand is left out, not trusted half-way).
  static PackEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = PackEntry(
      edition: j['edition'] is String ? j['edition'] as String : '',
      tier: j['tier'] is String ? j['tier'] as String : '',
      version: j['version'] is int ? j['version'] as int : 0,
      file: j['file'] is String ? j['file'] as String : '',
      bytes: j['bytes'] is int ? j['bytes'] as int : 0,
      sha256: j['sha256'] is String ? j['sha256'] as String : '',
      unpacked: j['unpacked'] is int ? j['unpacked'] as int : 0,
    );
    final ok = RegExp(r'^[a-z]+$').hasMatch(e.edition) &&
        (e.tier == 'high' || e.tier == 'low') &&
        e.version > 0 &&
        _file.hasMatch(e.file) &&
        e.bytes > 0 &&
        e.bytes < 2 * 1024 * 1024 * 1024 &&
        _sha.hasMatch(e.sha256);
    return ok ? e : null;
  }

  Uri get url => Uri.parse('${PackCatalog.base}/$file');
}

/// The catalog wasn't to be trusted (unsigned, wrongly signed, older than
/// one already seen, or unreadable).
class PackCatalogRefused implements Exception {
  final String why;
  const PackCatalogRefused(this.why);
  @override
  String toString() => 'pack catalog refused: $why';
}

/// What can be downloaded: `catalog.json` on the server, believed only with
/// its signature (`catalog.json.sig`, Ed25519 over its exact bytes, by
/// [kPacksPublicKey]) — and never one older than the newest seen (a server
/// handing back an old catalog can't bring back an old, fixed pack).
abstract final class PackCatalog {
  static bool get configured =>
      kPacksBaseUrl.startsWith('https://') && !kPacksPublicKey.startsWith('REPLACE');

  /// Tests: the client, the address and the key used.
  @visibleForTesting
  static http.Client Function() client = http.Client.new;
  @visibleForTesting
  static String? debugBase, debugKey;

  static String get base => debugBase ?? kPacksBaseUrl;
  static String get _key => debugKey ?? kPacksPublicKey;

  static const _seenKey = 'packs.catalogIssued';
  static const _maxBytes = 256 * 1024;

  static List<PackEntry>? _cached;

  /// The packs on offer (fetched once a run; [refresh] fetches again).
  static Future<List<PackEntry>> packs({bool refresh = false}) async {
    if (!refresh && _cached != null) return _cached!;
    return _cached = await _fetch();
  }

  /// The pack for [edition] at [tier], if the catalog has one.
  static Future<PackEntry?> find(String edition, String tier) async {
    for (final p in await packs()) {
      if (p.edition == edition && p.tier == tier) return p;
    }
    return null;
  }

  static Future<List<PackEntry>> _fetch() async {
    final c = client();
    try {
      final body = await _get(c, Uri.parse('$base/catalog.json'));
      final sig = await _get(c, Uri.parse('$base/catalog.json.sig'));
      await verify(body, utf8.decode(sig).trim(), _key);
      final j = jsonDecode(utf8.decode(body));
      if (j is! Map || j['format'] != 1) throw const PackCatalogRefused('format');
      final issued = DateTime.tryParse('${j['issued']}');
      if (issued == null) throw const PackCatalogRefused('no date');
      final prefs = await SharedPreferences.getInstance();
      final seen = DateTime.tryParse(prefs.getString(_seenKey) ?? '');
      if (seen != null && issued.isBefore(seen)) {
        throw const PackCatalogRefused('older than one already seen');
      }
      await prefs.setString(_seenKey, issued.toUtc().toIso8601String());
      return [
        for (final e in (j['packs'] as List? ?? const [])) ?PackEntry.fromJson(e),
      ];
    } finally {
      c.close();
    }
  }

  static Future<List<int>> _get(http.Client c, Uri url) async {
    final res = await c.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
    if (res.bodyBytes.length > _maxBytes) throw const PackCatalogRefused('too large');
    return res.bodyBytes;
  }

  /// Throws unless [signature] (base64) is [publicKey]'s (base64) over
  /// exactly [message].
  static Future<void> verify(List<int> message, String signature, String publicKey) async {
    final List<int> sig, key;
    try {
      sig = base64.decode(signature);
      key = base64.decode(publicKey);
    } on FormatException {
      throw const PackCatalogRefused('unreadable signature');
    }
    if (sig.length != 64 || key.length != 32) {
      throw const PackCatalogRefused('unreadable signature');
    }
    final ok = await Ed25519().verify(message,
        signature: Signature(sig, publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)));
    if (!ok) throw const PackCatalogRefused('signature');
  }

  /// Tests: forget what was fetched.
  @visibleForTesting
  static void debugReset() => _cached = null;
}
