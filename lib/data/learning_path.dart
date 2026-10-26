import 'letters.dart';

/// The Learning mode's step-by-step path: one thing at a time — the
/// letters, then the Qāʿidah's units — and a short quiz after every
/// [kPathQuizEvery] of them, on just those. The order is data (this file),
/// so the content review can reshape it without touching a screen.

/// What a step teaches: a letter (its char), a Qāʿidah unit (its progress
/// id), or a quiz on the steps before it.
enum PathKind { letter, unit, quiz }

/// One step on the path. A quiz's [covers] are the steps it asks about.
class PathStep {
  final PathKind kind;
  final String id;
  final List<PathStep> covers;
  const PathStep(this.kind, this.id, [this.covers = const []]);

  /// Where the step's progress is kept ([ProgressStore] stars: any star is
  /// done).
  String get progressId => 'path.${kind.name}.$id';
}

const kPathQuizEvery = 6;

/// The steps to learn, in order (no quizzes).
List<PathStep> get pathItems => [
      for (final l in letters) PathStep(PathKind.letter, l.char),
      for (final u in const [
        'qaidah.forms',
        'qaidah.harakat',
        'qaidah.tanwin',
        'qaidah.sukun',
        'qaidah.shadda',
        'qaidah.madd',
        'qaidah.words',
        'qaidah.wasl',
        'qaidah.muqattaat',
        'qaidah.review',
      ])
        PathStep(PathKind.unit, u),
    ];

/// The whole path: [pathItems] with a quiz after every [kPathQuizEvery],
/// and one on whatever is left at the end.
List<PathStep> learningPath() {
  final items = pathItems;
  final out = <PathStep>[];
  var since = <PathStep>[];
  for (final it in items) {
    out.add(it);
    since.add(it);
    if (since.length == kPathQuizEvery || it == items.last) {
      out.add(PathStep(PathKind.quiz, '${out.where((s) => s.kind == PathKind.quiz).length + 1}', since));
      since = [];
    }
  }
  return out;
}
