import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio.dart';
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
import '../../ui/kit.dart';
import 'deck_screen.dart' show playFluencyWords;

/// The fluency plan's verse build-up, on a passage: its words alone, then
/// the pairs across each join, the half-verses, the whole verses — then
/// the passage read three times, timed, faster each time.
///
/// Supports, as the plan fades them: hearing it modeled first (weeks 1–6),
/// after a first try (7–9) or not at all (10–12); eyes ahead (each word
/// covered once passed, so the eyes must already be on the next); and a
/// silent preview of each verse before reading it aloud.

/// When to hear the passage read: before reading, after a first try, never.
enum Modeling { first, after, none }

/// The plan's modeling for [week] (no plan: after a first try).
Modeling modelingOfWeek(int week) => week <= 0
    ? Modeling.after
    : week <= 6
        ? Modeling.first
        : week <= 9
            ? Modeling.after
            : Modeling.none;

enum _Step { words, pairs, halves, verses, repeated, done }

/// One thing to read: some of the passage's words.
class _Unit {
  final List<int> words; // indices into the passage's words
  const _Unit(this.words);
}

class PassageScreen extends StatefulWidget with DesktopAware {
  /// The passage: global āyāt [from]..[to].
  final int from, to;
  const PassageScreen({super.key, required this.from, required this.to});

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

class _PassageScreenState extends State<PassageScreen> {
  /// The passage's words (no ۝), and each āyah's [start, end).
  List<(WordRef, String)> _words = const [];
  List<(int, int)> _ayahs = const [];
  bool _ready = false;

  _Step _step = _Step.words;
  int _at = 0;
  late Modeling _modeling;
  bool _eyesAhead = false;
  bool _preview = true;

  /// Reading the current unit: words passed (eyes ahead); the silent
  /// preview's pointer (-1: reading aloud).
  int _cursor = 0;
  int _pointer = -1;

  /// Read first, then listen: heard after the first try.
  bool _tried = false;

  final List<Duration> _times = [];
  final _clock = Stopwatch();
  Timer? _tick;
  final _focus = FocusNode();

