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

  /// The pages' area: in landscape the whole width between the screen's
  /// edge and the dock, so a swipe anywhere turns the page and a page slides
  /// all the way out; [pagesInset] keeps the spread clear of the slot.
  final Rect pager;
  final EdgeInsets pagesInset;

  /// Landscape: the dock on the left (the phone held with its camera on
  /// the right), not the right.
  final bool dockLeft;

  /// A line above the pages (none: each page carries its own).
  final Rect? header;

  /// The toolbar.
  final Rect dock;

  /// A tool's own bar: [dock] itself in portrait.
  final Rect slot;
  final Axis slotAxis;

  /// Landscape: the gap between the pages (its centre line in the middle)
  /// and each page's margin rail.
  final double gap, rail;

  /// Landscape: how many pages show — 'two' facing, 'one' as wide as the
  /// two with their rails (the bars keep their slot beside it), or 'wide'
  /// the whole width to the dock (the bars float over its foot; it scrolls
  /// far enough to show all of it).
  final String pages;

  /// Landscape: the facing pages' width with their rails; one page in
  /// 'one' takes as much.
  final double spreadWidth;

  const HifzLayout._({
    required this.landscape,
    required this.pager,
    required this.header,
    required this.dock,
    required this.slot,
    required this.slotAxis,
    this.pagesInset = EdgeInsets.zero,
    this.dockLeft = false,
    this.gap = 0,
    this.rail = 0,
    this.pages = 'two',
    this.spreadWidth = 0,
  });

  /// The dock's thickness (and a portrait tool bar's height), past the
  /// window's own insets.
  static const dockExtent = 64.0;
  static const headerExtent = 40.0;

  /// A side slot narrower than this isn't worth it: the bar goes under.
  static const minSideSlot = 104.0;
  static const maxSideSlot = 248.0;

  /// [size] with the system's [padding]; [pageBox] sizes one page to fit an
  /// area (its shape decides the width).
  static HifzLayout resolve(Size size, EdgeInsets padding,
      {required Size Function(Size avail) pageBox,
      bool dockLeft = false,
      String pages = 'two',
      String align = 'auto'}) {
    final w = size.width, h = size.height;
    if (w <= h) {
      // The line above the page goes with each page (see the pager).
      final dockH = dockExtent + padding.bottom;
      final dock = Rect.fromLTWH(0, h - dockH, w, dockH);
      return HifzLayout._(
        landscape: false,
        header: null,
        pager: Rect.fromLTRB(0, padding.top, w, dock.top),
        dock: dock,
        slot: dock,
        slotAxis: Axis.horizontal,
      );
    }
    // Worked out with the dock on the right, then mirrored if it's left.
    final pad = dockLeft
        ? EdgeInsets.fromLTRB(padding.right, padding.top, padding.left, padding.bottom)
        : padding;
    final dockW = dockExtent + pad.right;
    final dock = Rect.fromLTWH(w - dockW, 0, dockW, h);
    final body = Rect.fromLTRB(
        pad.left + 4, pad.top + 6, dock.left - 4, h - pad.bottom - 6);
    // Each page's margin rail: its labels and lantern, and room to breathe
    // between them and the page.
    final rail = (body.height * .07).clamp(36.0, 50.0);
    final gap = (body.width * .012).clamp(12.0, 24.0);
    double spreadW(double height) {
      final page = pageBox(
          Size((body.width - 2 * rail - gap) / 2, height));
      return 2 * page.width + gap + 2 * rail;
    }

    final spread = spreadW(body.height);
    final spare = body.width - spread;
    Rect flip(Rect r) => dockLeft ? Rect.fromLTRB(w - r.right, r.top, w - r.left, r.bottom) : r;
    EdgeInsets flipInset(EdgeInsets e) =>
        dockLeft ? EdgeInsets.fromLTRB(e.right, e.top, e.left, e.bottom) : e;
    // Where the pages stand, worked out with the dock on the right: the side
    // slot (a mode's bar) takes the room on their other side.
    // ('auto': away from the dock.)
    final side = align == 'auto' || !dockLeft
        ? (align == 'auto' ? 'left' : align)
        : switch (align) { 'left' => 'right', 'right' => 'left', _ => align };
    final centred = side == 'center';
    final room = centred ? spare / 2 : spare;
    if (pages != 'wide' && room >= minSideSlot) {
      final slotW = (room - 8).clamp(minSideSlot, maxSideSlot);
      final slot = side == 'right'
          ? Rect.fromLTWH(body.left, body.top, slotW, body.height)
          : Rect.fromLTWH(body.right - slotW, body.top, slotW, body.height);
      return HifzLayout._(
        landscape: true,
        header: null,
        pager: flip(body),
        pagesInset: flipInset(switch (side) {
          'center' => EdgeInsets.zero,
          'right' => EdgeInsets.only(left: slotW + 4),
          _ => EdgeInsets.only(right: slotW + 4),
        }),
        dock: flip(dock),
        slot: flip(slot),
        slotAxis: Axis.vertical,
        dockLeft: dockLeft,
        gap: gap,
        rail: rail,
        pages: pages,
        spreadWidth: spread,
      );
    }
    const slotH = dockExtent;
    final slot = Rect.fromLTWH(body.left, body.bottom - slotH, body.width, slotH);
    return HifzLayout._(
      landscape: true,
      header: null,
      pager: flip(body),
      // The whole width: the bar floats over the page, which scrolls.
      pagesInset: pages == 'wide' ? EdgeInsets.zero : const EdgeInsets.only(bottom: slotH + 4),
      dock: flip(dock),
      slot: flip(slot),
      slotAxis: Axis.horizontal,
      dockLeft: dockLeft,
      gap: gap,
      rail: rail,
      pages: pages,
      spreadWidth: spread,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HifzLayout &&
      other.landscape == landscape &&
      other.pager == pager &&
      other.pagesInset == pagesInset &&
      other.dockLeft == dockLeft &&
      other.header == header &&
      other.dock == dock &&
      other.slot == slot &&
      other.slotAxis == slotAxis &&
      other.gap == gap &&
      other.rail == rail &&
      other.pages == pages &&
      other.spreadWidth == spreadWidth;

  @override
  int get hashCode =>
      Object.hash(landscape, pager, pagesInset, dockLeft, header, dock, slot,
          slotAxis, gap, rail, pages, spreadWidth);
}
