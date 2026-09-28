import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_order_card.dart';

import 'kids_test_support.dart';

/// [KidsOrderCard] is finished by dragging tiles into the row being built OR
/// by tapping them — both must work, and both must grade the same way.
const _items = ['ب', 'س', 'م'];

Finder _offered(String t) =>
    find.descendant(of: kidsTappables(), matching: find.text(t));

/// Pumps a card and returns what it reported: `wrong` taps and the final
/// `done` flag (null until it finishes).
Future<({List<String> wrong, List<bool> done})> _open(
  WidgetTester tester, {
  List<String> decoys = const [],
  bool wide = false,
}) async {
  useReducedMotion(tester);
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  final wrong = <String>[];
  final done = <bool>[];
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: KidsOrderCard(
            prompt: 'Build it',
            items: _items,
            decoys: decoys,
            rng: math.Random(3),
            size: 36,
            wide: wide,
            onWrong: (tapped, _) => wrong.add(tapped),
            onDone: done.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (wrong: wrong, done: done);
}

Finder get _row => find.byType(DragTarget<int>);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dragging the tiles in order builds the word', (tester) async {
    final r = await _open(tester);
    for (final t in _items) {
      await dragOnto(tester, _offered(t), _row);
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [true]);
    expect(r.wrong, isEmpty);
  });

  testWidgets('tapping the tiles in order builds the word', (tester) async {
    final r = await _open(tester);
    for (final t in _items) {
      await tester.tap(_offered(t));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [true]);
    expect(r.wrong, isEmpty);
  });

  testWidgets('dropping the wrong tile is a miss and places nothing', (
    tester,
  ) async {
    final r = await _open(tester);
    await dragOnto(tester, _offered('م'), _row);
    expect(r.wrong, ['م']);
    // It is still on offer, and the first tile is still the one that fits.
    expect(_offered('م'), findsOneWidget);
    for (final t in _items) {
      await dragOnto(tester, _offered(t), _row);
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [false], reason: 'a miss costs the first-try mark');
  });

  testWidgets('a decoy dragged in is always wrong and stays on offer', (
    tester,
  ) async {
    final r = await _open(tester, decoys: const ['ش']);
    await dragOnto(tester, _offered('ش'), _row);
    expect(r.wrong, ['ش']);
    expect(_offered('ش'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // the red flash ends
  });

  testWidgets('letting go away from the row does nothing at all', (
    tester,
  ) async {
    final r = await _open(tester);
    final start = tester.getCenter(_offered('ب'));
    final g = await tester.startGesture(start);
    await g.moveBy(const Offset(0, 30));
    await tester.pump();
    await g.moveTo(start + const Offset(0, 200));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(r.wrong, isEmpty, reason: 'a stray drop is not a wrong answer');
    expect(_offered('ب'), findsOneWidget);
  });

  testWidgets(
    'mixing drags and taps works, and a finished card takes no more',
    (tester) async {
      final r = await _open(tester);
      await dragOnto(tester, _offered('ب'), _row);
      await tester.tap(_offered('س'));
      await tester.pump();
      await dragOnto(tester, _offered('م'), _row);
      await tester.pump(const Duration(milliseconds: 800));
      expect(r.done, [true]);
    },
  );

  testWidgets('whole-line (āyah) mode drags the same way', (tester) async {
    final r = await _open(tester, wide: true);
    for (final t in _items) {
      await dragOnto(tester, _offered(t), _row);
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [true]);
  });
}
