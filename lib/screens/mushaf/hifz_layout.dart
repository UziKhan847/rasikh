import 'package:flutter/widgets.dart';

/// Where the Hifẓ home puts things — fixed by the window alone, never by
/// which tool is on: turning a tool on swaps what a slot holds, it doesn't
/// move or resize the pages (which would lay every line out again).
///
/// Portrait: the line above the page, the page, the dock along the bottom;
/// a tool's own bar takes the dock's place. Landscape: two facing pages
/// (each with its margin rail), the dock down the right edge, and a slot
/// for a tool's bar — beside the dock when the pages leave room at the
/// side (they're bound by the height, so mostly they do), else under the
/// pages, reserved either way.
@immutable
class HifzLayout {
  final bool landscape;

  /// The pages' area (a spread: rails and gap included).
  final Rect pager;

  /// Portrait: the line above the page; landscape: none.
  final Rect? header;

  /// The toolbar.
  final Rect dock;

  /// A tool's own bar: [dock] itself in portrait.
  final Rect slot;
  final Axis slotAxis;

  /// Landscape: the gap between the pages (its centre line in the middle)
  /// and each page's margin rail.
  final double gap, rail;

  const HifzLayout._({
    required this.landscape,
    required this.pager,
    required this.header,
    required this.dock,
    required this.slot,
    required this.slotAxis,
    this.gap = 0,
    this.rail = 0,
  });

  /// The dock's thickness (and a portrait tool bar's height), past the
  /// window's own insets.
  static const dockExtent = 64.0;
  static const headerExtent = 40.0;

  /// A side slot narrower than this isn't worth it: the bar goes under.
  static const minSideSlot = 128.0;
  static const maxSideSlot = 248.0;

  /// [size] with the system's [padding]; [pageBox] sizes one page to fit an
  /// area (its shape decides the width).
  static HifzLayout resolve(Size size, EdgeInsets padding,
      {required Size Function(Size avail) pageBox}) {
    final w = size.width, h = size.height;
    if (w <= h) {
      final header = Rect.fromLTWH(0, padding.top, w, headerExtent);
      final dockH = dockExtent + padding.bottom;
      final dock = Rect.fromLTWH(0, h - dockH, w, dockH);
      return HifzLayout._(
        landscape: false,
        header: header,
        pager: Rect.fromLTRB(0, header.bottom, w, dock.top),
        dock: dock,
        slot: dock,
        slotAxis: Axis.horizontal,
      );
    }
    final dockW = dockExtent + padding.right;
    final dock = Rect.fromLTWH(w - dockW, 0, dockW, h);
    final body = Rect.fromLTRB(
        padding.left + 4, padding.top + 6, dock.left - 4, h - padding.bottom - 6);
    final rail = (body.height * .05).clamp(26.0, 40.0);
    final gap = (body.width * .012).clamp(12.0, 24.0);
    double spreadW(double height) {
      final page = pageBox(
          Size((body.width - 2 * rail - gap) / 2, height));
      return 2 * page.width + gap + 2 * rail;
    }

    final spare = body.width - spreadW(body.height);
    if (spare >= minSideSlot) {
      final slotW = (spare - 8).clamp(minSideSlot, maxSideSlot);
      final slot = Rect.fromLTWH(body.right - slotW, body.top, slotW, body.height);
      return HifzLayout._(
        landscape: true,
        header: null,
        pager: Rect.fromLTRB(body.left, body.top, slot.left - 4, body.bottom),
        dock: dock,
        slot: slot,
        slotAxis: Axis.vertical,
        gap: gap,
        rail: rail,
      );
    }
    const slotH = dockExtent;
    final slot = Rect.fromLTWH(body.left, body.bottom - slotH, body.width, slotH);
    return HifzLayout._(
      landscape: true,
      header: null,
      pager: Rect.fromLTRB(body.left, body.top, body.right, slot.top - 4),
      dock: dock,
      slot: slot,
      slotAxis: Axis.horizontal,
      gap: gap,
      rail: rail,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HifzLayout &&
      other.landscape == landscape &&
      other.pager == pager &&
      other.header == header &&
      other.dock == dock &&
      other.slot == slot &&
      other.slotAxis == slotAxis &&
      other.gap == gap &&
      other.rail == rail;

  @override
  int get hashCode =>
      Object.hash(landscape, pager, header, dock, slot, slotAxis, gap, rail);
}
