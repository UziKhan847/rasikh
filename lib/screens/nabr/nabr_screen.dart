import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/nabr_content.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../shell/app_shell.dart' show openMushaf;
import 'nabr_widgets.dart';

/// The Nabr module: learn the stress rules chapter by chapter, practise
/// tapping the stressed letter, take the quiz, and read the colour guide —
/// from `assets/nabr/nabr_content.json`, in Arabic with English (see
/// [NabrContent]). Behind [kNabrEnabled]; reviewers see it with
/// [AppSettings.nabrPreview].
class NabrScreen extends StatefulWidget {
  const NabrScreen({super.key});

  @override
  State<NabrScreen> createState() => _NabrScreenState();
}

class _NabrScreenState extends State<NabrScreen> {
  late final Future<NabrContent> _content = NabrContent.load();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<NabrContent>(
      future: _content,
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) {
          return QScreen(title: l.nbTitle, children: [
            const SizedBox(height: 40),
            Center(child: CircularProgressIndicator(color: pal(context).acc)),
          ]);
        }
        final p = pal(context);
        Widget tile(IconData icon, String title, String sub, Widget Function() screen) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen())),
                child: Row(children: [
                  Icon(icon, color: p.acc),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                      Text(sub, style: uiStyle(context, size: 13, color: p.ink2)),
                    ]),
                  ),
                  Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
                ]),
              ),
            );
        return QScreen(
          title: l.nbTitle,
          children: [
            if (!kNabrEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: QTag(l.nbPreview, color: p.gold),
              ),
            QCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                BiText(c.title, size: 20, weight: FontWeight.w700),
                const SizedBox(height: 8),
                Text(l.nbBasedOn, style: uiStyle(context, size: 12, color: p.ink3)),
                BiText(c.basedOn, size: 14),
                if (c.riwaya.isNotEmpty)
                  Text(c.riwaya, style: uiStyle(context, size: 12, color: p.ink3)),
              ]),
            ),
            const SizedBox(height: 12),
            tile(AppIcons.quiz, l.nbPractice, '${l.nbPracticeSub} · ${c.drills.length}',
                () => NabrDrillScreen(content: c)),
            tile(AppIcons.check, l.nbQuiz, '${l.nbQuizSub} · ${c.quiz.length}',
                () => NabrQuizScreen(content: c)),
            tile(AppIcons.pageColour, l.nbColours, l.nbColoursSub,
                () => NabrColoursScreen(content: c)),
            QSectionLabel(l.nbLearn),
            for (final (pi, part) in c.parts.indexed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                child: BiText(part.title, size: 15, weight: FontWeight.w700),
              ),
              for (final (ci, ch) in part.chapters.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: QCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NabrChapterScreen(content: c, part: pi, chapter: ci))),
                    child: Row(children: [
                      Expanded(child: BiText(ch.title, size: 14.5)),
                      if (ch.ruleId != null) ...[
                        const SizedBox(width: 8),
                        QTag(ch.ruleId!),
                      ],
                    ]),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One chapter: its blocks in order, and the way on to the next.
class NabrChapterScreen extends StatelessWidget {
  final NabrContent content;
  final int part, chapter;
  const NabrChapterScreen(
      {super.key, required this.content, required this.part, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final ch = content.parts[part].chapters[chapter];
    final ar = !nabrShowsEnglish(context);
    // The next chapter, into the next part when this one ends.
    (int, int)? next;
    if (chapter + 1 < content.parts[part].chapters.length) {
      next = (part, chapter + 1);
    } else if (part + 1 < content.parts.length) {
      next = (part + 1, 0);
    }
    return QScreen(
      title: ar ? ch.title.ar : ch.title.en,
      kind: ContentKind.reading,
      children: [
        for (final b in ch.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: NabrBlockView(block: b, content: content),
          ),
        if (next case (final np, final nc))
          QPrimaryButton(context.l10n.nbNext,
              icon: AppIcons.chevronRight,
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => NabrChapterScreen(content: content, part: np, chapter: nc)))),
      ],
    );
  }
}

