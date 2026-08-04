import 'package:flutter/material.dart';

/// Per-tab color identity, copied from the desktop reference. Each learning
/// area has its own hero gradient, kicker color, soft tint, and watermark —
/// so every screen reads as its own place while sharing one design language.
enum DeskTab { home, reader, qaidah, tracing, tashkil, tajwid, coach, script, qiraat, about }

class TabTint {
  final String kicker; // small caps label above the title
  final String title;
  final String blurb; // hero sub-line
  final List<Color> hero; // hero gradient
  final Color kickerColor; // section-header bar + kicker accent
  final Color soft; // faint tint for chips/badges (light theme)
  final Color softDark; // its dark/OLED counterpart (from the reference)
  final String watermark; // big faint Arabic glyph in the hero
  final IconData icon;
  final bool advanced;

  /// Listed in the sidebar but not open yet.
  final bool soon;
  const TabTint(this.kicker, this.title, this.blurb, this.hero, this.kickerColor,
      this.soft, this.watermark, this.icon,
      {this.advanced = false,
      this.soon = false,
      this.softDark = const Color(0xFF22262D)});

  /// Theme-aware soft tint: pastel in light mode, deep tinted in dark/OLED.
  Color softOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? softDark : soft;
}

const _mint = [Color(0xFF28D6A2), Color(0xFF11B98C)];
const _green = [Color(0xFF43B36A), Color(0xFF2E9B53)];
const _teal = [Color(0xFF23C5AE), Color(0xFF149C8B)];
const _coral = [Color(0xFFF08478), Color(0xFFE45F52)];
const _purple = [Color(0xFF8E7DC4), Color(0xFF6E5BB0)];
const _amber = [Color(0xFFD9A441), Color(0xFFB9832A)];

const Map<DeskTab, TabTint> kTint = {
  DeskTab.home: TabTint('Assalāmu ʿalaykum', 'Home',
      'Pick up where you left off, or explore a new corner of the path.',
      _mint, Color(0xFF0FA87E), Color(0xFFE4F6EF), 'قِرَاءَة',
      Icons.home_rounded, softDark: Color(0xFF0F241C)),
  DeskTab.reader: TabTint('Qur’an · 114 sūrahs', 'Qur’an Reader',
      'Read with word-by-word help, tajwīd colors, and recitation.',
      _mint, Color(0xFF0FA87E), Color(0xFFE4F6EF), 'ق',
      Icons.menu_book_rounded, softDark: Color(0xFF0F241C)),
  DeskTab.qaidah: TabTint('Foundations', 'Qaidah Path',
      'From your first letter to reading whole words — nine guided units.',
      _mint, Color(0xFF0FA87E), Color(0xFFE4F6EF), 'ب',
      Icons.account_tree_rounded, softDark: Color(0xFF0F241C)),
  DeskTab.tracing: TabTint('Handwriting', 'Tracing Studio',
      'Write each letter, stroke by stroke, following the glowing comet.',
      _coral, Color(0xFFE45F52), Color(0xFFFCE7E3), 'ب',
      Icons.gesture_rounded, softDark: Color(0xFF2A1512)),
  DeskTab.tashkil: TabTint('Vowels & marks', 'Tashkīl Lab',
      'Every ḥarakah and mark — how it sounds and how long to hold it.',
      _teal, Color(0xFF149C8B), Color(0xFFDFF5F1), 'بَ',
      Icons.auto_awesome_rounded, softDark: Color(0xFF0F241C)),
  DeskTab.tajwid: TabTint('Rules of recitation', 'Tajwīd Academy',
      'Each rule has a color. Learn the color, spot the rule anywhere.',
      _green, Color(0xFF2E9B53), Color(0xFFE1F3E7), 'ج',
      Icons.school_rounded, softDark: Color(0xFF123026)),
  DeskTab.coach: TabTint('Fluency for look-alikes', 'Reading Coach',
      'Same shape, different dots — drills until you read without a pause.',
      _coral, Color(0xFFE45F52), Color(0xFFFCE7E3), 'ث',
      Icons.remove_red_eye_rounded, softDark: Color(0xFF2A1512)),
  DeskTab.script: TabTint('Madani & Indo-Pak', 'Script & Symbols',
      'Every mark on the page — waqf signs, sajdah, and how the two scripts differ.',
      _amber, Color(0xFFB9832A), Color(0xFFF7ECD9), '۩',
      Icons.style_rounded, softDark: Color(0xFF2E2412)),
  DeskTab.qiraat: TabTint('The ten readings', 'Qirā’āt Hall',
      'The ten canonical readers, their cities, and their transmitters.',
      _purple, Color(0xFF7259B0), Color(0xFFEDE7F8), 'ط',
      Icons.layers_rounded,
      advanced: true,
      soon: true,
      softDark: Color(0xFF241E38)),
  DeskTab.about: TabTint('Qiraah Arabiyyah', 'About',
      'Learn to read the Qur’an — from your first letter to the ten Qirā’āt.',
      _mint, Color(0xFF0FA87E), Color(0xFFE4F6EF), 'ن',
      Icons.info_outline_rounded, softDark: Color(0xFF0F241C)),
};
