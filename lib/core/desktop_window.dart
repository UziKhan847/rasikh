import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:qiraah_ui/responsive.dart' show isDesktopPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// The app's window on a computer: fullscreen, its title, and coming back the
/// size and in the place it was left. Does nothing elsewhere.
///
/// (window_manager 0.6's own API: the app's window is a [wm.Window], its
/// size, place, title and fullscreen are properties of it, and its moves
/// and resizes are events.)
class DesktopWindow {
  DesktopWindow._();

  static wm.Window? _window;
  static wm.ListenerId? _listening;
  static bool get ready => _window != null;
  static bool fullscreen = false;
  static const _key = 'noor.window.bounds';
  static const minimum = Size(640, 480);

  static Future<void> start() async {
    if (kIsWeb || !isDesktopPlatform()) return;
    try {
      final w = wm.WindowManager.instance.getCurrent();
      if (w == null) return;
      _window = w;
      w.minimumSize = minimum.toNative();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key)?.map(double.tryParse).toList();
      if (saved != null && saved.length == 4 && !saved.contains(null)) {
        final (x, y, width, height) = (saved[0]!, saved[1]!, saved[2]!, saved[3]!);
        if (width >= minimum.width && height >= minimum.height) {
          w.bounds = Rect.fromLTWH(x, y, width, height).toNative();
        }
      }
      _listening = w.addListener((e) {
        if (e is wm.WindowResizedEvent || e is wm.WindowMovedEvent) _saveSoon();
      });
    } catch (e) {
      _window = null;
      debugPrint('[window] $e');
    }
  }

  static Future<void> toggleFullscreen() async {
    final w = _window;
    if (w == null) return;
    fullscreen = !fullscreen;
    w.isFullScreen = fullscreen;
  }

  static Future<void> leaveFullscreen() async {
    if (ready && fullscreen) await toggleFullscreen();
  }

  static String? _title;

  static void setTitle(String title) {
    final w = _window;
    if (w == null || title == _title) return;
    _title = title;
    w.title = title;
  }

  static Timer? _save;

  /// Where the window is, kept a moment after it stops moving: a drag sends
  /// an event per step.
  static void _saveSoon() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), () async {
      final w = _window;
      if (w == null || fullscreen) return;
      final b = w.bounds.toRect();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, ['${b.left}', '${b.top}', '${b.width}', '${b.height}']);
    });
  }

  /// Tests: forget the window.
  @visibleForTesting
  static void debugReset() {
    final w = _window, l = _listening;
    if (w != null && l != null) w.removeListener(l);
    _window = null;
    _listening = null;
  }
}
