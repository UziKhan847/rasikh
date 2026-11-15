import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/desktop_window.dart';
import '../../core/keymap.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/profiles.dart';
import '../../core/settings.dart';
import '../../ui/app_icons.dart';
import '../mushaf_screen.dart';
import 'sections.dart' show openSection;

/// The top-level places of the app: the muṣḥaf (its home), the Hifẓ
/// history, the settings.
enum AppSection { mushaf, hifz, settings }

/// Lets any screen inside the shell switch section (Today's tiles open the
/// reader, Learn or Trace this way).
class ShellScope extends InheritedWidget {
  final void Function(AppSection) go;

  /// True while a screen reads in focus (the muṣḥaf with its menus hidden):
  /// the desktop sidebar and its restore button step aside.
  final ValueNotifier<bool> focus;
  const ShellScope(
      {super.key, required this.go, required this.focus, required super.child});

  static ShellScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>();

  static void setFocus(BuildContext context, bool on) {
    final n = maybeOf(context)?.focus;
    if (n != null && n.value != on) n.value = on;
  }

  static void goTo(BuildContext context, AppSection s) {
    final scope = context.getInheritedWidgetOfExactType<ShellScope>();
    if (scope != null) {
      scope.go(s);
    } else if (s == AppSection.mushaf) {
      openMushaf(context);
    }
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Opens the 15-line muṣḥaf full-screen: at [page] in [script] (both default
/// to the last page read / the muṣḥaf setting), optionally straight into
/// marking mode.
void openMushaf(
  BuildContext context, {
  int? page,
  String? script,
  bool startMarking = false,
}) {
  // The muṣḥaf is the home page: back to it, never a second one over it.
  if (HomeLink.ready && !startMarking) {
    HomeLink.show(context, page: page, script: script);
    return;
  }
  final prog = ProgressScope.read(context);
  Navigator.of(context, rootNavigator: !useDesktop(context)).push(
      MaterialPageRoute(
          builder: (_) => MushafPageScreen(
              startPage: page ?? prog.lastMushafPage ?? 1,
              script: script,
              pageScript: page == null ? prog.lastMushafScript : null,
              startMarking: startMarking)));
}

String sectionLabel(BuildContext context, AppSection s) => switch (s) {
  AppSection.mushaf => context.l10n.navMushaf,
  AppSection.hifz => context.l10n.hsTitle,
  AppSection.settings => context.l10n.settings,
};

IconData sectionIcon(AppSection s) => switch (s) {
  AppSection.mushaf => AppIcons.mushaf,
  AppSection.hifz => AppIcons.hifz,
  AppSection.settings => AppIcons.settings,
};

/// The app shell: the muṣḥaf, full screen, on every layout. Everything else
/// is a tap away from its tools.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _focus = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus.dispose();
    super.dispose();
  }

  /// F11 (or what it's been changed to), from wherever: the window on a
  /// computer; the system's bars on a phone or tablet.
  bool _fullscreen(KeyEvent e) {
    final s = SettingsScope.of(context);
    if (!s.keymap.matches(KeyAction.fullscreen, e)) return false;
    // A letter it's been changed to is still a letter in a text field.
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    if (field != null) return false;
    if (isDesktopPlatform()) {
      DesktopWindow.toggleFullscreen();
    } else {
      s.update(() => s.immersive = !s.immersive);
    }
    return true;
  }

  /// Ctrl+Shift+L (unless changed) switches between the desktop and phone
  /// layouts. A global
  /// handler rather than a Shortcuts widget, so it works whatever has focus
  /// (the muṣḥaf keeps focus for its arrow keys).
  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && mounted && _fullscreen(e)) return true;
    if (e is! KeyDownEvent || !mounted) return false;
    if (!SettingsScope.of(context).keymap.matches(KeyAction.toggleLayout, e)) return false;
    toggleLayout(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // read, not of: the home must not rebuild on every progress change.
    final prog = ProgressScope.read(context);
    final Widget home = MushafPageScreen(
      key: const ValueKey('home-mushaf'),
      home: true,
      startPage: prog.lastMushafPage ?? 1,
      pageScript: prog.lastMushafScript,
    );
    // Another profile: its home afresh (its page, its mode).
    final profile = ProfileScope.maybeOf(context)?.active.id ?? '';
    return ShellScope(
      go: (sec) => openSection(context, sec),
      focus: _focus,
      child: KeyedSubtree(key: ValueKey('profile-$profile'), child: home),
    );
  }
}
