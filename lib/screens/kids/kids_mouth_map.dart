import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/letters.dart';
import '../../data/makharij.dart';
import '../../widgets/common.dart' show TapScale, starsForFraction;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

/// The five places a sound is made, in the classical order from the chest to
/// the lips — plus the nose, where the hum of a ghunnah comes from.
const kidsZoneIds = ['jawf', 'halq', 'lisan', 'shafatan', 'khayshum'];

/// The plain-language name of [zone] — "Open mouth", "The Throat" — as a child
/// would say it, not the grown-up "oral cavity".
String kidsZoneName(BuildContext c, String zone) => switch (zone) {
  'jawf' => c.l10n.kidsZoneJawf,
  'halq' => c.l10n.mkZoneHalq,
  'lisan' => c.l10n.mkZoneLisan,
  'shafatan' => c.l10n.mkZoneShafatan,
  _ => c.l10n.kidsZoneKhayshum,
};

/// One line a child can act on with their own body: where to put a finger,
/// what to feel. It is the one thing a mouth map can teach with no recording.
String kidsZoneTip(BuildContext c, String zone) => switch (zone) {
  'jawf' => c.l10n.kidsZoneJawfTip,
  'halq' => c.l10n.kidsZoneHalqTip,
  'lisan' => c.l10n.kidsZoneLisanTip,
  'shafatan' => c.l10n.kidsZoneShafatanTip,
  _ => c.l10n.kidsZoneKhayshumTip,
};

String kidsZoneEmoji(String zone) => switch (zone) {
  'jawf' => '\u{1F62E}',
  'halq' => '\u{1F5E3}\uFE0F',
  'lisan' => '\u{1F445}',
  'shafatan' => '\u{1F444}',
  _ => '\u{1F443}',
};

Color kidsZoneColor(Palette p, String zone) => switch (zone) {
  'jawf' => p.accent2,
  'halq' => p.accent,
  'lisan' => const Color(0xFFE5739B),
  'shafatan' => p.amber,
  _ => const Color(0xFF8E7CC3),
};

/// The letters that live in [zone]. The open mouth holds the three madd
/// letters; the nose holds the two that hum; every other zone is read
/// straight off the classical table the grown-up Makhārij pages use, so the
/// two can never disagree.
List<String> kidsZoneLetters(String zone) => switch (zone) {
  'jawf' => const ['ا', 'و', 'ي'],
  'khayshum' => const ['ن', 'م'],
  _ => [
    for (final e in makhrajOfLetter.entries)
      if (makhrajById(e.value).zone == zone) e.key,
  ],
};

/// The place a tajwīd rule happens in, where it has one — so the rule card can
/// point at it on the same map the Mouth map teaches. Iẓhār is a throat-letter
/// rule; every ghunnah rule hums in the nose; the madd rules ring out through
/// the open mouth; the lip rules (a mīm sākinah, and iqlāb, which turns a nūn
/// into one) are the lips. Rules about a whole family of places (qalqalah, rā',
/// the lām rules) have no single one and get none.
String? kidsRuleZone(String ruleId) => switch (ruleId) {
  'izhar' => 'halq',
  'ghunnah' || 'idgham_g' || 'ikhfa' => 'khayshum',
  'idgham_ng' => 'lisan',
  'iqlab' ||
  'ikhfa_shafawi' ||
  'idgham_shafawi' ||
  'izhar_shafawi' => 'shafatan',
  'madd2' || 'madd4' || 'madd45' || 'madd6' => 'jawf',
  _ => null,
};

/// One question of the check: a letter and the zone it is made in, or the
/// nose question ("which one hums?") with its four candidate letters.
class KidsMouthQuestion {
  /// The letter asked about; null for the nose question.
  final String? letter;

  /// The right answer: a zone id for a letter question, a letter for the nose
  /// question.
  final String answer;

  /// The four choices, shuffled: zone ids, or letters for the nose question.
  final List<String> options;
  const KidsMouthQuestion({
    required this.letter,
    required this.answer,
    required this.options,
  });

  bool get isNose => letter == null;
}

/// Letters a question may be about, by zone. Wāw and yāʼ are left out — each
/// is made in one place as a letter and another as a madd — and so is hamzah,
/// which is not among the 28 a child has met.
const _askable = {
  'jawf': ['ا'],
  'halq': ['ه', 'ع', 'ح', 'غ', 'خ'],
  'lisan': [
    'ق',
    'ك',
    'ج',
    'ش',
    'ض',
    'ل',
    'ن',
    'ر',
    'ط',
    'د',
    'ت',
    'ص',
    'ز',
    'س',
    'ظ',
    'ذ',
    'ث', //
  ],
  'shafatan': ['ف', 'ب', 'م'],
};

