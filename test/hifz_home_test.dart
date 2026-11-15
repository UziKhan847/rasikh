import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/mushaf_search.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/fluency/fluency_tools.dart';
import 'package:rasikh/screens/marks/review_bar.dart';
import 'package:rasikh/screens/marks/word_marks_sheet.dart';
import 'package:rasikh/screens/mushaf/memorize_bar.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf/mushaf_index_sheet.dart';
import 'package:rasikh/screens/mushaf/words_line.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/ui/adaptive_sheet.dart';
import 'package:rasikh/ui/app_icons.dart';

import 'package:rasikh/screens/reader/reader_host.dart' show ReaderViewSwitch, VersesView;
import 'package:rasikh/core/display_rotation.dart';
import 'package:rasikh/screens/settings_screen.dart';
import 'test_support.dart';

/// The muṣḥaf home: its five circles and the ⋯ fan, Mark and Review (a tap
/// starts, a hold chooses), comment and eraser inside mark mode, memorize,
/// the View and Theme popovers, and searching the text.
const _ref = WordRef(44, 25, 2); // a word on page 497 (ad-Dukhān)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<(AppSettings, ProgressStore, MarksStore)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..toolHintSeen = true
      ..desktopMode = 'off';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (s, p, m);
  }

  Future<void> pump(WidgetTester tester, AppSettings s, ProgressStore p, MarksStore m) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = MushafRepo.pageOfWord('uthmani', _ref.globalAyah, _ref.word0);
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
            home: MushafPageScreen(home: true, startPage: page, script: 'uthmani'),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Opens the ⋯ fan.
  Future<void> fan(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
  }

  /// Where to touch [ref]'s word.
  Offset wordAt(WidgetTester tester, WordRef ref) {
    for (final el in find.byType(MushafLineView).evaluate()) {
      final r = el.renderObject! as RenderMushafLine;
      final laid = r.laidLine;
      if (laid == null) continue;
      final words = r.spec.line.words;
      for (var i = 0; i < words.length; i++) {
        final w = words[i];
        if (w.ayah == ref.globalAyah && w.wordIdx == ref.word0) {
          final (left, right) = laid.boxes[i];
          return r.localToGlobal(r.textOffset + Offset((left + right) / 2, laid.height / 2));
        }
      }
    }
    throw StateError('word not on screen');
  }

  testWidgets('five circles (Index first) and ⋯; the fan has the rest, a tap outside '
      'folds it; the header names sūrah, page, juzʼ', (tester) async {
    final (s, p, m) = await boot();
    s.toolHintSeen = false;
    await pump(tester, s, p, m);
    for (final t in ['Index', 'Review', 'Memorize', 'Mark', 'Recitation', 'More']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
    expect(find.text('Tap a circle to start; hold it for options'), findsOneWidget);
    await fan(tester);
    expect(find.byTooltip('Index'), findsOneWidget, reason: 'in the row, not the fan');
    for (final t in ['View', 'Arabic script: New Madani', 'Theme', 'Zoom',
        'Export', 'History', 'Settings']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
    expect(s.toolHintSeen, isTrue, reason: 'a circle used');
    await tester.tapAt(const Offset(215, 200));
    await tester.pumpAndSettle();
    expect(find.byTooltip('View'), findsNothing, reason: 'the fan folded');
    expect(find.textContaining('25'), findsWidgets);
    expect(find.text('Ad-Dukhan'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'the home has nothing to close');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('the script and (on its side) the pages: a tap each',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await fan(tester);
    expect(find.byTooltip('Two pages'), findsNothing, reason: 'portrait: no pages button');
    await tester.tap(find.byTooltip('Arabic script: New Madani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indo-Pak').first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.mushafScript, 'indopak');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }

    tester.view.physicalSize = const Size(914, 412);
    await tester.pump();
    Future<void> tapPages(String now) async {
      await fan(tester);
      await tester.tap(find.byTooltip(now));
      await tester.pump();
    }

    await tapPages('Two pages');
    expect(s.hifzLandscapePages, 'one');
    await tapPages('One page');
    expect(s.hifzLandscapePages, 'two');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('mark: a tap starts at once (no sheet); its comment opens a '
      'word\'s bubble', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('Undo'), findsOneWidget, reason: 'the marking bar');
    await tester.tap(find.byTooltip('Comment'));
    await tester.pump();
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pumpAndSettle();
    expect(find.byType(WordMarksPanel), findsOneWidget);
  });

  testWidgets('eraser: a tap wipes the word\'s marks; Undo brings them back',
      (tester) async {
    final (s, p, m) = await boot();
    final b = m.ensureActiveBook('Me');
    m.addMark(b.id, _ref, MarkType.mistake);
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pump();
    expect(m.marksAt(b.id, _ref), isEmpty);
    await tester.pump(const Duration(milliseconds: 600)); // the snackbar in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(m.marksAt(b.id, _ref), hasLength(1));
    await m.flush();
  });

  testWidgets('audio: a tap plays the word', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Recitation'));
    await tester.pump();
    await tester.tapAt(wordAt(tester, _ref));
    await tester.pump();
    final playing = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .any((r) => r.spec.playAyah == _ref.globalAyah && r.spec.playWord == _ref.word0);
    expect(playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30)); // the word audio's timeout
  });

  testWidgets('memorize: the page hides; its bar, and no thumb pad even when set',
      (tester) async {
    final (s, p, m) = await boot();
    s.memorizeTap = 'pad';
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Memorize'));
    await tester.pump();
    expect(find.byType(MemorizeBar), findsOneWidget);
    expect(find.byType(MemorizePad), findsNothing);
    final hidden = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .any((r) => r.spec.hideFrom >= 0);
    expect(hidden, isTrue);
  });

  testWidgets('view: script, colouring (Nabr not yet), brightness', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await fan(tester);
    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    expect(find.text('Colouring'), findsOneWidget);
    await tester.tap(find.text('Tajwīd').last);
    await tester.pump();
    expect(s.mushafTajwid, isTrue);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await fan(tester);
    await tester.tap(find.byTooltip('Dark'));
    await tester.pumpAndSettle();
    expect(s.appTheme, 'night');
    await tester.tap(find.byTooltip('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OLED'));
    await tester.pump();
    expect(s.appTheme, 'oled');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('the header\'s page opens its list there; a pick goes to it',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    final page = MushafRepo.pageOfWord('uthmani', _ref.globalAyah, _ref.word0);
    await tester.tap(find.text('$page').first);
    await tester.pumpAndSettle();
    expect(find.text('Page $page'), findsOneWidget, reason: 'opened on the current page');
    await tester.tap(find.text('Page ${page + 2}'));
    await tester.pumpAndSettle();
    expect(find.text('${page + 2}'), findsWidgets);
  });

  testWidgets('landscape: the index comes in from the side', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<AdaptiveSheet>(find.byType(AdaptiveSheet));
    expect(sheet.side, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('landscape, camera on the right: the index comes from the left',
      (tester) async {
    addTearDown(() => displayRotationChanges.value = -1);
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    expect(tester.getTopRight(find.byType(AdaptiveSheet)).dx, 1200, reason: 'the other way round: the right');
    await tester.tapAt(const Offset(20, 350));
    await tester.pumpAndSettle();

    displayRotationChanges.value = 3;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AdaptiveSheet)).dx, 0);
  });

  // The pages either side are built too, each with its line above it.
  final sw = find.byType(ReaderViewSwitch).hitTestable();
  double juzLeft(WidgetTester t) => t.getTopLeft(find.textContaining('Juzʼ').hitTestable().first).dx;
  double juzRight(WidgetTester t) => t.getTopRight(find.textContaining('Juzʼ').hitTestable().first).dx;

  testWidgets('the switch to the Verses view: in the line above the page, down '
      'the side in landscape, gone under a tool\'s bar', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    expect(tester.widget<ReaderViewSwitch>(sw.first).axis, Axis.horizontal);
    final r = tester.getRect(sw.first);
    expect(r.center.dy, lessThan(120));
    expect(r.left, greaterThan(215), reason: 'past the page number, in the middle');
    expect(r.right, lessThanOrEqualTo(juzLeft(tester)), reason: 'before the juzʼ');

    tester.view.physicalSize = const Size(914, 412);
    await tester.pumpAndSettle();
    expect(tester.widget<ReaderViewSwitch>(sw.first).axis, Axis.vertical);

    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderViewSwitch), findsOneWidget,
        reason: 'still there with the marking bar: it takes the mode along');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('the line above the page keeps its place: the juzʼ at the right, '
      'with the switch or a tool\'s bar', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    final right = juzRight(tester);
    expect(right, greaterThan(380));
    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderViewSwitch), findsOneWidget);
    expect(juzRight(tester), right);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('immersive, on end: the switch up in the empty band; without one, '
      'in the line', (tester) async {
    final (s, p, m) = await boot();
    s.immersive = true;
    await pump(tester, s, p, m);
    final right = juzRight(tester);
    expect(tester.getRect(sw.first).right, lessThanOrEqualTo(juzLeft(tester)),
        reason: 'no band: in the line');

    tester.view.padding = const FakeViewPadding(top: 46);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    final r = tester.getRect(sw.first);
    expect(r.bottom, lessThanOrEqualTo(46));
    expect(r.right, greaterThan(400), reason: 'the corner');
    expect(juzRight(tester), right);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('the switch opens the Verses view at the page', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Verses').hitTestable().first);
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(VersesView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('a sheet takes the window\'s shape as it turns, its content kept',
      (tester) async {
    addTearDown(() => displayRotationChanges.value = -1);
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    bool side() => tester.widget<AdaptiveSheet>(find.byType(AdaptiveSheet)).side;
    expect(side(), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'kahf');
    await tester.pump();

    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    expect(side(), isTrue);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getTopRight(find.byType(AdaptiveSheet)).dx, 1200);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'kahf',
        reason: 'the same sheet');

    // From one side straight to the other: the panel crosses over.
    displayRotationChanges.value = 3;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AdaptiveSheet)).dx, 0);

    tester.view.physicalSize = const Size(430, 930);
    await tester.pumpAndSettle();
    expect(side(), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'kahf');
  });

  testWidgets('a bottom sheet still drags away', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byType(BottomSheet));
    await tester.flingFrom(top + const Offset(200, 12), const Offset(0, 600), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveSheet), findsNothing);
  });

  testWidgets('Settings comes over the page, and follows the theme it changes',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await fan(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing, reason: 'not a page of its own');
    expect(find.byType(AdaptiveSheet), findsOneWidget);
    expect(find.byType(MushafPageScreen, skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('left in the Reader: opens there, at its last verse; back, the '
      'page it got to', (tester) async {
    final (s, p, m) = await boot();
    p.setLastRead(44, 25);
    p.setInVerses(true);
    await pump(tester, s, p, m);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    final v = tester.widget<VersesView>(find.byType(VersesView));
    expect((v.meta.n, v.startAyah), (44, 25));
    await tester.binding.handlePopRoute(); // (the Reader's back is the system's)
    await tester.pumpAndSettle();
    expect(find.byType(VersesView), findsNothing);
    expect(p.inVerses, isFalse, reason: 'backed out: the page next time');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('back from the Verses view, opened by its switch', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Verses').hitTestable().first);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(p.inVerses, isTrue);
    await tester.binding.handlePopRoute(); // (the Reader's back is the system's)
    await tester.pumpAndSettle();
    expect(find.byType(VersesView), findsNothing);
    expect(p.inVerses, isFalse);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('left on the page: opens on the page', (tester) async {
    final (s, p, m) = await boot();
    p.setLastRead(44, 25);
    await pump(tester, s, p, m);
    expect(find.byType(VersesView), findsNothing);
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('export: the range tapped on the muṣḥaf, a page and a page, and '
      'the sheet back as it was', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await fan(tester);
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    final here = int.parse(tester
        .widget<TextField>(find.widgetWithText(TextField, 'From page'))
        .controller!
        .text);
    await tester.ensureVisible(find.text('Pick on the muṣḥaf'));
    await tester.tap(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    expect(find.text('Tap the first page, swipe, tap the last'), findsOneWidget);
    expect(find.byType(AdaptiveSheet), findsNothing);
    final done = find.widgetWithText(TextButton, 'Done');
    expect(tester.widget<TextButton>(done).onPressed, isNull, reason: 'nothing chosen');

    await tester.tapAt(wordAt(tester, _ref));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('$here').hitTestable(), findsWidgets);
    // Swipe a page on (the pages run right to left), tap it.
    await tester.flingFrom(const Offset(100, 450), const Offset(320, 0), 1500);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(215, 450));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('$here – ${here + 1}'), findsOneWidget);

    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveSheet), findsOneWidget);
    String field(String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;
    expect((field('From page'), field('To page')), ('$here', '${here + 1}'));
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('export pick: cancelled, the sheet comes back unchanged',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await fan(tester);
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'To page'), '600');
    await tester.pump();
    await tester.ensureVisible(find.text('Pick on the muṣḥaf'));
    await tester.tap(find.text('Pick on the muṣḥaf'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'To page')).controller!.text,
        '600');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('a narrow phone: the five circles fit', (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final r = tester.getRect(find.byTooltip('Recitation'));
    expect(r.right, lessThanOrEqualTo(360));
  });

  testWidgets('the index searches by mark; a pick goes to the word once the '
      'sheet has gone', (tester) async {
    final (s, p, m) = await boot();
    final b = m.ensureActiveBook('Me');
    m.addMark(b.id, _ref, MarkType.mistake);
    await pump(tester, s, p, m);
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Mistake'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mistake · Ad-Dukhan 44:25'), findsOneWidget);
    expect(find.byType(WordsLine), findsOneWidget);
    await tester.tap(find.textContaining('Mistake · Ad-Dukhan 44:25'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsNothing);
    await m.flush();
  });

  testWidgets('mark, held: fluency marks; the next tap starts them again',
      (tester) async {
    final (s, p, m) = await boot();
    await pump(tester, s, p, m);
    await tester.longPress(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.text('Recitation marks'), findsOneWidget);
    // One kind: a tap steps a word through not fluent, pair, chunk.
    expect(find.text('Not fluent'), findsNothing);
    await tester.tap(find.text('Fluency marks'));
    await tester.pumpAndSettle();
    expect(find.byType(FluencyBar), findsOneWidget);
    expect(s.markKind, 'fluency');
    expect(find.byTooltip('Mark'), findsNothing, reason: 'its bar in the circles\' place');
    await tester.tap(find.descendant(
        of: find.byType(FluencyBar), matching: find.byIcon(AppIcons.check)));
    await tester.pumpAndSettle();
    expect(find.byType(FluencyBar), findsNothing);
    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.byType(FluencyBar), findsOneWidget, reason: 'remembered');
    await tester.pump(const Duration(milliseconds: 500)); // the save
  });

  testWidgets('review: a tap starts at once on the page; held, how',
      (tester) async {
    final (s, p, m) = await boot();
    final b = m.ensureActiveBook('Me');
    m.addMark(b.id, _ref, MarkType.mistake);
    await pump(tester, s, p, m);
    await tester.longPress(find.byTooltip('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Verse cards'), findsOneWidget);
    for (final t in ['Memorization marks', 'Fluency marks', 'All marks']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Review'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing, reason: 'no setup sheet');
    expect(find.byType(ReviewBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    await m.flush();
  });

  test('search: by letters, whatever the vowels', () {
    final hits = searchMushaf('uthmani', 'الرحمن الرحيم');
    expect(hits.first.surah, 1);
    expect(hits.any((h) => h.surah == 1 && h.ayahInSurah == 3), isTrue);
    expect(searchMushaf('uthmani', 'قُلْ هُوَ اللَّهُ أَحَدٌ').single.surah, 112);
    expect(bareArabic('ٱلْحَمْدُ'), 'الحمد');
    // The words a match covers.
    final h = searchMushaf('uthmani', 'ملك يوم').firstWhere((h) => h.surah == 1);
    expect((h.firstWord, h.lastWord), (0, 1));
  });
}
