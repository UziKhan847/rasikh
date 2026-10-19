import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/tashkeel.dart';
import '../widgets/common.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';

/// ⏱ Counts Studio — an animated metronome. One ḥarakah = one beat.
/// The ring fills across the chosen counts; recite along and hold the
/// madd for exactly that many beats.
class CountsStudio extends StatefulWidget with DesktopAware {
  final int initialCounts;
  final String? word;
  final String? highlight;
  final bool embedded; // true = bare content (no Scaffold), for desktop panes
  const CountsStudio(
      {super.key,
      this.initialCounts = 2,
      this.word,
      this.highlight,
      this.embedded = false});

  @override
  State<CountsStudio> createState() => _CountsStudioState();
}

class _CountsStudioState extends State<CountsStudio>
    with SingleTickerProviderStateMixin {
  late int counts = math.max(1, widget.initialCounts);
  double beatMs = 600;
  bool running = false;
  int _lastBeat = -1;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _cycle)
        ..addListener(_onTick)
        ..addStatusListener((st) {
          if (st == AnimationStatus.completed && running) {
            _lastBeat = -1;
            _c.forward(from: 0);
          }
        });

  Duration get _cycle =>
      Duration(milliseconds: (beatMs * counts).round() + 350);

  void _onTick() {
    final activePortion = (beatMs * counts) / _cycle.inMilliseconds;
    final t = _c.value / activePortion;
    if (t > 1) return;
    final beat = (t * counts).floor();
    if (beat != _lastBeat && beat < counts) {
      _lastBeat = beat;
      if (SettingsScope.of(context).haptics) HapticFeedback.mediumImpact();
      setState(() {});
    }
  }

  void _toggle() {
    setState(() => running = !running);
    if (running) {
      _lastBeat = -1;
      _c.duration = _cycle;
      _c.forward(from: 0);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePortion = (beatMs * counts) / _cycle.inMilliseconds;
    if (widget.embedded) return _content(context, activePortion);
    if (useDesktop(context)) {
      // Desktop: the reference metronome panel — one centered card holding
      // the word, the beat circle, count pills, tempo, and the start button.
      return Scaffold(
        backgroundColor: pal(context).bg,
        appBar: AppBar(title:  Text(context.l10n.countsStudio)),
        body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(40, 34, 40, 30),
                decoration: BoxDecoration(
                  color: pal(context).card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color:
                          pal(context).track.withValues(alpha: .6)),
                  boxShadow: qShadows(context, [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 30,
                        offset: const Offset(0, 8)),
                  ]),
                ),
                child: SizedBox(height: 540, child: _content(context, activePortion)),
              ),
            ),
          ),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(title:  Text(context.l10n.countsStudio)),
      body: SafeArea(
        top: false,
        child: _content(context, activePortion)),
    );
  }

  Widget _content(BuildContext context, double activePortion) {
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (widget.word != null)
              RichText(
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                text: TextSpan(
                    children: highlightSpans(
                  widget.word!,
                  widget.highlight ?? '',
                  quranicStyle(context, size: 44),
                  quranicStyle(context, size: 44, color: pal(context).acc),
                )),
              ),
            widget.embedded
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final t =
                              (_c.value / activePortion).clamp(0.0, 1.0);
                          final beat = running
                              ? math.min((t * counts).floor() + 1, counts)
                              : 0;
                          return CustomPaint(
                            size: const Size.square(180),
                            painter: _BeatsPainter(
                                progress: running ? t : 0,
                                counts: counts,
                                beat: beat,
                                track: pal(context).track,
                                pip: pal(context).ink3,
                                arc: pal(context).acc),
                            child: const SizedBox.square(dimension: 180),
                          );
                        },
                      ),
                    ),
                  )
                : Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = (_c.value / activePortion).clamp(0.0, 1.0);
                    final beat = running
                        ? math.min((t * counts).floor() + 1, counts)
                        : 0;
                    return CustomPaint(
                      size: const Size.square(230),
                      painter: _BeatsPainter(
                          progress: running ? t : 0,
                          counts: counts,
                          beat: beat,
                          track: pal(context).track,
                          pip: pal(context).ink3,
                          arc: pal(context).acc),
                      child: SizedBox.square(
                        dimension: 230,
                        child: Center(
                          child: AnimatedScale(
                            scale: running ? 1 + 0.06 * math.sin(t * counts * math.pi) : 1,
                            duration: const Duration(milliseconds: 80),
                            child: Text(
                              running ? '$beat' : '$counts',
                              style: uiStyle(context,
                                  size: 84, weight: FontWeight.w800,
                                  color: pal(context).acc),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in const [1, 2, 4, 6])
                  ChoiceChip(
                    label: Text(context.l10n.countLabelPlural(c)),
                    selected: counts == c,
                    selectedColor: pal(context).acc,
                    backgroundColor: pal(context).track,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: uiStyle(context,
                        size: 13,
                        color: counts == c ? Colors.white : pal(context).ink,
                        weight: FontWeight.w700),
                    onSelected: (_) {
                      setState(() {
                        counts = c;
                        running = false;
                        _c.stop();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(AppIcons.speed,
                  color: pal(context).ink3, size: 20),
              Expanded(
                child: Slider(
                  min: 350, max: 1000,
                  value: beatMs,
                  onChanged: (v) => setState(() {
                    beatMs = v;
                    running = false;
                    _c.stop();
                  }),
                ),
              ),
              Text(context.l10n.bpmLabel((60000 / beatMs).round()),
                  style: uiStyle(context, size: 13, color: pal(context).ink3)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor:
                        running ? pal(context).track : pal(context).acc,
                    foregroundColor:
                        running ? pal(context).ink : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _toggle,
                icon: Icon(running
                    ? AppIcons.stop
                    : AppIcons.play),
                label: Text(running ? context.l10n.stop : context.l10n.startReciteAlong),
              ),
            ),
          ],
        ),
      );
  }
}

class _BeatsPainter extends CustomPainter {
  final double progress;
  final int counts;
  final int beat;
  final Color track;
  final Color pip;
  final Color arc;
  _BeatsPainter(
      {required this.progress,
      required this.counts,
      required this.beat,
      required this.track,
      required this.pip,
      required this.arc});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    canvas.drawCircle(
        c, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = track);
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 12
            ..color = arc);
    }
    // beat pips around the ring
    for (var i = 0; i < counts; i++) {
      final a = -math.pi / 2 + 2 * math.pi * (i + 1) / counts;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
          p, i < beat ? 8 : 5,
          Paint()..color = i < beat ? AppColors.star : pip);
    }
  }

  @override
  bool shouldRepaint(_BeatsPainter old) =>
      old.progress != progress || old.beat != beat || old.counts != counts;
}

