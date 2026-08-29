import 'package:flutter_test/flutter_test.dart';

/// Kids Mode runs several *repeating* animations — the mascot's float, the
/// celebration's falling shapes, the pulse on the letter the child is up to.
/// A repeating [AnimationController] never lets `pumpAndSettle()` return (the
/// same trap `kids_shell_navigation_test.dart` already documents about
/// `TracingBoard`'s pulse), so a widget test that renders any of them hangs
/// until it times out.
///
/// Every one of them honours the OS reduce-motion flag via `kidsReduceMotion`,
/// so switching it on is both the honest way to make these tests settle and a
/// standing check that the accessibility path actually works — rather than a
/// test-only escape hatch bolted onto the widgets.
void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
