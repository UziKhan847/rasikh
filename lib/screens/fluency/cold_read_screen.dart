import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart';
import '../../core/fluency/plan.dart';
import '../../core/fluency/recorder.dart';
import '../../core/fluency/words.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'passage_screen.dart' show passageName;

/// The fluency plan's cold read: a minute on a passage never heard, read
/// aloud without correction, recorded. Then: the last word reached and any
/// misread (the words correct, per minute, counted from them); the
/// recording played back to count the stalls and madd errors; saved to
/// the tracker.
class ColdReadScreen extends StatefulWidget with DesktopAware {
  /// The read's length (the plan's minute; shorter in tests).
  final int seconds;
  const ColdReadScreen({super.key, this.seconds = 60});

  @override
  State<ColdReadScreen> createState() => _ColdReadScreenState();
}

enum _Stage { choose, countdown, reading, last, misread, check, saved }

class _ColdReadScreenState extends State<ColdReadScreen> {
  int get _seconds => widget.seconds;

  _Stage _stage = _Stage.choose;
  Iterator<Passage>? _passages;
  Passage? _passage;
  String _name = '';
  List<String> _words = const [];

  int _count = 3;
  final _clock = Stopwatch();
  Timer? _tick;
  bool _record = true;
  final _recorder = FluencyRecorder();
  String? _recording;

  int _lastWord = -1;
  final Set<int> _misread = {};
  int _stalls = 0, _madd = 0;
  int? _perception;
  final _notes = TextEditingController();
  final _player = AudioPlayer();
  bool _playing = false;
  final List<TapGestureRecognizer> _taps = [];

