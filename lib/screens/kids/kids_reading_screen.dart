import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import '../../data/quran.dart';
import '../../widgets/common.dart';
import 'kids_desktop_nav.dart';

/// "Read it aloud, then tap" over real Qurʼānic text — the reading half of
/// the Kids path, from one word at a time up to a whole short sūrah.
///
/// The text is loaded from the bundled corpus via [QuranRepo] rather than
/// hand-typed: every other Qurʼānic string in this app is held to a
/// verbatim-corpus test (`test/letters_data_test.dart`), and re-typing āyāt
/// into a kids file would be the one place that discipline lapsed.
///
/// [wordsPerChunk] is the whole ladder: 1 word, then 2, then 3, then — with
/// [wholeAyahs] — the full sūrah as the capstone.
class KidsReadingScreen extends StatefulWidget {
  final int surah;
  final int wordsPerChunk;
  final bool wholeAyahs;
  final String progressId;

  /// For tests: what hearing a line, or one word of it, does. The defaults
  /// stream the per-word recordings ([WbwAudio]).
  final PlaybackHandle Function(int surah, int ayah, int firstWord,
      int lastWord, void Function(int) onWord)? playWords;
  final Future<void> Function(int surah, int ayah, int word)? playWord;

  const KidsReadingScreen({
    super.key,
    required this.surah,
    required this.progressId,
    this.wordsPerChunk = 2,
    this.wholeAyahs = false,
    this.playWords,
    this.playWord,
  });

  @override
  State<KidsReadingScreen> createState() => _KidsReadingScreenState();
}

/// One thing to read: some words, and the āyah they came from (for audio).
class _Chunk {
  final List<String> words;
  final int ayah; // 1-based

  /// Where [words] starts in the āyah (0-based) — the per-word recordings
  /// are numbered by position in the āyah, not in the chunk.
  final int first;
  const _Chunk(this.words, this.ayah, this.first);
}

class _KidsReadingScreenState extends State<KidsReadingScreen> {
  List<_Chunk>? _chunks;
  String? _error;
  int _done = 0;

  // Which word is being said right now, so it can light up as it is heard.
  PlaybackHandle? _handle;
  int _litChunk = -1;
  int _litWord = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final perAyah = await QuranRepo.words(widget.surah, 'uthmani');
      final out = <_Chunk>[];
      for (var a = 0; a < perAyah.length; a++) {
        final words = perAyah[a];
        if (widget.wholeAyahs) {
          out.add(_Chunk(words, a + 1, 0));
          continue;
        }
        for (var i = 0; i < words.length; i += widget.wordsPerChunk) {
          final end = (i + widget.wordsPerChunk).clamp(0, words.length);
          out.add(_Chunk(words.sublist(i, end), a + 1, i));
        }
      }
      if (mounted) setState(() => _chunks = out);
    } catch (e) {
      // The corpus is bundled, so this should not happen — but a reading
      // stage that silently shows nothing would be worse than one that says
      // so, and the child can still leave.
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _tap(int i) {
    if (i != _done) return; // in order, one at a time
    setState(() => _done++);
    if (_done < _chunks!.length) return;
    final prog = ProgressScope.of(context);
    prog.report(widget.progressId, 3);
    prog.awardXp(kidsXpPerStar * 3);
    prog.awardGems(kidsGemsPerLesson);
    // Badges sync centrally off this store — see `kidsSyncBadges`.
  }

  /// The whole āyah, flowing — the way it is recited. Used by the capstone,
  /// where a line IS an āyah.
  Future<void> _hearAyah(int ayah) =>
      AyahAudio.instance.play(widget.surah, ayah);

  void _clearLit() {
    _litChunk = -1;
    _litWord = -1;
  }

  /// A line said word by word, each word lighting up as it is heard. For a
  /// one-to-three word line this is the right audio — the whole āyah played
  /// over a two-word card would say a great deal more than the child is
  /// reading — and it works with no timing data at all.
  void _hearLine(int i) {
    final c = _chunks![i];
    _handle?.cancel();
    if (_litChunk == i) {
      // Tapping the speaker again while it plays stops it.
      setState(_clearLit);
      if (widget.playWords == null) WbwAudio.instance.stop();
      return;
    }
    setState(() {
      _litChunk = i;
      _litWord = -1;
    });
    final play = widget.playWords ?? WbwAudio.instance.playWords;
    _handle = play(widget.surah, c.ayah, c.first + 1, c.first + c.words.length,
        (w) {
      if (!mounted) return;
      setState(() {
        if (w < 0) {
          _clearLit();
        } else {
          _litChunk = i;
          _litWord = w - c.first;
        }
      });
    });
  }

  /// One word, said on its own — tapping a word in a line.
  void _hearWord(int i, int w) {
    final c = _chunks![i];
    _handle?.cancel();
    setState(() {
      _litChunk = i;
      _litWord = w;
    });
    final play = widget.playWord ?? WbwAudio.instance.playWord;
    // Offline or no plugin: the word still lights, and the child can try again.
    play(widget.surah, c.ayah, c.first + w + 1).catchError((Object _) {});
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _litChunk == i && _litWord == w) setState(_clearLit);
    });
  }

  @override
  void dispose() {
    _handle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final chunks = _chunks;

    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Geo.gapXl),
          child: Text(context.l10n.kidsReadingUnavailable,
              textAlign: TextAlign.center,
              style: kidsStyle(context, size: 15, color: p.textDim)),
        ),
      );
    } else if (chunks == null) {
      body = Center(child: CircularProgressIndicator(color: p.accent));
    } else {
      final allDone = _done >= chunks.length;
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapSm),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Geo.radiusPill),
                      child: LinearProgressIndicator(
                        value: chunks.isEmpty ? 0 : _done / chunks.length,
                        minHeight: 8,
                        backgroundColor: p.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation(p.accent2),
                      ),
                    ),
                  ),
                  const SizedBox(width: Geo.gapSm),
                  Text('$_done / ${chunks.length}',
                      style: kidsStyle(context,
                          size: 12.5,
                          weight: FontWeight.w800,
                          color: p.accent2)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Geo.gapLg),
                child: Text(context.l10n.kidsReadAloudThenTap,
                    style: kidsStyle(context, size: 13, color: p.textDim)),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Geo.gapLg, Geo.gapMd, Geo.gapLg, Geo.gapXl),
                  itemCount: chunks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Geo.gapSm),
                  itemBuilder: (context, i) => _ChunkCard(
                    words: chunks[i].words,
                    lit: _litChunk == i ? _litWord : -1,
                    state: i < _done
                        ? _ChunkState.done
                        : i == _done
                            ? _ChunkState.current
                            : _ChunkState.ahead,
                    onTap: () => _tap(i),
                    onHear: () => _hearLine(i),
                    // A line that is a whole āyah can also be heard flowing.
                    onHearFlowing: widget.wholeAyahs
                        ? () => _hearAyah(chunks[i].ayah)
                        : null,
                    onWord: (w) => _hearWord(i, w),
                  ),
                ),
              ),
              if (allDone)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => closeKidsOverlayOrPop(context),
                    child: Text(context.l10n.continueLabel),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Embedded in the shell's content pane on desktop; its own route on
    // mobile — the same split every other full-pane kids screen uses.
    if (useDesktop(context)) return body;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(child: body),
    );
  }
}

