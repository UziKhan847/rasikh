import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_glosses.dart' show kidsShapeTitle;
import 'package:qiraah_arabiyyah/data/special_shapes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_special_shapes_lesson.dart';

import 'kids_test_support.dart';

/// The muṣḥaf's hand-drawn compound shapes, one at a time, ending on a real
/// recognition check — not the reused grown-up Joining Forms lesson viewer
/// this stage used to push straight into Kids Mode.
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
      home: child,
    ),
  ),
);

Future<void> _finishLesson(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      continue;
    }
    final options = kidsTappables();
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

  testWidgets('opens on the first ligature, with a real Material ancestor', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        Builder(
          builder: (c) {
            ctx = c;
            return const KidsSpecialShapesLesson(
              group: 'ligature',
              progressId: 'test.special.ligature',
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Material), findsWidgets);
    final first = specialShapes.firstWhere((s) => s.group == 'ligature');
    expect(find.text(kidsShapeTitle(ctx, first)), findsOneWidget);
  });

  testWidgets('a single-shape group still reaches a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsSpecialShapesLesson(
          group: 'kaf',
          progressId: 'kids.special.kaf',
        ),
      ),
    );
    await tester.pump();

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.special.kaf'), greaterThan(0));
  });

  testWidgets('the check step asks which shape matches a real title', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsSpecialShapesLesson(
          group: 'stacking',
          progressId: 'test.special.stacking',
        ),
      ),
    );
    await tester.pump();

    final stacking = specialShapes.where((s) => s.group == 'stacking').length;
    for (var i = 0; i < stacking; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.textContaining('Which one is'), findsOneWidget);
    expect(kidsTappables(), findsNWidgets(4));
  });
}
