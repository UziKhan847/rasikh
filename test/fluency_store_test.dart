import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';

/// The Reader's fluency work: marks per profile, cards retired after three
/// separate instant sessions, kept across a restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProgressStore.profileSuffix = '';
  });

  const a = WordRef(2, 30, 1), b = WordRef(2, 30, 2);

  test('marks toggle; visuals show both words of a pair', () async {
    final s = FluencyStore();
    await s.load();
    s.toggleSlow(a, 'وَإِذْ');
    s.togglePair(a, 'وَإِذْ قَالَ', 'join');
    s.setChunk(b, 'قَالَ', 1, 0);
    final v = s.visuals((r) => r == a ? b : null);
    expect(v[a.key], const FluencyVisual(slow: true, pairStart: true));
    expect(v[b.key], const FluencyVisual(pairEnd: true, chunk: true));
    s.toggleSlow(a, 'وَإِذْ');
    expect(s.isSlow(a), isFalse);
    s.setChunk(b, 'قَالَ', 0, 0);
    expect(s.markAt(FluencyKind.chunk, b), isNull);
  });

  test('instant on three separate days retires a card; slow starts over', () async {
    final s = FluencyStore();
    await s.load();
    var t = DateTime(2026, 10, 1, 9).millisecondsSinceEpoch;
    s.now = () => t;
    const day = 86400000;
    s.rate('f:x', Recall.instant);
    s.rate('f:x', Recall.instant); // the same day: once
    t += day;
    s.rate('f:x', Recall.instant);
    expect(s.progressOf('f:x')!.retired, isFalse);
    t += day;
    s.rate('f:x', Recall.slow);
    expect(s.progressOf('f:x')!.instantDays, isEmpty);
    for (var i = 0; i < 3; i++) {
      t += day;
      s.rate('f:x', Recall.instant);
    }
    expect(s.progressOf('f:x')!.retired, isTrue);
  });

  test('kept, and each profile its own', () async {
    final s = FluencyStore();
    await s.load();
    s.toggleSlow(a, 'وَإِذْ');
    s.addColdRead(const ColdRead(at: 1, firstTok: 10, lastTok: 60, script: 'uthmani', wordsCorrect: 42));
    s.markHeard(300);
    await s.flush();
    final again = FluencyStore();
    await again.load();
    expect(again.isSlow(a), isTrue);
    expect(again.coldReads.single.wordsCorrect, 42);
    expect(again.heard(300), isTrue);
    expect(again.heard(301), isFalse);
    // Another profile: nothing of this one's.
    ProgressStore.profileSuffix = '@p2';
    await again.reload();
    expect(again.isSlow(a), isFalse);
    expect(again.coldReads, isEmpty);
  });
}
