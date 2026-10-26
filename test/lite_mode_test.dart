import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf_atlas.dart';
import 'package:qiraah_arabiyyah/data/strokes.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart' show TracingBoard;
import 'package:qiraah_arabiyyah/ui/kit.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart';

import 'test_support.dart';

/// Lite mode: one switch that turns off what slow devices pay most for —
/// animations, blurred shadows, gradients and ornaments, the large glyph
/// sheets — without touching what reading needs.
Future<AppSettings> _settings({bool lite = true}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  await s.load();
  s.onboarded = true;
  s.desktopMode = 'off';
  s.lite = lite;
  return s;
}

Widget _harness(AppSettings s, Widget child) => SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        // What the app's root does in Lite mode (see _LiteMotion).
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: s.lite),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  test('Lite mode overrides ornaments and gradients, and keeps them', () async {
    final s = await _settings(lite: false);
    expect((s.useOrnate, s.useGradients), (true, true));
    s.lite = true;
    expect((s.useOrnate, s.useGradients), (false, false));
    expect((s.orHeader, s.gradients), ('auto', true)); // back when Lite is off
    final look = s.mushafLook('uthmani');
    // The one minimal look (kMushafCustomization off): no margin at all.
    expect((look.header, look.marker, look.margin),
        ('plain', 'font', kMushafCustomization ? 'text' : 'none'));
    await s.save();
    final again = AppSettings();
    await again.load();
    expect(again.lite, isTrue);
  });

  testWidgets('the whole app runs with animations off', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await _settings();
    final p = ProgressStore();
    await p.load();
    await tester.pumpWidget(QiraahArabiyyahApp(settings: s, progress: p));
    await tester.pump(const Duration(milliseconds: 300));
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.disableAnimationsOf(ctx), isTrue);
    expect(noMotion(ctx), isTrue);
    expect(qShadows(ctx, const [BoxShadow(blurRadius: 9)]), isNull);

    s.update(() => s.lite = false);
    await tester.pump(const Duration(milliseconds: 300));
    final ctx2 = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.disableAnimationsOf(ctx2), isFalse);
    await tester.pump(const Duration(seconds: 1)); // the settings save
  });

  testWidgets('entrances show their child at once', (tester) async {
    final s = await _settings();
    await tester.pumpWidget(_harness(
        s, const FadeSlideIn(delayMs: 300, child: Text('ready'))));
    expect(find.text('ready'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(FadeTransition)),
        findsNothing);
    // No delay timer and no controller: nothing left to draw once the
    // first frames are out.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('without Lite mode the entrance still plays', (tester) async {
    final s = await _settings(lite: false);
    await tester.pumpWidget(_harness(
        s, const FadeSlideIn(delayMs: 0, child: Text('ready'))));
    expect(
        find.descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(FadeTransition)),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a guided tracing board holds still: no frames while idle',
      (tester) async {
    final s = await _settings();
    await tester.pumpWidget(_harness(
        s, TracingBoard(glyph: glyphFor('ب', 'iso'), mode: 'guided')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'the guide pulse keeps repainting in Lite mode');
  });

  test('the muṣḥaf draws from the standard sheets only', () {
    addTearDown(() => MushafAtlas.setSmallOnly(false));
    final before = MushafAtlas.capVersion;
    MushafAtlas.setSmallOnly(true);
    expect(MushafAtlas.smallOnly, isTrue);
    expect(MushafAtlas.capVersion, before + 1);
    MushafAtlas.setSmallOnly(true); // no change, no new version
    expect(MushafAtlas.capVersion, before + 1);
  });
}
