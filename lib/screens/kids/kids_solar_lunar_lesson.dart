import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/extra_letters.dart' show letterForAny;
import '../../data/glyph_names.dart' show letterName;
import '../../data/wasl.dart';
import '../../widgets/common.dart' show MediaRow, starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_checkpoint_quiz.dart' show kidsCheckpointEvery;
import 'kids_sort_bins.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

sealed class _Step {
  const _Step();
}

class _IntroStep extends _Step {
  const _IntroStep();
}

class _LetterStep extends _Step {
  final WaslItem item;
  const _LetterStep(this.item);
}

class _SortStep extends _Step {
  final List<WaslItem> pool;
  const _SortStep(this.pool);
}

/// Sun and Moon letters, step by step and by ear — not the reused Tajwīd
/// rule page (a prose explanation plus a 14+14 letter-chip grid, with no
/// audio or sequence to it). Solar and lunar letters alternate through the
/// walk (`waslOfKind('solar'|'lunar')`, interleaved) so every few-letter
/// stretch — and every check-up — actually contrasts the two, rather than
/// running all fourteen of one kind before the other ever shows up.
///
/// The rule itself: a sun letter swallows the lām and doubles itself
/// (a shaddah stands in for it — `ٱلشَّمۡس` is a sun letter's own name-word);
/// a moon letter lets the lām stay silent but sounded, sukūn and all
/// (`ٱلۡقَمَر`, likewise). Every step's real Qurʼānic example is played
/// through the app's own verse audio (`MediaRow`) — this is a real word in
/// a real āyah, not a claim about a single letter's sound, so the verse
/// fallback the letter-audio fix removed does not apply here.
class KidsSolarLunarLesson extends StatefulWidget {
  final String progressId;

  /// The stage's Test: no letter cards, just three "sun or moon?" sorts over
  /// letters drawn from the whole alphabet.
  final bool quiz;
  const KidsSolarLunarLesson({
    super.key,
    required this.progressId,
    this.quiz = false,
  });

  @override
  State<KidsSolarLunarLesson> createState() => _KidsSolarLunarLessonState();
}

class _KidsSolarLunarLessonState extends State<KidsSolarLunarLesson> {
  late final List<WaslItem> _items = () {
    final solar = waslOfKind('solar');
    final lunar = waslOfKind('lunar');
    final out = <WaslItem>[];
    for (var i = 0; i < solar.length && i < lunar.length; i++) {
      out.add(solar[i]);
      out.add(lunar[i]);
    }
    return out;
  }();

  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    if (widget.quiz) {
      // Every sort has BOTH kinds in it — a bin that only ever gets one kind
      // would be a giveaway, not a test — three of one and two of the other,
      // alternating which is the bigger bin.
      final solar = [..._items.where((w) => w.kind == 'solar')]..shuffle(_rng);
      final lunar = [..._items.where((w) => w.kind == 'lunar')]..shuffle(_rng);
      return [
        for (var i = 0; i < 3; i++)
          _SortStep(
            ([
              ...solar.skip(i * 3).take(i.isEven ? 3 : 2),
              ...lunar.skip(i * 3).take(i.isEven ? 2 : 3),
            ]..shuffle(_rng)),
          ),
      ];
    }
    final out = <_Step>[const _IntroStep()];
    for (var i = 0; i < _items.length; i++) {
      out.add(_LetterStep(_items[i]));
      final done = i + 1;
      if (done % kidsCheckpointEvery == 0 && done != _items.length) {
        out.add(
          _SortStep(
            _items.sublist(math.max(0, done - kidsCheckpointEvery), done),
          ),
        );
      }
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

  void _answerSort(bool correct) {
    _total++;
    if (correct) _correct++;
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
              _IntroStep() => _IntroCard(onNext: _advance),
              _LetterStep(:final item) => _LetterCard(
                key: ValueKey(item.id),
                item: item,
                onNext: _advance,
              ),
              _SortStep(:final pool) => _SortCard(
                key: ValueKey('sort.${pool.first.id}'),
                pool: pool,
                onDone: _answerSort,
              ),
            },
    );
  }
}

/// The mnemonic itself: sun letters (ٱلشَّمۡس) swallow the lām; moon letters
/// (ٱلۡقَمَر) let it through — the two words the rule takes its own name from.
class _IntroCard extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(context.l10n.kidsBlockSolarLunar),
        const SizedBox(height: Geo.gapMd),
        Expanded(
          // Side by side when there is room, but a 320px phone gives each
          // tile ~105px: the Arabic word plus a wrapped caption needs about
          // 400px of height there. So a narrow screen stacks the two tiles
          // and lets the pair scroll rather than clipping the caption.
          child: LayoutBuilder(
            builder: (context, box) {
              final sun = _MnemonicTile(
                emoji: '☀️',
                word: 'ٱلشَّمۡس',
                caption: context.l10n.kidsSolarHidesLam,
              );
              final moon = _MnemonicTile(
                emoji: '🌙',
                word: 'ٱلۡقَمَر',
                caption: context.l10n.kidsLunarKeepsLam,
              );
              if (box.maxWidth >= 420) {
                return Row(
                  children: [
                    Expanded(child: sun),
                    const SizedBox(width: Geo.gapMd),
                    Expanded(child: moon),
                  ],
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sun,
                    const SizedBox(height: Geo.gapMd),
                    moon,
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

class _MnemonicTile extends StatelessWidget {
  final String emoji;
  final String word;
  final String caption;
  const _MnemonicTile({
    required this.emoji,
    required this.word,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsLessonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: Geo.gapSm),
          Text(
            word,
            textDirection: TextDirection.rtl,
            style: kbText(30, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
          ),
          const SizedBox(height: Geo.gapSm),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// One letter's turn: which kind it is, its ٱل-combined shape, and a real
/// example word from the muṣḥaf to hear it in — via [MediaRow], the app's
/// existing verse player, since this is genuine word-in-context audio.
class _LetterCard extends StatelessWidget {
  final WaslItem item;
  final VoidCallback onNext;
  const _LetterCard({super.key, required this.item, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final isSolar = item.kind == 'solar';
    final name = letterName(context, letterForAny(item.letter)!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(isSolar
              ? context.l10n.kidsSunLetterIs(name)
              : context.l10n.kidsMoonLetterIs(name), fontSize: 26),
        const SizedBox(height: Geo.gapMd),
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSolar ? '☀️' : '🌙',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    item.example,
                    textDirection: TextDirection.rtl,
                    style: kbText(32, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    isSolar
                        ? context.l10n.kidsSolarHidesLam
                        : context.l10n.kidsLunarKeepsLam,
                    textAlign: TextAlign.center,
                    style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapSm),
        Center(child: MediaRow(ref: item.ref)),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

/// The check-up: sort [pool] — always a mix of both kinds, since the walk
/// interleaves them — into the sun and the moon.
class _SortCard extends StatelessWidget {
  final List<WaslItem> pool;
  final void Function(bool correct) onDone;
  const _SortCard({super.key, required this.pool, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return KidsSortBins(
      prompt: context.l10n.kidsSortSunMoon,
      items: [
        for (final item in pool)
          KidsSortItem(
            id: item.id,
            label: item.kind == 'solar'
                ? 'ٱل${item.letter}ّ'
                : 'ٱلۡ${item.letter}',
            bin: item.kind == 'solar' ? 0 : 1,
          ),
      ],
      bins: [
        KidsSortBin(emoji: '☀️', title: context.l10n.kidsSunLetters),
        KidsSortBin(emoji: '🌙', title: context.l10n.kidsMoonLetters),
      ],
      onDone: onDone,
    );
  }
}
