import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/memorize.dart';
import 'package:rasikh/core/recite_back.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';

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

  test('a finished page turns blank first, then revealing goes on', () {
    final m = MemorizeController.startAt(script, 2);
    final (_, end) = MushafRepo.pageTokens(script, 2);
    while (m.revealedEnd < end) {
      m.nextWord();
    }
    expect(m.viewPage, 2, reason: 'the last word is still being looked at');
    m.nextWord();
    expect(m.viewPage, 3, reason: 'the step turns the page');
    expect(m.revealedEnd, end, reason: '…and reveals nothing on it');
    expect(m.hideFromOn(3), end);
    m.nextWord();
    expect(m.revealedEnd, greaterThan(end), reason: 'then words come again');

    // Back: the first word hides and page 3 stays, blank; the next step
    // back turns to page 2, all of it still showing.
    m.prevWord();
    expect((m.viewPage, m.revealedEnd), (3, end));
    m.prevWord();
    expect((m.viewPage, m.revealedEnd), (2, end));
    m.prevWord();
    expect(m.revealedEnd, lessThan(end));
  });

  test('back an āyah stops at the page edge, then turns back', () {
    final m = MemorizeController.startAt(script, 3);
    final (first3, end3) = MushafRepo.pageTokens(script, 3);
    // Reveal page 3, turn, and reveal an āyah running onto page 4.
    while (m.revealedEnd < end3) {
      m.nextVerse();
    }
    m.nextWord(); // the turn
    m.nextVerse();
    expect(m.viewPage, 4);
    m.prevVerse();
    expect((m.viewPage, m.revealedEnd), (4, end3),
        reason: 'page 4 goes blank; page 3 is untouched');
    m.prevVerse();
    expect((m.viewPage, m.revealedEnd), (3, end3), reason: 'the turn back');
    m.prevVerse();
    expect(m.revealedEnd, lessThan(end3));
    expect(m.revealedEnd, greaterThanOrEqualTo(first3));
  });

  test('the next āyah turns first too, and a spread turns as one', () {
    final m = MemorizeController.startAt(script, 3)
      ..screenOf = (p) => p.isOdd ? (p, p + 1) : (p - 1, p);
    final (_, end3) = MushafRepo.pageTokens(script, 3);
    final (_, end4) = MushafRepo.pageTokens(script, 4);
    while (m.revealedEnd < end3) {
      m.nextVerse();
    }
    m.nextWord();
    expect(m.revealedEnd, greaterThan(end3),
        reason: 'page 4 is on screen too: no turn');
    while (m.revealedEnd < end4) {
      m.nextVerse();
    }
    expect(m.viewPage, 4);
    m.nextVerse();
    expect((m.viewPage, m.revealedEnd), (5, end4));
  });

  test('verse cards: a revealed āyah turns to the next card, blank', () {
    final m = MemorizeController.startAt(script, 2)..cards = true;
    final g = m.viewAyah;
    m.nextVerse();
    final end = m.revealedEnd;
    m.nextWord();
    expect((m.viewAyah, m.revealedEnd), (g + 1, end));
    m.nextWord();
    expect(m.revealedEnd, greaterThan(end));
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

  test('show and hide act on the page on screen, not where it started', () {
    final m = MemorizeController.startAt(script, 50);
    final (first52, end52) = MushafRepo.pageTokens(script, 52);
    m.revealPage(52);
    expect(m.revealedEnd, end52);
    expect(m.viewPage, 52, reason: 'it stays on the page shown');
    m.hidePage(52);
    expect(m.revealedEnd, first52);
    expect(m.viewPage, 52);
    expect(m.hideFromOn(51), -1, reason: 'pages before it stay shown');
  });

  test('starts from any āyah, the words before it showing', () {
    final g = MushafRepo.globalAyahOf(2, 7);
    final t = MushafRepo.tokenOf(script, g, 0);
    final m = MemorizeController.startAtToken(script, t);
    final page = MushafRepo.pageOfToken(script, t);
    expect(m.viewPage, page);
    expect(m.revealedEnd, t);
    expect(m.hideFromOn(page), t);
    m.nextWord();
    expect(tok(m.revealedEnd - 1), (g, 0));
  });

  test('tap zones: left goes on, right goes back; split by halves', () {
    const screen = Size(400, 800);
    const left = Offset(100, 200), right = Offset(300, 200);
    const lowLeft = Offset(100, 600), lowRight = Offset(300, 600);
    final m = MemorizeController.startAt(script, 2);
    final first = m.revealedEnd;
    m.tapStep('word', left, screen);
    m.tapStep('word', left, screen);
    final two = m.revealedEnd;
    m.tapStep('word', right, screen);
    expect(m.revealedEnd, lessThan(two));
    m.tapStep('verse', left, screen);
    expect(tok(m.revealedEnd - 1).$2, -1, reason: 'a whole āyah');
    final verse = m.revealedEnd;
    m.tapStep('split', left, screen); // top: a word
    expect(m.revealedEnd, verse + 1);
    m.tapStep('split', lowLeft, screen); // bottom: the āyah
    expect(tok(m.revealedEnd - 1).$2, -1);
    m.tapStep('split', lowRight, screen); // bottom, back: that āyah
    expect(m.revealedEnd, verse);
    m.tapStep('verse', right, screen);
    m.tapStep('verse', right, screen);
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
