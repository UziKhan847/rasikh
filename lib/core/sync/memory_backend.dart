import 'dart:async';
import 'dart:math';

import '../marks/marks_model.dart';
import 'sync_backend.dart';
import 'wire.dart';

/// An in-memory server with the same permission and merge rules as the
/// PocketBase one (server/pb_migrations + pb_hooks). It is the executable
/// reference of the contract, and what the sync tests run against. Several
/// [MemorySyncBackend] clients share one server.
class MemoryServer {
  final users = <String, Map<String, dynamic>>{}; // id → {username, password, displayName, email}
  final books = <String, Map<String, dynamic>>{};
  final tables = <String, Map<String, Map<String, dynamic>>>{
    for (final c in Wire.collections) c: {},
  };
  final invites = <String, Map<String, dynamic>>{}; // code → {book, role, uses, max, expires}
  final _events =
      StreamController<(String, String, Map<String, dynamic>)>.broadcast();

  int _clock = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  String _stamp() => pbTime(DateTime.fromMillisecondsSinceEpoch(++_clock, isUtc: true));

  bool _owner(String book, String uid) => books[book]?['owner'] == uid;
  bool _listener(String book, String uid) =>
      (books[book]?['listeners'] as List? ?? const []).contains(uid);
  bool _checker(String book, String uid) =>
      (books[book]?['checkers'] as List? ?? const []).contains(uid);
  bool _member(String b, String u) =>
      _owner(b, u) || _listener(b, u) || _checker(b, u);
  bool _writer(String b, String u) => _owner(b, u) || _listener(b, u);

  static const _authorField = {
    'sessions': 'created_by',
    'marks': 'author',
    'mark_fixes': 'fixed_by',
    'mark_comments': 'author',
  };
}

class MemorySyncBackend implements SyncBackend {
  final MemoryServer server;
  Account? _account;

  /// Tests flip this to simulate losing the connection.
  bool offline = false;

  MemorySyncBackend(this.server);

  @override
  Account? get account => _account;

  String get _uid {
    _net();
    final a = _account;
    if (a == null) throw const SyncException(SyncError.auth);
    return a.id;
  }

  void _net() {
    if (offline) throw const SyncException(SyncError.network);
  }

  @override
  Future<Account?> restore() async => _account;

  Account _acct(String id) {
    final u = server.users[id]!;
    return Account(
        id: id,
        username: u['username'] as String,
        displayName: u['displayName'] as String? ?? '',
        email: u['email'] as String?);
  }

  @override
  Future<Account> signUp(
      {required String id,
      required String username,
      required String password,
      String displayName = '',
      String? email}) async {
    _net();
    if (server.users.values.any((u) => u['username'] == username)) {
      throw const SyncException(SyncError.taken);
    }
    final uid = server.users.containsKey(id) ? newRecordId() : id;
    server.users[uid] = {
      'username': username,
      'password': password,
      'displayName': displayName,
      'email': email,
    };
    return _account = _acct(uid);
  }

  @override
  Future<Account> signIn(String username, String password) async {
    _net();
    final e = server.users.entries.where((e) =>
        (e.value['username'] == username || e.value['email'] == username) &&
        e.value['password'] == password);
    if (e.isEmpty) throw const SyncException(SyncError.invalid);
    return _account = _acct(e.first.key);
  }

  @override
  Future<void> signOut() async => _account = null;

  @override
  Future<void> deleteAccount() async {
    final uid = _uid;
    server.users.remove(uid);
    for (final b in server.books.keys.toList()) {
      if (server._owner(b, uid)) {
        _dropBook(b);
      } else {
        (server.books[b]!['listeners'] as List).remove(uid);
        (server.books[b]!['checkers'] as List).remove(uid);
      }
    }
    // What they wrote in other people's books stays, anonymised.
    for (final c in Wire.collections) {
      final f = MemoryServer._authorField[c]!;
      for (final r in server.tables[c]!.values) {
        if (r[f] == uid) {
          r[f] = '';
          if (r.containsKey('author_name')) r['author_name'] = 'Deleted user';
          if (r.containsKey('fixed_by_name')) r['fixed_by_name'] = 'Deleted user';
        }
      }
    }
    _account = null;
  }

