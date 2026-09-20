import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_sentences.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Real sentences, one at a time, from [kidsSentences] — written and
/// reviewed content that had never been rendered anywhere before this stage.
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

Future<void> _finishLesson(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      continue;
    }
    final options = find.byType(TapScale);
    if (options.evaluate().isNotEmpty) {
      await tester.tap(options.first);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
  }
  fail('the lesson never reached its result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> played;
  setUp(() => LetterAudio.log = played = []);
  tearDown(() => LetterAudio.log = null);

  testWidgets('opens on the reading intro, not the first sentence', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWordsLesson(progressId: 'test.w')),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('Find the highlighted word'), findsOneWidget);
    expect(find.text(kidsSentences.first.sentence), findsNothing);
  });

  testWidgets('the first sentence shows its own gloss and plays on Listen', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWordsLesson(progressId: 'test.w2')),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the intro
    await tester.pump();

    final first = kidsSentences.first;
    expect(find.textContaining(first.gloss), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(played, [first.sentence]);
  });

  testWidgets('a check-up lands every five sentences, drawn from the pool', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWordsLesson(progressId: 'test.w3')),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // intro
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.textContaining('Which word means'), findsOneWidget);
    expect(find.byType(TapScale), findsNWidgets(4));
  });

  testWidgets('walking all 28 sentences reports a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsWordsLesson(progressId: 'kids.words.learn'),
      ),
    );
    await tester.pump();

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.words.learn'), greaterThan(0));
  });
}
