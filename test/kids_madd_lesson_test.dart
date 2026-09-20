import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/small_letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';

import 'kids_test_support.dart';

/// Madd & Līn, one stretching mark at a time, each with a kid-sized metronome
/// of its own ([KidsBeatRing]) — not the reused Learn page's flat list of
/// seven rows, each pushing to a separate full-screen timer, and not the
/// grown-up Counts Studio's tempo slider / count picker / animation that
/// never stops on its own.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home:
          child, // no Scaffold here: the widget itself must supply its own Material
      // ancestor (KidsLessonScaffold), exactly like pushKidsOverlay hosts it.
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'opens on Madd Ṭabī‘ī, with its own count shown, no adult tempo or count '
    'controls',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(_harness(settings, prog, const KidsMaddLesson()));
      await tester.pump();

      // A real `Material` ancestor — plain `find.text` would still pass even
      // if every Text here fell back to MaterialApp's "no Material" debug
      // style (a double yellow underline).
      expect(find.byType(Material), findsWidgets);
      expect(find.text('Madd Ṭabī‘ī'), findsOneWidget);
      // The adult Counts Studio's own tempo slider and 1/2/4/6 count picker
      // never appear — a child learning "this one is 6" must not be able to
      // set it to 2.
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    },
  );

  testWidgets(
    "the beat ring plays three cycles then stops on its own — it never "
    'loops forever the way the adult metronome does',
    (tester) async {
      final (settings, prog) = await _boot();
      await tester.pumpWidget(_harness(settings, prog, const KidsMaddLesson()));
      await tester.pump();

      // `MediaRow`'s own Listen/Watch buttons are also `TextButton`s, so
      // find this one by its label rather than by type alone.
      final button = find.widgetWithText(TextButton, 'Start — recite along');
      expect(button, findsOneWidget);
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);

      await tester.tap(button);
      await tester.pump();
      // Disabled while it plays — this is the only feedback a child gets
      // that a tap did something.
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      // Madd Ṭabī‘ī is a 2-count mark: 3 cycles of ~1.6s each is comfortably
      // under 6s. Pumped in chunks rather than `pumpAndSettle()`, which never
      // returns for a still-repeating controller.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    },
  );

  testWidgets(
    'walks the seven counted marks, then the three small letters, in order',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(_harness(settings, prog, const KidsMaddLesson()));
      await tester.pump();

      final counted = tashkil.where((t) => t.counts >= 2).toList();
      final total = counted.length + smallLetters.length;
      expect(total, 10);
      for (var i = 0; i < total; i++) {
        final isLast = i == total - 1;
        final label = isLast ? 'Continue' : 'Next';
        expect(find.text(label), findsOneWidget, reason: 'step $i');
        if (i >= counted.length) {
          // A small letter's own card, named by its data.
          expect(
            find.text(smallLetters[i - counted.length].name),
            findsOneWidget,
            reason: 'step $i',
          );
        }
        await tester.tap(find.text(label));
        await tester.pump();
      }
    },
  );

  testWidgets(
    'only the dagger alif gets a beat ring — the small wāw and yāʾ are a '
    'brief rounding, not a full extra count',
    (tester) async {
      final (settings, prog) = await _boot();
      await tester.pumpWidget(_harness(settings, prog, const KidsMaddLesson()));
      await tester.pump();

      final counted = tashkil.where((t) => t.counts >= 2).length;
      for (var i = 0; i < counted; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      final ring = find.widgetWithText(TextButton, 'Start — recite along');
      expect(find.text('Dagger Alif'), findsOneWidget);
      expect(ring, findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Small Wāw'), findsOneWidget);
      expect(ring, findsNothing);
    },
  );
}
