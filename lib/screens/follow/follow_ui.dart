import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qiraah_ui/responsive.dart' show isDesktopPlatform;
import 'package:record/record.dart' show AudioRecorder, InputDevice;

import '../../core/downloads.dart' show formatBytes;
import '../../core/follow/follow_model.dart';
import '../../core/follow/follow_session.dart';
import '../../core/follow/linux_mic.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/app_icons.dart';
import '../../ui/bidi.dart';
import '../../ui/tool_popover.dart';

/// Tests: what "Choose folder…" picks, in place of the system's dialog.
@visibleForTesting
Future<String?> Function() pickFollowFolder = () => getDirectoryPath();

FollowTier? _tierOf(String? name) => switch (name) {
      'high' => FollowTier.high,
      'low' => FollowTier.low,
      _ => null,
    };

/// "18:60", for a word's āyah.
String followRef(int g) {
  final (s, a) = MushafRepo.surahAyahOf(g);
  return '$s:$a';
}

/// Starts following from āyah [g], word [word0], for [owner] (the screen
/// whose tool it is): the warning the first time, the model if it isn't
/// here, then the mic. False (and why, said) if it didn't start.
Future<bool> startFollow(BuildContext context, Object owner, int g, int word0) async {
  final s = SettingsScope.of(context);
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!s.followWarned) {
    if (!await showFollowWarning(context)) return false;
    s.update(() => s.followWarned = true);
    if (!context.mounted) return false;
  }
  var model = await FollowModel.locate(chosenDir: s.followDir, preferred: _tierOf(s.followTier));
  if (model == null) {
    if (!context.mounted) return false;
    model = await showFollowModelSheet(context);
    if (model == null) return false;
  }
  final session = FollowSession.instance;
  session.owner = owner;
  session.micId = s.followMic;
  session.keepRecordings = s.followKeep;
  await session.start(model, g, word0);
  if (session.status.value == FollowStatus.failed) {
    messenger?.showSnackBar(SnackBar(
      persist: false,
      content: Text(session.failure == 'mic' ? l.followMicDenied : l.followFailed),
    ));
    await session.stop();
    return false;
  }
  return session.active;
}