/// A lesson block, drawn by its type.
class NabrBlockView extends StatelessWidget {
  final NabrBlock block;
  final NabrContent content;
  const NabrBlockView({super.key, required this.block, required this.content});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final l = context.l10n;
    return switch (block) {
      NabrParagraph(:final text) => BiText(text),
      NabrSection(:final title) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: BiText(title, size: 18, weight: FontWeight.w700, color: p.acc),
        ),
      NabrRule(:final num, :final text) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.accSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.acc.withValues(alpha: .35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.nbRule(num), style: uiStyle(context, size: 12.5, weight: FontWeight.w700, color: p.accInk)),
            const SizedBox(height: 4),
            BiText(text, size: 16.5, weight: FontWeight.w600),
          ]),
        ),
      NabrNote(:final kind, :final text) => Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _noteColour(p, kind).withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: BorderDirectional(start: BorderSide(color: _noteColour(p, kind), width: 4)),
          ),
          child: BiText(text, size: 15),
        ),
      NabrExamples(:final items) => Column(children: [
          for (final e in items) _ExampleCard(e, content),
        ]),
      NabrTable(:final columns, :final rows) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: p.line2),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: p.accSoft),
                  children: [for (final c in columns) _cell(c, bold: true)],
                ),
                for (final r in rows) TableRow(children: [for (final c in r) _cell(c)]),
              ],
            ),
          ),
        ),
      NabrTakeaways(:final items) => QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(AppIcons.check, size: 16, color: p.acc),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: BiText(i, size: 15)),
                ]),
              ),
          ]),
        ),
      NabrPractice() => _PracticeSet(block as NabrPractice, content),
    };
  }

  static Color _noteColour(Palette p, String kind) => switch (kind) {
        'warning' => p.red,
        'summary' => p.acc,
        _ => p.gold,
      };

  Widget _cell(Bi c, {bool bold = false}) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: BiText(c, size: 13.5, weight: bold ? FontWeight.w700 : FontWeight.w400),
        ),
      );
}

class _ExampleCard extends StatelessWidget {
  final NabrExample e;
  final NabrContent content;
  const _ExampleCard(this.e, this.content);

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NabrWord(e.word),
          NabrTokenRow(
              tokens: e.tokens,
              stressed: e.stressed.toSet(),
              colour: nabrLevelColour(context, content, 'medium'),
              size: 26),
          const SizedBox(height: 8),
          if (!e.stressOn.isEmpty) BiText(e.stressOn, size: 14.5, weight: FontWeight.w700, color: p.accInk),
          BiText(e.why, size: 14.5),
        ]),
      ),
    );
  }
}

/// A worksheet: the words to try, then their answers on request.
class _PracticeSet extends StatefulWidget {
  final NabrPractice set;
  final NabrContent content;
  const _PracticeSet(this.set, this.content);

  @override
  State<_PracticeSet> createState() => _PracticeSetState();
}

class _PracticeSetState extends State<_PracticeSet> {
  bool _shown = false;

  Future<void> _openAyah((int, int) ref) async {
    const script = 'uthmani';
    await MushafRepo.ensure(script);
    if (!mounted) return;
    final page = MushafRepo.pageForGlobalAyah(script, MushafRepo.globalAyahOf(ref.$1, ref.$2));
    openMushaf(context, page: page, script: script);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final s = widget.set;
    return QCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(l.nbSet(s.set),
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
          ),
          if (s.ayahRef case final ref?)
            TextButton.icon(
              onPressed: () => _openAyah(ref),
              icon: const Icon(AppIcons.mushaf, size: 18),
              label: Text(l.nbOpenAyah),
            ),
        ]),
        Text(l.nbTryFirst, style: uiStyle(context, size: 13, color: p.ink3)),
        const SizedBox(height: 8),
        Wrap(
          textDirection: TextDirection.rtl,
          spacing: 14,
          runSpacing: 4,
          children: [for (final w in s.items) NabrWord(w, size: 26)],
        ),
        const SizedBox(height: 8),
        if (!_shown)
          QOutlineButton(l.nbReveal, icon: AppIcons.show, onTap: () => setState(() => _shown = true))
        else
          for (final e in s.answers) _ExampleCard(e, widget.content),
      ]),
    );
  }
}

