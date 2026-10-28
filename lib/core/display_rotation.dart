import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('qiraah/display');

/// The screen's rotation, Android's Surface.ROTATION_*: 0, 1 (90°: a phone
/// on its side with its camera on the left), 2, 3 (270°: camera on the
/// right). Elsewhere (and if it can't tell), 1.
Future<int> displayRotation() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return 1;
  try {
    return await _channel.invokeMethod<int>('rotation') ?? 1;
  } catch (_) {
    return 1;
  }
}

/// The rotation as Android reports each change — including a turn from one
/// side straight to the other, which changes nothing else Flutter sees.
final ValueNotifier<int> displayRotationChanges = () {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'rotation' && call.arguments is int) {
      displayRotationChanges.value = call.arguments as int;
    }
  });
  return ValueNotifier<int>(-1);
}();
