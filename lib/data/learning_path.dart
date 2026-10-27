import '../learn/qaidah/families.dart';

/// The Learning mode's step-by-step path: one lesson at a time — the
/// letters family by family, then the Qāʿidah's units — and a short quiz
/// after every [kPathQuizEvery] of them, on just those. The order is data
/// (this file), so the content review can reshape it without touching a
/// screen.

/// What a step teaches: a letter family's lesson (its id), a Qāʿidah unit
/// (its progress id), or a quiz on the steps before it.
enum PathKind { lesson, unit, quiz }

/// One step on the path. A quiz's [covers] are the steps it asks about.
class PathStep {
  final PathKind kind;
  final String id;
  final List<PathStep> covers;
  const PathStep(this.kind, this.id, [this.covers = const []]);

  /// Where the step's progress is kept ([ProgressStore] stars: any star is
  /// done). A lesson's are its own (its check gives them).
  String get progressId => switch (kind) {
        PathKind.lesson => familyById(id).progressId,
        PathKind.quiz => 'path.check.$id',
        PathKind.unit => 'path.unit.$id',
      };
}

const kPathQuizEvery = 6;

/// The steps to learn, in order (no quizzes).
List<PathStep> get pathItems => [
      for (final f in letterFamilies) PathStep(PathKind.lesson, f.id),
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

/// Whether [s] is done, by [starsFor].
bool pathStepDone(int Function(String id) starsFor, PathStep s) =>
    starsFor(s.progressId) > 0;
