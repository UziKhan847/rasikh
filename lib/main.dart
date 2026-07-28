import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;

import 'core/responsive.dart';
import 'core/l10n.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'screens/desktop/desktop_shell.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  final progress = ProgressStore();
  await Future.wait([settings.load(), progress.load()]);
  WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpFonts());
  runApp(QiraahArabiyyahApp(settings: settings, progress: progress));
}

class QiraahArabiyyahApp extends StatelessWidget {
  final AppSettings settings;
  final ProgressStore progress;
  const QiraahArabiyyahApp(
      {super.key, required this.settings, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: _SystemUiSync(
          settings: settings,
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) => MaterialApp(
              // onGenerateTitle, not title: this callback is handed a context
              // BELOW the Localizations widget, so l10n is available. Reading
              // context.l10n for `title` here would throw.
              onGenerateTitle: (context) => context.l10n.qiraahArabiyyah,
              debugShowCheckedModeBanner: false,
              theme: buildTheme(settings),
              // The language comes from the in-app picker, not the device.
              locale: Locale(settings.language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RootScreen(),
              builder: (context, child) => Directionality(
                textDirection: L10n.isRtl(settings.language)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the OS chrome in step with the app-wide immersive setting: applies
/// it on startup and whenever it changes, and re-asserts it when the app
/// resumes (Android quietly restores the system bars after backgrounding or
/// the keyboard). No-ops on platforms without system bars.
class _SystemUiSync extends StatefulWidget {
  final AppSettings settings;
  final Widget child;
  const _SystemUiSync({required this.settings, required this.child});

  @override
  State<_SystemUiSync> createState() => _SystemUiSyncState();
}

class _SystemUiSyncState extends State<_SystemUiSync>
    with WidgetsBindingObserver {
  bool? _applied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applied = null; // force a re-assert
      _sync();
    } else if (state == AppLifecycleState.paused) {
      // Flush any debounced settings write (see AppSettings.update) before
      // the OS can suspend/kill the process mid-background.
      widget.settings.flush();
    }
  }

  void _sync() {
    final on = widget.settings.immersive;
    if (on == _applied) return;
    _applied = on;
    SystemChrome.setEnabledSystemUIMode(
            on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Picks the desktop shell or the mobile home based on platform / window /
/// the manual override in settings. Rebuilds live when the override changes.

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      useDesktop(context) ? const DesktopShell() : const HomeScreen();
}

/// Rasterizes a sample of each bundled Arabic face once at startup, so the
/// first real Qur'an/tracing screen doesn't pay the shaping cost mid-frame.
void _warmUpFonts() {
  for (final family in const [
    'UthmanicHafs',
    'ScheherazadeNew',
    // The 15-line mushaf's own faces — by far the heaviest bundled (their
    // GPOS/positioning tables run 5-7x larger than the fonts above, since
    // DigitalKhatt does the mushaf's mark-stacking/ayah-circle typesetting
    // via OpenType tables), so cold-shaping them belongs here too rather
    // than landing on the mushaf screen's first open or script switch.
    'DigitalKhattV2',
    'DigitalKhattIndoPak',
  ]) {
    final tp = TextPainter(
      text: TextSpan(
          text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          style: TextStyle(fontFamily: family, fontSize: 28)),
      textDirection: TextDirection.rtl,
    )..layout();
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), Offset.zero);
    rec.endRecording();
    tp.dispose();
  }
}
