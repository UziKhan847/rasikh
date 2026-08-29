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

  const KidsReadingScreen({
    super.key,
    required this.surah,
    required this.progressId,
    this.wordsPerChunk = 2,
    this.wholeAyahs = false,
  });

  @override
  State<KidsReadingScreen> createState() => _KidsReadingScreenState();
}

/// One thing to read: some words, and the āyah they came from (for audio).
class _Chunk {
  final String text;
  final int ayah; // 1-based
  const _Chunk(this.text, this.ayah);
}

class _KidsReadingScreenState extends State<KidsReadingScreen> {
  List<_Chunk>? _chunks;
  String? _error;
  int _done = 0;

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
          out.add(_Chunk(words.join(' '), a + 1));
          continue;
        }
        for (var i = 0; i < words.length; i += widget.wordsPerChunk) {
          final end = (i + widget.wordsPerChunk).clamp(0, words.length);
          out.add(_Chunk(words.sublist(i, end).join(' '), a + 1));
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
    for (final b in kidsBadgeDefs(context)) {
      if (b.earned(prog)) prog.unlockBadge(b.id);
    }
  }

  Future<void> _hear(int ayah) => AyahAudio.instance.play(widget.surah, ayah);

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
                    text: chunks[i].text,
                    state: i < _done
                        ? _ChunkState.done
                        : i == _done
                            ? _ChunkState.current
                            : _ChunkState.ahead,
                    onTap: () => _tap(i),
                    onHear: () => _hear(chunks[i].ayah),
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
  final String text;
  final _ChunkState state;
  final VoidCallback onTap;
  final VoidCallback onHear;
  const _ChunkCard(
      {required this.text,
      required this.state,
      required this.onTap,
      required this.onHear});

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
          Expanded(
            child: Text(text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: quranicStyle(context, size: 26)),
          ),
          IconButton(
            tooltip: context.l10n.listen,
            onPressed: onHear,
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
