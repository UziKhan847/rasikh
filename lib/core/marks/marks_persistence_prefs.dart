import 'package:shared_preferences/shared_preferences.dart';

import 'marks_persistence.dart';

MarksPersistence create() => _PrefsMarksPersistence();

/// Web fallback (no file system): one prefs key per file.
class _PrefsMarksPersistence implements MarksPersistence {
  static const _prefix = 'noor.marks.';

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
}
