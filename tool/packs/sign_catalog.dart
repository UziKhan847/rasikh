// Signs the packs' catalog, so the app believes only what you published.
//
//   dart run tool/packs/sign_catalog.dart keygen   (once: makes your key)
//   dart run tool/packs/sign_catalog.dart sign     (after each build_packs.py)
//   dart run tool/packs/sign_catalog.dart verify   (checks a signed catalog)
//
// The private key stays in ~/.config/rasikh/pack-signing.key, readable only
// by you: never in the repo, never on the server. Back it up somewhere safe
// (a password manager): without it, no new catalog can be signed for the
// apps already out — a new key needs an app update. If it's ever exposed,
// make a new one and ship an app with the new public key.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

final _home = Platform.environment['HOME'] ?? '.';
final _keyFile = File('$_home/.config/rasikh/pack-signing.key');
const _catalog = 'build/packs/catalog.json';

Future<void> main(List<String> args) async {
  switch (args.firstOrNull) {
    case 'keygen':
      await _keygen();
    case 'sign':
      await _sign(args.length > 1 ? args[1] : _catalog);
    case 'verify':
      await _verify(args.length > 1 ? args[1] : _catalog);
    default:
      stderr.writeln('usage: sign_catalog.dart keygen | sign [catalog.json] | verify [catalog.json]');
      exit(2);
  }
}

Future<void> _keygen() async {
  if (_keyFile.existsSync()) {
    stderr.writeln('${_keyFile.path} exists already: not replaced (a new key needs an app update).');
    exit(1);
  }
  final pair = await Ed25519().newKeyPair();
  final seed = await pair.extractPrivateKeyBytes();
  final pub = (await pair.extractPublicKey()).bytes;
  _keyFile.parent.createSync(recursive: true);
  _keyFile.writeAsStringSync('${base64.encode(seed)}\n');
  await Process.run('chmod', ['600', _keyFile.path]);
  await Process.run('chmod', ['700', _keyFile.parent.path]);
  stdout
    ..writeln('Private key: ${_keyFile.path} (back it up; never share it)')
    ..writeln('Public key, for kPacksPublicKey in lib/core/packs/pack_catalog.dart:')
    ..writeln(base64.encode(pub));
}

Future<SimpleKeyPair> _pair() async {
  if (!_keyFile.existsSync()) {
    stderr.writeln('No key: run "keygen" first.');
    exit(1);
  }
  final seed = base64.decode(_keyFile.readAsStringSync().trim());
  return Ed25519().newKeyPairFromSeed(seed);
}

Future<void> _sign(String path) async {
  final pair = await _pair();
  final bytes = File(path).readAsBytesSync();
  final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (j['format'] != 1 || j['issued'] == null) {
    stderr.writeln('$path: not a catalog (format 1, with "issued").');
    exit(1);
  }
  final sig = await Ed25519().sign(bytes, keyPair: pair);
  File('$path.sig').writeAsStringSync('${base64.encode(sig.bytes)}\n');
  stdout.writeln('Signed: $path.sig (${(j['packs'] as List).length} packs, issued ${j['issued']})');
  stdout.writeln('Public key: ${base64.encode((await pair.extractPublicKey()).bytes)}');
}

Future<void> _verify(String path) async {
  final pair = await _pair();
  final ok = await Ed25519().verify(File(path).readAsBytesSync(),
      signature: Signature(base64.decode(File('$path.sig').readAsStringSync().trim()),
          publicKey: await pair.extractPublicKey()));
  stdout.writeln(ok ? 'Good signature.' : 'BAD signature.');
  exit(ok ? 0 : 1);
}
