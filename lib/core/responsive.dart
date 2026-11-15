import 'package:flutter/widgets.dart';
import 'package:qiraah_ui/responsive.dart';

import 'settings.dart';

export 'package:qiraah_ui/responsive.dart';

/// Switches between desktop and mobile mode (Ctrl+Shift+L).
void toggleLayout(BuildContext context) {
  final s = SettingsScope.of(context);
  final desktop = useDesktop(context);
  s.update(() => s.desktopMode = desktop ? 'off' : 'on');
}

