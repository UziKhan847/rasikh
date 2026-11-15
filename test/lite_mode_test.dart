import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf_atlas.dart';
import 'package:rasikh/main.dart';
import 'package:rasikh/ui/kit.dart';

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
