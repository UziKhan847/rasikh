import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// A [TapGestureRecognizer] that also fires [onLongPress], so a single
/// `TextSpan.recognizer` can serve both a tap and a long-press.
/// (Ported from the quran_memorization_helper project.)
class TapAndLongPressGestureRecognizer extends TapGestureRecognizer {
  TapAndLongPressGestureRecognizer({
    required this.onLongPress,
    required GestureTapCallback onTap,
    this.enableFeedback = true,
  }) {
    this.onTap = onTap;
  }

  bool _longPressAccepted = false;
  int? _initialButtons;

  GestureLongPressCallback onLongPress;

  @override
  Duration? get deadline => const Duration(milliseconds: 500);

  PointerDownEvent? _down;
  PointerUpEvent? _up;

  bool enableFeedback;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kPrimaryButton:
        return true;
      default:
        return false;
    }
  }

  @override
  void didExceedDeadline() {
    resolve(GestureDisposition.accepted);
    _longPressAccepted = true;
    super.acceptGesture(primaryPointer!);
    _checkLongPressStart();
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      if (!_longPressAccepted) {
        _up = event;
        _checkTapUp();
        super.handlePrimaryPointer(const PointerCancelEvent());
      }
      _resetTap();
      _resetLongPress();
    } else if (event is PointerCancelEvent) {
      super.handlePrimaryPointer(event);
      _resetLongPress();
      _resetTap();
    } else if (event is PointerDownEvent) {
      _initialButtons = event.buttons;
      _down = event;
    } else if (event is PointerMoveEvent) {
      if (event.buttons != _initialButtons) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(primaryPointer!);
      }
    }
  }

  void _checkTapUp() {
    if (_up == null) return;
    assert(_up!.pointer == _down!.pointer);
    switch (_down!.buttons) {
      case kPrimaryButton:
        if (onTap != null) invokeCallback<void>('onTap', onTap!);
        break;
      default:
    }
  }

  void _resetTap() {
    _up = null;
    _down = null;
  }

  void _checkLongPressStart() {
    switch (_initialButtons) {
      case kPrimaryButton:
        if (enableFeedback) HapticFeedback.vibrate();
        invokeCallback<void>('onLongPress', onLongPress);
        break;
      default:
    }
  }

  void _resetLongPress() {
    _longPressAccepted = false;
    _initialButtons = null;
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.rejected) {
      if (_longPressAccepted) _resetLongPress();
    }
    super.resolve(disposition);
  }

  @override
  void acceptGesture(int pointer) {
    // Intentionally empty: calling super would stop the long-press timer.
  }

  @override
  String get debugDescription => 'tap or long press';
}
