import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// Kids Mode's own text size dial: Small / Medium / Large, scaling everything a
/// child reads — and nothing a child reads is below the caption size.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Amina'));
  return settings;
}

Widget _harness(AppSettings s, Widget child) => SettingsScope(
  settings: s,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the setting', () {
    test('is Medium unless the child\'s parent picks otherwise', () {
      expect(AppSettings().kidsTextScale, 1.0);
      expect(kidsTextSizes, [0.9, 1.0, 1.2]);
    });

    test('survives a restart, and a wild saved value is clamped', () async {
      SharedPreferences.setMockInitialValues({});
      final a = AppSettings();
      await a.load();
      a.kidsTextScale = 1.2;
      await a.save();

      final b = AppSettings();
      await b.load();
      expect(b.kidsTextScale, 1.2);

      // A hand-edited or corrupt value cannot make the app unreadable.
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().firstWhere(
        (k) => (prefs.getString(k) ?? '').contains('kidsTextScale'),
      );
      final raw = prefs.getString(key)!;
      await prefs.setString(
        key,
        raw.replaceAll('"kidsTextScale":1.2', '"kidsTextScale":9.0'),
      );
      final c = AppSettings();
      await c.load();
      expect(c.kidsTextScale, 1.2, reason: 'clamped to Large');
    });
  });

  group('what it scales', () {
    testWidgets('Latin text, Arabic and the shared quiz screen\'s text', (
      tester,
    ) async {
      useReducedMotion(tester);
      final s = await _boot();
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          s,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      double latin() => kidsStyle(ctx, size: 15).fontSize!;
      double arabic() => quranicStyle(ctx, size: 30).fontSize!;
      double quiz() => uiStyle(ctx, size: 17).fontSize!;

      expect((latin(), arabic(), quiz()), (15.0, 30.0, 17.0));

      s.kidsTextScale = 1.2;
      await tester.pumpWidget(
        _harness(
          s,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(latin(), closeTo(18, 1e-9));
      expect(arabic(), closeTo(36, 1e-9));
      expect(quiz(), closeTo(20.4, 1e-9));

      s.kidsTextScale = 0.9;
      expect(latin(), closeTo(13.5, 1e-9));
    });

    testWidgets('the grown-up Reading Coach no longer resizes a child\'s '
        'Arabic, and the child\'s dial does not touch the grown-up app', (
      tester,
    ) async {
      useReducedMotion(tester);
      final s = await _boot();
      late BuildContext ctx;
      Widget app() => _harness(
        s,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(app());

      s.arabicScale = 1.8; // a parent's reader setting
      expect(
        quranicStyle(ctx, size: 30).fontSize,
        30.0,
        reason: 'Kids Mode ignores the reader slider',
      );

      // Out of Kids Mode the reader slider is back in charge, and the kids
      // dial does nothing.
      s.kidsMode = false;
      s.kidsTextScale = 1.2;
      expect(quranicStyle(ctx, size: 30).fontSize, closeTo(54, 1e-9));
      expect(uiStyle(ctx, size: 17).fontSize, 17.0);
    });
  });

  group('the picker', () {
    testWidgets('three tiles, the current one selected, tapping changes it', (
      tester,
    ) async {
      useReducedMotion(tester);
      final s = await _boot();
      await tester.pumpWidget(_harness(s, const KidsTextSizePicker()));
      await tester.pump();

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);

      await tester.tap(find.text('Large'));
      await tester.pump();
      expect(s.kidsTextScale, 1.2);

      await tester.tap(find.text('Small'));
      await tester.pump();
      expect(s.kidsTextScale, 0.9);

      await tester.tap(find.text('Medium'));
      await tester.pump();
      expect(s.kidsTextScale, 1.0);
      // The save is debounced; let it fire.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('its "A"s stay their own size whichever is selected', (
      tester,
    ) async {
      useReducedMotion(tester);
      final s = await _boot();
      await tester.pumpWidget(_harness(s, const KidsTextSizePicker()));
      await tester.pump();
      double sizeOf(int i) =>
          tester.widget<Text>(find.text('A').at(i)).style!.fontSize!;
      final before = [sizeOf(0), sizeOf(1), sizeOf(2)];
      expect(before[0], lessThan(before[1]));
      expect(before[1], lessThan(before[2]));

      s.update(() => s.kidsTextScale = 1.2);
      await tester.pump(const Duration(milliseconds: 400));
      expect([sizeOf(0), sizeOf(1), sizeOf(2)], before);
    });

    testWidgets('the compact strip fits the desktop sidebar', (tester) async {
      useReducedMotion(tester);
      final s = await _boot();
      await tester.pumpWidget(
        _harness(
          s,
          const SizedBox(width: 200, child: KidsTextSizePicker(compact: true)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Small'), findsNothing, reason: 'letters only');
      expect(find.text('A'), findsNWidgets(3));
    });
  });

  group('the type ladder', () {
    test('has five steps and nothing below the caption', () {
      expect(
        [kidsCaption, kidsBody, kidsLabel, kidsPrompt, kidsTitle],
        [13.0, 15.0, 16.0, 19.0, 21.0],
      );
    });

    test('no child-facing kidsStyle call sets a size under the caption', () {
      // Parent-facing screens keep their own (small) sizes on purpose.
      const parentFacing = {
        'kids_parent_report.dart',
        'kids_parent_gate.dart',
        'kids_desktop_shell.dart',
      };
      // kidsStyle( ... size: <literal> — with no nested parentheses before it.
      final call = RegExp(
        r'kidsStyle\(\s*[^()]*?\bsize:\s*([0-9]+(?:\.[0-9]+)?)',
      );
      final offenders = <String>[];
      for (final f in Directory(
        'lib/screens/kids',
      ).listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.dart') || parentFacing.contains(name)) continue;
        final src = f.readAsStringSync();
        for (final m in call.allMatches(src)) {
          final v = double.parse(m.group(1)!);
          if (v < kidsCaption) {
            final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
            offenders.add('$name:$line size $v');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
