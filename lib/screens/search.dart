import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/letters.dart';
import '../data/quran.dart';
import '../data/tajweed.dart';
import 'qaidah_screen.dart' show LetterDetail;
import 'quran_screen.dart' show SurahReaderScreen;
import 'tajweed_screen.dart' show TajwidRuleScreen;

/// One row of results — a letter, a tajwīd rule, or a sūrah. The same delegate
/// powers the desktop top-bar search and the mobile search pill.
enum SearchKind { letter, tajwid, surah }

class SearchHit {
  final SearchKind kind;
  final String title;
  final String subtitle;
  final String glyph; // Arabic to show in the leading chip
  final Color accent;
  final Object payload; // ArabicLetter | TajwidRule | SurahMeta
  const SearchHit(
      this.kind, this.title, this.subtitle, this.glyph, this.accent, this.payload);
}

const _letterColor = Color(0xFF12B886);
const _surahColor = Color(0xFF8E7DC4);

/// Fold Latin diacritics and drop hamza/ʿayn marks so plain typing matches the
/// transliterated names: "sad" → "Ṣād", "izhar" → "Iẓhār", "ha" → "Ḥā'".
String foldSearch(String s) {
  const map = {
    'ā': 'a', 'â': 'a', 'á': 'a', 'ä': 'a', 'à': 'a',
    'ī': 'i', 'î': 'i', 'í': 'i',
    'ū': 'u', 'û': 'u', 'ú': 'u',
    'ō': 'o', 'ô': 'o',
    'ē': 'e', 'ê': 'e',
    'ḥ': 'h', 'ḫ': 'h', 'ẖ': 'h',
    'ṣ': 's', 'š': 's', 'ş': 's',
    'ḍ': 'd', 'ḏ': 'd', 'ð': 'd',
    'ṭ': 't', 'ṯ': 't', 'ţ': 't',
    'ẓ': 'z', 'ż': 'z', 'ž': 'z',
    'ġ': 'g', 'ǧ': 'g',
    'ḳ': 'k',
    'ḷ': 'l', 'ṁ': 'm', 'ṃ': 'm', 'ṅ': 'n', 'ṇ': 'n', 'ñ': 'n', 'ṛ': 'r',
    'ʿ': '', 'ʾ': '', 'ʼ': '', '’': '', '\'': '', 'ʻ': '', '`': '',
    'ʔ': '', 'ʕ': '',
  };
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(map[ch] ?? ch);
  }
  return b.toString();
}

/// Rank matches across letters, tajwīd rules, and sūrahs. Learning content
/// (letters, then rules) is surfaced above the 114 sūrahs.
List<SearchHit> searchAll(
    BuildContext context, String rawQuery, List<SurahMeta> metas) {
  final raw = rawQuery.trim();
  final q = foldSearch(raw);
  bool hit(String hay) => q.isEmpty || foldSearch(hay).contains(q);
  final out = <SearchHit>[];

  for (final l in letters) {
    if (q.isEmpty || hit(l.name) || hit(l.translit) || l.char == raw) {
      final dots = dotsDesc(context, l.dotCount, l.dotPos);
      out.add(SearchHit(SearchKind.letter, letterName(context, l),
          context.l10n.letterSubtitle(l.translit, dots), l.char, _letterColor, l));
    }
  }
  for (final r in tajwidRules) {
    if (q.isEmpty || hit(r.name) || r.arabicName.contains(raw) || hit(r.trigger)) {
      out.add(SearchHit(
          SearchKind.tajwid, r.name, context.l10n.tajwidRule, r.arabicName, r.color, r));
    }
  }
  for (final m in metas) {
    if (q.isEmpty || hit(m.tname) || '${m.n}' == raw || m.name.contains(raw)) {
      out.add(SearchHit(SearchKind.surah, m.tname,
          context.l10n.surahSubtitle(m.n,
              m.type == 'meccan' ? context.l10n.meccan : context.l10n.medinan,
              m.ayahs),
          m.name, _surahColor, m));
    }
  }
  return out;
}

class GlobalSearch extends SearchDelegate<void> {
  /// The field's placeholder, resolved by the caller (a SearchDelegate getter
  /// has no BuildContext of its own).
  GlobalSearch(this._fieldLabel);

  final String _fieldLabel;

  @override
  String get searchFieldLabel => _fieldLabel;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              onPressed: () => query = '',
              icon: const Icon(Icons.clear_rounded)),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded));

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    return FutureBuilder<List<SurahMeta>>(
      future: QuranRepo.meta(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
              child: CircularProgressIndicator(color: pal(context).accent));
        }
        final hits = searchAll(context, query, snap.data!);
        if (hits.isEmpty) {
          return Center(
            child: Text(context.l10n.noMatchesFor(query.trim()),
                style: uiStyle(context, size: 14, color: pal(context).textDim)),
          );
        }
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final h = hits[i];
            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: h.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(h.glyph,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: 'ScheherazadeNew', fontSize: 22)),
              ),
              title: Text(h.title,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              subtitle: Text(h.subtitle,
                  style: uiStyle(context, size: 12, color: pal(context).textDim)),
              trailing: _kindBadge(context, h),
              onTap: () => _open(context, h),
            );
          },
        );
      },
    );
  }

  Widget _kindBadge(BuildContext context, SearchHit h) {
    final label = switch (h.kind) {
      SearchKind.letter => 'Letter',
      SearchKind.tajwid => context.l10n.tajwid,
      SearchKind.surah => context.l10n.surah,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: h.accent.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: uiStyle(context,
              size: 11, weight: FontWeight.w700, color: h.accent)),
    );
  }

  void _open(BuildContext context, SearchHit h) {
    close(context, null);
    final p = h.payload;
    if (p is SurahMeta) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SurahReaderScreen(meta: p)));
    } else if (p is ArabicLetter) {
      pushAdaptive(context, LetterDetail(letter: p));
    } else if (p is TajwidRule) {
      pushAdaptive(context, TajwidRuleScreen(rule: p));
    }
  }
}