/// What it does and, above all, what it doesn't: true once read.
Future<bool> showFollowWarning(BuildContext context) async {
  final ok = await showAdaptiveSheet<bool>(
    context,
    useRootNavigator: true,
    builder: (sheet) {
      final l = sheet.l10n;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(AppIcons.mic, color: pal(sheet).acc),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.followTitle,
                      style: uiStyle(sheet, size: 19, weight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(l.followWarnBody,
                  key: const ValueKey('follow-warning'),
                  style: uiStyle(sheet, size: 14.5, color: pal(sheet).ink2, height: 1.5)),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('follow-understood'),
                  onPressed: () => Navigator.pop(sheet, true),
                  child: Text(l.followWarnOk),
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}

/// The model isn't here: download High or Low (one recommended), or on a
/// desktop a folder that holds it. The model to use, or null if left.
Future<({String dir, FollowTier tier})?> showFollowModelSheet(BuildContext context) {
  final settings = SettingsScope.of(context);
  return showAdaptiveSheet<({String dir, FollowTier tier})>(
    context,
    useRootNavigator: true,
    builder: (sheet) => _ModelSheet(settings: settings),
  );
}

class _ModelSheet extends StatefulWidget {
  final AppSettings settings;
  const _ModelSheet({required this.settings});

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  FollowTier? _recommended, _loading;
  double _progress = 0;
  String? _problem;
  Completer<void>? _cancel;

  @override
  void initState() {
    super.initState();
    FollowModel.recommended(lite: widget.settings.lite).then((t) {
      if (mounted) setState(() => _recommended = t);
    });
  }

  @override
  void dispose() {
    _cancel?.complete();
    super.dispose();
  }

  Future<void> _download(FollowTier t) async {
    final l = context.l10n;
    final cancel = _cancel = Completer<void>();
    setState(() {
      _loading = t;
      _progress = 0;
      _problem = null;
    });
    try {
      await FollowModel.download(t, cancel: cancel.future, onProgress: (done, total) {
        if (mounted) setState(() => _progress = done / total);
      });
      final s = widget.settings;
      s.update(() {
        s.followTier = t.name;
        s.followDir = null;
      });
      final dir = await FollowModel.dirOf(t);
      if (mounted) Navigator.pop(context, (dir: dir, tier: t));
    } on FollowCancelled {
      // Left: what's downloaded so far stays, to go on from.
    } on FollowBadFile {
      if (mounted) setState(() => _problem = l.followBadFile);
    } catch (e) {
      debugPrint('follow download: $e');
      if (mounted) setState(() => _problem = l.followNetError);
    } finally {
      if (mounted) setState(() => _loading = null);
      _cancel = null;
    }
  }

  Future<void> _folder() async {
    final dir = await pickFollowFolder();
    if (dir == null || !mounted) return;
    final t = FollowModel.check(dir);
    if (t == null) {
      setState(() => _problem = context.l10n.followNotModel);
      return;
    }
    final s = widget.settings;
    s.update(() {
      s.followDir = dir;
      s.followTier = t.name;
    });
    Navigator.pop(context, (dir: dir, tier: t));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    Widget tier(FollowTier t, String label) {
      final loading = _loading == t;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: ValueKey('follow-${t.name}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download_rounded, color: p.ink2),
          title: Row(children: [
            Flexible(child: Text(label)),
            if (t == _recommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.acc.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(l.packRecommended,
                    style: uiStyle(context, size: 11.5, weight: FontWeight.w700, color: p.acc)),
              ),
            ],
          ]),
          subtitle: Text(loading
              ? l.followDownloading((_progress * 100).floor())
              : l.packMb(FollowModel.sizeMb(t))),
          trailing: loading
              ? TextButton(onPressed: () => _cancel?.complete(), child: Text(l.cancel))
              : FilledButton.tonal(
                  key: ValueKey('follow-download-${t.name}'),
                  onPressed: _loading == null ? () => _download(t) : null,
                  child: Text(l.followDownload),
                ),
        ),
        if (loading) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
      ]);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.followModelTitle, style: uiStyle(context, size: 19, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l.followModelBody, style: uiStyle(context, size: 14, color: p.ink2)),
            const SizedBox(height: 8),
            tier(FollowTier.high, l.packHigh),
            tier(FollowTier.low, l.packLow),
            if (isDesktopPlatform()) ...[
              const Divider(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('follow-folder'),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(l.packChooseFolder),
                  onPressed: _loading == null ? _folder : null,
                ),
              ),
            ],
            if (_problem != null) ...[
              const SizedBox(height: 10),
              Text(_problem!,
                  key: const ValueKey('follow-problem'),
                  style: uiStyle(context, size: 13.5, color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 10),
            Text(l.followCaption,
                style: uiStyle(context, size: 12.5, weight: FontWeight.w700, color: p.ink3)),
          ],
        ),
      ),
    );
  }
}

