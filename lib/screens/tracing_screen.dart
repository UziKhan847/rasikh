import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/strokes.dart';
import '../data/tracing_levels.dart';
import '../widgets/common.dart';

/// ✍️ Tracing Studio — authentic Uthman-Taha letterforms in every position
/// (alone · start · middle · end), whole-word tracing, and two modes:
///   • Guided — the strict comet-follow engine with live direction checking.
///   • Memory — a blank board: draw the shape yourself, tap its dots, hit
///     Check, and the app grades stroke shape, order-independence, pen
///     direction, and dot placement against the real letterform.
class TracingScreen extends StatefulWidget {
  final String? initialLetter; // a letter char like 'ب'
  final bool embedded;
  const TracingScreen({super.key, this.initialLetter, this.embedded = false});

  @override
  State<TracingScreen> createState() => _TracingScreenState();
}

class _TracingScreenState extends State<TracingScreen> {
  int level = 0;
  late String letter;
  String form = 'iso';
  int wordIdx = 0;
  /// 'guided' · 'outline' · 'memory' — see [TracingBoard.mode].
  String mode = 'guided';

  // 0 = spinner · 1 = layout with a board placeholder · 2 = board mounted.
  int _stage = 0;

  // ── quiz state ──
  bool quiz = false;
  int quizTarget = 5; // correct traces in a row to clear a letter
  int quizStreak = 0;
  int attempt = 0; // bump to remount the board fresh
  final Set<String> quizCleared = {};
  TracedGlyph? quizGlyph;
  int? lastStars;
  bool awaitingNext = false;
  bool quizComplete = false;
  final math.Random _rng = math.Random();

  TracingLevel get lvl => tracingLevels[level];

  TracedGlyph get glyph {
    if (quiz) return quizGlyph ?? lvl.quizPool.first;
    if (lvl.words) {
      final i = wordIdx.clamp(0, lvl.glyphs.length - 1);
      return lvl.glyphs[i];
    }
    return lvl.glyphForIn(letter, form);
  }

  static const _modeSuffix = {
    'guided': '',
    'outline': '.out',
    'memory': '.mem',
  };

  String get progressId =>
      'trace.${lvl.id}.${glyph.id}${_modeSuffix[mode] ?? ''}';

