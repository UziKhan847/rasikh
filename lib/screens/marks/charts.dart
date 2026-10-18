import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_stats.dart';
import '../../core/theme.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// Colour of a stats bucket (see [statBuckets]).
Color bucketColor(MarkPalette pal, int bucket) {
  final t = statBuckets[bucket];
  return t == null ? pal.fixed : pal.colorOf(t);
}

String bucketLabel(BuildContext context, int bucket) {
  final t = statBuckets[bucket];
  return t == null ? context.l10n.mkFixed : markTypeLabel(context, t);
}

/// "Mistake 3 · Doubt 1 · Fixed 2" — the tooltip / screen-reader text of a bar.
String bucketBreakdown(BuildContext context, List<int> values) => [
      for (var b = 0; b < values.length; b++)
        if (values[b] > 0) '${bucketLabel(context, b)} ${values[b]}'
    ].join(' · ');

/// One horizontal stacked bar: segments in bucket order, 2px gaps between
/// them, rounded ends, length relative to [max].
class StackedBar extends StatelessWidget {
  final List<int> values;
  final int max;
  final MarkPalette mp;
  final double height;
  const StackedBar(
      {super.key,
      required this.values,
      required this.max,
      required this.mp,
      this.height = 12});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final total = values.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        final w = max == 0 ? 0.0 : c.maxWidth * total / max;
        final segs = [
          for (var b = 0; b < values.length; b++)
            if (values[b] > 0) b
        ];
        return Stack(children: [
          Container(
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          SizedBox(
            width: w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(children: [
                for (var i = 0; i < segs.length; i++) ...[
                  if (i > 0) Container(width: 2, color: p.card),
                  Expanded(
                    flex: values[segs[i]],
                    child: Container(color: bucketColor(mp, segs[i])),
                  ),
                ],
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Labelled stacked-bar rows (by sūrah, by juzʼ…). Rows are tappable.
class BarRows extends StatelessWidget {
  final List<(String label, List<int> values)> rows;
  final MarkPalette mp;
  final void Function(int index)? onTap;
  const BarRows(
      {super.key, required this.rows, required this.mp, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final max = rows.fold<int>(
        0, (m, r) => math.max(m, r.$2.fold<int>(0, (a, b) => a + b)));
    return Column(children: [
      for (var i = 0; i < rows.length; i++)
        Tooltip(
          message: bucketBreakdown(context, rows[i].$2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: Text(rows[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w600, color: p.ink2)),
                ),
                Expanded(
                    child: StackedBar(
                        values: rows[i].$2, max: max, mp: mp, height: 10)),
                SizedBox(
                  width: 36,
                  child: Text('${rows[i].$2.fold<int>(0, (a, b) => a + b)}',
                      textAlign: TextAlign.end,
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w700, color: p.ink)),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Every page of the muṣḥaf as a cell, shaded by its number of marks (one
/// hue, light → dark). Hover or long-press shows the page and count; a tap
/// opens it.
class PageHeatmap extends StatefulWidget {
  final List<int> counts;
  final void Function(int page) onOpen;
  const PageHeatmap({super.key, required this.counts, required this.onOpen});

  @override
  State<PageHeatmap> createState() => _PageHeatmapState();
}

class _PageHeatmapState extends State<PageHeatmap> {
  int? _hover;
  static const _gap = 2.0;

  /// Columns for a width: cells stay roughly 14–28px.
  static int colsFor(double w) => w < 600 ? 20 : (w < 900 ? 30 : 40);

  int? _pageAt(Offset o, Size size) {
    final cols = colsFor(size.width);
    final cell = (size.width - _gap * (cols - 1)) / cols;
    final col = (o.dx / (cell + _gap)).floor();
    final row = (o.dy / (cell + _gap)).floor();
    if (col < 0 || col >= cols || row < 0) return null;
    // Pages run right to left, like the book.
    final i = row * cols + (cols - 1 - col);
    return i < widget.counts.length ? i + 1 : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final n = widget.counts.length;
    final max = widget.counts.fold<int>(0, math.max);
    final h = _hover;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 20,
        child: Text(
          h == null
              ? context.l10n.mkTapPageHint
              : '${context.l10n.mkPageN(h)} · ${widget.counts[h - 1]}',
          style: uiStyle(context,
              size: 12.5,
              weight: h == null ? FontWeight.w500 : FontWeight.w700,
              color: h == null ? p.ink3 : p.ink),
        ),
      ),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (context, c) {
        final cols = colsFor(c.maxWidth);
        final cell = (c.maxWidth - _gap * (cols - 1)) / cols;
        final rows = (n / cols).ceil();
        final size = Size(c.maxWidth, rows * (cell + _gap) - _gap);
        return MouseRegion(
          onHover: (e) => setState(() => _hover = _pageAt(e.localPosition, size)),
          onExit: (_) => setState(() => _hover = null),
          child: GestureDetector(
            onTapUp: (d) {
              final pg = _pageAt(d.localPosition, size);
              if (pg != null) widget.onOpen(pg);
            },
            onLongPressStart: (d) =>
                setState(() => _hover = _pageAt(d.localPosition, size)),
            child: CustomPaint(
              size: size,
              painter: _HeatPainter(
                  counts: widget.counts,
                  max: max,
                  empty: p.track,
                  hot: p.acc,
                  ring: p.ink,
                  hover: h),
            ),
          ),
        );
      }),
    ]);
  }
}

class _HeatPainter extends CustomPainter {
  final List<int> counts;
  final int max;
  final Color empty, hot, ring;
  final int? hover;
  _HeatPainter(
      {required this.counts,
      required this.max,
      required this.empty,
      required this.hot,
      required this.ring,
      required this.hover});

  @override
  void paint(Canvas canvas, Size size) {
    final cols = _PageHeatmapState.colsFor(size.width);
    const gap = _PageHeatmapState._gap;
    final cell = (size.width - gap * (cols - 1)) / cols;
    for (var i = 0; i < counts.length; i++) {
      final row = i ~/ cols, col = cols - 1 - i % cols;
      final r = Rect.fromLTWH(
          col * (cell + gap), row * (cell + gap), cell, cell);
      final c = counts[i];
      // 4 steps of one hue; any mark is clearly off the empty colour.
      final t = c == 0 || max == 0 ? 0.0 : .3 + .7 * math.sqrt(c / max);
      final color = c == 0 ? empty : Color.lerp(empty, hot, t)!;
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(2));
      canvas.drawRRect(rr, Paint()..color = color);
      if (hover == i + 1) {
        canvas.drawRRect(
            rr.inflate(1),
            Paint()
              ..color = ring
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.counts != counts || old.hover != hover || old.hot != hot;
}

/// A single-series line over time (one axis). Hover / touch shows a point's
/// value; first and last dates label the x axis.
class TrendChart extends StatefulWidget {
  /// (x = ms since epoch, y) oldest first.
  final List<(int, int)> points;
  final Color color;
  final double height;
  final bool bars;
  const TrendChart(
      {super.key,
      required this.points,
      required this.color,
      this.height = 140,
      this.bars = false});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _sel;

  int _nearest(double dx, double w) {
    final n = widget.points.length;
    if (n <= 1) return 0;
    return (dx / w * (n - 1)).round().clamp(0, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final pts = widget.points;
    final sel = _sel;
    String date(int ms) => shortDate(context, ms);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 20,
        child: sel == null
            ? null
            : Text('${date(pts[sel].$1)} · ${pts[sel].$2}',
                style: uiStyle(context,
                    size: 12.5, weight: FontWeight.w700, color: p.ink)),
      ),
      LayoutBuilder(builder: (context, c) {
        void at(Offset o) => setState(() => _sel = _nearest(o.dx, c.maxWidth));
        return MouseRegion(
          onHover: (e) => at(e.localPosition),
          onExit: (_) => setState(() => _sel = null),
          child: GestureDetector(
            onTapDown: (d) => at(d.localPosition),
            onHorizontalDragUpdate: (d) => at(d.localPosition),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.height),
              painter: _TrendPainter(
                points: pts,
                color: widget.color,
                grid: p.line2,
                axis: p.ink3,
                surface: p.card,
                sel: sel,
                bars: widget.bars,
                label: uiStyle(context, size: 10.5, color: p.ink3),
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 4),
      if (pts.isNotEmpty)
        Row(children: [
          Text(date(pts.first.$1),
              style: uiStyle(context, size: 11.5, color: p.ink3)),
          const Spacer(),
          if (pts.length > 1)
            Text(date(pts.last.$1),
                style: uiStyle(context, size: 11.5, color: p.ink3)),
        ]),
    ]);
  }
}

class _TrendPainter extends CustomPainter {
  final List<(int, int)> points;
  final Color color, grid, axis, surface;
  final int? sel;
  final bool bars;
  final TextStyle label;
  _TrendPainter(
      {required this.points,
      required this.color,
      required this.grid,
      required this.axis,
      required this.surface,
      required this.sel,
      required this.bars,
      required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxY = math.max(1, points.map((e) => e.$2).reduce(math.max));
    const top = 16.0, bottom = 2.0;
    final h = size.height - top - bottom;
    double y(int v) => top + h - h * v / maxY;
    final n = points.length;
    double x(int i) => n == 1 ? size.width / 2 : size.width * i / (n - 1);

    // Recessive grid: baseline and the max line, with its value.
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), gp);
    canvas.drawLine(Offset(0, y(maxY)), Offset(size.width, y(maxY)), gp);
    final tp = TextPainter(
        text: TextSpan(
            text: '$maxY', style: label),
        textDirection: TextDirection.ltr)
      ..layout();
    // Right edge: the first bar / the line's start sits at the left.
    tp.paint(canvas, Offset(size.width - tp.width, y(maxY) - tp.height - 1));
    tp.dispose();

    if (bars) {
      final w = math.min(18.0, size.width / n * .7);
      for (var i = 0; i < n; i++) {
        final cx = n == 1 ? size.width / 2 : (size.width - w) * i / (n - 1) + w / 2;
        final r = RRect.fromRectAndCorners(
            Rect.fromLTRB(cx - w / 2, y(points[i].$2), cx + w / 2, y(0)),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4));
        canvas.drawRRect(
            r, Paint()..color = sel == null || sel == i ? color : color.withValues(alpha: .45));
      }
      return;
    }
    final path = Path()..moveTo(x(0), y(points[0].$2));
    for (var i = 1; i < n; i++) {
      path.lineTo(x(i), y(points[i].$2));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    final s = sel;
    if (s != null) {
      canvas.drawLine(Offset(x(s), top), Offset(x(s), y(0)),
          Paint()..color = axis.withValues(alpha: .4));
      final c = Offset(x(s), y(points[s].$2));
      canvas.drawCircle(c, 6, Paint()..color = surface);
      canvas.drawCircle(c, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.sel != sel || old.color != color;
}

/// A big number with its label.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget? swatch;
  const StatTile(
      {super.key, required this.label, required this.value, this.swatch});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (swatch != null) ...[swatch!, const SizedBox(width: 6)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 12.5, color: p.ink3)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(value, style: displayStyle(context, size: 26)),
      ]),
    );
  }
}

/// Legend for stacked bars: always shown with two or more series.
class BucketLegend extends StatelessWidget {
  final MarkPalette pal;
  final Set<int> buckets;
  const BucketLegend({super.key, required this.pal, required this.buckets});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 14, runSpacing: 6, children: [
      for (final b in buckets.toList()..sort())
        Row(mainAxisSize: MainAxisSize.min, children: [
          MarkSwatch(type: statBuckets[b], pal: pal, size: 13),
          const SizedBox(width: 6),
          Text(bucketLabel(context, b), style: uiStyle(context, size: 12.5)),
        ]),
    ]);
  }
}

/// Which marks types a stats view can filter on.
const statTypes = [
  MarkType.mistake,
  MarkType.tajwid,
  MarkType.hesitation,
  MarkType.doubt,
  MarkType.note,
];
