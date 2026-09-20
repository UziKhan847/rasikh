import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/glyph_names.dart';
import 'package:qiraah_arabiyyah/screens/qaidah_screen.dart';

/// `hamzaCarrierQuestion` used to name ONE of the five hamza carriers
/// ("Which is Wāw with Hamzah?") and show all five glyphs as options — which
/// broke down for the seatless ء: "Which is Hamzah?" has no answer a learner
/// could deduce, since ء أ إ ؤ ئ are all, in a real sense, "a hamzah". It now
/// shows the glyph and asks for ITS name instead, which is answerable no
/// matter which of the five gets picked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext ctx;

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
  }

  testWidgets(
      'is answerable no matter which of the five carriers gets picked',
      (tester) async {
    await boot(tester);
    // Which carrier is picked is random — run enough times that the bare,
    // seatless ء (the one that used to break) is virtually certain to appear.
    for (var i = 0; i < 60; i++) {
      final q = hamzaCarrierQuestion(ctx);
      // A fixed, glyph-agnostic prompt — not one built from the target
      // carrier's own name, which is what made the bare ء case unanswerable.
      expect(q.prompt, ctx.l10n.qpWhichLetterIsThis);
      expect(q.arabic, isNotNull);
      expect(q.optionsAreArabic, isFalse);
      // The five NAMES are all textually distinct (unlike the five glyphs,
      // which are visually distinct but conceptually "all a hamzah"), so
      // there is exactly one right answer regardless of which glyph is shown.
      expect(q.options.toSet().length, q.options.length);
      expect(q.correct, inInclusiveRange(0, q.options.length - 1));
      expect(q.options[q.correct], letterNameOf(ctx, q.arabic!));
    }
  });
}
