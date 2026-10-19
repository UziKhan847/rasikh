import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/mushaf_atlas.dart';

/// Turns on the OS reduce-motion flag for this test, so screens with
/// repeating animations let `pumpAndSettle()` return.
void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Drags the middle of [from] onto the middle of [to] the way a finger does:
/// down, a first move past the touch slop toward the target (a drag only
/// begins once the pointer has moved that far), then across, then up.
Future<void> dragOnto(WidgetTester tester, Finder from, Finder to) async {
  final start = tester.getCenter(from);
  final end = tester.getCenter(to);
  final g = await tester.startGesture(start);
  final dir = (end - start);
  final nudge = dir.distance == 0
      ? const Offset(30, 0)
      : dir / dir.distance * 30;
  await g.moveBy(nudge);
  await tester.pump();
  await g.moveTo(end);
  await tester.pump();
  await g.up();
  await tester.pump();
}

/// Answers every audioplayers platform call with an empty success, so screens
/// that touch the audio engine (the reader, the muṣḥaf) can render in tests.
void mockAudioPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  messenger.allMessagesHandler = (channel, handler, message) async {
    if (channel.startsWith('xyz.luan/audioplayers')) {
      return codec.encodeSuccessEnvelope(null);
    }
    return handler?.call(message);
  };
}

/// Loads [script]'s muṣḥaf and its glyph atlas outside fake async (call from
/// setUpAll), so muṣḥaf screens draw from the atlas from their first frame.
Future<void> loadMushaf(String script) async {
  await MushafRepo.ensure(script);
  await MushafAtlas.load(script, MushafRepo.tokensSync(script));
}
