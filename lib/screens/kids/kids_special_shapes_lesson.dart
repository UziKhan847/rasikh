import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/special_shapes.dart';
import '../../widgets/common.dart'
    show buildOptions, highlightSpans, pickN, starsForFraction;
import '../../widgets/lesson.dart' show shapeSvg;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsSpecialShapesLesson]: meet a hand-drawn
/// shape, or pick it out from a real word / from a lookalike.
sealed class _Step {
  const _Step();
}

class _ShapeStep extends _Step {
  final SpecialShape shape;
  const _ShapeStep(this.shape);
}

class _CheckStep extends _Step {
  final SpecialShape answer;
  final List<SpecialShape> options;
  const _CheckStep({required this.answer, required this.options});
}

/// The muṣḥaf's hand-drawn compound shapes — lām+alif, kāf's wrap, stacked
/// letters, and the height/tail shifts — one shape at a time, each with its
/// own real word to spot it in and its own `tellApart` note, ending on a
/// "which shape is this?" recognition check. Reuses the SAME 20 hand-traced
/// SVGs and [SpecialShape] data the grown-up Joining Forms page uses (via
/// the shared [shapeSvg] renderer, `lib/widgets/lesson.dart`) — nothing new
/// is drawn — but never opens that adult page itself: this stage used to
/// push `lessonEntryScreen` straight into Kids Mode, a bug found on a real
/// device (Kids Mode is supposed to never leave its own presentation).
class KidsSpecialShapesLesson extends StatefulWidget {
  final String group; // 'ligature' | 'kaf' | 'stacking' | 'tails'
  final String progressId;
  const KidsSpecialShapesLesson({
    super.key,
    required this.group,
    required this.progressId,
  });

  @override
  State<KidsSpecialShapesLesson> createState() =>
      _KidsSpecialShapesLessonState();
}

class _KidsSpecialShapesLessonState extends State<KidsSpecialShapesLesson> {
  late final List<SpecialShape> _shapes = specialShapes
      .where((s) => s.group == widget.group)
      .toList();
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    final out = <_Step>[for (final s in _shapes) _ShapeStep(s)];
    final chosen = pickN(_shapes, math.min(3, _shapes.length), _rng);
    for (final answer in chosen) {
      final poolIds = [for (final other in _shapes) other.id]
        ..remove(answer.id);
      final built = buildOptions(answer.id, poolIds, _rng, count: 4);
      out.add(
        _CheckStep(
          answer: answer,
          options: [for (final id in built.options) shapeById(id)],
        ),
      );
    }
    return out;
  }

  int _index = 0;
  int _correct = 0;
  int _total = 0;
  bool _reported = false;

  bool get _done => _index >= _steps.length;

  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_correct / _total, kids: true);

  void _advance() => setState(() => _index++);

  void _answerCheck(bool firstTry) {
    _total++;
    if (firstTry) _correct++;
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    if (_done && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _stars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: _steps.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : switch (_steps[_index]) {
              _ShapeStep(:final shape) => _ShapeCard(
                key: ValueKey(shape.id),
                shape: shape,
                onNext: _advance,
              ),
              _CheckStep(:final answer, :final options) => _CheckCard(
                key: ValueKey('check.${answer.id}'),
                answer: answer,
                options: options,
                onDone: _answerCheck,
              ),
            },
    );
  }
}

String _formCaption(BuildContext context, ShapeForm f) => f.position != null
    ? switch (f.position!) {
        ShapePosition.isolated => context.l10n.formAlone,
        ShapePosition.beginning => context.l10n.formStart,
        ShapePosition.middle => context.l10n.formMiddle,
        ShapePosition.ending => context.l10n.formEnd,
      }
    : f.label;

class _ShapeCard extends StatelessWidget {
  final SpecialShape shape;
  final VoidCallback onNext;
  const _ShapeCard({super.key, required this.shape, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final example = shape.examples.isNotEmpty ? shape.examples.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          shape.title,
          style: kidsStyle(context, size: 19, weight: FontWeight.w800),
        ),
        const SizedBox(height: Geo.gapSm),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(Geo.gapLg),
              decoration: kidsCard(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: shapeSvg(
                      context,
                      shape.forms.first.asset,
                      mm: shapeSvgMm[shape.forms.first.asset]!,
                      boxSide: 80,
                      color: p.accent,
                    ),
                  ),
                  if (shape.forms.length > 1) ...[
                    const SizedBox(height: Geo.gapMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final f in shape.forms) ...[
                          Column(
                            children: [
                              shapeSvg(
                                context,
                                f.asset,
                                mm: shapeSvgMm[f.asset]!,
                                boxSide: 36,
                                color: p.text,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formCaption(context, f),
                                style: kidsStyle(context, size: 10),
                              ),
                            ],
                          ),
                          if (f != shape.forms.last)
                            const SizedBox(width: Geo.gapMd),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    shape.note,
                    textAlign: TextAlign.center,
                    style: kidsStyle(context, size: 13, color: p.textDim),
                  ),
                  if (example != null) ...[
                    const SizedBox(height: Geo.gapMd),
                    RichText(
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: highlightSpans(
                          example.word,
                          example.highlight,
                          quranicStyle(context, size: 28),
                          quranicStyle(context, size: 28, color: p.accent),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Geo.gapMd),
                  Container(
                    padding: const EdgeInsets.all(Geo.gapSm),
                    decoration: BoxDecoration(
                      color: p.accent2.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(Geo.radiusMd),
                    ),
                    child: Text(
                      shape.tellApart,
                      textAlign: TextAlign.center,
                      style: kidsStyle(context, size: 12, color: p.accent2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onNext,
          child: Text(context.l10n.kidsNextCard),
        ),
      ],
    );
  }
}

class _CheckCard extends StatelessWidget {
  final SpecialShape answer;
  final List<SpecialShape> options;
  final void Function(bool firstTry) onDone;
  const _CheckCard({
    super.key,
    required this.answer,
    required this.options,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return KidsChoiceCard(
      prompt: context.l10n.kidsWhichShapeIsThis(answer.title),
      options: [
        for (final option in options)
          shapeSvg(
            context,
            option.forms.first.asset,
            mm: shapeSvgMm[option.forms.first.asset]!,
            boxSide: 56,
            color: p.text,
          ),
      ],
      correct: options.indexWhere((o) => o.id == answer.id),
      aspect: 1.3,
      // What tells this shape from the ones it is confused with.
      explain: answer.tellApart,
      onDone: onDone,
    );
  }
}
