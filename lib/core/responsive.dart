import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'settings.dart';
import 'theme.dart';

/// True when the desktop shell should be used: desktop OS, or a wide window,
/// unless the user forced a mode in settings.
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

bool useDesktop(BuildContext context) {
  final mode = SettingsScope.of(context).desktopMode;
  if (mode == 'on') return true;
  if (mode == 'off') return false;
  // auto:
  if (isDesktopPlatform()) return true;
  final w = MediaQuery.of(context).size.width;
  return kIsWeb && w >= 1024;
}

/// Marker mixin: screens that render their own desktop layout are pushed
/// full-screen by [pushAdaptive]; portrait-only screens get a phone frame.
mixin DesktopAware on Widget {}

Future<T?> pushAdaptive<T>(BuildContext context, Widget child) {
  if (!useDesktop(context) || child is DesktopAware) {
    return Navigator.push<T>(
        context, MaterialPageRoute(builder: (_) => child));
  }
  return Navigator.push<T>(
      context, MaterialPageRoute(builder: (_) => _DesktopFrame(child: child)));
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.surfaceHigh),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
