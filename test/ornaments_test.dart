import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/divisions.dart' show rukuCountOf;
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/ui/ornaments/ornaments.dart';

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

  group('settings from before the ornaments were separate', () {
    test('Classic with its border and lantern: every part on auto', () async {
      final s = await _from({
        'ornaments': 'classic',
        'mushafBorder': true,
        'mushafMarginInfo': true,
      });
      expect((s.orHeader, s.orMarker, s.orBorder, s.orMargin),
          ('auto', 'auto', 'auto', 'auto'));
    });

    test('Modern, border off: the script\'s header, the font\'s marker',
        () async {
      final s = await _from({'ornaments': 'modern', 'mushafBorder': false});
      expect((s.orHeader, s.orMarker, s.orBorder, s.orMargin),
          ('auto', 'font', 'none', 'none'));
    });

    test('dropped options: plain and rosette headers, the Madani circle',
        () async {
      final s = await _from({
        'orHeader': 'rosette',
        'orMarker': 'madani',
        'orBorder': 'thin2',
        'orMargin': 'auto',
        'orTune': {'markerMadaniScale': 1.2, 'headerScale': .9},
      });
      expect((s.orHeader, s.orMarker, s.orBorder), ('auto', 'font', 'thin2'));
      expect(s.orTune, {'headerScale': .9});
    });

    test('a chosen border style and the margin off carry over', () async {
      final s = await _from({
        'ornaments': 'classic',
        'mushafBorder': true,
        'mushafBorderStyle': 'indopak',
        'mushafMarginInfo': false,
      });
      expect((s.orBorder, s.orMargin), ('indopak', 'none'));
    });

    test('"ornate borders" off, from before the styles: plain', () async {
      final s = await _from({'ornate': false});
      expect((s.orHeader, s.orMarker), ('auto', 'font'));
    });
  });

  group('MushafLook', () {
    test('auto takes each script\'s own artwork', () {
      MushafLook auto(String script) => MushafLook.resolve(script,
          header: 'auto', marker: 'auto', border: 'auto', margin: 'auto');
      final m = auto('uthmani'), i = auto('indopak');
      expect((m.header, m.marker, m.border, m.margin),
          ('madani', 'font', 'madani', 'lantern'));
      expect((i.header, i.marker, i.border, i.margin),
          ('indopak', 'indopak', 'indopak', 'text'));
    });

    test('a part chosen outright stays, whatever the script', () {
      final l = MushafLook.resolve('indopak',
          header: 'madani', marker: 'madani', border: 'tile2', margin: 'lantern');
      expect((l.header, l.marker, l.border, l.margin, l.tileBorder),
          ('madani', 'madani', 'tile2', 'lantern', 2));
    });

    test('Lite draws plainly; focus mode bares the page', () async {
      final s = await _from({});
      s
        ..orHeader = 'tile1'
        ..orMarker = 'madani'
        ..orBorder = 'tile1'
        ..orMargin = 'lantern';
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
      expect(b('indopak').borderBand(fs), closeTo(6, 1e-9));
      expect(b('tile1').borderBand(fs), closeTo(14.4 * 1.35, 1e-9));
      expect(b('thin2').borderBand(fs), closeTo(14.4 * .95, 1e-9));
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
    expect(ip.bounds.width, lessThanOrEqualTo(1000));
    expect(1000 - ip.bounds.width, lessThan(strip));
    expect(copies, greaterThan(0));
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