/// The check: one question for the open mouth, the throat and the lips, two
/// for the tongue (it has by far the most letters), and one about the nose.
/// Letters the child has met are preferred; a zone with none of them draws
/// from all its letters rather than being left out.
List<KidsMouthQuestion> kidsMouthQuestions(Set<String> known, math.Random rng) {
  const zones = ['jawf', 'halq', 'lisan', 'lisan', 'shafatan'];
  final zoneOptions = ['jawf', 'halq', 'lisan', 'shafatan'];
  final used = <String>{};
  final out = <KidsMouthQuestion>[];
  for (final zone in zones) {
    final all = _askable[zone]!.where((l) => !used.contains(l)).toList();
    final mine = all.where(known.contains).toList();
    final pool = mine.isNotEmpty ? mine : all;
    final letter = pool[rng.nextInt(pool.length)];
    used.add(letter);
    out.add(
      KidsMouthQuestion(
        letter: letter,
        answer: zone,
        options: [...zoneOptions]..shuffle(rng),
      ),
    );
  }
  // The nose: one of the two humming letters among three that do not hum.
  final hummer = const ['ن', 'م'][rng.nextInt(2)];
  final others = [
    for (final l in letters)
      if (l.char != 'ن' &&
          l.char != 'م' &&
          _askable.values.any((v) => v.contains(l.char)))
        l.char,
  ]..shuffle(rng);
  out.add(
    KidsMouthQuestion(
      letter: null,
      answer: hummer,
      options: [hummer, ...others.take(3)]..shuffle(rng),
    ),
  );
  return out..shuffle(rng);
}

// ── the diagram ───────────────────────────────────────────────────────────

/// A side-on cartoon of a head facing left — the direction Arabic is read, so
/// a sound travels the way the eye does, from the throat on the right to the
/// lips on the left — with one tappable dot for each of the five places.
class KidsMouthDiagram extends StatelessWidget {
  /// The zone lit up, or null for none.
  final String? selected;
  final Set<String> seen;
  final ValueChanged<String>? onSelect;

  /// A picture, not a control: only the [selected] place is marked, and
  /// nothing can be tapped — for a card that points at one place.
  final bool interactive;
  const KidsMouthDiagram({
    super.key,
    required this.selected,
    this.onSelect,
    this.interactive = true,
    this.seen = const {},
  });

