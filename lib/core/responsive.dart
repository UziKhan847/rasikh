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

/// True on a genuinely large screen: the Material "sw600dp" tablet
/// breakpoint. Uses the shorter side so it doesn't flip when the device is
/// rotated between portrait and landscape.
bool isTabletSize(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// A screen size/platform where the desktop shell is appropriate: an actual
/// desktop OS, the web (which can be resized to anything), or a tablet-sized
/// native device. A phone is never included — the desktop shell (sidebar,
/// multi-column layouts) doesn't fit a phone screen regardless of what the
/// user asks for.
bool canUseDesktopShell(BuildContext context) =>
    isDesktopPlatform() || kIsWeb || isTabletSize(context);

bool useDesktop(BuildContext context) {
  final mode = SettingsScope.of(context).desktopMode;
  // A phone can never be forced into the desktop shell, even by an explicit
  // 'on' — only 'auto' and 'off' are meaningful there.
  if (mode == 'on') return canUseDesktopShell(context);
  if (mode == 'off') return false;
  // auto:
  if (isDesktopPlatform()) return true;
  if (kIsWeb) return MediaQuery.of(context).size.width >= 1024;
  // Native mobile: tablets default to the desktop shell, phones don't.
  return isTabletSize(context);
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
