import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Whether sheets come in from the side here: a window wider than tall and
/// at least 600 wide (a phone on its side, a tablet, a desktop). A bottom
/// sheet there would cover the pages from below and leave a strip of them
/// above; a panel at the side leaves them in view.
bool sheetFromSide(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width > s.height && s.width >= 600;
}

/// A sheet that is a bottom sheet in portrait and a panel sliding in from
/// the right in landscape ([sheetFromSide]), its outer corners rounded
/// (the top ones from below, the left ones from the side). Its content can
/// ask [AdaptiveSheet.isSide] to lay itself out for either. With
/// [waitForExit] the result arrives once the sheet has gone (so whatever
/// it leads to — a jump to a page — doesn't build under its closing).
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  double sideWidth = 440,
  bool useRootNavigator = false,
  bool waitForExit = false,
}) async {
  final nav = Navigator.of(context, rootNavigator: useRootNavigator);
  final side = sheetFromSide(context);
  final label = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final themes = InheritedTheme.capture(from: context, to: nav.context);
  final TransitionRoute<T> route;
  if (!side) {
    route = ModalBottomSheetRoute<T>(
      builder: (c) => AdaptiveSheet._(side: false, child: Builder(builder: builder)),
      capturedThemes: themes,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      barrierLabel: label,
      modalBarrierColor: Colors.black.withValues(alpha: .32),
    );
  } else {
    route = RawDialogRoute<T>(
      barrierDismissible: true,
      barrierLabel: label,
      barrierColor: Colors.black.withValues(alpha: .24),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (c, _, _) {
        final size = MediaQuery.sizeOf(c);
        final w = (size.width * .45).clamp(360.0, sideWidth);
        return themes.wrap(Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            width: w,
            height: size.height,
            child: Material(
              color: pal(c).bg,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadiusDirectional.horizontal(
                        start: Radius.circular(24))
                    .resolve(Directionality.of(c)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                left: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AdaptiveSheet._(side: true, child: Builder(builder: builder)),
                ),
              ),
            ),
          ),
        ));
      },
      transitionBuilder: (c, a, _, child) {
        final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        final rtl = Directionality.of(c) == TextDirection.rtl;
        return SlideTransition(
          position: Tween(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero)
              .animate(curve),
          child: child,
        );
      },
    );
  }
  final result = await nav.push(route);
  if (waitForExit) await route.completed;
  return result;
}

/// Tells a sheet's content which way it came in.
class AdaptiveSheet extends InheritedWidget {
  final bool side;
  const AdaptiveSheet._({required this.side, required super.child});

  /// True in a side panel (full height); false in a bottom sheet or
  /// outside any adaptive sheet.
  static bool isSide(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveSheet>()?.side ?? false;

  @override
  bool updateShouldNotify(AdaptiveSheet old) => old.side != side;
}