  /// Where each dot sits, as fractions of the diagram.
  static const _spots = {
    'jawf': Alignment(0.0, -0.08),
    'halq': Alignment(0.36, 0.60),
    'lisan': Alignment(-0.08, 0.22),
    'shafatan': Alignment(-0.64, 0.10),
    'khayshum': Alignment(-0.40, -0.40),
  };

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return AspectRatio(
      aspectRatio: 1.25,
      child: LayoutBuilder(
        builder: (context, box) {
          final dot = math.min(44.0, box.maxWidth * 0.14);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _MouthPainter(p, selected)),
              ),
              if (interactive)
                for (final z in kidsZoneIds)
                  Align(
                    alignment: _spots[z]!,
                    child: Semantics(
                      button: true,
                      label: kidsZoneName(context, z),
                      child: TapScale(
                        onTap: () => onSelect?.call(z),
                        child: _ZoneDot(
                          zone: z,
                          size: dot,
                          on: selected == z,
                          seen: seen.contains(z),
                        ),
                      ),
                    ),
                  )
              else if (selected != null)
                Align(
                  alignment: _spots[selected]!,
                  child: _ZoneDot(
                    zone: selected!,
                    size: dot,
                    on: true,
                    seen: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ZoneDot extends StatelessWidget {
  final String zone;
  final double size;
  final bool on;
  final bool seen;
  const _ZoneDot({
    required this.zone,
    required this.size,
    required this.on,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final c = kidsZoneColor(p, zone);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: on ? size * 1.15 : size,
      height: on ? size * 1.15 : size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? c : c.withValues(alpha: .28),
        shape: BoxShape.circle,
        border: Border.all(color: c, width: on ? 3 : 2),
        boxShadow: on
            ? [BoxShadow(color: c.withValues(alpha: .5), blurRadius: 12)]
            : null,
      ),
      child: Text(kidsZoneEmoji(zone), style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

class _MouthPainter extends CustomPainter {
  final Palette p;
  final String? selected;
  const _MouthPainter(this.p, this.selected);

  @override
  void paint(Canvas canvas, Size s) {
    // Paths are written in fractions of the box, so the drawing scales.
    Path shape(void Function(_Pen) draw) {
      final pen = _Pen(s);
      draw(pen);
      return pen.path;
    }

    final skin = p.amber.withValues(alpha: .30);
    final line = p.textDim.withValues(alpha: .55);
    Paint stroke([double w = 2.2]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = line;
    final inner = Paint()..color = p.surface.withValues(alpha: .92);

    // The head and neck, facing left.
    final head = shape((g) {
      g.move(.30, .09);
      g.curve(.40, -.02, .82, -.02, .90, .22); // top of the head
      g.curve(.97, .44, .90, .60, .86, .70); // back of the head
      g.line(.84, 1.0); // back of the neck
      g.line(.56, 1.0); // front of the neck
      g.curve(.56, .90, .50, .84, .40, .82); // under the jaw
      g.curve(.30, .82, .24, .78, .25, .70); // chin
      g.curve(.20, .68, .19, .62, .22, .58); // lower lip
      g.curve(.18, .55, .18, .49, .21, .46); // upper lip
      g.curve(.22, .42, .14, .40, .10, .34); // under the nose
      g.curve(.06, .29, .16, .24, .22, .22); // nose tip
      g.curve(.24, .16, .26, .12, .30, .09); // up to the brow
      g.path.close();
    });
    canvas.drawPath(head, Paint()..color = skin);
    canvas.drawPath(head, stroke());

    // The airway: an open wedge from the lips back to the throat, and the
    // throat itself running down — one shape, so they read as one passage.
    final airway = shape((g) {
      g.move(.215, .50);
      g.curve(.34, .43, .56, .43, .72, .50); // the roof of the mouth
      g.line(.76, 1.0); // the back of the throat
      g.line(.64, 1.0);
      g.line(.60, .72); // the front of the throat
      g.curve(.50, .68, .36, .64, .235, .56); // the floor of the mouth
      g.path.close();
    });
    canvas.drawPath(airway, inner);
    canvas.drawPath(airway, stroke(1.8));

    // The tongue.
    final tongue = shape((g) {
      g.move(.27, .575);
      g.curve(.37, .49, .52, .50, .64, .61); // the back of the tongue, arched
      g.curve(.58, .70, .42, .64, .27, .575); // resting on the floor
      g.path.close();
    });
    canvas.drawPath(
      tongue,
      Paint()..color = const Color(0xFFE5739B).withValues(alpha: .55),
    );

    // The nose passage, from the nostril over the roof of the mouth.
    final nose = shape((g) {
      g.move(.14, .32);
      g.curve(.30, .30, .60, .32, .70, .48);
    });
    canvas.drawPath(
      nose,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFF8E7CC3,
        ).withValues(alpha: selected == 'khayshum' ? .8 : .3),
    );

    // The eye, for company.
    canvas.drawCircle(
      Offset(.34 * s.width, .20 * s.height),
      s.width * .012,
      Paint()..color = line,
    );
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.selected != selected || old.p != p;
}

/// A path drawn in fractions of a box.
class _Pen {
  final Size size;
  final Path path = Path();
  _Pen(this.size);

  double _x(double f) => f * size.width;
  double _y(double f) => f * size.height;

  void move(double x, double y) => path.moveTo(_x(x), _y(y));
  void line(double x, double y) => path.lineTo(_x(x), _y(y));
  void curve(double x1, double y1, double x2, double y2, double x, double y) =>
      path.cubicTo(_x(x1), _y(y1), _x(x2), _y(y2), _x(x), _y(y));
}

// ── the lesson ────────────────────────────────────────────────────────────

/// **Mouth map.** Where in the mouth each letter is made — the one thing
/// about pronunciation that can be taught with no recording at all. A child
/// explores the map by tapping the five places (each lists its letters and
/// one thing to feel with their own hand), then answers a short check:
/// "where is this letter made?".
///
/// The letters in each place are the grown-up Makhārij table's own
/// (`makhrajOfLetter`), so this never disagrees with it.
class KidsMouthMapLesson extends StatefulWidget {
  final String progressId;
  final Set<String> known;
  final math.Random? rng;
  const KidsMouthMapLesson({
    super.key,
    required this.progressId,
    this.known = const {},
    this.rng,
  });

  @override
  State<KidsMouthMapLesson> createState() => _KidsMouthMapLessonState();
}

class _KidsMouthMapLessonState extends State<KidsMouthMapLesson> {
  late final List<KidsMouthQuestion> _questions = kidsMouthQuestions(
    widget.known,
    widget.rng ?? math.Random(),
  );
  // Step 0 is the map; each later step is one question.
  int _step = 0;
  int _right = 0;
  int _total = 0;
  bool _reported = false;

  bool get _done => _step > _questions.length;

  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_right / _total, kids: true);

  /// Files a letter question in the review queue: a miss the moment it
  /// happens, a promotion only for a first-try right answer. (The nose
  /// question has no card: its answer is a letter, not a place.)
  void _record(KidsMouthQuestion q, bool correct) {
    if (q.isNose) return;
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.mouth.${q.letter}',
      arabic: q.letter!,
      answer: kidsZoneName(context, q.answer),
      distractors: [
        for (final o in q.options)
          if (o != q.answer) kidsZoneName(context, o),
      ],
      optionsArabic: false,
    );
  }

  void _answer(KidsMouthQuestion q, bool firstTry) {
    _total++;
    if (firstTry) {
      _right++;
      _record(q, true);
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    if (_done && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _stars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _step,
      total: _questions.length + 1,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : _step == 0
          ? _Explore(onNext: () => setState(() => _step = 1))
          : _Check(
              key: ValueKey('q$_step'),
              question: _questions[_step - 1],
              onMiss: () => _record(_questions[_step - 1], false),
              onDone: (firstTry) => _answer(_questions[_step - 1], firstTry),
            ),
    );
  }
}

/// The map itself: tap a place to light it up and read what lives there.
class _Explore extends StatefulWidget {
  final VoidCallback onNext;
  const _Explore({required this.onNext});

  @override
  State<_Explore> createState() => _ExploreState();
}

class _ExploreState extends State<_Explore> {
  String? _zone;
  final Set<String> _seen = {};

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final zone = _zone;
    final ready = _seen.length == kidsZoneIds.length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.kidsMouthMapIntro,
            style: kidsStyle(context, size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: Geo.gapSm),
          // Capped: on a tablet or a desktop window the head would otherwise
          // grow to fill the width and push everything else off the screen.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: KidsMouthDiagram(
                selected: zone,
                seen: _seen,
                onSelect: (z) => setState(() {
                  _zone = z;
                  _seen.add(z);
                }),
              ),
            ),
          ),
          const SizedBox(height: Geo.gapSm),
          Container(
            padding: const EdgeInsets.all(Geo.gapMd),
            decoration: kidsCard(context),
            child: zone == null
                ? const SizedBox(height: 92)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            kidsZoneEmoji(zone),
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: Geo.gapSm),
                          Expanded(
                            child: Text(
                              kidsZoneName(context, zone),
                              style: kidsStyle(
                                context,
                                size: 17,
                                weight: FontWeight.w800,
                                color: kidsZoneColor(p, zone),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Geo.gapSm),
                      Wrap(
                        spacing: Geo.gapMd,
                        runSpacing: 4,
                        textDirection: TextDirection.rtl,
                        children: [
                          for (final l in kidsZoneLetters(zone))
                            Text(l, style: quranicStyle(context, size: 28)),
                        ],
                      ),
                      const SizedBox(height: Geo.gapSm),
                      Text(
                        kidsZoneTip(context, zone),
                        style: kidsStyle(context, size: 13, color: p.textDim),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: Geo.gapMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final z in kidsZoneIds)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _seen.contains(z)
                        ? kidsZoneColor(p, z)
                        : p.textDim.withValues(alpha: .25),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Geo.gapSm),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: ready ? widget.onNext : null,
            child: Text(context.l10n.kidsNextCard),
          ),
        ],
      ),
    );
  }
}

