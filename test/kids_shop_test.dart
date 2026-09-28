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
      expect(prog.buyShopItem('starlight_frame', 100), isTrue);
      expect(prog.gems, 0);
      expect(prog.shopOwned.contains('starlight_frame'), isTrue);

      // Already owned: refused even with plenty of gems.
      prog.awardGems(1000);
      expect(prog.buyShopItem('starlight_frame', 100), isFalse);
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

      expect(kidsItemEquipped(items['starlight_frame']!, profile), isFalse);
      kidsEquipItem(items['starlight_frame']!, profile);
      expect(profile.frame, 'starlight_frame');
      expect(kidsItemEquipped(items['starlight_frame']!, profile), isTrue);
      // Equipping a frame must not touch the theme slot.
      expect(profile.theme, 'kids');

      // A second frame replaces the first rather than stacking.
      kidsEquipItem(items['aurora_frame']!, profile);
      expect(profile.frame, 'aurora_frame');
      expect(kidsItemEquipped(items['starlight_frame']!, profile), isFalse);

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

    testWidgets('every cosmetic can be taken back off', (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      // A frame goes back to no frame.
      kidsEquipItem(items['starlight_frame']!, profile);
      kidsUnequipItem(items['starlight_frame']!, profile);
      expect(profile.frame, isEmpty);

      // A theme goes back to the default palette — the bug this pins: a
      // bought Ocean could be equipped but never un-equipped, because the
      // unequip button existed only for frames.
      kidsEquipItem(items['kids_ocean']!, profile);
      expect(profile.theme, 'kids_ocean');
      kidsUnequipItem(items['kids_ocean']!, profile);
      expect(profile.theme, kKidsDefaultTheme);
      expect(kidsItemEquipped(items['kids_ocean']!, profile), isFalse);

      // An avatar unlock goes back to the avatar the child chose themselves.
      profile.avatar = '🦁';
      kidsEquipItem(items['whale_avatar']!, profile);
      expect(profile.avatar, '🐋');
      kidsUnequipItem(items['whale_avatar']!, profile);
      expect(profile.avatar, '🦁');
    });

    testWidgets('taking off an item that is not worn changes nothing',
        (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      kidsEquipItem(items['glow_frame']!, profile);
      kidsEquipItem(items['kids_night']!, profile);
      kidsUnequipItem(items['starlight_frame']!, profile); // not worn
      kidsUnequipItem(items['kids_ocean']!, profile); // not worn
      expect(profile.frame, 'glow_frame');
      expect(profile.theme, 'kids_night');
    });

    testWidgets('swapping one avatar unlock for another keeps the child\'s own',
        (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      profile.avatar = '🦁';
      kidsEquipItem(items['whale_avatar']!, profile);
      kidsEquipItem(items['bee_avatar']!, profile);
      expect(profile.avatar, '🐝');
      // The whale must not have become "their own" avatar on the way past.
      kidsUnequipItem(items['bee_avatar']!, profile);
      expect(profile.avatar, '🦁');
    });

    testWidgets('a profile with no remembered avatar falls back to the default',
        (tester) async {
      await boot(tester);
      final items = {for (final i in kidsShopItems(ctx)) i.id: i};

      // Saved before `baseAvatar` existed, while already wearing an unlock.
      profile.avatar = '🐋';
      kidsUnequipItem(items['whale_avatar']!, profile);
      expect(profile.avatar, kKidsDefaultAvatar);
    });

    test('every avatar unlock is listed in kidsAvatarUnlockEmojis', () {
      const ids = [
        'camel_avatar',
        'bee_avatar',
        'elephant_avatar',
        'ant_avatar',
        'spider_avatar',
        'horse_avatar',
        'cow_avatar',
        'whale_avatar',
        // Added with the drawn animal avatars — the two of the design's six new
        // animals that the Qurʼān also names (see `kidsAnimals`).
        'monkey_avatar',
        'sheep_avatar',
      ];
      expect({for (final id in ids) kidsAvatarUnlock(id)!}, kidsAvatarUnlockEmojis);
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
        final isFrame = kidsFrameKind(item.id) != null;
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
      // No frame: the bare emoji, nothing painted around it.
      await tester.pumpWidget(SettingsScope(
        settings: AppSettings(),
        child: MaterialApp(home: KidsAvatar(profile: profile)),
      ));
      expect(
          find.descendant(
              of: find.byType(KidsAvatar), matching: find.byType(CustomPaint)),
          findsNothing);

      // Each frame paints, at the biggest size (the profile picker) and the
      // smallest (the desktop nav), without throwing.
      for (final id in [
        'silver_frame',
        'starlight_frame',
        'glow_frame',
        'aurora_frame',
      ]) {
        for (final size in [17.0, 44.0, 64.0]) {
          profile.frame = id;
          await tester.pumpWidget(SettingsScope(
            settings: AppSettings(),
            child: MaterialApp(home: KidsAvatar(profile: profile, size: size)),
          ));
          expect(
              find.descendant(
                  of: find.byType(KidsAvatar),
                  matching: find.byType(CustomPaint)),
              findsOneWidget,
              reason: '$id at $size');
          expect(tester.takeException(), isNull, reason: '$id at $size');
        }
      }
    });

    testWidgets('the four frames are four different kinds, not four colours',
        (tester) async {
      await boot(tester);
      final kinds = {
        for (final id in [
          'silver_frame',
          'starlight_frame',
          'glow_frame',
          'aurora_frame',
        ])
          kidsFrameKind(id)
      };
      expect(kinds.length, 4);
      expect(kinds.contains(null), isFalse);
    });

    testWidgets('a retired frame id renders as its successor', (tester) async {
      await boot(tester);
      expect(kidsFrameKind('golden_frame'), kidsFrameKind('starlight_frame'));
      expect(kidsFrameKind('emerald_frame'), kidsFrameKind('aurora_frame'));
      expect(kidsFrameKind(''), isNull);
      expect(kidsFrameKind('no_such_frame'), isNull);
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
      a.buyShopItem('starlight_frame', 100);

      expect(a.shopOwned.contains('starlight_frame'), isTrue);
      expect(b.shopOwned.contains('starlight_frame'), isFalse);
      expect(b.gems, 0);
    });

    test('two profiles do not share equipped cosmetics', () {
      final a = KidsProfile(id: 'a', name: 'Sara');
      final b = KidsProfile(id: 'b', name: 'Yusuf');

      a.frame = 'starlight_frame';
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
          frame: 'starlight_frame');
      final restored = KidsProfile.fromJson(p.toJson());
      expect(restored.theme, 'kids_desert');
      expect(restored.frame, 'starlight_frame');
    });

    test('a profile saved with the retired hat key still loads', () {
      final restored = KidsProfile.fromJson({
        'id': 'p1',
        'name': 'Sara',
        'avatar': '🦊',
        'gender': '',
        'theme': 'kids',
        'frame': 'starlight_frame',
        'hat': 'falcon_hat',
      });
      expect(restored.frame, 'starlight_frame');
      expect(restored.toJson().containsKey('hat'), isFalse);
    });

    test('a profile saved with a retired frame loads as its successor', () {
      for (final (old, now) in [
        ('golden_frame', 'starlight_frame'),
        ('emerald_frame', 'aurora_frame'),
      ]) {
        final restored = KidsProfile.fromJson(
            {'id': 'p1', 'name': 'Sara', 'frame': old});
        expect(restored.frame, now, reason: old);
        // And it is a frame the shop can still draw, so the child keeps a
        // visible ring for what they paid.
        expect(kidsFrameKind(restored.frame), isNotNull);
      }
    });

    test('the remembered avatar round-trips', () {
      final p = KidsProfile(
          id: 'p1', name: 'Sara', avatar: '🐋', baseAvatar: '🦁');
      final restored = KidsProfile.fromJson(p.toJson());
      expect(restored.baseAvatar, '🦁');
      expect(restored.avatar, '🐋');
    });

    test('owned retired frames are migrated when the store loads', () async {
      SharedPreferences.setMockInitialValues({
        'noor.kidsxp.v1.p_legacy': jsonEncode({
          'xp': 10,
          'gems': 5,
          'badges': <String>[],
          'shop': ['golden_frame', 'emerald_frame', 'kids_ocean'],
        }),
      });
      final prog = ProgressStore(profileId: 'p_legacy');
      await prog.load();
      expect(prog.shopOwned,
          containsAll(['starlight_frame', 'aurora_frame', 'kids_ocean']));
      expect(prog.shopOwned.contains('golden_frame'), isFalse);
      expect(prog.shopOwned.contains('emerald_frame'), isFalse);
      SharedPreferences.setMockInitialValues({});
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

  group('Rewards shop row', () {
    // Pumps the Rewards tab with [owned] in the store and [equip] applied to
    // the profile, on a tall window so the whole shop is built.
    Future<(AppSettings, KidsProfile, ProgressStore)> open(
        WidgetTester tester,
        {required List<String> owned,
        void Function(KidsProfile)? equip}) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(480, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      settings.desktopMode = 'off';
      final profile = KidsProfile(id: 'p1', name: 'Sara');
      settings.addKidsProfile(profile);
      equip?.call(profile);
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();
      prog.awardGems(2000);
      for (final id in owned) {
        prog.buyShopItem(id, 1);
      }
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
      await tester.pump(const Duration(milliseconds: 100));
      return (settings, profile, prog);
    }

    // Themes are a grid of painted tiles now (the design's theme shop). Taking a
    // theme off is the same logic as ever — `kidsUnequipItem`, back to the
    // original palette — reached by tapping the Classic tile.
    testWidgets('a worn theme can be taken off from the Classic tile, and put '
        'back on', (tester) async {
      final (_, profile, _) = await open(tester,
          owned: ['kids_ocean'], equip: (p) => p.theme = 'kids_ocean');
      final classic = find.byKey(const ValueKey('kidsThemeTile.kids'));
      final ocean = find.byKey(const ValueKey('kidsThemeTile.kids_ocean'));
      expect(find.descendant(of: ocean, matching: find.text('In use')),
          findsOneWidget);

      await tester.ensureVisible(classic);
      await tester.tap(classic);
      await tester.pump(const Duration(milliseconds: 400));
      expect(profile.theme, kKidsDefaultTheme);
      expect(find.descendant(of: classic, matching: find.text('In use')),
          findsOneWidget);
      // ...and it can be put back on: owned, so no price, just "Use".
      expect(find.descendant(of: ocean, matching: find.text('Use')),
          findsOneWidget);
      await tester.ensureVisible(ocean);
      await tester.tap(ocean);
      await tester.pump(const Duration(milliseconds: 400));
      expect(profile.theme, 'kids_ocean');
    });

    testWidgets('a worn frame offers "Take off", and it works', (tester) async {
      final (_, profile, _) = await open(tester,
          owned: ['starlight_frame'],
          equip: (p) => p.frame = 'starlight_frame');
      expect(find.text('Take off'), findsOneWidget);

      await tester.tap(find.text('Take off'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(profile.frame, isEmpty);
    });

    testWidgets('a worn avatar unlock gives the original avatar back',
        (tester) async {
      final (_, profile, _) = await open(tester,
          owned: ['whale_avatar'], equip: (p) {
        p.avatar = '🦁';
        kidsEquipItem(
            KidsShopItem(
                id: 'whale_avatar',
                emoji: '🐋',
                cost: 1,
                shelf: KidsShopShelf.looks,
                title: (_) => ''),
            p);
      });
      expect(profile.avatar, '🐋');
      await tester.tap(find.text('Use original'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(profile.avatar, '🦁');
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
