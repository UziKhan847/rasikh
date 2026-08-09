import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/special_shapes.dart';
import 'package:qiraah_arabiyyah/data/variants.dart';

/// Data-integrity guards for special_shapes.dart, mirroring
/// qaidah_variants_test.dart's own style: everything here is checked
/// against the real files on disk, not just internal consistency.
void main() {
  List<String> ayahsFor(int surah) =>
      (jsonDecode(File('assets/quran/u/$surah.json').readAsStringSync()) as List).cast<String>();

  String ayahAt(String ref) {
    final parts = ref.split(':');
    final surah = int.parse(parts[0]);
    final ayah = int.parse(parts[1]);
    return ayahsFor(surah)[ayah - 1];
  }

  final allFormAssets = {
    for (final s in specialShapes)
      for (final f in s.forms) f.asset,
  };

  group('asset files', () {
    test('every ShapeForm asset exists on disk', () {
      for (final s in specialShapes) {
        for (final f in s.forms) {
          expect(File(f.asset).existsSync(), isTrue,
              reason: 'Shape "${s.id}" points at a missing file: ${f.asset}');
        }
      }
    });

    test('every non-empty ShapeExample asset exists on disk', () {
      for (final s in specialShapes) {
        for (final e in s.examples) {
          if (e.asset.isEmpty) continue;
          expect(File(e.asset).existsSync(), isTrue,
              reason: 'Shape "${s.id}" example points at a missing file: ${e.asset}');
        }
      }
    });

    test('assets/special_cases/*.svg on disk is exactly the set of '
        'ShapeForm assets — no orphans, no duplicates, no stale names', () {
      final onDisk = Directory('assets/special_cases')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.svg'))
          .toSet();
      expect(onDisk, allFormAssets);
    });

    test('every ShapeForm/ShapeExample asset path sits under a directory '
        "registered in pubspec.yaml's assets: block", () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final registered = RegExp(r'^\s*-\s*(assets/\S+)$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();
      bool covered(String path) => registered.any((dir) => path.startsWith(dir));
      for (final a in allFormAssets) {
        expect(covered(a), isTrue, reason: '$a is not under a registered asset directory');
      }
      for (final s in specialShapes) {
        for (final e in s.examples) {
          if (e.asset.isEmpty) continue;
          expect(covered(e.asset), isTrue,
              reason: '${e.asset} is not under a registered asset directory');
        }
      }
    });
  });

  group('shapeSvgMm', () {
    test('every ShapeForm asset has an mm entry, matching its own <svg> '
        'header to within 0.01mm', () {
      final wh = RegExp(r'width="([\d.]+)mm"\s+height="([\d.]+)mm"');
      for (final a in allFormAssets) {
        expect(shapeSvgMm.containsKey(a), isTrue, reason: 'shapeSvgMm has no entry for $a');
        final m = wh.firstMatch(File(a).readAsStringSync());
        expect(m, isNotNull, reason: '$a has no width=".."mm" height=".."mm" header');
        final (w, h) = shapeSvgMm[a]!;
        expect(w, closeTo(double.parse(m!.group(1)!), 0.01), reason: '$a width');
        expect(h, closeTo(double.parse(m.group(2)!), 0.01), reason: '$a height');
      }
    });
  });

  group('specialShapes', () {
    test('every shape has non-empty title, note, tellApart, and at least '
        'one form', () {
      for (final s in specialShapes) {
        expect(s.title, isNotEmpty, reason: s.id);
        expect(s.note, isNotEmpty, reason: s.id);
        expect(s.tellApart, isNotEmpty, reason: s.id);
        expect(s.forms, isNotEmpty, reason: s.id);
      }
    });

    test('ids are unique', () {
      final ids = specialShapes.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('shapeById finds every id, and only real ids', () {
      for (final s in specialShapes) {
        expect(shapeById(s.id).id, s.id);
      }
      expect(() => shapeById('nope'), throwsStateError);
    });

    test('every variantIds entry is a real LetterVariant id', () {
      final realIds = letterVariants.map((v) => v.id).toSet();
      for (final s in specialShapes) {
        for (final id in s.variantIds) {
          expect(realIds.contains(id), isTrue, reason: 'Shape "${s.id}" -> unknown variant $id');
        }
      }
    });

    test('superseded (variantIds) + pending together cover all 20 '
        'LetterVariant ids, with no overlap', () {
      final superseded = specialShapes.expand((s) => s.variantIds).toList();
      expect(superseded.toSet().length, superseded.length, reason: 'a variant is superseded twice');
      final supersededSet = superseded.toSet();
      final pendingSet = pendingVariantIds.toSet();
      expect(pendingVariantIds.length, pendingSet.length, reason: 'pendingVariantIds has a duplicate');
      expect(supersededSet.intersection(pendingSet), isEmpty,
          reason: 'a variant is both superseded and pending');
      final allVariantIds = letterVariants.map((v) => v.id).toSet();
      expect(supersededSet.union(pendingSet), allVariantIds);
    });

    test('every ShapeExample with a ref is a verbatim word of that āyah', () {
      for (final s in specialShapes) {
        for (final e in s.examples) {
          if (e.ref.isEmpty) continue;
          final ayah = ayahAt(e.ref);
          expect(ayah.split(' ').contains(e.word), isTrue,
              reason: 'Shape "${s.id}" example word is not a verbatim word of '
                  '${e.ref}.\n  word: ${e.word}\n  āyah: $ayah');
          if (e.highlight.isNotEmpty) {
            expect(e.word.contains(e.highlight), isTrue,
                reason: 'Shape "${s.id}" example highlight is not inside its word');
          }
        }
      }
    });

    test('every ShapeForm declares exactly one of position/label', () {
      for (final s in specialShapes) {
        for (final f in s.forms) {
          expect((f.position == null) != (f.label.isEmpty), isTrue,
              reason: 'Shape "${s.id}" has a form with both/neither position and label');
        }
      }
    });
  });
}
