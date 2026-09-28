import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';

/// The desktop kids shell's own "push" — unlike mobile, where a lesson or
/// practice screen is a normal full-screen [Navigator] push (hiding the
/// bottom nav, exactly like the design intends), the desktop design keeps
/// the 248px sidebar on screen even while a lesson is open, with only the
/// top bar swapping to its "lesson" variant. That means a full-pane kids
/// destination can't be a routed push on desktop — it has to be content the
/// shell itself swaps in, so the sidebar never disappears.
///
/// [KidsDesktopShell] publishes one of these over its whole subtree.
/// [pushKidsOverlay] is what every kids screen calls instead of
/// `Navigator.push` for a full-pane destination (a letter's lesson,
/// Flashcards, Listening): on desktop it hands off to the shell; on mobile,
/// where no [KidsDesktopOverlay] exists, it falls back to an ordinary push,
/// unchanged from before this shell existed.
class KidsDesktopOverlay extends InheritedWidget {
  final void Function(String title, WidgetBuilder builder) open;
  final VoidCallback close;
  const KidsDesktopOverlay({
    super.key,
    required this.open,
    required this.close,
    required super.child,
  });

  static KidsDesktopOverlay? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KidsDesktopOverlay>();

  @override
  bool updateShouldNotify(KidsDesktopOverlay oldWidget) => false;
}

/// Opens a full-pane kids destination: in the shell's content pane on
/// desktop, or as a normal pushed route on mobile.
void pushKidsOverlay(BuildContext context,
    {required String title, required WidgetBuilder builder}) {
  final overlay = KidsDesktopOverlay.maybeOf(context);
  if (overlay != null) {
    overlay.open(title, builder);
    return;
  }
  // The pushed route is a child of the ROOT Navigator, which sits ABOVE both
  // the child profile's ProgressScope (KidsProfileGate) and the kids Theme
  // (KidsShell) — those live inside RootScreen. Without re-providing them
  // here, a lesson resolves `ProgressScope.of` to the GROWN-UP store at
  // main.dart:38 and reports its stars, XP, gems and badges there, while the
  // Learn tab reads the child's store and sees nothing. That is what left the
  // letter path stuck on Alif forever, and it painted pushed kids screens in
  // the adult ThemeData besides. Desktop never hit it: its overlay keeps the
  // destination in-tree.
  final progress = ProgressScope.of(context); // unreachable from the route
  Navigator.push(
    context,
    MaterialPageRoute(
      // kidsTheme is rebuilt from the route's own context rather than captured
      // here, so changing the appearance mid-lesson still recolours it —
      // SettingsScope is above the root Navigator, so it resolves fine.
      builder: (routeContext) => PaletteScope(
        palette: kidsPal(routeContext),
        child: Theme(
          data: kidsTheme(routeContext),
          child: ProgressScope(
            progress: progress,
            // The Kids text size, for every screen pushed from Kids Mode —
            // the tabs get it from the shell, which this route sits above.
            child: KidsTextScale(child: Builder(builder: builder)),
          ),
        ),
      ),
    ),
  );
}

/// Leaves a full-pane kids destination: closes the desktop overlay, or pops
/// the pushed route on mobile. Every kids lesson/practice screen's "done" or
/// "back" action should call this instead of `Navigator.pop` directly.
void closeKidsOverlayOrPop(BuildContext context) {
  final overlay = KidsDesktopOverlay.maybeOf(context);
  if (overlay != null) {
    overlay.close();
    return;
  }
  Navigator.pop(context);
}
