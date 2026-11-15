import 'package:flutter/material.dart';

import 'adaptive_sheet.dart';

/// A screen over the muṣḥaf, never in its place: a sheet from below on a
/// phone, a panel at the side on a wide window — so the page is always just
/// under it, and Esc, a tap outside or its back arrow close it. [wide] for a
/// screen with a lot to show (statistics, mutashābihāt): on a desktop it
/// takes most of the window, not a phone's width.
Future<T?> showOverlayScreen<T>(
  BuildContext context,
  Widget child, {
  bool wide = false,
}) {
  final w = MediaQuery.sizeOf(context).width;
  return showAdaptiveSheet<T>(
    context,
    useRootNavigator: true,
    sideWidth: wide ? (w * .62).clamp(440.0, 960.0) : 480,
    sideFraction: wide ? .62 : .45,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: AdaptiveSheet.isSide(sheet) ? 1 : .92,
      child: child,
    ),
  );
}
