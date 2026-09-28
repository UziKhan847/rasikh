import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/extra_letters.dart';
import 'package:qiraah_arabiyyah/data/kids_sentences.dart';
import 'package:qiraah_arabiyyah/data/small_letters.dart';
import 'package:qiraah_arabiyyah/data/special_shapes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_special_shapes_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';

import 'kids_test_support.dart';

/// A Spanish, French, Arabic or Urdu child used to get an English sentence
/// on these four screens — the raw adult-register data, not a translated kid
/// key. This checks the opposite: at a non-English locale, none of that raw
/// English prose is on screen.
///
/// It does NOT check every word choice (that is what the resolver's own unit
/// tests and a native speaker's review are for) — only that the literal
/// strings the audit found (`special_shapes.dart`'s `.note`/`.tellApart`,
/// `extraLetterNotes`, `smallLetters[..].note`, `kidsSentences[..].gloss`)
/// are gone from these screens once the locale is not English.
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

Widget _harness(
  AppSettings s,
  ProgressStore p,
  Widget child, {
  String locale = 'es',
}) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      home: child,
    ),
  ),
);

/// Every raw English string these four data sources hold, minus the ones
/// short enough (a bare letter name) to collide with ordinary UI chrome.
Set<String> _englishStrings() => {
  for (final s in specialShapes) ...[s.note, s.tellApart],
  for (final n in extraLetterNotes.values) n,
  for (final l in smallLetters) l.note,
  for (final s in kidsSentences) s.gloss,
};

void _expectNoneOnScreen(WidgetTester tester) {
  final shown = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toSet();
  for (final raw in _englishStrings()) {
    expect(shown, isNot(contains(raw)), reason: raw);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['es', 'fr', 'ar', 'ur']) {
    testWidgets('special shapes lesson ($locale)', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      for (final group in ['ligature', 'kaf', 'stacking', 'tails']) {
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsSpecialShapesLesson(
              group: group,
              progressId: 'test.special.$group.$locale',
            ),
            locale: locale,
          ),
        );
        await tester.pump();
        _expectNoneOnScreen(tester);
      }
    });

    testWidgets('every extra-letter lesson ($locale)', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      for (final char in extraLetterNotes.keys) {
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsExtraLetterLesson(char: char),
            locale: locale,
          ),
        );
        await tester.pump();
        _expectNoneOnScreen(tester);
      }
    });

    testWidgets('the madd lesson\'s small letters ($locale)', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(settings, prog, const KidsMaddLesson(), locale: locale),
      );
      await tester.pump();
      // Walk to the small-letter cards at the end.
      for (var i = 0; i < 8; i++) {
        final next = find.text(i == 7 ? 'Continue' : 'Next');
        if (next.evaluate().isEmpty) break;
        await tester.tap(next);
        await tester.pump();
        _expectNoneOnScreen(tester);
      }
    });

    testWidgets('the words lesson\'s sentences and their gloss ($locale)', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsWordsLesson(progressId: 'test.words'),
          locale: locale,
        ),
      );
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        _expectNoneOnScreen(tester);
        final next = find.text('Next');
        if (next.evaluate().isEmpty) break;
        await tester.tap(next.first);
        await tester.pump();
      }
    });
  }
}
