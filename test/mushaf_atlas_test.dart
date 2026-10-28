import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/mushaf_atlas.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/ui/tajwid_colors.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The glyph atlas (tool/mushaf_atlas/gen_atlas.py) draws the muṣḥaf's
/// lines: the Madani set justified by digitalkhatt's engine, the Indo-Pak
/// as the text path would (same token positions, baseline, justification)
/// — and adds tajwīd colours letter by letter.
const _ink = Color(0xFF111111);
const _accent = Color(0xFF00AA00);

MushafLineSpec _spec(
  String script,
  int page,
  int index, {
  double fs = 22,
  double targetW = 380,
  List<Color>? tajwid,
  int playAyah = -1,
  int playWord = -1,
}) {
  final lines = MushafRepo.pageSync(script, page)!;
  return MushafLineSpec(
    script: script,
    page: page,
    index: index,
    line: lines[index],
    fontSize: fs,
    slotH: fs * 1.8,
    targetW: targetW,
    ink: _ink,
    accent: _accent,
    strongBg: const Color(0x3300AA00),
    verseBg: const Color(0x1100AA00),
    tajwid: tajwid,
    playAyah: playAyah,
    playWord: playWord,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  test('both scripts load an atlas built from their text', () {
    for (final script in ['uthmani', 'indopak']) {
      final a = MushafAtlas.of(script);
      expect(a, isNotNull, reason: script);
      expect(a!.tokenWord.length, MushafRepo.tokensSync(script).length);
      expect(a.tiers.first.images, isNotNull);
    }
  });

  test('the Madani lines come justified: a page\'s full lines fill the measure, '
      'its narrow ones keep their width', () {
    final atlas = MushafAtlas.of('uthmani')!;
    expect(atlas.justified, isTrue);
    expect(MushafAtlas.of('indopak')!.justified, isFalse);
    // (Pages 1–2: their circle, below.)
    for (final page in [3, 50, 300, 604]) {
      final lines = MushafRepo.pageSync('uthmani', page)!;
      final text = [for (var i = 0; i < lines.length; i++) if (lines[i].isText) i];
      // Each line as set, unstretched; the page's measure is its widest.
      final natural = {
        for (final i in text) i: buildAtlasLine(_spec('uthmani', page, i, targetW: 1e6), atlas, 0).width,
      };
      final measure = natural.values.reduce((a, b) => a > b ? a : b);
      var full = 0;
      for (final i in text) {
        final drawn = buildAtlasLine(_spec('uthmani', page, i, targetW: measure), atlas, 0);
        final where = 'p.$page line $i';
        if (natural[i]! >= measure * .97) {
          full++;
          expect(drawn.width, closeTo(measure, 1.5), reason: where);
          expect(natural[i]!, greaterThan(measure * .98), reason: '$where: set near the measure');
        } else {
          expect(drawn.width, closeTo(natural[i]!, .01), reason: '$where: not stretched');
        }
        expect(drawn.boxes.length, lines[i].words.length, reason: where);
        for (var k = 1; k < drawn.boxes.length; k++) {
          expect(drawn.boxes[k].$2, lessThanOrEqualTo(drawn.boxes[k - 1].$1 + .5),
              reason: '$where token $k: right to left, no overlap');
        }
      }
      // Bar the last page's short sūrahs, all but a sūrah's last line
      // fill it.
      if (page < 600) expect(full, greaterThan(text.length - 3), reason: 'p.$page');
    }
  });

  test('the opening pages are set as the print sets them: each line its '
      'share of one circle, the same circle on both pages', () {
    final atlas = MushafAtlas.of('uthmani')!;
    double width(int page, int row) => buildAtlasLine(
            _spec('uthmani', page, row, targetW: 1e6), atlas, 0)
        .width;
    // Al-Fātiḥah's widest is its 5th line; al-Baqarah's 2nd–6th are wide,
    // its last short — and al-Fātiḥah's 2nd and 6th shorter than their
    // neighbours, as printed.
    expect(width(1, 5), greaterThan(width(1, 4)));
    expect(width(1, 2), lessThan(width(1, 3)));
    expect(width(1, 6), lessThan(width(1, 5) * .65));
    expect(width(2, 7), lessThan(width(2, 6) * .55));
    // One circle: al-Fātiḥah's 5th (.93 of it) and al-Baqarah's 5th (.91).
    expect(width(1, 5) / width(2, 5), closeTo(.93 / .91, .02));
  });

  test('a line is laid out once: another size, a mark or a tick reuses its '
      'geometry and only recolours it', () {
    final atlas = MushafAtlas.of('uthmani')!;
    final a = buildAtlasLine(_spec('uthmani', 50, 3), atlas, 0);
    final bigger = buildAtlasLine(_spec('uthmani', 50, 3, fs: 33, targetW: 570), atlas, 0);
    final line = MushafRepo.pageSync('uthmani', 50)![3];
    final w = line.words.firstWhere((w) => !w.isMarker);
    final ticked = buildAtlasLine(
        _spec('uthmani', 50, 3, playAyah: w.ayah, playWord: w.wordIdx), atlas, 0);
    expect(identical(a.geometry, bigger.geometry), isTrue, reason: 'resized');
    expect(identical(a.geometry, ticked.geometry), isTrue, reason: 'a tick');
    expect(bigger.width, closeTo(a.width * 33 / 22, .5));
  });

  test('atlas lines match the text path: positions, width, baseline', () {
    for (final (script, pages) in [
      ('indopak', [3, 50, 300]),
    ]) {
      final atlas = MushafAtlas.of(script)!;
      for (final page in pages) {
        final lines = MushafRepo.pageSync(script, page)!;
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].isText) continue;
          final spec = _spec(script, page, i);
          final text = MushafLineCache.get(spec);
          final drawn = buildAtlasLine(spec, atlas, 0);
          final where = '$script p.$page line $i';
          expect(drawn.width, closeTo(text.width, 1.5), reason: where);
          expect(drawn.baseline, closeTo(text.baseline, 0.75), reason: where);
          expect(drawn.boxes.length, text.boxes.length, reason: where);
          for (var k = 0; k < text.boxes.length; k++) {
            final (tl, tr) = text.boxes[k];
            final (al, ar) = drawn.boxes[k];
            expect(al, closeTo(tl, 1.5), reason: '$where token $k left');
            expect(ar, closeTo(tr, 1.5), reason: '$where token $k right');
          }
        }
      }
    }
  });

  test('tajwīd colours single letters; the recited word stays in accent', () {
    final atlas = MushafAtlas.of('uthmani')!;
    final colors = tajwidColorsForDark(false);
    // Find a line on page 50 with tajwīd on some, not all, of a word.
    final lines = MushafRepo.pageSync('uthmani', 50)!;
    var found = false;
    for (var i = 0; i < lines.length && !found; i++) {
      if (!lines[i].isText) continue;
      final on = buildAtlasLine(
        _spec('uthmani', 50, i, tajwid: colors),
        atlas,
        0,
      );
      final off = buildAtlasLine(_spec('uthmani', 50, i), atlas, 0);
      for (var k = 0; k < on.glyphColors.length; k++) {
        final g = on.glyphColors[k];
        final ruled = g.where((c) => c != _ink).toList();
        if (ruled.isEmpty || ruled.length == g.length) continue;
        found = true;
        expect(ruled.every(colors.contains), isTrue);
        expect(off.glyphColors[k].every((c) => c == _ink), isTrue);
        // Recited: the whole word in the accent colour, no tajwīd.
        final w = lines[i].words[k];
        if (w.isMarker) continue;
        final playing = buildAtlasLine(
          _spec(
            'uthmani',
            50,
            i,
            tajwid: colors,
            playAyah: w.ayah,
            playWord: w.wordIdx,
          ),
          atlas,
          0,
        );
        expect(playing.glyphColors[k].every((c) => c == _accent), isTrue);
        break;
      }
    }
    expect(found, isTrue, reason: 'no partly-coloured word on page 50');
  });

  test('a large page draws from the larger glyphs', () {
    final atlas = MushafAtlas.of('uthmani')!;
    expect(atlas.tierFor(50), 0);
    expect(atlas.tierFor(140), atlas.tiers.length - 1);
  });

  testWidgets('without the atlas the line is shaped as text', (tester) async {
    MushafAtlas.debugDisabled = true;
    addTearDown(() => MushafAtlas.debugDisabled = false);
    tester.view.physicalSize = const Size(420, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MushafLineView(
            handlers: MushafTapHandlers(),
            spec: _spec('uthmani', 50, 3),
          ),
        ),
      ),
    );
    final r = tester.renderObject<RenderMushafLine>(
      find.byType(MushafLineView),
    );
    expect(r.laidLine, isA<LaidLine>());
    MushafLineScheduler.reset(); // the text path's background shaping
  });

  test('the phone spread\'s compact page chrome leaves more room', () {
    const avail = Size(380, 380);
    Size box(bool compact) => MushafGeometry.pageBox(
      avail,
      'uthmani',
      look: MushafLook.framed,
      header: true,
      page: 50,
      compact: compact,
    );
    expect(box(true).width, greaterThan(box(false).width));
  });
}
