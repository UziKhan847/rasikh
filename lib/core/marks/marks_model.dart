import 'dart:math';

import 'word_ref.dart';

/// A listener's mark on one word. "Fixed" is not a type: any mark except a
/// [note] can later be fixed, which is recorded as a separate [MarkFix].
enum MarkType {
  mistake('mistake'),
  tajwid('tajwid'),
  hesitation('hesitation'),
  doubt('doubt'),
  note('note');

  final String code;
  const MarkType(this.code);
  static MarkType fromCode(String? c) =>
      values.firstWhere((t) => t.code == c, orElse: () => mistake);

  /// Pen order in the marking bar and in charts.
  static const pens = [mistake, tajwid, hesitation, doubt];

  bool get fixable => this != note;
}

/// What kind of recitation a session was (hifz-class terms; optional).
enum SessionKind {
  none('none'),
  sabaq('sabaq'),
  sabqi('sabqi'),
  manzil('manzil'),
  other('other');

  final String code;
  const SessionKind(this.code);
  static SessionKind fromCode(String? c) =>
      values.firstWhere((t) => t.code == c, orElse: () => none);
}

enum BookRole {
  owner('owner'),
  listener('listener'),
  checker('checker');

  final String code;
  const BookRole(this.code);
  static BookRole fromCode(String? c) =>
      values.firstWhere((t) => t.code == c, orElse: () => owner);

  bool get canMark => this != checker;
}

final _rng = Random.secure();
const _idAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// 15 chars of [a-z0-9] — PocketBase's own record-id format, so a record
/// created offline keeps its id when it reaches the server.
String newRecordId() =>
    String.fromCharCodes(List.generate(
        15, (_) => _idAlphabet.codeUnitAt(_rng.nextInt(_idAlphabet.length))));

/// Fields every synced record carries.
abstract class SyncRecord {
  String get id;
  String get bookId;

  /// Last local edit, ms since epoch UTC. Last-writer-wins key.
  int clientUpdated;

  /// Tombstone: deleted records are kept (and synced) so the deletion
  /// propagates; never-synced ones are dropped outright instead.
  bool deleted;

  /// Server's `updated` stamp once synced; null = never reached the server.
  String? serverUpdated;

  /// Edited locally since the last successful push.
  bool dirty;

  SyncRecord(
      {required this.clientUpdated,
      this.deleted = false,
      this.serverUpdated,
      this.dirty = true});

  Map<String, dynamic> toJson();

  Map<String, dynamic> syncJson() => {
        'cu': clientUpdated,
        if (deleted) 'del': true,
        if (serverUpdated != null) 'su': serverUpdated,
        if (dirty) 'dirty': true,
      };

  void readSync(Map<String, dynamic> j) {
    clientUpdated = (j['cu'] as num?)?.toInt() ?? 0;
    deleted = j['del'] == true;
    serverUpdated = j['su'] as String?;
    dirty = j['dirty'] == true;
  }

  void touch(int now) {
    clientUpdated = now;
    dirty = true;
  }
}

/// One reciter's collection of marks — on a teacher's device there is one
/// per student.
class MarkBook extends SyncRecord {
  @override
  final String id;
  String name;
  final int createdAt;

  /// The server account that owns it (null while the book is local-only).
  String? ownerAccountId;
  BookRole myRole;

  /// Synced with the server (vs local-only).
  bool synced;

  MarkBook({
    required this.id,
    required this.name,
    required this.createdAt,
    this.ownerAccountId,
    this.myRole = BookRole.owner,
    this.synced = false,
    required super.clientUpdated,
    super.deleted,
    super.serverUpdated,
    super.dirty,
  });

  @override
  String get bookId => id;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        if (ownerAccountId != null) 'owner': ownerAccountId,
        'role': myRole.code,
        if (synced) 'synced': true,
        ...syncJson(),
      };

  factory MarkBook.fromJson(Map<String, dynamic> j) => MarkBook(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        ownerAccountId: j['owner'] as String?,
        myRole: BookRole.fromCode(j['role'] as String?),
        synced: j['synced'] == true,
        clientUpdated: 0,
      )..readSync(j);
}

