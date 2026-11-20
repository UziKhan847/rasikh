import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart' show InputDevice;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/follow/follow_model.dart';
import 'package:rasikh/core/follow/follow_session.dart';
import 'package:rasikh/core/follow/linux_mic.dart';
import 'package:rasikh/core/follow/follow_worker.dart' show FollowHeard;
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/follow/follow_ui.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/reader/reader_host.dart' show VersesView;

import 'test_support.dart';

/// A stand-in for the mic and the model: what it's told, and events sent as
/// if heard.
class FakeEngine implements FollowEngine {
  final events_ = StreamController<(String, int)>.broadcast();
  final heard_ = StreamController<FollowHeard>.broadcast();
  final levels_ = StreamController<double>.broadcast();
  @override
  Stream<double> get levels => levels_.stream;
  final positions = <int>[];
  bool listening = false, disposed = false;
  bool micAllowed = true;

  @override
  Stream<(String, int)> get events => events_.stream;
  @override
  Stream<FollowHeard> get heard => heard_.stream;

  @override
  Future<bool> start(int fromWord) async {
    positions.add(fromWord);
    listening = micAllowed;
    return micAllowed;
  }

  @override
  void setPosition(int word) => positions.add(word);

  final views = <List<(int, int)>>[];
  @override
  void setView(List<(int, int)> ranges) => views.add(ranges);

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    listening = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  /// A model folder as check() wants it (the model only its size).
  void fakeModel(String dir, FollowTier t) {
    Directory(dir).createSync(recursive: true);
    final m = File('$dir/${FollowModel.model}').openSync(mode: FileMode.write);
    m.truncateSync(FollowModel.files[t]!.first.bytes);
    m.closeSync();
    File('$dir/${FollowModel.tokens}').writeAsStringSync([
      for (final (i, c) in ['<blk>', ...FollowModel.vocabulary.substring(5).split('')].indexed) '$c $i',
    ].join('\n'));
    File('$dir/${FollowModel.vad}').writeAsBytesSync([0]);
  }

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    tmp = Directory.systemTemp.createTempSync('rasikh_follow');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  tearDown(() {
    FollowModel.debugRoot = null;
    FollowModel.debugFiles = null;
    FollowModel.client = http.Client.new;
    FollowSession.debugEngine = null;
  });

  group('the model\'s files', () {
    test('a folder is the model only with all three files and its vocabulary', () {
      final high = '${tmp.path}/m_high', low = '${tmp.path}/m_low';
      fakeModel(high, FollowTier.high);
      fakeModel(low, FollowTier.low);
      expect(FollowModel.check(high), FollowTier.high);
      expect(FollowModel.check(low), FollowTier.low);
      File('$low/${FollowModel.tokens}').writeAsStringSync('<blk> 0\na 1\n');
      expect(FollowModel.check(low), isNull, reason: 'another model\'s tokens');
      File('$high/${FollowModel.vad}').deleteSync();
      expect(FollowModel.check(high), isNull);
      if (Directory('assets/follow/high').existsSync()) {
        expect(FollowModel.check('assets/follow/high'), FollowTier.high);
        expect(FollowModel.check('assets/follow/low'), FollowTier.low);
      }
    });

    test('downloaded: resumed where it stopped, checked, and a damaged file '
        'thrown away', () async {
      final a = utf8.encode('the model, its bytes' * 40);
      final b = utf8.encode('tokens');
      String sha(List<int> d) => sha256.convert(d).toString();
      FollowModel.debugRoot = '${tmp.path}/dl';
      FollowModel.debugFiles = {
        FollowTier.low: [
          FollowFile('model.int8.onnx', 'https://x/a', sha(a), a.length),
          FollowFile('tokens.txt', 'https://x/b', sha(b), b.length),
        ],
        FollowTier.high: const [],
      };
      final ranges = <String?>[];
      FollowModel.client = () => MockClient.streaming((req, _) async {
            ranges.add(req.headers['Range']);
            final data = req.url.path == '/a' ? a : b;
            final r = req.headers['Range'];
            if (r != null) {
              final from = int.parse(r.substring(6, r.length - 1));
              return http.StreamedResponse(Stream.value(data.sublist(from)), 206);
            }
            return http.StreamedResponse(Stream.value(data), 200);
          });
      // Half the model, from a try before.
      final dir = '${tmp.path}/dl/low';
      Directory(dir).createSync(recursive: true);
      File('$dir/model.int8.onnx.part').writeAsBytesSync(a.sublist(0, 300));
      final seen = <int>[];
      await FollowModel.download(FollowTier.low, onProgress: (d, _) => seen.add(d));
      expect(ranges.first, 'bytes=300-', reason: 'on from where it stopped');
      expect(File('$dir/model.int8.onnx').readAsBytesSync(), a);
      expect(File('$dir/tokens.txt').readAsBytesSync(), b);
      expect(seen.last, a.length + b.length);

      // A file that isn't what it should be: thrown away, said.
      File('$dir/tokens.txt').deleteSync();
      FollowModel.client = () => MockClient((_) async => http.Response('nope!!', 200));
      await expectLater(FollowModel.download(FollowTier.low), throwsA(isA<FollowBadFile>()));
      expect(File('$dir/tokens.txt').existsSync(), isFalse);
      expect(File('$dir/tokens.txt.part').existsSync(), isFalse);
    });
  });