/// One question: a letter and four places, or four letters and "which one
/// hums?". On the shared check: a second try, a hint, then a reason.
class _Check extends StatelessWidget {
  final KidsMouthQuestion question;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _Check({
    super.key,
    required this.question,
    required this.onMiss,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    // Capped like the map: on a wide window the option tiles would otherwise
    // grow taller than the screen.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: KidsChoiceCard(
          prompt: q.isNose
              ? context.l10n.kidsWhichHumsNose
              : context.l10n.kidsWhereMade,
          display: q.isNose
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: Geo.gapMd),
                  decoration: kidsCard(context),
                  alignment: Alignment.center,
                  child: Text(
                    q.letter!,
                    style: quranicStyle(context, size: 64),
                  ),
                ),
          options: [
            for (final option in q.options)
              q.isNose
                  ? Text(option, style: quranicStyle(context, size: 40))
                  // Scaled down rather than wrapped: a translated name or a
                  // large font must shrink to fit its tile, never spill out.
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            kidsZoneEmoji(option),
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kidsZoneName(context, option),
                            textAlign: TextAlign.center,
                            style: kidsStyle(
                              context,
                              size: 13,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
          ],
          correct: q.options.indexOf(q.answer),
          aspect: q.isNose ? 1.5 : 1.7,
          hint: context.l10n.kidsHintMouth,
          // The answer is always a place, so the reason is always its tip:
          // where to put a hand and what to feel.
          explain: kidsZoneTip(context, q.isNose ? 'khayshum' : q.answer),
          onMiss: (_) => onMiss(),
          onDone: onDone,
        ),
      ),
    );
  }
}