/// One sitting: a listener hears the reciter read a range.
class RecitationSession extends SyncRecord {
  @override
  final String id;
  @override
  final String bookId;
  final String createdBy;
  final int startedAt;
  int? endedAt;
  String listenerName;
  SessionKind kind;

  /// 'uthmani' | 'indopak' — what the listener had open (pages are
  /// script-specific; the range below is not).
  String script;
  int? fromGlobalAyah;
  int? toGlobalAyah;
  String note;

  RecitationSession({
    required this.id,
    required this.bookId,
    required this.createdBy,
    required this.startedAt,
    this.endedAt,
    this.listenerName = '',
    this.kind = SessionKind.none,
    this.script = 'uthmani',
    this.fromGlobalAyah,
    this.toGlobalAyah,
    this.note = '',
    required super.clientUpdated,
    super.deleted,
    super.serverUpdated,
    super.dirty,
  });

  bool get isOpen => endedAt == null;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'book': bookId,
        'by': createdBy,
        'start': startedAt,
        if (endedAt != null) 'end': endedAt,
        if (listenerName.isNotEmpty) 'listener': listenerName,
        'kind': kind.code,
        'script': script,
        if (fromGlobalAyah != null) 'from': fromGlobalAyah,
        if (toGlobalAyah != null) 'to': toGlobalAyah,
        if (note.isNotEmpty) 'note': note,
        ...syncJson(),
      };

  factory RecitationSession.fromJson(Map<String, dynamic> j) =>
      RecitationSession(
        id: j['id'] as String,
        bookId: j['book'] as String,
        createdBy: j['by'] as String? ?? '',
        startedAt: (j['start'] as num?)?.toInt() ?? 0,
        endedAt: (j['end'] as num?)?.toInt(),
        listenerName: j['listener'] as String? ?? '',
        kind: SessionKind.fromCode(j['kind'] as String?),
        script: j['script'] as String? ?? 'uthmani',
        fromGlobalAyah: (j['from'] as num?)?.toInt(),
        toGlobalAyah: (j['to'] as num?)?.toInt(),
        note: j['note'] as String? ?? '',
        clientUpdated: 0,
      )..readSync(j);
}

/// A mark on one word (or, with word 0, a whole āyah).
class Mark extends SyncRecord {
  @override
  final String id;
  @override
  final String bookId;
  final String? sessionId;
  final WordRef ref;
  MarkType type;
  String comment;
  final String authorId;
  String authorName;
  final int createdAt;

  Mark({
    required this.id,
    required this.bookId,
    this.sessionId,
    required this.ref,
    required this.type,
    this.comment = '',
    required this.authorId,
    this.authorName = '',
    required this.createdAt,
    required super.clientUpdated,
    super.deleted,
    super.serverUpdated,
    super.dirty,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'book': bookId,
        if (sessionId != null) 'session': sessionId,
        's': ref.surah,
        'a': ref.ayah,
        'w': ref.word,
        'type': type.code,
        if (comment.isNotEmpty) 'comment': comment,
        'author': authorId,
        if (authorName.isNotEmpty) 'authorName': authorName,
        'at': createdAt,
        ...syncJson(),
      };

  factory Mark.fromJson(Map<String, dynamic> j) => Mark(
        id: j['id'] as String,
        bookId: j['book'] as String,
        sessionId: j['session'] as String?,
        ref: WordRef((j['s'] as num).toInt(), (j['a'] as num).toInt(),
            (j['w'] as num).toInt()),
        type: MarkType.fromCode(j['type'] as String?),
        comment: j['comment'] as String? ?? '',
        authorId: j['author'] as String? ?? '',
        authorName: j['authorName'] as String? ?? '',
        createdAt: (j['at'] as num?)?.toInt() ?? 0,
        clientUpdated: 0,
      )..readSync(j);
}

/// "This mark has since been fixed." Its own record, so a listener fixing a
/// mark and its author editing the comment can never overwrite each other.
class MarkFix extends SyncRecord {
  @override
  final String id;
  final String markId;
  @override
  final String bookId;
  final String? sessionId;
  final String fixedBy;
  String fixedByName;
  final int fixedAt;

