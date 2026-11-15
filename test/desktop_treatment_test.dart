import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/keymap.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/button_guide.dart';
import 'package:rasikh/screens/keyboard_sheet.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf/tool_circles.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/shell/app_shell.dart';

import 'test_support.dart';

/// Desktop mode: the row, right-clicks, the mouse over words, the key map.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Finder tip(String t) => find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message == t || (w.message ?? '').startsWith('$t (')));

  Future<(AppSettings, MarksStore)> pump(WidgetTester tester,
      {Size size = const Size(1400, 900), String mode = 'on', bool shell = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..toolHintSeen = true
      ..desktopMode = mode;
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: shell
                ? const AppShell()
                : const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
          ),
        ),
      ),
    ));
    await settle(tester);
    return (s, m);
  }

  /// A word's middle on screen, and what it is.
  (Offset, MushafWord) someWord(WidgetTester tester) {
    final line = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .firstWhere((r) => r.attached && r.spec.line.words.length > 3 && r.spec.page == 50);
    final i = line.spec.line.words.indexWhere((w) => !w.isMarker);
    final wd = line.spec.line.words[i];
    final rect = line.wordRect(i)!;
    return (line.localToGlobal(rect.center), wd);
  }

  group('the row', () {
    DockItem item(String t) => DockItem(icon: Icons.add, tooltip: t, onTap: (_) {});
    final main = [for (var i = 0; i < 5; i++) item('m$i')];
    final fan = [for (var i = 0; i < 11; i++) item('f$i')];

    test('off desktop mode, nothing moves', () {
      final (row, rest) = splitDock(main, fan, desktop: false, length: 2000);
      expect(row, hasLength(5));
      expect(rest, hasLength(11));
    });

    test('tall: everything in the row; short: what fits, the rest behind ⋯', () {
      final (row, rest) = splitDock(main, fan, desktop: true, length: 1000);
      expect(row, hasLength(16));
      expect(rest, isEmpty);
      final (r2, rest2) = splitDock(main, fan, desktop: true, length: 500);
      expect(r2.length + rest2.length, 16);
      expect(rest2, isNotEmpty);
      expect(r2.length, greaterThan(5));
      // Fits, with a ⋯ beside it.
      expect((r2.length + 1) * (ToolCircles.desktopSize + 12), lessThanOrEqualTo(500));
    });

    testWidgets('a big window has no ⋯; the pages button is a tap, and the popovers open '
        'from their own buttons', (tester) async {
      final (s, m) = await pump(tester);
      expect(find.byTooltip('More'), findsNothing);
      expect(tip('Two pages'), findsOneWidget);
      expect(s.hifzLandscapePages, 'two');
      await tester.tap(tip('Two pages'));
      await settle(tester);
      expect(s.hifzLandscapePages, isNot('two'));
      await tester.tap(find.byTooltip('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Page colour'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  group('a right-click on a word', () {
    Future<void> rightClick(WidgetTester tester, Offset at) async {
      await tester.tapAt(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
    }

    testWidgets('a small menu: the kinds, comment, play, copy, more', (tester) async {
      final (_, m) = await pump(tester);
      final (at, _) = someWord(tester);
      await rightClick(tester, at);
      for (final t in ['Mistake', 'Tajwīd', 'Hesitation', 'Doubt', 'Note', 'Comment', 'Play word', 'Copy', 'More…']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await m.flush();
    });

    testWidgets('choosing a kind marks it, and again takes it off; Ctrl+Z undoes it',
        (tester) async {
      final (_, m) = await pump(tester);
      final b = m.activeBookId!;
      final (at, wd) = someWord(tester);
      final ref = WordRef.fromGlobal(wd.ayah, wd.wordIdx);
      await rightClick(tester, at);
      await tester.tap(find.text('Doubt'));
      await tester.pumpAndSettle();
      expect(m.marksAt(b, ref).single.type, MarkType.doubt);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(m.marksAt(b, ref), isEmpty, reason: 'undone');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(m.marksAt(b, ref).single.type, MarkType.doubt, reason: 'redone');
      await rightClick(tester, at);
      await tester.tap(find.text('Doubt'));
      await tester.pumpAndSettle();
      expect(m.marksAt(b, ref), isEmpty, reason: 'chosen again: off');
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('a right-click on a tool: its options', (tester) async {
      final (_, m) = await pump(tester);
      await tester.tapAt(tester.getCenter(tip('Mark')),
          kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('How a tap marks'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await m.flush();
    });
  });

  group('a click with a modifier', () {
    Future<void> click(WidgetTester tester, Offset at, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(key);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(key);
      await tester.pumpAndSettle();
    }

    Future<void> middle(WidgetTester tester, Offset at) async {
      await tester.tapAt(at, kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
      await tester.pumpAndSettle();
    }

    const shift = LogicalKeyboardKey.shiftLeft, ctrl = LogicalKeyboardKey.controlLeft;

    testWidgets('they can be changed: another button does it, the old one no longer does',
        (tester) async {
      final (s, m) = await pump(tester);
      final b = m.activeBookId!;
      final (at, wd) = someWord(tester);
      final ref = WordRef.fromGlobal(wd.ayah, wd.wordIdx);
      s.update(() => s.keyBindings[Keymap.mouseKey(MouseAction.stepMark)] =
          const MouseCombo(kMiddleMouseButton).encode());
      await tester.pump();
      await click(tester, at, shift);
      expect(m.marksAt(b, ref), isEmpty, reason: 'Shift and a click: a click, now');
      await middle(tester, at);
      expect(m.marksAt(b, ref).single.type, MarkType.mistake);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('in the sheet: a button pressed binds it; a plain left click is refused',
        (tester) async {
      final (s, m) = await pump(tester);
      await tester.sendKeyDownEvent(shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(shift);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.byKey(const ValueKey('mouse-comment')),
          find.byType(KeyboardSheet), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mouse-comment')));
      await tester.pumpAndSettle();
      final box = tester.getCenter(find.byKey(const ValueKey('mouse-capture')));
      await tester.tapAt(box, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mouse-capture')), findsOneWidget, reason: 'refused');
      await tester.tapAt(box, kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
      await tester.pumpAndSettle();
      // The back button turns pages: asks, and swaps.
      expect(find.text('Swap'), findsOneWidget);
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();
      expect(s.keymap.mouseOf(MouseAction.comment).button, kBackMouseButton);
      expect(s.keymap.mouseOf(MouseAction.prevPage).button, kMiddleMouseButton);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('Shift marks a word, again the next kind, on to off; undo too', (tester) async {
      final (_, m) = await pump(tester);
      final b = m.activeBookId!;
      final (at, wd) = someWord(tester);
      final ref = WordRef.fromGlobal(wd.ayah, wd.wordIdx);
      for (final t in MarkType.pens) {
        await click(tester, at, shift);
        expect(m.marksAt(b, ref).single.type, t);
      }
      await click(tester, at, shift);
      expect(m.marksAt(b, ref), isEmpty, reason: 'past the last: off');
      await tester.sendKeyDownEvent(ctrl);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(ctrl);
      await tester.pump();
      expect(m.marksAt(b, ref).single.type, MarkType.pens.last);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('the wheel\'s click writes the comment: a note on a bare word, or on its '
        'own mark', (tester) async {
      final (_, m) = await pump(tester);
      final b = m.activeBookId!;
      final (at, wd) = someWord(tester);
      final ref = WordRef.fromGlobal(wd.ayah, wd.wordIdx);
      await middle(tester, at);
      await tester.enterText(find.byType(TextField), 'first');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(m.marksAt(b, ref).single.type, MarkType.note);
      expect(m.marksAt(b, ref).single.comment, 'first');
      // Its own mark: the same one, its words to edit.
      await middle(tester, at);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'first');
      await tester.enterText(find.byType(TextField), 'second');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(m.marksAt(b, ref).single.comment, 'second');
      // Nothing written on a bare word: nothing made.
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('mobile mode: they\'re just clicks', (tester) async {
      final (_, m) = await pump(tester, size: const Size(900, 1000), mode: 'off');
      final b = m.activeBookId!;
      final (at, wd) = someWord(tester);
      await click(tester, at, shift);
      await middle(tester, at);
      expect(m.marksAt(b, WordRef.fromGlobal(wd.ayah, wd.wordIdx)), isEmpty);
      expect(find.byType(TextField), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  testWidgets('the mouse over a word lights it; off it, it goes', (tester) async {
    final (_, m) = await pump(tester);
    final (at, _) = someWord(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(5, 5));
    addTearDown(mouse.removePointer);
    await tester.pump();
    final before = RenderMushafLine.debugPaints;
    await mouse.moveTo(at);
    await tester.pump();
    expect(RenderMushafLine.debugPaints, greaterThan(before), reason: 'its line repainted');
    final painted = RenderMushafLine.debugPaints;
    await mouse.moveTo(at + const Offset(.5, 0));
    await tester.pump();
    expect(RenderMushafLine.debugPaints, painted, reason: 'still the same word: nothing to do');
    expect(tester.takeException(), isNull);
    await m.flush();
  });

  group('the keys', () {
    test('a key survives being saved; a clash is only with what\'s live at once', () {
      const c = KeyCombo(LogicalKeyboardKey.keyK, ctrl: true, shift: true);
      expect(KeyCombo.decode(c.encode()), c);
      expect(c.label, 'Ctrl+Shift+K');
      const km = Keymap({});
      expect(km.label(KeyAction.nextPage), '←');
      // The shortcuts list shows every key an action answers to.
      expect(km.allLabels(KeyAction.reviewNext), '←  ·  Space');
      expect(km.allLabels(KeyAction.memoPrevWord), '→  ·  Backspace');
      expect(km.allLabels(KeyAction.zoomIn).split('·').length, 2,
          reason: 'a key once, not each Shift variant');
      expect(const Keymap({'reviewNext': '000:${0x00000000020}'}).allLabels(KeyAction.reviewNext),
          isNot(contains('·')), reason: 'a changed key replaces them');
      expect(km.clashOf(KeyAction.markMode, const KeyCombo(LogicalKeyboardKey.keyI)),
          KeyAction.openIndex);
      // Memorizing's own keys are its own.
      expect(km.clashOf(KeyAction.memoPlay, const KeyCombo(LogicalKeyboardKey.keyI)), isNull);
      for (final a in KeyAction.values) {
        expect(kDefaultKeys[a], isNotEmpty, reason: a.name);
      }
    });

    test('a mouse\'s binding survives being saved; a plain click or scroll can\'t be one', () {
      const c = MouseCombo(kMiddleMouseButton, alt: true);
      expect(MouseCombo.decode(c.encode()), c);
      expect(c.label, 'Alt+Wheel click');
      expect(const MouseCombo(kPrimaryButton).isReserved, isTrue);
      expect(const MouseCombo(MouseCombo.scroll).isReserved, isTrue);
      expect(const MouseCombo(kPrimaryButton, shift: true).isReserved, isFalse);
      expect(const Keymap({}).mouseOf(MouseAction.comment).button, kMiddleMouseButton);
    });

    test('no two defaults that are live together are the same key', () {
      const km = Keymap({});
      for (final a in KeyAction.values) {
        for (final c in kDefaultKeys[a]!) {
          expect(km.clashOf(a, c), isNull, reason: '${a.name} ${c.label}');
        }
      }
    });

    testWidgets('D, T, Ctrl+G and F11 do what they say', (tester) async {
      final (s, m) = await pump(tester, shell: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(s.hifzLandscapePages, isNot('two'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await settle(tester);
      expect(s.isDarkTheme, isTrue);
      final immersive = s.immersive;
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(s.immersive, !immersive, reason: 'not a computer here: the system bars');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.autofocus, isTrue, reason: 'ready to type the page');
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });

    testWidgets('a key changed in the sheet works; a clash offers a swap; reset puts it back',
        (tester) async {
      final (s, m) = await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardSheet), findsOneWidget);

      await tester.dragUntilVisible(find.byKey(const ValueKey('key-darkMode')),
          find.byType(KeyboardSheet), const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('key-darkMode')));
      await tester.pumpAndSettle();
      expect(find.text('Press the new keys.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(s.keymap.label(KeyAction.darkMode), 'K');

      // M is Mark mode's: asks, and swaps.
      await tester.tap(find.byKey(const ValueKey('key-darkMode')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(find.textContaining('M already does'), findsOneWidget);
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();
      expect(s.keymap.label(KeyAction.darkMode), 'M');
      expect(s.keymap.label(KeyAction.markMode), 'K');

      await tester.dragUntilVisible(
          find.text('Reset all'), find.byType(KeyboardSheet), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset all'));
      await tester.pumpAndSettle();
      expect(s.keyBindings, isEmpty);
      expect(s.keymap.label(KeyAction.darkMode), 'T');
      await tester.pump(const Duration(seconds: 5));
      await m.flush();
    });
  });

  testWidgets('the button guide fits a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showButtonGuide(c),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Button guide'), findsOneWidget);
    expect(find.text('Index'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
