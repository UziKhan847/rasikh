import 'marks_persistence_prefs.dart'
    if (dart.library.io) 'marks_persistence_io.dart' as platform;

/// Where the marks files live. Named blobs (`index.json`, `book_<id>.json`)
/// rather than SharedPreferences keys: a teacher's books can run to megabytes,
/// which doesn't belong in the prefs file Android loads whole at start-up.
abstract class MarksPersistence {
  Future<String?> read(String name);

  /// Must be atomic: a crash mid-write leaves the old contents.
  Future<void> write(String name, String data);
  Future<void> delete(String name);

  /// Set aside a file that failed to parse (never silently overwrite data).
  Future<void> quarantine(String name);

  /// Files under app support storage on io platforms; prefs on the web.
  static MarksPersistence platformDefault() => platform.create();
}

/// In-memory, for tests.
class MemoryMarksPersistence implements MarksPersistence {
  final Map<String, String> files;
  final List<String> quarantined = [];
  MemoryMarksPersistence([Map<String, String>? files]) : files = files ?? {};

  @override
  Future<String?> read(String name) async => files[name];
  @override
  Future<void> write(String name, String data) async => files[name] = data;
  @override
  Future<void> delete(String name) async => files.remove(name);
  @override
  Future<void> quarantine(String name) async {
    final d = files.remove(name);
    if (d != null) {
      quarantined.add(name);
      files['$name.corrupt'] = d;
    }
  }
}
