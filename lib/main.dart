import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlayStyle;

import 'core/audio.dart';
import 'core/fluency/fluency_store.dart';
import 'core/jank_watch.dart';
import 'core/l10n.dart';
import 'core/marks/marks_store.dart';
import 'core/perf_log.dart';
import 'core/profiles.dart';
import 'core/sync/pocketbase_backend.dart';
import 'core/sync/sync_backend.dart';
import 'core/sync/sync_engine.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'screens/onboarding_screen.dart';
import 'data/mushaf.dart';
import 'data/mushaf_atlas.dart';
import 'screens/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  final progress = ProgressStore();
  final profiles = ProfileStore();
  await settings.load();
  // The profile in use decides whose progress and marks load.
  await profiles.load(settings);
  await progress.load();
  // The Reader's fluency work: small, per profile.
  final fluency = FluencyStore();
  await fluency.load();
  // Marks load in the background: nothing on the first frame needs them,
  // and the marks UI waits for `ready`.
  final marks = MarksStore(persistence: profiles.marksPersistence);
  // Sync is opt-in: start() only touches the network if this device is
  // already signed in to a marks server.
  final sync = SyncEngine(
      store: marks,
      backend: settings.syncServer.isEmpty
          ? const NoServerBackend()
          : await PocketBaseSyncBackend.create(settings.syncServer));
  unawaited(marks.load().then((_) => sync.start()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _warmUpFonts();
    // The muṣḥaf's glyph atlas, ready before the muṣḥaf is first opened.
    final script = settings.mushafScript;
    unawaited(MushafRepo.ensure(script).then(
        (_) => MushafAtlas.load(script, MushafRepo.tokensSync(script))));
  });
  // Slow-frame logging in profile builds (or with MUSHAF_PERF=true).
  PerfLog.start();
  // A device that keeps dropping frames is offered Lite mode, once.
  JankWatch.start(settings);
  runApp(QiraahArabiyyahApp(
      settings: settings,
      progress: progress,
      marks: marks,
      sync: sync,
      profiles: profiles,
      fluency: fluency));
}

class QiraahArabiyyahApp extends StatelessWidget {
  final AppSettings settings;
  final ProgressStore progress;
  final MarksStore? marks;
  final SyncEngine? sync;
  final ProfileStore? profiles;
  final FluencyStore? fluency;
  const QiraahArabiyyahApp({
    super.key,
    required this.settings,
    required this.progress,
    this.marks,
    this.sync,
    this.profiles,
    this.fluency,
  });

