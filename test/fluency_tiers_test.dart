import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/fluency_tiers.dart';

import 'test_support.dart';

/// Every word of the plan's tiers is found as each muṣḥaf prints it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final script in ['uthmani', 'indopak']) {
    test('$script: every tier word found, in its own spelling', () async {
      await loadMushaf(script);
      final words = tierWords(script);
      final missing = [
        for (final list in fluencyTierLists)
          for (final l in list)
            if (!words.any((w) => w.label == l)) l
      ];
      expect(missing, isEmpty);
      String formOf(String label) => words.firstWhere((w) => w.label == label).form;
      expect(formOf('مِنْ'), isNot(formOf('مَنْ')));
      expect(formOf('خَالِدِينَ فِيهَا').split(' '), hasLength(2));
      // ignore: avoid_print
      if (script == 'uthmani') print(words.map((w) => '${w.label}→${w.form}').join('  '));
    });
  }
}
