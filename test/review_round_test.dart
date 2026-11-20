import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/follow/follow_model.dart';
import 'package:rasikh/core/follow/follow_session.dart';
import 'package:rasikh/core/follow/follow_worker.dart' show FollowHeard;
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/divisions.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/pages_pdf.dart';
import 'package:rasikh/screens/mushaf/edition_picker.dart';
import 'package:rasikh/data/original/mushaf_packs.dart';

/// The fixes of the review round: Follow paused when the app goes away,
/// recordings kept within bounds, a span highlighted whole in the export,
/// the review count within its filter, a mark stretched by touch, the notes
/// beside an exported page fitting it, the printed muṣḥafs on a phone.
class _Engine implements FollowEngine {
  final positions = <int>[];
  bool listening = false;
  @override
  Stream<(String, int)> get events => const Stream.empty();
  @override
  Stream<FollowHeard> get heard => const Stream.empty();
  @override
  Stream<double> get levels => const Stream.empty();
  @override
  Future<bool> start(int fromWord) async {
    positions.add(fromWord);
    return listening = true;
  }

  @override
  void setPosition(int word) {}
  @override
  void setView(List<(int, int)> ranges) {}
  @override
  Future<void> stop() async => listening = false;
  @override
  Future<void> dispose() async => listening = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    MarksStore.ayahWords = (g) => MushafRepo.wordCount('uthmani', g);
    tmp = Directory.systemTemp.createTempSync('rasikh_round');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<(MarksStore, String)> store() async {
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (m, m.ensureActiveBook('Me').id);
  }

  test('the app away: following pauses, whoever started it; back: it listens again', () async {
    final engine = _Engine();
    FollowSession.debugEngine = (_, _) async => engine;
    addTearDown(() => FollowSession.debugEngine = null);
    final fs = FollowSession.instance;
    fs.owner = #verses;
    await fs.start((dir: '', tier: FollowTier.low), 0, 0);
    expect(fs.status.value, FollowStatus.listening);
    fs.debugLifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(fs.status.value, FollowStatus.paused);
    expect(engine.listening, isFalse, reason: 'the mic off');
    fs.debugLifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(fs.status.value, FollowStatus.listening);
    // Paused by hand: coming back doesn't turn it on.
    await fs.pause();
    fs.debugLifecycle(AppLifecycleState.paused);
    fs.debugLifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(fs.status.value, FollowStatus.paused);
    await fs.stop();
  });

  test('recordings for tuning: their size, deleted at a tap, the oldest going past the cap',
      () async {
    final dir = Directory('${tmp.path}/rec')..createSync();
    FollowRecordings.debugDir = dir.path;
    addTearDown(() => FollowRecordings.debugDir = null);
    // Over the cap: three files of 200 MB (sparse), named by time.
    for (final name in ['2026-01-01', '2026-01-02', '2026-01-03']) {
      final f = File('${dir.path}/$name.pcm').openSync(mode: FileMode.write);
      f.truncateSync(200 * 1024 * 1024);
      f.closeSync();
    }
    expect(await FollowRecordings.size(), 600 * 1024 * 1024);
    await FollowRecordings.prune();
    expect(File('${dir.path}/2026-01-01.pcm').existsSync(), isFalse, reason: 'the oldest');
    expect(await FollowRecordings.size(), lessThanOrEqualTo(FollowRecordings.cap));
    await FollowRecordings.deleteAll();
    expect(await FollowRecordings.size(), 0);
  });

  test('the page export: a mark over several words is highlighted on each', () async {
    final (m, b) = await store();
    m.addMark(b, const WordRef(2, 31, 2), MarkType.mistake, to: const WordRef(2, 31, 5));
    final e = PagesExport(store: m, bookId: b, script: 'uthmani', pages: [6]);
    for (var w = 2; w <= 5; w++) {
      expect(e.visuals[WordRef(2, 31, w).key]?.open, MarkType.mistake, reason: 'word $w');
    }
    expect(e.visuals[const WordRef(2, 31, 6).key], isNull);
  });

