import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import 'kids_profile_picker.dart';

/// The three-stage gate every Kids Mode shell (mobile bottom-nav, desktop
/// sidebar) opens behind: no profile yet → [KidsProfilePicker]; a profile is
/// active but its [ProgressStore] hasn't loaded → a spinner; loaded → a
/// [ProgressScope] wraps [builder]. Shared so both shells load a profile
/// exactly once, the same way, rather than keeping two copies in sync.
///
/// Also where badges are synced. This is the one place guaranteed to hold
/// the active child's store for as long as Kids Mode is open, so a listener
/// here — see [_onProgressChanged] — catches a badge earned by ANY kind of
/// progress (a quiz, a reused Qāʿidah/Tajwīd unit, a reading), not only the
/// two places that used to call `unlockBadge` directly.
class KidsProfileGate extends StatefulWidget {
  final WidgetBuilder builder;
  const KidsProfileGate({super.key, required this.builder});

  @override
  State<KidsProfileGate> createState() => _KidsProfileGateState();
}

class _KidsProfileGateState extends State<KidsProfileGate> {
  ProgressStore? _progress;
  String? _loadedFor;

  // Guards against `kidsSyncBadges` re-entering itself: unlocking a badge or
  // awarding gems calls `notifyListeners()` on the very store this listens
  // to. `unlockBadge`/`awardGems` are no-ops on a repeat call (a Set add that
  // returns false notifies nothing further), so this would settle on its own
  // after one extra pass regardless — the flag just makes that explicit
  // rather than relying on it.
  bool _syncingBadges = false;

  void _onProgressChanged() {
    if (_syncingBadges || _progress == null) return;
    _syncingBadges = true;
    try {
      kidsSyncBadges(_progress!);
    } finally {
      _syncingBadges = false;
    }
  }

  void _attach(ProgressStore store) {
    _progress?.removeListener(_onProgressChanged);
    _progress = store;
    _progress!.addListener(_onProgressChanged);
    // Catches anything already earned before this listener existed — e.g. a
    // profile restored from a backup, or progress from before this sync
    // existed at all.
    _onProgressChanged();
  }

  @override
  void dispose() {
    _progress?.removeListener(_onProgressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (s.kidsProfiles.isEmpty || s.activeKidsProfile == null) {
      return KidsProfilePicker(onDone: () => setState(() {}));
    }
    final activeId = s.activeKidsProfileId!;
    if (_progress == null || _loadedFor != activeId) {
      return _ProfileLoader(
        key: ValueKey(activeId),
        profileId: activeId,
        onLoaded: (store) => setState(() {
          _attach(store);
          _loadedFor = activeId;
        }),
      );
    }
    return ProgressScope(
      progress: _progress!,
      child: Builder(builder: widget.builder),
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  final String profileId;
  final void Function(ProgressStore) onLoaded;
  const _ProfileLoader(
      {super.key, required this.profileId, required this.onLoaded});

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = ProgressStore(profileId: widget.profileId);
    await store.load();
    if (mounted) widget.onLoaded(store);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kidsPal(context).bg,
        body: Center(
            child: CircularProgressIndicator(color: kidsPal(context).accent)),
      );
}
