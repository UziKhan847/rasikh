import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/screens/mushaf/trackpad_pager.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester) async {
    final turns = <int>[];
    await tester.pumpWidget(TrackpadPager(
      onTurn: turns.add,
      child: const SizedBox.expand(),
    ));
    return turns;
  }

  Future<void> swipe(WidgetTester tester, Offset by) async {
    final g = TestPointer(1, PointerDeviceKind.trackpad);
    const at = Offset(200, 200);
    await tester.sendEventToBinding(g.panZoomStart(at));
    for (var i = 1; i <= 5; i++) {
      await tester.sendEventToBinding(g.panZoomUpdate(at, pan: by * (i / 5)));
    }
    await tester.sendEventToBinding(g.panZoomEnd());
  }

  testWidgets('a two-finger swipe turns once: right forward, left back',
      (tester) async {
    final turns = await pump(tester);
    await swipe(tester, const Offset(200, 10));
    expect(turns, [1], reason: 'one turn however far the swipe goes');
    await swipe(tester, const Offset(-200, 0));
    expect(turns, [1, -1]);
  });

  testWidgets('short or mostly vertical swipes leave the page', (tester) async {
    final turns = await pump(tester);
    await swipe(tester, const Offset(30, 0));
    await swipe(tester, const Offset(80, 200));
    expect(turns, isEmpty);
  });

  testWidgets('sideways scrolling turns once per burst', (tester) async {
    final turns = await pump(tester);
    final p = TestPointer(2, PointerDeviceKind.mouse)
      ..hover(const Offset(200, 200));
    for (var i = 0; i < 10; i++) {
      await tester.sendEventToBinding(
          p.scroll(const Offset(-30, 0)));
    }
    expect(turns, [1]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendEventToBinding(p.scroll(const Offset(90, 0)));
    expect(turns, [1, -1]);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('a finger swiping across turns (a tablet); a mouse drag '
      'does not', (tester) async {
    final turns = await pump(tester);
    await tester.dragFrom(const Offset(100, 200), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(turns, [1], reason: 'rightward: forward');
    await tester.flingFrom(const Offset(300, 200), const Offset(-60, 0), 1200);
    await tester.pumpAndSettle();
    expect(turns, [1, -1], reason: 'a quick flick back');
    await tester.dragFrom(const Offset(100, 200), const Offset(200, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(turns, [1, -1]);
  });
}
