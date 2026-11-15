import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/theme.dart';

/// [word]'s letters in order, without their ḥarakāt and signs (each place its
/// own button, a letter that comes twice twice).
List<String> wordLetters(String word) => [
      for (final c in word.runes)
        if (_isLetter(c)) String.fromCharCode(c),
    ];

bool _isLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) ||
    (c >= 0x0641 && c <= 0x064A) ||
    c == 0x066E ||
    c == 0x066F ||
    (c >= 0x0671 && c <= 0x06D3) ||
    c == 0x06D5 ||
    (c >= 0x06FA && c <= 0x06FC);

/// Buttons that put into a comment what's slow to type: the word it's about
/// and its letters, then the terms of the trade, those for [markType]'s kind
/// first.
class QuickInsertBar extends StatelessWidget {
  /// The word, as printed ('': a whole āyah, or no word: no first row).
  final String word;
  final MarkType? markType;
  final ValueChanged<String> onInsert;
  const QuickInsertBar(
      {super.key, required this.word, required this.markType, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final harakat = [
      l.qiFathah, l.qiKasrah, l.qiDammah, l.qiSukun, l.qiShaddah, l.qiTanwin,
    ];
    final mistakes = [
      l.qiWrongLetter, l.qiWrongHarakah, l.qiSkipped, l.qiAdded, l.qiRepeated, l.qiHesitated,
    ];
    final tajwid = [
      l.qiMadd, l.qiGhunnah, l.qiQalqalah, l.qiIdgham, l.qiIkhfa, l.qiTafkhim, l.qiTarqiq,
    ];
    final groups = switch (markType) {
      MarkType.tajwid => [tajwid, harakat, mistakes],
      _ => [mistakes, harakat, tajwid],
    };
    final letters = wordLetters(word);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (word.isNotEmpty)
          _Row(children: [
            _Chip(word, arabic: true, strong: true, onTap: () => onInsert(word)),
            for (final c in letters) _Chip(c, arabic: true, onTap: () => onInsert(c)),
          ]),
        _Row(children: [
          for (final (i, g) in groups.indexed) ...[
            if (i > 0)
              Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: pal(context).line2),
            for (final t in g) _Chip(t, onTap: () => onInsert(t)),
          ],
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final List<Widget> children;
  const _Row({required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final bool arabic, strong;
  final VoidCallback onTap;
  const _Chip(this.text, {this.arabic = false, this.strong = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: strong ? p.acc.withValues(alpha: .14) : p.line2.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          // The field keeps the keyboard's focus.
          canRequestFocus: false,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: arabic ? 10 : 9, vertical: arabic ? 2 : 6),
            child: Text(text,
                textDirection: arabic ? TextDirection.rtl : null,
                style: arabic
                    ? TextStyle(fontFamily: 'UthmanicHafs', fontSize: 19, color: p.ink, height: 1.3)
                    : uiStyle(context, size: 12.5, weight: FontWeight.w600, color: p.ink2)),
          ),
        ),
      ),
    );
  }
}