/// Tap the stressed letter(s), one word at a time; a single-letter drill is
/// checked on the tap, a several-letter one with Check.
class NabrDrillScreen extends StatefulWidget {
  final NabrContent content;
  const NabrDrillScreen({super.key, required this.content});

  @override
  State<NabrDrillScreen> createState() => _NabrDrillScreenState();
}

class _NabrDrillScreenState extends State<NabrDrillScreen> {
  int _i = 0, _right = 0;
  final Set<int> _picked = {};
  bool _checked = false;

  List<NabrDrill> get _drills => widget.content.drills;

  bool get _correct {
    final d = _drills[_i];
    return _picked.length == d.correct.length && d.correct.every(_picked.contains);
  }

  void _tap(int t) {
    if (_checked) return;
    setState(() {
      if (!_picked.remove(t)) _picked.add(t);
      if (!_drills[_i].multi) _check();
    });
  }

  void _check() {
    _checked = true;
    if (_correct) _right++;
  }

  void _next() => setState(() {
        _i++;
        _picked.clear();
        _checked = false;
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    if (_i >= _drills.length) {
      return _Score(
          title: l.nbPractice,
          right: _right,
          total: _drills.length,
          onAgain: () => setState(() {
                _i = _right = 0;
                _picked.clear();
                _checked = false;
              }));
    }
    final d = _drills[_i];
    final colour = nabrLevelColour(context, widget.content, 'medium');
    return QScreen(
      title: '${l.nbPractice} · ${_i + 1}/${_drills.length}',
      kind: ContentKind.reading,
      children: [
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            NabrWord(d.word, size: 44),
            const SizedBox(height: 8),
            if (d.multi && !_checked)
              Text(l.nbPickAll, style: uiStyle(context, size: 13, color: p.ink3)),
            const SizedBox(height: 6),
            NabrTokenRow(
              tokens: d.tokens,
              colour: colour,
              size: 34,
              dimmed: d.nonSelectable.toSet(),
              // Checked: the stressed letters filled in; a wrong pick ringed red.
              stressed: _checked ? d.correct.toSet() : const {},
              onTap: _tap,
              ring: (i) => !_picked.contains(i)
                  ? null
                  : !_checked
                      ? p.acc
                      : d.correct.contains(i)
                          ? null
                          : p.red,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (!_checked && d.multi)
          QPrimaryButton(l.nbCheck,
              onTap: _picked.isEmpty ? null : () => setState(_check)),
        if (_checked) ...[
          Text(_correct ? l.nbRight : l.nbWrong,
              style: uiStyle(context,
                  size: 16, weight: FontWeight.w700, color: _correct ? p.acc : p.red)),
          const SizedBox(height: 6),
          QCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.nbAnswer, style: uiStyle(context, size: 12, color: p.ink3)),
              BiText(d.answer, weight: FontWeight.w700),
              const SizedBox(height: 6),
              Text(l.nbWhy, style: uiStyle(context, size: 12, color: p.ink3)),
              BiText(d.explanation, size: 15),
            ]),
          ),
          const SizedBox(height: 12),
          QPrimaryButton(l.nbNext, icon: AppIcons.chevronRight, onTap: _next),
        ],
      ],
    );
  }
}

/// The quiz: one question at a time, options shuffled where the content
/// allows, the explanation after each answer, the score at the end.
class NabrQuizScreen extends StatefulWidget {
  final NabrContent content;
  const NabrQuizScreen({super.key, required this.content});

  @override
  State<NabrQuizScreen> createState() => _NabrQuizScreenState();
}

class _NabrQuizScreenState extends State<NabrQuizScreen> {
  final _rng = Random();
  int _i = 0, _right = 0;
  int? _picked;
  late List<int> _order = _shuffle(0);

  List<NabrQuestion> get _qs => widget.content.quiz;

