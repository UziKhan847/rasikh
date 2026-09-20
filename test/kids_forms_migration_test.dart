import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';

/// The Joining Shapes stage used to be one lesson per LETTER
/// (`kids.forms.more.<char>`, tracing every shape it has together); it is one
/// lesson per SHAPE now (`kids.forms.<ini|med|fin>.<char>`), so a single old
/// star cannot become three honestly earned ones. `ProgressStore.load()`
/// copies it onto every new shape id for that letter instead — the work it
/// represents really was done, and a child who finished a letter's joining
/// shapes before this changed should not be sent back to redo it.
void main() {
  test('an old per-letter forms star lands on every new per-shape id',
      () async {
    SharedPreferences.setMockInitialValues({
      'noor.progress.v1.p1': '{"kids.forms.more.ب": 3, "kids.forms.more.و": 2}',
    });
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    // بَاء joins both ways: all three new shape ids inherit the old mark.
    expect(prog.starsFor('kids.forms.ini.ب'), 3);
    expect(prog.starsFor('kids.forms.med.ب'), 3);
    expect(prog.starsFor('kids.forms.fin.ب'), 3);

    // Waw is a non-connector: only the one shape it really has.
    expect(prog.starsFor('kids.forms.fin.و'), 2);
    expect(prog.starsFor('kids.forms.ini.و'), 0);
    expect(prog.starsFor('kids.forms.med.و'), 0);
  });

  test('the migration never downgrades a star already earned under the new id',
      () async {
    SharedPreferences.setMockInitialValues({
      // A child who had already re-earned a perfect mark under the new id
      // before this migration ran (e.g. from an earlier partial rollout)
      // must not be knocked back down to the old, lower mark.
      'noor.progress.v1.p1':
          '{"kids.forms.more.ب": 1, "kids.forms.ini.ب": 3}',
    });
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    expect(prog.starsFor('kids.forms.ini.ب'), 3);
    // The two shapes untouched by the pre-existing new-id record still pick
    // up the migrated mark.
    expect(prog.starsFor('kids.forms.med.ب'), 1);
    expect(prog.starsFor('kids.forms.fin.ب'), 1);
  });

  test('a profile with no old-shape ids is untouched', () async {
    SharedPreferences.setMockInitialValues({
      'noor.progress.v1.p1': '{"kids.letter.ا": 3}',
    });
    final prog = ProgressStore(profileId: 'p1');
    await prog.load();

    expect(prog.starsFor('kids.letter.ا'), 3);
    expect(prog.starsFor('kids.forms.fin.ا'), 0);
  });
}