  String get _script => SettingsScope.of(context).mushafScript;
  FluencyStore get _store => FluencyScope.read(context)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_passages != null) return;
    _passages = const <Passage>[].iterator; // set below, once the text's in
    MushafRepo.ensure(_script).then((_) {
      if (!mounted) return;
      _passages = coldPassages(_store, _script, _store.week).iterator;
      _nextPassage();
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _nextPassage() async {
    final it = _passages!;
    final p = it.moveNext() ? it.current : null;
    final name = p == null ? '' : await passageName(p.$1, p.$2);
    if (!mounted) return;
    setState(() {
      _passage = p;
      _name = name;
      _words = p == null
          ? const []
          : [
              for (var g = p.$1; g <= p.$2; g++)
                for (final w in MushafRepo.ayahTokens(_script, g).$2)
                  if (!w.isMarker) cleanForm(w.text),
            ];
    });
  }

  void _known() {
    final p = _passage;
    if (p == null) return;
    _store.setKnown(MushafRepo.tokenOf(_script, p.$1, 0), true);
    _nextPassage();
  }

  void _begin() {
    setState(() {
      _stage = _Stage.countdown;
      _count = 3;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return t.cancel();
      if (_count > 1) {
        setState(() => _count--);
        return;
      }
      t.cancel();
      if (_record) _record = await _recorder.start();
      if (!mounted) return;
      _clock
        ..reset()
        ..start();
      setState(() => _stage = _Stage.reading);
      _tick = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted) return t.cancel();
        if (_clock.elapsed.inSeconds >= _seconds) {
          t.cancel();
          _timeUp();
        } else {
          setState(() {});
        }
      });
    });
  }

  Future<void> _timeUp() async {
    _clock.stop();
    final path = _record ? await _recorder.stop() : null;
    if (!mounted) return;
    setState(() {
      _recording = path != null && File(path).existsSync() ? path : null;
      _stage = _Stage.last;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_clock.isRunning) _recorder.stop();
    _recorder.dispose();
    _player.dispose();
    _notes.dispose();
    for (final r in _taps) {
      r.dispose();
    }
    super.dispose();
  }

  int get _correct => _lastWord < 0 ? 0 : _lastWord + 1 - _misread.where((i) => i <= _lastWord).length;

  void _save() {
    final p = _passage!;
    _store
      ..addColdRead(ColdRead(
        at: _store.now(),
        firstTok: MushafRepo.tokenOf(_script, p.$1, 0),
        lastTok: MushafRepo.tokenOf(_script, p.$2, -1),
        script: _script,
        seconds: _seconds,
        wordsCorrect: _correct,
        stalls: _stalls,
        maddErrors: _madd,
        perception: _perception,
        recording: _recording,
        notes: _notes.text.trim(),
      ))
      ..blockDone('cold');
    setState(() => _stage = _Stage.saved);
  }

  Future<void> _togglePlay() async {
    final r = _recording;
    if (r == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(r));
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.crTitle)),
      body: SafeArea(child: QColumn(child: _body(context))),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    switch (_stage) {
      case _Stage.choose:
        if (_passage == null) {
          return Center(
              child: Text(_passages == null ? '' : l.crNone,
                  textAlign: TextAlign.center, style: uiStyle(context, size: 15, color: p.ink2)));
        }
        return _page(context, [
          Text(l.crIntro, style: uiStyle(context, size: 14.5, color: p.ink2, height: 1.45)),
          const SizedBox(height: 16),
          QCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name, style: uiStyle(context, size: 17, weight: FontWeight.w700)),
              Text(l.crWords(_words.length), style: uiStyle(context, size: 13, color: p.ink3)),
            ]),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: _nextPassage, child: Text(l.crAnother)),
            TextButton(onPressed: _known, child: Text(l.crKnown)),
          ]),
          QRow(
            title: l.crRecord,
            subtitle: l.crRecordSub,
            control: QSwitch(value: _record, onChanged: (v) => setState(() => _record = v)),
          ),
        ], QPrimaryButton(l.crStart, icon: AppIcons.play, onTap: _begin));
      case _Stage.countdown:
        return Center(child: Text('$_count', style: displayStyle(context, size: 96, color: p.acc)));
      case _Stage.reading:
        final left = _seconds - _clock.elapsed.inSeconds;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (_record) Icon(AppIcons.mic, color: const Color(0xFFB4483B), size: 18),
              const Spacer(),
              Text('$left s', style: displayStyle(context, size: 22, color: left <= 10 ? p.acc : p.ink)),
            ]),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _text(context))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.crNoCorrection, style: uiStyle(context, size: 13, color: p.ink3)),
          ),
        ]);
      case _Stage.last:
      case _Stage.misread:
        final last = _stage == _Stage.last;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(last ? l.crTapLast : l.crTapMisread,
                textAlign: TextAlign.center, style: uiStyle(context, size: 14.5, weight: FontWeight.w700)),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _text(context))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text(l.crCorrectN(_correct),
                    style: uiStyle(context, size: 15, weight: FontWeight.w700, color: p.acc)),
              ),
              QPrimaryButton(l.flNext,
                  onTap: _lastWord < 0
                      ? null
                      : () => setState(() => _stage = last ? _Stage.misread : _Stage.check)),
            ]),
          ),
        ]);
      case _Stage.check:
        Widget counter(String label, int value, ValueChanged<int> on) => QRow(
              title: label,
              control: QStepper(
                height: 40,
                label: '$value',
                minusTooltip: '−',
                plusTooltip: '+',
                minusChild: const Text('−'),
                plusChild: const Text('+'),
                onMinus: value <= 0 ? null : () => setState(() => on(value - 1)),
                onPlus: () => setState(() => on(value + 1)),
              ),
            );
        return _page(context, [
          Text(_recording != null ? l.crCheckRecorded : l.crCheckSelf,
              style: uiStyle(context, size: 14.5, color: p.ink2, height: 1.45)),
          const SizedBox(height: 12),
          if (_recording != null)
            QOutlineButton(_playing ? l.pause : l.crPlayBack,
                icon: _playing ? AppIcons.pause : AppIcons.play, onTap: _togglePlay),
          const SizedBox(height: 12),
          QGroup(children: [
            counter(l.crStalls, _stalls, (v) => _stalls = v),
            counter(l.crMadd, _madd, (v) => _madd = v),
            QRow(
              title: l.crPerception,
              subtitle: l.crPerceptionSub,
              control: QStepper(
                height: 40,
                label: _perception == null ? '—' : '$_perception',
                minusTooltip: '−',
                plusTooltip: '+',
                minusChild: const Text('−'),
                plusChild: const Text('+'),
                onMinus: _perception == null
                    ? null
                    : () => setState(() => _perception = _perception! <= 0 ? null : _perception! - 1),
                onPlus: (_perception ?? -1) >= 10
                    ? null
                    : () => setState(() => _perception = (_perception ?? -1) + 1),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: InputDecoration(labelText: l.crNotes, border: const OutlineInputBorder()),
          ),
        ], QPrimaryButton(l.mkSave, onTap: _save));
      case _Stage.saved:
        final reads = _store.coldReads;
        final base = reads.first;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.crPerMinute(_correct), style: displayStyle(context, size: 30, color: p.acc)),
              const SizedBox(height: 8),
              if (reads.length > 1)
                Text(l.crSinceStart(base.perMinute.round()),
                    style: uiStyle(context, size: 14, color: p.ink2)),
              const SizedBox(height: 20),
              QPrimaryButton(l.rvDone, onTap: () => Navigator.maybePop(context)),
            ]),
          ),
        );
    }
  }

  /// A step's text above, its button at the foot.
  Widget _page(BuildContext context, List<Widget> children, Widget button) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView(children: children)),
          const SizedBox(height: 12),
          button,
        ]),
      );

  /// The passage; after the minute, its words tappable: the last reached,
  /// then the misread ones.
  Widget _text(BuildContext context) {
    final p = pal(context);
    final base = TextStyle(
        fontFamily: MushafRepo.fontFamily(_script), fontSize: 30, height: 2.1, color: p.ink);
    for (final r in _taps) {
      r.dispose();
    }
    _taps.clear();
    final tapping = _stage == _Stage.last || _stage == _Stage.misread;
    final spans = <InlineSpan>[];
    for (var i = 0; i < _words.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: base));
      TapGestureRecognizer? rec;
      if (tapping) {
        rec = TapGestureRecognizer()
          ..onTap = () => setState(() {
                if (_stage == _Stage.last) {
                  _lastWord = i;
                } else if (i <= _lastWord) {
                  _misread.contains(i) ? _misread.remove(i) : _misread.add(i);
                }
              });
        _taps.add(rec);
      }
      final past = tapping && _lastWord >= 0 && i > _lastWord;
      final wrong = _misread.contains(i);
      spans.add(TextSpan(
        text: _words[i],
        recognizer: rec,
        style: base.copyWith(
          color: wrong ? const Color(0xFFB4483B) : (past ? p.ink3.withValues(alpha: .5) : null),
          backgroundColor: i == _lastWord ? p.accSoft : null,
        ),
      ));
    }
    return Text.rich(TextSpan(children: spans), textDirection: TextDirection.rtl);
  }
}
