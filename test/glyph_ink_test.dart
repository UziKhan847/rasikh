import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/glyph_ink.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';

/// Regression guard for the letter card that showed a wide gap above some
/// letters (e.g. Jīm) and crowded others against the bottom of their card —
/// `FittedBox` was centring the font's line box, not the glyph's own ink.
/// See `_GlyphHero` in `screens/kids/kids_letter_flow.dart`.
void main() {
  test('every taught letter has a measured ink entry', () {
    for (final l in kidsLetterPath) {
      final ink = kUthmanicInk[l.char];
      expect(ink, isNotNull, reason: '${l.char} (${l.name}) has no entry');
      final (top, bottom) = ink!;
      expect(top, greaterThan(bottom), reason: l.char);
      // Sanity bounds a real letter-only glyph should sit within — nothing
      // here is a full word, so nowhere near the font's full ascent/descent.
      expect(top, inInclusiveRange(0, 1), reason: l.char);
      expect(bottom, inInclusiveRange(-1, 0.1), reason: l.char);
    }
  });

  test('glyphInkFontSize fills the box height with the ink span, not the '
      'line box', () {
    // jīm's own measured span: 0.7876em of ink.
    const top = 0.3442, bottom = -0.4434;
    final fontSize = glyphInkFontSize(200, top, bottom);
    expect(fontSize * (top - bottom), closeTo(200, 1e-9));
  });

  test('glyphInkOffset centres the ink span, not the line box', () {
    // Hand-computed: size 200x200, top=0.6, bottom=-0.2 (inkEm 0.8),
    // fontSize = 200/0.8 = 250. A line box 150 wide, baseline 200 down from
    // its own top (both arbitrary stand-ins for real TextPainter output —
    // this test is only checking the offset arithmetic, not font metrics).
    final offset = glyphInkOffset(
      size: const Size(200, 200),
      fontSize: 250,
      top: 0.6,
      bottom: -0.2,
      lineWidth: 150,
      baseline: 200,
    );
    expect(offset.dx, closeTo(25, 1e-9));
    expect(offset.dy, closeTo(-50, 1e-9));

    // Forward-check from the other direction: painting a line box at this
    // offset, with this baseline, puts the ink's own vertical centre at
    // exactly the box's vertical centre — the actual property that matters,
    // computed independently of the formula under test.
    final baselineY = offset.dy + 200;
    final inkTopY = baselineY - 0.6 * 250;
    final inkBottomY = baselineY - (-0.2) * 250;
    expect((inkTopY + inkBottomY) / 2, closeTo(100, 1e-9));
  });

  test('a symmetric glyph (top == -bottom) needs no vertical offset from '
      'the naive line-box centring', () {
    final offset = glyphInkOffset(
      size: const Size(100, 100),
      fontSize: 100,
      top: 0.4,
      bottom: -0.4,
      lineWidth: 80,
      baseline: 50,
    );
    // (top + bottom) / 2 == 0, so dy reduces to size.height/2 - baseline —
    // exactly what plain line-box centring would already have done.
    expect(offset.dy, closeTo(100 / 2 - 50, 1e-9));
  });
}
