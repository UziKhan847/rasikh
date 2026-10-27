import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/screens/reader/ayah_text.dart';
import 'package:qiraah_arabiyyah/ui/mark_style.dart';

/// The reader's āyah paragraph: the recited word moving on, or a mark
/// added, repaints it; only new text shapes it again.
void main() {
  Widget ayah({int play = -1, List<MarkVisual?> marks = const [null, null, null], String key = 'a'}) =>
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 300,
            child: AyahText(
              words: const [TextSpan(text: 'بسم'), TextSpan(text: 'الله'), TextSpan(text: 'الرحمن')],
              textKey: key,
              playWord: play,
              highlight: const Color(0x3300AA00),
              marks: marks,
              markPal: markPaletteFor(paletteOf(AppTheme.light)),
              onTap: (_) {},
              onLongPress: (_) {},
            ),
          ),
        ),
      );

  testWidgets('a tick and a mark repaint; new text reshapes', (tester) async {
    await tester.pumpWidget(ayah());
    final before = RenderAyahText.debugLayouts;
    await tester.pumpWidget(ayah(play: 1));
    await tester.pumpWidget(ayah(play: 2));
    await tester.pumpWidget(ayah(play: 2, marks: const [null, MarkVisual(open: MarkType.mistake), null]));
    expect(RenderAyahText.debugLayouts, before, reason: 'reshaped on a tick or a mark');
    await tester.pumpWidget(ayah(key: 'b'));
    expect(RenderAyahText.debugLayouts, before + 1);
  });

  testWidgets('a tap lands on its word', (tester) async {
    int? tapped;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SizedBox(
          width: 300,
          child: AyahText(
            words: const [TextSpan(text: 'بسم'), TextSpan(text: 'الله'), TextSpan(text: 'الرحمن')],
            textKey: 'a',
            playWord: -1,
            highlight: const Color(0x3300AA00),
            marks: const [null, null, null],
            markPal: null,
            onTap: (w) => tapped = w,
            onLongPress: (_) {},
          ),
        ),
      ),
    ));
    final r = tester.renderObject<RenderAyahText>(find.byType(AyahText));
    await tester.tapAt(r.localToGlobal(r.wordCenter(2)!));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tapped, 2);
  });
}