/// The tool's options: the model (High or Low, a folder, removing it),
/// what's heard, and what it is.
void showFollowOptions(BuildContext context, BuildContext anchor, AxisDirection side) {
  final s = SettingsScope.of(context);
  showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
    final l = pop.l10n;
    return StatefulBuilder(builder: (pop, setPop) {
      return FutureBuilder<Set<FollowTier>>(
        future: FollowModel.downloaded(),
        builder: (pop, snap) {
          final have = snap.data ?? const <FollowTier>{};
          final current = s.followDir != null ? null : (_tierOf(s.followTier) ?? have.firstOrNull);
          Widget tier(FollowTier t, String label) => ListTile(
                dense: true,
                title: Text(label),
                subtitle: Text(l.packMb(FollowModel.sizeMb(t))),
                trailing: current == t ? Icon(AppIcons.check, size: 18, color: pal(pop).acc) : null,
                onTap: () async {
                  if (!have.contains(t)) {
                    Navigator.pop(pop);
                    await showFollowModelSheet(context);
                    return;
                  }
                  s.update(() {
                    s.followTier = t.name;
                    s.followDir = null;
                  });
                  setPop(() {});
                },
              );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Text(l.followModel,
                    style: uiStyle(pop, size: 12.5, weight: FontWeight.w700, color: pal(pop).ink3)),
              ),
              tier(FollowTier.high, l.packHigh),
              tier(FollowTier.low, l.packLow),
              if (isDesktopPlatform())
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_open_rounded, size: 20),
                  title: Text(s.followDir == null ? l.packChooseFolder : l.packChangeFolder),
                  subtitle: s.followDir == null ? null : Text(s.followDir!, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    final dir = await pickFollowFolder();
                    if (dir == null) return;
                    if (FollowModel.check(dir) case final t?) {
                      s.update(() {
                        s.followDir = dir;
                        s.followTier = t.name;
                      });
                    } else if (pop.mounted) {
                      ScaffoldMessenger.maybeOf(context)
                          ?.showSnackBar(SnackBar(persist: false, content: Text(l.followNotModel)));
                    }
                    setPop(() {});
                  },
                ),
              if (current != null && have.contains(current))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_outline, size: 20),
                  title: Text(l.followRemove),
                  subtitle: Text(current == FollowTier.high ? l.packHigh : l.packLow),
                  onTap: () async {
                    if (FollowSession.instance.active) await FollowSession.instance.stop();
                    await FollowModel.remove(current);
                    s.update(() => s.followTier = null);
                    setPop(() {});
                  },
                ),
              const Divider(height: 8),
              ListTile(
                dense: true,
                leading: Icon(AppIcons.mic, size: 20),
                title: Text(l.followMic),
                subtitle: Text(s.followMic ?? l.followMicDefault,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(pop);
                  showFollowMicPicker(context);
                },
              ),
              SwitchListTile(
                dense: true,
                title: Text(l.followKeep),
                subtitle: Text(l.followKeepSub),
                value: s.followKeep,
                onChanged: (v) {
                  s.update(() => s.followKeep = v);
                  FollowSession.instance.keepRecordings = v;
                  setPop(() {});
                },
              ),
              // What's kept, and deleting it.
              FutureBuilder<int>(
                future: FollowRecordings.size(),
                builder: (pop, snap) {
                  final n = snap.data ?? 0;
                  if (n == 0) return const SizedBox.shrink();
                  return ListTile(
                    key: const ValueKey('follow-recordings'),
                    dense: true,
                    leading: const Icon(Icons.delete_outline, size: 20),
                    title: Text(l.followDeleteRecordings),
                    subtitle: Text(formatBytes(n)),
                    onTap: () async {
                      await FollowRecordings.deleteAll();
                      setPop(() {});
                    },
                  );
                },
              ),
              SwitchListTile(
                dense: true,
                title: Text(l.followShowHeard),
                value: s.followShowHeard,
                onChanged: (v) {
                  s.update(() => s.followShowHeard = v);
                  setPop(() {});
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.info_outline, size: 20),
                title: Text(l.followAbout),
                onTap: () {
                  Navigator.pop(pop);
                  showFollowWarning(context);
                },
              ),
            ]),
          );
        },
      );
    });
  }, maxHeight: 560);
}