  @override
  void initState() {
    super.initState();
    letter = widget.initialLetter ?? '';
    if (!lvl.letters.any((l) => l.char == letter)) {
      letter = lvl.letters.first.char;
    }
    final f = lvl.formsPresentFor(letter);
    if (!f.contains(form)) form = f.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _stage = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stage = 2);
      });
    });
  }

  // ── selection ──
  void _setLevel(int i) {
    setState(() {
      level = i;
      quiz = false;
      awaitingNext = false;
      quizComplete = false;
      quizStreak = 0;
      quizCleared.clear();
      quizGlyph = null;
      if (lvl.words) {
        wordIdx = 0;
      } else {
        if (!lvl.letters.any((l) => l.char == letter)) {
          letter = lvl.letters.first.char;
        }
        final f = lvl.formsPresentFor(letter);
        if (!f.contains(form)) form = f.first;
      }
      attempt++;
    });
  }

  void _setLetter(String ch) {
    setState(() {
      letter = ch;
      final f = lvl.formsPresentFor(ch);
      if (!f.contains(form)) form = f.first;
      attempt++;
    });
  }

  // ── quiz ──
  TracedGlyph? _pickQuiz() {
    final pool =
        lvl.quizPool.where((g) => !quizCleared.contains(g.id)).toList();
    if (pool.isEmpty) return null;
    return pool[_rng.nextInt(pool.length)];
  }

  void _startQuiz() {
    setState(() {
      quiz = true;
      quizComplete = false;
      awaitingNext = false;
      quizStreak = 0;
      lastStars = null;
      quizCleared.clear();
      quizGlyph = _pickQuiz();
      attempt++;
    });
  }

  void _exitQuiz() {
    setState(() {
      quiz = false;
      awaitingNext = false;
      attempt++;
    });
  }

  void _onStars(int s) {
    if (quiz && awaitingNext) return;
    ProgressScope.of(context).report(progressId, s);
    if (!quiz) return;
    setState(() {
      lastStars = s;
      awaitingNext = true;
      if (s >= 2) {
        quizStreak++;
        if (quizStreak >= quizTarget && quizGlyph != null) {
          quizCleared.add(quizGlyph!.id);
        }
      } else {
        quizStreak = 0;
      }
    });
  }

  void _quizNext() {
    setState(() {
      final cleared =
          quizGlyph != null && quizCleared.contains(quizGlyph!.id);
      if (cleared) {
        quizStreak = 0;
        final next = _pickQuiz();
        if (next == null) {
          quizComplete = true;
          awaitingNext = false;
          return;
        }
        quizGlyph = next;
      }
      awaitingNext = false;
      lastStars = null;
      attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == 0) {
      return Scaffold(
        appBar:
            widget.embedded ? null : AppBar(title:  Text(context.l10n.tracingStudio)),
        body: Center(
            child: CircularProgressIndicator(color: pal(context).accent)),
      );
    }
    return Scaffold(
      appBar:
          widget.embedded ? null : AppBar(title:  Text(context.l10n.tracingStudio)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: LayoutBuilder(builder: (context, c) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: (c.maxHeight * 0.5).clamp(150.0, 430.0)),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _levelBar(context),
                        const SizedBox(height: 10),
                        _modeBar(context),
                        const SizedBox(height: 10),
                        if (quiz)
                          ..._quizControls(context)
                        else
                          ..._practiceControls(context),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _stage < 2
                      ? Container(
                          decoration: BoxDecoration(
                            color: pal(context).surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: pal(context).accent)),
                        )
                      : TracingBoard(
                          key: ValueKey(
                              '${lvl.id}-${glyph.id}-$mode-$quiz-$attempt'),
                          glyph: glyph,
                          mode: mode,
                          showOverlay: !quiz,
                          onStars: _onStars,
                        ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── control widgets ──
  Widget _levelBar(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tracingLevels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final lv = tracingLevels[i];
            final sel = i == level;
            return TapScale(
              onTap: () => _setLevel(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: sel ? pal(context).accent : pal(context).surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? pal(context).accent : Colors.transparent),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1} · ${levelNameOf(context, lv.id)}',
                        style: uiStyle(context,
                            size: 12.5,
                            weight: FontWeight.w800,
                            color: sel ? Colors.white : pal(context).text)),
                    Text(tierLabelOf(context, lv.tier),
                        style: uiStyle(context,
                            size: 10,
                            color:
                                sel ? Colors.white70 : pal(context).textDim)),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _modeBar(BuildContext context) => Column(children: [
        Row(children: [
          for (final value in const [
            'guided',
            'outline',
            'memory',
          ]) ...[
            Expanded(
              child: _seg(context, modeLabelOf(context, value),
                  mode == value, () {
                setState(() {
                  mode = value;
                  attempt++;
                });
              }),
            ),
            if (value != 'memory') const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _seg(context, context.l10n.practice, !quiz, () {
            if (quiz) _exitQuiz();
          }),
          const SizedBox(width: 8),
          _seg(context, context.l10n.quiz, quiz, () {
            if (!quiz) _startQuiz();
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_modeHint,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 11, color: pal(context).textDim)),
          ),
        ]),
      ]);

  String get _modeHint => switch (mode) {
        'outline' => context.l10n.hintOutline,
        'memory' => context.l10n.hintMemory,
        _ => context.l10n.hintGuided,
      };

  List<Widget> _practiceControls(BuildContext context) {
    final progress = ProgressScope.of(context);
    return [
      if (lvl.words)
        _wordStrip(context)
      else ...[
        _letterStrip(context),
        const SizedBox(height: 10),
        _formsRow(context),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Text(glyphNameOf(context, glyph),
              style: uiStyle(context, size: 15, weight: FontWeight.w700)),
        ),
        StarRow(progress.starsFor(progressId)),
      ]),
      const SizedBox(height: 8),
      Text(
        switch (mode) {
          'memory' =>
            context.l10n.traceInstrMemory(glyphNameOf(context, glyph)),
          'outline' => context.l10n.traceInstrOutline,
          _ => context.l10n.traceInstrGuided,
        },
        textAlign: TextAlign.center,
        style: uiStyle(context, size: 12.5, color: pal(context).textDim),
      ),
    ];
  }

  List<Widget> _quizControls(BuildContext context) {
    final pool = lvl.quizPool;
    final total = pool.length;
    final g = glyph;
    final cleared =
        quizGlyph != null && quizCleared.contains(quizGlyph!.id);
    return [
      Row(children: [
        Text(context.l10n.inARow,
            style: uiStyle(context,
                size: 12.5,
                weight: FontWeight.w700,
                color: pal(context).textDim)),
        const SizedBox(width: 8),
        _seg(context, '5', quizTarget == 5,
            () => setState(() => quizTarget = 5)),
        const SizedBox(width: 8),
        _seg(context, '10', quizTarget == 10,
            () => setState(() => quizTarget = 10)),
        const Spacer(),
        Text(context.l10n.clearedXofY(quizCleared.length, total),
            style: uiStyle(context,
                size: 12.5,
                weight: FontWeight.w800,
                color: pal(context).accentDeep)),
      ]),
      const SizedBox(height: 12),
      if (quizComplete) ...[
        Text(context.l10n.levelCompleteEveryLetterCleared,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 15.5, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: pal(context).accent),
            onPressed: _startQuiz,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label:  Text(context.l10n.restartQuiz),
          ),
        ),
      ] else ...[
        Row(children: [
          Text(g.char,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 30,
                  height: 1.3,
                  color: pal(context).text)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(glyphNameOf(context, g),
                style: uiStyle(context, size: 14, weight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        _streakDots(context),
        const SizedBox(height: 10),
        if (awaitingNext) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            StarRow(lastStars ?? 0, size: 22),
            const SizedBox(width: 10),
            Text(
                cleared
                    ? context.l10n.letterCleared
                    : ((lastStars ?? 0) >= 2
                        ? context.l10n.niceKeepStreak
                        : context.l10n.notQuiteStreakReset),
                style: uiStyle(context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: cleared ? AppColors.ok : pal(context).textDim)),
          ]),
          const SizedBox(height: 10),
          Center(
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: pal(context).accent),
              onPressed: _quizNext,
              icon: Icon(
                  cleared
                      ? Icons.arrow_forward_rounded
                      : Icons.refresh_rounded,
                  size: 18),
              label: Text(cleared ? context.l10n.nextLetter : context.l10n.traceAgain),
            ),
          ),
        ] else
          Text(
            switch (mode) {
              'memory' => context.l10n.quizInstrMemory(quizTarget),
              'outline' => context.l10n.quizInstrOutline(quizTarget),
              _ => context.l10n.quizInstrGuided(quizTarget),
            },
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 12.5, color: pal(context).textDim),
          ),
      ],
    ];
  }

  Widget _streakDots(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < quizTarget; i++) ...[
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < quizStreak
                    ? pal(context).accent
                    : pal(context).surfaceHigh,
                border: Border.all(
                    color: pal(context).accent.withValues(alpha: .4)),
              ),
            ),
            if (i != quizTarget - 1) const SizedBox(width: 6),
          ],
        ],
      );

  Widget _letterStrip(BuildContext context) => SizedBox(
        height: 54,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: lvl.letters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final l = lvl.letters[i];
            final sel = l.char == letter;
            return TapScale(
              onTap: () => _setLetter(l.char),
              child: Container(
                width: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? pal(context).accent : pal(context).surface,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(l.char,
                    style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 24,
                        height: 1.5,
                        color: sel ? Colors.white : pal(context).text)),
              ),
            );
          },
        ),
      );

  Widget _formsRow(BuildContext context) {
    final forms = lvl.formsPresentFor(letter);
    return Row(children: [
      for (final f in forms) ...[
        Expanded(
          child: TapScale(
            onTap: () => setState(() {
              form = f;
              attempt++;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: form == f
                    ? pal(context).accent.withValues(alpha: .14)
                    : pal(context).surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: form == f
                        ? pal(context).accent
                        : Colors.transparent),
              ),
              child: Column(children: [
                Text(lvl.glyphForIn(letter, f).char,
                    style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 20,
                        height: 1.4,
                        color: pal(context).text)),
                Text(formLabelOf(context, f),
                    style: uiStyle(context,
                        size: 10.5, color: pal(context).textDim)),
              ]),
            ),
          ),
        ),
        if (f != forms.last) const SizedBox(width: 8),
      ],
    ]);
  }

  Widget _wordStrip(BuildContext context) => SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: lvl.glyphs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final sel = i == wordIdx;
            return TapScale(
              onTap: () => setState(() {
                wordIdx = i;
                attempt++;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? pal(context).accent : pal(context).surface,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: pal(context).shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(lvl.glyphs[i].char,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 22,
                        height: 1.5,
                        color: sel ? Colors.white : pal(context).text)),
              ),
            );
          },
        ),
      );

  Widget _seg(BuildContext context, String label, bool sel, VoidCallback onTap) =>
      TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? pal(context).accent : pal(context).surfaceHigh,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(label,
              style: uiStyle(context,
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: sel ? Colors.white : pal(context).text)),
        ),
      );
}

