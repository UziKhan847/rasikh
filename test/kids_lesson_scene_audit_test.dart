// The design's one rule for the backdrop, applied to every lesson: only
// headings and one-line subtitles sit straight on the vivid scene; everything
// else sits on a solid surface. The tabs have their own audit
// (kids_scene_audit_test.dart); this walks each lesson step by step.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';

import 'kids_lesson_walk_support.dart';
import 'kids_scene_audit_support.dart';
import 'kids_test_support.dart';

void main() {
  setUp(() => LetterAudio.log = []);
  tearDown(() => LetterAudio.log = null);

  for (final e in kidsWalkLessons().entries) {
    testWidgets('${e.key}: no step leaves text bare on the vivid scene', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      final prog = ProgressStore(profileId: 'p1');
      await settings.load();
      await prog.load();
      settings
        ..kidsMode = true
        ..desktopMode = 'off'
        ..kidsDetail = KidsDetail.high;
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Amina'));
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: ProgressScope(
            progress: prog,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: e.value(),
            ),
          ),
        ),
      );
      await tester.pump();

      final bare = <String>{};
      await kidsWalk(
        tester,
        onStep: (_) => bare.addAll(kidsTextsOnScene(tester)),
      );
      expect(
        bare,
        isEmpty,
        reason:
            'text on the vivid scene — make it a heading or put it on a card',
      );
    });
  }
}