/// Following's own bar: where it is (listening, finding you, paused),
/// pause / resume, Done — and, always, that it judges neither mistakes nor
/// tajwīd.
class FollowBar extends StatelessWidget {
  final Color ink, sub, accent;
  final Axis axis;
  final VoidCallback onDone;
  const FollowBar({
    super.key,
    required this.ink,
    required this.sub,
    required this.accent,
    required this.onDone,
    this.axis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = FollowSession.instance;
    final s = SettingsScope.of(context);
    final vertical = axis == Axis.vertical;
    return ValueListenableBuilder<FollowStatus>(
      valueListenable: session.status,
      builder: (context, st, _) {
        final (label, dot) = switch (st) {
          FollowStatus.listening => (l.followListening, accent),
          FollowStatus.searching => (l.followSearching, Colors.orange),
          FollowStatus.paused => (l.followPaused, sub),
          _ => (l.followStarting, sub),
        };
        final paused = st == FollowStatus.paused;
        // What it's doing — or, if the microphone gives nothing (muted,
        // unplugged) or too little, that, with the microphones a tap away.
        // On one line: the bar keeps its height.
        final status = ValueListenableBuilder<String?>(
          valueListenable: session.micProblem,
          builder: (context, pr, _) {
            final warn = Colors.orange.shade800;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: pr == null ? dot : warn, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Tooltip(
                  message: pr == 'silent' ? l.followNoSoundHint : '',
                  child: Text(
                      pr == null ? label : (pr == 'silent' ? l.followNoSound : l.followQuiet),
                      key: ValueKey(pr == null ? 'follow-status' : 'follow-mic-problem'),
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 14, weight: FontWeight.w700, color: pr == null ? ink : warn)),
                ),
              ),
              if (pr != null)
                TextButton(
                  key: const ValueKey('follow-mic-button'),
                  // As tall as the line: the bar keeps its height.
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  onPressed: () => showFollowMicPicker(context),
                  child: Text(l.followMicPick),
                )
              // How loud the microphone is: that it hears at all.
              else if (st == FollowStatus.listening || st == FollowStatus.searching) ...[
                const SizedBox(width: 8),
                _LevelMeter(color: accent, track: sub.withValues(alpha: .25)),
              ],
            ]);
          },
        );
        final caption = Text(l.followCaption,
            key: const ValueKey('follow-caption'),
            maxLines: vertical ? 4 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: vertical ? TextAlign.center : TextAlign.start,
            style: uiStyle(context, size: 12, color: sub));
        final heard = s.followShowHeard
            ? ValueListenableBuilder(
                valueListenable: session.heard,
                builder: (context, h, _) => Text(
                  // (The time first, the Arabic heard in its place after it.)
                  h == null ? '' : isolateArabic('${h.decodeMs} ms · ${h.text}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: uiStyle(context, size: 12, color: sub),
                ),
              )
            : null;
        final pause = IconButton(
          key: const ValueKey('follow-pause'),
          tooltip: paused ? l.resume : l.pause,
          onPressed: st == FollowStatus.starting
              ? null
              : () => paused ? session.resume() : session.pause(),
          icon: Icon(paused ? AppIcons.mic : Icons.mic_off_outlined, color: ink),
        );
        final done = TextButton(
          key: const ValueKey('follow-done'),
          onPressed: onDone,
          child: Text(l.nbDone,
              style: uiStyle(context, size: 14, weight: FontWeight.w700, color: accent)),
        );
        if (vertical) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            status,
            const SizedBox(height: 6),
            pause,
            ?heard,
            const SizedBox(height: 6),
            caption,
            const SizedBox(height: 6),
            done,
          ]);
        }
        return Row(children: [
          pause,
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [status, caption, ?heard],
            ),
          ),
          done,
        ]);
      },
    );
  }
}

/// The microphone's level, a short bar.
class _LevelMeter extends StatelessWidget {
  final Color color, track;
  const _LevelMeter({required this.color, required this.track});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: FollowSession.instance.level,
        builder: (context, v, _) => Container(
          key: const ValueKey('follow-level'),
          width: 46,
          height: 5,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(3)),
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            // Voices are mostly quiet next to the peak: shown on a curve.
            widthFactor: v <= 0 ? 0 : (v * 4).clamp(.04, 1.0),
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      );
}

/// Tests: the inputs offered, in place of the system's.
@visibleForTesting
Future<List<InputDevice>> Function() listFollowMics = () async {
  final r = AudioRecorder();
  try {
    return await r.listInputDevices();
  } finally {
    await r.dispose();
  }
};

/// Which microphone following listens with: the system's, or one of the
/// inputs — on Linux each says if it's muted, and can be unmuted here.
Future<void> showFollowMicPicker(BuildContext context) async {
  final s = SettingsScope.of(context);
  await showAdaptiveSheet<void>(
    context,
    useRootNavigator: true,
    builder: (sheet) => _MicSheet(settings: s),
  );
}

class _MicSheet extends StatefulWidget {
  final AppSettings settings;
  const _MicSheet({required this.settings});

  @override
  State<_MicSheet> createState() => _MicSheetState();
}

