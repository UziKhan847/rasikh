import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';

/// The audit that found four "Kids Mode opens the grown-up app" bugs, kept as
/// a test: EVERY tile on the path is built, and none may be a grown-up Learn
/// page. Asserting stages one by one is how Special Shapes, tāʼ marbūṭah and
/// the madd metronome slipped through; this walks them all.
///
/// What a tile may open: a `Kids…` lesson, or a `QuizScreen` — the neutral quiz
/// shell every kid check-up runs on (its prompts and wording are kid-safe).
/// What it may not: any screen whose type name marks it as the grown-up
/// lesson/letter/metronome pages.
const _adultScreens = {
  'LetterDetail',
  'LessonDetailScreen',
  'LessonIndexScreen',
  '_LessonCustomScreen',
  'CountsStudio',
  'TashkeelScreen',
  'QaidahScreen',
  'TajweedScreen',
  'TracingScreen',
  'DyslexiaScreen',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no tile on the Kids path opens a grown-up Learn page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    final prog = ProgressStore(profileId: 'p1');
    await settings.load();
    await prog.load();
    settings.kidsMode = true;
    late BuildContext ctx;
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    final seen = <String, int>{};
    for (final block in kidsPath(ctx)) {
      for (final item in block.items(ctx)) {
        final type = item.open(ctx).runtimeType.toString();
        seen[type] = (seen[type] ?? 0) + 1;
        expect(
          _adultScreens,
          isNot(contains(type)),
          reason: '${block.id} / ${item.id} opens the grown-up $type',
        );
        // Anything that is not a kid lesson must at least be the neutral quiz.
        if (!type.startsWith('Kids')) {
          expect(
            type,
            'QuizScreen',
            reason: '${block.id} / ${item.id} opens an unexpected $type',
          );
        }
      }
    }
    // The audit must actually have covered the path, not an empty one.
    expect(seen.values.fold<int>(0, (a, b) => a + b), greaterThan(150));
    expect(seen.keys.where((t) => t.startsWith('Kids')), isNotEmpty);
  });
}