enum _ChunkState { done, current, ahead }

class _ChunkCard extends StatelessWidget {
  final List<String> words;

  /// The word being said (0-based in [words]), or -1.
  final int lit;
  final _ChunkState state;
  final VoidCallback onTap;
  final VoidCallback onHear;
  final VoidCallback? onHearFlowing;
  final ValueChanged<int> onWord;
  const _ChunkCard(
      {required this.words,
      required this.lit,
      required this.state,
      required this.onTap,
      required this.onHear,
      required this.onWord,
      this.onHearFlowing});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final current = state == _ChunkState.current;
    final done = state == _ChunkState.done;
    return Opacity(
      opacity: state == _ChunkState.ahead ? .45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Geo.radiusLg),
          border: Border.all(
              color: current
                  ? p.accent
                  : done
                      ? p.amber
                      : p.surfaceHigh,
              width: current ? 2 : 1.5),
        ),
        padding: const EdgeInsets.fromLTRB(
            Geo.gapMd, Geo.gapSm, Geo.gapSm, Geo.gapSm),
        child: Row(children: [
          // Word by word, not one string: each word is its own target (tap to
          // hear it) and its own highlight (lit while it is being said). A
          // space already separates Arabic words, so nothing joins across.
          Expanded(
            child: Wrap(
              textDirection: TextDirection.rtl,
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final (i, w) in words.indexed)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onWord(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: i == lit
                            ? p.accent.withValues(alpha: .18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(Geo.radiusMd),
                      ),
                      child: Text(w,
                          textDirection: TextDirection.rtl,
                          style: quranicStyle(context,
                              size: 26, color: i == lit ? p.accent : null)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.kidsWordByWord,
            onPressed: onHear,
            icon: Icon(Icons.record_voice_over_rounded, color: p.accent2),
          ),
          if (onHearFlowing != null)
            IconButton(
              tooltip: context.l10n.listen,
              onPressed: onHearFlowing,
              icon: Icon(Icons.volume_up_rounded, color: p.accent2),
            ),
          // Tapping the tick is the "I read it" action, kept as its own
          // target so a mis-tap while reading doesn't skip the line.
          TapScale(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? p.amber
                    : current
                        ? p.accent
                        : kidsLockedFill(p),
              ),
              child: Icon(
                  done ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 20,
                  color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}
