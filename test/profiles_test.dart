import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/profiles.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';

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
    settings.appMode = 'hifz';
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

  test('a new profile starts empty and picks its mode; back again, '
      'everything is as it was', () async {
    final x = await profiles.add('Aisha');
    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    expect(profiles.active.id, x.id);
    expect(progress.starsFor('qaidah.letters'), 0);
    expect(progress.lastMushafPage, isNull);
    expect(progress.bookmarks, isEmpty);
    expect(marks.ready, isTrue);
    expect(marks.books, isEmpty);
    expect(settings.mode, isNull, reason: 'a new profile chooses its mode');

    progress.report('qaidah.forms', 2);
    settings.appMode = 'learn';
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await profiles.switchTo(ProfileStore.defaultId,
        settings: settings, progress: progress, marks: marks);
    expect(progress.starsFor('qaidah.letters'), 3);
    expect(progress.starsFor('qaidah.forms'), 0);
    expect(progress.lastMushafPage, 245);
    expect(marks.activeBook?.name, 'Me');
    expect(settings.mode, AppMode.hifz);

    await profiles.switchTo(x.id, settings: settings, progress: progress, marks: marks);
    expect(progress.starsFor('qaidah.forms'), 2);
    expect(settings.mode, AppMode.learn);
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
}
