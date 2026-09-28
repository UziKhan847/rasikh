import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_avatars.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_avatar_face.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_profile_picker.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';

import 'kids_test_support.dart';

/// The drawn animal avatars. A profile still STORES an emoji — that string is
/// the avatar's identity for the shop, for `baseAvatar` and for every saved
/// profile — and these faces are only how it is drawn. So most of what is
/// pinned here is what must NOT change: who owns what, what things cost, and
/// which avatar a child gets back when they take an unlock off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the catalogue', () {
    test('has the design\'s seventeen faces, each once', () {
      expect(kidsAnimals, hasLength(17));
      expect(kidsAnimals.map((a) => a.id).toSet(), hasLength(17));
      expect(kidsAnimals.map((a) => a.emoji).toSet(), hasLength(17));
    });

    for (final a in kidsAnimals) {
      test('${a.id}: the asset exists, is a clean 120×120 SVG', () {
        final f = File(a.asset);
        expect(f.existsSync(), isTrue, reason: a.asset);
        final svg = f.readAsStringSync();
        expect(svg, startsWith('<svg'));
        expect(svg, contains('viewBox="0 0 120 120"'));
        // The design ships each file with a C2PA provenance block — 128 KB of
        // the 179 KB total. It is stripped from what the app bundles.
        expect(svg.toLowerCase(), isNot(contains('c2pa')), reason: a.id);
        expect(svg, isNot(contains('<metadata')), reason: a.id);
        expect(
          f.lengthSync(),
          lessThan(20 * 1024),
          reason: '${a.id} is bloated',
        );
      });
    }

    test('the folder is declared in pubspec.yaml, or nothing would load', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/avatars/'),
      );
    });

    test('lookup is by exact emoji, and misses stay emoji', () {
      expect(kidsAnimalFor('🦊')?.id, 'fox');
      expect(kidsAnimalFor('🐪')?.id, 'camel');
      expect(kidsAnimalFor('🐜'), isNull, reason: 'the ant has no drawn art');
      expect(kidsAnimalFor('🕷️'), isNull);
      expect(kidsAnimalFor('🐄'), isNull);
      expect(kidsAnimalFor('🐋'), isNull);
      expect(kidsAnimalFor('✨'), isNull, reason: 'a frame is not an animal');
      expect(kidsAnimalFor(''), isNull);
    });

    test('the paid racehorse is NOT the free horse', () {
      // Aliasing 🐎 to the horse's art would let a child spend 90 gems on an
      // avatar that looks exactly like the free one.
      expect(kidsAnimalFor('🐴')?.id, 'horse');
      expect(kidsAnimalFor('🐎'), isNull);
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

    testWidgets('the four held animals are neither sold nor offered', (
      tester,
    ) async {
      // A tripwire. Selling an avatar is irreversible — a child spends gems
      // and owns it — and this shelf is animals the Qurʼān names. Cat, bunny,
      // penguin and owl are not, so their art ships but nobody can wear it
      // until someone decides to, on purpose, in `kidsShopItems`.
      final held = kidsAnimals.where((a) => a.held).toList();
      expect(held.map((a) => a.id), ['cat', 'bunny', 'penguin', 'owl']);
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
      // Real asset I/O — see the v4 gotcha — so let the SVG load for real.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    testWidgets('draws the animal when there is one', (tester) async {
      await pump(tester, const KidsAvatarFace('🦊', size: 64));
      expect(find.byKey(const ValueKey('kidsAvatar.fox')), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('🦊'), findsNothing, reason: 'the emoji is replaced');
    });

    testWidgets('keeps the emoji when there is no art', (tester) async {
      await pump(tester, const KidsAvatarFace('🐜', size: 64));
      expect(find.text('🐜'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
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
        expect(find.byType(SvgPicture), findsNWidgets(kidsAnimals.length));
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
        find.byType(SvgPicture),
        findsNWidgets(kidsAvatarChoices.length + 1),
      );
    });
  });
}
