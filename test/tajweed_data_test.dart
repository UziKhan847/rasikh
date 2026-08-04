import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/data/glyph_names.dart';
import 'package:qiraah_arabiyyah/data/tajweed.dart';

/// Every example verse must be built entirely from the bundled Uthmani text —
/// [VerseExample.plain] is the exact substring of `assets/quran/u/{s}.json`
/// at [VerseExample.ref], not a hand-retyped/simplified transcription. This
/// pins down a real bug: the original data used plain (Imlāʾī) orthography
/// that never matched the Uthmani script the rest of the app renders.
void main() {
  test('every tajwīd example is a verbatim substring of its Uthmani āyah', () {
    for (final rule in tajwidRules) {
      final ref = rule.example.ref;
      final parts = ref.split(':');
      final surah = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      final ayah = ayahs[ayahNum - 1];
      expect(ayah.contains(rule.example.plain), isTrue,
          reason: 'Rule "${rule.id}" example ($ref) is not a substring of '
              'the bundled Uthmani āyah.\n  example: ${rule.example.plain}\n'
              '  āyah:    $ayah');
    }
  });

  test('every tajwīd rule id is unique', () {
    final ids = tajwidRules.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every letters-keyed rule\'s letters are non-empty and unique within the rule', () {
    for (final rule in tajwidRules) {
      if (rule.letters.isEmpty) continue;
      final chars = rule.letters.split('');
      expect(chars.toSet().length, chars.length,
          reason: 'Rule "${rule.id}" repeats a letter in its letters field');
    }
  });

  testWidgets(
      'every tajwīd rule id has a real case in glyph_names.dart — guards the '
      '"_ => ghunnah" switch fallback silently mis-describing a new rule',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));
    await tester.pump();

    final ghunnah = tajwidRules.firstWhere((r) => r.id == 'ghunnah');
    final ghunnahTrig = tajwidTrigger(ctx, ghunnah);
    final ghunnahHow = tajwidHow(ctx, ghunnah);

    for (final rule in tajwidRules) {
      if (rule.id == 'ghunnah') continue;
      expect(tajwidTrigger(ctx, rule), isNot(equals(ghunnahTrig)),
          reason:
              'Rule "${rule.id}" falls through to ghunnah\'s trigger text — '
              'add a case for it in tajwidTrigger() in glyph_names.dart');
      expect(tajwidHow(ctx, rule), isNot(equals(ghunnahHow)),
          reason: 'Rule "${rule.id}" falls through to ghunnah\'s how text — '
              'add a case for it in tajwidHow() in glyph_names.dart');
    }
  });
}