  group('on the muṣḥaf', () {
    late FakeEngine engine;

    Future<(AppSettings, ProgressStore)> home(WidgetTester tester, {bool warned = false}) async {
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
        ..desktopMode = 'on'
        ..followWarned = warned;
      FollowModel.debugRoot = '${tmp.path}/app';
      fakeModel('${tmp.path}/app/low', FollowTier.low);
      engine = FakeEngine();
      FollowSession.debugEngine = (_, _) async => engine;
      final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
      await m.load();
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
              home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
            ),
          ),
        ),
      ));
      await settle(tester);
      return (s, p);
    }

    final followButton = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Follow my recitation'));

    Future<void> close(WidgetTester tester) async {
      await tester.runAsync(() => FollowSession.instance.stop());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('the first time, what it does and doesn\'t; then it listens from '
        'the page, saying always that it judges neither mistakes nor tajwīd', (tester) async {
      final (s, _) = await home(tester);
      await tester.tap(followButton.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('follow-warning')), findsOneWidget);
      expect(find.textContaining('does not detect mistakes, nor tajwīd'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('follow-understood')));
      await settle(tester);
      expect(s.followWarned, isTrue);
      expect(FollowSession.instance.status.value, FollowStatus.listening);
      final words = FollowSession.instance.words!;
      // (A desktop spread: 49|50, from 49's first word.)
      final (first, _) = MushafRepo.pageTokens('uthmani', 49);
      final (g, w) = MushafRepo.tokenAt('uthmani', first);
      expect(engine.positions.first, words.indexOf(g, w), reason: 'from the spread\'s first word');
      expect(find.byKey(const ValueKey('follow-caption')), findsOneWidget);
      expect(find.text("Doesn't detect mistakes or tajwīd"), findsOneWidget);
      await close(tester);
    });

    testWidgets('a word heard is lit; the page\'s last word turns it; Done stops '
        'it all', (tester) async {
      final (_, p) = await home(tester, warned: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(find.byKey(const ValueKey('follow-warning')), findsNothing, reason: 'read before');
      expect(FollowSession.instance.status.value, FollowStatus.listening);
      final words = FollowSession.instance.words!;
      // A few words in.
      final (first, end) = MushafRepo.pageTokens('uthmani', 50);
      final (g0, w0) = MushafRepo.tokenAt('uthmani', first);
      engine.events_.add(('progress', words.indexOf(g0, w0) + 3));
      await settle(tester);
      expect(FollowSession.instance.place, (words.ayahOf[words.indexOf(g0, w0) + 3],
          words.word0Of[words.indexOf(g0, w0) + 3]));
      expect(p.lastMushafPage, 50, reason: 'still on its page');

      // The page's last word: on to the next.
      var last = end - 1;
      while (MushafRepo.tokenAt('uthmani', last).$2 < 0) {
        last--;
      }
      final (gl, wl) = MushafRepo.tokenAt('uthmani', last);
      engine.events_.add(('progress', words.indexOf(gl, wl)));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(p.lastMushafPage, anyOf(51, 52), reason: 'turned on');

      await tester.tap(find.byKey(const ValueKey('follow-done')));
      await settle(tester);
      expect(FollowSession.instance.active, isFalse);
      expect(engine.disposed, isTrue);
      expect(find.byKey(const ValueKey('follow-caption')), findsNothing);
      await close(tester);
    });

    testWidgets('started elsewhere: the page goes there, and says where', (tester) async {
      final (_, p) = await home(tester, warned: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      final words = FollowSession.instance.words!;
      final g = MushafRepo.globalAyahOf(18, 60);
      engine.events_.add(('jump', words.indexOf(g, 2)));
      await settle(tester);
      await tester.pumpAndSettle();
      final pg = MushafRepo.pageForGlobalAyah('uthmani', g);
      expect(p.lastMushafPage, anyOf(pg, pg - 1), reason: 'its spread');
      expect(find.text('Found you at 18:60'), findsOneWidget);
      // Lost a while: said so; heard again: listening.
      engine.events_.add(('lost', -1));
      await tester.pump(const Duration(seconds: 2));
      expect(FollowSession.instance.status.value, FollowStatus.searching);
      engine.events_.add(('progress', words.indexOf(g, 4)));
      await tester.pump();
      expect(FollowSession.instance.status.value, FollowStatus.listening);
      await close(tester);
    });

    testWidgets('into the Verses view and back: still following, the same session',
        (tester) async {
      await home(tester, warned: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      await tester.tap(find.byTooltip('Verses').hitTestable().first);
      await settle(tester);
      expect(find.byType(VersesView), findsOneWidget);
      expect(FollowSession.instance.active, isTrue, reason: 'not stopped by the switch');
      expect(engine.disposed, isFalse);
      expect(find.byKey(const ValueKey('follow-caption')).hitTestable(), findsOneWidget,
          reason: 'its bar in the verses, the warning with it');
      // A word heard there: the verses keep up.
      final words = FollowSession.instance.words!;
      final g = MushafRepo.globalAyahOf(3, 20);
      engine.events_.add(('progress', words.indexOf(g, 1)));
      await settle(tester);
      expect(FollowSession.instance.place, (g, 1));
      // Back to the page: following there.
      await tester.tap(find.byTooltip('Page').hitTestable().first);
      await settle(tester);
      expect(find.byType(VersesView), findsNothing);
      expect(FollowSession.instance.active, isTrue);
      expect(find.byKey(const ValueKey('follow-caption')).hitTestable(), findsOneWidget);
      await close(tester);
    });

    testWidgets('it shows it hears: the level moves; nothing at all for a while '
        'says so, with the microphones a tap away; a sound clears it', (tester) async {
      await home(tester, warned: true);
      final prev = listFollowMics;
      listFollowMics = () async => const [
            InputDevice(id: 'headset', label: 'Headset microphone'),
            InputDevice(id: 'builtin', label: 'Built-in microphone'),
            InputDevice(id: 'speakers.monitor', label: 'Monitor of speakers'),
          ];
      addTearDown(() => listFollowMics = prev);
      LinuxMic.debugMuted = {null: false, 'headset': false, 'builtin': true};
      addTearDown(() => LinuxMic.debugMuted = null);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      final session = FollowSession.instance;
      expect(find.byKey(const ValueKey('follow-level')), findsOneWidget);
      engine.levels_.add(.2);
      await tester.pump();
      expect(session.level.value, .2);
      expect(find.byKey(const ValueKey('follow-mic-problem')), findsNothing);

      // Silence (a muted or unplugged input): said within a few seconds.
      for (var i = 0; i < 8; i++) {
        engine.levels_.add(0);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(session.micProblem.value, 'silent');
      expect(find.text('No sound from the microphone'), findsOneWidget);
      expect(find.byKey(const ValueKey('follow-caption')), findsOneWidget,
          reason: 'the warning stays, whatever else is said');

      // The microphones: the system's first, a speaker's monitor left out.
      await tester.tap(find.byKey(const ValueKey('follow-mic-button')));
      await settle(tester);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('Built-in microphone'), findsOneWidget);
      expect(find.text('Monitor of speakers'), findsNothing);
      // Muted in the system: said, and undone here.
      expect(find.text('Muted in the system'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unmute-builtin')));
      await settle(tester);
      expect(LinuxMic.debugMuted!['builtin'], isFalse);
      expect(find.text('Muted in the system'), findsNothing);
      final before = engine.positions.length;
      await tester.tap(find.byKey(const ValueKey('mic-builtin')));
      await settle(tester);
      final s = SettingsScope.of(tester.element(find.byType(MushafPageScreen)));
      expect(s.followMic, 'builtin');
      expect(session.micId, 'builtin');
      expect(engine.positions.length, greaterThan(before), reason: 'listening again, with it');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // A voice: the warning goes.
      engine.levels_.add(.3);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(session.micProblem.value, isNull);
      await close(tester);
    });

    testWidgets('memorizing, Reveal as I recite: each word heard shows; a jump far '
        'on reveals nothing', (tester) async {
      await home(tester, warned: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN); // memorize
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('memo-listen')).first);
      await settle(tester);
      final fs = FollowSession.instance;
      expect(fs.status.value, FollowStatus.listening);
      expect(find.byKey(const ValueKey('follow-strip')), findsOneWidget);
      expect(find.textContaining("Doesn't detect mistakes or tajwīd"), findsOneWidget);
      final words = fs.words!;
      final start = engine.positions.first;
      final (g0, w0) = (words.ayahOf[start], words.word0Of[start]);
      final t0 = MushafRepo.tokenOf('uthmani', g0, w0);
      // Nothing of it shows yet.
      final m = tester.state<State<MushafPageScreen>>(find.byType(MushafPageScreen));
      int revealed() => (m as dynamic).debugMemoEnd as int;
      expect(revealed(), t0);
      // Two words heard: they show.
      engine.events_.add(('progress', start + 1));
      await settle(tester);
      expect(revealed(), greaterThanOrEqualTo(t0 + 2));
      final before = revealed();
      // A jump far on: nothing more shows; it's told where they are.
      final n = engine.positions.length;
      engine.events_.add(('jump', start + 200));
      await settle(tester);
      expect(revealed(), before);
      expect(engine.positions.length, n + 1, reason: 're-anchored');
      // Off.
      await tester.tap(find.byKey(const ValueKey('memo-listen')).first);
      await settle(tester);
      expect(fs.active, isFalse);
      await close(tester);
    });

    testWidgets('memorizing, the Follow key reveals what\'s recited (memorizing goes '
        'on); revealing by hand moves where it listens from; the page in view '
        'is told first', (tester) async {
      await home(tester, warned: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN); // memorize
      await settle(tester);
      final m = tester.state<State<MushafPageScreen>>(find.byType(MushafPageScreen));
      int revealed() => (m as dynamic).debugMemoEnd as int;
      final t0 = revealed();
      expect(t0, greaterThanOrEqualTo(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV); // Follow
      await settle(tester);
      final fs = FollowSession.instance;
      expect(fs.status.value, FollowStatus.listening);
      expect(revealed(), t0, reason: 'still memorizing, nothing shown yet');
      // The page being memorized first, the reveal point on.
      final words = fs.words!;
      expect(engine.views, isNotEmpty);
      final (g0, w0) = MushafRepo.tokenAt('uthmani', t0);
      expect(engine.views.last.first.$1, words.indexOf(g0, w0 < 0 ? 0 : w0));
      // A word heard: shown.
      engine.events_.add(('progress', engine.positions.first + 1));
      await settle(tester);
      expect(revealed(), greaterThan(t0));
      // A verse revealed by hand: they'll recite on from after it.
      final n = engine.positions.length;
      final before = revealed();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space); // the rest of the āyah
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(revealed(), greaterThan(before));
      expect(engine.positions.length, greaterThan(n), reason: 're-placed after a reveal by hand');
      var next = revealed();
      while (MushafRepo.tokenAt('uthmani', next).$2 < 0) {
        next++;
      }
      final (g, w) = MushafRepo.tokenAt('uthmani', next);
      expect(engine.positions.last, words.indexOf(g, w));
      // V again: off, still memorizing.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(fs.active, isFalse);
      expect(revealed(), greaterThan(t0));
      await close(tester);
    });

    testWidgets('the microphone refused: said, and the tool goes off', (tester) async {
      await home(tester, warned: true);
      engine.micAllowed = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(FollowSession.instance.active, isFalse);
      expect(find.textContaining("can't use the microphone"), findsOneWidget);
      expect(find.byKey(const ValueKey('follow-caption')), findsNothing);
      await close(tester);
    });

    testWidgets('no model: the prompt, High and Low with sizes, one recommended', (tester) async {
      await home(tester, warned: true);
      File('${tmp.path}/app/low/${FollowModel.model}').deleteSync();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(find.text("The listening model isn't on this device"), findsOneWidget);
      expect(find.text('37 MB'), findsOneWidget);
      expect(find.text('19 MB'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('Recommended'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(FollowSession.instance.active, isFalse);
      await close(tester);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}