// ═════════════════════════════ Board ═════════════════════════════

class TracingBoard extends StatefulWidget {
  final TracedGlyph glyph;

  /// 'guided'  — letterform shown, comet leads, the ideal stroke inks itself in
  /// 'outline' — letterform shown, no comet, YOU form every stroke
  /// 'memory'  — blank board, no shape, no comet
  final String mode;
  final void Function(int stars) onStars;
  final bool showOverlay; // false in quiz mode (parent shows its own feedback)
  const TracingBoard(
      {super.key,
      required this.glyph,
      required this.mode,
      required this.onStars,
      this.showOverlay = true});

  @override
  State<TracingBoard> createState() => _TracingBoardState();
}

class _TracingBoardState extends State<TracingBoard>
    with SingleTickerProviderStateMixin {
  // ── guided engine ──
  static const startTol = .10, pathTol = .075, strayTol = .13;
  static const resumeTol = .15; // re-touch radius to continue after a lift
  static const lookAhead = .15, finishAt = .965;
  static const maxStraySamples = 12;

  int strokeIndex = 0;
  double progress = 0; // 0..1 along current stroke
  bool tracking = false;
  int straying = 0;
  int faults = 0;
  List<Offset> _samples = const [];
  Offset? finger;

  // dots (both modes)
  final Set<int> dotsHit = {};

  // ── memory mode ──
  final List<List<Offset>> drawn = [];
  List<Offset> current = [];
  final List<Offset> userDots = [];
  _MemoryResult? result;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  bool get strokesDone => strokeIndex >= widget.glyph.strokes.length;
  bool get allDone =>
      strokesDone && dotsHit.length >= widget.glyph.dots.length;

  @override
  void initState() {
    super.initState();
    _rebuildSamples();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _rebuildSamples() {
    if (strokesDone) {
      _samples = const [];
      return;
    }
    final path = smoothPath(widget.glyph.strokes[strokeIndex]);
    final metric = path.computeMetrics().first;
    const n = 140;
    _samples = [
      for (var i = 0; i <= n; i++)
        metric.getTangentForOffset(metric.length * i / n)!.position
    ];
  }

  void _haptic() {
    if (SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
  }

  // ── guided gestures (normalized: divide by board height) ──
  void _gStart(Offset p) {
    if (strokesDone || result != null) return;
    final n = _samples.length;
    final start = _samples.first;
    final frontier = _samples[(progress * (n - 1)).round().clamp(0, n - 1)];
    if (progress <= 0 && (p - start).distance <= startTol) {
      // fresh stroke — must begin at the green start
      tracking = true;
      straying = 0;
      _haptic();
    } else if (progress > 0 && (p - frontier).distance <= resumeTol) {
      // lifted mid-stroke — CONTINUE from the comet, never restart
      tracking = true;
      straying = 0;
      _haptic();
    }
    setState(() => finger = p);
  }

  void _gMove(Offset p) {
    setState(() => finger = p);
    if (!tracking || strokesDone) return;
    final n = _samples.length;
    final curIdx = (progress * (n - 1)).round();
    final maxIdx = math.min(n - 1, curIdx + (lookAhead * n).round());
    var best = -1;
    var bestD = double.infinity;
    for (var i = curIdx; i <= maxIdx; i++) {
      final d = (p - _samples[i]).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD <= pathTol) {
      straying = 0;
      if (best > curIdx) progress = best / (n - 1);
      if (progress >= finishAt) _finishStroke();
    } else {
      var nearAny = double.infinity;
      for (final s in _samples) {
        final d = (p - s).distance;
        if (d < nearAny) nearAny = d;
      }
      if (nearAny > strayTol) {
        straying++;
        if (straying > maxStraySamples) _strayPause();
      }
    }
  }

  void _gEnd() {
    // Lifting the finger pauses the stroke; progress is preserved so the
    // learner can set the pen back down on the comet and keep going.
    setState(() {
      tracking = false;
      finger = null;
    });
  }

  void _strayPause() {
    // Wandered off the path: stop tracking and nudge, but KEEP progress so
    // the stroke resumes from where it is rather than the beginning.
    faults++;
    tracking = false;
    straying = 0;
    _haptic();
    setState(() {});
  }

  void _finishStroke() {
    _haptic();
    strokeIndex++;
    progress = 0;
    tracking = false;
    _rebuildSamples();
    setState(() {});
    if (allDone) _completeGuided();
  }

  void _tapDot(Offset p) {
    for (var i = 0; i < widget.glyph.dots.length; i++) {
      if (dotsHit.contains(i)) continue;
      if ((p - widget.glyph.dots[i]).distance <= .12) {
        dotsHit.add(i);
        _haptic();
        setState(() {});
        if (allDone) _completeGuided();
        return;
      }
    }
    faults++;
    setState(() {});
  }

  void _completeGuided() {
    final stars = faults == 0 ? 3 : (faults <= 2 ? 2 : 1);
    widget.onStars(stars);
    setState(() => result = _MemoryResult.simple(stars));
  }

  // ── memory gestures ──
  void _mStart(Offset p) {
    if (result != null) return;
    current = [p];
    setState(() => finger = p);
  }

  void _mMove(Offset p) {
    if (result != null) return;
    if (current.isEmpty || (p - current.last).distance > .004) current.add(p);
    setState(() => finger = p);
  }

  void _mEnd() {
    setState(() => finger = null);
    if (result != null || current.isEmpty) return;
    final len = _polyLen(current);
    if (len < .03 && widget.glyph.dots.isNotEmpty) {
      userDots.add(current.first); // a tap = dot placement
    } else if (len >= .03) {
      drawn.add(_resample(current, 40));
    }
    current = [];
    setState(() {});
  }

  void _check() {
    final r = _evaluate(widget.glyph, drawn, userDots);
    widget.onStars(r.stars);
    setState(() => result = r);
  }

  void _reset() {
    setState(() {
      strokeIndex = 0;
      progress = 0;
      tracking = false;
      straying = 0;
      faults = 0;
      dotsHit.clear();
      drawn.clear();
      userDots.clear();
      current = [];
      result = null;
      _rebuildSamples();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.glyph;
    final aspect = g.aspect.clamp(0.6, 3.4);
    final p = pal(context);
    // Two independent axes: who forms the stroke, and whether the shape shows.
    final free = widget.mode != 'guided';
    final showShape = widget.mode != 'memory';
    return Column(children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect.toDouble(),
            child: LayoutBuilder(builder: (context, c) {
          final u = c.maxHeight;
          Offset norm(Offset local) => local / u;
          return GestureDetector(
            onPanStart: (d) => free
                ? _mStart(norm(d.localPosition))
                : _gStart(norm(d.localPosition)),
            onPanUpdate: (d) => free
                ? _mMove(norm(d.localPosition))
                : _gMove(norm(d.localPosition)),
            onPanEnd: (_) => free ? _mEnd() : _gEnd(),
            onTapUp: (d) {
              final q = norm(d.localPosition);
              if (free) {
                if (result == null && widget.glyph.dots.isNotEmpty) {
                  userDots.add(q);
                  setState(() {});
                }
              } else if (strokesDone) {
                _tapDot(q);
              }
            },
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _BoardPainter(
                  glyph: g,
                  free: free,
                  showShape: showShape,
                  strokeIndex: strokeIndex,
                  progress: progress,
                  samples: _samples,
                  finger: finger,
                  tracking: tracking,
                  dotsHit: dotsHit,
                  drawn: drawn,
                  current: current,
                  userDots: userDots,
                  result: result,
                  pulse: _pulse.value,
                  p: p,
                  u: u,
                ),
                child: result == null || !widget.showOverlay
                    ? null
                    : _ResultOverlay(result: result!, onRetry: _reset),
              ),
            ),
          );
            }),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label:  Text(context.l10n.clear),
        ),
        if (free) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: drawn.isNotEmpty && result == null ? _check : null,
            icon: const Icon(Icons.check_rounded, size: 18),
            label:  Text(context.l10n.check),
          ),
          const SizedBox(width: 10),
          Text(
            context.l10n.strokesAndDots(drawn.length,
                widget.glyph.strokes.length, userDots.length,
                widget.glyph.dots.length),
            style: uiStyle(context, size: 12, color: p.textDim),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              strokesDone
                  ? (widget.glyph.dots.isEmpty
                      ? context.l10n.doneExclaim
                      : context.l10n.tapTheDots(widget.glyph.dots.length))
                  : context.l10n.strokeXofY(
                      strokeIndex + 1, widget.glyph.strokes.length),
              style: uiStyle(context, size: 12, color: p.textDim),
            ),
          ),
      ]),
    ]);
  }
}

