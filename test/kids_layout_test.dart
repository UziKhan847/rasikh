import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'kids_test_support.dart';

/// Overflow guard for the two Kids Mode screens that lay content out to a
/// fixed height — the Learn stage grid's tiles and the Home screen's trail.
///
/// Learn is two levels since the path became a curriculum: a list of stages,
/// then that stage's tiles. Both are pumped here.
///
/// A RenderFlex/RenderBox overflow surfaces as a thrown FlutterError in
/// tests, so pumping each tab at real phone viewports is enough to catch the
/// class of bug that shipped once already: the Learn tiles overflowed by a
/// few pixels because `quranicStyle`'s 1.8 line height, multiplied by the
/// user's `arabicScale`, outgrew the cell.
Future<AppSettings> _boot({double arabicScale = 1.0}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  settings.kidsMode = true;
  settings.arabicScale = arabicScale;
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  return settings;
}

Widget _harness(AppSettings settings, {String locale = 'en'}) => SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: const KidsShell(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Small-but-real phone (Pixel-class, 360x760dp) and a cramped one.
  for (final (label, size) in [
    ('360x760', const Size(360, 760)),
    ('320x640', const Size(320, 640)),
  ]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('Home and Learn lay out cleanly at $label, arabicScale $scale',
          (tester) async {
    useReducedMotion(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final settings = await _boot(arabicScale: scale);
        await tester.pumpWidget(_harness(settings));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Home overflowed');

        await tester.tap(find.text('Learn'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'the Learn stage list overflowed');

        // Scroll the whole path past the viewport: every stage row builds,
        // including the trailing locked run.
        await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'a stage row below the fold overflowed');
        // ...then back to the top, so the first stage is tappable again.
        await tester.drag(find.byType(ListView).last, const Offset(0, 1400));
        await tester.pumpAndSettle();

        // Then into the first stage, where the letter tiles live.
        await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'the Learn grid overflowed');

        await tester.drag(find.byType(GridView), const Offset(0, -1200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'a Learn tile below the fold overflowed');
      });
    }
  }

  // The design's mirrored details — the Learn tile's check badge, the resume
  // card's go arrow, and the Arabic section companions (empty in ar, so the
  // heading isn't printed twice) — all flip on locale, so pump one RTL pass.
  testWidgets('Home and Learn lay out cleanly in Arabic (RTL)', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    await tester.pumpWidget(_harness(settings, locale: 'ar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // By icon, not label — the label is localized in this pass.
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Learn grid keys every letter tile, locked ones included',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
    await tester.pumpAndSettle();

    // Tiles are keyed by their progress id. ا is current (renders its glyph);
    // ب is locked (renders only a padlock, per the design) — both must still
    // be addressable.
    expect(find.byKey(const ValueKey('kids.letter.ا')), findsOneWidget);
    expect(find.byKey(const ValueKey('kids.letter.ب')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('kids.letter.ب')),
            matching: find.byIcon(Icons.lock_rounded)),
        findsOneWidget);
  });

  testWidgets('the Home trail keeps cleared letters reachable', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    final progress = ProgressStore(profileId: 'p1');
    await progress.load();
    for (final char in ['ا', 'ب', 'ت', 'ث', 'ج']) {
      progress.report('kids.letter.$char', 3);
    }
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const KidsShell(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The trail used to be a fixed six-node slice with no way to move it, so
    // by the sixth letter alif had left the Home screen for good. It holds
    // the whole stage now and scrolls within itself.
    final alif = find.byKey(const ValueKey('kids.trail.kids.letter.ا'));
    final current = find.byKey(const ValueKey('kids.trail.kids.letter.ح'));
    expect(alif, findsOneWidget);
    expect(current, findsOneWidget);

    // It opens on where the child is, not at the very top...
    final trail = find.byKey(const ValueKey('kids.trail'));
    final trailTop = tester.getTopLeft(trail).dy;
    expect(tester.getBottomLeft(alif).dy, lessThan(trailTop),
        reason: 'the trail should open near the current letter, not at ا');

    // ...and dragging inside it scrolls the trail itself back to the start,
    // rather than the Home list underneath it.
    await tester.drag(trail, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(trail).dy, trailTop,
        reason: 'the drag scrolled the Home list instead of the trail');
    expect(tester.getTopLeft(alif).dy, greaterThanOrEqualTo(trailTop));
  });

  testWidgets(
      'the trail never fades an edge with nothing hidden beyond it',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    final progress = ProgressStore(profileId: 'p1');
    await progress.load();
    for (final char in ['ا', 'ب', 'ت', 'ث', 'ج']) {
      progress.report('kids.letter.$char', 3);
    }
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const KidsShell(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Opened mid-stage (current is the checkpoint after five letters, well
    // short of either end of a 33-node stage): both fades wash an edge that
    // really does hide more content, so both are there.
    final trail = find.byKey(const ValueKey('kids.trail'));
    expect(find.byKey(const ValueKey('kids.trail.fadeTop')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('kids.trail.fadeBottom')), findsOneWidget);

    // Drag well past the stage's real content height — the fix under test:
    // once there is truly nothing left below, the bottom fade must be gone,
    // not just faintly still claiming there is.
    for (var i = 0; i < 20; i++) {
      await tester.drag(trail, const Offset(0, -400));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kids.trail.fadeBottom')), findsNothing,
        reason: 'ي is the stage\'s real last node — nothing is hidden below '
            'it, so nothing should look like it is');
    // The true last node is fully on screen, not clipped by a fade that
    // shouldn't be there.
    expect(find.byKey(const ValueKey('kids.trail.kids.letter.ي')),
        findsOneWidget);
    // Scrolled well away from the top, so that edge still honestly hides
    // everything before the checkpoint.
    expect(find.byKey(const ValueKey('kids.trail.fadeTop')), findsOneWidget);

    // And back at the top, the same holds in the other direction.
    for (var i = 0; i < 20; i++) {
      await tester.drag(trail, const Offset(0, 400));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kids.trail.fadeTop')), findsNothing,
        reason: 'ا is the stage\'s real first node — nothing precedes it');
    expect(find.byKey(const ValueKey('kids.trail.kids.letter.ا')),
        findsOneWidget);
  });

  testWidgets('finishing a letter while Home is mounted does not throw',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    final progress = ProgressStore(profileId: 'p1');
    await progress.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const KidsShell(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Clearing a lesson notifies the store, which rebuilds Home, which moves
    // the trail's current node — and the trail then scrolls to follow it.
    // That scroll is driven from didUpdateWidget, i.e. from inside a build,
    // so it is deferred to a post-frame callback; this is the guard on that.
    for (final char in ['ا', 'ب', 'ت']) {
      progress.report('kids.letter.$char', 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'cleared $char');
    }
  });

  testWidgets('a later stage is locked until the one before it is finished',
      (tester) async {
    useReducedMotion(tester);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    // Blocks unlock in order, so the letters quiz cannot be reached before
    // the letters themselves.
    await tester.tap(find.byKey(const ValueKey('kids.block.letters.quiz')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });
}
