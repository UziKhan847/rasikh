import 'package:flutter/material.dart';

import '../../core/fluency/chunks.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/fluency/joins.dart';
import '../../core/fluency/words.dart';
import '../../core/l10n.dart';
import '../../core/marks/word_ref.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'passage_screen.dart' show PassageScreen, passageFrom;
import 'verse_review_screen.dart';

/// The Reader's fluency marking: a tap on a word marks it not fluent,
/// pairs it with the next word, or opens its split into stem and
/// attachments — whichever tool the bar has on.
enum FluencyTool { slow, pair, chunk }

/// What a tap on [ref] does with [tool] on.
void applyFluency(BuildContext context, FluencyTool tool, String script, WordRef ref) {
  final store = FluencyScope.read(context);
  if (store == null) return;
  switch (tool) {
    case FluencyTool.slow:
      store.toggleSlow(ref, formOf(script, ref));
    case FluencyTool.pair:
      togglePairAt(store, script, ref);
    case FluencyTool.chunk:
      showChunkEditor(context, script, ref);
  }
}

/// Pairs [ref] with the word after it (or unpairs it).
void togglePairAt(FluencyStore store, String script, WordRef ref) {
  final next = nextWordOf(script, ref);
  if (next == null) return;
  final a = formOf(script, ref), b = formOf(script, next);
  store.togglePair(ref, '$a $b', joinOf(a, b));
}

/// A join's name.
String joinLabel(BuildContext context, String join) => switch (join) {
      'wasl' => context.l10n.flJoinWasl,
      'idgham' => context.l10n.flJoinIdgham,
      'iqlab' => context.l10n.flJoinIqlab,
      'ikhfa' => context.l10n.flJoinIkhfa,
      _ => context.l10n.flJoinPlain,
    };

/// The bar while marking fluency: the three tools, a word of what a tap
/// does, and Done.
class FluencyBar extends StatelessWidget {
  final FluencyTool tool;
  final ValueChanged<FluencyTool> onTool;
  final VoidCallback onDone;
  const FluencyBar({super.key, required this.tool, required this.onTool, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: QSegmented<FluencyTool>(
            options: [
              (FluencyTool.slow, l.flSlow, null),
              (FluencyTool.pair, l.flPair, null),
              (FluencyTool.chunk, l.flChunk, null),
            ],
            value: tool,
            onChanged: onTool,
          ),
        ),
        const SizedBox(width: 8),
        QIconButton(icon: AppIcons.check, tooltip: l.rvDone, onTap: onDone),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          switch (tool) {
            FluencyTool.slow => l.flHintSlow,
            FluencyTool.pair => l.flHintPair,
            FluencyTool.chunk => l.flHintChunk,
          },
          textAlign: TextAlign.center,
          style: uiStyle(context, size: 12.5, color: p.ink3),
        ),
      ),
    ]);
  }
}

/// In a held word's sheet: its fluency marks, to set or clear.
class FluencyWordPanel extends StatelessWidget {
  final String script;
  final WordRef ref;
  const FluencyWordPanel({super.key, required this.script, required this.ref});

  @override
  Widget build(BuildContext context) {
    final store = FluencyScope.maybeOf(context);
    if (store == null) return const SizedBox.shrink();
    final l = context.l10n;
    final next = nextWordOf(script, ref);
    final pair = store.markAt(FluencyKind.pair, ref);
    final chunk = store.markAt(FluencyKind.chunk, ref);
    final form = formOf(script, ref);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QSectionLabel(l.flTool),
      QGroup(children: [
        QRow(
          title: l.flSlow,
          subtitle: l.flSlowSub,
          control: QSwitch(
              value: store.isSlow(ref), onChanged: (_) => store.toggleSlow(ref, form)),
        ),
        if (next != null)
          QRow(
            title: l.flPairWithNext,
            subtitle:
                '${joinLabel(context, joinOf(form, formOf(script, next)))} · ${formOf(script, next)}',
            control: QSwitch(
                value: pair != null, onChanged: (_) => togglePairAt(store, script, ref)),
          ),
        QRow(
          title: l.flSplit,
          subtitle: chunk == null ? l.flSplitSub : _splitShown(form, chunk.prefix, chunk.suffix),
          chevron: true,
          onTap: () => showChunkEditor(context, script, ref),
        ),
        QRow(
          title: l.vrFromHere,
          subtitle: l.vrSub,
          chevron: true,
          onTap: () {
            final nav = Navigator.of(context);
            final title = l.vrTitle;
            nav.pop();
            nav.push(MaterialPageRoute<void>(
                builder: (_) => VerseReviewScreen(ayahs: ayahsToSurahEnd(ref.globalAyah), title: title)));
          },
        ),
        QRow(
          title: l.psPractisePassage,
          subtitle: l.psPractisePassageSub,
          chevron: true,
          onTap: () {
            final (a, b) = passageFrom(script, ref.globalAyah);
            // Out of the word's sheet, then the passage (the sheet's own
            // context goes with it).
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => PassageScreen(from: a, to: b)));
          },
        ),
      ]),
    ]);
  }
}

