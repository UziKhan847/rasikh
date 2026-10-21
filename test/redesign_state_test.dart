import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';

/// The redesign's settings migrations, the reading state that now persists
/// (last read, muṣḥaf page, bookmarks, today's minutes), and the contrast of
/// every text colour in every theme.
Future<AppSettings> _settingsFrom(Map<String, Object?>? stored) async {
  SharedPreferences.setMockInitialValues(
    stored == null ? {} : {'noor.settings.v1': jsonEncode(stored)},
  );
  final s = AppSettings();
  await s.load();
  return s;
}

/// WCAG 2 contrast ratio of [a] on [b].
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('settings migration', () {
    test(
      'the old light / dark / oled modes become Light / Night / OLED',
      () async {
        expect((await _settingsFrom({'mode': 'light'})).appTheme, 'light');
        expect((await _settingsFrom({'mode': 'dark'})).appTheme, 'night');
        expect((await _settingsFrom({'mode': 'oled'})).appTheme, 'oled');
        expect(
          (await _settingsFrom({'theme': 'mono', 'mode': 'dark'})).appTheme,
          'mono',
        );
      },
    );

    test(
      'a pinned or floating player keeps its place as a dock mode',
      () async {
        expect(
          (await _settingsFrom({'playerPinned': true})).playerDock,
          'pinned',
        );
        expect(
          (await _settingsFrom({'playerPinned': false})).playerDock,
          'floating',
        );
        expect(
          (await _settingsFrom({'playerDock': 'hidden'})).playerDock,
          'hidden',
        );
      },
    );

    test('fill-width muṣḥaf becomes the Fill width view', () async {
      expect((await _settingsFrom({'mushafFillW': true})).mushafView, 'fill');
      expect((await _settingsFrom({})).mushafView, 'spread');
    });

    test(
      'a fresh install sees the welcome; an existing one does not',
      () async {
        expect((await _settingsFrom(null)).onboarded, isFalse);
        expect((await _settingsFrom({'lang': 'en'})).onboarded, isTrue);
      },
    );

    test('the old word-by-word flag no longer forces the word grid', () async {
      expect((await _settingsFrom({'wbw': true})).wordByWord, isFalse);
      expect((await _settingsFrom({'wbwGrid': true})).wordByWord, isTrue);
    });

    test('new settings survive a save and reload', () async {
      final s = await _settingsFrom(null);
      s.update(() {
        s.appTheme = 'night';
        s.mushafPaper = 'white';
        s.orHeader = 'madaniColoured';
        s.orMarker = 'indopak';
        s.orBorder = 'tile2';
        s.orMargin = 'text';
        s.orTune = {'headerScale': 1.2};
        s.gradients = false;
        s.playerDock = 'floating';
        s.playbackSpeed = 1.25;
        s.dailyGoalMinutes = 20;
        s.reminderOn = true;
        s.reminderMinutes = 6 * 60 + 30;
        s.sidebarCollapsed = true;
        s.mushafView = 'single';
        s.onboarded = true;
      });
      await s.flush();
      final again = AppSettings();
      await again.load();
      expect(again.appTheme, 'night');
      expect(again.mushafPaper, 'white');
      expect((again.orHeader, again.orMarker, again.orBorder, again.orMargin),
          ('madaniColoured', 'indopak', 'tile2', 'text'));
      expect(again.ornamentTuning['headerScale'], 1.2);
      expect(again.gradients, isFalse);
      expect(again.playerDock, 'floating');
      expect(again.playbackSpeed, 1.25);
      expect(again.dailyGoalMinutes, 20);
      expect(again.reminderOn, isTrue);
      expect(again.reminderMinutes, 390);
      expect(again.sidebarCollapsed, isTrue);
      expect(again.mushafView, 'single');
      expect(again.onboarded, isTrue);
    });
  });

  test('last read, muṣḥaf page, bookmarks and minutes persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressStore();
    await p.load();
    p.setLastRead(2, 255);
    p.setLastMushafPage(42, 'indopak');
    p.toggleBookmark(1, 5);
    p.toggleBookmark(36, 58);
    p.toggleBookmark(1, 5); // and off again
    p.addTime(150);
    await Future<void>.delayed(Duration.zero);

    final again = ProgressStore();
    await again.load();
    expect(again.lastRead, (2, 255));
    expect(again.lastMushafPage, 42);
    expect(again.lastMushafScript, 'indopak');
    expect(again.bookmarks, [(36, 58)]);
    expect(again.minutesToday, 2);
  });

  group('contrast', () {
    for (final t in AppTheme.values) {
      test('every text colour in ${t.name} reads at 4.5:1 or better', () {
        final p = paletteOf(t);
        final pairs = <String, (Color, Color)>{
          'ink on bg': (p.ink, p.bg),
          'ink on card': (p.ink, p.card),
          'ink2 on bg': (p.ink2, p.bg),
          'ink2 on card': (p.ink2, p.card),
          'ink3 on bg': (p.ink3, p.bg),
          'ink3 on card': (p.ink3, p.card),
          'mut on bg': (p.mut, p.bg),
          'acc on card': (p.acc, p.card),
          'acc on bg': (p.acc, p.bg),
          'accInk on accSoft': (p.accInk, p.accSoft),
          'white on accBg': (Colors.white, p.accBg),
          'ink on track': (p.ink, p.track),
        };
        for (final e in pairs.entries) {
          expect(
            contrast(e.value.$1, e.value.$2),
            greaterThanOrEqualTo(4.5),
            reason:
                '${t.name}: ${e.key} is '
                '${contrast(e.value.$1, e.value.$2).toStringAsFixed(2)}:1',
          );
        }
      });
    }

    test('muṣḥaf ink and running head read on every paper', () {
      for (final m in kMushafPapers.values) {
        expect(
          contrast(m.ink, m.paper),
          greaterThanOrEqualTo(7),
          reason: '${m.id}: ink',
        );
        expect(
          contrast(m.sub, m.paper),
          greaterThanOrEqualTo(4.5),
          reason: '${m.id}: sub',
        );
        expect(
          contrast(m.acc, m.paper),
          greaterThanOrEqualTo(4.5),
          reason: '${m.id}: accent',
        );
      }
    });
  });
}