  List<int> _shuffle(int i) {
    if (i >= _qs.length) return const [];
    final o = [for (var k = 0; k < _qs[i].options.length; k++) k];
    if (_qs[i].shuffle) o.shuffle(_rng);
    return o;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    if (_i >= _qs.length) {
      return _Score(
          title: l.nbQuiz,
          right: _right,
          total: _qs.length,
          onAgain: () => setState(() {
                _i = _right = 0;
                _picked = null;
                _order = _shuffle(0);
              }));
    }
    final q = _qs[_i];
    return QScreen(
      title: '${l.nbQuiz} · ${_i + 1}/${_qs.length}',
      kind: ContentKind.reading,
      children: [
        QCard(child: BiText(q.prompt, size: 17, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final k in _order)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: QCard(
              padding: const EdgeInsets.all(12),
              color: _picked == null
                  ? null
                  : k == q.correct
                      ? p.accSoft
                      : k == _picked
                          ? p.red.withValues(alpha: .12)
                          : null,
              borderColor: _picked != null && k == q.correct ? p.acc : null,
              onTap: _picked != null
                  ? null
                  : () => setState(() {
                        _picked = k;
                        if (k == q.correct) _right++;
                      }),
              child: BiText(q.options[k], size: 15.5),
            ),
          ),
        if (_picked != null) ...[
          Text(_picked == q.correct ? l.nbRight : l.nbWrong,
              style: uiStyle(context,
                  size: 16, weight: FontWeight.w700, color: _picked == q.correct ? p.acc : p.red)),
          const SizedBox(height: 6),
          if (!q.explanation.isEmpty) QCard(child: BiText(q.explanation, size: 15)),
          const SizedBox(height: 12),
          QPrimaryButton(l.nbNext,
              icon: AppIcons.chevronRight,
              onTap: () => setState(() {
                    _i++;
                    _picked = null;
                    _order = _shuffle(_i);
                  })),
        ],
      ],
    );
  }
}

class _Score extends StatelessWidget {
  final String title;
  final int right, total;
  final VoidCallback onAgain;
  const _Score({required this.title, required this.right, required this.total, required this.onAgain});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return QScreen(title: title, children: [
      const SizedBox(height: 30),
      Center(
        child: Text(l.nbScore(right, total),
            style: displayStyle(context, size: 34, color: pal(context).acc)),
      ),
      const SizedBox(height: 24),
      QPrimaryButton(l.nbAgain, icon: AppIcons.reset, onTap: onAgain),
      const SizedBox(height: 10),
      QOutlineButton(l.nbDone, onTap: () => Navigator.of(context).maybePop()),
    ]);
  }
}

/// The colour guide: what each stress level's colour means, with examples,
/// and the modifiers.
class NabrColoursScreen extends StatelessWidget {
  final NabrContent content;
  const NabrColoursScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget level(NabrLevel lv) {
      final v = p.isDark ? lv.dark : lv.light;
      final colour = v == null ? p.ink3 : Color(v);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 10),
              Expanded(child: BiText(lv.name, size: 16, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            if (!lv.desc.isEmpty) BiText(lv.desc, size: 14.5),
            if (lv.style.isNotEmpty && nabrShowsEnglish(context))
              Text(lv.style, style: uiStyle(context, size: 12.5, color: p.ink3)),
            if (lv.examples.isNotEmpty)
              Wrap(
                textDirection: TextDirection.rtl,
                spacing: 16,
                children: [
                  for (final e in lv.examples)
                    Text(e,
                        style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 26, height: 1.8, color: colour)),
                ],
              ),
          ]),
        ),
      );
    }

    return QScreen(
      title: context.l10n.nbColours,
      kind: ContentKind.reading,
      children: [
        if (content.principle.isNotEmpty && nabrShowsEnglish(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(content.principle, style: uiStyle(context, size: 14, color: p.ink2, height: 1.5)),
          ),
        for (final lv in content.levels) level(lv),
        if (content.modifiers.isNotEmpty) ...[
          QSectionLabel(context.l10n.nbModifiers),
          for (final m in content.modifiers) level(m),
        ],
      ],
    );
  }
}
