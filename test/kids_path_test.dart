import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_path.dart';

/// The Kids Mode curriculum, as data — the stage engine that replaced the
/// flat 28-letter list.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  return (settings, progress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext ctx;
  late AppSettings settings;
  late ProgressStore prog;

  Future<void> boot(WidgetTester tester) async {
    (settings, prog) = await _boot();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: prog,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ),
    ));
  }

  /// A stage's tracing lessons, without the check-up quizzes woven between
  /// them — those are `KidsItem`s too, but they open a `QuizScreen`.
  List<KidsItem> lessonsOf(String stage) => [
        for (final i in kidsPath(ctx).firstWhere((b) => b.id == stage).items(ctx))
          if (!i.id.startsWith('kids.check.')) i
      ];

  testWidgets('every stage has items, a title and its own subtitle',
      (tester) async {
    await boot(tester);
    final path = kidsPath(ctx);
    expect(path.length, greaterThan(8));
    for (final block in path) {
      expect(block.items(ctx), isNotEmpty, reason: block.id);
      expect(block.title(ctx), isNotEmpty, reason: block.id);
      expect(block.subtitle(ctx), isNotEmpty, reason: block.id);
      expect(block.badge, isNotEmpty, reason: block.id);
      // The sukūn stage shipped briefly with its subtitle used as its title
      // too, so the row read the same sentence twice.
      expect(block.subtitle(ctx), isNot(block.title(ctx)), reason: block.id);
    }
  });

  testWidgets('item ids are unique across the whole path', (tester) async {
    await boot(tester);
    final ids = [
      for (final block in kidsPath(ctx))
        for (final item in block.items(ctx)) item.id
    ];
    // Two stages sharing an id would mean clearing one silently clears the
    // other — the "fewer strokes" pass in particular must not be satisfied by
    // the "more strokes" one.
    expect(ids.toSet().length, ids.length);
  });

  testWidgets('the letters stage keeps its original progress ids',
      (tester) async {
    await boot(tester);
    final first = kidsPath(ctx).first;
    expect(first.id, 'letters');
    // Deliberately unchanged: anything already earned under these ids would
    // otherwise be orphaned by the path growing around it, and
    // `kidsLettersLearned` counts exactly this prefix.
    expect(first.items(ctx).map((i) => i.id).take(3),
        ['kids.letter.ا', 'kids.letter.ب', 'kids.letter.ت']);
  });

  testWidgets('a letter lesson traces the fewer-strokes shape five times',
      (tester) async {
    await boot(tester);
    final alif = kidsPath(ctx).first.items(ctx).first;
    final flow = alif.open(ctx) as KidsLetterFlow;

    // Meet the shape, say it, trace the beginner breakdown once, then write
    // it in fewer, longer strokes five times over — practice is repetition.
    expect(flow.introduce, isTrue);
    expect(flow.traces.map((t) => (t.levelId, t.repeat)),
        [('naskh_more', 1), ('naskh_few', 5)]);
  });

  testWidgets('a joining-forms lesson is built like a letter lesson',
      (tester) async {
    await boot(tester);
    final items =
        kidsPath(ctx).firstWhere((b) => b.id == 'forms.more').items(ctx);
    // Bāʼ joins on both sides, so it has all three connected shapes, and each
    // one gets the letters stage's own two passes: the beginner stroke
    // breakdown once, then the writing pass five times over.
    final ba = items.firstWhere((i) => i.id.endsWith('.ب'));
    final flow = ba.open(ctx) as KidsLetterFlow;
    expect(flow.introduce, isTrue);
    expect(flow.traces.map((t) => (t.levelId, t.form, t.repeat)), [
      ('naskh_more', 'ini', 1),
      ('naskh_few', 'ini', 5),
      ('naskh_more', 'med', 1),
      ('naskh_few', 'med', 5),
      ('naskh_more', 'fin', 1),
      ('naskh_few', 'fin', 5),
    ]);
  });

  testWidgets('the fewer-strokes stage is gone, not hidden', (tester) async {
    await boot(tester);
    // "Shapes Again" used to make the child meet all 28 letters' shapes a
    // second time, a whole quiz later. Its pass lives inside the joining-forms
    // lesson now, so the stage itself must not still be in the path.
    expect(kidsPath(ctx).map((b) => b.id), isNot(contains('forms.few')));
    for (final item in lessonsOf('forms.more')) {
      final flow = item.open(ctx) as KidsLetterFlow;
      expect(flow.traces.any((t) => t.levelId == 'naskh_few'), isTrue,
          reason: item.id);
    }
  });

  testWidgets('a long stage stops to check every five lessons', (tester) async {
    await boot(tester);
    for (final (stage, prefix) in [
      ('letters', 'kids.check.letters.'),
      ('forms.more', 'kids.check.forms.'),
    ]) {
      final items = kidsPath(ctx).firstWhere((b) => b.id == stage).items(ctx);
      // Five lessons, a check-up, five more, another — and the check-up is
      // cumulative, so the one at 10 covers everything from letter one.
      expect([
        for (var i = 0; i < items.length; i++)
          if (items[i].id.startsWith(prefix)) (i, items[i].id)
      ], [
        (5, '${prefix}5'),
        (11, '${prefix}10'),
        (17, '${prefix}15'),
        (23, '${prefix}20'),
        (29, '${prefix}25'),
      ], reason: stage);
      // 28 lessons + 5 check-ups, and nothing tacked onto the end: the
      // stage's own quiz is the very next stage.
      expect(items, hasLength(letters.length + 5), reason: stage);
      expect(items.last.id.startsWith(prefix), isFalse, reason: stage);
    }
  });

  testWidgets('a checkpoint id cannot be counted as a lesson', (tester) async {
    await boot(tester);
    // `kidsLettersLearned` and the joining-forms badge both count progress
    // ids by prefix. A checkpoint filed under one of those prefixes would
    // inflate the count it is not part of — 28 letters would "arrive" at 23.
    for (final block in kidsPath(ctx)) {
      for (final item in block.items(ctx)) {
        if (!item.id.startsWith('kids.check.')) continue;
        expect(item.id.startsWith('kids.letter.'), isFalse, reason: item.id);
        expect(item.id.startsWith('kids.forms.more.'), isFalse,
            reason: item.id);
      }
    }
    for (var i = 1; i <= 5; i++) {
      prog.report('kids.check.letters.$i', 3);
    }
    expect(prog.kidsLettersLearned, 0);
    expect(prog.countStarred('kids.forms.more.'), 0);
  });

  testWidgets('non-joiners are never asked for a shape they do not have',
      (tester) async {
    await boot(tester);
    final forms = lessonsOf('forms.more');
    expect(forms, hasLength(letters.length));
    // A dāl has no initial or medial shape, so its lesson must be shorter
    // than a bāʾ's rather than tracing a form that does not exist.
    final dal = forms.firstWhere((i) => i.id.endsWith('.د'));
    final ba = forms.firstWhere((i) => i.id.endsWith('.ب'));
    expect(dal.glyph, letterFor('د').finalForm);
    expect(ba.glyph, letterFor('ب').medial);
  });

  testWidgets('stages and tiles unlock in order as progress lands',
      (tester) async {
    await boot(tester);
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    final letters0 = kidsPath(ctx).first.items(ctx);
    expect(kidsCurrentItemIndex(prog, letters0), 0);

    prog.report('kids.letter.ا', 3);
    expect(kidsCurrentItemIndex(prog, letters0), 1);
    expect(kidsItemsDone(prog, letters0), 1);
    // Still on stage one — 27 letters to go.
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    for (final item in letters0) {
      prog.report(item.id, 3);
    }
    expect(kidsCurrentBlockIndex(ctx, prog), 1,
        reason: 'clearing every letter should open the letters quiz');
  });

  testWidgets(
      'devStage pins the current block for testing, without touching progress',
      (tester) async {
    await boot(tester);
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    // Ignored while the testing unlock is off — a corrupted or stale pref
    // must not silently move a real, non-testing session off alif.
    prog.setDevStage('forms.more');
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    prog.setUnlockAll(true);
    expect(kidsCurrentBlockIndex(ctx, prog), 2,
        reason: 'forms.more is the third stage in the path');
    expect(prog.xp, 0);
    expect(prog.gems, 0);
    expect(prog.kidsLettersLearned, 0,
        reason: 'jumping the display must not fake having cleared letters');

    // An id that no longer matches any stage falls back to real progress
    // rather than throwing or pointing nowhere.
    prog.setDevStage('not.a.real.stage');
    expect(kidsCurrentBlockIndex(ctx, prog), 0);

    // Turning the unlock back off drops the pin — it should not silently
    // keep steering a later, non-testing session.
    prog.setDevStage('forms.more');
    prog.setUnlockAll(false);
    expect(prog.devStage, isNull);
    expect(kidsCurrentBlockIndex(ctx, prog), 0);
  });

  testWidgets('the reused grown-up units resolve to real screens',
      (tester) async {
    await boot(tester);
    // The "reuse, don't re-author" half of the path: ḥarakāt onwards points at
    // the Qāʿidah units' own Learn and Test phases. A renamed unit progress id
    // would throw here rather than silently producing an empty stage.
    for (final id in [
      'harakat',
      'sukun',
      'shadda',
      'madd',
      'tanwin',
      'muqattaat',
      'words',
      'wasl',
      'solar_lunar', // the Tajwīd lām unit, placed with ٱل
      'waqf', // the Script & Symbols stopping unit
      'tajwid.madd',
      'tajwid.mim',
      'tajwid.nun',
      'tajwid.qalqalah',
      'tajwid.raa',
      'review',
    ]) {
      final block = kidsPath(ctx).firstWhere((b) => b.id == id);
      final items = block.items(ctx);
      expect(items, hasLength(2), reason: '$id: expected Learn + Test');
      expect(items.first.completeOnOpen, isTrue,
          reason: '$id: a Learn page has nothing to grade');
      expect(items.last.completeOnOpen, isFalse,
          reason: '$id: the quiz reports its own stars');
    }
  });

  testWidgets('the path follows the agreed Qāʿidah order', (tester) async {
    await boot(tester);
    final ids = kidsPath(ctx).map((b) => b.id).toList();
    int at(String id) {
      final i = ids.indexOf(id);
      expect(i, isNot(-1), reason: 'missing stage: $id');
      return i;
    }

    // Reading مٓ needs the six counts of madd lāzim; a child who met it
    // earlier could only imitate the sound.
    expect(at('muqattaat'), greaterThan(at('madd')));
    expect(at('madd'), greaterThan(at('harakat')));
    // Shaddah IS sukūn plus a moving letter, so it follows sukūn directly.
    expect(at('shadda'), greaterThan(at('sukun')));
    expect(at('forms.more'), greaterThan(at('letters')));
    // ٱل is the archetypal waṣl, so sun/moon letters come right after it.
    expect(at('solar_lunar'), greaterThan(at('wasl')));
    // Tāʼ marbūṭah's whole point is what happens when you stop, so the
    // stopping rules follow it.
    expect(at('waqf'), greaterThan(at('tamarbuta')));
    // One word, then two, then three.
    expect(at('words.two'), greaterThan(at('words')));
    expect(at('words.three'), greaterThan(at('words.two')));
    // Tajwīd last, and the capstone after everything.
    expect(at('tajwid.nun'), greaterThan(at('words.three')));
    expect(at('capstone'), ids.length - 1);
  });

  testWidgets('sun and moon letters are taught once, not twice',
      (tester) async {
    await boot(tester);
    final ids = kidsPath(ctx).map((b) => b.id).toList();
    // `solar_lunar` IS the grown-up Tajwīd lām unit, moved to where a Qāʿidah
    // actually teaches it. Listing that unit again in the tajwīd block would
    // make the child sit the same lesson twice.
    expect(ids.contains('tajwid.lam'), isFalse);
    expect(ids.contains('solar_lunar'), isTrue);
  });

  testWidgets('the special shapes stage covers the hamza carriers',
      (tester) async {
    await boot(tester);
    final ids = kidsPath(ctx)
        .firstWhere((b) => b.id == 'special')
        .items(ctx)
        .map((i) => i.id)
        .toList();
    // The characters the 28-letter alphabet leaves out but the muṣḥaf uses
    // constantly — they were missing from this stage when it first shipped.
    for (final ch in ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى']) {
      expect(ids, contains('kids.special.$ch'));
    }
  });

  testWidgets('reading stages ladder from two words to a whole sūrah',
      (tester) async {
    await boot(tester);
    for (final id in ['words.two', 'words.three', 'capstone']) {
      final items =
          kidsPath(ctx).firstWhere((b) => b.id == id).items(ctx);
      expect(items, hasLength(1), reason: id);
      expect(items.single.id, 'kids.$id.read');
      // Reading is graded by doing it, so it must NOT be marked done merely
      // for being opened.
      expect(items.single.completeOnOpen, isFalse, reason: id);
    }
  });
}
