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

/// 🎵 Tashkīl Lab — every mark, what it does, and a Counts Studio that
/// trains the exact timing: 1 count, 2, 4, and 6 (the heart of madd).
class TashkeelScreen extends StatelessWidget {
  final bool focusCounts;
  final bool embedded;
  const TashkeelScreen({super.key, this.focusCounts = false, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final items = focusCounts
        ? tashkil.where((t) => t.counts >= 2).toList()
        : tashkil;
    if (useDesktop(context)) return _desktopBuild(context, items.toList());
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(title: Text(focusCounts ? context.l10n.maddCounts : context.l10n.tashkilLab)),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          for (var i = 0; i < items.length; i++)
            FadeSlideIn(
              delayMs: 40 * i,
              child: _TashkilCard(item: items[i]),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: pal(context).accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => pushAdaptive(context, _tashkilQuiz(context, focusCounts)),
            icon: const Icon(Icons.quiz_rounded),
            label:  Text(context.l10n.tashkilQuiz),
          ),
        ],
      )),
    );
  }
}


extension _TashkeelDesktop on TashkeelScreen {
  /// Desktop: the reference "Madd & Counts" — a two-column accordion of the
  /// marks (tile glyph, name + sound, chevron; tap to expand the note), with
  /// a Tashkīl Quiz CTA beneath.
  Widget _desktopBuild(BuildContext context, List<TashkilItem> items) {
    return Scaffold(
      backgroundColor: pal(context).bg,
      body: _DeskAccordion(items: items, focusCounts: focusCounts),
    );
  }
}

class _DeskAccordion extends StatefulWidget {
  final List<TashkilItem> items;
  final bool focusCounts;
  const _DeskAccordion({required this.items, required this.focusCounts});
  @override
  State<_DeskAccordion> createState() => _DeskAccordionState();
}

class _DeskAccordionState extends State<_DeskAccordion> {
  int? open;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(34, 12, 34, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              LayoutBuilder(builder: (context, c) {
                final two = c.maxWidth > 760;
                final colW = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(width: colW, child: _tile(context, i)),
                  ],
                );
              }),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: pal(context).accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                onPressed: () => pushAdaptive(
                    context, _tashkilQuiz(context, widget.focusCounts)),
                child:  Text(context.l10n.tashkilQuiz),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, int i) {
    final m = widget.items[i];
    final isOpen = open == i;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isOpen
                ? pal(context).accent.withValues(alpha: .5)
                : pal(context).surfaceHigh.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => open = isOpen ? null : i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: pal(context).bg,
                    borderRadius: BorderRadius.circular(14)),
                child: Text(m.mark,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'ScheherazadeNew',
                        fontSize: 30,
                        height: 1.2,
                        color: pal(context).accent)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tashkilName(context, m),
                        style: uiStyle(context,
                            size: 16, weight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                        '“${m.sound}” · ${m.counts == 0 ? context.l10n.noCount : context.l10n.countLabelPlural(m.counts)}',
                        style: uiStyle(context,
                            size: 13, color: pal(context).textDim)),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: isOpen ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: pal(context).textDim),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(90, 0, 22, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(tashkilNote(context, m),
                  style: uiStyle(context,
                          size: 14, color: pal(context).textDim)
                      .copyWith(height: 1.65)),
              const SizedBox(height: 12),
              Text(m.example,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontFamily: 'UthmanicHafs', fontSize: 30, height: 1.6)),
              Text(context.l10n.surahRef(m.ref),
                  style: uiStyle(context,
                      size: 12, color: pal(context).textDim)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _TashkilCard extends StatelessWidget {
  final TashkilItem item;
  const _TashkilCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    // The madd variants carry a range in their label ('4–5', '2 / 4 / 6'),
    // so those keep the composed form; the rest use the plural.
    final suffix = item.id == 'madd45' || item.id == 'madd4'
        ? '–5'
        : item.id == 'madd246'
            ? ' / 4 / 6'
            : '';
    final countLabel = item.counts == 0
        ? '· ${context.l10n.noCount}'
        : suffix.isEmpty
            ? '· ${context.l10n.countLabelPlural(item.counts)}'
            : '· ${context.l10n.countsN(item.counts)}$suffix';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 50, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal(context).surfaceHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(item.mark,
                  textDirection: TextDirection.rtl,
                  style: arabicStyle(context, size: 24, height: 1.5,
                      color: pal(context).accent)),
            ),
            title: Text(tashkilName(context, item),
                style: uiStyle(context, size: 16.5, weight: FontWeight.w700)),
            subtitle: Text('“${item.sound}” $countLabel',
                style: uiStyle(context, size: 13, color: pal(context).textDim)),
            children: [
              Text(tashkilNote(context, item),
                  style: uiStyle(context, size: 14, color: pal(context).textDim)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.paperMode ? pal(context).paper : pal(context).surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                        children: highlightSpans(
                      item.example,
                      item.highlight,
                      arabicStyle(context, size: 38),
                      arabicStyle(context, size: 38, color: pal(context).accent,
                          weight: FontWeight.w700),
                    )),
                  ),
                  Text(context.l10n.surahRef(item.ref),
                      style: uiStyle(context,
                          size: 12.5, color: pal(context).textDim)),
                ]),
              ),
              if (item.counts >= 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: pal(context).accent,
                        side: BorderSide(color: pal(context).accent)),
                    onPressed: () => pushAdaptive(
                        context,
                        CountsStudio(
                          initialCounts: item.counts,
                          word: item.example,
                          highlight: item.highlight,
                        )),
                    icon: const Icon(Icons.av_timer_rounded),
                    label: Text(context.l10n.trainCountTiming(item.counts)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<TextSpan> highlightSpans(
    String text, String hl, TextStyle base, TextStyle hlStyle) {
  final i = text.indexOf(hl);
  if (i < 0 || hl.isEmpty) return [TextSpan(text: text, style: base)];
  return [
    if (i > 0) TextSpan(text: text.substring(0, i), style: base),
    TextSpan(text: hl, style: hlStyle),
    if (i + hl.length < text.length)
      TextSpan(text: text.substring(i + hl.length), style: base),
  ];
}

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
                  color: pal(context).surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color:
                          pal(context).surfaceHigh.withValues(alpha: .6)),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 30,
                        offset: const Offset(0, 8)),
                  ],
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
                  arabicStyle(context, size: 44),
                  arabicStyle(context, size: 44,
                      color: pal(context).accent, weight: FontWeight.w700),
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
                                track: pal(context).surfaceHigh,
                                pip: pal(context).textDim,
                                arc: pal(context).accent),
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
                          track: pal(context).surfaceHigh,
                          pip: pal(context).textDim,
                          arc: pal(context).accent),
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
                                  color: pal(context).accent),
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
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: uiStyle(context,
                        size: 13,
                        color: counts == c ? Colors.white : pal(context).text,
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
              Icon(Icons.speed_rounded,
                  color: pal(context).textDim, size: 20),
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
                  style: uiStyle(context, size: 13, color: pal(context).textDim)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor:
                        running ? pal(context).surfaceHigh : pal(context).accent,
                    foregroundColor:
                        running ? pal(context).text : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _toggle,
                icon: Icon(running
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded),
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

QuizScreen _tashkilQuiz(BuildContext context, bool focusCounts) {
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
        options: o.options,
        correct: o.correct,
        explain: tashkilNote(context, t)));
  }
  qs.shuffle(rng);
  return QuizScreen(
      title: context.l10n.tashkilQuiz,
      progressId: focusCounts ? 'qaidah.madd' : 'tashkil.quiz',
      questions: qs);
}
