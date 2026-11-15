import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/reader/ayah_text.dart';
import 'package:rasikh/screens/reader/reader_host.dart' show VersesView;

import 'test_support.dart';

/// A word held is the same sheet in the Reader as on the muṣḥaf: its marks
/// (a mutashābih too — linked on the muṣḥaf), its fluency marks as compact
/// chips, the arrows to the words either side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });

  Future<MarksStore> home(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
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
      ..desktopMode = 'on';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    final f = FluencyStore();
    await tester.pumpWidget(MarksScope(
      store: m,
      child: FluencyScope(
        store: f,
        child: SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
    return m;
  }

  Future<void> sheetOpen(WidgetTester tester) async {
    for (var i = 0; i < 40 && find.text('Play word').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('held in the Reader: the muṣḥaf\'s sheet; a mutashābih goes to the '
      'muṣḥaf to link its likenesses', (tester) async {
    final m = await home(tester);
    await tester.tap(find.byTooltip('Verses').hitTestable().first);
    await settle(tester);
    expect(find.byType(VersesView), findsOneWidget);

    final r = tester
        .renderObjectList<RenderAyahText>(find.byType(AyahText))
        .firstWhere((r) => r.attached && r.wordCenter(1) != null);
    await tester.longPressAt(r.localToGlobal(r.wordCenter(1)!));
    await sheetOpen(tester);
    // As on the muṣḥaf: the arrows, the marks with a mutashābih, the fluency chips.
    expect(find.byTooltip('Next word'), findsOneWidget);
    expect(find.byTooltip('Previous word'), findsOneWidget);
    expect(find.text('Mutashābih'), findsOneWidget);
    expect(find.byKey(const ValueKey('fl-slow')), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Not fluent'), findsOneWidget,
        reason: 'a compact chip, not a row with a switch');
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.text('Mutashābih'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(VersesView), findsNothing, reason: 'back on the muṣḥaf');
    expect(find.text("Tap the passages it's confused with — on any page"), findsOneWidget);
    final b = m.activeBookId!;
    expect(m.marksOf(b).single.type, MarkType.mutashabih);
    await m.flush();
    await tester.pumpWidget(const SizedBox());
    // The audio plugin's 30 s prepare timeout (no audio in tests).
    await tester.pump(const Duration(seconds: 31));
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}
