import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show tashkilName, tashkilNote;
import '../../data/tashkeel.dart' show tashkil;
import '../../data/wasl.dart';
import '../../widgets/common.dart' show MediaRow, pickN, starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsWaslLesson]: meet the waṣl rule itself, meet
/// one of the two "zero" signs, meet the tanwīn seam, or check whether a
/// zero sign ever makes a sound.
sealed class _Step {
  const _Step();
}

class _RuleStep extends _Step {
  const _RuleStep();
}

class _ZeroKindStep extends _Step {
  final String kind; // 'zero_rect' | 'zero_round'
  const _ZeroKindStep(this.kind);
}

class _TanwinStep extends _Step {
  const _TanwinStep();
}

class _CheckStep extends _Step {
  final WaslItem answer;
  const _CheckStep(this.answer);
}

/// What happens at the seam between two words, one idea at a time — hamzat
/// al-waṣl itself, the rectangular zero, the round zero, and tanwīn meeting
/// a waṣl alif — rather than the reused Learn page's six-row list (of which
/// two rows, solar and lunar letters, are ALSO covered on their own already,
/// see `KidsSolarLunarLesson`, taught where sun/moon letters actually sit in
/// a Qāʿidah — right after ٱل — so this lesson does not repeat them).
class KidsWaslLesson extends StatefulWidget {
  final String progressId;

  /// The stage's Test: no teaching cards, just "does this sign ever sound?"
  /// checks over every real example of the two zero signs.
  final bool quiz;
  const KidsWaslLesson({
    super.key,
    required this.progressId,
    this.quiz = false,
  });

  @override
  State<KidsWaslLesson> createState() => _KidsWaslLessonState();
}

class _KidsWaslLessonState extends State<KidsWaslLesson> {
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    final zeros = [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')];
    if (widget.quiz) {
      // Every example, not just the headline one of each sign — the same
      // sign in a different word is what proves it was understood.
      // Each gets its own id: the check card is keyed by it, and two checks
      // in a row with one key would reuse the first's already-answered State.
      final all = [
        for (final z in zeros) ...[
          z,
          for (final (k, (word, ref, hl)) in z.moreExamples.indexed)
            WaslItem('${z.id}.${k + 1}', z.kind, z.letter, word, ref, hl),
        ],
      ];
      return [
        for (final z in pickN(all, math.min(kidsQuizLength, all.length), _rng))
          _CheckStep(z),
      ];
    }
    final checks = pickN(zeros, math.min(3, zeros.length), _rng);
    return [
      const _RuleStep(),
      const _ZeroKindStep('zero_rect'),
      const _ZeroKindStep('zero_round'),
      const _TanwinStep(),
      for (final z in checks) _CheckStep(z),
    ];
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
              _RuleStep() => _RuleCard(onNext: _advance),
              _ZeroKindStep(:final kind) => _ZeroCard(
                key: ValueKey(kind),
                kind: kind,
                onNext: _advance,
              ),
              _TanwinStep() => _TanwinCard(onNext: _advance),
              _CheckStep(:final answer) => _CheckCard(
                key: ValueKey('check.${answer.id}'),
                item: answer,
                onDone: _answerCheck,
              ),
            },
    );
  }
}

class _ConceptShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onNext;
  const _ConceptShell({required this.child, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: child,
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final VoidCallback onNext;
  const _RuleCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final mark = tashkil.firstWhere((t) => t.id == 'wasl');
    final concept = waslOfKind('wasl').first;
    return _ConceptShell(
      onNext: onNext,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mark.mark,
            textDirection: TextDirection.rtl,
            style: kbText(40, kbC(ui.linkInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            tashkilName(context, mark),
            style: kbText(21, kbC(ui.ink)),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            tashkilNote(context, mark),
            textAlign: TextAlign.center,
            style: kbText(18, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: Geo.gapMd),
          Text(
            concept.example,
            textDirection: TextDirection.rtl,
            style: kbText(26, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
          const SizedBox(height: Geo.gapSm),
          MediaRow(ref: concept.ref),
        ],
      ),
    );
  }
}

class _ZeroCard extends StatelessWidget {
  final String kind;
  final VoidCallback onNext;
  const _ZeroCard({super.key, required this.kind, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final items = waslOfKind(kind);
    final title = kind == 'zero_rect'
        ? context.l10n.zeroRectTitle
        : context.l10n.zeroRoundTitle;
    final note = kind == 'zero_rect'
        ? context.l10n.zeroRectNote
        : context.l10n.zeroRoundNote;
    return _ConceptShell(
      onNext: onNext,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            items.first.highlight,
            textDirection: TextDirection.rtl,
            style: kbText(36, kbC(ui.linkInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            title,
            style: kbText(21, kbC(ui.ink)),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            note,
            textAlign: TextAlign.center,
            style: kbText(18, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: Geo.gapMd),
          for (final w in items) ...[
            Text(
              w.example,
              textDirection: TextDirection.rtl,
              style: kbText(24, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
            ),
            const SizedBox(height: 2),
            MediaRow(ref: w.ref),
            const SizedBox(height: Geo.gapSm),
          ],
        ],
      ),
    );
  }
}

class _TanwinCard extends StatelessWidget {
  final VoidCallback onNext;
  const _TanwinCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final concept = waslOfKind('tanwin_wasl').first;
    return _ConceptShell(
      onNext: onNext,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.tanwinMeetsWaslTitle,
            style: kbText(21, kbC(ui.ink)),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            context.l10n.tanwinMeetsWaslNote,
            textAlign: TextAlign.center,
            style: kbText(18, kbC(ui.ink), weight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: Geo.gapMd),
          Text(
            concept.example,
            textDirection: TextDirection.rtl,
            style: kbText(24, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
          const SizedBox(height: Geo.gapSm),
          MediaRow(ref: concept.ref),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final WaslItem item;
  final void Function(bool firstTry) onDone;
  const _CheckCard({super.key, required this.item, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final rect = item.kind == 'zero_rect';
    // Two options, so no second try — the pick would be a guess — but the
    // answer always comes with why: what each zero does.
    return KidsChoiceCard(
      prompt: context.l10n.kidsWaslZeroCheckPrompt,
      display: KidsLessonCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          item.example,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: kbText(26, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
      options: [
        for (final label in [
          context.l10n.kidsWaslZeroYesOnStop,
          context.l10n.kidsWaslZeroNeverSounds,
        ])
          Text(
            label,
            textAlign: TextAlign.center,
            style: kbText(18, kbC(ui.ink), weight: FontWeight.w700),
          ),
      ],
      correct: rect ? 0 : 1,
      columns: 1,
      explain: rect ? context.l10n.zeroRectNote : context.l10n.zeroRoundNote,
      onDone: onDone,
    );
  }
}
