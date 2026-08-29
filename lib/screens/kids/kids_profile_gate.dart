import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import 'kids_profile_picker.dart';

/// The three-stage gate every Kids Mode shell (mobile bottom-nav, desktop
/// sidebar) opens behind: no profile yet → [KidsProfilePicker]; a profile is
/// active but its [ProgressStore] hasn't loaded → a spinner; loaded → a
/// [ProgressScope] wraps [builder]. Shared so both shells load a profile
/// exactly once, the same way, rather than keeping two copies in sync.
class KidsProfileGate extends StatefulWidget {
  final WidgetBuilder builder;
  const KidsProfileGate({super.key, required this.builder});

  @override
  State<KidsProfileGate> createState() => _KidsProfileGateState();
}

class _KidsProfileGateState extends State<KidsProfileGate> {
  ProgressStore? _progress;
  String? _loadedFor;

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
          _progress = store;
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
