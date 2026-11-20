import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:qiraah_ui/responsive.dart' show isDesktopPlatform;

import '../../core/l10n.dart';
import '../../core/mushaf_edition.dart';
import '../../core/packs/pack_catalog.dart';
import '../../core/packs/pack_install.dart';
import '../../core/verified_download.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/original/mushaf_packs.dart';
import '../../data/original/original_atlas.dart';
import '../../ui/adaptive_sheet.dart';

/// Tests: what "Choose folder…" picks, in place of the system's dialog.
@visibleForTesting
Future<String?> Function() pickPackFolder = () => getDirectoryPath();

/// [script]'s files, if it needs some and they aren't here: the prompt to get
/// them. True once they're here (a folder chosen); false if left.
Future<bool> ensureMushafPack(BuildContext context, String script) async {
  if (MushafPacks.available(script)) return true;
  return showPackSheet(context, script);
}

/// The prompt: download (High or Low, with sizes; one recommended), or, on a
/// desktop, a folder that already holds the files.
Future<bool> showPackSheet(BuildContext context, String script) async {
  final settings = SettingsScope.of(context);
  final ok = await showAdaptiveSheet<bool>(
    context,
    useRootNavigator: true,
    builder: (sheet) => _PackSheet(script: script, settings: settings),
  );
  return ok == true;
}

/// Chooses (or changes) [script]'s folder: true if one that holds the files
/// was chosen. A wrong one goes to [onProblem] (else a snackbar), saying
/// what's missing.
Future<bool> choosePackFolder(BuildContext context, String script,
    {ValueChanged<String>? onProblem, AppSettings? settings}) async {
  final s = settings ?? SettingsScope.of(context);
  final dir = await pickPackFolder();
  if (dir == null || !context.mounted) return false;
  final (pack, problem) = MushafPacks.check(dir, script);
  if (pack == null) {
    final l = context.l10n;
    final say = switch (problem) {
      PackProblem.noData => l.packBadData,
      PackProblem.noTier => l.packBadTier,
      PackProblem.otherEdition => l.packBadEdition(
          mushafEditionName(l, _editionIn(dir) ?? ''), mushafEditionName(l, script)),
      _ => l.packBadMissing,
    };
    if (onProblem != null) {
      onProblem(say);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(say)));
    }
    return false;
  }
  s.update(() => s.packDirs[script] = dir);
  OriginalAtlas.reset();
  MushafPacks.changes.value++;
  return true;
}

/// Forgets [script]'s folder (the files stay where they are).
void forgetPackFolder(BuildContext context, String script) {
  final s = SettingsScope.of(context);
  s.update(() => s.packDirs.remove(script));
  OriginalAtlas.reset();
  MushafPacks.changes.value++;
}

class _PackSheet extends StatefulWidget {
  final String script;
  final AppSettings settings;
  const _PackSheet({required this.script, required this.settings});

  @override
  State<_PackSheet> createState() => _PackSheetState();
}

class _PackSheetState extends State<_PackSheet> {
  String? _problem;

  /// This device's tier, once known (it asks how much memory there is).
  OriginalTier? _recommended;

  /// What the (signed) catalog offers for this print, by tier; null while
  /// it's fetched, or without downloads.
  Map<OriginalTier, PackEntry>? _offered;
  bool _catalogFailed = false;

  /// The download going on: its tier and how far.
  OriginalTier? _loading;
  double _progress = 0;
  Completer<void>? _cancel;

  @override
  void initState() {
    super.initState();
    originalTierOfDevice(lite: widget.settings.lite).then((t) {
      if (mounted) setState(() => _recommended = t);
    });
    if (PackCatalog.configured) {
      PackCatalog.packs().then((all) {
        if (!mounted) return;
        setState(() => _offered = {
              for (final p in all)
                if (p.edition == widget.script)
                  for (final t in OriginalTier.values)
                    if (t.name == p.tier) t: p,
            });
      }, onError: (Object e) {
        debugPrint('packs: $e');
        if (mounted) setState(() => _catalogFailed = true);
      });
    }
  }

