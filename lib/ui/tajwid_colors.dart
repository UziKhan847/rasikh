import 'package:flutter/painting.dart';

/// Tajwīd rule colours, by rule index (see `QuranRepo.tajwid`): the
/// redesign's light set, or its night set on dark backgrounds. Shared by the
/// reader and the muṣḥaf.
List<Color> tajwidColorsForDark(bool dark) => dark ? _tjNight : _tjLight;

const _tjLight = <Color>[
  Color(0xFF1E8A86), // 0 ghunnah
  Color(0xFF1E8A86), // 1 idgham_g
  Color(0xFF6F8F8C), // 2 idgham_ng
  Color(0xFF3F7FC2), // 3 iqlab
  Color(0xFF2E9A7A), // 4 ikhfa
  Color(0xFF2E9A7A), // 5 ikhfa_shafawi
  Color(0xFF1E8A86), // 6 idgham_shafawi
  Color(0xFF2F6CA6), // 7 qalqalah
  Color(0xFFB4862C), // 8 madd2
  Color(0xFFC9682F), // 9 madd4 (muttasil)
  Color(0xFFC9682F), // 10 madd45 (munfasil)
  Color(0xFFB4483B), // 11 madd6 (lazim)
  Color(0xFFA7ABA3), // 12 shamsiyya
  Color(0xFFA7ABA3), // 13 silent
];

const _tjNight = <Color>[
  Color(0xFF5CC3BE),
  Color(0xFF5CC3BE),
  Color(0xFF8FB3AF),
  Color(0xFF8AB4E8),
  Color(0xFF6FCFAE),
  Color(0xFF6FCFAE),
  Color(0xFF5CC3BE),
  Color(0xFF7DAEDD),
  Color(0xFFD9AE55),
  Color(0xFFE39A62),
  Color(0xFFE39A62),
  Color(0xFFE07A6C),
  Color(0xFF5E6863),
  Color(0xFF5E6863),
];

/// Kept for callers outside the reader: the light set.
const tajwidRuleColors = _tjLight;
