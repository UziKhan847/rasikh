import 'package:flutter_test/flutter_test.dart';
import 'package:rasikh/core/downloads.dart';

/// Pure-logic checks for the Downloads screen's data layer — no filesystem
/// or asset access, mirroring how `test/fetch_origin_test.dart` pins
/// `isQuranFoundationOrigin` in isolation.
void main() {
  group('downloadableReciters', () {
    test('offers exactly Al-ʿAfāsī and Al-Ḥuṣarī', () {
      expect(downloadableReciters, ['alafasy', 'husary']);
    });

    test('never offers Tunaiji — EveryAyah-only, licensing unconfirmed', () {
      expect(downloadableReciters.contains('tunaiji'), isFalse);
    });
  });

  group('classifyDl', () {
    test('nothing downloaded is none', () {
      expect(classifyDl(0, 286), DlState.none);
    });

    test('some but not all downloaded is partial', () {
      expect(classifyDl(1, 286), DlState.partial);
      expect(classifyDl(285, 286), DlState.partial);
    });

    test('every file present is full', () {
      expect(classifyDl(286, 286), DlState.full);
    });

    test('more on disk than expected (a stale/renumbered count) still reads as full, '
        'not partial', () {
      expect(classifyDl(300, 286), DlState.full);
    });

    test('a surah with zero total (degenerate input) is never "full" just because '
        'have is also zero', () {
      expect(classifyDl(0, 0), DlState.none);
    });
  });

  group('formatBytes', () {
    test('zero and negative are shown as 0 KB', () {
      expect(formatBytes(0), '0 KB');
      expect(formatBytes(-5), '0 KB');
    });

    test('sub-MB sizes round up to whole KB', () {
      expect(formatBytes(500), '1 KB');
      expect(formatBytes(2048), '2 KB');
    });

    test('MB range shows one decimal', () {
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes((1.5 * 1024 * 1024).round()), '1.5 MB');
    });

    test('GB range shows two decimals', () {
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
    });
  });
}
