import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';

/// The card reader briefly offered a Madani typeface picker (UthmanicHafs vs
/// DigitalKhattV2); DigitalKhatt simply read better across the board — its
/// GPOS carries 276 lookups against UthmanicHafs' 21, visible on a dagger
/// alif crowded against a fatḥah — so the choice was dropped and DigitalKhatt
/// is now the reader's one Madani face, same as Indo-Pak's one face. These
/// check that both scripts resolve to a DigitalKhatt family with the line
/// height that family needs, and that the text each one loads is transcoded
/// for it — since "which font" here is not just a `fontFamily` swap, it
/// changes which codepoints the loaded text has to carry.
Future<AppSettings> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.desktopMode = 'off';
  return settings;
}

Widget _harness(AppSettings s, Widget child) => SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: ProgressStore(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: child,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('both scripts render with a DigitalKhatt face', (tester) async {
    final s = await _boot();
    late BuildContext ctx;
    await tester.pumpWidget(_harness(
        s,
        Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })));

    expect(s.quranScript, 'uthmani');
    var st = quranStyle(ctx);
    expect(st.fontFamily, 'DigitalKhattV2');
    expect(st.height, MushafRepo.khattLineHeight);

    s.quranScript = 'indopak';
    await tester.pump();
    st = quranStyle(ctx);
    expect(st.fontFamily, 'DigitalKhattIndoPak');
    expect(st.height, MushafRepo.khattLineHeight);
  });

  test('the reader loads text transcoded for DigitalKhattV2', () async {
    // 2:2 ends on هُدٗى — U+0657 in the shipped corpus, which DigitalKhattV2
    // has no glyph for, so the reader must be handed U+08F0 instead.
    final reader = await QuranRepo.ayahs(2, 'uthmani', font: 'DigitalKhattV2');
    expect(reader[1].contains('ࣰ'), isTrue);
    expect(reader[1].contains('ٗ'), isFalse);

    // And the untransformed default — still what Kids Mode's reading screen
    // and the downloads manager get, since neither renders through
    // DigitalKhattV2 — is unmoved.
    final plain = await QuranRepo.ayahs(2, 'uthmani');
    expect(plain[1].contains('ٗ'), isTrue);
    // Same characters, same words either way — the invariant tajwīd offsets
    // and word-by-word audio numbering rely on.
    expect(reader[1].length, plain[1].length);
    expect(QuranRepo.wordRanges(reader[1]), QuranRepo.wordRanges(plain[1]));
  });
}
