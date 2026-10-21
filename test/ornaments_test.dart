import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/divisions.dart' show rukuCountOf;
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/page_details.dart';
import 'package:qiraah_arabiyyah/ui/ornaments/ornaments.dart';

import 'test_support.dart' show loadMushaf;

/// Settings loaded from [saved] (the stored JSON's fields).
Future<AppSettings> _from(Map<String, Object?> saved) async {
  SharedPreferences.setMockInitialValues({
    'noor.settings.v1': jsonEncode(saved),
  });
  final s = AppSettings();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('each script\'s own look', () {
    test('from before looks were per script: each script\'s default look',
        () async {
      final s = await _from({'orHeader': 'madani', 'orBorder': 'none'});
      final m = s.mushafLook('uthmani', focus: false);
      final i = s.mushafLook('indopak', focus: false);
      // Madani: cream, the gold double frame, line-art header, head inside.
      expect((m.header, m.marker, m.border, m.margin, m.head),
          ('madani', 'font', 'double', 'none', 'inside'));
      expect((i.header, i.marker, i.border, i.margin, i.head),
          ('indopak', 'indopak', 'indopak', 'text', 'edges'));
      expect((s.styleFor('uthmani').paper, s.styleFor('indopak').paper),
          ('cream', 'mono'));
    });

    test('the old printed Madani default moves to the new one; a choice '
        'stays', () async {
      Map<String, Object?> saved(String paper, String border) => {
            'mushafStyles': {
              'uthmani': {'paper': paper, 'border': border},
            },
          };
      final old = await _from(saved('madani', 'auto'));
      expect(old.styleFor('uthmani').paper, 'cream');
      final chosen = await _from(saved('madani', 'thinnest3'));
      expect(chosen.styleFor('uthmani').paper, 'madani');
    });

    test('edge to edge: no frame, margin or running head', () async {
      final s = await _from({});
      s.mushafScript = 'uthmani';
      s.styleFor('uthmani').edge = true;
      final l = s.mushafLook('uthmani', focus: false);
      expect((l.edge, l.border, l.margin, l.header),
          (true, 'none', 'none', 'madani'));
      expect(s.mushafHeaderShown, isFalse);
      expect(
          MushafGeometry.chromeW(roomy: true, look: l),
          lessThan(MushafGeometry.chromeW(
              roomy: true, look: s.mushafLook('indopak', focus: false))));
    });

    test('a change to one script leaves the other', () async {
      final s = await _from({});
      s.styleFor('indopak').border = 'thin2';
      s.mushafScript = 'uthmani';
      s.orHeader = 'tile1';
      await s.save();
      final again = await _from(jsonDecode(
          jsonEncode({'mushafStyles': {
            for (final e in s.mushafStyles.entries) e.key: e.value.toJson(),
          }})) as Map<String, Object?>);
      expect(again.styleFor('uthmani').header, 'tile1');
      expect(again.styleFor('indopak').header, 'auto');
      expect(again.styleFor('indopak').border, 'thin2');
    });

    test('tuning keys that no longer exist are dropped', () async {
      final s = await _from({
        'mushafStyles': {
          'uthmani': {
            'tune': {'markerMadaniScale': 1.2, 'headerScale': .9},
          },
        },
      });
      expect(s.styleFor('uthmani').tune, {'headerScale': .9});
    });
  });

  group('page details', () {
    test('juzʼ and para names, ḥizb quarters', () {
      expect(madaniJuzName(1), 'الجزء الأول');
      expect(madaniJuzName(12), 'الجزء الثاني عشر');
      expect(madaniJuzName(20), 'الجزء العشرون');
      expect(madaniJuzName(23), 'الجزء الثالث والعشرون');
      expect(madaniJuzName(30), 'الجزء الثلاثون');
      expect(indopakParaName(30), 'عَمَّ');
      expect(hizbQuarterText(189), 'الحزب\n٤٨');
      expect(hizbQuarterText(190), 'ربع الحزب\n٤٨');
      expect(hizbQuarterText(191), 'نصف الحزب\n٤٨');
      expect(hizbQuarterText(192), 'ثلاثة أرباع\nالحزب ٤٨');
    });

    test('lines carry their quarter starts and rukūʿ ends', () async {
      await loadMushaf('uthmani');
      await loadMushaf('indopak');
      // Madani page 5 holds 2:26, the second quarter.
      final m5 = MushafRepo.pageSync('uthmani', 5)!;
      final q = hizbQuartersOn(m5);
      expect(q.map((e) => e.$1), [2]);
      expect(m5[q.single.$2].words.any((w) =>
          MushafRepo.surahAyahOf(w.ayah) == (2, 26) && w.wordIdx == 0), isTrue);
      // al-Baqarah's first rukūʿ, 2:1–7, ends on Indo-Pak page 2 or 3.
      final ends = [
        for (final p in [2, 3]) ...rukuEndsOn(MushafRepo.pageSync('indopak', p)!),
      ];
      expect(ends.first.$2, 1);
      expect(ends.first.$3, 7);
    });
  });

  group('MushafLook', () {
    test('auto takes each script\'s own artwork', () {
      MushafLook auto(String script) => MushafLook.resolve(script,
          header: 'auto', marker: 'auto', border: 'auto', margin: 'auto');
      final m = auto('uthmani'), i = auto('indopak');
      expect((m.header, m.marker, m.border, m.margin, m.head),
          ('madani', 'font', 'double', 'none', 'inside'));
      expect((i.header, i.marker, i.border, i.margin, i.head),
          ('indopak', 'indopak', 'indopak', 'text', 'edges'));
    });

    test('a part chosen outright stays, whatever the script', () {
      final l = MushafLook.resolve('indopak',
          header: 'madani', marker: 'indopak', border: 'tile2', margin: 'lantern2');
      expect((l.header, l.marker, l.border, l.margin, l.tileBorder),
          ('madani', 'indopak', 'tile2', 'lantern2', 2));
    });

    test('Lite draws plainly; focus mode bares the page', () async {
      final s = await _from({});
      s
        ..orHeader = 'tile1'
        ..orMarker = 'indopak'
        ..orBorder = 'tile1'
        ..orMargin = 'lantern1';
      s.lite = true;
      final lite = s.mushafLook('uthmani');
      expect((lite.header, lite.marker, lite.border, lite.margin),
          ('plain', 'font', 'line', 'text'));
      s
        ..lite = false
        ..focusMode = true;
      final focus = s.mushafLook('uthmani');
      expect((focus.header, focus.border, focus.margin),
          ('plain', 'none', 'none'));
      expect(s.mushafLook('uthmani', focus: false).border, 'tile1');
    });

    test('each artwork border has its own band, and tuning scales it', () {
      const fs = 30.0;
      MushafLook b(String border, [Map<String, double> t = const {}]) =>
          MushafLook(border: border, tune: OrnamentTuning(t));
      expect(b('madani').borderBand(fs), closeTo(14.4, 1e-9));
      // (Its default thickness is 1.85 × its band.)
      expect(b('indopak').borderBand(fs), closeTo(6 * 1.85, 1e-9));
      expect(b('tile1').borderBand(fs), closeTo(14.4 * 1.35, 1e-9));
      expect(b('thin2').borderBand(fs), closeTo(14.4 * .95, 1e-9));
      expect(b('thinnest3').borderBand(fs), closeTo(14.4 * .6, 1e-9));
      expect(b('line').borderBand(fs), 0);
      expect(b('madani', {'borderMadani': 1.5}).borderBand(fs),
          closeTo(21.6, 1e-9));
      // Wider chrome for an artwork border than for a line.
      double w(String border) => MushafGeometry.chromeW(
          roomy: false, look: b(border), fs: fs);
      expect(w('tile1'), greaterThan(w('madani')));
      expect(w('madani'), greaterThan(w('line')));
    });
  });

  test('rukūʿ per sūrah, as the Indo-Pak header prints them', () {
    expect((rukuCountOf(1), rukuCountOf(2), rukuCountOf(3)), (1, 40, 20));
    expect([for (var i = 1; i <= 114; i++) rukuCountOf(i)].reduce((a, b) => a + b),
        558);
  });

  test('a widened header keeps its ends; the Indo-Pak beads repeat whole',
      () {
    final madani = WideArt.layout(ClassicArt.surahBorder,
        box: const Rect.fromLTWH(0, 0, 1000, 40), height: 40,
        stretch: (.3, .7));
    expect(madani.bounds.width, 1000);
    // The ends keep the art's own proportions.
    final natural = 40 * ClassicArt.surahBorder.ratio;
    expect(madani.x(.3), closeTo(.3 * natural, 1e-6));
    expect(1000 - madani.x(.7), closeTo(.3 * natural, 1e-6));

    final ip = WideArt.layout(ClassicArt.indopakSurahHeader,
        box: const Rect.fromLTWH(0, 0, 1000, 40), height: 40,
        repeat: (.5 - .011595, 2 * .011595));
    final strip = 2 * .011595 * 40 * ClassicArt.indopakSurahHeader.ratio;
    final copies = ip.pieces.length - 2;
    // Exactly the width: whole bead strips, each at most a few % wider.
    expect(ip.bounds.width, closeTo(1000, 1e-6));
    expect(copies, greaterThan(0));
    final copyW = ip.pieces[1].$2.width;
    expect(copyW, greaterThanOrEqualTo(strip - 1e-6));
    expect(copyW, lessThan(strip * 2));
  });

  test('edges repeat in whole tiles', () {
    expect(wholeTiles(300, 73), 4);
    expect(wholeTiles(10, 73), 1);
    expect(wholeTiles(146, 73), 2);
  });

  test('tuning: overrides only, a copyable description, equality', () {
    const t = OrnamentTuning();
    final u = t.withValue('headerScale', 1.2);
    expect(u['headerScale'], 1.2);
    expect(u.overrides, {'headerScale': 1.2});
    expect(u.withValue('headerScale', 1.0).overrides, isEmpty);
    expect(u.describe(), contains('headerScale: 1.200'));
    expect(u, OrnamentTuning(const {'headerScale': 1.2}));
  });

  test('containRect keeps the ratio and centres', () {
    final r = containRect(const Rect.fromLTWH(0, 0, 200, 20), 8);
    expect((r.width, r.height, r.center.dx), (160.0, 20.0, 100.0));
  });
}