  @override
  void dispose() {
    _cancel?.complete();
    super.dispose();
  }

  Future<void> _download(PackEntry p, OriginalTier t) async {
    final l = context.l10n;
    final cancel = _cancel = Completer<void>();
    setState(() {
      _loading = t;
      _progress = 0;
      _problem = null;
    });
    try {
      await PackInstall.install(p, cancel: cancel.future, onProgress: (done, total) {
        if (mounted) setState(() => _progress = done / total);
      });
      OriginalAtlas.reset();
      if (mounted) Navigator.pop(context, true);
    } on DownloadCancelled {
      // Left: what came so far stays, to go on from next time.
    } on DownloadBadFile {
      if (mounted) setState(() => _problem = l.followBadFile);
    } on PackRefused {
      if (mounted) setState(() => _problem = l.followBadFile);
    } on FileSystemException {
      if (mounted) setState(() => _problem = l.packNoSpace);
    } catch (e) {
      debugPrint('pack download: $e');
      if (mounted) setState(() => _problem = l.followNetError);
    } finally {
      if (mounted) setState(() => _loading = null);
      _cancel = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script, recommended = _recommended;
    final l = context.l10n;
    final p = pal(context);
    final name = mushafEditionName(l, script);
    final sizes = MushafPacks.sizesMb[script] ?? const {};
    Widget tier(OriginalTier t, String label) {
      final offer = _offered?[t];
      final mb = offer != null ? (offer.bytes / 1e6).round() : sizes[t];
      final loading = _loading == t;
      // Ready to download: the signed catalog has it, and nothing else is coming.
      final can = offer != null && _loading == null;
      final note = loading
          ? l.followDownloading((_progress * 100).floor())
          : offer != null
              ? l.packMb(mb ?? 0)
              : [
                  if (mb != null) l.packMb(mb),
                  !PackCatalog.configured || _catalogFailed || _offered != null
                      ? (_catalogFailed ? l.followNetError : l.packSoon)
                      : l.followStarting,
                ].join(' · ');
      return Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        key: ValueKey('pack-${t.name}'),
        enabled: can || loading,
        onTap: can ? () => _download(offer, t) : null,
        trailing: loading
            ? TextButton(onPressed: () => _cancel?.complete(), child: Text(l.cancel))
            : null,
        leading: const Icon(Icons.download_rounded),
        title: Row(children: [
          Flexible(child: Text(label)),
          if (t == recommended) ...[
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
        subtitle: Text(note),
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
            Text(l.packTitle(name),
                style: uiStyle(context, size: 19, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l.packBody, style: uiStyle(context, size: 14, color: p.ink2)),
            const SizedBox(height: 10),
            tier(OriginalTier.high, l.packHigh),
            tier(OriginalTier.low, l.packLow),
            if (!isDesktopPlatform() && _problem != null) ...[
              const SizedBox(height: 8),
              Text(_problem!,
                  key: const ValueKey('pack-problem'),
                  style: uiStyle(context, size: 13.5, color: Theme.of(context).colorScheme.error)),
            ],
            if (isDesktopPlatform()) ...[
              const Divider(height: 24),
              Text(l.packFolderHint, style: uiStyle(context, size: 13.5, color: p.ink2)),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const ValueKey('pack-folder'),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(l.packChooseFolder),
                  onPressed: () async {
                    setState(() => _problem = null);
                    final ok = await choosePackFolder(context, script,
                        settings: widget.settings,
                        onProblem: (m) => setState(() => _problem = m));
                    if (ok && context.mounted) Navigator.pop(context, true);
                  },
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(_problem!,
                    key: const ValueKey('pack-problem'),
                    style: uiStyle(context, size: 13.5, color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The edition [dir] (or the set over its tier folder) holds.
String? _editionIn(String dir) =>
    MushafPacks.editionAt(dir) ?? MushafPacks.editionAt(Directory(dir).absolute.parent.path);
