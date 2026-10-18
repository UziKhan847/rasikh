import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/main.dart';

import 'test_support.dart';

/// Android 15+ draws apps behind a transparent navigation bar; the app must
/// keep its screens and sheets above it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  Future<void> boot(WidgetTester tester, {required double navBar}) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 24, bottom: navBar);
    tester.view.viewPadding = FakeViewPadding(top: 24, bottom: navBar);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.desktopMode = 'off';
    await tester.pumpWidget(QiraahArabiyyahApp(settings: s, progress: p));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('screens end above the Android navigation bar', (tester) async {
    await boot(tester, navBar: 48);
    final nav = tester.getRect(find.byType(Navigator).first);
    expect(nav.bottom, 892 - 48);
    // Below the app, nothing reports the bar any more (no double padding).
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.paddingOf(ctx).bottom, 0);
    expect(MediaQuery.paddingOf(ctx).top, 24);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no bar (gestures hidden / immersive): full height',
      (tester) async {
    await boot(tester, navBar: 0);
    expect(tester.getRect(find.byType(Navigator).first).bottom, 892);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
