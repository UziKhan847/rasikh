import '../marks/marks_model.dart';

/// The signed-in account.
class Account {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  const Account(
      {required this.id,
      required this.username,
      this.displayName = '',
      this.email});
}

/// A member of a shared mark book (for the members list).
class BookMember {
  final String id;
  final String username;
  final String displayName;
  final BookRole role;
  const BookMember(
      {required this.id,
      required this.username,
      required this.displayName,
      required this.role});
}

class Invite {
  final String code;
  final BookRole role;
  final DateTime expires;
  const Invite(this.code, this.role, this.expires);
}

class PushResult {
  /// (id, server `updated`) of each row the server stored.
  final List<(String, String)> accepted;

  /// Rows the server refused, with why.
  final List<(String, SyncError)> rejected;
  const PushResult(this.accepted, this.rejected);
}

enum SyncError {
  /// No connection / server unreachable — retry later.
  network,

  /// Not signed in, or the session expired.
  auth,

  /// The server has a newer copy of this row (pull it).
  stale,

  /// Not allowed (not a member, someone else's mark…).
  forbidden,

  /// Wrong username/password, bad invite code, invalid data.
  invalid,

  /// Username already taken.
  taken,
}

class SyncException implements Exception {
  final SyncError error;
  final String message;
  const SyncException(this.error, [this.message = '']);
  @override
  String toString() => 'SyncException($error, $message)';
}

/// What the sync engine needs from a server. The real one is
/// PocketBaseSyncBackend (self-hosted PocketBase); MemorySyncBackend
/// implements the same rules in memory for tests.
///
/// Rows travel as "wire" maps (see wire.dart) with snake_case fields; pulled
/// rows also carry the server's `updated` stamp.
abstract interface class SyncBackend {
  Account? get account;

  /// Restores a saved session (no network unless one exists).
  Future<Account?> restore();

  Future<Account> signUp(
      {required String id,
      required String username,
      required String password,
      String displayName = '',
      String? email});
  Future<Account> signIn(String username, String password);
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<void> requestPasswordReset(String email);

  /// Books this account owns or is a member of (wire maps).
  Future<List<Map<String, dynamic>>> listBooks();
  Future<String> upsertBook(Map<String, dynamic> wire);
  Future<void> deleteBook(String id);

  Future<PushResult> push(String collection, List<Map<String, dynamic>> rows);

  /// Rows of [bookId] changed at or after [since] (a server `updated`
  /// stamp; null = everything), oldest first.
  Future<List<Map<String, dynamic>>> pull(
      String collection, String bookId, String? since);

  Future<Invite> createInvite(String bookId, BookRole role);
  Future<String> acceptInvite(String code);
  Future<List<BookMember>> members(String bookId);
  Future<void> removeMember(String bookId, String userId);
  Future<void> leaveBook(String bookId);

  /// Live changes to [bookId] (collection, wire row). May never emit, in
  /// which case the engine's polling still catches up.
  Stream<(String, Map<String, dynamic>)> watch(String bookId);
}

/// Before a server address is set: signed out, and every call says so.
class NoServerBackend implements SyncBackend {
  const NoServerBackend();
  static const _e = SyncException(SyncError.invalid, 'no server');
  @override
  Account? get account => null;
  @override
  Future<Account?> restore() async => null;
  @override
  Future<Account> signUp(
          {required String id,
          required String username,
          required String password,
          String displayName = '',
          String? email}) =>
      throw _e;
  @override
  Future<Account> signIn(String username, String password) => throw _e;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() => throw _e;
  @override
  Future<void> requestPasswordReset(String email) => throw _e;
  @override
  Future<List<Map<String, dynamic>>> listBooks() => throw _e;
  @override
  Future<String> upsertBook(Map<String, dynamic> wire) => throw _e;
  @override
  Future<void> deleteBook(String id) => throw _e;
  @override
  Future<PushResult> push(String collection, List<Map<String, dynamic>> rows) =>
      throw _e;
  @override
  Future<List<Map<String, dynamic>>> pull(
          String collection, String bookId, String? since) =>
      throw _e;
  @override
  Future<Invite> createInvite(String bookId, BookRole role) => throw _e;
  @override
  Future<String> acceptInvite(String code) => throw _e;
  @override
  Future<List<BookMember>> members(String bookId) => throw _e;
  @override
  Future<void> removeMember(String bookId, String userId) => throw _e;
  @override
  Future<void> leaveBook(String bookId) => throw _e;
  @override
  Stream<(String, Map<String, dynamic>)> watch(String bookId) =>
      const Stream.empty();
}
