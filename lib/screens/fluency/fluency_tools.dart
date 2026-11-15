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
import '../marks/marking.dart' show FluencyStep, MarkingController;

/// Fluency marking (Mark's fluency kind, in both views): a tap steps a word
/// on, as recitation marks' taps do.
enum FluencyTool { fluency }

/// What a tap on [ref] does in fluency marking: see [cycleFluency]. [undo]
/// keeps the step for undo and redo.
void applyFluency(BuildContext context, FluencyTool tool, String script, WordRef ref,
    {MarkingController? undo}) {
  final store = FluencyScope.read(context);
  if (store == null) return;
  final step = cycleFluency(store, script, ref);
  if (step != null) undo?.recordStep(step);
}

/// A word's fluency mark one step on: none → not fluent → paired with the
/// next word → a chunk (split as suggested) → none. A step it can't take (no
/// next word, a word too short to split) is passed over. The step, for undo.
FluencyStep? cycleFluency(FluencyStore store, String script, WordRef ref) {
  final before = store.snapshotAt(ref);
  final form = formOf(script, ref);
  final next = nextWordOf(script, ref);
  bool chunk() {
    var (p, x) = suggestSplit(form);
    if (p == 0 && x == 0) {
      // Nothing obvious to split off: the first letter, to be moved.
      if (clustersOf(form).length < 2) return false;
      p = 1;
    }
    store.setChunk(ref, form, p, x);
    return true;
  }

  if (store.markAt(FluencyKind.chunk, ref) != null) {
    store.setChunk(ref, form, 0, 0);
  } else if (store.markAt(FluencyKind.pair, ref) != null) {
    togglePairAt(store, script, ref);
    chunk();
  } else if (store.isSlow(ref)) {
    store.toggleSlow(ref, form);
    if (next != null) {
      togglePairAt(store, script, ref);
    } else {
      chunk();
    }
  } else {
    store.toggleSlow(ref, form);
  }
  return FluencyStep(store, before);
}

/// What fluency mark [ref] has, the step furthest on.
FluencyKind? fluencyKindAt(FluencyStore store, WordRef ref) =>
    store.markAt(FluencyKind.chunk, ref) != null
        ? FluencyKind.chunk
        : store.markAt(FluencyKind.pair, ref) != null
            ? FluencyKind.pair
            : store.isSlow(ref)
                ? FluencyKind.word
                : null;

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

/// The bar while marking fluency: what a tap does, the steps in order, undo
/// and redo, and Done.
class FluencyBar extends StatelessWidget {
  final VoidCallback onDone;
  final MarkingController? marking;

  /// The line of what a tap does (none where room is short).
  final bool hint;
  const FluencyBar({super.key, required this.onDone, this.marking, this.hint = true});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    Widget step(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: p.acc.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
          child: Text(t, style: uiStyle(context, size: 12.5, weight: FontWeight.w600)),
        );
    final arrow = Icon(AppIcons.chevronLeft, size: 14, color: p.ink3);
    final m = marking;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(textDirection: TextDirection.ltr, children: [
              step(l.flChunk),
              arrow,
              step(l.flPair),
              arrow,
              step(l.flSlow),
            ]),
          ),
        ),
        if (m != null)
          ListenableBuilder(
            listenable: m,
            builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: l.mkUndo,
                visualDensity: VisualDensity.compact,
                onPressed: m.canUndo ? () => m.undo(context) : null,
                icon: const Icon(AppIcons.undo),
              ),
            ]),
          ),
        QIconButton(icon: AppIcons.check, tooltip: l.rvDone, onTap: onDone),
      ]),
      if (hint)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l.mkFluencySub,
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 12.5, color: p.ink3)),
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
    // Compact, as the marks above it: a chip each, on or off at a tap.
    final p = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QSectionLabel(l.flTool),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilterChip(
          key: const ValueKey('fl-slow'),
          label: Text(l.flSlow),
          tooltip: l.flSlowSub,
          selected: store.isSlow(ref),
          onSelected: (_) => store.toggleSlow(ref, form),
        ),
        if (next != null)
          FilterChip(
            key: const ValueKey('fl-pair'),
            label: Text(l.flPairWithNext),
            tooltip: '${joinLabel(context, joinOf(form, formOf(script, next)))} · ${formOf(script, next)}',
            selected: pair != null,
            onSelected: (_) => togglePairAt(store, script, ref),
          ),
        ActionChip(
          key: const ValueKey('fl-split'),
          avatar: chunk == null ? null : Icon(Icons.check, size: 16, color: p.acc),
          label: Text(chunk == null ? l.flSplit : _splitShown(form, chunk.prefix, chunk.suffix)),
          tooltip: l.flSplitSub,
          onPressed: () => showChunkEditor(context, script, ref),
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
  final letters = clustersOf(form);
  final n = letters.length;
  // Which edge a tap between letters moves.
  var editing = 'prefix';
  return showAdaptiveSheet<void>(
    context,
    builder: (sheet) => StatefulBuilder(builder: (sheet, set) {
      final l = sheet.l10n;
      final p = pal(sheet);
      final family = MushafRepo.fontFamily(script);
      // Gap g sits before letter g (0: before the first, n: after the last).
      void tapGap(int g) => set(() {
            if (editing == 'prefix') {
              if (g < n - suffix) prefix = g;
            } else {
              if (n - g < n - prefix) suffix = n - g;
            }
          });
      Color tone(int i) =>
          i < prefix || i >= n - suffix ? p.acc : p.ink;
      Widget gap(int g) {
        final edge = (editing == 'prefix' && g == prefix) || (editing == 'suffix' && g == n - suffix);
        return GestureDetector(
          key: ValueKey('gap-$g'),
          behavior: HitTestBehavior.opaque,
          onTap: () => tapGap(g),
          child: Container(
            width: 26,
            height: 76,
            alignment: Alignment.center,
            child: Container(
              width: edge ? 4 : 2,
              height: edge ? 64 : 40,
              decoration: BoxDecoration(
                color: edge ? p.acc : p.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }

      final row = <Widget>[];
      for (var i = 0; i < n; i++) {
        if (i > 0) row.add(gap(i));
        final c = letters[i];
        row.add(Text('${c.base}${c.marks}',
            style: TextStyle(fontFamily: family, fontSize: 46, height: 1.7, color: tone(i))));
      }
      final (a, b, c) = splitText(form, prefix, suffix);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.flSplit, style: displayStyle(sheet, size: 22)),
            const SizedBox(height: 6),
            Text(l.flSplitTap, style: uiStyle(sheet, size: 13, color: p.ink3)),
            const SizedBox(height: 10),
            QSegmented<String>(
              options: [
                ('prefix', l.flPrefixEdge, null),
                ('suffix', l.flSuffixEdge, null),
              ],
              value: editing,
              onChanged: (v) => set(() => editing = v),
            ),
            const SizedBox(height: 8),
            // The word large, letter by letter, right to left: a tap between
            // two puts the chosen edge there.
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(textDirection: TextDirection.rtl, children: row),
              ),
            ),
            if (prefix > 0 || suffix > 0)
              Center(
                child: Text([if (a.isNotEmpty) a, b, if (c.isNotEmpty) c].join('  +  '),
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: family, fontSize: 22, height: 1.6, color: p.ink2)),
              ),
            const SizedBox(height: 14),
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
