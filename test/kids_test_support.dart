import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;
import 'package:qiraah_arabiyyah/screens/kids/kids_sort_bins.dart';

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

/// Drags the middle of [from] onto the middle of [to] the way a finger does:
/// down, a first move past the touch slop toward the target (a drag only
/// begins once the pointer has moved that far), then across, then up. A single
/// jump would land the gesture on the drop target without the hover a real
/// drag has.
Future<void> dragOnto(WidgetTester tester, Finder from, Finder to) async {
  final start = tester.getCenter(from);
  final end = tester.getCenter(to);
  final g = await tester.startGesture(start);
  final dir = (end - start);
  final nudge = dir.distance == 0 ? const Offset(30, 0) : dir / dir.distance * 30;
  await g.moveBy(nudge);
  await tester.pump();
  await g.moveTo(end);
  await tester.pump();
  await g.up();
  await tester.pump();
}

/// True while a sort-into-bins card is on screen.
bool sortCardShowing() => find.byType(KidsSortBins).evaluate().isNotEmpty;

/// Finishes a [KidsSortBins] card by TAPPING alone — the walkers' way through
/// it, and the proof that the activity never needs a drag: pick each tile up
/// and put it in the first bin, and if it comes straight back put it in the
/// second. Ends with a pause long enough for the card to report itself done.
Future<void> finishSortByTap(WidgetTester tester, {int bins = 2}) async {
  final tiles = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('sortItem.');
  });
  for (var guard = 0; guard < 60 && tiles.evaluate().isNotEmpty; guard++) {
    final key = tiles.evaluate().first.widget.key! as ValueKey<String>;
    for (var bin = 0; bin < bins; bin++) {
      final tile = find.byKey(key);
      if (tile.evaluate().isEmpty) break;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump();
      final target = find.byKey(ValueKey('sortBin.$bin'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 600));
    }
  }
  await tester.pump(const Duration(milliseconds: 800));
}

/// A tab in the phone shell's bottom bar, by its (English) label.
Finder kidsTab(String label) =>
    find.descendant(of: find.byType(KbNavBar), matching: find.text(label));

/// The [i]th tab in the phone shell's bottom bar (0 = Home … 4 = Me), for a
/// test running in a language whose labels it does not know.
Finder kidsTabAt(int i) => find
    .descendant(of: find.byType(KbNavBar), matching: find.byType(GestureDetector))
    .at(i);

/// The answer tiles a child can tap right now: the kit's answer cells
/// (`KbGlyphCell` with a tap handler — a tried or resolved one has none) and,
/// on a screen not yet on the kit, the old `TapScale` tiles. In build order,
/// so `.first`/`.at(i)` walk the options as laid out.
Finder kidsTappables() => find.byWidgetPredicate(
    (w) => w is TapScale || (w is KbGlyphCell && w.onTap != null));

/// A Listen button's speaker: the kit's `volume_up` symbol or, on a screen
/// not yet on the kit, the old Material icon.
Finder kidsListenIcon() => find.byWidgetPredicate((w) =>
    (w is KbIcon && w.name == 'volume_up') ||
    (w is Icon && w.icon == Icons.volume_up_rounded));

/// An icon by what it shows: the kit's Material Symbol [name] (`KbIcon`) or,
/// on a screen not yet on the kit, the old Material [legacy] icon.
Finder kidsIcon(String name, [IconData? legacy]) => find.byWidgetPredicate(
    (w) => (w is KbIcon && w.name == name) || (legacy != null && w is Icon && w.icon == legacy));
