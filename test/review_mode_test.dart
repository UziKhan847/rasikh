import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/review_bar.dart';
import 'package:rasikh/screens/marks/review_cards_screen.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf/verse_view.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// Review mode: the reviewed word is in focus (outlined, drawn from the
/// glyph atlas like every word), any word plays when tapped and is never
/// marked, fixing moves on, and the arrows turn the pages.
const _a = WordRef(2, 255, 3);
const _b = WordRef(2, 255, 8);
const _c = WordRef(3, 2, 1); // a few pages on

Future<(AppSettings, ProgressStore, MarksStore, String)> _boot(
    {bool desktop = false}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.desktopMode = desktop ? 'on' : 'off';
  if (desktop) s.mushafView = 'spread';
  final m = MarksStore(
      persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
  await m.load();
  final b = m.ensureActiveBook('Me').id;
  m.addMark(b, _a, MarkType.mistake);
  m.addMark(b, _b, MarkType.doubt);
  m.addMark(b, _c, MarkType.mistake);
  return (s, p, m, b);
}

int _page(WordRef r) => MushafRepo.pageOfWord('uthmani', r.globalAyah, r.word0);

Widget _app(AppSettings s, ProgressStore p, MarksStore m, Widget home) =>
    MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: home,
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Every laid-out line on screen.
List<RenderMushafLine> _lines(WidgetTester tester) => [
      for (final el in find.byType(MushafLineView).evaluate())
        if ((el.renderObject! as RenderMushafLine).laidLine != null)
          el.renderObject! as RenderMushafLine,
    ];

/// The line holding the word in focus, and that word's index on it.
(RenderMushafLine, int)? _focused(WidgetTester tester, WordRef w) {
  for (final r in _lines(tester)) {
    final words = r.spec.line.words;
    for (var i = 0; i < words.length; i++) {
      final wd = words[i];
      if (!wd.isMarker && wd.ayah == w.globalAyah && wd.wordIdx == w.word0) {
        if (r.spec.focus == w.key) return (r, i);
      }
    }
  }
  return null;
}

Offset _at(RenderMushafLine r, int token) {
  final (left, right) = r.laidLine!.boxes[token];
  return r.localToGlobal(
      r.textOffset + Offset((left + right) / 2, r.laidLine!.height / 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  testWidgets('the muṣḥaf opens on the reviewed word, outlined in the atlas',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot();
    final c = ReviewController.start(m, b, const ReviewQuery());
    await tester.pumpWidget(_app(s, p, m,
        MushafPageScreen(startPage: _page(_a), script: 'uthmani', review: c)));
    await _settle(tester);

    expect(find.byType(ReviewBar), findsOneWidget);
    final hit = _focused(tester, _a);
    expect(hit, isNotNull, reason: 'the reviewed word is in focus');
    final (line, i) = hit!;
    final laid = line.laidLine!;
    expect(laid, isA<AtlasLine>(), reason: 'drawn from the glyph atlas');
    expect(laid.focusBoxes, [laid.boxes[i]]);
    // Only the line with the focused word carries it.
    expect(_lines(tester).where((r) => r.laidLine!.focusBoxes.isNotEmpty),
        hasLength(1));

    // A tap on another word plays it — and marks nothing.
    final marksBefore = m.marksOf(b).length;
    final other = line.spec.line.words
        .indexWhere((w) => !w.isMarker && w.wordIdx != _a.word0);
    await tester.tapAt(_at(line, other));
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.marksOf(b).length, marksBefore);
    expect(
        _lines(tester).any((r) =>
            r.spec.playWord == line.spec.line.words[other].wordIdx &&
            r.spec.playAyah == line.spec.line.words[other].ayah),
        isTrue,
        reason: 'the tapped word is the one playing');

    // Fixed: the mark is fixed in the review session, focus moves on.
    final first = c.current!;
    await tester.tap(find.text('Mark fixed'));
    await _settle(tester);
    expect(m.isFixed(first), isTrue);
    expect(m.fixOf(first)!.sessionId, c.sessionId);
    expect(c.current!.ref, _b);
    expect(_focused(tester, _b), isNotNull);
    expect(_focused(tester, _a), isNull);

    // End: no summary to dismiss — the session closes, kept in History.
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved to History'), findsOneWidget);
    expect(find.byType(ReviewBar), findsNothing);
    expect(m.session(b, c.sessionId!)!.endedAt, isNotNull);
    await tester.pumpWidget(const SizedBox());
    // Past the word audio's fetch timeouts (a tap played a word).
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('on the desktop spread the arrows turn to the next mark',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot(desktop: true);
    final c = ReviewController.start(
        m, b, const ReviewQuery(types: {MarkType.mistake}));
    await tester.pumpWidget(_app(s, p, m,
        MushafPageScreen(startPage: _page(_a), script: 'uthmani', review: c)));
    await _settle(tester);
    expect(_focused(tester, _a), isNotNull);

    await tester.tap(find.byTooltip('Next'));
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(c.current!.ref, _c);
    expect(p.lastMushafPage, anyOf(_page(_c), _page(_c) - 1));
    expect(_focused(tester, _c), isNotNull);

    await tester.tap(find.byTooltip('Previous'));
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(_focused(tester, _a), isNotNull);
    c.end();
    await tester.pumpWidget(const SizedBox());
    // Past the word audio's fetch timeouts (a tap played a word).
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('verse cards: the āyah from the atlas, tap plays, fixed moves on',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot();
    final c = ReviewController.start(m, b, const ReviewQuery());
    await tester.pumpWidget(_app(
        s, p, m, ReviewCardsScreen(controller: c, script: 'uthmani')));
    await _settle(tester);

    expect(find.byType(VerseView), findsWidgets);
    final hit = _focused(tester, _a);
    expect(hit, isNotNull);
    final (line, i) = hit!;
    expect(line.laidLine, isA<AtlasLine>());
    expect(line.laidLine!.focusBoxes, [line.laidLine!.boxes[i]]);

    // Every word of the card is there, wrapped over rows: Āyat al-Kursī's.
    final words = {
      for (final r in _lines(tester))
        for (final w in r.spec.line.words)
          if (w.ayah == _a.globalAyah && !w.isMarker) w.wordIdx,
    };
    expect(words.length, MushafRepo.wordCount('uthmani', _a.globalAyah));

    final before = m.marksOf(b).length;
    await tester.tapAt(_at(line, i));
    await tester.pump(const Duration(milliseconds: 300));
    expect(m.marksOf(b).length, before);

    final first = c.current!;
    await tester.tap(find.text('Mark fixed'));
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(m.isFixed(first), isTrue);
    expect(c.index, 1);
    expect(_focused(tester, _b), isNotNull);
    await tester.pumpWidget(const SizedBox());
    // Past the word audio's fetch timeouts (a tap played a word).
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('closing the muṣḥaf mid-review rebuilds nothing mid-teardown',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot();
    final c = ReviewController.start(m, b, const ReviewQuery());
    // A screen below that listens to the marks (as the Hifz screen does).
    await tester.pumpWidget(_app(
        s,
        p,
        m,
        Builder(
          builder: (context) => ListenableBuilder(
            listenable: m,
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MushafPageScreen(
                        startPage: _page(_a), script: 'uthmani', review: c))),
                child: Text('${m.sessionsOf(b).length} sessions'),
              ),
            ),
          ),
        )));
    await tester.tap(find.byType(TextButton));
    await _settle(tester);
    expect(find.byType(ReviewBar), findsOneWidget);
    Navigator.of(tester.element(find.byType(MushafPageScreen))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(m.session(b, c.sessionId!)!.endedAt, isNotNull,
        reason: 'the review session still closes');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('the review bar recites the āyah', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot();
    final c = ReviewController.start(m, b, const ReviewQuery());
    await tester.pumpWidget(_app(s, p, m,
        MushafPageScreen(startPage: _page(_a), script: 'uthmani', review: c)));
    await _settle(tester);
    expect(find.byTooltip('Ḥuṣarī recites the āyah'), findsOneWidget);
    c.end();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('desktop cards: the word always below, Space and Backspace step, '
      'the audio bar', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot(desktop: true);
    s.reviewCardWord = false;
    final c = ReviewController.start(m, b, const ReviewQuery());
    await tester.pumpWidget(
      _app(s, p, m, ReviewCardsScreen(controller: c, script: 'uthmani')),
    );
    await _settle(tester);

    // The marked word, large, though "show the word" is off.
    expect(
      find.text(MushafRepo.wordText('uthmani', _a.globalAyah, _a.word0)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-audio')), findsOneWidget);
    final stop = tester.widget<IconButton>(
      find.byKey(const ValueKey('audio-stop')),
    );
    expect(stop.onPressed, isNull, reason: 'nothing playing yet');
    final pause = tester.widget<IconButton>(
      find.byKey(const ValueKey('audio-pause')),
    );
    expect(pause.onPressed, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(c.current!.ref, _b);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(c.current!.ref, _a);

    // A word played: stop can stop it.
    await tester.tap(find.byKey(const ValueKey('audio-word')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('audio-stop')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('audio-stop')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('audio-stop')))
          .onPressed,
      isNull,
    );
    c.end();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('phone cards: no audio bar, the word only when asked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p, m, b) = await _boot();
    s.reviewCardWord = false;
    final c = ReviewController.start(m, b, const ReviewQuery());
    await tester.pumpWidget(
      _app(s, p, m, ReviewCardsScreen(controller: c, script: 'uthmani')),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('review-audio')), findsNothing);
    expect(
      find.text(MushafRepo.wordText('uthmani', _a.globalAyah, _a.word0)),
      findsNothing,
    );
    c.end();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
