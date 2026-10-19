import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/memorize.dart';
import 'package:qiraah_arabiyyah/core/recite_back.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

import 'test_support.dart';

/// Memorize mode's cursor: word by word with the ۝ coming with an āyah's
/// last word, āyah by āyah, the rest of the page, back again; the page in
/// view turns only when a word on the next page is revealed. And the
/// recite-back cut: right after the last revealed word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  const script = 'uthmani';
  (int, int) tok(int t) => MushafRepo.tokenAt(script, t);

  test('starts hidden from the page; words reveal one by one, ۝ with the last',
      () {
    final m = MemorizeController.startAt(script, 2); // al-Baqarah 1–5
    final (first, end) = MushafRepo.pageTokens(script, 2);
    expect(m.revealedEnd, first);
    expect(m.hideFromOn(2), first);
    expect(m.hideFromOn(1), -1, reason: 'pages before show');
    expect(m.hideFromOn(3), MushafRepo.pageTokens(script, 3).$1);

    // 2:1 is الٓمٓ, one word: revealing it brings its ۝ along.
    m.nextWord();
    expect(tok(m.revealedEnd - 1).$2, -1, reason: 'the ۝ came with it');
    expect(m.revealedEnd, first + 2);
    expect(m.currentClip, (tok(first).$1, -1));

    // 2:2's first word only.
    m.nextWord();
    expect(tok(m.revealedEnd - 1), (tok(first).$1 + 1, 0));
    expect(m.currentClip, (tok(first).$1 + 1, 0));

    // The rest of 2:2, its ۝ included.
    m.nextVerse();
    expect(tok(m.revealedEnd - 1).$2, -1);
    expect(tok(m.revealedEnd).$1, tok(first).$1 + 2);
    expect(m.pageClips(), [(tok(first).$1, -1), (tok(first).$1 + 1, -1)]);

    // Back a word: the ۝ goes with the word it closed.
    m.prevWord();
    expect(tok(m.revealedEnd - 1).$2, isNot(-1));
    expect(tok(m.revealedEnd).$1, tok(first).$1 + 1);
    // Back the āyah: all of 2:2 hidden again.
    m.prevVerse();
    expect(m.revealedEnd, first + 2);

    // The rest of the page, then the view turns to the next.
    expect(m.viewPage, 2);
    m.nextPage();
    expect(m.revealedEnd, end);
    expect(m.viewPage, 3);
    expect(m.hideFromOn(2), -1);
    expect(m.hideFromOn(3), MushafRepo.pageTokens(script, 3).$1);
  });

  test('a finished page stays in view until the next page gets a word', () {
    final m = MemorizeController.startAt(script, 2);
    final (_, end) = MushafRepo.pageTokens(script, 2);
    while (m.revealedEnd < end) {
      m.nextWord();
    }
    expect(m.viewPage, 2, reason: 'the last word is still being looked at');
    m.nextWord();
    expect(m.viewPage, 3, reason: 'a word on page 3: the page turns');
    m.prevWord();
    expect(m.viewPage, 2);
  });

  test('show and hide the page', () {
    final m = MemorizeController.startAt(script, 50);
    final (first, end) = MushafRepo.pageTokens(script, 50);
    m.revealPage();
    expect(m.revealedEnd, end);
    expect(m.hideFromOn(50), -1);
    m.hidePage();
    expect(m.revealedEnd, first);
  });

  test('recite-back cuts after the last revealed word', () {
    // Rows: [word0, startMs, endMs]; words 3 and 4 run together (no row 3).
    const seg = [
      [0, 0, 900],
      [1, 1000, 1800],
      [2, 2100, 2900],
      [4, 3000, 4100],
      [5, 4300, 5000],
    ];
    expect(ReciteBack.cutMs(seg, 0), 900);
    expect(ReciteBack.cutMs(seg, 2), 2900);
    expect(ReciteBack.cutMs(seg, 3), 4100, reason: 'carried by the next row');
    expect(ReciteBack.cutMs(seg, 5), isNull, reason: 'the last: play it all');
    expect(ReciteBack.cutMs(null, 2), isNull);
  });
}
