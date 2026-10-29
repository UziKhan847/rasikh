import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio.dart';
import '../../core/fluency/chunks.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/l10n.dart';
import '../../core/marks/qc_words.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/fluency_tiers.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'fluency_tools.dart' show joinLabel;

/// The fluency plan's flashcards: a word (a pair, a chunked word) at a
/// time, read aloud, then rated — instant, slow or wrong. Slow and wrong
/// come back in the same session until they're instant; only the first
/// rating counts towards retiring a card (instant in three separate
/// sessions).

/// Which cards a deck holds.
enum Deck { warmup, words, pairs, chunks, tier1, tier2, tier3 }

/// One card.
class FluencyCard {
  final String id;
  final String text;

  /// Under it: a pair's join, a tier word's list spelling.
  final String? note;

  /// A chunked word: its prefix and suffix letters.
  final (int, int)? chunk;

  /// Its words, to hear.
  final List<WordRef> words;
  const FluencyCard(this.id, this.text, {this.note, this.chunk, this.words = const []});
}

/// The plan's tier for [week]: 1 (weeks 1–3), 2 (4–6), 3 (7–9); none past.
int? tierOfWeek(int week) => week <= 0
    ? 1
    : week <= 3
        ? 1
        : week <= 6
            ? 2
            : week <= 9
                ? 3
                : null;

/// [deck]'s cards, the ones due first: last read slow or wrong, then never
/// seen, then the longest unseen; retired cards left out.
List<FluencyCard> deckCards(BuildContext context, FluencyStore store, String script, Deck deck,
    {int limit = 25}) {
  final out = <FluencyCard>[];
  final seen = <String>{};
  void add(FluencyCard c) {
    if (seen.add(c.id) && !(store.progressOf(c.id)?.retired ?? false)) out.add(c);
  }

  List<WordRef> refsAt(int tok, int n) {
    final refs = <WordRef>[];
    var t = tok;
    while (refs.length < n && t < MushafRepo.tokenCount(script)) {
      final (g, w) = MushafRepo.tokenAt(script, t++);
      if (w >= 0) refs.add(WordRef.fromGlobal(g, w));
    }
    return refs;
  }

  void tier(int t) {
    for (final w in tierWords(script).where((w) => w.tier == t)) {
      add(FluencyCard(w.cardId, w.form, words: refsAt(w.firstTok, w.words)));
    }
  }

  void words() {
    for (final m in store.marksOf(FluencyKind.word)) {
      add(FluencyCard(m.cardId, m.form, words: [m.ref]));
    }
  }

  switch (deck) {
    case Deck.warmup:
      words();
      if (tierOfWeek(store.week) case final t?) tier(t);
    case Deck.words:
      words();
    case Deck.pairs:
      for (final m in store.marksOf(FluencyKind.pair)) {
        add(FluencyCard(m.cardId, m.form,
            note: joinLabel(context, m.join), words: [m.ref, ...refsAt(_tokAfter(script, m.ref), 1)]));
      }
    case Deck.chunks:
      for (final m in store.marksOf(FluencyKind.chunk)) {
        add(FluencyCard(m.cardId, m.form, chunk: (m.prefix, m.suffix), words: [m.ref]));
      }
    case Deck.tier1:
      tier(1);
    case Deck.tier2:
      tier(2);
    case Deck.tier3:
      tier(3);
  }
  int rank(FluencyCard c) {
    final p = store.progressOf(c.id);
    if (p == null) return 1;
    return p.last == Recall.instant ? 2 : 0;
  }

  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (store.progressOf(a.id)?.lastSeen ?? 0).compareTo(store.progressOf(b.id)?.lastSeen ?? 0);
  });
  return out.take(limit).toList();
}

int _tokAfter(String script, WordRef r) => MushafRepo.tokenOf(script, r.globalAyah, r.word0) + 1;

/// Plays [words]: together if they're one āyah's, in a row; else the first.
void playFluencyWords(List<WordRef> words) {
  if (words.isEmpty) return;
  final a = words.first;
  final qc = qcWordOf(a.globalAyah, a.word0) + 1;
  final sameAyah = words.every((w) => w.surah == a.surah && w.ayah == a.ayah);
  if (words.length > 1 && sameAyah) {
    final last = qcWordOf(a.globalAyah, words.last.word0) + 1;
    WbwAudio.instance.playWords(a.surah, a.ayah, qc, last, (_) {});
  } else {
    WbwAudio.instance.playWord(a.surah, a.ayah, qc);
  }
}

class DeckScreen extends StatefulWidget with DesktopAware {
  final Deck deck;
  final String title;

  /// The plan block it counts as, once done ('warmup', 'chunks').
  final String? block;
  const DeckScreen({super.key, required this.deck, required this.title, this.block});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  List<FluencyCard>? _queue;
  int _total = 0;
  int _at = 0;
  final Set<String> _rated = {};
  final Map<Recall, int> _tally = {for (final r in Recall.values) r: 0};
  Recall? _shown; // this card's rating, once given
  bool _whole = false; // a chunk card: the whole word shown
  final _clock = Stopwatch();
  Timer? _tick;
  final _focus = FocusNode();