/// Public entry point for the Qaidah "Madd & Līn" unit's Test/Practice
/// phases — the counts-focused tashkīl quiz, without exposing [_tashkilQuiz]
/// itself.
QuizScreen maddLinQuizScreen(BuildContext context, {bool graded = true}) =>
    _tashkilQuiz(context, true, graded: graded);

QuizScreen _tashkilQuiz(BuildContext context, bool focusCounts,
    {bool graded = true}) {
  final rng = math.Random();
  final items =
      (focusCounts ? tashkil.where((t) => t.counts >= 2).toList() : tashkil)
        ..toList();
  final qs = <QuizQuestion>[];
  final pool = tashkil.map((t) => tashkilName(context, t)).toList();
  final sample = [...items]..shuffle(rng);
  for (final t in sample.take(8)) {
    final o = buildOptions(tashkilName(context, t), pool, rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpIdentifyGoldenMark,
        arabic: t.example,
        highlight: t.highlight,
        reviewId: 'tashkil.${t.id}',
        options: o.options,
        correct: o.correct,
        explain: tashkilNote(context, t)));
  }
  // counts questions
  final counted = tashkil.where((t) => t.counts >= 2).toList()..shuffle(rng);
  for (final t in counted.take(4)) {
    final answer = context.l10n.countsN(t.counts);
    final o = buildOptions(
        answer,
        [
          for (final n in const [1, 2, 4, 6]) context.l10n.countsN(n),
        ],
        rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpHowLongHeld(tashkilName(context, t)),
        arabic: t.example,
        reviewId: 'tashkil.counts.${t.id}',
        options: o.options,
        correct: o.correct,
        explain: tashkilNote(context, t)));
  }
  qs.shuffle(rng);
  return QuizScreen(
      title: context.l10n.tashkilQuiz,
      progressId: focusCounts ? 'qaidah.madd' : 'tashkil.quiz',
      questions: qs,
      graded: graded);
}