  String get _script => SettingsScope.of(context).mushafScript;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _modeling = modelingOfWeek(FluencyScope.read(context)?.week ?? 0);
    MushafRepo.ensure(_script).then((_) {
      if (!mounted) return;
      final words = <(WordRef, String)>[];
      final ayahs = <(int, int)>[];
      for (var g = widget.from; g <= widget.to; g++) {
        final start = words.length;
        for (final w in MushafRepo.ayahTokens(_script, g).$2) {
          if (w.isMarker) continue;
          words.add((WordRef.fromGlobal(g, w.wordIdx), cleanForm(w.text)));
        }
        ayahs.add((start, words.length));
      }
      setState(() {
        _words = words;
        _ayahs = ayahs;
        _ready = true;
      });
      _enter(_Step.words);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _focus.dispose();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    super.dispose();
  }

  // ── the steps' units ──

  List<_Unit> _unitsOf(_Step s) => switch (s) {
        _Step.words => [for (var i = 0; i < _words.length; i++) _Unit([i])],
        _Step.pairs => [
            for (final (a, b) in _ayahs)
              for (var i = a; i + 1 < b; i++) _Unit([i, i + 1])
          ],
        _Step.halves => [
            for (final (a, b) in _ayahs) ...[
              if (b - a < 4)
                _Unit([for (var i = a; i < b; i++) i])
              else ...[
                _Unit([for (var i = a; i < _halfAt(a, b); i++) i]),
                _Unit([for (var i = _halfAt(a, b); i < b; i++) i]),
              ],
            ]
          ],
        _Step.verses => [
            for (final (a, b) in _ayahs) _Unit([for (var i = a; i < b; i++) i])
          ],
        _Step.repeated => [_Unit([for (var i = 0; i < _words.length; i++) i])],
        _Step.done => const [],
      };

  /// Where the āyah [a, b) halves: after the pause sign nearest its middle,
  /// else in the middle.
  int _halfAt(int a, int b) {
    final mid = (a + b) ~/ 2;
    var best = mid, dist = 1 << 30;
    for (var i = a + 1; i < b - 1; i++) {
      final r = _words[i].$1;
      final raw = MushafRepo.wordText(_script, r.globalAyah, r.word0);
      if (raw.runes.any((c) => c >= 0x06D6 && c <= 0x06DC) && (i + 1 - mid).abs() < dist) {
        dist = (i + 1 - mid).abs();
        best = i + 1;
      }
    }
    return best;
  }

  List<_Unit> get _units => _unitsOf(_step);
  _Unit? get _unit => _at < _units.length ? _units[_at] : null;

  void _enter(_Step s) {
    setState(() {
      _step = s;
      _at = 0;
    });
    _beginUnit();
  }

  void _beginUnit() {
    setState(() {
      _cursor = 0;
      _tried = false;
      _pointer = _preview && _step == _Step.verses ? 0 : -1;
    });
    if (_modeling == Modeling.first && _step != _Step.repeated && _pointer < 0) _hear();
  }

  void _hear() {
    final u = _unit;
    if (u == null) return;
    final refs = [for (final i in u.words) _words[i].$1];
    FluencyScope.read(context)?.markHeard(refs.first.globalAyah);
    final whole = _step == _Step.verses;
    if (whole) {
      AyahAudio.instance.play(refs.first.surah, refs.first.ayah,
          reciter: SettingsScope.of(context).reciter);
    } else {
      playFluencyWords(refs);
    }
  }

  /// On: the preview's pointer, eyes ahead's cover, then the next unit (or
  /// step).
  void _advance() {
    final u = _unit;
    if (u == null) return;
    if (_pointer >= 0) {
      setState(() => _pointer = _pointer + 1 >= u.words.length ? -1 : _pointer + 1);
      return;
    }
    if (_eyesAhead && u.words.length > 1 && _cursor < u.words.length && _step != _Step.repeated) {
      setState(() => _cursor++);
      if (_cursor < u.words.length) return;
    }
    if (_modeling == Modeling.after && !_tried && _step != _Step.repeated) {
      setState(() => _tried = true);
      _hear();
      return;
    }
    if (_at + 1 < _units.length) {
      setState(() => _at++);
      _beginUnit();
    } else {
      _enter(_Step.values[_step.index + 1]);
    }
  }

  // ── repeated reading ──

  void _startStop() {
    if (_clock.isRunning) {
      _clock.stop();
      _tick?.cancel();
      setState(() => _times.add(_clock.elapsed));
      if (_times.length >= 3) {
        FluencyScope.read(context)?.blockDone('buildup');
      }
    } else {
      _clock
        ..reset()
        ..start();
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.arrowLeft) {
      _step == _Step.repeated ? _startStop() : _advance();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH) {
      _hear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── build ──

  String _stepName(BuildContext context, _Step s) => switch (s) {
        _Step.words => context.l10n.psWords,
        _Step.pairs => context.l10n.psPairs,
        _Step.halves => context.l10n.psHalves,
        _Step.verses => context.l10n.psVerses,
        _Step.repeated => context.l10n.psRepeated,
        _Step.done => context.l10n.flDeckDone,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.psTitle),
        actions: [
          IconButton(
            tooltip: l.psSupports,
            icon: const Icon(AppIcons.tune),
            onPressed: _supports,
          ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: !_ready
              ? Center(child: CircularProgressIndicator(color: p.acc))
              : QColumn(child: _body(context)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    if (_step == _Step.done) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.flDeckDone, style: displayStyle(context, size: 26)),
          const SizedBox(height: 12),
          if (_times.isNotEmpty) _timesView(context),
          const SizedBox(height: 20),
          QPrimaryButton(l.rvDone, onTap: () => Navigator.maybePop(context)),
        ]),
      );
    }
    final u = _unit!;
    // The steps, as dots: where in the build-up.
    final steps = _Step.values.where((s) => s != _Step.done).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(children: [
        Row(children: [
          for (final s in steps)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: s.index <= _step.index ? p.acc : p.track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text(_stepName(context, _step),
              style: uiStyle(context, size: 15, weight: FontWeight.w700)),
          const Spacer(),
          if (_step != _Step.repeated)
            Text(l.flDeckAt(_at + 1, _units.length),
                style: uiStyle(context, size: 13, color: p.ink3)),
        ]),
        Expanded(child: Center(child: SingleChildScrollView(child: _text(context, u)))),
        if (_step == _Step.repeated) ...[
          if (_times.isNotEmpty) _timesView(context),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: QPrimaryButton(
                _clock.isRunning
                    ? l.psStop((_clock.elapsedMilliseconds / 1000).toStringAsFixed(1))
                    : l.psStart(_times.length + 1),
                icon: _clock.isRunning ? AppIcons.stop : AppIcons.play,
                onTap: _times.length >= 3 && !_clock.isRunning ? null : _startStop,
              ),
            ),
            if (_times.length >= 3) ...[
              const SizedBox(width: 10),
              Expanded(child: QOutlineButton(l.flNext, onTap: () => _enter(_Step.done))),
            ],
          ]),
        ] else ...[
          Text(
              _pointer >= 0
                  ? l.psPreviewHint
                  : _tried
                      ? l.psListenHint
                      : l.psReadHint,
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 13, color: p.ink3)),
          const SizedBox(height: 10),
          Row(children: [
            if (_modeling != Modeling.none) ...[
              Expanded(child: QOutlineButton(l.flHear, icon: AppIcons.volume, onTap: _hear)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: QPrimaryButton(
                  _pointer >= 0 && _pointer + 1 >= u.words.length ? l.psAloud : l.flNext,
                  onTap: _advance),
            ),
          ]),
        ],
      ]),
    );
  }

  /// The unit's words: the preview's pointer on its word, words passed
  /// covered (eyes ahead).
  Widget _text(BuildContext context, _Unit u) {
    final p = pal(context);
    final size = switch (_step) {
      _Step.words || _Step.pairs => 64.0,
      _Step.halves => 40.0,
      _ => 32.0,
    };
    final base = TextStyle(
        fontFamily: MushafRepo.fontFamily(_script), fontSize: size, height: 2.0, color: p.ink);
    final spans = <InlineSpan>[];
    for (var k = 0; k < u.words.length; k++) {
      if (k > 0) spans.add(TextSpan(text: ' ', style: base));
      final covered = _eyesAhead && k < _cursor && _step != _Step.repeated;
      final pointed = k == _pointer;
      spans.add(TextSpan(
        text: _words[u.words[k]].$2,
        style: base.copyWith(
          color: covered ? Colors.transparent : (pointed ? p.acc : null),
          backgroundColor: covered ? p.track : (pointed ? p.accSoft : null),
        ),
      ));
    }
    return Text.rich(TextSpan(children: spans),
        textDirection: TextDirection.rtl, textAlign: TextAlign.center);
  }

  /// The three readings' times, each bar its share of the slowest.
  Widget _timesView(BuildContext context) {
    final p = pal(context);
    final most = _times.map((t) => t.inMilliseconds).reduce((a, b) => a > b ? a : b);
    return Column(children: [
      for (final (i, t) in _times.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
                width: 28,
                child: Text('${i + 1}', style: uiStyle(context, size: 13, color: p.ink3))),
            Expanded(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: most == 0 ? 0 : t.inMilliseconds / most,
                child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                        color: i == _times.length - 1 ? p.acc : p.track,
                        borderRadius: BorderRadius.circular(6))),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text('${(t.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  textAlign: TextAlign.end,
                  style: uiStyle(context, size: 13, weight: FontWeight.w700)),
            ),
          ]),
        ),
    ]);
  }

  void _supports() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(builder: (sheet, set) {
        final l = sheet.l10n;
        void both(VoidCallback f) {
          setState(f);
          set(() {});
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QGroup(children: [
                QRow(
                  title: l.psModeling,
                  subtitle: l.psModelingSub,
                  control: QSegmented<Modeling>(
                    expand: false,
                    options: [
                      (Modeling.first, l.psListenFirst, null),
                      (Modeling.after, l.psListenAfter, null),
                      (Modeling.none, l.psListenNone, null),
                    ],
                    value: _modeling,
                    onChanged: (v) => both(() => _modeling = v),
                  ),
                ),
                QRow(
                  title: l.psEyesAhead,
                  subtitle: l.psEyesAheadSub,
                  control: QSwitch(value: _eyesAhead, onChanged: (v) => both(() => _eyesAhead = v)),
                ),
                QRow(
                  title: l.psPreview,
                  subtitle: l.psPreviewSub,
                  control: QSwitch(value: _preview, onChanged: (v) => both(() => _preview = v)),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

/// Opens passage practice on āyāt [from]..[to] (global).
Future<void> openPassage(BuildContext context, int from, int to) =>
    pushAdaptive(context, PassageScreen(from: from, to: to));

/// The passage from [g]: its āyah and those after, up to [words] words
/// (at least the one āyah) within its sūrah.
(int, int) passageFrom(String script, int g, {int words = 40}) {
  final (s, _) = MushafRepo.surahAyahOf(g);
  var to = g, n = MushafRepo.ayahTokens(script, g).$2.length;
  while (true) {
    final next = to + 1;
    if (next >= 6236 || MushafRepo.surahAyahOf(next).$1 != s) break;
    final m = MushafRepo.ayahTokens(script, next).$2.length;
    if (n + m > words) break;
    to = next;
    n += m;
  }
  return (g, to);
}

/// A passage's name: "Al-Baqarah 2:30–33".
Future<String> passageName(int from, int to) async {
  final metas = await QuranRepo.meta();
  final (s, a) = MushafRepo.surahAyahOf(from);
  final (_, b) = MushafRepo.surahAyahOf(to);
  return '${metas[s - 1].tname} $s:$a${b == a ? '' : '–$b'}';
}
