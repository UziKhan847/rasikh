import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marks/marks_model.dart';
import 'sync_backend.dart';

/// The self-hosted PocketBase server (schema: server/pb_migrations, rules and
/// routes: server/pb_hooks). Talks only to [baseUrl]; the session token is
/// kept in SharedPreferences so the user stays signed in.
class PocketBaseSyncBackend implements SyncBackend {
  PocketBaseSyncBackend._(this.baseUrl, this._pb);

  final String baseUrl;
  final PocketBase _pb;

  static const _authKey = 'noor.pb_auth';

  static Future<PocketBaseSyncBackend> create(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (data) => prefs.setString(_authKey, data),
      initial: prefs.getString(_authKey),
      clear: () => prefs.remove(_authKey),
    );
    return PocketBaseSyncBackend._(
        baseUrl, PocketBase(baseUrl, authStore: store));
  }

  RecordService get _users => _pb.collection('users');

  Account? _toAccount(RecordModel? r) => r == null
      ? null
      : Account(
          id: r.id,
          username: r.getStringValue('username'),
          displayName: r.getStringValue('displayName'),
          email: r.getStringValue('email').isEmpty
              ? null
              : r.getStringValue('email'));

  @override
  Account? get account =>
      _pb.authStore.isValid ? _toAccount(_pb.authStore.record) : null;

  /// Runs [f], mapping PocketBase errors onto [SyncError]s.
  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ClientException catch (e) {
      throw SyncException(_errorOf(e), _messageOf(e));
    }
  }

  static SyncError _errorOf(ClientException e) {
    switch (e.statusCode) {
      case 0:
        return SyncError.network;
      case 401:
        return SyncError.auth;
      case 403:
      case 404:
        return SyncError.forbidden;
      case 409:
        return SyncError.stale;
    }
    final data = e.response['data'];
    if (data is Map && data['username'] is Map) {
      final code = (data['username'] as Map)['code'];
      if (code == 'validation_not_unique') return SyncError.taken;
    }
    return SyncError.invalid;
  }

  static String _messageOf(ClientException e) =>
      e.response['message'] as String? ?? '';

  @override
  Future<Account?> restore() async {
    if (!_pb.authStore.isValid) return null;
    try {
      await _users.authRefresh();
    } on ClientException catch (e) {
      // Offline: keep the saved session; anything else means it's gone.
      if (e.statusCode != 0) _pb.authStore.clear();
    }
    return account;
  }

  @override
  Future<Account> signUp(
      {required String id,
      required String username,
      required String password,
      String displayName = '',
      String? email}) {
    return _call(() async {
      await _users.create(body: {
        'id': id,
        'username': username,
        'password': password,
        'passwordConfirm': password,
        'displayName': displayName,
        'email': ?email,
      });
      await _users.authWithPassword(username, password);
      return account!;
    });
  }

  @override
  Future<Account> signIn(String username, String password) => _call(() async {
        await _users.authWithPassword(username, password);
        return account!;
      });

  @override
  Future<void> signOut() async => _pb.authStore.clear();

  @override
  Future<void> deleteAccount() => _call(() async {
        final id = account?.id;
        if (id == null) throw const SyncException(SyncError.auth);
        await _users.delete(id);
        _pb.authStore.clear();
      });

  @override
  Future<void> requestPasswordReset(String email) =>
      _call(() => _users.requestPasswordReset(email));

  // ── books ──

  @override
  Future<List<Map<String, dynamic>>> listBooks() => _call(() async {
        final list = await _pb.collection('books').getFullList(batch: 200);
        return [for (final r in list) r.toJson()];
      });

  @override
  Future<String> upsertBook(Map<String, dynamic> wire) => _call(() async {
        final books = _pb.collection('books');
        final id = wire['id'] as String;
        RecordModel r;
        try {
          r = await books.update(id, body: wire);
        } on ClientException catch (e) {
          if (e.statusCode != 404) rethrow;
          r = await books.create(body: wire);
        }
        return r.getStringValue('updated');
      });

  @override
  Future<void> deleteBook(String id) => _call(() async {
        try {
          await _pb.collection('books').delete(id);
        } on ClientException catch (e) {
          if (e.statusCode != 404) rethrow;
        }
      });

  // ── records ──

  @override
  Future<PushResult> push(
      String collection, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const PushResult([], []);
    // One transactional batch of upserts; if any row is refused the whole
    // batch is, so fall back to row by row to find which.
    try {
      final batch = _pb.createBatch();
      for (final r in rows) {
        batch.collection(collection).upsert(body: r);
      }
      final res = await batch.send();
      return PushResult([
        for (var i = 0; i < res.length; i++)
          (
            rows[i]['id'] as String,
            ((res[i].body as Map?)?['updated'] as String?) ?? '',
          )
      ], const []);
    } on ClientException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 401) {
        throw SyncException(_errorOf(e));
      }
    }
    final ok = <(String, String)>[];
    final bad = <(String, SyncError)>[];
    final c = _pb.collection(collection);
    for (final r in rows) {
      final id = r['id'] as String;
      try {
        RecordModel saved;
        try {
          saved = await c.update(id, body: r);
        } on ClientException catch (e) {
          if (e.statusCode != 404) rethrow;
          saved = await c.create(body: r);
        }
        ok.add((id, saved.getStringValue('updated')));
      } on ClientException catch (e) {
        final err = _errorOf(e);
        if (err == SyncError.network || err == SyncError.auth) {
          throw SyncException(err);
        }
        bad.add((id, err));
      }
    }
    return PushResult(ok, bad);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
          String collection, String bookId, String? since) =>
      _call(() async {
        final filter = since == null
            ? _pb.filter('book = {:b}', {'b': bookId})
            : _pb.filter('book = {:b} && updated >= {:t}',
                {'b': bookId, 't': since});
        final list = await _pb
            .collection(collection)
            .getFullList(batch: 500, filter: filter, sort: 'updated,id');
        return [for (final r in list) r.toJson()];
      });

  // ── sharing (routes in server/pb_hooks/hifz.pb.js) ──

  @override
  Future<Invite> createInvite(String bookId, BookRole role) => _call(() async {
        final res = await _pb.send<Map<String, dynamic>>('/api/hifz/invites',
            method: 'POST', body: {'book': bookId, 'role': role.code});
        return Invite(res['code'] as String, role,
            DateTime.tryParse(res['expires'] as String? ?? '') ??
                DateTime.now().add(const Duration(days: 7)));
      });

  @override
  Future<String> acceptInvite(String code) => _call(() async {
        final res = await _pb.send<Map<String, dynamic>>(
            '/api/hifz/invites/accept',
            method: 'POST',
            body: {'code': code});
        return res['book'] as String;
      });

  @override
  Future<List<BookMember>> members(String bookId) => _call(() async {
        final res = await _pb.send<Map<String, dynamic>>(
            '/api/hifz/books/${Uri.encodeComponent(bookId)}/members');
        return [
          for (final m in (res['members'] as List? ?? const []))
            BookMember(
              id: m['id'] as String,
              username: m['username'] as String? ?? '',
              displayName: m['displayName'] as String? ?? '',
              role: BookRole.fromCode(m['role'] as String?),
            )
        ];
      });

  @override
  Future<void> removeMember(String bookId, String userId) => _call(() =>
      _pb.send('/api/hifz/books/${Uri.encodeComponent(bookId)}/remove',
          method: 'POST', body: {'user': userId}));

  @override
  Future<void> leaveBook(String bookId) => _call(() => _pb.send(
      '/api/hifz/books/${Uri.encodeComponent(bookId)}/leave',
      method: 'POST'));

  @override
  Stream<(String, Map<String, dynamic>)> watch(String bookId) {
    late StreamController<(String, Map<String, dynamic>)> ctl;
    final unsubs = <UnsubscribeFunc>[];
    ctl = StreamController(
      onListen: () async {
        for (final c in const ['sessions', 'marks', 'mark_fixes', 'mark_comments']) {
          try {
            unsubs.add(await _pb.collection(c).subscribe(
                  '*',
                  (e) {
                    final r = e.record;
                    if (r != null && e.action != 'delete') {
                      ctl.add((c, r.toJson()));
                    }
                  },
                  filter: _pb.filter('book = {:b}', {'b': bookId}),
                ));
          } catch (_) {
            // Realtime unavailable: the engine's polling covers it.
          }
        }
      },
      onCancel: () async {
        for (final u in unsubs) {
          try {
            await u();
          } catch (_) {}
        }
      },
    );
    return ctl.stream;
  }
}
