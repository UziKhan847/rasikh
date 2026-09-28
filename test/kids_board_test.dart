import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/screens/kids/kids_board.dart';

/// The line-detection math shared by Three in a Row and Letter Bingo.
void main() {
  group('kidsBoardLines', () {
    test('a 3×3 board has 8 lines: 3 rows, 3 columns, 2 diagonals', () {
      final lines = kidsBoardLines(3);
      expect(lines, hasLength(8));
      expect(lines, contains(equals([0, 1, 2]))); // top row
      expect(lines, contains(equals([3, 4, 5]))); // middle row
      expect(lines, contains(equals([6, 7, 8]))); // bottom row
      expect(lines, contains(equals([0, 3, 6]))); // left column
      expect(lines, contains(equals([1, 4, 7]))); // middle column
      expect(lines, contains(equals([2, 5, 8]))); // right column
      expect(lines, contains(equals([0, 4, 8]))); // main diagonal
      expect(lines, contains(equals([2, 4, 6]))); // anti diagonal
    });

    test('a 4×4 board has 10 lines: 4 rows, 4 columns, 2 diagonals', () {
      final lines = kidsBoardLines(4);
      expect(lines, hasLength(10));
      expect(lines, contains(equals([0, 1, 2, 3])));
      expect(lines, contains(equals([12, 13, 14, 15])));
      expect(lines, contains(equals([0, 4, 8, 12])));
      expect(lines, contains(equals([3, 7, 11, 15])));
      expect(lines, contains(equals([0, 5, 10, 15])));
      expect(lines, contains(equals([3, 6, 9, 12])));
    });

    test('every line has n distinct cells, and no board index is missing '
        'from every row/column pair', () {
      for (final n in [3, 4, 5]) {
        final lines = kidsBoardLines(n);
        for (final line in lines) {
          expect(line.toSet(), hasLength(n), reason: 'n=$n: $line');
          for (final i in line) {
            expect(i, inInclusiveRange(0, n * n - 1));
          }
        }
      }
    });
  });

  group('kidsHasWinningLine', () {
    test('a full top row on a 3×3 board wins', () {
      const owned = {0, 1, 2};
      expect(kidsHasWinningLine(3, owned.contains), isTrue);
    });

    test('a full diagonal wins', () {
      const owned = {0, 4, 8};
      expect(kidsHasWinningLine(3, owned.contains), isTrue);
    });

    test('an almost-complete line does not win', () {
      const owned = {0, 1}; // missing index 2
      expect(kidsHasWinningLine(3, owned.contains), isFalse);
    });

    test('owning cells scattered across several lines, none complete, does '
        'not win', () {
      const owned = {0, 1, 3, 7}; // top-left corner-ish, no full line
      expect(kidsHasWinningLine(3, owned.contains), isFalse);
    });

    test('nothing owned never wins', () {
      expect(kidsHasWinningLine(3, (_) => false), isFalse);
    });

    test('a full 4×4 column wins', () {
      const owned = {1, 5, 9, 13};
      expect(kidsHasWinningLine(4, owned.contains), isTrue);
    });
  });
}
