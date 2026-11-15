import 'dart:io';

import 'package:flutter/foundation.dart';

import '../mushaf.dart' show kNewMadaniPrint, kOldMadani;
import 'original_atlas.dart' show OriginalTier;

/// A printed muṣḥaf's files on this device: where they are and which tiers.
class MushafPack {
  /// The folder with pages.json and signs.json; the tiers are under it.
  final String root;
  final Set<OriginalTier> tiers;
  const MushafPack(this.root, this.tiers);

  String tierDir(OriginalTier t) => '$root${Platform.pathSeparator}${t.name}';

  /// [want] if it's here, else the other.
  OriginalTier best(OriginalTier want) => tiers.contains(want) ? want : tiers.first;
}

/// Why a folder isn't a pack: not there; no pages.json (or, for Old
/// Madani, signs.json); no tier of pages; or another print's ([otherEdition]).
enum PackProblem { missing, noData, noTier, otherEdition }

/// The printed muṣḥafs aren't in the app: each is a folder of files, chosen
/// (desktop) or, later, downloaded. Which folder is the settings'
/// ([dirs], `packDirs`); what's in it is checked before it's used.
class MushafPacks {
  MushafPacks._();

  /// The scripts that need a pack.
  static const scripts = {kOldMadani, kNewMadaniPrint};

  /// The folders chosen, by script (the settings' map).
  static Map<String, String> dirs = {};

  /// Tests: a folder for every script, over [dirs].
  @visibleForTesting
  static String? debugDir;

  /// The download's size of each tier, for the prompt.
  static const sizesMb = {
    kOldMadani: {OriginalTier.high: 124, OriginalTier.low: 73},
    kNewMadaniPrint: {OriginalTier.high: 147, OriginalTier.low: 84},
  };

  /// Only Old Madani's set has signs.json (its clean signs and circle).
  static bool _needsSigns(String script) => script == kOldMadani;

  /// The edition [root]'s pages.json says it is (`tool/gen_print_layout.py`
  /// writes it first), or null.
  static String? editionAt(String root) {
    try {
      final f = File('$root${Platform.pathSeparator}pages.json').openSync();
      try {
        final head = String.fromCharCodes(f.readSync(160));
        return RegExp(r'"edition"\s*:\s*"(\w+)"').firstMatch(head)?[1];
      } finally {
        f.closeSync();
      }
    } on FileSystemException {
      return null;
    }
  }

  /// Bumped when a folder is chosen or forgotten: what's open is read again.
  static final changes = ValueNotifier<int>(0);

  static String? dirOf(String script) => debugDir ?? dirs[script];

  /// [script]'s pack, if its folder is there and holds one.
  static MushafPack? of(String script) {
    final d = dirOf(script);
    if (d == null) return null;
    final (pack, _) = check(d, script);
    return pack;
  }

  static bool available(String script) => !scripts.contains(script) || of(script) != null;

  /// What [dir] holds for [script]: the whole set (pages.json, signs.json
  /// for Old Madani, high/ and/or low/), or one tier's folder in it — and
  /// only if it's [script]'s print, not another's.
  static (MushafPack?, PackProblem?) check(String dir, String script) {
    final d = Directory(dir);
    if (!d.existsSync()) return (null, PackProblem.missing);
    String sep(String a, String b) => '$a${Platform.pathSeparator}$b';
    // Which print first (a pages.json that doesn't say isn't one of ours),
    // then whether the rest of its data is there.
    PackProblem? data(String root) {
      if (!File(sep(root, 'pages.json')).existsSync()) return PackProblem.noData;
      final e = editionAt(root);
      if (e == null) return PackProblem.noData;
      if (e != script) return PackProblem.otherEdition;
      if (_needsSigns(script) && !File(sep(root, 'signs.json')).existsSync()) {
        return PackProblem.noData;
      }
      return null;
    }
    bool isTier(String t) =>
        File(sep(t, 'mushaf_manifest.bin')).existsSync() &&
        File(sep(t, 'shared.webp')).existsSync() &&
        File(sep(sep(t, 'pages'), '1.webp')).existsSync();

    var root = d.absolute.path;
    if (root.endsWith(Platform.pathSeparator) && root.length > 1) {
      root = root.substring(0, root.length - 1);
    }
    // A tier's own folder: the set is its parent.
    final name = root.split(Platform.pathSeparator).last;
    if (OriginalTier.values.any((t) => t.name == name) && isTier(root)) {
      final parent = d.absolute.parent.path;
      if (data(parent) case final p?) return (null, p);
      return (
        MushafPack(parent, {OriginalTier.values.firstWhere((t) => t.name == name)}),
        null
      );
    }
    if (data(root) case final p?) return (null, p);
    final tiers = {
      for (final t in OriginalTier.values)
        if (isTier(sep(root, t.name))) t,
    };
    if (tiers.isEmpty) return (null, PackProblem.noTier);
    return (MushafPack(root, tiers), null);
  }
}
