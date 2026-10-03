import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_avatars.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart'
    show KbAvatarPickerTile;
import 'package:qiraah_arabiyyah/screens/kids/kids_profile_picker.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_rewards_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The testing unlock opens the shop and the avatar picker as well as the
/// path, so every theme and avatar can be seen — without buying anything, and
/// without leaving a profile wearing something it never bought once it is off.
Future<(AppSettings, ProgressStore)> _boot({bool profile = true}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  await settings.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  if (profile) {
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
  }
  final prog = ProgressStore(profileId: 'p1');
  await prog.load();
  return (settings, prog);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  ),
);

/// A real BuildContext, for `kidsShopItems` (its titles are l10n lookups).
Future<List<KidsShopItem>> _items(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return kidsShopItems(ctx);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every theme can be worn without gems, and nothing is bought', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.setUnlockAll(true);
    await tester.pumpWidget(
      _harness(settings, prog, const KidsRewardsScreen()),
    );
    await tester.pumpAndSettle();
    expect(prog.gems, 0);

    final snowy = find.byKey(const ValueKey('kidsThemeTile.kids_snowy'));
    final shelf = find.byType(GridView).last;
    await tester.ensureVisible(shelf);
    await tester.pumpAndSettle();
    await tester.drag(shelf, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(snowy);
    await tester.pumpAndSettle();
    expect(settings.activeKidsProfile!.theme, 'kids_snowy');
    expect(prog.shopOwned, isEmpty, reason: 'trying on is not buying');
    expect(prog.gems, 0);
    await tester.pump(const Duration(seconds: 1)); // the debounced save
  });

  testWidgets('every look offers Wear instead of Get', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.setUnlockAll(true);
    await tester.pumpWidget(
      _harness(settings, prog, const KidsRewardsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get'), findsNWidgets(1), reason: 'only the freeze');
    expect(find.text('Wear'), findsWidgets);
  });

  group('the new-profile picker', () {
    Future<int> tiles(WidgetTester tester, {required bool unlock}) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // No profiles yet, so the picker opens straight onto the form.
      final (settings, prog) = await _boot(profile: false);
      prog.setUnlockAll(unlock);
      await tester.pumpWidget(
        _harness(settings, prog, KidsProfilePicker(onDone: () {})),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return find.byType(KbAvatarPickerTile).evaluate().length;
    }

    testWidgets('offers the free animals normally', (tester) async {
      expect(await tiles(tester, unlock: false), kidsAvatarChoices.length);
    });

    testWidgets('all fifty fit and scroll on a 320×568 phone', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot(profile: false);
      prog.setUnlockAll(true);
      settings.kidsTextScale = 1.2;
      await tester.pumpWidget(
        _harness(settings, prog, KidsProfilePicker(onDone: () {})),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final last = find.byKey(
        ValueKey('kidsAvatarChoice.${kidsAnimals.last.emoji}'),
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers every avatar while the testing unlock is on', (
      tester,
    ) async {
      final every = {
        ...kidsAvatarChoices,
        for (final a in kidsAnimals) a.emoji,
        ...kidsAvatarUnlockEmojis,
      };
      expect(await tiles(tester, unlock: true), every.length);
      for (final a in kidsAnimals.where((a) => a.held)) {
        expect(
          find.byKey(ValueKey('kidsAvatarChoice.${a.emoji}')),
          findsOneWidget,
          reason: '${a.id} is not shown',
        );
      }
    });
  });

  testWidgets('turning it off takes off what was only tried on', (
    tester,
  ) async {
    final items = await _items(tester);
    KidsShopItem item(String id) => items.firstWhere((i) => i.id == id);
    final profile = KidsProfile(id: 'p1', name: 'Sara', avatar: '🦁');
    // Bought: the camel. Tried on under the unlock: a theme and a frame.
    kidsEquipItem(item('kids_ocean'), profile);
    kidsEquipItem(item('glow_frame'), profile);
    kidsEquipItem(item('camel_avatar'), profile);
    kidsTakeOffUnowned(profile, {'camel_avatar'}, items);
    expect(profile.theme, kKidsDefaultTheme);
    expect(profile.frame, '');
    expect(profile.avatar, '🐪', reason: 'the camel was really bought');

    // An avatar unlock that was only tried on goes back to their own.
    kidsEquipItem(item('whale_avatar'), profile);
    kidsTakeOffUnowned(profile, {'camel_avatar'}, items);
    expect(profile.avatar, '🦁');
  });

  testWidgets('the Me tab\'s "turn off" does the taking off', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.setUnlockAll(true);
    late BuildContext ctx;
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final items = kidsShopItems(ctx);
    final profile = settings.activeKidsProfile!;
    settings.update(
      () =>
          kidsEquipItem(items.firstWhere((i) => i.id == 'kids_night'), profile),
    );
    kidsSetTestUnlock(ctx, false);
    await tester.pump(const Duration(seconds: 1));
    expect(prog.unlockAll, isFalse);
    expect(profile.theme, kKidsDefaultTheme);
  });

  group('a profile loading without the unlock', () {
    Future<KidsProfile> load(
      WidgetTester tester, {
      required String avatar,
      String base = '',
      String theme = 'kids',
      String frame = '',
      bool unlock = false,
    }) async {
      useReducedMotion(tester);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      settings.desktopMode = 'off';
      final profile = KidsProfile(
        id: 'p1',
        name: 'Sara',
        avatar: avatar,
        baseAvatar: base,
        theme: theme,
        frame: frame,
      );
      settings.addKidsProfile(profile);
      final store = ProgressStore(profileId: 'p1');
      await store.load();
      store.setUnlockAll(unlock);
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const KidsShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1)); // the debounced save
      return settings.activeKidsProfile!;
    }

    testWidgets('takes off what it never bought', (tester) async {
      // A profile made while another profile's unlock was on: a held animal,
      // an unbought theme and frame.
      final p = await load(
        tester,
        avatar: '🦈',
        base: '🦈',
        theme: 'kids_night',
        frame: 'glow_frame',
      );
      expect(p.avatar, kKidsDefaultAvatar);
      expect(p.baseAvatar, kKidsDefaultAvatar);
      expect(p.theme, kKidsDefaultTheme);
      expect(p.frame, '');
    });

    testWidgets('leaves an emoji it does not know alone', (tester) async {
      // Possibly an avatar an older version offered: never taken away.
      final p = await load(tester, avatar: '🦄');
      expect(p.avatar, '🦄');
    });

    testWidgets('changes nothing while the unlock is on', (tester) async {
      final p = await load(
        tester,
        avatar: '🦈',
        theme: 'kids_night',
        unlock: true,
      );
      expect(p.avatar, '🦈');
      expect(p.theme, 'kids_night');
    });
  });
}
