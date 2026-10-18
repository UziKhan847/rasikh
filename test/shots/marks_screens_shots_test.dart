// Renders the Hifz section, the stats screen and the muṣḥaf in marking mode
// to PNGs for a visual check. Off by default; run with
//   flutter test test/shots/marks_screens_shots_test.dart --dart-define=SHOTS=/some/dir
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/sync/memory_backend.dart';
import 'package:qiraah_arabiyyah/core/sync/sync_engine.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/marks/marks_stats_screen.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/shell/app_shell.dart';

import '../test_support.dart';
import 'shots_test.dart' show loadFonts;

const _out = String.fromEnvironment('SHOTS');

/// A month of sessions on Juzʼ ʿAmma and al-Baqarah.
Future<MarksStore> _seeded() async {
  var t = DateTime(2026, 9, 10, 18).millisecondsSinceEpoch;
  final m = MarksStore(
      persistence: MemoryMarksPersistence(),
      clock: () => t,
      saveDelay: Duration.zero);
  await m.load();
  m.renameMe('Ustadh Bilal');
  final b = m.ensureActiveBook('Zayd').id;
  const plan = [
    (SessionKind.sabaq, 78, 1, 12),
    (SessionKind.sabqi, 79, 1, 9),
    (SessionKind.sabaq, 2, 255, 6),
    (SessionKind.manzil, 67, 1, 7),
    (SessionKind.sabaq, 2, 256, 4),
    (SessionKind.sabqi, 78, 1, 3),
  ];
  var k = 0;
  for (final (kind, s, a, n) in plan) {
    final sess = m.startSession(
        bookId: b, script: 'uthmani', kind: kind, listenerName: 'Ustadh Bilal');
    for (var i = 0; i < n; i++) {
      t += 60000;
      final type = MarkType.pens[(k++ * 7) % 4];
      m.addMark(b, WordRef(s, a + i ~/ 3, 1 + i % 3), type, sessionId: sess.id);
    }
    // Last time's mistakes in this place, read correctly now.
    if (kind == SessionKind.sabqi) {
      for (var i = 0; i < 3; i++) {
        m.fix(b, WordRef(s, a + i ~/ 3, 1 + i % 3), sessionId: sess.id);
      }
    }
    m.endSession(b, sess.id,
        fromGlobalAyah: globalAyahIndex(s, a),
        toGlobalAyah: globalAyahIndex(s, a + 4));
    t += const Duration(days: 4).inMilliseconds;
  }
  return m;
}

void main() {
  if (_out.isEmpty) {
    test('marks screen shots are off (pass --dart-define=SHOTS=dir)', () {});
    return;
  }
  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });

  Future<void> shot(WidgetTester tester, String name, Widget home,
      {required double w,
      required double h,
      String theme = 'light',
      Future<void> Function()? then}) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.appTheme = theme;
    s.desktopMode = w >= 1024 ? 'on' : 'off';
    final m = await _seeded();
    final sync = SyncEngine(store: m, backend: MemorySyncBackend(MemoryServer()));
    final key = GlobalKey();
    await tester.pumpWidget(SyncScope(
      engine: sync,
      child: MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(s),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: RepaintBoundary(key: key, child: home),
            ),
          ),
        ),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    if (then != null) {
      await then();
      await settle();
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 1.5);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
    sync.dispose();
    await m.flush();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('hifz_phone_360', (tester) async {
    await shot(tester, 'hifz_phone_360', const AppShell(), w: 360, h: 1500,
        then: () async {
      await tester.tap(find.text('Hifz').last);
    });
  });

  testWidgets('stats_phone', (tester) async {
    await shot(tester, 'stats_phone', const MarksStatsScreen(), w: 390, h: 2600);
  });

  testWidgets('stats_desk_night', (tester) async {
    await shot(tester, 'stats_desk_night', const MarksStatsScreen(),
        w: 1100, h: 2200, theme: 'night');
  });

  testWidgets('mushaf_marking_phone', (tester) async {
    await shot(tester, 'mushaf_marking_phone',
        const MushafPageScreen(startPage: 582, startMarking: true),
        w: 390, h: 844, then: () async {
      await tester.tap(find.text('Start'));
    });
  });

  testWidgets('session_sheet_phone', (tester) async {
    await shot(tester, 'session_sheet_phone',
        const MushafPageScreen(startPage: 582, startMarking: true),
        w: 390, h: 844);
  });
}
