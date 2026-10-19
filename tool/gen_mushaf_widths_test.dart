// Writes assets/quran/mushaf_line_em_<script>.json: every text line's
// natural width in em, measured with the bundled DigitalKhatt fonts, so the
// muṣḥaf doesn't shape each line once at runtime just to size the page.
//
//   flutter test tool/gen_mushaf_widths_test.dart
//
// Re-run after changing the muṣḥaf fonts or text; test/mushaf_widths_test.dart
// fails when the tables no longer match a live measurement.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

import '../test/shots/shots_test.dart' show loadFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate the muṣḥaf line-width tables', () async {
    await loadFonts();
    await QuranRepo.meta();
    for (final script in ['uthmani', 'indopak']) {
      await MushafRepo.ensure(script);
      final pages = <String, List<double>>{};
      final count = MushafRepo.pageCountSync(script);
      for (var p = 1; p <= count; p++) {
        final lines = MushafRepo.pageSync(script, p)!;
        pages['$p'] = [
          for (final l in lines)
            l.isText
                ? double.parse(
                    MushafGeometry.measureLineEm(script, l).toStringAsFixed(4))
                : 0,
        ];
      }
      File('assets/quran/mushaf_line_em_$script.json').writeAsStringSync(
          jsonEncode({
            'font': MushafRepo.fontFamily(script),
            'refPx': 44,
            'pages': pages,
          }));
      // ignore: avoid_print
      print('$script: $count pages');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
