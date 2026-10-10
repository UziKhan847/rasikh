import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The screen's refresh rate, on Android.
///
/// The app asks for the screen's fastest mode at start (`MainActivity`), so
/// lists and pages scroll at 90 or 120 Hz where the phone has it. Kids Mode's
/// Ultra scene takes longer than a 120 Hz frame on most phones, and frames
/// that keep missing that deadline judder more than an even 60, so while it
/// runs it holds the screen at 60 ([hold60] / [release60]). Every other
/// screen, Detail level and lesson runs at the fastest rate.
///
/// Elsewhere (iOS — whose ProMotion is already allowed in Info.plist —, the
/// desktop, the web, tests) it does nothing.
class DisplayRate {
  DisplayRate._();

  static const _channel = MethodChannel('qiraah/display');
  static int _holds = 0;

  /// The refresh rate last asked for, in Hz; 0 until known.
  static final hz = ValueNotifier<double>(0);

  /// Whether something is holding the screen at 60.
  static bool get holding60 => _holds > 0;

  static void hold60() {
    if (++_holds == 1) _apply();
  }

  static void release60() {
    if (_holds == 0) return;
    if (--_holds == 0) _apply();
  }

  /// Asks again for the current choice, to learn [hz].
  static void refresh() => _apply();

  static Future<void> _apply() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final rate = await _channel.invokeMethod<double>(
        'setRate',
        _holds > 0 ? '60' : 'max',
      );
      if (rate != null && rate > 0) hz.value = rate;
    } on MissingPluginException {
      // Not running on the app's own activity (tests, a plugin host).
    } on PlatformException {
      // Left as it is.
    }
  }
}
