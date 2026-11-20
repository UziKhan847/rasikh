import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/follow/follow_aligner.dart';
import 'package:rasikh/core/follow/follow_model.dart';
import 'package:rasikh/core/follow/follow_text.dart';

/// Following, without a model: the muṣḥaf's own words brought to the
/// model's letters, and the aligner fed what a reciter would be heard as.
void main() {
  // The muṣḥaf's words as the app lists them ('uthmani' tokens, the āyah
  // markers left out), with each word's sūrah and "s:a:w".
  final text = (jsonDecode(File('assets/quran/mushaf_u_text.json').readAsStringSync()) as List)
      .cast<String>();
  final meta = (jsonDecode(File('assets/quran/meta.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final raw = <String>[], surahs = <int>[], refs = <String>[];
  final firstOf = <String, int>{};
  var g = 0;
  for (final m in meta) {
    for (var a = 1; a <= (m['ayahs'] as int); a++) {
      final toks = text[g++].split('‌').where((t) => t.isNotEmpty).toList();
      firstOf['${m['n']}:$a'] = raw.length;
      for (var w = 0; w < toks.length - 1; w++) {
        raw.add(toks[w]);
        surahs.add(m['n'] as int);
        refs.add('${m['n']}:$a:${w + 1}');
      }
    }
  }
  final bare = [for (final w in raw) FollowText.word(w)];
  final surahOf = Uint8List.fromList(surahs);

  test('every word comes down to letters the model writes', () {
    expect(bare.length, 77432);
    final letters = FollowModel.vocabulary.replaceAll('<blk>', '').replaceAll('▁', '');
    final unknown = <String>{};
    for (final (i, w) in bare.indexed) {
      expect(w, isNotEmpty, reason: '${refs[i]} ${raw[i]}');
      for (final c in w.split('')) {
        if (!letters.contains(c)) unknown.add('$c ${refs[i]}');
      }
    }
    expect(unknown, isEmpty);
    // The model's spellings: no hamza seats, ة or ى; the dagger alif gone.
    expect(FollowText.word('ٱلصَّلَوٰةَ'), 'الصلوه');
    expect(FollowText.word('يُؤْمِنُونَ'), 'يومنون');
    expect(FollowText.words('ذلك▁الكتب ۚ لا'), ['ذلك', 'الكتب', 'لا']);
  });

  /// What a reciter from [from] is heard as, word by word: the last few
  /// words each time (the window), a word now and then misheard.
  Iterable<List<String>> heard(int from, int count, {int seed = 1, double garble = .15}) sync* {
    final rnd = math.Random(seed);
    final said = <String>[];
    for (var i = from; i < from + count; i++) {
      var w = bare[i];
      if (rnd.nextDouble() < garble && w.length > 2) {
        // A letter misheard.
        final k = rnd.nextInt(w.length);
        w = w.replaceRange(k, k + 1, 'ق');
      }
      said.add(w);
      // Two transcripts a word, the second with the word fully heard.
      final window = said.sublist(math.max(0, said.length - 6));
      yield [...window.sublist(0, window.length - 1), w.substring(0, (w.length + 1) ~/ 2)];
      yield window;
    }
  }

  test('reciting on: it keeps up a word or so behind, through a page and an āyah\'s end', () {
    final a = FollowAligner(bare, surahOf);
    final from = firstOf['2:1']!;
    a.setPosition(from);
    var last = from - 1;
    var i = 0;
    for (final h in heard(from, 120)) {
      for (final e in a.update(h)) {
        expect(e, isA<FollowProgress>(), reason: 'no jumps reciting on');
        final w = (e as FollowProgress).word;
        expect(w, greaterThan(last));
        last = w;
      }
      i++;
      // Never far behind the word being said.
      expect(from + i ~/ 2 - a.heard, lessThan(4), reason: 'at ${refs[from + i ~/ 2]}');
    }
    expect(a.heard, greaterThanOrEqualTo(from + 118));
  });

  test('starting elsewhere: found once two transcripts agree, not on one', () {
    final a = FollowAligner(bare, surahOf);
    a.setPosition(firstOf['2:1']!);
    for (final h in heard(firstOf['2:1']!, 12)) {
      a.update(h);
    }
    final there = firstOf['18:60']!;
    final events = <FollowEvent>[];
    var n = 0;
    for (final h in heard(there, 20, seed: 3)) {
      final e = a.update(h);
      events.addAll(e);
      n++;
      if (e.any((e) => e is FollowJump)) break;
    }
    final jump = events.whereType<FollowJump>().single;
    expect(refs[jump.word], startsWith('18:60:'));
    expect(n, lessThan(26), reason: 'found within a dozen words');
  });

  test('a long madd (one letter heard over and over) is no sign of being lost', () {
    final a = FollowAligner(bare, surahOf);
    a.setPosition(firstOf['2:1']!);
    for (var i = 0; i < 30; i++) {
      expect(a.update(['م']), isEmpty);
    }
    expect(a.lost, isFalse);
    // And on it goes.
    final events = [for (final h in heard(firstOf['2:2']!, 6)) ...a.update(h)];
    expect(events.whereType<FollowJump>(), isEmpty);
    expect(refs[a.heard], startsWith('2:2:'));
  });

  test('nothing to place it by: a whole transcript of another sūrah is found', () {
    final a = FollowAligner(bare, surahOf)..clearPosition();
    FollowEvent? first;
    for (final h in heard(firstOf['36:1']!, 12)) {
      final e = a.update(h);
      if (e.isNotEmpty) {
        first ??= e.first;
      }
    }
    expect(first, isA<FollowJump>());
    expect(refs[a.heard], startsWith('36:'));
  });

  // Page 11 (2:70–76) begins "قالوا ادع لنا ربك يبين لنا", and page 10
  // has it twice (2:68, 2:69): on page 11 it's 2:70, not one of those.
  final page11 = (firstOf['2:70']!, firstOf['2:77']! - 1);
  final page12 = (firstOf['2:77']!, firstOf['2:84']! - 1);
  final page10 = (firstOf['2:62']!, firstOf['2:70']! - 1);

  test('lost for a moment at the top of a page: the phrase found on the page, '
      'not the same words a page back', () {
    final a = FollowAligner(bare, surahOf)
      ..setPosition(firstOf['2:70']!)
      ..setView([page11, page12, page10]);
    // A hesitant start: nothing that matches.
    for (var i = 0; i < 8; i++) {
      a.update(['طلب', 'دن', 'الطلب']);
    }
    final events = [for (final h in heard(firstOf['2:70']!, 8)) ...a.update(h)];
    expect(events, isNotEmpty);
    expect(refs[a.heard], startsWith('2:70:'));
    for (final e in events) {
      final w = switch (e) { FollowProgress(:final word) || FollowJump(:final word) => word, _ => -1 };
      if (w >= 0) expect(refs[w], startsWith('2:70:'), reason: 'never back to 2:68 or 2:69');
    }
  });

  test('lost, with no page known: on from where they were, not back', () {
    final a = FollowAligner(bare, surahOf)..setPosition(firstOf['2:70']!);
    for (var i = 0; i < 8; i++) {
      a.update(['طلب', 'دن', 'الطلب']);
    }
    for (final h in heard(firstOf['2:70']!, 8)) {
      a.update(h);
    }
    expect(refs[a.heard], startsWith('2:70:'));
  });

  test('no idea where they are: of the same words all over, the page in view\'s', () {
    final a = FollowAligner(bare, surahOf)
      ..clearPosition()
      ..setView([page11, page12, page10]);
    for (final h in heard(firstOf['2:70']!, 10, garble: 0)) {
      a.update(h);
    }
    expect(refs[a.heard], startsWith('2:70:'));
    // The page in view the one before: there (2:68 or 2:69, which begin
    // alike, on it), not 2:70.
    final b = FollowAligner(bare, surahOf)
      ..clearPosition()
      ..setView([page10, page11]);
    for (final h in heard(firstOf['2:69']!, 10, garble: 0)) {
      b.update(h);
    }
    expect(b.heard, inInclusiveRange(page10.$1, page10.$2));
  });

  test('a transcript is aligned in well under a millisecond', () {
    final a = FollowAligner(bare, surahOf);
    final from = firstOf['3:1']!;
    a.setPosition(from);
    final all = heard(from, 400).toList();
    final sw = Stopwatch()..start();
    for (final h in all) {
      a.update(h);
    }
    final per = sw.elapsedMicroseconds / all.length;
    expect(per, lessThan(1000), reason: '$per µs each');
  });
}
