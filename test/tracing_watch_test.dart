import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/strokes.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart' show TracingBoard;

/// "Watch" — a non-interactive replay of a letter being written, stroke by
/// stroke, built from the same [TracedGlyph] stroke data and `_BoardPainter`
/// the guided tracing mode already uses to ink the child's own strokes
/// progressively. Never graded: there is nothing for the viewer to do.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  return settings;
}

Widget _harness(AppSettings settings, Widget child) => SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays through every stroke on its own, never asks onStars',
      (tester) async {
    // Deliberately NOT useReducedMotion + pumpAndSettle: the board's own
    // pulse animation repeats forever regardless of watch mode, so every
    // tracing-board test in this app advances time with bounded pumps.
    final settings = await _boot();
    var starsCalled = false;
    final glyph = glyphFor('ب', 'iso'); // 2 strokes + a dot
    await tester.pumpWidget(_harness(
        settings,
        TracingBoard(
          glyph: glyph,
          mode: 'guided',
          watch: true,
          onStars: (_) => starsCalled = true,
        )));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);

    // Long enough to run through every stroke at least twice over.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(starsCalled, isFalse,
        reason: 'a watched demo is never graded — there is nothing to grade');
  });

  testWidgets('offers a control to watch it again', (tester) async {
    final settings = await _boot();
    final glyph = glyphFor('ب', 'iso');
    await tester.pumpWidget(_harness(
        settings,
        TracingBoard(glyph: glyph, mode: 'guided', watch: true)));
    await tester.pump();

    final replay = find.byIcon(Icons.replay_rounded);
    expect(replay, findsOneWidget);
    await tester.tap(replay);
    await tester.pump();
    // Restarting mid-playback must not throw.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a watched demo needs no onStars callback', (tester) async {
    final settings = await _boot();
    final glyph = glyphFor('ب', 'iso');
    // No onStars at all — the constructor no longer requires one.
    await tester.pumpWidget(
        _harness(settings, TracingBoard(glyph: glyph, mode: 'guided', watch: true)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