// ═════════════════════ memory evaluation ═════════════════════

class _MemoryResult {
  final int stars;
  final List<bool> strokePass;
  final List<bool> strokeReversed;
  final int dotsMatched;
  final int dotsExpected;
  final bool simpleMode; // guided completion banner
  const _MemoryResult(this.stars, this.strokePass, this.strokeReversed,
      this.dotsMatched, this.dotsExpected,
      {this.simpleMode = false});
  factory _MemoryResult.simple(int stars) =>
      _MemoryResult(stars, const [], const [], 0, 0, simpleMode: true);
}

double _polyLen(List<Offset> p) {
  var l = 0.0;
  for (var i = 0; i < p.length - 1; i++) {
    l += (p[i + 1] - p[i]).distance;
  }
  return l;
}

List<Offset> _resample(List<Offset> p, int n) {
  if (p.length < 2) return List.filled(n, p.isEmpty ? Offset.zero : p.first);
  final cum = <double>[0];
  for (var i = 0; i < p.length - 1; i++) {
    cum.add(cum.last + (p[i + 1] - p[i]).distance);
  }
  final total = cum.last;
  final out = <Offset>[];
  var j = 0;
  for (var k = 0; k < n; k++) {
    final t = total * k / (n - 1);
    while (j < p.length - 2 && cum[j + 1] < t) {
      j++;
    }
    final seg = cum[j + 1] - cum[j];
    final f = seg == 0 ? 0.0 : (t - cum[j]) / seg;
    out.add(p[j] + (p[j + 1] - p[j]) * f);
  }
  return out;
}

