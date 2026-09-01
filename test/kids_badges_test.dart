import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_profile_gate.dart';

/// Kids Mode badges used to be evaluated from exactly two call sites — the
/// letter-lesson result screen and the reading screen — so a badge tied to a
/// quiz or a reused Qāʿidah/Tajwīd stage could never fire, no matter how much
/// progress a child made there. `kidsSyncBadges` fixes that by running off
/// every change to the active child's `ProgressStore`, wired up once in
/// `KidsProfileGate`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ProgressStore.report() fires off an unawaited SharedPreferences write on
  // every call (see ProgressStore._save/_saveStreak) — needed even for the
  // plain (non-widget) tests below, or that write throws
  // MissingPluginException into the zone and fails the test despite every
  // assertion in it passing.
  SharedPreferences.setMockInitialValues({});

  group('kidsSyncBadges', () {
    test('is a no-op on a fresh store', () {
      final prog = ProgressStore(profileId: 'p_fresh');
      kidsSyncBadges(prog);
      expect(prog.badges, isEmpty);
      expect(prog.gems, 0);
    });

    test('unlocking a badge awards gems exactly once', () {
      final prog = ProgressStore(profileId: 'p_once');
      prog.report('kids.letter.ا', 3);
      kidsSyncBadges(prog);
      expect(prog.badges.contains('first_letter'), isTrue);
      expect(prog.gems, kidsGemsPerBadge);

      // Calling it again with nothing new must not re-award the same badge.
      kidsSyncBadges(prog);
      expect(prog.gems, kidsGemsPerBadge);
    });

    test('a badge tied to a QUIZ id unlocks, not only letter/reading ids',
        () {
      // This is the actual regression: before the fix, nothing ever called
      // unlockBadge for a quiz completion at all.
      final prog = ProgressStore(profileId: 'p_quiz');
      prog.report('kids.quiz.letters', 3);
      kidsSyncBadges(prog);
      expect(prog.badges.contains('first_quiz'), isTrue);
      expect(prog.badges.contains('perfect_quiz'), isTrue);
    });

    test('a badge tied to a reused Qāʿidah unit\'s .test id unlocks', () {
      final prog = ProgressStore(profileId: 'p_unit');
      prog.report('kids.harakat.test', 2); // not perfect, still a pass
      kidsSyncBadges(prog);
      expect(prog.badges.contains('harakat_cleared'), isTrue);
      expect(prog.badges.contains('first_quiz'), isTrue);
      expect(prog.badges.contains('perfect_quiz'), isFalse,
          reason: '2 stars is a pass, not a perfect mark');
    });

    // How to put a store into the state each badge is looking for. Keyed by
    // badge id and checked for completeness below, so adding a badge without
    // a way to earn it fails rather than silently going untested.
    final earnIt = <String, void Function(ProgressStore)>{
      // ── path ──
      for (final id in [
        'first_letter',
        'five_letters',
        'ten_letters',
        'halfway',
        'alphabet_master',
      ])
        id: (p) {
          for (final l in kidsLetterPath) {
            p.report('kids.letter.${l.char}', 3);
          }
        },
      'forms_cleared': (p) => p.report('kids.quiz.forms', 3),
      'forms_few_cleared': (p) {
        for (final l in kidsLetterPath) {
          p.report('kids.forms.more.${l.char}', 3);
        }
      },
      'special_shapes': (p) => p.report('kids.quiz.special', 3),
      'harakat_cleared': (p) => p.report('kids.harakat.test', 1),
      'shadda_cleared': (p) => p.report('kids.shadda.test', 1),
      'madd_cleared': (p) => p.report('kids.madd.test', 1),
      'tanwin_cleared': (p) => p.report('kids.tanwin.test', 1),
      'muqattaat_read': (p) => p.report('kids.muqattaat.test', 1),
      'solar_lunar': (p) => p.report('kids.solar_lunar.test', 1),
      'tamarbuta_cleared': (p) => p.report('kids.tamarbuta.test', 1),
      'waqf_cleared': (p) => p.report('kids.waqf.test', 1),
      'two_words': (p) => p.report('kids.words.two.read', 1),
      'three_words': (p) => p.report('kids.words.three.read', 1),
      'reached_tajwid': (p) => p.report('kids.tajwid.madd.learn', 1),
      'path_finished': (p) => p.report('kids.review.test', 1),
      'read_a_surah': (p) => p.report('kids.capstone.read', 1),
      // ── habit ──
      for (final id in ['streak_3', 'streak_7', 'streak_14', 'streak_30'])
        id: (p) => p.streakDays = 30,
      'full_week': (p) => p.weekMask = 0x7F, // every weekday active
      'five_in_a_day': (p) {
        for (final id in ['a', 'b', 'c', 'd', 'e']) {
          p.report('kids.probe.$id', 1);
        }
      },
      // ── mastery ──
      'first_quiz': (p) => p.report('kids.quiz.letters', 1),
      'perfect_quiz': (p) => p.report('kids.quiz.letters', 3),
      'ten_perfect': (p) {
        for (var i = 0; i < 10; i++) {
          p.report('kids.probe.$i', 3);
        }
      },
      for (final id in ['fifty_stars', 'hundred_stars'])
        id: (p) {
          for (var i = 0; i < 34; i++) {
            p.report('kids.probe.$i', 3);
          }
        },
      for (final id in ['level_5', 'level_10']) id: (p) => p.awardXp(1000),
    };

    test('every badge has a way to earn it written down here', () {
      final missing =
          kidsBadgeDefs().map((b) => b.id).where((id) => !earnIt.containsKey(id));
      expect(missing, isEmpty,
          reason: 'new badges with no reachability case — add one so they '
              'are actually covered by the test below');
    });

    test('every badge is reachable, and none is earned on a fresh store', () {
      for (final b in kidsBadgeDefs()) {
        final prog = ProgressStore(profileId: 'p_reach_${b.id}');
        expect(b.earned(prog), isFalse,
            reason: '${b.id}: earned on a fresh store — '
                'this predicate can never be usefully unlocked');
        earnIt[b.id]!(prog);
        expect(b.earned(prog), isTrue, reason: '${b.id} never became true');
      }
    });

    test('badge ids are unique', () {
      final ids = kidsBadgeDefs().map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('KidsProfileGate wiring', () {
    Future<AppSettings> boot() async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
      return settings;
    }

    testWidgets(
        'a quiz reported through the real gate unlocks its badge with no '
        'explicit sync call', (tester) async {
      final settings = await boot();
      late BuildContext inner;
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: KidsProfileGate(builder: (c) {
            inner = c;
            return const SizedBox();
          }),
        ),
      ));
      await tester.pumpAndSettle();

      final prog = ProgressScope.of(inner);
      expect(prog.badges, isEmpty);
      prog.report('kids.quiz.letters', 3);
      await tester.pump();

      expect(prog.badges.contains('first_quiz'), isTrue);
      expect(prog.badges.contains('perfect_quiz'), isTrue);
    });

    testWidgets('badge titles are non-empty in every supported locale',
        (tester) async {
      final settings = await boot();
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(SettingsScope(
          settings: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: locale,
            home: Builder(builder: (c) {
              for (final b in kidsBadgeDefs()) {
                expect(b.title(c), isNotEmpty,
                    reason: '${b.id} has no title in $locale');
              }
              return const SizedBox();
            }),
          ),
        ));
        await tester.pumpAndSettle();
      }
    });
  });
}
