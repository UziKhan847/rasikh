import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/audio.dart';

/// Which host a downloaded verse actually came from decides whether the
/// weekly-refresh requirement (Quran Foundation's condition for offline
/// caching their API/CDN content) applies to that file — EveryAyah is a
/// separate provider and is deliberately excluded. Getting this wrong in
/// either direction is bad: refreshing EveryAyah content we have no
/// obligation to touch, or silently never refreshing quran.com content we do.
void main() {
  group('isQuranFoundationOrigin', () {
    test('verses.quran.com is in scope', () {
      expect(
          isQuranFoundationOrigin('https://verses.quran.com/Alafasy/mp3/002001.mp3'),
          isTrue);
    });

    test('the quranicaudio.com mirror (returned for Ḥuṣarī) is in scope', () {
      expect(
          isQuranFoundationOrigin(
              'https://mirrors.quranicaudio.com/everyayah/Husary_64kbps/002001.mp3'),
          isTrue);
      expect(isQuranFoundationOrigin('https://quranicaudio.com/x.mp3'), isTrue);
    });

    test('everyayah.com is NOT in scope', () {
      expect(
          isQuranFoundationOrigin(
              'https://everyayah.com/data/Husary_128kbps/002001.mp3'),
          isFalse);
    });

    test('a lookalike host is not fooled by substring matching', () {
      // "verses.quran.com" must match the HOST exactly, not just appear in
      // the URL somewhere (e.g. as a path segment or subdomain trick).
      expect(
          isQuranFoundationOrigin('https://evil.com/verses.quran.com/x.mp3'),
          isFalse);
      expect(
          isQuranFoundationOrigin('https://notquranicaudio.com/x.mp3'),
          isFalse);
    });

    test('malformed URLs do not throw and are treated as out of scope', () {
      expect(isQuranFoundationOrigin('not a url'), isFalse);
      expect(isQuranFoundationOrigin(''), isFalse);
    });
  });

  // A verse-timings API response can hand back a host-qualified URL (see
  // _versesFor's "some reciters return a host-qualified path" comment),
  // which then gets fetched (downloadSurah) or played (AyahAudio.play)
  // directly. isKnownAudioHost is the fixed allowlist gating that — see the
  // Kids Mode plan's "audio host allowlist" hardening note, made more
  // pointed now that this same playback path is child-facing.
  group('isKnownAudioHost', () {
    test('every real reciter host is allowed', () {
      expect(isKnownAudioHost('https://everyayah.com/data/x.mp3'), isTrue);
      expect(isKnownAudioHost('https://verses.quran.com/x.mp3'), isTrue);
      expect(
          isKnownAudioHost('https://mirrors.quranicaudio.com/x.mp3'), isTrue);
      expect(isKnownAudioHost('https://audio.qurancdn.com/wbw/x.mp3'), isTrue);
    });

    test('an arbitrary host is rejected, even if the API returned it', () {
      expect(isKnownAudioHost('https://evil.example/x.mp3'), isFalse);
      expect(isKnownAudioHost('not a url'), isFalse);
      expect(isKnownAudioHost(''), isFalse);
    });
  });
}
