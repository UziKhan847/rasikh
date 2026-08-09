import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/downloads.dart';
import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/quran.dart';

/// 📥 Downloads — what's already saved for offline use, and what isn't, for
/// the two reciters and the word-by-word audio offered for bulk download
/// (see [downloadableReciters] for why Al-Tunaiji isn't one of them). Every
/// per-surah download/refresh call here reuses [AyahAudio]/[WbwAudio]
/// exactly as the reader's own download button does — this screen only adds
/// the missing "see everything at once, choose what to fetch ahead of time"
/// layer on top.
class DownloadsScreen extends StatefulWidget with DesktopAware {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<SurahMeta>? _meta;
  Map<int, DlState> _alafasy = {};
  Map<int, DlState> _husary = {};
  Map<int, DlState> _wbw = {};
  int _alafasyBytes = 0;
  int _husaryBytes = 0;
  int _wbwBytes = 0;
  bool _loading = true;

  // a single per-surah download in flight, keyed 'kind:surah'
  String? _activeKey;
  int _activeDone = 0;
  int _activeTotal = 1;

  // a bulk "download all" run in flight
  bool _bulkActive = false;
  bool _bulkCancelled = false;
  int _bulkIndex = 0;
  int _bulkTotal = 1;

  bool get _busy => _activeKey != null || _bulkActive;

  @override
  void initState() {
    super.initState();
    refreshStaleQuranCache();
    _load();
  }

