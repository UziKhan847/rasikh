import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_rewards_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The Kids Mode shop used to sell three items that rendered nowhere once
/// bought — `shopOwned` was written to disk and read by exactly one widget,
/// the shop row's own "Owned" label. These tests are the guard against that
/// regression: a purchase has to actually change something the child can
/// see, not just a boolean in a set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('buying', () {
    test('deducts gems exactly once and only when affordable', () {
      final prog = ProgressStore(profileId: 'p_buy');
      prog.awardGems(100);
      expect(prog.buyShopItem('golden_frame', 100), isTrue);
      expect(prog.gems, 0);
      expect(prog.shopOwned.contains('golden_frame'), isTrue);

      // Already owned: refused even with plenty of gems.
      prog.awardGems(1000);
      expect(prog.buyShopItem('golden_frame', 100), isFalse);
      expect(prog.gems, 1000);
    });

    test('a consumable has no ownership gate — buying twice is allowed', () {
      final prog = ProgressStore(profileId: 'p_consumable');
      prog.awardGems(200);
      expect(prog.buyStreakFreeze(40), isTrue);
      expect(prog.buyStreakFreeze(40), isTrue);
      expect(prog.streakFreezes, 2);
      expect(prog.gems, 120);
    });
  });

  group('equipping', () {
    late KidsProfile profile;
    late BuildContext ctx;

    Future<void> boot(WidgetTester tester) async {
      profile = KidsProfile(id: 'p1', name: 'Sara');
      final settings = AppSettings();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));
    }

    testWidgets('a frame maps to the frame slot, a theme to the theme slot',
        (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      expect(kidsItemEquipped(items['golden_frame']!, profile), isFalse);
      kidsEquipItem(items['golden_frame']!, profile);
      expect(profile.frame, 'golden_frame');
      expect(kidsItemEquipped(items['golden_frame']!, profile), isTrue);
      // Equipping a frame must not touch the theme slot.
      expect(profile.theme, 'kids');

      // A second frame replaces the first rather than stacking.
      kidsEquipItem(items['emerald_frame']!, profile);
      expect(profile.frame, 'emerald_frame');
      expect(kidsItemEquipped(items['golden_frame']!, profile), isFalse);

      kidsEquipItem(items['kids_ocean']!, profile);
      expect(profile.theme, 'kids_ocean');
    });

    testWidgets('the avatar unlock sets profile.avatar to its own emoji',
        (tester) async {
      await boot(tester);
      final camel =
          kidsShopItems(ctx).firstWhere((i) => i.id == 'camel_avatar');
      final original = profile.avatar;
      expect(kidsAvatarUnlock('camel_avatar'), isNotNull);

      kidsEquipItem(camel, profile);
      expect(profile.avatar, kidsAvatarUnlock('camel_avatar'));
      expect(profile.avatar, isNot(original));
      expect(kidsItemEquipped(camel, profile), isTrue);
    });

    testWidgets('a frame can be taken back off; a theme or avatar cannot',
        (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      expect(kidsItemUnequippable(items['golden_frame']!), isTrue);
      expect(kidsItemUnequippable(items['kids_ocean']!), isFalse);
      expect(kidsItemUnequippable(items['camel_avatar']!), isFalse);

      kidsEquipItem(items['golden_frame']!, profile);
      kidsUnequipItem(items['golden_frame']!, profile);
      expect(profile.frame, isEmpty);
    });

    testWidgets('every Looks item resolves to a real, rendering cosmetic',
        (tester) async {
      await boot(tester);
      // The retirement guard. A Looks item has to be either a frame ring or
      // an avatar swap — the only two decorations that survive an emoji
      // avatar at every size it renders at. Anything else (a hat, a cape
      // drawn on) reads as a rendering artefact and shipped once already.
      for (final item in kidsShopItems(ctx)
          .where((i) => i.shelf == KidsShopShelf.looks)) {
        final isFrame = kidsFrameColor(item.id) != null;
        final isAvatar = kidsAvatarUnlock(item.id) != null;
        expect(isFrame || isAvatar, isTrue,
            reason: '${item.id} equips nothing that KidsAvatar can draw');
      }
      // Retired ids, each for its own reason: the hat could not be drawn
      // legibly beside an emoji avatar, and the cape/falcon/dragon were
      // fantasy and heraldic imagery that has no place in a Qurʼān app.
      for (final retired in [
        'falcon_hat',
        'star_cape',
        'falcon_avatar',
        'dragon_avatar',
      ]) {
        expect(kidsShopItems(ctx).any((i) => i.id == retired), isFalse,
            reason: '$retired was retired, not repurposed');
      }
    });

    testWidgets('a bought frame actually renders around KidsAvatar',
        (tester) async {
      await boot(tester);
      profile.frame = 'golden_frame';
      await tester.pumpWidget(MaterialApp(
        home: KidsAvatar(profile: profile),
      ));

      // Presence of a circular border is the whole point — before this, an
      // owned frame changed nothing a widget test (or a child) could see.
      final container = tester.widget<Container>(find
          .descendant(
              of: find.byType(KidsAvatar), matching: find.byType(Container))
          .first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect((decoration.border as Border).top.color,
          kidsFrameColor('golden_frame'));
    });

    testWidgets('a bought theme changes what kidsPal resolves to',
        (tester) async {
      final settings = AppSettings();
      final child = KidsProfile(id: 'p1', name: 'Sara');
      settings.addKidsProfile(child);
      late BuildContext inner;
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Builder(builder: (c) {
            inner = c;
            return const SizedBox();
          }),
        ),
      ));
      final before = kidsPal(inner);

      settings.update(() => child.theme = 'kids_ocean');
      await tester.pump();
      // AppSettings.update() debounces its disk write behind a Timer; let it
      // fire before the test ends, or the framework flags it as still
      // pending after the widget tree is torn down.
      await tester.pump(const Duration(milliseconds: 300));
      final after = kidsPal(inner);

      expect(after.accent, isNot(before.accent));
      expect(after, paletteFor('kids_ocean', settings.kidsThemeMode));
    });
  });

  group('per-profile isolation', () {
    test('two profiles do not share shop purchases', () {
      final a = ProgressStore(profileId: 'p_iso_a');
      final b = ProgressStore(profileId: 'p_iso_b');
      a.awardGems(100);
      a.buyShopItem('golden_frame', 100);

      expect(a.shopOwned.contains('golden_frame'), isTrue);
      expect(b.shopOwned.contains('golden_frame'), isFalse);
      expect(b.gems, 0);
    });

    test('two profiles do not share equipped cosmetics', () {
      final a = KidsProfile(id: 'a', name: 'Sara');
      final b = KidsProfile(id: 'b', name: 'Yusuf');

      a.frame = 'golden_frame';
      expect(b.frame, isEmpty);
      a.theme = 'kids_ocean';
      expect(b.theme, 'kids');
    });
  });

  group('KidsProfile persistence', () {
    test('theme/frame round-trip through toJson/fromJson', () {
      final p = KidsProfile(
          id: 'p1',
          name: 'Sara',
          theme: 'kids_desert',
          frame: 'golden_frame');
      final restored = KidsProfile.fromJson(p.toJson());
      expect(restored.theme, 'kids_desert');
      expect(restored.frame, 'golden_frame');
    });

    test('a profile saved with the retired hat key still loads', () {
      final restored = KidsProfile.fromJson({
        'id': 'p1',
        'name': 'Sara',
        'avatar': '🦊',
        'gender': '',
        'theme': 'kids',
        'frame': 'golden_frame',
        'hat': 'falcon_hat',
      });
      expect(restored.frame, 'golden_frame');
      expect(restored.toJson().containsKey('hat'), isFalse);
    });

    test('an old profile blob with no equip fields defaults safely', () {
      final restored = KidsProfile.fromJson(
          {'id': 'p1', 'name': 'Sara', 'avatar': '🦊', 'gender': ''});
      expect(restored.theme, 'kids');
      expect(restored.frame, isEmpty);
    });
  });

  group('streak freeze', () {
    test('a two-day gap is covered, and the streak keeps counting', () {
      final prog = ProgressStore(profileId: 'p_freeze');
      prog.streakFreezes = 1;
      prog.streakDays = 4;
      final today = ProgressStore.dayIndexFor(DateTime.now());
      prog.lastActiveDayForTest = today - 2;

      prog.refreshStreak();
      expect(prog.streakFreezes, 0, reason: 'the freeze should be spent');
      expect(prog.streakDays, 4,
          reason: 'the streak must survive the covered day');
      expect(prog.justUsedFreeze, isTrue,
          reason: 'the Home screen banner reads this flag');

      // The next real activity continues the streak rather than resetting
      // it — refreshStreak already advanced _lastDay to "yesterday".
      prog.recordActivity();
      expect(prog.streakDays, 5);
    });

    test('a two-day gap with no freeze in hand resets the streak', () {
      final prog = ProgressStore(profileId: 'p_no_freeze');
      prog.streakDays = 4;
      final today = ProgressStore.dayIndexFor(DateTime.now());
      prog.lastActiveDayForTest = today - 2;

      prog.refreshStreak();
      expect(prog.streakDays, 0);
    });

    test('recordActivity() also spends a freeze, if refreshStreak never ran',
        () {
      final prog = ProgressStore(profileId: 'p_freeze_ra');
      prog.streakFreezes = 1;
      prog.streakDays = 2;
      final today = ProgressStore.dayIndexFor(DateTime.now());
      prog.lastActiveDayForTest = today - 2;

      prog.recordActivity();
      expect(prog.streakFreezes, 0);
      expect(prog.streakDays, 3);
    });

    test('a gap of more than two days is not covered by one freeze', () {
      final prog = ProgressStore(profileId: 'p_freeze_toolate');
      prog.streakFreezes = 1;
      prog.streakDays = 4;
      final today = ProgressStore.dayIndexFor(DateTime.now());
      prog.lastActiveDayForTest = today - 3;

      prog.refreshStreak();
      expect(prog.streakDays, 0);
      expect(prog.streakFreezes, 1,
          reason: 'a gap this large is not what the freeze covers');
      expect(prog.justUsedFreeze, isFalse);
    });

    test('acknowledgeFreezeUsed clears the flag without notifying', () {
      final prog = ProgressStore(profileId: 'p_ack');
      var notifications = 0;
      prog.addListener(() => notifications++);
      prog.streakFreezes = 1;
      prog.streakDays = 1;
      final today = ProgressStore.dayIndexFor(DateTime.now());
      prog.lastActiveDayForTest = today - 2;
      prog.refreshStreak();
      expect(prog.justUsedFreeze, isTrue);

      final before = notifications;
      prog.acknowledgeFreezeUsed();
      expect(prog.justUsedFreeze, isFalse);
      expect(notifications, before,
          reason: 'acknowledging is bookkeeping, not a state change other '
              'widgets should react to');
    });
  });

  group('Rewards layout', () {
    testWidgets('the whole tab fits a small phone with real fonts loaded',
        (tester) async {
      // Real fonts, deliberately: the badge tiles overflowed their ~100px
      // cells on a 360px-wide phone, and the default test font is narrow
      // enough to hide it. Nothing pumped this tab at a phone size with the
      // shipped font before, which is why it went unnoticed.
      await tester.runAsync(() async {
        final loader = FontLoader('Outfit')
          ..addFont(File('assets/fonts/Outfit-Variable.ttf')
              .readAsBytes()
              .then((b) => b.buffer.asByteData()));
        await loader.load();
      });
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      settings.desktopMode = 'off';
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();
      prog.awardGems(400);
      prog.report('kids.letter.ا', 3);
      kidsSyncBadges(prog); // a mix of earned and locked tiles

      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: KidsRewardsScreen()),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Rewards overflowed');

      // The badge wall is capped at three rows and spills sideways, so the
      // Shop stays reachable however many badges exist. Both scroll axes
      // have to work without throwing.
      await tester.drag(find.byType(GridView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'the badge wall overflowed once scrolled');
      expect(find.text('Shop'), findsOneWidget,
          reason: 'the Shop heading should be on-screen with the badges, '
              'not buried below a dozen rows of them');
    });
  });

  group('Home screen', () {
    testWidgets('shows "streak saved" once, right after a real app-open '
        'spends a freeze', (tester) async {
      useReducedMotion(tester);
      // KidsShell owns a KidsProfileGate internally, which builds its OWN
      // ProgressStore(profileId: 'p1') and calls load() on it — so the
      // freeze has to be reached the way a real reopen after a missed day
      // would reach it: through SharedPreferences, not by handing the
      // widget tree a pre-built store object it will never actually use.
      final today = ProgressStore.dayIndexFor(DateTime.now());
      SharedPreferences.setMockInitialValues({
        'noor.streak.v1.p1': jsonEncode({
          'streak': 2,
          'last': today - 2,
          'wkStart': -1,
          'wkMask': 0,
          'todayCount': 0,
          'todayCountDay': -1,
          'freezes': 1,
        }),
      });
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      settings.desktopMode = 'off';
      settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));

      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const KidsShell(),
        ),
      ));
      // load() -> refreshStreak() already spent the freeze by the time the
      // profile finishes loading; no extra trigger needed.
      await tester.pumpAndSettle();

      expect(find.text('Your streak was saved!'), findsOneWidget);

      // And it goes away on its own after a few seconds, rather than
      // sitting there forever.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Your streak was saved!'), findsNothing);
    });
  });
}
