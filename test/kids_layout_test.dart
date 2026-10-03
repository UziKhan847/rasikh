import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_alphabet_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';

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
  settings.kidsTextScale = arabicScale;
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
    for (final scale in [1.0, 1.2]) {
      testWidgets('Home and Learn lay out cleanly at $label, text size $scale',
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

        await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -1200));
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

    // By position, not label — the label is localized in this pass.
    await tester.tap(kidsTabAt(1));
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
            matching: find.byWidgetPredicate(
                (w) => w is KbIcon && w.name == 'lock')),
        findsOneWidget);
  });

  /// The mobile trail is the whole stage, inline: ONE scroll on Home, the
  /// page's own. It used to scroll inside a window of its own, which made two
  /// scrolls fight over one gesture (the trail's won until it ran out) and cut
  /// the last node's edge off at the window's foot. Its rows are built lazily:
  /// only those near the screen exist.
  testWidgets('the Home trail is the whole stage, in the page\'s one scroll', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = await _boot();
    final progress = ProgressStore(profileId: 'p1');
    await progress.load();
    for (final char in ['ا', 'ب', 'ت', 'ث']) {
      progress.report('kids.letter.$char', 3);
    }
    await tester.pumpWidget(_harnessWith(settings, progress));
    await tester.pumpAndSettle();

    final home = find.byType(KidsHomeScreen);
    final scrolls = find.descendant(
        of: home,
        matching: find.byWidgetPredicate((w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical));
    expect(scrolls, findsOneWidget, reason: 'one scroll: the page\'s');

    // Home opens with the node the child is on in view, above the nav bar.
    final current = find.byWidgetPredicate(
        (w) => w is KbPathNode && w.state == KbNodeState.current);
    final navTop = tester.getTopLeft(find.byType(KbNavBar)).dy;
    expect(tester.getRect(current).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(current).bottom, lessThanOrEqualTo(navTop));

    // Lazy: the stage's last node is not built until it is near the screen...
    final last = find.byKey(const ValueKey('kids.trail.kids.letter.ي'));
    expect(last, findsNothing);
    // ...and one drag moves the trail with the page, to it.
    final before = tester.getTopLeft(current).dy;
    await tester.dragFrom(tester.getCenter(current), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(current).dy, lessThan(before));
    final page = tester.state<ScrollableState>(scrolls).position;
    page.jumpTo(page.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(last, findsOneWidget);
  });

  testWidgets('a child at the start of a stage finds Home at the top', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = await _boot();
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    // The first node is already in view, so nothing moves the page for it.
    final page = find
        .ancestor(
            of: find.byKey(const ValueKey('kids.trail.kids.letter.ا')),
            matching: find.byType(Scrollable))
        .first;
    expect(_positionOf(tester, page).pixels, 0);
  });

  testWidgets('the line down the trail is filled up to the current node', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final line = find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_ScrollingTrailLine');
    double fill() =>
        ((tester.widget<CustomPaint>(line).painter as dynamic).fill as num)
            .toDouble();

    final settings = await _boot();
    final progress = ProgressStore(profileId: 'p1');
    await progress.load();
    await tester.pumpWidget(_harnessWith(settings, progress));
    await tester.pumpAndSettle();
    expect(fill(), 0, reason: 'nothing cleared yet, nothing filled');

    // The shell loads the profile's own store, so seed before mounting.
    await tester.pumpWidget(const SizedBox());
    final settings2 = await _boot();
    final progress2 = ProgressStore(profileId: 'p1');
    await progress2.load();
    for (final char in ['ا', 'ب', 'ت']) {
      progress2.report('kids.letter.$char', 3);
    }
    await tester.pumpWidget(_harnessWith(settings2, progress2));
    await tester.pumpAndSettle();
    // Filled to the current node's centre, measured from the line's top: 30
    // px into the first row, which ends at the first node's foot.
    final current = find.byWidgetPredicate(
        (w) => w is KbPathNode && w.state == KbNodeState.current);
    final first = find.byKey(const ValueKey('kids.trail.kids.letter.ا'));
    final lineTop = tester.getRect(first).bottom - 74 + 30;
    final circleCentre = tester.getRect(current).bottom - 42;
    expect(fill(), moreOrLessEquals(circleCentre - lineTop, epsilon: 2));
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
    expect(find.byType(KidsBlockScreen), findsNothing);
  });

  testWidgets('the current node fits at the largest system and kids text size', (
    tester,
  ) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settings = await _boot(arabicScale: 1.2);
    await tester.pumpWidget(_harness(settings));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'the Start tag pushed the current node out of its row');
  });
}

/// The [_harness] above builds its own ProgressStore; the trail tests need
/// to seed one first.
Widget _harnessWith(AppSettings settings, ProgressStore progress) =>
    SettingsScope(
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
    );

ScrollPosition _positionOf(WidgetTester tester, Finder scrollable) =>
    tester.state<ScrollableState>(scrollable).position;
