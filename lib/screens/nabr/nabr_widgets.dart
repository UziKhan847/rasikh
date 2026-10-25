import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/nabr_content.dart';

/// Whether to show the English beside the Arabic: everywhere but the
/// Arabic interface.
bool nabrShowsEnglish(BuildContext context) =>
    SettingsScope.of(context).language != 'ar';

final _md = RegExp(r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|\*(.+?)\*|(﴿[^﴾]*﴾)');

/// The content's markdown-lite as spans: `***both***`, `**bold**`,
/// `*italic*`, and Qurʾān quotes in ﴿ ﴾ set in the Qurʾān font.
List<InlineSpan> nabrSpans(String s, TextStyle base) {
  final out = <InlineSpan>[];
  var i = 0;
  for (final m in _md.allMatches(s)) {
    if (m.start > i) out.add(TextSpan(text: s.substring(i, m.start)));
    if (m[1] != null) {
      out.add(TextSpan(
          text: m[1],
          style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)));
    } else if (m[2] != null) {
      out.add(TextSpan(text: m[2], style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (m[3] != null) {
      out.add(TextSpan(text: m[3], style: const TextStyle(fontStyle: FontStyle.italic)));
    } else {
      out.add(TextSpan(
          text: m[4],
          style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: (base.fontSize ?? 15) * 1.15)));
    }
    i = m.end;
  }
  if (i < s.length) out.add(TextSpan(text: s.substring(i)));
  return out;
}

/// A text in Arabic (right to left) with its English underneath — or only
/// the Arabic, in the Arabic interface.
class BiText extends StatelessWidget {
  final Bi text;
  final double size;
  final FontWeight weight;
  final Color? color;
  const BiText(this.text,
      {super.key, this.size = 16, this.weight = FontWeight.w400, this.color});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final ink = color ?? p.ink;
    final ar = TextStyle(
        fontFamily: 'NotoNaskhArabic', fontSize: size + 1, height: 1.8, fontWeight: weight, color: ink);
    final en = uiStyle(context, size: size - 1.5, weight: weight, color: color ?? p.ink2, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text.ar.isNotEmpty)
          Text.rich(TextSpan(children: nabrSpans(text.ar, ar), style: ar),
              textDirection: TextDirection.rtl, textAlign: TextAlign.right),
        if (text.en.isNotEmpty && (nabrShowsEnglish(context) || text.ar.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(TextSpan(children: nabrSpans(text.en, en), style: en),
                textDirection: TextDirection.ltr),
          ),
      ],
    );
  }
}

/// The level colour for [id] ('strong', 'medium', 'weak', 'special') in
/// this theme.
Color nabrLevelColour(BuildContext context, NabrContent c, String id) {
  final l = c.level(id) ?? c.level('medium');
  final v = pal(context).isDark ? l?.dark : l?.light;
  return Color(v ?? 0xFF1565C0);
}

/// A word's letters as separate tiles, right to left, the stressed ones in
/// [colour] (brief §2.3: never joined back into one word here).
class NabrTokenRow extends StatelessWidget {
  final List<String> tokens;
  final Set<int> stressed;
  final Color colour;
  final Set<int> dimmed;

  /// Tapping a tile (drills); null: the row only shows.
  final ValueChanged<int>? onTap;

  /// Per tile: a ring drawn around it (a drill's selection or verdict).
  final Color? Function(int i)? ring;
  final double size;
  const NabrTokenRow({
    super.key,
    required this.tokens,
    this.stressed = const {},
    required this.colour,
    this.dimmed = const {},
    this.onTap,
    this.ring,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (i, t) in tokens.indexed)
          Opacity(
            opacity: dimmed.contains(i) ? .4 : 1,
            child: Material(
              color: stressed.contains(i) ? colour : p.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: ring?.call(i) ?? (stressed.contains(i) ? colour : p.line2),
                    width: ring?.call(i) != null ? 2.5 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap == null || dimmed.contains(i) ? null : () => onTap!(i),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: size * 1.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(t,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: size,
                            height: 1.7,
                            color: stressed.contains(i) ? Colors.white : p.ink)),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A Qurʾānic word, large.
class NabrWord extends StatelessWidget {
  final String word;
  final double size;
  const NabrWord(this.word, {super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => Text(word,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(
          fontFamily: 'UthmanicHafs', fontSize: size, height: 1.8, color: pal(context).ink));
}
