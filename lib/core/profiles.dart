import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fluency/fluency_store.dart';
import 'marks/marks_persistence.dart';
import 'marks/marks_store.dart';
import 'settings.dart';

/// One person using the app on this device: their own marks (and their
/// students' mark books), place, bookmarks, learning, streak and mode. The
/// theme, language and muṣḥaf look are the device's, shared.
class Profile {
  final String id;
  String name;
  int hue;

  /// The mode this profile opens to ('' until chosen).
  String mode;
  int lastUsedAt;
  Profile({
    required this.id,
    required this.name,
    required this.hue,
    this.mode = '',
    this.lastUsedAt = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        hue: (j['hue'] ?? 165) as int,
        mode: (j['mode'] ?? '') as String,
        lastUsedAt: (j['used'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'hue': hue, 'mode': mode, 'used': lastUsedAt};
}

/// The profiles on this device, and which is in use. The first is the
/// default one: its data is what was here before profiles (the plain
/// keys, the `marks/` folder), so nothing moves for an existing install;
/// another profile's keys end in `@<id>` and its marks live in
/// `profiles/<id>/marks/`.
class ProfileStore extends ChangeNotifier {
  static const key = 'noor.profiles.v1';
  static const defaultId = 'default';

  final List<Profile> profiles = [];
  String _active = defaultId;

  /// Where a profile's marks are kept (tests pass memory).
  final MarksPersistence Function(String dir) persistenceFor;
  ProfileStore({MarksPersistence Function(String dir)? persistenceFor})
      : persistenceFor =
            persistenceFor ?? ((dir) => MarksPersistence.platformDefault(dir: dir));

  Profile get active =>
      profiles.firstWhere((p) => p.id == _active, orElse: () => profiles.first);

  static String suffixOf(String id) => id == defaultId ? '' : '@$id';
  static String marksDirOf(String id) =>
      id == defaultId ? 'marks' : 'profiles/$id/marks';

  /// The active profile's marks persistence.
  MarksPersistence get marksPersistence => persistenceFor(marksDirOf(_active));

  /// Reads the profiles (first run: the default one, in [settings]' mode)
  /// and points the progress keys at the active one. Before the progress
  /// and marks load.
  Future<void> load(AppSettings settings) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    profiles.clear();
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in (j['profiles'] as List? ?? const [])) {
          profiles.add(Profile.fromJson((e as Map).cast<String, dynamic>()));
        }
        _active = (j['active'] ?? defaultId) as String;
      } catch (_) {}
    }
    if (!profiles.any((x) => x.id == defaultId)) {
      profiles.insert(0, Profile(id: defaultId, name: '', hue: 165));
    }
    if (!profiles.any((x) => x.id == _active)) _active = defaultId;
    ProgressStore.profileSuffix = suffixOf(_active);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode({
      'active': _active,
      'profiles': [for (final x in profiles) x.toJson()],
    }));
  }

  /// A new profile, named [name], not yet in use.
  Future<Profile> add(String name) async {
    final r = math.Random();
    final id = List.generate(8, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)]).join();
    const hues = [165.0, 25, 280, 220, 50, 330, 140, 75];
    final p = Profile(id: id, name: name.trim(), hue: hues[profiles.length % hues.length].toInt());
    profiles.add(p);
    notifyListeners();
    await _save();
    return p;
  }

  Future<void> rename(String id, String name) async {
    profiles.firstWhere((p) => p.id == id).name = name.trim();
    notifyListeners();
    await _save();
  }

  /// Makes [id] the profile in use: what's pending is saved, then the
  /// progress and marks are the other profile's.
  Future<void> switchTo(
    String id, {
    required AppSettings settings,
    required ProgressStore progress,
    MarksStore? marks,
    FluencyStore? fluency,
  }) async {
    if (id == _active || !profiles.any((p) => p.id == id)) return;
    _active = id;
    active.lastUsedAt = DateTime.now().millisecondsSinceEpoch;
    ProgressStore.profileSuffix = suffixOf(id);
    await progress.reload();
    await marks?.reopen(marksPersistence);
    await fluency?.reload();
    settings.update(() {});
    notifyListeners();
    await _save();
  }

  /// Deletes [id]'s profile and everything it kept (not the default one,
  /// nor the one in use).
  Future<void> remove(String id) async {
    if (id == defaultId || id == _active) return;
    profiles.removeWhere((p) => p.id == id);
    final p = await SharedPreferences.getInstance();
    for (final k in ProgressStore.keysOf(suffixOf(id))) {
      await p.remove(k);
    }
    await p.remove('${FluencyStore.keyBase}${suffixOf(id)}');
    await persistenceFor(marksDirOf(id)).wipe();
    notifyListeners();
    await _save();
  }

  /// [id]'s last muṣḥaf page, without loading the profile.
  Future<int?> lastPageOf(String id) async =>
      ProgressStore.peekPage(await SharedPreferences.getInstance(), suffixOf(id));
}

class ProfileScope extends InheritedNotifier<ProfileStore> {
  const ProfileScope({super.key, required ProfileStore profiles, required super.child})
      : super(notifier: profiles);

  static ProfileStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.notifier;
}