  MarkFix({
    required this.id,
    required this.markId,
    required this.bookId,
    this.sessionId,
    required this.fixedBy,
    this.fixedByName = '',
    required this.fixedAt,
    required super.clientUpdated,
    super.deleted,
    super.serverUpdated,
    super.dirty,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'mark': markId,
        'book': bookId,
        if (sessionId != null) 'session': sessionId,
        'by': fixedBy,
        if (fixedByName.isNotEmpty) 'byName': fixedByName,
        'at': fixedAt,
        ...syncJson(),
      };

  factory MarkFix.fromJson(Map<String, dynamic> j) => MarkFix(
        id: j['id'] as String,
        markId: j['mark'] as String,
        bookId: j['book'] as String,
        sessionId: j['session'] as String?,
        fixedBy: j['by'] as String? ?? '',
        fixedByName: j['byName'] as String? ?? '',
        fixedAt: (j['at'] as num?)?.toInt() ?? 0,
        clientUpdated: 0,
      )..readSync(j);
}

/// A reply on a mark (listener ↔ reciter ↔ checker).
class MarkComment extends SyncRecord {
  @override
  final String id;
  final String markId;
  @override
  final String bookId;
  final String authorId;
  String authorName;
  String text;
  final int createdAt;

  MarkComment({
    required this.id,
    required this.markId,
    required this.bookId,
    required this.authorId,
    this.authorName = '',
    required this.text,
    required this.createdAt,
    required super.clientUpdated,
    super.deleted,
    super.serverUpdated,
    super.dirty,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'mark': markId,
        'book': bookId,
        'author': authorId,
        if (authorName.isNotEmpty) 'authorName': authorName,
        'text': text,
        'at': createdAt,
        ...syncJson(),
      };

  factory MarkComment.fromJson(Map<String, dynamic> j) => MarkComment(
        id: j['id'] as String,
        markId: j['mark'] as String,
        bookId: j['book'] as String,
        authorId: j['author'] as String? ?? '',
        authorName: j['authorName'] as String? ?? '',
        text: j['text'] as String? ?? '',
        createdAt: (j['at'] as num?)?.toInt() ?? 0,
        clientUpdated: 0,
      )..readSync(j);
}

/// Who is marking on this device.
class LocalIdentity {
  /// Author id on every record made here. Becomes the account id on sign-up.
  String id;
  String displayName;

  /// Set while signed in to the server.
  String? accountId;
  String? username;

  LocalIdentity({
    required this.id,
    this.displayName = '',
    this.accountId,
    this.username,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayName.isNotEmpty) 'name': displayName,
        if (accountId != null) 'account': accountId,
        if (username != null) 'username': username,
      };

  factory LocalIdentity.fromJson(Map<String, dynamic> j) => LocalIdentity(
        id: j['id'] as String? ?? newRecordId(),
        displayName: j['name'] as String? ?? '',
        accountId: j['account'] as String?,
        username: j['username'] as String?,
      );
}

/// How one word should look: the most important OPEN mark on it, whether
/// any mark on it has been fixed, and so on.
class MarkVisual {
  final MarkType? open;
  final bool fixed;
  final bool hasComment;
  final int count;
  const MarkVisual(
      {this.open, this.fixed = false, this.hasComment = false, this.count = 0});

  /// Display priority among open marks: most serious first.
  static const priority = [
    MarkType.mistake,
    MarkType.doubt,
    MarkType.tajwid,
    MarkType.hesitation,
    MarkType.note,
  ];

  @override
  bool operator ==(Object other) =>
      other is MarkVisual &&
      other.open == open &&
      other.fixed == fixed &&
      other.hasComment == hasComment &&
      other.count == count;
  @override
  int get hashCode => Object.hash(open, fixed, hasComment, count);
}
