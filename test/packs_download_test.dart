import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/packs/pack_catalog.dart';
import 'package:rasikh/core/packs/pack_install.dart';
import 'package:rasikh/core/verified_download.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/original/mushaf_packs.dart';
import 'package:rasikh/data/original/original_atlas.dart';

/// Packs from the server: a catalog believed only with its signature (and
/// never an older one), each pack checked by its SHA-256 and by the names in
/// it, unpacked where the app finds it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late SimpleKeyPair key;
  late String publicKey;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('rasikh_packs_dl');
    key = await Ed25519().newKeyPair();
    publicKey = base64.encode((await key.extractPublicKey()).bytes);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackCatalog.debugReset();
    PackCatalog.debugBase = 'https://dl.test';
    PackCatalog.debugKey = publicKey;
  });
  tearDown(() {
    PackCatalog.debugBase = null;
    PackCatalog.debugKey = null;
    PackCatalog.client = http.Client.new;
    PackInstall.client = http.Client.new;
    PackInstall.root = null;
    MushafPacks.downloadRoot = null;
  });

  /// A small pack for [tier] (or one holding [extra] too), and its catalog.
  Future<(Uint8List zip, Map<String, dynamic> catalog)> pack(String tier,
      {String? extra, String issued = '2026-11-01T00:00:00Z'}) async {
    final a = Archive();
    void add(String n, List<int> d) => a.add(ArchiveFile.bytes(n, d));
    final src = 'assets/quran/new_madani';
    add('pages.json', File('$src/pages.json').readAsBytesSync());
    add('$tier/mushaf_manifest.bin', File('$src/$tier/mushaf_manifest.bin').readAsBytesSync());
    add('$tier/shared.webp', File('$src/$tier/shared.webp').readAsBytesSync());
    add('$tier/pages/1.webp', File('$src/$tier/pages/1.webp').readAsBytesSync());
    if (extra != null) add(extra, utf8.encode('x'));
    final zip = Uint8List.fromList(ZipEncoder().encode(a));
    return (
      zip,
      {
        'format': 1,
        'issued': issued,
        'packs': [
          {
            'edition': 'newmadani',
            'tier': tier,
            'version': 1,
            'file': 'packs/newmadani-$tier-v1.zip',
            'bytes': zip.length,
            'sha256': sha256.convert(zip).toString(),
            'unpacked': zip.length,
          }
        ],
      }
    );
  }

  /// A server holding [files] (path → bytes).
  http.Client server(Map<String, List<int>> files) => MockClient((req) async {
        final body = files[req.url.path.substring(1)];
        return body == null
            ? http.Response('', 404)
            : http.Response.bytes(body, 200);
      });

  Future<Map<String, List<int>>> signed(Map<String, dynamic> catalog,
      {Uint8List? zip, String? tier, bool badSig = false}) async {
    final bytes = utf8.encode(jsonEncode(catalog));
    final sig = await Ed25519().sign(badSig ? utf8.encode('other') : bytes, keyPair: key);
    return {
      'catalog.json': bytes,
      'catalog.json.sig': utf8.encode(base64.encode(sig.bytes)),
      'packs/newmadani-$tier-v1.zip': ?zip,
    };
  }

  test('a signed catalog is believed; downloaded, the pack is the muṣḥaf\'s', () async {
    final (zip, catalog) = await pack('low');
    final files = await signed(catalog, zip: zip, tier: 'low');
    PackCatalog.client = () => server(files);
    PackInstall.client = () => server(files);
    PackInstall.root = '${tmp.path}/app1';
    MushafPacks.downloadRoot = PackInstall.root;
    final p = (await PackCatalog.find('newmadani', 'low'))!;
    await PackInstall.install(p);
    expect(MushafPacks.available(kNewMadaniPrint), isTrue);
    expect(MushafPacks.isDownloaded(kNewMadaniPrint), isTrue);
    expect(MushafPacks.of(kNewMadaniPrint)!.tiers, {OriginalTier.low});
    expect(PackInstall.installedVersion(kNewMadaniPrint, OriginalTier.low), 1);
    expect(Directory('${tmp.path}/app1/.downloads').listSync(), isEmpty, reason: 'the zip removed');
    await PackInstall.remove(kNewMadaniPrint);
    expect(MushafPacks.available(kNewMadaniPrint), isFalse);
  });

  test('a catalog signed with another key, or not at all: refused', () async {
    final (_, catalog) = await pack('low');
    final forged = await signedSync(catalog, badSig: true);
    PackCatalog.client = () => server(forged);
    await expectLater(PackCatalog.packs(refresh: true), throwsA(isA<PackCatalogRefused>()));
    PackCatalog.client = () => server({'catalog.json': utf8.encode(jsonEncode(catalog))});
    await expectLater(PackCatalog.packs(refresh: true), throwsA(anything));
  }, skip: false);

  test('an older catalog than one already seen: refused (no rollback to an old pack)',
      () async {
    final (_, newer) = await pack('low', issued: '2026-11-10T00:00:00Z');
    PackCatalog.client = () => server(cache[0]!);
    cache[0] = await signed(newer);
    await PackCatalog.packs(refresh: true);
    final (_, older) = await pack('low', issued: '2026-11-01T00:00:00Z');
    cache[0] = await signed(older);
    await expectLater(PackCatalog.packs(refresh: true), throwsA(isA<PackCatalogRefused>()));
  });

  test('a pack that isn\'t the file listed: thrown away, nothing installed', () async {
    final (zip, catalog) = await pack('low');
    final files = await signed(catalog, zip: zip, tier: 'low');
    files['packs/newmadani-low-v1.zip'] = [...zip]..[100] ^= 1; // one bit changed
    PackCatalog.client = () => server(files);
    PackInstall.client = () => server(files);
    PackInstall.root = '${tmp.path}/app2';
    MushafPacks.downloadRoot = PackInstall.root;
    final p = (await PackCatalog.find('newmadani', 'low'))!;
    await expectLater(PackInstall.install(p), throwsA(isA<DownloadBadFile>()));
    expect(MushafPacks.available(kNewMadaniPrint), isFalse);
  });

  test('a pack holding anything it shouldn\'t (even signed): refused', () async {
    for (final bad in ['../outside.txt', 'low/run.sh', '/etc/passwd', 'high/pages/1.webp']) {
      final (zip, catalog) = await pack('low', extra: bad);
      final files = await signed(catalog, zip: zip, tier: 'low');
      PackCatalog.debugReset();
      PackCatalog.client = () => server(files);
      PackInstall.client = () => server(files);
      PackInstall.root = '${tmp.path}/app3';
      MushafPacks.downloadRoot = PackInstall.root;
      final p = (await PackCatalog.find('newmadani', 'low'))!;
      await expectLater(PackInstall.install(p), throwsA(isA<PackRefused>()), reason: bad);
      expect(File('${tmp.path}/outside.txt').existsSync(), isFalse);
      expect(MushafPacks.available(kNewMadaniPrint), isFalse, reason: bad);
    }
  });

  test('only https', () async {
    expect(
        () => downloadVerified(Uri.parse('http://dl.test/x.zip'), File('${tmp.path}/x'),
            bytes: 1, sha256: '0' * 64, client: http.Client.new),
        throwsArgumentError);
  });

  // The real server config, if it's running locally (see
  // server/downloads/README.md: "Try it on your computer").
  final local = Platform.environment['RASIKH_DL_TEST'];
  test('end to end against the nginx config: the real packs, the real catalog', () async {
    // (Widget tests answer every real connection with 400: this one is real.)
    HttpOverrides.global = null;
    PackCatalog.debugBase = local;
    PackCatalog.debugKey = null; // the app's own key
    http.Client insecure() => IOClient(HttpClient()..badCertificateCallback = (_, _, _) => true);
    PackCatalog.client = insecure;
    PackInstall.client = insecure;
    PackInstall.root = '${tmp.path}/app4';
    MushafPacks.downloadRoot = PackInstall.root;
    final p = (await PackCatalog.find('newmadani', 'low'))!;
    var last = 0;
    await PackInstall.install(p, onProgress: (d, _) => last = d);
    expect(last, p.bytes);
    final pack = MushafPacks.of(kNewMadaniPrint)!;
    expect(pack.tiers, {OriginalTier.low});
    expect(Directory('${pack.root}/low/pages').listSync(), hasLength(604));
    OriginalAtlas.reset();
    final atlas = await OriginalAtlas.open(kNewMadaniPrint, OriginalTier.high);
    expect(atlas.tier, OriginalTier.low, reason: 'what was downloaded');
    expect(atlas.reader.pageCount, 604);
  }, skip: local == null ? 'set RASIKH_DL_TEST=https://localhost:18443 with the test server up' : false,
      timeout: const Timeout(Duration(minutes: 5)));
}

final cache = <int, Map<String, List<int>>?>{};

Future<Map<String, List<int>>> signedSync(Map<String, dynamic> catalog, {bool badSig = false}) async {
  final key = await Ed25519().newKeyPair();
  final bytes = utf8.encode(jsonEncode(catalog));
  final sig = await Ed25519().sign(badSig ? utf8.encode('other') : bytes, keyPair: key);
  return {
    'catalog.json': bytes,
    'catalog.json.sig': utf8.encode(base64.encode(sig.bytes)),
  };
}
