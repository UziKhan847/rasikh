import 'package:shared_preferences/shared_preferences.dart';

import 'marks_persistence.dart';

MarksPersistence create(String dir) => _PrefsMarksPersistence(dir);

/// Web fallback (no file system): one prefs key per file.
class _PrefsMarksPersistence implements MarksPersistence {
  _PrefsMarksPersistence(String dir)
      : _prefix = dir == 'marks' ? 'noor.marks.' : 'noor.$dir.';
  final String _prefix;

  @override
  Future<String?> read(String name) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$name');

  @override
  Future<void> write(String name, String data) async =>
      (await SharedPreferences.getInstance()).setString('$_prefix$name', data);

  @override
  Future<void> delete(String name) async =>
      (await SharedPreferences.getInstance()).remove('$_prefix$name');

  @override
  Future<void> quarantine(String name) async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString('$_prefix$name');
    if (d == null) return;
    await p.setString(
        '$_prefix$name.corrupt-${DateTime.now().millisecondsSinceEpoch}', d);
    await p.remove('$_prefix$name');
  }

  @override
  Future<void> wipe() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await p.remove(k);
    }
  }
}
