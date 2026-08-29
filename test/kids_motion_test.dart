import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// Kids Mode's repeating animations — the mascot's float/breath and the
/// celebration's continuously falling shapes — and their reduce-motion path.
///
/// The reduce-motion checks are load-bearing for the whole suite, not a
/// nicety: a repeating [AnimationController] never lets `pumpAndSettle()`
/// return, so if these widgets ever stop honouring the flag, every kids
/// widget test hangs until it times out.
Future<AppSettings> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  await s.load();
  s.kidsMode = true;
  return s;
}

Widget _harness(AppSettings settings, Widget child) => SettingsScope(
      settings: settings,
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the mascot is drawn, not an emoji', (tester) async {
    useReducedMotion(tester);
    final settings = await _settings();
    await tester.pumpWidget(_harness(settings, const KidsMascot()));
    await tester.pumpAndSettle();

    // It used to be a Text('🦉'). It is a painted character now, so nothing
    // in the tree renders a glyph for it.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('🦉'), findsNothing);
  });

  testWidgets('the mascot and the falling shapes keep animating', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(_harness(
      settings,
      const SizedBox(
        width: 300,
        height: 400,
        child: Stack(children: [
          Center(child: KidsMascot()),
          Positioned.fill(child: KidsConfetti()),
        ]),
      ),
    ));
    await tester.pump();
    // Both controllers repeat, so there is always a frame pending — this is
    // what makes the celebration read as ambient rather than as a one-shot
    // burst that has already finished by the time the screen is looked at.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // Long past the old 2200ms one-shot duration, pieces are still falling.
    await tester.pump(const Duration(seconds: 6));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('reduce motion holds both of them on a still frame',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _settings();
    await tester.pumpWidget(_harness(
      settings,
      const SizedBox(
        width: 300,
        height: 400,
        child: Stack(children: [
          Center(child: KidsMascot()),
          Positioned.fill(child: KidsConfetti()),
        ]),
      ),
    ));

    // Settles at all, which a repeating controller would never allow...
    await tester.pumpAndSettle();
    // ...and leaves nothing scheduled.
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(KidsConfetti), findsOneWidget);
  });
}
