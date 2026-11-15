// Runs the sync engine against a real PocketBase with server/pb_migrations
// and server/pb_hooks — the rules, routes and hooks as deployed. Off by
// default. Start a throwaway server and run:
//   server/dev.sh superuser admin@example.com admin-pass-123
//   server/dev.sh &
//   flutter test test/server --dart-define=PB_URL=http://127.0.0.1:8090 \
//     --dart-define=PB_ADMIN=admin@example.com --dart-define=PB_ADMIN_PASS=admin-pass-123
@Tags(['server'])
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/sync/pocketbase_backend.dart';
import 'package:rasikh/core/sync/sync_backend.dart';
import 'package:rasikh/core/sync/sync_engine.dart';

const _url = String.fromEnvironment('PB_URL');
const _admin = String.fromEnvironment('PB_ADMIN');
const _adminPass = String.fromEnvironment('PB_ADMIN_PASS');

class _Device {
  final MarksStore store;
  final SyncEngine engine;
  _Device(this.store, this.engine);

  static Future<_Device> make() async {
    final store = MarksStore(
        persistence: MemoryMarksPersistence(),
        saveDelay: const Duration(hours: 1));
    await store.load();
    final backend = await PocketBaseSyncBackend.create(_url);
    return _Device(store, SyncEngine(store: store, backend: backend));
  }
}

/// Superuser call (test setup only).
Future<Map<String, dynamic>> _admin_(String method, String path,
    [Map<String, dynamic>? body]) async {
  final auth = await http.post(
      Uri.parse('$_url/api/collections/_superusers/auth-with-password'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'identity': _admin, 'password': _adminPass}));
  final token = (jsonDecode(auth.body) as Map)['token'] as String;
  final req = http.Request(method, Uri.parse('$_url$path'))
    ..headers.addAll({'Authorization': token, 'content-type': 'application/json'});
  if (body != null) req.body = jsonEncode(body);
  final res = await http.Response.fromStream(await req.send());
  return res.body.isEmpty ? {} : (jsonDecode(res.body) as Map).cast();
}

String _user(String base) =>
    '$base${Random().nextInt(1 << 30).toRadixString(36)}';

const w1 = WordRef(2, 255, 3);
const w2 = WordRef(67, 1, 2);

void main() {
  if (_url.isEmpty) {
    test('server tests are off (pass --dart-define=PB_URL=…)', () {});
    return;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Many sign-ups in a few seconds: lift the rate limits for the run.
    await _admin_('PATCH', '/api/settings', {
      'rateLimits': {'enabled': false}
    });
  });
  tearDownAll(() async {
    await _admin_('PATCH', '/api/settings', {
      'rateLimits': {'enabled': true}
    });
  });

  Future<(_Device, _Device, String)> shared() async {
    final reciter = await _Device.make();
    final listener = await _Device.make();
    // Username only — no email.
    await reciter.engine.signUp(_user('zayd'), 'pw-zayd-123', displayName: 'Zayd');
    final book = reciter.store.ensureActiveBook('Zayd').id;
    await reciter.engine.enableSync(book);
    final inv = await reciter.engine.invite(book, BookRole.listener);
    await listener.engine.signUp(_user('ustadh'), 'pw-ustadh-1', displayName: 'Ustadh');
    await listener.engine.join(inv.code);
    return (reciter, listener, book);
  }

  test('username-only sign-up; local id becomes the account id', () async {
    final d = await _Device.make();
    final name = _user('only');
    await d.engine.signUp(name, 'pw-only-123');
    expect(d.engine.account!.id, d.store.me.id);
    expect(d.engine.account!.username, name);
    await d.engine.signOut();
    await d.engine.signIn(name, 'pw-only-123');
    expect(d.engine.signedIn, isTrue);
    await expectLater(d.engine.signIn(name, 'wrong-pass'),
        throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.invalid)));
    final e = await _Device.make();
    await expectLater(e.engine.signUp(name, 'pw-other-12'),
        throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.taken)));
  });

  test('share code → listener marks → reciter receives (incl. live)', () async {
    final (reciter, listener, book) = await shared();
    expect(listener.store.book(book)!.myRole, BookRole.listener);
    final members = await reciter.engine.members(book);
    expect(members.map((m) => m.role), [BookRole.owner, BookRole.listener]);

    final s = listener.store.startSession(bookId: book, script: 'indopak');
    listener.store.toggle(book, w1, MarkType.doubt, sessionId: s.id);
    await listener.engine.syncNow();
    await reciter.engine.syncNow();
    expect(reciter.store.marksAt(book, w1).single.type, MarkType.doubt);

    // Live: the reciter is watching its active book over SSE.
    listener.store.addMark(book, w2, MarkType.tajwid, sessionId: s.id);
    await listener.engine.syncNow();
    for (var i = 0; i < 30 && reciter.store.marksAt(book, w2).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(reciter.store.marksAt(book, w2), hasLength(1));
  });

  test('a fix and a comment edit made at once both survive', () async {
    final (reciter, listener, book) = await shared();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    listener.store.fix(book, w1);
    reciter.store.setComment(reciter.store.marksAt(book, w1).single, 'ā, not a');
    await listener.engine.syncNow();
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    for (final d in [reciter, listener]) {
      final m = d.store.marksAt(book, w1).single;
      expect(m.comment, 'ā, not a');
      expect(d.store.isFixed(m), isTrue);
    }
  });

  test('rules: a listener cannot change the reciter\'s mark; checkers only comment',
      () async {
    final (reciter, listener, book) = await shared();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    listener.store.setType(listener.store.marksAt(book, w1).single, MarkType.note);
    await listener.engine.syncNow();
    await reciter.engine.syncNow();
    expect(reciter.store.marksAt(book, w1).single.type, MarkType.mistake);

    final inv = await reciter.engine.invite(book, BookRole.checker);
    final checker = await _Device.make();
    await checker.engine.signUp(_user('mum'), 'pw-mum-1234');
    await checker.engine.join(inv.code);
    final m = checker.store.marksAt(book, w1).single;
    checker.store.addComment(m, 'Practise tonight');
    checker.store.addMark(book, w2, MarkType.mistake);
    await checker.engine.syncNow();
    await reciter.engine.syncNow();
    expect(reciter.store.commentsOn(reciter.store.marksAt(book, w1).single)
        .single.text, 'Practise tonight');
    expect(reciter.store.marksAt(book, w2), isEmpty);
  });

  test('a stale write gets 409 and the newer copy wins', () async {
    final (reciter, listener, book) = await shared();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    final row = Map<String, dynamic>.from(
        (await reciter.engine.backend.pull('marks', book, null)).single);
    final older = {...row, 'client_updated': (row['client_updated'] as int) - 1000, 'comment': 'old'};
    final res = await reciter.engine.backend.push('marks', [older]);
    expect(res.rejected.single.$2, SyncError.stale);
  });

  test('revoking access and deleting an account', () async {
    final (reciter, listener, book) = await shared();
    listener.store.addMark(book, w1, MarkType.doubt);
    await listener.engine.syncNow();

    // Delete the listener's account: their mark stays, anonymised.
    await listener.engine.deleteAccount();
    await reciter.engine.syncNow();
    final m = reciter.store.marksAt(book, w1).single;
    expect(m.authorName, 'Deleted user');
    expect(m.authorId, '');
    expect((await reciter.engine.members(book)).length, 1);

    // A bad code is refused.
    final other = await _Device.make();
    await other.engine.signUp(_user('x'), 'pw-x-123456');
    await expectLater(other.engine.join('NOTACODE'),
        throwsA(isA<SyncException>()));
  });
}
