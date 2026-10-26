import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../ui/app_icons.dart';
import '../learn_screen.dart';
import '../mushaf_screen.dart';
import '../quran_screen.dart';
import '../tracing_screen.dart';
import 'app_mode.dart' show openSection;

/// The top-level places of the app.
enum AppSection { today, quran, mushaf, hifz, learn, trace, settings }

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
void openMushaf(BuildContext context,
    {int? page, String? script, bool startMarking = false}) {
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
      AppSection.today => context.l10n.navToday,
      AppSection.quran => context.l10n.navReader,
      AppSection.mushaf => context.l10n.navMushaf,
      AppSection.hifz => context.l10n.mkHifz,
      AppSection.learn => context.l10n.navLearn,
      AppSection.trace => context.l10n.navTrace,
      AppSection.settings => context.l10n.settings,
    };

IconData sectionIcon(AppSection s) => switch (s) {
      AppSection.today => AppIcons.today,
      AppSection.quran => AppIcons.reader,
      AppSection.mushaf => AppIcons.mushaf,
      AppSection.hifz => AppIcons.hifz,
      AppSection.learn => AppIcons.learn,
      AppSection.trace => AppIcons.trace,
      AppSection.settings => AppIcons.settings,
    };

/// The app shell: the chosen mode's home, full screen, on every layout —
/// the muṣḥaf (Hifẓ), the reader, the learning modules or the tracing
/// studio. Everything else is a tap away from its settings button (long
/// press: the mode switcher; see app_mode.dart).
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

  /// Ctrl+Shift+L switches between the desktop and phone layouts. A global
  /// handler rather than a Shortcuts widget, so it works whatever has focus
  /// (the muṣḥaf keeps focus for its arrow keys).
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyL) {
      return false;
    }
    final k = HardwareKeyboard.instance;
    if (!k.isShiftPressed || !(k.isControlPressed || k.isMetaPressed)) {
      return false;
    }
    if (!mounted || !canUseDesktopShell(context)) return false;
    toggleLayout(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    // read, not of: the home must not rebuild on every progress change.
    final prog = ProgressScope.read(context);
    final Widget home = switch (s.mode ?? AppMode.reader) {
      AppMode.hifz => MushafPageScreen(
          key: const ValueKey('home-mushaf'),
          home: true,
          startPage: prog.lastMushafPage ?? 1,
          pageScript: prog.lastMushafScript),
      AppMode.reader => const SurahListScreen(key: ValueKey('home-reader')),
      AppMode.learn => const LearnScreen(key: ValueKey('home-learn')),
      AppMode.write => const TracingScreen(key: ValueKey('home-write')),
    };
    return ShellScope(
      go: (sec) => openSection(context, sec),
      focus: _focus,
      child: home,
    );
  }
}