  String get _script => SettingsScope.of(context).mushafScript;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final store = FluencyScope.read(context);
    if (store == null) return;
    MushafRepo.ensure(_script).then((_) {
      if (!mounted) return;
      setState(() {
        _queue = deckCards(context, store, _script, widget.deck);
        _total = _queue!.length;
      });
      _start();
    });
  }

  void _start() {
    _shown = null;
    _whole = false;
    _clock
      ..reset()
      ..start();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _clock.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _focus.dispose();
    WbwAudio.instance.stop();
    super.dispose();
  }

  FluencyCard? get _card {
    final q = _queue;
    return q == null || _at >= q.length ? null : q[_at];
  }

  void _rate(Recall r) {
    final c = _card;
    if (c == null || _shown != null) return;
    _clock.stop();
    final store = FluencyScope.read(context)!;
    // Only the first reading in a session counts.
    if (_rated.add(c.id)) {
      store.rate(c.id, r);
      _tally[r] = _tally[r]! + 1;
    }
    // Not yet instant: it comes back at the end.
    if (r != Recall.instant) _queue!.add(c);
    setState(() => _shown = r);
  }

  void _next() {
    if (_shown == null) return;
    setState(() => _at++);
    if (_card == null) {
      _tick?.cancel();
      if (widget.block case final b?) FluencyScope.read(context)?.blockDone(b);
    } else {
      _start();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    // 1, 2, 3: instant, slow, wrong; H: hear it; Space or Enter: on.
    if (k == LogicalKeyboardKey.digit1) {
      _rate(Recall.instant);
    } else if (k == LogicalKeyboardKey.digit2) {
      _rate(Recall.slow);
    } else if (k == LogicalKeyboardKey.digit3) {
      _rate(Recall.wrong);
    } else if (k == LogicalKeyboardKey.keyH) {
      playFluencyWords(_card?.words ?? const []);
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      if (_card?.chunk != null && !_whole) {
        setState(() => _whole = true);
      } else {
        _next();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final q = _queue;
    final c = _card;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: q == null
              ? Center(child: CircularProgressIndicator(color: p.acc))
              : q.isEmpty
                  ? _empty(context)
                  : c == null
                      ? _summary(context)
                      : QColumn(child: _cardView(context, c)),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.flDeckEmpty,
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 15, color: pal(context).ink2)),
        ),
      );

  Widget _summary(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    return Center(
      child: QColumn(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.flDeckDone, style: displayStyle(context, size: 26)),
            const SizedBox(height: 16),
            Text(
                l.flDeckTally(_tally[Recall.instant]!, _tally[Recall.slow]!, _tally[Recall.wrong]!),
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 15, color: p.ink2)),
            const SizedBox(height: 24),
            QPrimaryButton(l.rvDone, onTap: () => Navigator.maybePop(context)),
          ]),
        ),
      ),
    );
  }

  Widget _cardView(BuildContext context, FluencyCard c) {
    final l = context.l10n;
    final p = pal(context);
    final big = MediaQuery.sizeOf(context).shortestSide > 600 ? 96.0 : 64.0;
    final style = TextStyle(fontFamily: MushafRepo.fontFamily(_script), fontSize: big, height: 1.8, color: p.ink);
    final secs = _clock.elapsedMilliseconds / 1000;
    Widget word;
    if (c.chunk case (final pre, final suf)) {
      final (a, b, z) = splitText(c.text, pre, suf);
      word = _whole
          ? Text.rich(
              TextSpan(children: [
                TextSpan(text: a, style: style.copyWith(color: p.acc)),
                TextSpan(text: b, style: style),
                TextSpan(text: z, style: style.copyWith(color: p.acc)),
              ]),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center)
          : Text(b, textDirection: TextDirection.rtl, style: style);
    } else {
      word = Text(c.text, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: style);
    }
    final rated = _shown != null;
    Widget rate(Recall r, String label, Color colour, String key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: colour.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: rated ? null : () => _rate(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(children: [
                    Text(label, style: uiStyle(context, size: 15, weight: FontWeight.w700, color: colour)),
                    Text(key, style: uiStyle(context, size: 11, color: p.ink3)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(children: [
        Row(children: [
          Text(l.flDeckAt(_at.clamp(0, _total - 1) + 1, _total),
              style: uiStyle(context, size: 13, weight: FontWeight.w700, color: p.ink3)),
          const Spacer(),
          Text('${secs.toStringAsFixed(1)} s',
              style: uiStyle(context, size: 13, color: secs <= 1 ? p.acc : p.ink3)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: _total == 0 ? 0 : (_at.clamp(0, _total) / _total), color: p.acc, backgroundColor: p.track),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(child: word),
              if (c.note != null)
                Text(c.note!, style: uiStyle(context, size: 14, color: p.ink3)),
              if (c.chunk != null && !_whole)
                TextButton(
                    onPressed: () => setState(() => _whole = true),
                    child: Text(l.flShowWhole, style: uiStyle(context, size: 14, color: p.acc))),
            ]),
          ),
        ),
        Text(rated ? l.flHearHint : l.flReadAloud,
            textAlign: TextAlign.center, style: uiStyle(context, size: 13, color: p.ink3)),
        const SizedBox(height: 10),
        if (!rated)
          Row(children: [
            rate(Recall.instant, l.flInstant, const Color(0xFF2E8B57), '1'),
            rate(Recall.slow, l.flSlowRead, const Color(0xFFC27C12), '2'),
            rate(Recall.wrong, l.flWrong, const Color(0xFFB4483B), '3'),
          ])
        else
          Row(children: [
            Expanded(
              child: QOutlineButton(l.flHear,
                  icon: AppIcons.volume, onTap: () => playFluencyWords(c.words)),
            ),
            const SizedBox(width: 10),
            Expanded(child: QPrimaryButton(l.flNext, onTap: _next)),
          ]),
      ]),
    );
  }
}
