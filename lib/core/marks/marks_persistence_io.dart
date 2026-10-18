import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'marks_persistence.dart';

MarksPersistence create() => _FileMarksPersistence();

/// `<application support>/marks/`. Not the documents directory: on Linux and
/// Windows that is the user's own ~/Documents folder.
class _FileMarksPersistence implements MarksPersistence {
  Directory? _dir;

  Future<Directory> _root() async {
    final d = _dir ??= Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}marks');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _file(String name) async =>
      File('${(await _root()).path}${Platform.pathSeparator}$name');

  @override
  Future<String?> read(String name) async {
    final f = await _file(name);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String name, String data) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    // rename() replaces the target atomically on POSIX; on Windows it fails
    // if the target exists, so fall back to delete + rename there.
    try {
      await tmp.rename(f.path);
    } on FileSystemException {
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
    }
  }

  @override
  Future<void> delete(String name) async {
    final f = await _file(name);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> quarantine(String name) async {
    final f = await _file(name);
    if (await f.exists()) {
      await f.rename(
          '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
    }
  }
}
