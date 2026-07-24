import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/qiraat.dart';
import '../widgets/common.dart';

/// 🕌 Qirā'āt Hall — advanced mode. The ten canonical readings: who, what
/// makes each distinctive, and famous side-by-side differences with the
/// Ḥafṣ transmission most learners know.
class QiraatScreen extends StatelessWidget {
  const QiraatScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title:  Text(context.l10n.qiraHallAdvanced)),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal(context).accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: pal(context).accent.withValues(alpha: .4)),
            ),
            child: Text(
              context.l10n.qiraAreMassTransmittedReadings,
              style: uiStyle(context, size: 13.5, color: pal(context).textDim),
            ),
          ),
           SectionHeader(context.l10n.theTenReaders,
              subtitle: context.l10n.eachTwoFamousTransmittersRawis),
          for (var i = 0; i < qiraat.length; i++)
            FadeSlideIn(delayMs: 35 * i, child: _ReaderCard(q: qiraat[i], index: i)),
           SectionHeader(context.l10n.hearTheDifference,
              subtitle: context.l10n.famousVariantsSideSideHafs),
          for (var i = 0; i < qiraatDifferences.length; i++)
            FadeSlideIn(
                delayMs: 35 * i, child: _DiffCard(d: qiraatDifferences[i])),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: pal(context).accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => pushAdaptive(context, _qiraatQuiz(context)),
            icon: const Icon(Icons.quiz_rounded),
            label:  Text(context.l10n.qiraAtQuiz),
          ),
        ],
      )),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  final Qiraah q;
  final int index;
  const _ReaderCard({required this.q, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal(context).surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: pal(context).accent.withValues(alpha: .5)),
                ),
                child: Text('${index + 1}',
                    style: uiStyle(context, size: 16, weight: FontWeight.w800,
                        color: pal(context).accent)),
              ),
              title: Text(q.reader,
                  style: uiStyle(context, size: 16, weight: FontWeight.w700)),
              subtitle: Text('${q.city} · d. ${q.died} AH',
                  style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
              trailing: Text(q.arabic,
                  textDirection: TextDirection.rtl,
                  style: arabicStyle(context, size: 20, height: 1.4,
                      color: pal(context).accent)),
              children: [
                if (q.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(q.bio,
                        style: uiStyle(context, size: 13.5)
                            .copyWith(height: 1.5)),
                  ),
                Row(children: [
                  _rawi(context, q.rawi1),
                  const SizedBox(width: 8),
                  _rawi(context, q.rawi2),
                ]),
                const SizedBox(height: 10),
                for (final s in q.signatures)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(Icons.brightness_1,
                              size: 6, color: pal(context).accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s,
                                style: uiStyle(context,
                                    size: 13.5, color: pal(context).textDim))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rawi(BuildContext context, String name) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pal(context).surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(name,
              style: uiStyle(context, size: 13.5, weight: FontWeight.w600)),
        ),
      );
}

class _DiffCard extends StatelessWidget {
  final QiraatDifference d;
  const _DiffCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pal(context).accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(d.ref,
                    style: uiStyle(context, size: 12.5,
                        color: pal(context).accent, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(d.topic,
                  style: uiStyle(context, size: 13.5,
                      color: pal(context).textDim, weight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            _variantRow(context, 'Ḥafṣ', d.hafs, pal(context).accent),
            const SizedBox(height: 8),
            _variantRow(
                context, context.l10n.variantLabel, d.variant, AppColors.lilac),
            const SizedBox(height: 10),
            Text(context.l10n.readByName(d.readBy),
                style: uiStyle(context, size: 12.5,
                    color: pal(context).accent, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(d.note,
                style: uiStyle(context, size: 13, color: pal(context).textDim)),
          ],
        ),
      ),
    );
  }

  Widget _variantRow(
          BuildContext context, String label, String text, Color color) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4, height: 38,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 56,
              child: Text(label,
                  style: uiStyle(context, size: 12, color: color,
                      weight: FontWeight.w700))),
          Expanded(
            child: Text(text,
                textDirection: TextDirection.rtl,
                style: arabicStyle(context, size: 22, height: 1.6)),
          ),
        ],
      );
}

QuizScreen _qiraatQuiz(BuildContext context) {
  final rng = math.Random();
  final readerPool = qiraat.map((q) => q.reader).toList();
  final qs = <QuizQuestion>[];
  {
    final o = buildOptions('Ḥafṣ ‘an ‘Āṣim',
        ['Warsh ‘an Nāfi‘', 'Qālūn ‘an Nāfi‘', 'Ad-Dūrī ‘an Abī ‘Amr', 'Ḥafṣ ‘an ‘Āṣim'], rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpWhoseTransmission,
        options: o.options,
        correct: o.correct));
  }
  // match rāwī → reader
  final sample = [...qiraat]..shuffle(rng);
  for (final q in sample.take(5)) {
    final rawi = rng.nextBool() ? q.rawi1 : q.rawi2;
    final o = buildOptions(q.reader, readerPool, rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpRawiTransmitsFrom(rawi),
        options: o.options,
        correct: o.correct));
  }
  // differences
  for (final d in ([...qiraatDifferences]..shuffle(rng)).take(4)) {
    final o = buildOptions(d.topic,
        qiraatDifferences.map((x) => x.topic).toSet().toList(), rng);
    qs.add(QuizQuestion(
        prompt: context.l10n.qpReadingsDifferIn(d.ref),
        arabic: d.hafs,
        options: o.options,
        correct: o.correct,
        explain: d.note));
  }
  return QuizScreen(
      title: context.l10n.qiraAtQuiz, progressId: 'qiraat.quiz', questions: qs);
}
