import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/ui/qiraah_icons.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/learn/qaidah/qaidah_home.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart';
import 'package:qiraah_arabiyyah/screens/script_screen.dart';
import 'package:qiraah_arabiyyah/screens/tajweed_screen.dart';

/// Widget-interaction checks for Round 13: desktop drill-downs must have a
/// working back control (the user found dead ends past 2 levels deep, e.g.
/// Tanwīn → Ḍammatān → Iqlāb), a SET of letters (a makhraj's 'بمو') must
/// render as separate glyphs rather than one joined cursive string, and
/// Joining Forms now opens onto a picker (28 letters + Special Shapes),
/// mirroring Unit 1, instead of one crowded screen.
Future<(AppSettings, ProgressStore)> _boot({String desktopMode = 'off'}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings.desktopMode = desktopMode;
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress, Widget child) {
  return SettingsScope(
    settings: settings,
    child: ProgressScope(
      progress: progress,
      child: MaterialApp(
        theme: buildTheme(settings),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Desktop: a two-level-deep lesson push (Tanwīn → Ḍammatān → Iqlāb) has '
      'a working back control at every level, not a dead end', (tester) async {
    final (settings, progress) = await _boot(desktopMode: 'on');
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Tanwīn'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Tanwīn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ḍammatān'));
    await tester.pumpAndSettle();
    // On the index, "Small Mīm (Iqlāb)" is one of three sibling rows;
    // "Parallel Shape" is another — it won't be on screen once we drill into
    // Iqlāb's own detail page, since a detail page never lists its siblings.
    expect(find.text('Parallel Shape'), findsOneWidget);
    await tester.tap(find.text('Small Mīm (Iqlāb)'));
    await tester.pumpAndSettle();
    expect(find.text('Parallel Shape'), findsNothing);

    // The reported dead end: on desktop, a route two pushes deep must still
    // show a way back — not the mobile AppBar, not nothing.
    final back = find.byIcon(QiraahIcons.back);
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    // Back on Ḍammatān's index — its sibling row is visible again.
    expect(find.text('Parallel Shape'), findsOneWidget);

    // And the index screen one level up ALSO has a working back control.
    expect(find.byIcon(QiraahIcons.back), findsOneWidget);
    await tester.tap(find.byIcon(QiraahIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('Ḍammatān'), findsWidgets);
    expect(find.text('Fatḥatān'), findsOneWidget);
  });

  testWidgets(
      'Desktop: Script Families\' bespoke comparison page (the user\'s '
      'Hamzat al-Waṣl screenshot) has a working back control, not the mobile '
      'AppBar or a phone-sized frame', (tester) async {
    final (settings, progress) = await _boot(desktopMode: 'on');
    await tester.pumpWidget(_harness(settings, progress, const ScriptScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Script Families'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hamzat al-Waṣl'));
    await tester.pumpAndSettle();

    // No mobile-style AppBar back button (would render via BackButtonIcon
    // rather than the desktop's own arrow_back_rounded tile) and no
    // 640px phone-frame chrome — just the one desktop back control.
    expect(find.byIcon(QiraahIcons.back), findsOneWidget);
    await tester.tap(find.byIcon(QiraahIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('Hamzat al-Waṣl'), findsWidgets);
    expect(find.text('Script Families'), findsWidgets);
  });

  testWidgets(
      'A letter SET (a makhraj\'s بمو) renders as separate glyphs, never as '
      'one joined cursive string', (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const TajweedScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Makhārij'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Makhārij'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    // "The Lips" zone has exactly one point, so it collapses straight onto
    // the point's own detail page (bmw's hero + letter-chip row).
    await tester.scrollUntilVisible(find.text('The Lips'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('The Lips'));
    await tester.pumpAndSettle();

    expect(find.text('بمو'), findsNothing);
    expect(find.text('ب'), findsWidgets);
    expect(find.text('م'), findsWidgets);
    expect(find.text('و'), findsWidgets);
  });

  testWidgets(
      'Special shapes: Learn lists the shapes a letter\'s own forms can\'t '
      'show — the letters themselves are taught in their families\' lessons',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Special shapes'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.text('ب'), findsNothing, reason: 'no letter grid here');
    final scrollable = find.byType(Scrollable).first;
    for (final label in ['Ligatures', 'Kāf\'s Wrap', 'Stacking', 'Heights & Tails']) {
      await tester.scrollUntilVisible(find.text(label), 300, scrollable: scrollable);
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Joining Forms: the لا ligature — previously unreachable dead data — '
      'now shows its hand-drawn shape(s), not the old wrong-glyph text',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Special shapes'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Ligatures'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ligatures'));
    await tester.pumpAndSettle();

    // Round 14: the old لا / لأ / لإ trio (3 tiles) is now 2 tiles — the
    // hamzah-above and hamzah-below forms merged into one "Lām + Hamzah"
    // tile with 3 hand-drawn forms, since one drawing per positional/
    // labelled form replaces the old per-variant split.
    expect(find.text('Lām + Alif'), findsOneWidget);
    expect(find.text('Lām + Hamzah'), findsOneWidget);

    await tester.tap(find.text('Lām + Alif'));
    await tester.pumpAndSettle();
    // Lām + Alif has 2 hand-drawn forms (isolated, ending) — captioned by
    // position, not the old text-only "Apart -> Joined as One Shape" pair.
    expect(find.byType(SvgPicture), findsWidgets);
    expect(find.text('Alone'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.textContaining('Examples'), findsOneWidget);
  });

  testWidgets(
      'Joining Forms > Stacking: Mīm over Jīm/Ḥāʼ/Khāʼ renders its '
      'hand-drawn shape, not the old isolated-form fragment مُجۡ',
      (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Special shapes'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Stacking'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Stacking'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mīm over Jīm, Ḥāʾ, or Khāʾ'));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsWidgets);
    // The old text badge/hero rendered this fragment in its default,
    // isolated form — wrong for the lesson. It must be gone now that the
    // hero and index badge are hand-drawn art instead.
    expect(find.text('مُجۡ'), findsNothing);
    expect(find.textContaining('Telling Them Apart'), findsOneWidget);
  });

  testWidgets(
      'Joining Forms > Heights & Tails: a shape with no hand-drawn art yet '
      'is locked — dimmed, and tapping it shows "coming soon" instead of '
      'navigating', (tester) async {
    final (settings, progress) = await _boot();
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Special shapes'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Special shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Heights & Tails'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Heights & Tails'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('A Tooth Letter, Elevated'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('A Tooth Letter, Elevated'));
    await tester.pumpAndSettle();

    // Still on the Heights & Tails index — no navigation happened.
    expect(find.text('A Tooth Letter, Elevated'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets(
      'Desktop: a letter\'s detail page opens without '
      'crashing. Regression: adding the Articulation Point section pulled '
      '"See it in Words" out of its old IntrinsicHeight-bounded layout, '
      'leaving a bare Row(crossAxisAlignment: stretch) with unbounded '
      'height inside the ListView', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (settings, progress) = await _boot(desktopMode: 'on');
    await tester.pumpWidget(
        _harness(settings, progress, LetterDetail(letter: letterFor('ب'))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Easily confused with'), findsOneWidget);
    // Below the fold even at 900px tall — ListView(children: [...]) still
    // only inflates elements near the viewport, same sliver virtualization
    // noted for eager lists elsewhere in this suite.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('See it in Words'), 300,
        scrollable: scrollable);
    expect(find.text('See it in Words'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Articulation Point'), 300,
        scrollable: scrollable);
    expect(find.text('Articulation Point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Desktop: a lesson detail page\'s back header sits flush with the '
      'left edge, not centered mid-page with the reading content below it',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (settings, progress) = await _boot(desktopMode: 'on');
    await tester.pumpWidget(_harness(settings, progress, const QaidahHome()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Tanwīn'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Tanwīn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ḍammatān'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small Mīm (Iqlāb)'));
    await tester.pumpAndSettle();

    final backX = tester.getTopLeft(find.byIcon(QiraahIcons.back)).dx;
    // The content column is capped at 760px and centered in a 1440px window,
    // so a header still trapped inside that column would sit past x≈300.
    // Flush left (the ListView's own 20px padding) stays well under that.
    expect(backX, lessThan(60));
  });

  testWidgets(
      'Desktop: Script Families\' bespoke detail page back header also '
      'sits flush left, not centered', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (settings, progress) = await _boot(desktopMode: 'on');
    await tester.pumpWidget(_harness(settings, progress, const ScriptScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Script Families'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hamzat al-Waṣl'));
    await tester.pumpAndSettle();

    final backX = tester.getTopLeft(find.byIcon(QiraahIcons.back)).dx;
    expect(backX, lessThan(60));
  });
}