  test('the review count is within what the arrows step through', () async {
    final (m, b) = await store();
    m.addMark(b, const WordRef(2, 10, 1), MarkType.mistake);
    m.addMark(b, const WordRef(2, 20, 1), MarkType.tajwid);
    m.addMark(b, const WordRef(18, 60, 2), MarkType.mistake);
    m.addMark(b, const WordRef(36, 1, 1), MarkType.mistake);
    final c = ReviewController.start(m, b, const ReviewQuery(), session: false);
    expect((c.shownPosition, c.shownCount), (1, 4));
    c.setOnly(MarkType.mistake);
    expect(c.shownCount, 3);
    c.setWhere((Division.surah, 2));
    expect((c.shownPosition, c.shownCount), (1, 1), reason: 'mistakes in sūrah 2');
    c.setOnly(null);
    c.next();
    expect((c.shownPosition, c.shownCount), (2, 2));
  });

  test('a mark stretched by touch: on, back, and back to one word, each undoable', () async {
    final (m, b) = await store();
    m.addMark(b, const WordRef(2, 31, 3), MarkType.mistake);
    final mark = m.marksOf(b).single;
    final op = m.setSpanEnd(mark, const WordRef(2, 32, 1));
    expect((mark.ref, mark.to), (const WordRef(2, 31, 3), const WordRef(2, 32, 1)));
    expect(m.marksAt(b, const WordRef(2, 31, 7)), hasLength(1), reason: 'every word between');
    // Before its first word: that's its start now.
    m.setSpanEnd(mark, const WordRef(2, 31, 1));
    expect((mark.ref, mark.to), (const WordRef(2, 31, 1), const WordRef(2, 32, 1)));
    // Its own first word: one word again.
    m.setSpanEnd(mark, const WordRef(2, 31, 1));
    expect(mark.to, isNull);
    expect(op.isEmpty, isFalse, reason: 'undoable');
    expect(m.marksOf(b), hasLength(1), reason: 'the same mark throughout');
  });

  testWidgets('the notes beside an exported page fit it, however many', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final (m, b) = await store();
    const long = 'A long note on how this word was recited, and what to watch '
        'for next time, written out in full to see that it fits. ';
    for (var a = 31; a <= 37; a++) {
      for (var w = 1; w <= 3; w++) {
        m.addMark(b, WordRef(2, a, w), MarkType.mistake, comment: long * 2);
      }
    }
    late BuildContext ctx;
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
    final e = PagesExport(store: m, bookId: b, script: 'uthmani', pages: [6]);
    await tester.runAsync(() async {
      final sheet = (await preparePages(ctx, e, [6])).single;
      expect(sheet.notes.length, greaterThan(15));
      for (final side in [true, false]) {
        final boxes = [for (final n in sheet.notes) if (n.$2 == side) n.$3]
          ..sort((a, b) => a.top.compareTo(b.top));
        for (var i = 0; i < boxes.length; i++) {
          expect(boxes[i].top, greaterThanOrEqualTo(0));
          expect(boxes[i].bottom, lessThanOrEqualTo(842 - 40), reason: 'above the foot');
          if (i > 0) {
            expect(boxes[i].top, greaterThanOrEqualTo(boxes[i - 1].bottom), reason: 'none over another');
          }
        }
      }
    });
    await m.flush();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a phone: a printed muṣḥaf it can\'t get yet is greyed, saying so', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MushafPacks.dirs = {};
    SharedPreferences.setMockInitialValues({});
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: SettingsScope(
        settings: AppSettings(),
        child: Scaffold(body: MushafEditionPicker(value: 'uthmani', onChanged: picked.add)),
      ),
    ));
    expect(find.byKey(const ValueKey('edition-soon-$kOldMadani')), findsOneWidget);
    await tester.tap(find.text('Old Madani'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text("Old Madani isn't on this device"), findsNothing, reason: 'no dead-end prompt');
    debugDefaultTargetPlatformOverride = null;
  });
}
