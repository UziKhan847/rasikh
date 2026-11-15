import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:qiraah_ui/responsive.dart' show isDesktopPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// The app's window on a computer: fullscreen, its title, and coming back the
/// size and in the place it was left. Does nothing elsewhere.
class DesktopWindow with WindowListener {
  DesktopWindow._();
  static final _instance = DesktopWindow._();

  static bool _ready = false;
  static bool get ready => _ready;
  static bool fullscreen = false;
  static const _key = 'noor.window.bounds';
  static const minimum = Size(640, 480);

  static Future<void> start() async {
    if (kIsWeb || !isDesktopPlatform()) return;
    try {
      await windowManager.ensureInitialized();
      _ready = true;
      await windowManager.setMinimumSize(minimum);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key)?.map(double.tryParse).toList();
      if (saved != null && saved.length == 4 && !saved.contains(null)) {
        final (x, y, w, h) = (saved[0]!, saved[1]!, saved[2]!, saved[3]!);
        if (w >= minimum.width && h >= minimum.height) {
          await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
        }
      }
      windowManager.addListener(_instance);
    } catch (e) {
      _ready = false;
      debugPrint('[window] $e');
    }
  }

  static Future<void> toggleFullscreen() async {
    if (!_ready) return;
    fullscreen = !fullscreen;
    await windowManager.setFullScreen(fullscreen);
  }

  static Future<void> leaveFullscreen() async {
    if (_ready && fullscreen) await toggleFullscreen();
  }

  static String? _title;

  static void setTitle(String title) {
    if (!_ready || title == _title) return;
    _title = title;
    unawaited(windowManager.setTitle(title));
  }

  Timer? _save;

  void _saveSoon() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), () async {
      if (fullscreen) return;
      final b = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, ['${b.left}', '${b.top}', '${b.width}', '${b.height}']);
    });
  }

  @override
  void onWindowResized() => _saveSoon();
  @override
  void onWindowMoved() => _saveSoon();
}