  @override
  Widget build(BuildContext context) {
    final app = SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: _SystemUiSync(
          settings: settings,
          marks: marks,
          sync: sync,
          // The app itself (theme, language, motion) rebuilds only when one
          // of those changes, not on every setting saved.
          child: _Select(
            settings: settings,
            select: (s) => (s.theme, s.language, s.lite, s.appTheme),
            builder: (context) => MaterialApp(
              // onGenerateTitle, not title: this callback is handed a context
              // BELOW the Localizations widget, so l10n is available. Reading
              // context.l10n for `title` here would throw.
              onGenerateTitle: (context) => context.l10n.qiraahArabiyyah,
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: rootMessengerKey,
              theme: buildTheme(settings),
              // The language comes from the in-app picker, not the device.
              locale: Locale(settings.language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const RootScreen(),
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyleFor(paletteOf(settings.theme)),
                child: Directionality(
                  textDirection: L10n.isRtl(settings.language)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: _NavBarInset(
                    color: paletteOf(settings.theme).bg,
                    child: _TimeTracker(
                      progress: progress,
                      child: _LiteMotion(lite: settings.lite, child: child!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final m = marks, sy = sync, pr = profiles, fl = fluency;
    final withFluency = fl == null ? app : FluencyScope(store: fl, child: app);
    final withProfiles =
        pr == null ? withFluency : ProfileScope(profiles: pr, child: withFluency);
    if (m == null) return withProfiles;
    final scoped = MarksScope(store: m, child: withProfiles);
    return sy == null ? scoped : SyncScope(engine: sy, child: scoped);
  }
}

/// Rebuilds [builder] when [select] of the settings changes.
class _Select extends StatefulWidget {
  final AppSettings settings;
  final Object? Function(AppSettings) select;
  final WidgetBuilder builder;
  const _Select({required this.settings, required this.select, required this.builder});

  @override
  State<_Select> createState() => _SelectState();
}

class _SelectState extends State<_Select> {
  Object? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select(widget.settings);
    widget.settings.addListener(_changed);
  }

  @override
  void didUpdateWidget(_Select old) {
    super.didUpdateWidget(old);
    if (!identical(old.settings, widget.settings)) {
      old.settings.removeListener(_changed);
      widget.settings.addListener(_changed);
      _value = widget.select(widget.settings);
    }
  }

  void _changed() {
    final v = widget.select(widget.settings);
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Lite mode turns animations off app-wide through the same flag the
/// system's "remove animations" setting sets, so every widget that honours
/// one honours both (see `noMotion` in ui/kit.dart).
class _LiteMotion extends StatelessWidget {
  final bool lite;
  final Widget child;
  const _LiteMotion({required this.lite, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!lite) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}

/// Keeps the app clear of Android's navigation bar.
///
/// Android 15+ draws every app edge-to-edge, behind a transparent
/// navigation bar, and the screens here don't pad their scroll views and
/// sheets for it — so the system buttons sat on top of content. Reserving
/// the bar's height once, below the whole app (in the theme's background
/// up or in immersive mode the inset is zero, so nothing changes there.
class _NavBarInset extends StatelessWidget {
  final Color color;
  final Widget child;
  const _NavBarInset({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return child;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (bottom <= 0) return child;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: MediaQuery.removePadding(
            context: context, removeBottom: true, child: child),
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
  final MarksStore? marks;
  final SyncEngine? sync;
  final Widget child;
  const _SystemUiSync(
      {required this.settings, this.marks, this.sync, required this.child});

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
      // Fire-and-forget: silently top up any quran.com-sourced cache older
      // than 7 days (Quran Foundation's offline-caching condition). Failures
      // are swallowed inside and simply retried on the next resume.
      refreshStaleQuranCache();
      // Catch up with marks made elsewhere (no-op unless signed in).
      widget.sync?.syncNow();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Flush any debounced settings/marks write (see AppSettings.update)
      // before the OS can suspend/kill the process mid-background. Desktop
      // windows may only go as far as `hidden`.
      widget.settings.flush();
      widget.marks?.flush();
    }
  }

  void _sync() {
    final on = widget.settings.immersive;
    if (on == _applied) return;
    _applied = on;
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The first-launch setup until it has been finished or skipped, then the
/// app shell — the chosen mode's home ([AppShell]). An install from before
/// the modes picks one, once.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (!s.onboarded) return const OnboardingScreen();
    if (s.mode == null) return const OnboardingScreen(modeOnly: true);
    return const AppShell();
  }
}

/// Counts time spent in the app (while it is in the foreground) towards the
/// daily goal, in 30-second ticks.
class _TimeTracker extends StatefulWidget {
  final ProgressStore progress;
  final Widget child;
  const _TimeTracker({required this.progress, required this.child});
  @override
  State<_TimeTracker> createState() => _TimeTrackerState();
}

class _TimeTrackerState extends State<_TimeTracker>
    with WidgetsBindingObserver {
  Timer? _tick;
  DateTime? _since;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _since = DateTime.now();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  void _flush() {
    final since = _since;
    if (since == null) return;
    final now = DateTime.now();
    widget.progress.addTime(now.difference(since).inSeconds);
    _since = now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _flush();
      _since = null;
      _tick?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        text: 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        style: TextStyle(fontFamily: family, fontSize: 28),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), Offset.zero);
    rec.endRecording().dispose();
    tp.dispose();
  }
}
