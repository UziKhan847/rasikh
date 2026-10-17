import 'dart:async';

import 'package:flutter/widgets.dart';

import '../marks/marks_model.dart';
import '../marks/marks_store.dart';
import 'sync_backend.dart';
import 'wire.dart';

enum SyncStatus { signedOut, idle, syncing, offline, error }

/// Keeps the local [MarksStore] and the server in step. Strictly opt-in:
/// nothing touches the network until someone signs in, and everything keeps
/// working offline — edits queue up as dirty records and go out on the next
/// sync.
///
/// A sync: books first (the server's list decides membership), then for each
/// synced book push its dirty records, then pull what changed since the last
/// cursor (rewound a few seconds; merging is idempotent).
class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.store, required SyncBackend backend})
      : _backend = backend {
    store.onLocalEdit = _onLocalEdit;
    store.addListener(_onStore);
  }

  final MarksStore store;
  SyncBackend _backend;
  SyncBackend get backend => _backend;

  SyncStatus _status = SyncStatus.signedOut;
  SyncStatus get status => _status;
  DateTime? lastSync;
  SyncError? lastError;

  Account? get account => _backend.account;
  bool get signedIn => account != null;

  Timer? _debounce, _poll, _retry;
  int _backoff = 0;
  Future<void>? _running;
  bool _again = false;
  String? _watching;
  StreamSubscription<(String, Map<String, dynamic>)>? _watchSub;

  /// Delay between a local edit and pushing it.
  static const pushDelay = Duration(seconds: 2);

  /// Polling while a synced book is open (realtime may be unavailable).
  static const pollEvery = Duration(seconds: 30);

  void _set(SyncStatus s, [SyncError? e]) {
    if (s == _status && e == lastError) return;
    _status = s;
    lastError = e;
    notifyListeners();
  }

  /// Switch servers (e.g. the server address changed). Signs out locally.
  Future<void> replaceBackend(SyncBackend b) async {
    _stopWatch();
    _backend = b;
    await start();
  }

  /// Restore a saved session (no network if there is none) and sync.
  Future<void> start() async {
    final a = await _backend.restore();
    if (a == null) {
      _set(SyncStatus.signedOut);
      return;
    }
    store.setAccount(accountId: a.id, username: a.username);
    _set(SyncStatus.idle);
    unawaited(syncNow());
  }

  // ── account ────────────────────────────────────────────────────────────

  Future<void> signUp(String username, String password,
      {String displayName = '', String? email}) async {
    final a = await _backend.signUp(
        id: store.me.id,
        username: username.trim().toLowerCase(),
        password: password,
        displayName: displayName.trim(),
        email: email == null || email.trim().isEmpty ? null : email.trim());
    _signedIn(a, displayName);
  }

  Future<void> signIn(String username, String password) async {
    final a = await _backend.signIn(username.trim().toLowerCase(), password);
    _signedIn(a, a.displayName);
  }

  void _signedIn(Account a, String displayName) {
    store.setAccount(accountId: a.id, username: a.username);
    if (displayName.trim().isNotEmpty && store.me.displayName.isEmpty) {
      store.renameMe(displayName);
    }
    _set(SyncStatus.idle);
    unawaited(syncNow());
  }

  Future<void> signOut() async {
    _stopWatch();
    await _backend.signOut();
    // Shared books (someone else's) leave this device with the account;
    // the user's own books stay as local copies.
    for (final b in store.syncedBooks.toList()) {
      b.myRole == BookRole.owner ? store.unsyncBook(b.id) : store.forgetBook(b.id);
    }
    store.setAccount(accountId: null);
    _set(SyncStatus.signedOut);
  }

  /// Deletes the account on the server (its own books with it; what it wrote
  /// in others' books is anonymised there). Local data stays, unsynced.
  Future<void> deleteAccount() async {
    _stopWatch();
    await _backend.deleteAccount();
    for (final b in store.syncedBooks.toList()) {
      b.myRole == BookRole.owner ? store.unsyncBook(b.id) : store.forgetBook(b.id);
    }
    store.setAccount(accountId: null);
    _set(SyncStatus.signedOut);
  }

  // ── sharing ────────────────────────────────────────────────────────────

  /// Starts syncing a local book under this account.
  Future<void> enableSync(String bookId) async {
    final a = account;
    if (a == null || store.book(bookId) == null) return;
    store.setBookSynced(bookId, ownerAccountId: a.id);
    await syncNow();
  }

  Future<Invite> invite(String bookId, BookRole role) =>
      _backend.createInvite(bookId, role);

  /// Joins a book by its share code; it becomes the active book.
  Future<void> join(String code) async {
    final id = await _backend.acceptInvite(code);
    await syncNow();
    if (store.book(id) != null) store.setActiveBook(id);
  }

  Future<List<BookMember>> members(String bookId) => _backend.members(bookId);
  Future<void> removeMember(String bookId, String userId) =>
      _backend.removeMember(bookId, userId);

  Future<void> leave(String bookId) async {
    await _backend.leaveBook(bookId);
    store.forgetBook(bookId);
  }

  // ── syncing ────────────────────────────────────────────────────────────

  void _onLocalEdit(String bookId) {
    if (!signedIn || store.book(bookId)?.synced != true) return;
    _debounce?.cancel();
    _debounce = Timer(pushDelay, () => unawaited(syncNow()));
  }

  void _onStore() {
    // Follow the active book for live updates.
    final b = store.activeBook;
    final want = signedIn && b != null && b.synced ? b.id : null;
    if (want != _watching) _startWatch(want);
  }

  void _startWatch(String? bookId) {
    _stopWatch();
    _watching = bookId;
    if (bookId == null) return;
    _watchSub = _backend.watch(bookId).listen((e) {
      final (collection, row) = e;
      store.merge(Wire.changeSet(collection, [row]), fromServer: true);
    }, onError: (_) {});
    _poll = Timer.periodic(pollEvery, (_) => unawaited(syncNow(quiet: true)));
  }

  void _stopWatch() {
    _watchSub?.cancel();
    _watchSub = null;
    _poll?.cancel();
    _poll = null;
    _watching = null;
  }

  /// Runs a full sync (coalescing overlapping requests). A [quiet] sync —
  /// the background poll — doesn't flip the status to "syncing" and back,
  /// so it rebuilds nothing unless data actually changed.
  Future<void> syncNow({bool quiet = false}) async {
    if (!signedIn || !store.ready) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final c = Completer<void>();
    _running = c.future;
    try {
      do {
        _again = false;
        await _syncOnce(quiet: quiet);
      } while (_again);
    } finally {
      _running = null;
      c.complete();
    }
  }

  Future<void> _syncOnce({bool quiet = false}) async {
    if (!quiet) _set(SyncStatus.syncing);
    try {
      await _syncBooks();
      // Only books the server has: one shared mid-sync is uploaded (and its
      // records pushed) on the next pass, not refused now.
      for (final b in store.syncedBooks.toList()) {
        if (!b.deleted && b.serverUpdated != null) await _syncBook(b.id);
      }
      lastSync = DateTime.now();
      _backoff = 0;
      _set(SyncStatus.idle);
      _onStore();
    } on SyncException catch (e) {
      if (e.error == SyncError.auth) {
        _set(SyncStatus.signedOut, e.error);
        return;
      }
      _set(e.error == SyncError.network ? SyncStatus.offline : SyncStatus.error,
          e.error);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _backoff = (_backoff + 1).clamp(1, 6);
    _retry = Timer(Duration(seconds: 5 << _backoff), () => unawaited(syncNow()));
  }

  Future<void> _syncBooks() async {
    final me = account!.id;
    // Local changes to books first: deletions, new and renamed books.
    for (final b in store.syncedBooks.toList()) {
      if (b.myRole != BookRole.owner) continue;
      if (b.deleted) {
        await _backend.deleteBook(b.id);
        store.forgetBook(b.id);
      } else if (b.dirty) {
        final cu = b.clientUpdated;
        try {
          final upd = await _backend.upsertBook(Wire.book(b, me));
          store.markPushed('books', b.id, b.id, cu, upd);
        } on SyncException catch (e) {
          if (e.error != SyncError.stale) rethrow;
        }
      }
    }
    final remote = await _backend.listBooks();
    final ids = <String>{};
    for (final w in remote) {
      final b = Wire.bookFrom(w, me);
      ids.add(b.id);
      store.upsertRemoteBook(b);
    }
    // Synced books the server no longer lists: deleted by their owner, or
    // our access was revoked. (Not one that has never reached the server —
    // it may have been shared a moment ago, mid-sync.)
    for (final b in store.syncedBooks.toList()) {
      if (!ids.contains(b.id) && !b.deleted && b.serverUpdated != null) {
        store.forgetBook(b.id);
      }
    }
  }

  Future<void> _syncBook(String bookId) async {
    final dirty = store.dirtyRecords(bookId);
    for (final kind in Wire.collections) {
      final recs = dirty[kind] ?? const <SyncRecord>[];
      if (recs.isEmpty) continue;
      final cu = {for (final r in recs) r.id: r.clientUpdated};
      for (var i = 0; i < recs.length; i += 200) {
        final chunk = recs.sublist(i, (i + 200).clamp(0, recs.length));
        final res = await _backend.push(
            kind, [for (final r in chunk) Wire.toWire(kind, r)]);
        for (final (id, updated) in res.accepted) {
          store.markPushed(kind, bookId, id, cu[id]!, updated);
        }
        for (final (id, err) in res.rejected) {
          // Stale: the pull below brings the newer copy. Anything else won't
          // succeed on retry; stop resending it.
          if (err != SyncError.stale) {
            store.markPushed(kind, bookId, id, cu[id]!, null);
          }
        }
      }
    }
    for (final kind in Wire.collections) {
      final cursor = store.cursor(bookId, kind);
      final rows = await _backend.pull(kind, bookId, rewind(cursor));
      if (rows.isEmpty) continue;
      store.merge(Wire.changeSet(kind, rows), fromServer: true);
      var max = cursor ?? '';
      for (final r in rows) {
        final u = r['updated'] as String? ?? '';
        if (u.compareTo(max) > 0) max = u;
      }
      if (max.isNotEmpty) store.setCursor(bookId, kind, max);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _retry?.cancel();
    _stopWatch();
    store.removeListener(_onStore);
    if (store.onLocalEdit == _onLocalEdit) store.onLocalEdit = null;
    super.dispose();
  }
}

/// Puts the [SyncEngine] in the widget tree.
class SyncScope extends InheritedNotifier<SyncEngine> {
  const SyncScope({super.key, required SyncEngine engine, required super.child})
      : super(notifier: engine);

  static SyncEngine? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