  void _dropBook(String b) {
    server.books.remove(b);
    for (final t in server.tables.values) {
      t.removeWhere((_, r) => r['book'] == b);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async => _net();

  @override
  Future<List<Map<String, dynamic>>> listBooks() async {
    final uid = _uid;
    return [
      for (final b in server.books.values)
        if (server._member(b['id'] as String, uid)) Map.of(b)
    ];
  }

  @override
  Future<String> upsertBook(Map<String, dynamic> wire) async {
    final uid = _uid;
    final id = wire['id'] as String;
    final cur = server.books[id];
    if (cur == null) {
      if (wire['owner'] != uid) throw const SyncException(SyncError.forbidden);
      server.books[id] = {
        ...wire,
        'listeners': <String>[],
        'checkers': <String>[],
        'updated': server._stamp(),
      };
    } else {
      if (cur['owner'] != uid || wire['owner'] != uid) {
        throw const SyncException(SyncError.forbidden);
      }
      if ((wire['client_updated'] as int) < (cur['client_updated'] as int)) {
        throw const SyncException(SyncError.stale);
      }
      cur
        ..['name'] = wire['name']
        ..['client_updated'] = wire['client_updated']
        ..['updated'] = server._stamp();
    }
    return server.books[id]!['updated'] as String;
  }

  @override
  Future<void> deleteBook(String id) async {
    final uid = _uid;
    if (!server.books.containsKey(id)) return;
    if (!server._owner(id, uid)) throw const SyncException(SyncError.forbidden);
    _dropBook(id);
  }

  @override
  Future<PushResult> push(
      String collection, List<Map<String, dynamic>> rows) async {
    final uid = _uid;
    final table = server.tables[collection]!;
    final authorField = MemoryServer._authorField[collection]!;
    final accepted = <(String, String)>[];
    final rejected = <(String, SyncError)>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final book = row['book'] as String;
      final cur = table[id];
      SyncError? err;
      if (cur == null) {
        // create rule
        final canWrite = collection == 'mark_comments'
            ? server._member(book, uid)
            : server._writer(book, uid);
        if (row[authorField] != uid || !canWrite) err = SyncError.forbidden;
      } else {
        // update rule
        final mayEdit = cur[authorField] == uid || server._owner(book, uid);
        final immutable =
            row['book'] == cur['book'] && row[authorField] == cur[authorField];
        if (!mayEdit || !immutable) {
          err = SyncError.forbidden;
        } else if ((row['client_updated'] as int) <
            (cur['client_updated'] as int)) {
          err = SyncError.stale;
        }
      }
      if (err != null) {
        rejected.add((id, err));
        continue;
      }
      final stored = {...row, 'updated': server._stamp()};
      table[id] = stored;
      accepted.add((id, stored['updated'] as String));
      server._events.add((collection, book, Map.of(stored)));
    }
    return PushResult(accepted, rejected);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
      String collection, String bookId, String? since) async {
    final uid = _uid;
    if (!server._member(bookId, uid)) {
      throw const SyncException(SyncError.forbidden);
    }
    final rows = [
      for (final r in server.tables[collection]!.values)
        if (r['book'] == bookId &&
            (since == null || (r['updated'] as String).compareTo(since) >= 0))
          Map<String, dynamic>.of(r)
    ]..sort((a, b) {
        final c = (a['updated'] as String).compareTo(b['updated'] as String);
        return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
      });
    return rows;
  }

  @override
  Future<Invite> createInvite(String bookId, BookRole role) async {
    final uid = _uid;
    if (!server._owner(bookId, uid)) {
      throw const SyncException(SyncError.forbidden);
    }
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = String.fromCharCodes(List.generate(
        8, (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length))));
    final expires = DateTime.now().add(const Duration(days: 7));
    server.invites[code] = {
      'book': bookId,
      'role': role.code,
      'uses': 0,
      'max': 20,
      'expires': expires,
    };
    return Invite(code, role, expires);
  }

  @override
  Future<String> acceptInvite(String code) async {
    final uid = _uid;
    final inv = server.invites[code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '')];
    if (inv == null ||
        (inv['expires'] as DateTime).isBefore(DateTime.now()) ||
        (inv['uses'] as int) >= (inv['max'] as int)) {
      throw const SyncException(SyncError.invalid);
    }
    final b = server.books[inv['book']];
    if (b == null) throw const SyncException(SyncError.invalid);
    final field = inv['role'] == 'checker' ? 'checkers' : 'listeners';
    final list = b[field] as List;
    if (!list.contains(uid) && b['owner'] != uid) list.add(uid);
    inv['uses'] = (inv['uses'] as int) + 1;
    return b['id'] as String;
  }

  @override
  Future<List<BookMember>> members(String bookId) async {
    final uid = _uid;
    if (!server._member(bookId, uid)) {
      throw const SyncException(SyncError.forbidden);
    }
    final b = server.books[bookId]!;
    BookMember m(String id, BookRole r) => BookMember(
        id: id,
        username: server.users[id]?['username'] as String? ?? '',
        displayName: server.users[id]?['displayName'] as String? ?? '',
        role: r);
    return [
      m(b['owner'] as String, BookRole.owner),
      for (final id in (b['listeners'] as List).cast<String>())
        m(id, BookRole.listener),
      for (final id in (b['checkers'] as List).cast<String>())
        m(id, BookRole.checker),
    ];
  }

  @override
  Future<void> removeMember(String bookId, String userId) async {
    final uid = _uid;
    if (!server._owner(bookId, uid)) {
      throw const SyncException(SyncError.forbidden);
    }
    (server.books[bookId]!['listeners'] as List).remove(userId);
    (server.books[bookId]!['checkers'] as List).remove(userId);
  }

  @override
  Future<void> leaveBook(String bookId) async {
    final uid = _uid;
    final b = server.books[bookId];
    if (b == null) return;
    (b['listeners'] as List).remove(uid);
    (b['checkers'] as List).remove(uid);
  }

  @override
  Stream<(String, Map<String, dynamic>)> watch(String bookId) =>
      server._events.stream
          .where((e) =>
              e.$2 == bookId &&
              _account != null &&
              !offline &&
              server._member(bookId, _account!.id))
          .map((e) => (e.$1, e.$3));
}