double _meanSymDist(List<Offset> a, List<Offset> b) {
  double oneWay(List<Offset> x, List<Offset> y) {
    var s = 0.0;
    for (final p in x) {
      var best = double.infinity;
      for (final q in y) {
        final d = (p - q).distance;
        if (d < best) best = d;
      }
      s += best;
    }
    return s / x.length;
  }

  return (oneWay(a, b) + oneWay(b, a)) / 2;
}

_MemoryResult _evaluate(
    TracedGlyph g, List<List<Offset>> drawn, List<Offset> userDots) {
  final expected = [
    for (final s in g.strokes)
      () {
        final m = smoothPath(s).computeMetrics().first;
        return [
          for (var i = 0; i < 40; i++)
            m.getTangentForOffset(m.length * i / 39)!.position
        ];
      }()
  ];
  final scale = math.max(g.aspect, 1.0);
  final passTol = .09 * scale, endTol = .17 * scale;

  final n = expected.length;
  final pass = List.filled(n, false);
  final rev = List.filled(n, false);

  // assignment: exhaustive for small counts, greedy otherwise
  final used = List.filled(drawn.length, false);
  List<int>? bestAssign;
  if (n <= 4 && drawn.length <= 5) {
    double bestCost = double.infinity;
    void perm(List<int> acc, double cost) {
      if (cost >= bestCost) return;
      if (acc.length == n) {
        bestCost = cost;
        bestAssign = List.of(acc);
        return;
      }
      for (var j = -1; j < drawn.length; j++) {
        if (j >= 0 && acc.contains(j)) continue;
        final c = j < 0
            ? 1.0
            : _meanSymDist(expected[acc.length], drawn[j]);
        perm([...acc, j], cost + c);
      }
    }

    perm([], 0);
  } else {
    bestAssign = List.filled(n, -1);
    for (var i = 0; i < n; i++) {
      var best = -1;
      var bestD = double.infinity;
      for (var j = 0; j < drawn.length; j++) {
        if (used[j]) continue;
        final d = _meanSymDist(expected[i], drawn[j]);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      if (best >= 0) {
        used[best] = true;
        bestAssign[i] = best;
      }
    }
  }

  for (var i = 0; i < n; i++) {
    final j = bestAssign![i];
    if (j < 0) continue;
    final d = _meanSymDist(expected[i], drawn[j]);
    if (d <= passTol) {
      final fwd = (expected[i].first - drawn[j].first).distance <= endTol &&
          (expected[i].last - drawn[j].last).distance <= endTol;
      final bwd = (expected[i].first - drawn[j].last).distance <= endTol &&
          (expected[i].last - drawn[j].first).distance <= endTol;
      pass[i] = fwd || bwd || d <= passTol * .6;
      rev[i] = !fwd && bwd;
    }
  }

  var dotsMatched = 0;
  final taken = List.filled(userDots.length, false);
  for (final d in g.dots) {
    for (var j = 0; j < userDots.length; j++) {
      if (taken[j]) continue;
      if ((userDots[j] - d).distance <= .13) {
        taken[j] = true;
        dotsMatched++;
        break;
      }
    }
  }

  final passed = pass.where((x) => x).length;
  final reversed = rev.where((x) => x).length;
  final dotsOk = dotsMatched >= g.dots.length;
  final extras = (drawn.length - n).clamp(0, 99) +
      (userDots.length - g.dots.length).clamp(0, 99);

  int stars;
  if (passed == n && reversed == 0 && dotsOk && extras == 0) {
    stars = 3;
  } else if (passed == n && reversed <= 1 && dotsMatched >= g.dots.length - (g.dots.isEmpty ? 0 : 1)) {
    stars = 2;
  } else if (passed >= (n * 0.6).ceil()) {
    stars = 1;
  } else {
    stars = 0;
  }
  return _MemoryResult(stars, pass, rev, dotsMatched, g.dots.length);
}

// ═════════════════════════ painter ═════════════════════════

class _BoardPainter extends CustomPainter {
  final TracedGlyph glyph;
  /// Free drawing (the learner forms the stroke) rather than following the
  /// comet. True for BOTH 'outline' and 'memory'.
  final bool free;

  /// The letterform is shown underneath. True for BOTH 'guided' and 'outline'.
  final bool showShape;
  final int strokeIndex;
  final double progress;
  final List<Offset> samples;
  final Offset? finger;
  final bool tracking;
  final Set<int> dotsHit;
  final List<List<Offset>> drawn;
  final List<Offset> current;
  final List<Offset> userDots;
  final _MemoryResult? result;
  final double pulse;
  final Palette p;
  final double u;

  _BoardPainter({
    required this.glyph,
    required this.free,
    required this.showShape,
    required this.strokeIndex,
    required this.progress,
    required this.samples,
    required this.finger,
    required this.tracking,
    required this.dotsHit,
    required this.drawn,
    required this.current,
    required this.userDots,
    required this.result,
    required this.pulse,
    required this.p,
    required this.u,
  });

  Path _scaled(List<Offset> pts) => smoothPathScaled(pts, u);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = p.surface;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(22));
    canvas.drawRRect(rrect, bg);
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = p.surfaceHigh);
    canvas.save();
    canvas.clipRRect(rrect);

    // Stroke weights (0.75× the original nib for a finer, less blobby line).
    final ghostW = u * .05625;
    final inkW = u * .0375;

    Paint stroke(Color c, double w, [double alpha = 1]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c.withValues(alpha: alpha);

    // The shape itself: always once checked, so the learner can compare.
    final showGuides = showShape || result != null;

    if (showGuides) {
      // ghost skeleton (the real letterform)
      for (final s in glyph.strokes) {
        canvas.drawPath(
            _scaled(s),
            stroke(
                result == null ? p.textDim : AppColors.ok, ghostW,
                result == null ? .18 : .28));
      }
      for (var i = 0; i < glyph.dots.length; i++) {
        final c = glyph.dots[i] * u;
        canvas.drawCircle(
            c,
            u * .035,
            Paint()
              ..color = (dotsHit.contains(i) ? p.accent : p.textDim)
                  .withValues(alpha: dotsHit.contains(i) ? .9 : .25));
      }
    }

    if (!free) {
      // completed strokes
      for (var i = 0; i < strokeIndex && i < glyph.strokes.length; i++) {
        canvas.drawPath(_scaled(glyph.strokes[i]), stroke(p.accent, inkW));
      }
      // current stroke progress + comet
      if (strokeIndex < glyph.strokes.length && samples.isNotEmpty) {
        final n = samples.length;
        final upto = (progress * (n - 1)).round();
        if (upto > 0) {
          final part = Path()
            ..moveTo(samples[0].dx * u, samples[0].dy * u);
          for (var i = 1; i <= upto; i++) {
            part.lineTo(samples[i].dx * u, samples[i].dy * u);
          }
          canvas.drawPath(part, stroke(p.accent, inkW));
        }
        final target = samples[math.min(upto + 4, n - 1)] * u;
        final glow = u * (.05 + .015 * pulse);
        canvas.drawCircle(
            target, glow, Paint()..color = p.accent2.withValues(alpha: .30));
        canvas.drawCircle(target, u * .026, Paint()..color = p.accent2);
        // arrowhead pointing ahead
        final aheadI = math.min(upto + 10, n - 1);
        final dir = (samples[aheadI] - samples[math.max(aheadI - 3, 0)]);
        if (dir.distance > 0) {
          final d = dir / dir.distance;
          final tip = samples[aheadI] * u + d * (u * .05);
          final left = tip - d * (u * .045) + Offset(-d.dy, d.dx) * (u * .02);
          final right = tip - d * (u * .045) - Offset(-d.dy, d.dx) * (u * .02);
          canvas.drawPath(
              Path()
                ..moveTo(tip.dx, tip.dy)
                ..lineTo(left.dx, left.dy)
                ..lineTo(right.dx, right.dy)
                ..close(),
              Paint()..color = p.accent2.withValues(alpha: .85));
        }
        // start marker
        if (progress == 0 && !tracking) {
          final s0 = samples.first * u;
          canvas.drawCircle(
              s0,
              u * (.045 + .012 * pulse),
              Paint()..color = AppColors.ok.withValues(alpha: .25));
          canvas.drawCircle(s0, u * .03, Paint()..color = AppColors.ok);
        }
      }
    } else {
      // memory ink
      Color inkFor(int i) {
        if (result == null || result!.simpleMode || i >= result!.strokePass.length) {
          return AppColors.lilac;
        }
        // map drawn index -> pass? we color by order drawn vs first matching
        return AppColors.lilac;
      }

      for (var i = 0; i < drawn.length; i++) {
        canvas.drawPath(_scaled(drawn[i]), stroke(inkFor(i), inkW, .9));
      }
      if (current.length > 1) {
        canvas.drawPath(_scaled(current), stroke(AppColors.lilac, inkW, .9));
      }
      for (final d in userDots) {
        canvas.drawCircle(d * u, u * .03,
            Paint()..color = AppColors.lilac.withValues(alpha: .9));
      }
    }

    // finger halo
    if (finger != null) {
      canvas.drawCircle(
          finger! * u,
          u * .055,
          Paint()
            ..color = (tracking || free ? p.accent : p.accent2)
                .withValues(alpha: .22));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

// ═════════════════════════ result overlay ═════════════════════════

class _ResultOverlay extends StatelessWidget {
  final _MemoryResult result;
  final VoidCallback onRetry;
  const _ResultOverlay({required this.result, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            result.stars >= 3
                ? context.l10n.perfectTrace
                : result.stars == 2
                    ? context.l10n.veryClose
                    : result.stars == 1
                        ? context.l10n.goodStartKeepGoing
                        : context.l10n.notQuiteTryAgain,
            style: uiStyle(context, size: 15.5, weight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          StarRow(result.stars, size: 26),
          if (!result.simpleMode) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < result.strokePass.length; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (result.strokePass[i] ? AppColors.ok : AppColors.bad)
                        .withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'S${i + 1} ${result.strokePass[i] ? (result.strokeReversed[i] ? '↺ ${context.l10n.strokeDirectionLabel}' : '✓') : '✗'}',
                    style: uiStyle(context,
                        size: 11.5,
                        color: result.strokePass[i]
                            ? AppColors.ok
                            : AppColors.bad),
                  ),
                ),
              if (result.dotsExpected > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (result.dotsMatched >= result.dotsExpected
                            ? AppColors.ok
                            : AppColors.bad)
                        .withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.l10n
                        .dotsCountLabel(result.dotsMatched, result.dotsExpected),
                    style: uiStyle(context,
                        size: 11.5,
                        color: result.dotsMatched >= result.dotsExpected
                            ? AppColors.ok
                            : AppColors.bad),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent),
            onPressed: onRetry,
            child:  Text(context.l10n.traceAgain),
          ),
        ]),
      ),
    );
  }
}
