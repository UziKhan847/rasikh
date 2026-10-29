import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio.dart';
import '../../core/fluency/chunks.dart';
import '../../core/fluency/fluency_audio.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/fluency/words.dart';
import '../../core/l10n.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../../ui/fluency_style.dart';
import '../../ui/kit.dart';
import '../reader/ayah_text.dart';
import 'fluency_tools.dart';

/// The Reader's fluency review, verse by verse (as Hifẓ's review goes mark
/// by mark): an āyah on a card, its words tappable to mark — not fluent, a
/// pair, a chunk — and under it the marks in that āyah, each to hear as
/// Ḥuṣarī recites it and to rate; then the next āyah. What's marked here is
/// in the decks too.
class VerseReviewScreen extends StatefulWidget with DesktopAware {
  /// The āyāt, in order (global).
  final List<int> ayahs;
  final String title;
  const VerseReviewScreen({super.key, required this.ayahs, required this.title});

  @override
  State<VerseReviewScreen> createState() => _VerseReviewScreenState();
}

class _VerseReviewScreenState extends State<VerseReviewScreen> {
  int _at = 0;
  FluencyTool _tool = FluencyTool.slow;
  bool _ready = false;
  final _focus = FocusNode();

  String get _script => SettingsScope.of(context).mushafScript;
  int get _g => widget.ayahs[_at];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    MushafRepo.ensure(_script).then((_) async {
      final metas = await QuranRepo.meta();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _names = {for (final m in metas) m.n: m.tname};
      });
    });
  }

  Map<int, String> _names = const {};

  @override
  void dispose() {
    _focus.dispose();
    FluencyAudio.instance.stop();
    super.dispose();
  }

  void _go(int by) {
    final to = (_at + by).clamp(0, widget.ayahs.length - 1);
    if (to == _at) return;
    FluencyAudio.instance.stop();
    setState(() => _at = to);
  }

  /// The āyah's words (no ۝).
  List<(WordRef, String)> _words(int g) => [
        for (final w in MushafRepo.ayahTokens(_script, g).$2)
          if (!w.isMarker) (WordRef.fromGlobal(g, w.wordIdx), cleanForm(w.text)),
      ];

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // The book's way: ← is onward.
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final store = FluencyScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: !_ready || store == null || widget.ayahs.isEmpty
              ? Center(
                  child: widget.ayahs.isEmpty
                      ? Text(l.flDeckEmpty, textAlign: TextAlign.center)
                      : CircularProgressIndicator(color: p.acc))
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [QColumn(child: _card(context, store))],
                    ),
                  ),
                  _footer(context),
                ]),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, FluencyStore store) {
    final l = context.l10n;
    final p = pal(context);
    final g = _g;
    final (s, a) = MushafRepo.surahAyahOf(g);
    final words = _words(g);
    final vis = store.visuals((r) => nextWordOf(_script, r));
    final style = TextStyle(
        fontFamily: MushafRepo.fontFamily(_script), fontSize: 30, height: 2.1, color: p.ink);
    // The marks in this āyah: its words', its pairs' (starting here), its
    // chunks'.
    final marks = [
      for (final m in store.marks)
        if (m.ref.globalAyah == g) m
    ]..sort((x, y) => x.ref.word.compareTo(y.ref.word));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${_names[s] ?? ''} $s:$a',
            style: uiStyle(context, size: 14, weight: FontWeight.w700, color: p.ink2)),
        const Spacer(),
        Text(l.flDeckAt(_at + 1, widget.ayahs.length), style: uiStyle(context, size: 13, color: p.ink3)),
      ]),
      const SizedBox(height: 10),
      QCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: AyahText(
              words: [for (final (_, t) in words) TextSpan(text: t, style: style)],
              textKey: '$_script/$g/${style.color}',
              playWord: -1,
              highlight: p.hl,
              marks: const [],
              markPal: null,
              fluency: [for (final (r, _) in words) vis[r.key]],
              fluencyColor: fluencyColor(dark: p.isDark),
              onTap: (w) => applyFluency(context, _tool, _script, words[w].$1),
              onLongPress: (w) => FluencyAudio.instance.play([words[w].$1]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: QSegmented<FluencyTool>(
                options: [
                  (FluencyTool.slow, l.flSlow, null),
                  (FluencyTool.pair, l.flPair, null),
                  (FluencyTool.chunk, l.flChunk, null),
                ],
                value: _tool,
                onChanged: (v) => setState(() => _tool = v),
              ),
            ),
            const SizedBox(width: 8),
            QIconButton(
              icon: AppIcons.recite,
              tooltip: l.vrHearAyah,
              onTap: () {
                FluencyAudio.instance.stop();
                AyahAudio.instance.play(s, a, reciter: FluencyAudio.reciter);
              },
            ),
          ]),
          const SizedBox(height: 4),
          Text(
              switch (_tool) {
                FluencyTool.slow => l.flHintSlow,
                FluencyTool.pair => l.flHintPair,
                FluencyTool.chunk => l.flHintChunk,
              },
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 12.5, color: p.ink3)),
        ]),
      ),
      QSectionLabel(l.vrMarked),
      if (marks.isEmpty)
        Text(l.vrNone, style: uiStyle(context, size: 13.5, color: p.ink3))
      else
        QGroup(children: [for (final m in marks) _markRow(context, store, m)]),
    ]);
  }

  /// One mark: its words, what it is, a play, and the three ratings.
  Widget _markRow(BuildContext context, FluencyStore store, FluencyMark m) {
    final l = context.l10n;
    final p = pal(context);
    final prog = store.progressOf(m.cardId);
    final refs = [
      m.ref,
      if (m.kind == FluencyKind.pair) ?nextWordOf(_script, m.ref),
    ];
    final text = switch (m.kind) {
      FluencyKind.chunk => () {
          final (a, b, c) = splitText(m.form, m.prefix, m.suffix);
          return [a, b, c].where((x) => x.isNotEmpty).join(' · ');
        }(),
      _ => m.form,
    };
    final kind = switch (m.kind) {
      FluencyKind.word => l.flSlow,
      FluencyKind.pair => '${l.flPair} · ${joinLabel(context, m.join)}',
      FluencyKind.chunk => l.flChunk,
    };
    Widget rate(Recall r, String label, Color c) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Material(
            color: (prog?.last == r ? c : c.withValues(alpha: .12)),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => store.rate(m.cardId, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Text(label,
                    style: uiStyle(context,
                        size: 12, weight: FontWeight.w700, color: prog?.last == r ? Colors.white : c)),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        QIconButton(
            size: 36, icon: AppIcons.volume, tooltip: l.flHear, onTap: () => FluencyAudio.instance.play(refs)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: MushafRepo.fontFamily(_script), fontSize: 22, height: 1.7, color: p.ink)),
            Text(prog?.retired ?? false ? '$kind · ${l.vrRetired}' : kind,
                style: uiStyle(context, size: 12, color: p.ink3)),
          ]),
        ),
        rate(Recall.instant, l.flInstant, const Color(0xFF2E8B57)),
        rate(Recall.slow, l.flSlowRead, const Color(0xFFC27C12)),
        rate(Recall.wrong, l.flWrong, const Color(0xFFB4483B)),
      ]),
    );
  }

  Widget _footer(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line2))),
      child: QColumn(
        child: Row(children: [
          Expanded(
            child: QOutlineButton(l.vrPrev, onTap: _at == 0 ? null : () => _go(-1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QPrimaryButton(l.vrNext,
                onTap: _at + 1 >= widget.ayahs.length ? () => Navigator.maybePop(context) : () => _go(1)),
          ),
        ]),
      ),
    );
  }
}

/// The āyāt from [g] to its sūrah's end.
List<int> ayahsToSurahEnd(int g) {
  final (s, _) = MushafRepo.surahAyahOf(g);
  final last = MushafRepo.globalAyahOf(s, MushafRepo.ayahCountOf(s));
  return [for (var x = g; x <= last; x++) x];
}

/// The āyāt with fluency marks, in order.
List<int> markedAyahs(FluencyStore store) =>
    ({for (final m in store.marks) m.ref.globalAyah}.toList()..sort());
