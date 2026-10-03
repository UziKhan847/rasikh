import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_avatars.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_avatar_face.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_profile_picker.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_rewards_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The drawn animal avatars. A profile still STORES an emoji — that string is
/// the avatar's identity for the shop, for `baseAvatar` and for every saved
/// profile — and these faces are only how it is drawn. So most of what is
/// pinned here is what must NOT change: who owns what, what things cost, and
/// which avatar a child gets back when they take an unlock off.
/// The asset behind an image, looking through a decode-size [ResizeImage].
String? _assetOf(ImageProvider p) => switch (p) {
  AssetImage(:final assetName) => assetName,
  ResizeImage(:final imageProvider) => _assetOf(imageProvider),
  _ => null,
};

/// Every drawn avatar face on screen (the PNG art, not any other image).
Finder _faces() => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      (_assetOf(w.image)?.startsWith('assets/avatars/') ?? false),
);

/// The chunk types of a PNG file, in order.
List<String> _pngChunks(List<int> b) {
  final out = <String>[];
  var i = 8;
  while (i + 8 <= b.length) {
    final n = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    out.add(String.fromCharCodes(b.sublist(i + 4, i + 8)));
    i += 12 + n;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the catalogue', () {
    test('has the design\'s fifty drawings, each once', () {
      expect(kidsAnimals, hasLength(50));
      expect(kidsAnimals.map((a) => a.id).toSet(), hasLength(50));
      expect(kidsAnimals.map((a) => a.emoji).toSet(), hasLength(50));
    });

    test('objects and the lion cub are stored by id, never by an emoji that '
        'already means something else', () {
      for (final id in ['lioncub', 'icecube', 'crescent', 'mosque', 'shield']) {
        expect(kidsAnimals.firstWhere((a) => a.id == id).emoji, 'avatar:$id');
      }
      // 🧊 is the Frozen theme and the streak freeze; 🌙 the Night theme.
      expect(kidsAnimalFor('🧊'), isNull);
      expect(kidsAnimalFor('🌙'), isNull);
    });

    for (final a in kidsAnimals) {
      test('${a.id}: a clean PNG at 1x, 2x and 3x', () {
        // PNG, not SVG: the faces' soft shadows are SVG blur filters, which
        // flutter_svg drops.
        for (final (dir, px) in [('', 128), ('2.0x/', 256), ('3.0x/', 384)]) {
          final f = File('assets/avatars/$dir${a.id}.png');
          expect(f.existsSync(), isTrue, reason: f.path);
          final b = f.readAsBytesSync();
          expect(b.sublist(1, 4), 'PNG'.codeUnits, reason: f.path);
          // IHDR width and height, big-endian at bytes 16 and 20.
          int u32(int o) =>
              (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
          expect((u32(16), u32(20)), (px, px), reason: f.path);
          // The design ships each file with a C2PA provenance chunk (`caBX`),
          // 449 KB across the set. It is stripped from what the app bundles.
          expect(_pngChunks(b), isNot(contains('caBX')), reason: f.path);
        }
        expect(a.asset, 'assets/avatars/${a.id}.png');
      });
    }

    test('no SVG avatars are left behind', () {
      expect(
        Directory('assets/avatars')
            .listSync(recursive: true)
            .where((e) => e.path.endsWith('.svg')),
        isEmpty,
      );
    });

    test('the folder is declared in pubspec.yaml, or nothing would load', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/avatars/'),
      );
    });

    test('lookup is by exact emoji, and misses stay emoji', () {
      expect(kidsAnimalFor('🦊')?.id, 'fox');
      expect(kidsAnimalFor('🐪')?.id, 'camel');
      // The ant, spider and cow were emoji-only shop unlocks until the art
      // came; a child who already owns one now sees it drawn.
      expect(kidsAnimalFor('🐜')?.id, 'ant');
      expect(kidsAnimalFor('🕷️')?.id, 'spider');
      expect(kidsAnimalFor('🐄')?.id, 'cow');
      expect(kidsAnimalFor('🐋')?.id, 'whale',
          reason: 'the whale, sold as an emoji, now has its drawing');
      expect(kidsAnimalFor('🦄'), isNull, reason: 'no art: stays an emoji');
      expect(kidsAnimalFor('✨'), isNull, reason: 'a frame is not an animal');
      expect(kidsAnimalFor(''), isNull);
    });

    test('the old shop racehorse draws the horse it duplicated', () {
      // 🐎 was sold while 🐴 was free — the same animal twice. It is no longer
      // sold, so a child who bought it simply sees the drawn horse.
      expect(kidsAnimalFor('🐴')?.id, 'horse');
      expect(kidsAnimalFor('🐎')?.id, 'horse');
    });
  });

  group('who owns what does not move', () {
    // kidsShopItems takes a BuildContext (its titles are l10n lookups), so
    // these need a real one.
    Future<List<KidsShopItem>> items(WidgetTester tester) async {
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

    testWidgets('the eight avatar unlocks already on sale keep their prices', (
      tester,
    ) async {
      // Nothing a child already bought becomes free, and nothing gets dearer.
      const prices = {
        'camel_avatar': 60,
        'bee_avatar': 60,
        'elephant_avatar': 80,
        'ant_avatar': 60,
        'spider_avatar': 70,
        'horse_avatar': 90,
        'cow_avatar': 90,
        'whale_avatar': 110,
      };
      final all = await items(tester);
      prices.forEach((id, cost) {
        expect(all.firstWhere((i) => i.id == id).cost, cost, reason: id);
      });
    });

    testWidgets('the two new Qurʼānic animals are on sale, at the design\'s '
        'prices', (tester) async {
      final all = await items(tester);
      const prices = {'monkey_avatar': 100, 'sheep_avatar': 120};
      prices.forEach((id, cost) {
        final i = all.firstWhere((i) => i.id == id);
        expect(i.cost, cost, reason: id);
        expect(i.shelf, KidsShopShelf.looks, reason: id);
      });
    });

    testWidgets('the held animals are neither sold nor offered', (
      tester,
    ) async {
      // A tripwire. Selling an avatar is irreversible — a child spends gems
      // and owns it — and this shelf is animals the Qurʼān names. These are
      // not, so their art ships but nobody can wear it until someone decides
      // to, on purpose, in `kidsShopItems`.
      final held = kidsAnimals.where((a) => a.held).toList();
      expect(held.map((a) => a.id), [
        'cat', 'bunny', 'penguin', 'owl', //
        'hippo', 'crocodile', 'rhino', 'shark', 'buffalo',
        // the sacred objects
        'prayermat', 'mosque', 'quran',
      ]);
      final all = await items(tester);
      final sold = {
        for (final i in all)
          if (kidsAvatarUnlock(i.id) != null) kidsAvatarUnlock(i.id)!,
      };
      for (final a in held) {
        expect(sold, isNot(contains(a.emoji)), reason: '${a.id} is being sold');
        expect(kidsAvatarChoices, isNot(contains(a.emoji)), reason: a.id);
        expect(kidsAvatarUnlockEmojis, isNot(contains(a.emoji)), reason: a.id);
      }
    });

    testWidgets('every drawn animal that is not held can actually be had', (
      tester,
    ) async {
      final all = await items(tester);
      final free = kidsAvatarChoices.toSet();
      final sold = {
        for (final i in all)
          if (kidsAvatarUnlock(i.id) != null) kidsAvatarUnlock(i.id)!,
      };
      for (final a in kidsAnimals.where((a) => !a.held)) {
        expect(
          free.contains(a.emoji) || sold.contains(a.emoji),
          isTrue,
          reason: '${a.id} has art but a child can never wear it',
        );
      }
    });

    testWidgets('no animal is both a free choice and for sale', (tester) async {
      // The horse was, once — free in the picker and sold in the shop.
      final all = await items(tester);
      final freeArt = {
        for (final e in kidsAvatarChoices) kidsAnimalFor(e)?.id ?? e,
      };
      for (final i in all) {
        final v = kidsAvatarUnlock(i.id);
        if (v == null || i.retired) continue;
        expect(freeArt, isNot(contains(kidsAnimalFor(v)?.id ?? v)),
            reason: '${i.id} sells a free avatar');
      }
    });

    testWidgets('the retired horse is shown only to a child who owns it', (
      tester,
    ) async {
      Future<Finder> shop({required bool owns}) async {
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.load();
        settings.kidsMode = true;
        settings.desktopMode = 'off';
        settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
        final prog = ProgressStore(profileId: 'p1');
        await prog.load();
        if (owns) prog.shopOwned.add('horse_avatar');
        await tester.pumpWidget(
          SettingsScope(
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
          ),
        );
        await tester.pumpAndSettle();
        return find.text('Horse', skipOffstage: false);
      }

      expect(await shop(owns: false), findsNothing);
      expect(await shop(owns: true), findsOneWidget);
    });

    testWidgets('the Ice Cube appears only once earned, and is never for sale', (
      tester,
    ) async {
      Future<void> shop({required bool earned}) async {
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.load();
        settings.kidsMode = true;
        settings.desktopMode = 'off';
        settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Sara'));
        final prog = ProgressStore(profileId: 'p1');
        await prog.load();
        prog.awardGems(1000);
        if (earned) prog.shopOwned.add(ProgressStore.iceCubeItem);
        await tester.pumpWidget(
          SettingsScope(
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
          ),
        );
        await tester.pumpAndSettle();
      }

      await shop(earned: false);
      expect(find.text('Things', skipOffstage: false), findsOneWidget);
      expect(find.text('Lantern', skipOffstage: false), findsOneWidget);
      expect(find.text('Ice Cube', skipOffstage: false), findsNothing);
      expect(find.text('Mosque', skipOffstage: false), findsNothing,
          reason: 'held, never sold');

      await shop(earned: true);
      final row = find.ancestor(
          of: find.text('Ice Cube', skipOffstage: false),
          matching: find.byType(Row, skipOffstage: false));
      expect(row, findsWidgets);
      expect(
          find.descendant(
              of: row.first, matching: find.text('Get', skipOffstage: false)),
          findsNothing,
          reason: 'owned: wear it, not buy it');
    });

    test('the design\'s two new free animals are free here too', () {
      expect(kidsAvatarChoices, containsAll(['🐻', '🦘', 'avatar:lioncub']));
      expect(kidsAvatarChoices, hasLength(11));
    });

    test('every free picker choice has drawn art', () {
      for (final e in kidsAvatarChoices) {
        expect(kidsAnimalFor(e), isNotNull, reason: e);
      }
    });

    testWidgets(
      'an avatar unlock\'s value is its own shop icon, and is listed',
      (tester) async {
        for (final i in await items(tester)) {
          final v = kidsAvatarUnlock(i.id);
          if (v == null) continue;
          expect(v, i.emoji, reason: i.id);
          expect(kidsAvatarUnlockEmojis, contains(v), reason: i.id);
        }
      },
    );

    testWidgets('a new animal equips and un-equips like the old ones', (
      tester,
    ) async {
      final all = await items(tester);
      KidsShopItem item(String id) => all.firstWhere((i) => i.id == id);
      final profile = KidsProfile(id: 'p1', name: 'Sara', avatar: '🦁');
      kidsEquipItem(item('monkey_avatar'), profile);
      expect(profile.avatar, '🐵');
      expect(kidsItemEquipped(item('monkey_avatar'), profile), isTrue);
      // Swapping to another unlock must not make the monkey their "own" avatar.
      kidsEquipItem(item('sheep_avatar'), profile);
      expect(profile.avatar, '🐑');
      kidsUnequipItem(item('sheep_avatar'), profile);
      expect(
        profile.avatar,
        '🦁',
        reason: 'the child\'s OWN avatar comes back',
      );
    });
  });

  group('the Ice Cube', () {
    test('is earned the first time a freeze saves the streak, once', () async {
      SharedPreferences.setMockInitialValues({});
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();
      final today = ProgressStore.dayIndexFor(DateTime.now());

      prog.streakFreezes = 2;
      prog.lastActiveDayForTest = today - 2; // one day missed
      prog.recordActivity();
      expect(prog.justUsedFreeze, isTrue);
      expect(prog.justUnlockedIceCube, isTrue);
      expect(prog.shopOwned, contains(ProgressStore.iceCubeItem));
      prog.acknowledgeFreezeUsed();
      expect(prog.justUnlockedIceCube, isFalse);

      // A second saving freeze is just a freeze.
      prog.lastActiveDayForTest = today - 2;
      prog.recordActivity();
      expect(prog.justUsedFreeze, isTrue);
      expect(prog.justUnlockedIceCube, isFalse);
    });

    test('cannot be bought', () async {
      SharedPreferences.setMockInitialValues({});
      final prog = ProgressStore(profileId: 'p1');
      await prog.load();
      prog.awardGems(1000);
      expect(prog.buyShopItem(ProgressStore.iceCubeItem, 0), isFalse);
      expect(prog.shopOwned, isNot(contains(ProgressStore.iceCubeItem)));
    });
  });

  group('KidsAvatarFace', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.kidsMode = true;
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(body: Center(child: child)),
          ),
        ),
      );
      // Real asset I/O — see the v4 gotcha — so let the image load for real.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    testWidgets('draws the animal when there is one', (tester) async {
      await pump(tester, const KidsAvatarFace('🦊', size: 64));
      expect(find.byKey(const ValueKey('kidsAvatar.fox')), findsOneWidget);
      expect(_faces(), findsOneWidget);
      expect(find.text('🦊'), findsNothing, reason: 'the emoji is replaced');
      // Decoded at the size it is shown, not the whole 128/256/384 px image.
      final image = tester.widget<Image>(_faces()).image;
      expect(image, isA<ResizeImage>());
      final dpr = tester.view.devicePixelRatio;
      expect((image as ResizeImage).width, (64 * 1.15 * dpr).ceil());
    });

    testWidgets('keeps the emoji when there is no art', (tester) async {
      await pump(tester, const KidsAvatarFace('🦄', size: 64));
      expect(find.text('🦄'), findsOneWidget);
      expect(_faces(), findsNothing);
    });

    testWidgets('an object is drawn from its id', (tester) async {
      await pump(tester, const KidsAvatarFace('avatar:lantern', size: 64));
      expect(find.byKey(const ValueKey('kidsAvatar.lantern')), findsOneWidget);
      expect(find.textContaining('avatar:'), findsNothing);
    });

    testWidgets('an id with no drawing shows the default face, never the id', (
      tester,
    ) async {
      await pump(tester, const KidsAvatarFace('avatar:dragon', size: 64));
      expect(find.byKey(const ValueKey('kidsAvatar.fox')), findsOneWidget);
      expect(find.textContaining('avatar:'), findsNothing);
    });

    testWidgets('takes about the room the emoji did, so layouts hold', (
      tester,
    ) async {
      await pump(tester, const KidsAvatarFace('🦊', size: 64));
      final box = tester.getSize(find.byKey(const ValueKey('kidsAvatar.fox')));
      expect(box.width, box.height, reason: 'a square, like the face');
      expect(box.width, inInclusiveRange(64, 84));
    });

    for (final size in [17.0, 22.0, 28.0, 64.0]) {
      testWidgets('every animal paints without error at ${size.toInt()}px', (
        tester,
      ) async {
        // 17px is the desktop nav; 22 the picker tiles; 28 shop rows; 64 Me.
        await pump(
          tester,
          Wrap(
            children: [
              for (final a in kidsAnimals) KidsAvatarFace(a.emoji, size: size),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        expect(_faces(), findsNWidgets(kidsAnimals.length));
      });
    }

    testWidgets('a saved profile holding a plain emoji shows the drawn face', (
      tester,
    ) async {
      // No migration: a profile saved long ago holds '🦁', and that is all it
      // needs to hold.
      final profile = KidsProfile(id: 'p1', name: 'Sara', avatar: '🦁');
      await pump(tester, KidsAvatar(profile: profile, size: 44));
      expect(find.byKey(const ValueKey('kidsAvatar.lion')), findsOneWidget);
    });

    testWidgets('a framed avatar still gets its ring around the drawn face', (
      tester,
    ) async {
      final profile = KidsProfile(
        id: 'p1',
        name: 'Sara',
        avatar: '🐼',
        frame: 'ring_frame',
      );
      await pump(tester, KidsAvatar(profile: profile, size: 44));
      expect(find.byKey(const ValueKey('kidsAvatar.panda')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the new-profile picker', () {
    testWidgets('offers the free animals as drawn faces, and fits 320×568', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings();
      await settings.load();
      settings.desktopMode = 'off';
      settings.kidsMode = true;
      settings.kidsTextScale = 1.2;
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            // A brand-new install opens straight onto profile creation.
            home: const KidsShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('New Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // One large preview, plus one tile per free choice.
      expect(
        _faces(),
        findsNWidgets(kidsAvatarChoices.length + 1),
      );
    });
  });
}
