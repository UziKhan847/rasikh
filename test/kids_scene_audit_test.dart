import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_app.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';

import 'kids_scene_audit_support.dart';
import 'kids_test_support.dart';

/// The design's rule for the vivid scene: **only headings and one-line
/// subtitles sit directly on it; everything else sits on a solid surface.**
///
/// The vivid backdrop is saturated sky, and ordinary text in the palette's
/// `text` colour is unreadable on it. So each screen that sits on it must keep
/// every piece of text either inside a heading (white, outlined) or
/// on a card. This walks the real element tree of every main tab, in the states
/// a child actually meets, and lists any text that breaks the rule — by name,
/// so a failure is a work list rather than a count.
///
/// Lessons and games are NOT covered here on purpose: they sit on the gentle
/// scene (`KidsBackdrop.calm`) until their text is restyled. See
/// `KidsScreenScaffold`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> boot() async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    settings.desktopMode = 'off';
    settings.kidsMode = true;
    return settings;
  }

  Widget harness(AppSettings s, Widget child) => SettingsScope(
    settings: s,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  group('the checker itself', () {
    // A check that cannot fail proves nothing — so first show it can.
    // The marker KidsBackdrop puts over a vivid scene — all the checker keys on.
    Widget vivid(Widget child) =>
        KbSceneScope(style: KbStyle.vivid, child: child);

    testWidgets('flags plain text sitting on the scene', (tester) async {
      final s = await boot();
      await tester.pumpWidget(
        harness(
          s,
          vivid(const Text('bare'),
          ),
        ),
      );
      expect(kidsTextsOnScene(tester), ['bare']);
    });

    testWidgets('lets a heading through', (tester) async {
      final s = await boot();
      await tester.pumpWidget(
        harness(
          s,
          vivid(Builder(
              builder: (c) => KbHeading('dressed', ui: kbUi(c)),
            ),
          ),
        ),
      );
      expect(kidsTextsOnScene(tester), isEmpty);
    });

    testWidgets('lets text on a card through', (tester) async {
      final s = await boot();
      await tester.pumpWidget(
        harness(
          s,
          vivid(Container(
              color: Colors.white,
              child: const Text('on a card'),
            ),
          ),
        ),
      );
      expect(kidsTextsOnScene(tester), isEmpty);
    });

    testWidgets('does NOT count a translucent fill as a card', (tester) async {
      final s = await boot();
      await tester.pumpWidget(
        harness(
          s,
          vivid(Container(
              color: Colors.white.withValues(alpha: .2),
              child: const Text('see-through'),
            ),
          ),
        ),
      );
      expect(kidsTextsOnScene(tester), ['see-through']);
    });

    testWidgets('ignores text with no scene behind it at all', (tester) async {
      final s = await boot();
      await tester.pumpWidget(harness(s, const Text('flat')));
      expect(kidsTextsOnScene(tester), isEmpty);
    });
  });

  group('every main tab keeps its text off the vivid scene', () {
    testWidgets('Home, Learn, Rank, Rewards and Me', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final s = await boot();
      // Two children, so Rank has a real leaderboard rather than its
      // "add another profile" empty state.
      s.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
      s.addKidsProfile(KidsProfile(id: 'p2', name: 'Omar'));
      s.activeKidsProfileId = 'p1';
      await tester.pumpWidget(harness(s, const KidsShell()));
      await tester.pumpAndSettle();

      // Progress, so Home shows a resume card and a trail with done nodes,
      // and Rewards has gems to spend.
      final prog = ProgressScope.of(tester.element(find.text('Hello, Sara!')));
      for (final c in ['ا', 'ب', 'ت', 'ث', 'ج', 'ح']) {
        prog.report('kids.letter.$c', 3);
      }
      prog.awardGems(500);
      prog.awardXp(300);
      await tester.pumpAndSettle();

      final offenders = <String, List<String>>{};
      Future<void> audit(String where) async {
        final on = kidsTextsOnScene(tester);
        if (on.isNotEmpty) offenders[where] = on;
      }

      for (final tab in ['Home', 'Learn', 'Rank', 'Rewards', 'Me']) {
        await tester.tap(
          kidsTab(tab),
        );
        await tester.pumpAndSettle();
        await audit(tab);

        if (tab == 'Learn') {
          // Learn is two levels: the list of stages, then one stage's tiles.
          await tester.tap(find.text('The Letters'));
          await tester.pumpAndSettle();
          await audit('Learn > a stage');
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'text sitting straight on the vivid scene — dress it with '
            'a heading or put it on a card:\n$offenders',
      );
    });

    testWidgets('the same tabs are equally clean in dark and OLED', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final mode in ['dark', 'oled']) {
        final s = await boot();
        s.kidsThemeMode = mode;
        s.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
        await tester.pumpWidget(harness(s, const KidsShell()));
        await tester.pumpAndSettle();
        for (final tab in ['Home', 'Learn', 'Rank', 'Rewards', 'Me']) {
          await tester.tap(
            kidsTab(tab),
          );
          await tester.pumpAndSettle();
          expect(kidsTextsOnScene(tester), isEmpty, reason: '$tab in $mode');
        }
      }
    });
  });
}