String _splitShown(String form, int prefix, int suffix) {
  final (a, b, c) = splitText(form, prefix, suffix);
  return [a, b, c].where((x) => x.isNotEmpty).join(' · ');
}

/// Splits [ref] into prefix, stem and suffix: a suggestion to accept or
/// move, letter by letter.
Future<void> showChunkEditor(BuildContext context, String script, WordRef ref) {
  final store = FluencyScope.read(context);
  if (store == null) return Future.value();
  final form = formOf(script, ref);
  final have = store.markAt(FluencyKind.chunk, ref);
  var (prefix, suffix) = have != null ? (have.prefix, have.suffix) : suggestSplit(form);
  final letters = clustersOf(form).length;
  return showAdaptiveSheet<void>(
    context,
    builder: (sheet) => StatefulBuilder(builder: (sheet, set) {
      final l = sheet.l10n;
      final p = pal(sheet);
      final (a, b, c) = splitText(form, prefix, suffix);
      final big = TextStyle(fontFamily: MushafRepo.fontFamily(script), fontSize: 48, height: 1.9);
      Widget stepper(String label, int value, int max, ValueChanged<int> on) => Expanded(
            child: Column(children: [
              Text(label, style: uiStyle(sheet, size: 13, weight: FontWeight.w700, color: p.ink2)),
              const SizedBox(height: 6),
              QStepper(
                height: 40,
                label: '$value',
                minusTooltip: '−',
                plusTooltip: '+',
                minusChild: const Text('−'),
                plusChild: const Text('+'),
                onMinus: value <= 0 ? null : () => set(() => on(value - 1)),
                onPlus: value >= max ? null : () => set(() => on(value + 1)),
              ),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.flSplit, style: displayStyle(sheet, size: 22)),
            const SizedBox(height: 6),
            Text(l.flSplitSub, style: uiStyle(sheet, size: 13, color: p.ink3)),
            Center(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: a, style: big.copyWith(color: p.acc)),
                  TextSpan(text: b, style: big.copyWith(color: p.ink)),
                  TextSpan(text: c, style: big.copyWith(color: p.acc)),
                ]),
                textDirection: TextDirection.rtl,
              ),
            ),
            if (prefix > 0 || suffix > 0)
              Center(
                child: Text(
                    [if (a.isNotEmpty) a, b, if (c.isNotEmpty) c].join('  +  '),
                    textDirection: TextDirection.rtl,
                    style: big.copyWith(fontSize: 22, height: 1.6, color: p.ink2)),
              ),
            const SizedBox(height: 12),
            // Right to left as the word reads: the prefix's letters first.
            Row(textDirection: TextDirection.rtl, children: [
              stepper(l.flPrefix, prefix, letters - suffix - 1, (v) => prefix = v),
              const SizedBox(width: 16),
              stepper(l.flSuffix, suffix, letters - prefix - 1, (v) => suffix = v),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              if (have != null) ...[
                Expanded(
                  child: QOutlineButton(l.flRemove, onTap: () {
                    store.setChunk(ref, form, 0, 0);
                    Navigator.pop(sheet);
                  }),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: QPrimaryButton(l.mkSave,
                    onTap: prefix == 0 && suffix == 0
                        ? null
                        : () {
                            store.setChunk(ref, form, prefix, suffix);
                            Navigator.pop(sheet);
                          }),
              ),
            ]),
          ]),
        ),
      );
    }),
  );
}