class _MicSheetState extends State<_MicSheet> {
  List<InputDevice>? _mics;
  final Map<String?, bool?> _muted = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<InputDevice> mics;
    try {
      mics = await listFollowMics();
    } catch (_) {
      mics = const [];
    }
    // (A speaker's monitor isn't a microphone.)
    mics = [for (final m in mics) if (!m.id.endsWith('.monitor')) m];
    final muted = <String?, bool?>{};
    for (final id in <String?>[null, for (final m in mics) m.id]) {
      muted[id] = await LinuxMic.isMuted(id);
    }
    if (!mounted) return;
    setState(() {
      _mics = mics;
      _muted
        ..clear()
        ..addAll(muted);
    });
  }

  Future<void> _pick(String? id) async {
    final s = widget.settings;
    s.update(() => s.followMic = id);
    final session = FollowSession.instance;
    session.micId = id;
    await session.restartMic();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final current = widget.settings.followMic;
    Widget row(String? id, String label) {
      final muted = _muted[id] == true;
      return ListTile(
        key: ValueKey('mic-${id ?? 'default'}'),
        leading: Icon(id == current ? Icons.radio_button_checked : Icons.radio_button_off,
            color: id == current ? p.acc : p.ink3),
        title: Text(label),
        subtitle: muted
            ? Text(l.followMuted, style: TextStyle(color: Colors.orange.shade800))
            : null,
        trailing: muted
            ? TextButton(
                key: ValueKey('unmute-${id ?? 'default'}'),
                onPressed: () async {
                  await LinuxMic.unmute(id);
                  await _load();
                },
                child: Text(l.followUnmute),
              )
            : null,
        onTap: () => _pick(id),
      );
    }

    final mics = _mics;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.followMic, style: uiStyle(context, size: 19, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (mics == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              row(null, l.followMicDefault),
              for (final m in mics) row(m.id, m.label),
            ],
            const SizedBox(height: 8),
            // Is it hearing? The level, as they speak.
            Row(children: [
              Text(l.followListening, style: uiStyle(context, size: 12.5, color: p.ink3)),
              const SizedBox(width: 8),
              _LevelMeter(color: p.acc, track: p.ink3.withValues(alpha: .25)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Following while memorizing, above the memorize bar: one slim line —
/// listening (its level), or what's wrong with the microphone — and,
/// always, that it judges neither mistakes nor tajwīd.
class FollowStrip extends StatelessWidget {
  final Color ink, sub, accent;
  const FollowStrip({super.key, required this.ink, required this.sub, required this.accent});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = FollowSession.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([session.status, session.micProblem]),
      builder: (context, _) {
        final st = session.status.value, pr = session.micProblem.value;
        if (st == FollowStatus.off || st == FollowStatus.failed) return const SizedBox.shrink();
        final warn = Colors.orange.shade800;
        final label = pr == 'silent'
            ? l.followNoSound
            : pr == 'quiet'
                ? l.followQuiet
                : switch (st) {
                    FollowStatus.listening => l.followListening,
                    FollowStatus.searching => l.followSearching,
                    FollowStatus.paused => l.followPaused,
                    _ => l.followStarting,
                  };
        return Padding(
          key: const ValueKey('follow-strip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.mic, size: 15, color: pr == null ? accent : warn),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context,
                      size: 12.5, weight: FontWeight.w700, color: pr == null ? ink : warn)),
            ),
            if (pr != null)
              TextButton(
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                onPressed: () => showFollowMicPicker(context),
                child: Text(l.followMicPick),
              )
            else if (st == FollowStatus.listening || st == FollowStatus.searching) ...[
              const SizedBox(width: 6),
              _LevelMeter(color: accent, track: sub.withValues(alpha: .25)),
            ],
            // "Show what's heard": what the model made of the last moments.
            if (SettingsScope.of(context).followShowHeard)
              Flexible(
                child: ValueListenableBuilder(
                  valueListenable: session.heard,
                  builder: (context, h, _) => Text(
                    h == null ? '' : '  ${isolateArabic(h.text)}',
                    key: const ValueKey('follow-strip-heard'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: uiStyle(context, size: 12, color: sub),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text('· ${l.followCaption}',
                  key: const ValueKey('follow-caption'),
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 12, color: sub)),
            ),
          ]),
        );
      },
    );
  }
}
