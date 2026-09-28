import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/tanwin_allographs.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import '../../widgets/common.dart' show starsForFraction;
import 'kids_sort_bins.dart';
import 'kids_widgets.dart';

/// Tanwīn's shape is a clue, not decoration: the muṣḥaf draws it one of three
/// ways, and which one tells a reader what to do with the sound —
/// [tanwinAllographs] already carries the shape ↔ rule link, reviewed against
/// the whole bundled corpus. This teaches that link to a child: one card per
/// shape, in plain "what does your voice do" language, then a sort — real
/// words, by which shape their own tanwīn is drawn in.
///
/// A drag-sort, like [KidsSortBins]'s other uses: drag a word into its bin, or
/// tap the word and then the bin.
class KidsTanwinShapesLesson extends StatefulWidget {
  final String progressId;
  const KidsTanwinShapesLesson({super.key, required this.progressId});

  @override
  State<KidsTanwinShapesLesson> createState() => _KidsTanwinShapesLessonState();
}

class _KidsTanwinShapesLessonState extends State<KidsTanwinShapesLesson> {
  static const _forms = ['parallel', 'alternate', 'iqlab'];
  int _step = 0; // 0..2 = the three shape cards; 3 = the sort
  int _correct = 0;
  bool _reported = false;

  bool get _done => _step > _forms.length;
  int get _stars => starsForFraction(_correct == 0 ? 0 : 1, kids: true);

  void _next() => setState(() => _step++);

  void _finishSort(bool firstTry) {
    _correct = firstTry ? 1 : 0;
    _next();
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
      index: _step,
      total: _forms.length + 1,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : _step < _forms.length
          ? _ShapeCard(
              key: ValueKey('tanwin.${_forms[_step]}'),
              form: _forms[_step],
              onNext: _next,
            )
          : _SortStep(onDone: _finishSort),
    );
  }
}

String _formName(BuildContext context, String form) => switch (form) {
  'parallel' => context.l10n.kidsTanwinParallelName,
  'alternate' => context.l10n.kidsTanwinAlternateName,
  _ => context.l10n.kidsTanwinIqlabName,
};

String _formHow(BuildContext context, String form) => switch (form) {
  'parallel' => context.l10n.kidsTanwinParallelHow,
  'alternate' => context.l10n.kidsTanwinAlternateHow,
  _ => context.l10n.kidsTanwinIqlabHow,
};

class _ShapeCard extends StatelessWidget {
  final String form;
  final VoidCallback onNext;
  const _ShapeCard({super.key, required this.form, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    // One example per form — fatḥatan's, since every form has one.
    final example = tanwinAllographs.firstWhere(
      (a) => a.form == form && a.tanwinId == 'fathatan',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(context.l10n.kidsTanwinShapesTitle,
            align: TextAlign.center),
        const SizedBox(height: 16),
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (form == tanwinAllographs.first.form)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        context.l10n.kidsTanwinShapesIntro,
                        textAlign: TextAlign.center,
                        style: kbText(17, kbC(ui.inkSoft),
                            weight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  Center(
                    child: Text(
                      example.highlight,
                      textDirection: TextDirection.rtl,
                      style: kbText(56, kbC(ui.linkInk),
                          family: kbFontQuran,
                          weight: FontWeight.w400,
                          height: 1.9),
                    ),
                  ),
                  Text(
                    _formName(context, form),
                    textAlign: TextAlign.center,
                    style: kbText(22, kbC(ui.ink), height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formHow(context, form),
                    textAlign: TextAlign.center,
                    style: kbText(17, kbC(ui.inkSoft),
                        weight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  KidsQuranWord(example.example,
                      highlight: example.highlight, size: 30),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

class _SortStep extends StatelessWidget {
  final void Function(bool firstTry) onDone;
  const _SortStep({required this.onDone});

  @override
  Widget build(BuildContext context) {
    // One word per (mark, form) — nine tiles, three per bin, over all three
    // tanwīn marks so the sort is not just about fatḥatan.
    final items = [
      for (final a in tanwinAllographs)
        KidsSortItem(
          id: a.id,
          label: a.example,
          bin: switch (a.form) {
            'parallel' => 0,
            'alternate' => 1,
            _ => 2,
          },
        ),
    ];
    return KidsSortBins(
      prompt: context.l10n.kidsTanwinSortPrompt,
      items: items,
      size: 22,
      bins: [
        KidsSortBin(emoji: '↔️', title: _formName(context, 'parallel')),
        KidsSortBin(emoji: '🔼', title: _formName(context, 'alternate')),
        KidsSortBin(emoji: 'م', title: _formName(context, 'iqlab')),
      ],
      onDone: onDone,
    );
  }
}
