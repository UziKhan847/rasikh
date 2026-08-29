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
        await tester.tap(find.byKey(const ValueKey('kids.block.letters.more')));
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
    await tester.tap(find.byKey(const ValueKey('kids.block.letters.more')));
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
