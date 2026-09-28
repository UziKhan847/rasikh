import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_sort_bins.dart';

import 'kids_test_support.dart';

/// [KidsSortBins]: every tile is sorted by dragging it into its bin OR by
/// tapping it and then the bin — both must work and grade the same.
const _items = [
  KidsSortItem(id: 'a', label: 'ٱلشَّ', bin: 0),
  KidsSortItem(id: 'b', label: 'ٱلۡقَ', bin: 1),
  KidsSortItem(id: 'c', label: 'ٱلتَّ', bin: 0),
];

Finder _tile(String id) => find.byKey(ValueKey('sortItem.$id'));
Finder _bin(int i) => find.byKey(ValueKey('sortBin.$i'));

Future<({List<String> wrong, List<bool> done})> _open(
  WidgetTester tester, {
  double textScale = 1.0,
}) async {
  useReducedMotion(tester);
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.kidsTextScale = textScale;
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
          body: KidsSortBins(
            prompt: 'Sort them',
            items: _items,
            bins: const [
              KidsSortBin(emoji: '☀️', title: 'Sun'),
              KidsSortBin(emoji: '🌙', title: 'Moon'),
            ],
            onWrong: (item, bin) => wrong.add('${item.id}->$bin'),
            onDone: done.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (wrong: wrong, done: done);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dragging every tile into its bin finishes, first try', (
    tester,
  ) async {
    final r = await _open(tester);
    await dragOnto(tester, _tile('a'), _bin(0));
    await dragOnto(tester, _tile('b'), _bin(1));
    expect(r.done, isEmpty, reason: 'one tile is still to sort');
    await dragOnto(tester, _tile('c'), _bin(0));
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [true]);
    expect(r.wrong, isEmpty);
    expect(_tile('a'), findsNothing, reason: 'sorted tiles leave the pool');
  });

  testWidgets('tapping a tile and then its bin does the same', (tester) async {
    final r = await _open(tester);
    for (final (id, bin) in [('a', 0), ('b', 1), ('c', 0)]) {
      await tester.tap(_tile(id));
      await tester.pump();
      await tester.tap(_bin(bin));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [true]);
    expect(r.wrong, isEmpty);
  });

  testWidgets('a tile dropped in the wrong bin comes back and costs the '
      'first-try mark', (tester) async {
    final r = await _open(tester);
    await dragOnto(tester, _tile('a'), _bin(1));
    expect(r.wrong, ['a->1']);
    expect(_tile('a'), findsOneWidget, reason: 'handed back, not lost');
    await tester.pump(const Duration(milliseconds: 600));

    await dragOnto(tester, _tile('a'), _bin(0));
    await dragOnto(tester, _tile('b'), _bin(1));
    await dragOnto(tester, _tile('c'), _bin(0));
    await tester.pump(const Duration(milliseconds: 800));
    expect(r.done, [false]);
  });

  testWidgets('a wrong tap-and-place is a miss too', (tester) async {
    final r = await _open(tester);
    await tester.tap(_tile('b'));
    await tester.pump();
    await tester.tap(_bin(0));
    await tester.pump();
    expect(r.wrong, ['b->0']);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('tapping a bin with nothing picked up does nothing', (
    tester,
  ) async {
    final r = await _open(tester);
    await tester.tap(_bin(0));
    await tester.pump();
    expect(r.wrong, isEmpty);
    expect(_tile('a'), findsOneWidget);
  });

  testWidgets('letting go away from both bins is not a miss', (tester) async {
    final r = await _open(tester);
    final start = tester.getCenter(_tile('a'));
    final g = await tester.startGesture(start);
    await g.moveBy(const Offset(0, -20));
    await tester.pump();
    await g.moveTo(start + const Offset(0, -60));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(r.wrong, isEmpty);
    expect(_tile('a'), findsOneWidget);
  });

  testWidgets('fits a 320×568 phone at the largest text size', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester, textScale: 1.2);
    expect(tester.takeException(), isNull);
  });
}