  Future<void> _load() async {
    final meta = await QuranRepo.meta();
    final alafasy = await reciterDownloadStates('alafasy');
    final husary = await reciterDownloadStates('husary');
    final wbw = await wbwDownloadStates();
    final ab = await AyahAudio.instance.bytesUsed('alafasy');
    final hb = await AyahAudio.instance.bytesUsed('husary');
    final wb = await WbwAudio.instance.bytesUsed();
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _alafasy = alafasy;
      _husary = husary;
      _wbw = wbw;
      _alafasyBytes = ab;
      _husaryBytes = hb;
      _wbwBytes = wb;
      _loading = false;
    });
  }

  String _nameFor(String kind) => switch (kind) {
        'alafasy' => context.l10n.afasyName,
        'husary' => context.l10n.husaryName,
        _ => context.l10n.wordByWordLabel,
      };

  Map<int, DlState> _statesFor(String kind) => switch (kind) {
        'alafasy' => _alafasy,
        'husary' => _husary,
        _ => _wbw,
      };

  int _bytesFor(String kind) => switch (kind) {
        'alafasy' => _alafasyBytes,
        'husary' => _husaryBytes,
        _ => _wbwBytes,
      };

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _downloadOneSurah(String kind, SurahMeta m) async {
    if (kind == 'wbw') {
      final perAyah = await wbwWordsPerAyah(m.n);
      final total = perAyah.fold(0, (a, b) => a + b);
      if (mounted) setState(() => _activeTotal = total == 0 ? 1 : total);
      return WbwAudio.instance.downloadSurah(
          m.n, perAyah, (d, t) => mounted ? setState(() => _activeDone = d) : null);
    }
    if (mounted) setState(() => _activeTotal = m.ayahs);
    return AyahAudio.instance.downloadSurah(
        m.n, m.ayahs, (d, t) => mounted ? setState(() => _activeDone = d) : null,
        reciter: kind);
  }

  Future<void> _downloadOne(String kind, SurahMeta m) async {
    if (_busy) return;
    final key = '$kind:${m.n}';
    setState(() {
      _activeKey = key;
      _activeDone = 0;
      _activeTotal = 1;
    });
    final ok = await _downloadOneSurah(kind, m);
    if (!mounted) return;
    setState(() => _activeKey = null);
    await _load();
    if (!mounted) return;
    _snack(ok
        ? (kind == 'wbw'
            ? context.l10n.wbwAudioSaved(m.tname)
            : context.l10n.surahAudioSaved(m.tname))
        : context.l10n.downloadFailed);
  }

  Future<void> _downloadAll(String kind) async {
    if (_busy || _meta == null) return;
    final name = _nameFor(kind);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.downloadAllFor(name)),
        content: Text(context.l10n.confirmBulkDownloadBody(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.download)),
        ],
      ),
    );
    if (confirmed != true) return;
    final meta = _meta!;
    setState(() {
      _bulkActive = true;
      _bulkCancelled = false;
      _bulkIndex = 0;
      _bulkTotal = meta.length;
    });
    var anyFailed = false;
    for (var i = 0; i < meta.length; i++) {
      if (_bulkCancelled) break;
      final m = meta[i];
      setState(() {
        _bulkIndex = i + 1;
        _activeDone = 0;
        _activeTotal = 1;
      });
      final ok = await _downloadOneSurah(kind, m);
      if (!ok) anyFailed = true;
      if (!mounted) return;
    }
    setState(() => _bulkActive = false);
    await _load();
    if (!mounted) return;
    _snack(anyFailed
        ? context.l10n.downloadFailed
        : context.l10n.bulkDownloadComplete(name));
  }

  Future<void> _deleteOne(String kind, SurahMeta m) async {
    if (_busy) return;
    final name = _nameFor(kind);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.confirmDeleteOneBody(name, m.tname)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (kind == 'wbw') {
      await WbwAudio.instance.deleteSurah(m.n);
    } else {
      await AyahAudio.instance.deleteSurah(kind, m.n);
    }
    await _load();
  }

  Future<void> _deleteAllFor(String kind) async {
    if (_busy) return;
    final name = _nameFor(kind);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteAllFor(name)),
        content: Text(context.l10n.confirmDeleteAllBody(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (kind == 'wbw') {
      await WbwAudio.instance.deleteAll();
    } else {
      await AyahAudio.instance.deleteAll(kind);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.downloads)),
      body: SafeArea(
        top: false,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: pal(context).accent))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(children: [
                    if (_bulkActive) _bulkBanner(context),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount: _meta!.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) return _summaryCard(context);
                          return _surahRow(context, _meta![i - 1]);
                        },
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _bulkBanner(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal(context).accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: pal(context).accent,
                value: _activeTotal > 0 ? _activeDone / _activeTotal : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                _bulkCancelled
                    ? context.l10n.bulkDownloadCancelling
                    : context.l10n.bulkDownloadProgress(_bulkIndex, _bulkTotal),
                style: uiStyle(context, size: 13, weight: FontWeight.w600)),
          ),
          if (!_bulkCancelled)
            TextButton(
                onPressed: () => setState(() => _bulkCancelled = true),
                child: Text(context.l10n.cancel)),
        ]),
      );

  Widget _summaryCard(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pal(context).surfaceHigh),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.downloadsIntro,
              style: uiStyle(context, size: 13, color: pal(context).textDim)
                  .copyWith(height: 1.45)),
          const SizedBox(height: 16),
          _categoryRow(context, 'alafasy'),
          const Divider(height: 26),
          _categoryRow(context, 'husary'),
          const Divider(height: 26),
          _categoryRow(context, 'wbw'),
          const SizedBox(height: 14),
          Text(context.l10n.tunaijiDownloadNote,
              style: uiStyle(context, size: 12, color: pal(context).textDim)
                  .copyWith(height: 1.4)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.sync_rounded, size: 15, color: pal(context).textDim),
            const SizedBox(width: 6),
            Expanded(
                child: Text(context.l10n.complianceNote,
                    style: uiStyle(context, size: 11.5, color: pal(context).textDim))),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await refreshStaleQuranCache();
                      await _load();
                      if (!context.mounted) return;
                      _snack(context.l10n.checkedForUpdates);
                    },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.checkForUpdates),
            ),
          ),
        ]),
      );

  Widget _categoryRow(BuildContext context, String kind) {
    final name = _nameFor(kind);
    final bytes = _bytesFor(kind);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: uiStyle(context, size: 14.5, weight: FontWeight.w700)),
          Text(formatBytes(bytes),
              style: uiStyle(context, size: 12, color: pal(context).textDim)),
        ]),
      ),
      if (bytes > 0)
        IconButton(
          tooltip: context.l10n.deleteAllFor(name),
          onPressed: _busy ? null : () => _deleteAllFor(kind),
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.bad),
        ),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _downloadAll(kind),
        icon: const Icon(Icons.download_rounded, size: 16),
        label: Text(context.l10n.downloadAll),
      ),
    ]);
  }

  Widget _surahRow(BuildContext context, SurahMeta m) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal(context).surfaceHigh),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pal(context).accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('${m.n}',
                style: uiStyle(context,
                    size: 12, weight: FontWeight.w800, color: pal(context).accentDeep)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.tname,
                  style: uiStyle(context, size: 14, weight: FontWeight.w700)),
              Text(
                  context.l10n.typeAyat(
                      m.type == 'meccan' ? context.l10n.meccan : context.l10n.medinan,
                      m.ayahs),
                  style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
            ]),
          ),
          _statusChip(context, 'alafasy', m),
          _statusChip(context, 'husary', m),
          _statusChip(context, 'wbw', m),
        ]),
      );

  Widget _statusChip(BuildContext context, String kind, SurahMeta m) {
    final key = '$kind:${m.n}';
    final active = _activeKey == key;
    final state = _statesFor(kind)[m.n] ?? DlState.none;
    final label = kind == 'wbw' ? 'W' : (kind == 'alafasy' ? 'A' : 'Ḥ');
    final name = _nameFor(kind);

    if (active) {
      return SizedBox(
        width: 34, height: 34,
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: pal(context).accent,
                value: _activeTotal > 0 ? _activeDone / _activeTotal : null),
          ),
        ),
      );
    }

    final (icon, color) = switch (state) {
      DlState.full => (Icons.check_circle_rounded, AppColors.ok),
      DlState.partial => (Icons.incomplete_circle_rounded, pal(context).accent),
      DlState.none => (Icons.download_rounded, pal(context).textDim),
    };
    final stateLabel = switch (state) {
      DlState.full => context.l10n.downloadedFull,
      DlState.partial => context.l10n.downloadedPartial,
      DlState.none => context.l10n.notDownloaded,
    };

    return Tooltip(
      message: '$name ($label) · $stateLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _busy
            ? null
            : () => state == DlState.full
                ? _deleteOne(kind, m)
                : _downloadOne(kind, m),
        child: SizedBox(
          width: 34, height: 34,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}
