import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/profiles.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/sync/memory_backend.dart';
import 'package:rasikh/core/sync/pocketbase_backend.dart';
import 'package:rasikh/core/sync/sync_engine.dart';

/// Profiles: the default one is what was here before (nothing moves); a
/// new one starts empty and picks its mode; switching back brings
/// everything back; deleting one takes its data with it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, MemoryMarksPersistence> disks;
  late AppSettings settings;
  late ProgressStore progress;
  late MarksStore marks;
  late ProfileStore profiles;

  setUp(() async {
    ProgressStore.profileSuffix = '';
    // An install from before profiles: a star, a bookmark, a page, a mark.
    SharedPreferences.setMockInitialValues({
      'noor.progress.v1': '{"qaidah.letters":3}',
      'noor.reading.v1': '{"page":245,"pageScript":"uthmani","marks":[[2,255]]}',
    });
    disks = {};
    MarksPersistence disk(String dir) =>
        disks.putIfAbsent(dir, MemoryMarksPersistence.new);
    settings = AppSettings();
    await settings.load();
    profiles = ProfileStore(persistenceFor: disk);
    await profiles.load(settings);
    progress = ProgressStore();
    await progress.load();
    marks = MarksStore(persistence: profiles.marksPersistence, saveDelay: Duration.zero);
    await marks.load();
    final b = marks.ensureActiveBook('Me');
    marks.addMark(b.id, const WordRef(2, 255, 1), MarkType.mistake);
    await marks.flush();
  });

  test('the default profile is the data from before', () {
    expect(profiles.profiles.single.id, ProfileStore.defaultId);
    expect(progress.starsFor('qaidah.letters'), 3);
    expect(progress.lastMushafPage, 245);
    expect(progress.isBookmarked(2, 255), isTrue);
    expect(disks.keys, ['marks']);
  });

  test('a new profile starts empty; back again, '
      'everything is as it was', () async {
    final x = await profiles.add('Aisha');
    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    expect(profiles.active.id, x.id);
    expect(progress.starsFor('qaidah.letters'), 0);
    expect(progress.lastMushafPage, isNull);
    expect(progress.bookmarks, isEmpty);
    expect(marks.ready, isTrue);
    expect(marks.books, isEmpty);

    progress.report('qaidah.forms', 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await profiles.switchTo(ProfileStore.defaultId,
        settings: settings, progress: progress, marks: marks);
    expect(progress.starsFor('qaidah.letters'), 3);
    expect(progress.starsFor('qaidah.forms'), 0);
    expect(progress.lastMushafPage, 245);
    expect(marks.activeBook?.name, 'Me');

    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    expect(progress.starsFor('qaidah.forms'), 2);
  });

  test('deleting a profile takes its data with it', () async {
    final x = await profiles.add('Bilal');
    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    progress.report('qaidah.forms', 2);
    final b = marks.ensureActiveBook('Bilal');
    marks.addMark(b.id, const WordRef(1, 1, 1), MarkType.doubt);
    await marks.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await profiles.switchTo(ProfileStore.defaultId,
        settings: settings, progress: progress, marks: marks);
    expect(disks[ProfileStore.marksDirOf(x.id)]!.files, isNotEmpty);
    await profiles.remove(x.id);
    expect(profiles.profiles.map((p) => p.id), [ProfileStore.defaultId]);
    expect(disks[ProfileStore.marksDirOf(x.id)]!.files, isEmpty);
    final p = await SharedPreferences.getInstance();
    expect(p.getKeys().where((k) => k.endsWith('@${x.id}')), isEmpty);
  });

  test('the profiles and the one in use persist', () async {
    final x = await profiles.add('Aisha');
    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    final again = ProfileStore(persistenceFor: profiles.persistenceFor);
    await again.load(settings);
    expect(again.active.id, x.id);
    expect(again.active.name, 'Aisha');
    expect(ProgressStore.profileSuffix, '@${x.id}');
    ProgressStore.profileSuffix = '';
  });

  test('each profile its own sign-in: switching, one account\'s books never '
      'reach the other\'s marks; a book shared with a student gets a code', () async {
    // Where each profile's session is kept: the first profile's where the
    // device's always was.
    expect(profiles.syncAuthKey, PocketBaseSyncBackend.authKeyFor(''));
    expect(profiles.syncAuthKey, 'noor.pb_auth');
    final server = MemoryServer();
    final sessions = {ProfileStore.defaultId: MemorySyncBackend(server)};
    final sync = SyncEngine(store: marks, backend: sessions[ProfileStore.defaultId]!);
    addTearDown(sync.dispose);
    Future<void> switchTo(String id) async {
      await sync.pause();
      await profiles.switchTo(id, settings: settings, progress: progress, marks: marks);
      await sync.replaceBackend(sessions.putIfAbsent(id, () => MemorySyncBackend(server)));
    }

    // The teacher: a book for a student, shared.
    await sync.signUp('ustadh', 'pw-ustadh-1');
    final ahmad = marks.createBook('Ahmad').id;
    marks.addMark(ahmad, const WordRef(1, 2, 1), MarkType.tajwid, comment: 'Madd');
    await sync.enableSync(ahmad);
    final code = (await sync.invite(ahmad, BookRole.checker)).code;
    expect(code, hasLength(8));
    expect(marks.book(ahmad)!.synced, isTrue);

    // Another profile on the device: signed out, none of the teacher's books.
    final x = await profiles.add('Aisha');
    await switchTo(x.id);
    expect(profiles.syncAuthKey, 'noor.pb_auth@${x.id}');
    expect(sync.signedIn, isFalse);
    expect(marks.book(ahmad), isNull);
    // Her own account, her own books: still not the teacher's.
    await sync.signUp('aisha', 'pw-aisha-1');
    await sync.syncNow();
    expect(marks.book(ahmad), isNull);
    expect(sync.account!.username, 'aisha');

    // Back: the teacher, signed in, the book there as it was.
    await switchTo(ProfileStore.defaultId);
    expect(sync.account!.username, 'ustadh');
    await sync.syncNow();
    expect(marks.book(ahmad)!.synced, isTrue);
    expect(marks.marksOf(ahmad), hasLength(1));

    // The student, on their own phone and account, joins with the code.
    final phone = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await phone.load();
    final theirs = SyncEngine(store: phone, backend: MemorySyncBackend(server));
    addTearDown(theirs.dispose);
    await theirs.signUp('ahmad', 'pw-ahmad-1');
    await theirs.join(code);
    expect(phone.book(ahmad)!.myRole, BookRole.checker);
    expect(phone.marksOf(ahmad).single.comment, 'Madd');
  });
}
