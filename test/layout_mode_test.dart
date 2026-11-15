import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/responsive.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/screens/marks/marking.dart';

import 'test_support.dart';

/// Desktop mode is asked for on a phone or tablet, and a comment's keys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(mockAudioPlugins);

  Future<(AppSettings, BuildContext)> pump(WidgetTester tester, Size size, String mode) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.desktopMode = mode;
    late BuildContext ctx;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ),
    ));
    return (s, ctx);
  }

  testWidgets('auto: mobile on a phone and on a tablet', (tester) async {
    for (final size in [const Size(390, 800), const Size(1024, 1366), const Size(1366, 1024)]) {
      final (_, c) = await pump(tester, size, 'auto');
      expect(useDesktop(c), isFalse, reason: '$size');
    }
  });

  testWidgets('either can ask for desktop mode, a phone too', (tester) async {
    for (final size in [const Size(390, 800), const Size(1024, 1366)]) {
      final (s, c) = await pump(tester, size, 'on');
      expect(useDesktop(c), isTrue, reason: '$size');
      s.update(() => s.desktopMode = 'off');
      await tester.pump();
      expect(useDesktop(c), isFalse);
      await tester.pump(const Duration(seconds: 5));
    }
  });

  group('a comment', () {
    Future<(Future<String?>,)> open(WidgetTester tester, String mode) async {
      final (_, c) = await pump(tester, const Size(800, 900), mode);
      final result = askText(c, title: 'Comment', comment: true);
      await tester.pumpAndSettle();
      return (result,);
    }

    testWidgets('desktop: Enter sends it, Shift+Enter leaves it open for a new line',
        (tester) async {
      final (result,) = await open(tester, 'on');
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget, reason: 'still writing');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(await result, 'a');
    });

    testWidgets('an input method\'s word in the making keeps its Enter', (tester) async {
      await open(tester, 'on');
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.value = const TextEditingValue(
          text: 'سل', composing: TextRange(start: 0, end: 2));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('mobile: Enter is a new line; Save sends it', (tester) async {
      final (result,) = await open(tester, 'off');
      await tester.enterText(find.byType(TextField), 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await result, isNotNull);
    });
  });
}
