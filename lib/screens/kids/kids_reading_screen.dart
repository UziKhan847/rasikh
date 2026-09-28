import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../data/kids_content.dart';
import '../../data/quran.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kBlack, kWhite, kbC;
import 'kids_widgets.dart';

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

  /// One key per line, so the list can be scrolled to the line being read: the
  /// longer sūrahs run to a couple of dozen lines, and a child should not have
  /// to find their place again after every tap.
  final List<GlobalKey> _keys = [];
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
      _keys
        ..clear()
        ..addAll(List.generate(out.length, (_) => GlobalKey()));
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
    if (_done < _chunks!.length) {
      _revealCurrent();
      return;
    }
    final prog = ProgressScope.of(context);
    prog.report(widget.progressId, 3);
    prog.awardXp(kidsXpPerStar * 3);
    prog.awardGems(kidsGemsPerLesson);
    // Badges sync centrally off this store — see `kidsSyncBadges`.
  }

  /// Scrolls the line now being read into view, a little below the top.
  void _revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _done >= _keys.length) return;
      final at = _keys[_done].currentContext;
      if (at == null) return;
      Scrollable.ensureVisible(
        at,
        alignment: .3,
        duration: kidsReduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
    final ui = kbUi(context);
    final chunks = _chunks;

    if (_error != null) {
      return KidsMessageScreen(context.l10n.kidsReadingUnavailable);
    }
    if (chunks == null) return const KidsLoadingScreen();

    final Widget body;
    if (_done >= chunks.length) {
      // The same celebration every other lesson ends on — mascot, stars
      // landing one at a time, confetti — rather than the bare Continue
      // button this used to leave sixteen reading stages on, with the XP and
      // gems already awarded silently in [_tap].
      body = const KidsLessonResult(stars: 3);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KbSurface(
            color: ui.surface,
            edge: ui.edge,
            elev: KbElev.card,
            radius: 22,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(children: [
              Expanded(
                child: KbProgress(
                    value: chunks.isEmpty ? 0 : _done / chunks.length, ui: ui),
              ),
              const SizedBox(width: 12),
              Text('$_done / ${chunks.length}',
                  style: kbText(17, kbC(ui.linkInk))),
            ]),
          ),
          const SizedBox(height: 14),
          KidsLessonSubtitle(context.l10n.kidsReadAloudThenTap,
              fontSize: 18, align: TextAlign.center),
          Expanded(
            child: ListView.separated(
              // Every line is built up front (there are at most a few dozen)
              // so each has a context to scroll to — see [_keys].
              scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              // Room for the cards' edges and rings.
              clipBehavior: Clip.none,
              itemCount: chunks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _ChunkCard(
                key: _keys[i],
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
                onHearFlowing:
                    widget.wholeAyahs ? () => _hearAyah(chunks[i].ayah) : null,
                onWord: (w) => _hearWord(i, w),
              ),
            ),
          ),
        ],
      );
    }

    // Embedded in the shell's content pane on desktop; its own route on
    // mobile — the same split every other full-pane kids screen uses.
    return KidsScreenScaffold(child: body);
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
      {super.key,
      required this.words,
      required this.lit,
      required this.state,
      required this.onTap,
      required this.onHear,
      required this.onWord,
      this.onHearFlowing});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final current = state == _ChunkState.current;
    final done = state == _ChunkState.done;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // A solid card whatever its state (UI_SPEC §1.7): the current line wears
    // the selection ring, a read one the reward edge; a line still ahead fades
    // its contents, never the card.
    return KbSurface(
      color: ui.surface,
      edge: current
          ? ui.accentEdge
          : done
              ? ui.rewardEdge
              : ui.edge,
      outline: current ? ui.accent : null,
      outlineWidth: 3,
      elev: KbElev.card,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Opacity(
        opacity: state == _ChunkState.ahead ? .45 : 1,
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
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      decoration: BoxDecoration(
                        color: i == lit ? kbC(ui.tile) : kbC(kBlack, 0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(w,
                          textDirection: TextDirection.rtl,
                          style: kbText(28,
                              kbC(i == lit ? ui.tileInk : ui.ink),
                              family: kbFontQuran,
                              weight: FontWeight.w400,
                              height: 1.9)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KbRoundButton('record_voice_over',
              ui: ui, tooltip: context.l10n.kidsWordByWord, onTap: onHear),
          if (onHearFlowing != null) ...[
            const SizedBox(width: 8),
            KbRoundButton('volume_up',
                ui: ui, tooltip: context.l10n.listen, onTap: onHearFlowing),
          ],
          const SizedBox(width: 8),
          // Tapping the tick is the "I read it" action, kept as its own
          // target so a mis-tap while reading doesn't skip the line.
          KbSurface(
            color: done
                ? ui.reward
                : current
                    ? ui.accent
                    : ui.disabledBg,
            edge: done
                ? ui.rewardEdge
                : current
                    ? ui.accentEdge
                    : ui.edge,
            elev: KbElev.edge4,
            circle: true,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            onTap: onTap,
            child: KbIcon(
                done ? 'check' : (rtl ? 'arrow_back' : 'arrow_forward'),
                size: 24,
                color: kbC(done
                    ? ui.rewardInk
                    : current
                        ? kWhite
                        : ui.inkSoft)),
          ),
        ]),
      ),
    );
  }
}
