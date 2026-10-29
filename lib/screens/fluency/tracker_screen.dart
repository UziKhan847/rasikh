import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'passage_screen.dart' show passageName;

/// The fluency plan's tracker: each cold read (the baseline first, then a
/// row a week) — passage, words correct a minute, stalls and madd errors a
/// minute, the perception score, notes — and the words a minute's line,
/// rising. The first recording can be played beside the latest.
class TrackerScreen extends StatefulWidget with DesktopAware {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _player = AudioPlayer();
  final Map<int, String> _names = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = FluencyScope.read(context);
    // Seeing the tracker is the session's wrap-up (after this build).
    WidgetsBinding.instance.addPostFrameCallback((_) => store?.blockDone('wrapup'));
    for (final c in store?.coldReads ?? const <ColdRead>[]) {
      if (_names.containsKey(c.at)) continue;
      _names[c.at] = '';
      final (from, to) = _ayahsOf(c);
      passageName(from, to).then((n) {
        if (mounted) setState(() => _names[c.at] = n);
      });
    }
  }

  /// A cold read's passage, from its tokens to āyāt (in the script read).
  (int, int) _ayahsOf(ColdRead c) =>
      (_ayahOfTok(c.script, c.firstTok), _ayahOfTok(c.script, c.lastTok));

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(String? path) async {
    if (path == null || !File(path).existsSync()) return;
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final store = FluencyScope.maybeOf(context);
    final reads = store?.coldReads ?? const <ColdRead>[];
    final start = store?.planStart;
    String weekOf(ColdRead c, int i) {
      if (i == 0) return l.tkBaseline;
      if (start == null) return '${i + 1}';
      return '${((c.at - start) ~/ (7 * 86400000) + 1).clamp(1, 99)}';
    }

    final recorded = reads.where((c) => c.recording != null && File(c.recording!).existsSync()).toList();
    TextStyle head = uiStyle(context, size: 12, weight: FontWeight.w700, color: p.ink3);
    TextStyle cell = uiStyle(context, size: 13.5);
    return Scaffold(
      appBar: AppBar(title: Text(l.tkTitle)),
      body: SafeArea(
        child: reads.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.tkEmpty,
                      textAlign: TextAlign.center, style: uiStyle(context, size: 15, color: p.ink2)),
                ),
              )
            : ListView(padding: const EdgeInsets.all(20), children: [
                QColumn(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(l.tkWpm, style: uiStyle(context, size: 13, weight: FontWeight.w700, color: p.ink2)),
                    const SizedBox(height: 8),
                    SizedBox(height: 140, child: CustomPaint(painter: _Line(reads, p.acc, p.line2))),
                    const SizedBox(height: 16),
                    if (recorded.length >= 2)
                      Row(children: [
                        Expanded(
                          child: QOutlineButton(l.tkPlayFirst,
                              icon: AppIcons.play, onTap: () => _play(recorded.first.recording)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: QOutlineButton(l.tkPlayLatest,
                              icon: AppIcons.play, onTap: () => _play(recorded.last.recording)),
                        ),
                      ]),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 18,
                        headingTextStyle: head,
                        dataTextStyle: cell,
                        columns: [
                          DataColumn(label: Text(l.tkWeek)),
                          DataColumn(label: Text(l.tkPassage)),
                          DataColumn(label: Text(l.tkWords), numeric: true),
                          DataColumn(label: Text(l.tkStalls), numeric: true),
                          DataColumn(label: Text(l.tkMadd), numeric: true),
                          DataColumn(label: Text(l.tkPerception), numeric: true),
                          DataColumn(label: Text(l.crNotes)),
                        ],
                        rows: [
                          for (final (i, c) in reads.indexed)
                            DataRow(cells: [
                              DataCell(Text(weekOf(c, i))),
                              DataCell(Text(_names[c.at] ?? '')),
                              DataCell(Text(c.perMinute.toStringAsFixed(0))),
                              DataCell(Text((c.stalls * 60 / c.seconds).toStringAsFixed(1))),
                              DataCell(Text((c.maddErrors * 60 / c.seconds).toStringAsFixed(1))),
                              DataCell(Text(c.perception == null ? '—' : '${c.perception}/10')),
                              DataCell(Text(c.notes)),
                            ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ]),
      ),
    );
  }
}

/// The global āyah token [tok] is in, in [script].
int _ayahOfTok(String script, int tok) => MushafRepo.tokenAt(script, tok).$1;

/// The words a minute, a point per cold read.
class _Line extends CustomPainter {
  final List<ColdRead> reads;
  final Color colour, grid;
  _Line(this.reads, this.colour, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final most = reads.map((c) => c.perMinute).reduce((a, b) => a > b ? a : b);
    final top = most <= 0 ? 1.0 : most * 1.15;
    final g = Paint()..color = grid;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), g);
    Offset at(int i) => Offset(
        reads.length == 1 ? size.width / 2 : size.width * i / (reads.length - 1),
        size.height * (1 - reads[i].perMinute / top));
    final line = Paint()
      ..color = colour
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < reads.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < reads.length; i++) {
      canvas.drawCircle(at(i), 4, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(_Line o) => o.reads != reads || o.colour != colour;
}
