import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';
import '../widgets/common.dart';
import 'mushaf_screen.dart';
import 'search.dart';

/// 📗 Qur'an Reader — whole Qur'an, both scripts, two fonts per script,
/// word-by-word with adjustable gaps / grouping (1–6 words per segment) /
/// one-segment-per-line, tajwīd color-coding, ḥarakāt toggle, tap-to-hear
/// words (Markaz Tafsir) and verse recitation by Shaykh Khalifah
/// Al-Tunaiji — both downloadable for offline use.

const tajwidRuleColors = <Color>[
  AppColors.tjGhunnah, // 0 ghunnah
  AppColors.tjIdghamG, // 1 idgham_g
  AppColors.tjIdghamNoG, // 2 idgham_ng
  AppColors.tjIqlab, // 3 iqlab
  AppColors.tjIkhfa, // 4 ikhfa
  AppColors.tjIkhfa, // 5 ikhfa_shafawi
  AppColors.tjIdghamG, // 6 idgham_shafawi
  AppColors.tjQalqalah, // 7 qalqalah
  AppColors.tjMadd2, // 8 madd2
  AppColors.tjMadd4, // 9 madd4 (muttasil)
  AppColors.tjMadd4, // 10 madd45 (munfasil)
  AppColors.tjMadd6, // 11 madd6 (lazim)
  AppColors.tjShamsiyya, // 12 shamsiyya
  AppColors.tjIzhar, // 13 silent
];

TextStyle quranStyle(BuildContext context,
    {Color? color, double base = 26, FontWeight weight = FontWeight.w400}) {
  final s = SettingsScope.of(context);
  final indo = s.quranScript == 'indopak';
  return TextStyle(
    fontFamily: indo ? s.fontIndopak : s.fontUthmani,
    fontSize: base * s.quranFontScale * (indo ? .92 : 1),
    height: indo ? 2.2 : 1.95,
    fontWeight: weight,
    color: color ?? readingInk(context),
  );
}

void comingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
        SnackBar(content: Text('$what ${context.l10n.comingSoon}')));
}

// ───────────────────────────── Surah list ─────────────────────────────

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: Text(context.l10n.quranReader),
              actions: [
                IconButton(
                  tooltip: context.l10n.k15LineMushaf,
                  onPressed: () =>
                      pushAdaptive(context, const MushafPageScreen()),
                  icon: const Icon(Icons.auto_stories_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.search,
                  onPressed: () =>
                      showSearch(context: context, delegate: GlobalSearch(context.l10n.searchLettersRulesSurahs)),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<SurahMeta>>(
        future: QuranRepo.meta(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child:
                    CircularProgressIndicator(color: pal(context).accent));
          }
          final metas = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: metas.length,
            itemBuilder: (context, i) {
              final m = metas[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TapScale(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SurahReaderScreen(meta: m))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: pal(context).surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: pal(context).shadow,
                            blurRadius: 12,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pal(context).accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text('${m.n}',
                            style: uiStyle(context,
                                size: 14,
                                weight: FontWeight.w800,
                                color: pal(context).accentDeep)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.tname,
                                style: uiStyle(context,
                                    size: 15.5, weight: FontWeight.w700)),
                            Text(
                                context.l10n.typeAyat(
                                    m.type == 'meccan'
                                        ? context.l10n.meccan
                                        : context.l10n.medinan,
                                    m.ayahs),
                                style: uiStyle(context,
                                    size: 12.5,
                                    color: pal(context).textDim)),
                          ],
                        ),
                      ),
                      Text(m.name,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontFamily: 'UthmanicHafs',
                              fontSize: 22,
                              color: pal(context).text,
                              height: 1.6)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      )),
    );
  }
}

// ───────────────────────────── Reader ─────────────────────────────

class SurahReaderScreen extends StatefulWidget with DesktopAware {
  final SurahMeta meta;
  final bool shell; // embedded in the desktop shell (no Scaffold/AppBar)
  final VoidCallback? onBack; // desktop: return to the sūrah grid
  const SurahReaderScreen(
      {super.key, required this.meta, this.shell = false, this.onBack});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  List<String>? ayahs; // raw ayah strings (current script)
  List<List<String>>? words; // tokens per ayah
  List<TajwidAyah>? tajwid; // char spans for the loaded tajwid script
  String _tajwidScript = ''; // which script the spans were built for
  bool get wbwMode => SettingsScope.of(context).wordByWord;
  set wbwMode(bool v) => SettingsScope.of(context)
      .update(() => SettingsScope.of(context).wordByWord = v);
  String _loadedScript = '';

  int playingAyah = -1;
  int playingWord = -1;
  bool recitingAyah = false; // verse recitation (Tunaiji) active
  PlaybackHandle? _handle;

  bool downloading = false;
  bool _warnedFallback = false;
  final Map<int, GlobalKey> _ayahKeys = {};
  int dlDone = 0;
  int dlTotal = 1;

  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    AyahAudio.instance.pos.addListener(_onRecitePos);
    _doneSub = AyahAudio.instance.onComplete.listen((_) {
      if (!mounted || !recitingAyah) return;
      final s = SettingsScope.of(context);
      if (s.reciteFlow == 'repeat' && playingAyah >= 0) {
        _playRecitation(playingAyah, userTap: false);
        return;
      }
      if (s.reciteFlow == 'auto' &&
          playingAyah >= 0 &&
          words != null &&
          playingAyah < words!.length - 1) {
        _playRecitation(playingAyah + 1, userTap: false);
        return;
      }
      setState(() {
        playingAyah = -1;
        playingWord = -1;
        recitingAyah = false;
      });
    });
  }

  void _scrollToAyah(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _ayahKeys[i]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            alignment: .12,
            curve: Curves.easeOut);
      }
    });
  }

  /// The āyah whose card is currently topmost in the viewport.
  int _topVisibleAyah() {
    RenderObject? viewport;
    var bestTop = double.infinity;
    var best = -1;
    for (final e in _ayahKeys.entries) {
      final ctx = e.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      viewport ??= Scrollable.maybeOf(ctx)?.context.findRenderObject();
      if (viewport == null) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + box.size.height <= 8) continue; // fully scrolled past
      if (top < bestTop) {
        bestTop = top;
        best = e.key;
      }
    }
    return best;
  }

  /// After a layout-changing toggle, bring [anchor] back to the top so the
  /// reader stays on the same verse instead of landing wherever the old
  /// scroll offset happens to fall under the new item heights.
  void _anchorScroll(int anchor, [int tries = 0]) {
    if (anchor < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tries > 30) return;
      final ctx = _ayahKeys[anchor]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: .04,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut);
        return;
      }
      // The anchor isn't laid out under the new extents — hop toward it,
      // using the nearest built āyah as a compass, then look again.
      ScrollableState? sc;
      int? near;
      for (final e in _ayahKeys.entries) {
        final c = e.value.currentContext;
        if (c == null) continue;
        sc ??= Scrollable.maybeOf(c);
        if (near == null || (e.key - anchor).abs() < (near - anchor).abs()) {
          near = e.key;
        }
      }
      final pos = sc?.position;
      if (pos == null || near == null || near == anchor) return;
      final dir = anchor > near ? 1 : -1;
      pos.jumpTo((pos.pixels + dir * pos.viewportDimension * 2)
          .clamp(0.0, pos.maxScrollExtent));
      _anchorScroll(anchor, tries + 1);
    });
  }

  /// Applies a display toggle while keeping the reader on the same verse.
  void _keepPlace(VoidCallback change) {
    final anchor = _topVisibleAyah();
    setState(change);
    _anchorScroll(anchor);
  }

  void _onRecitePos() {
    if (!mounted || !recitingAyah) return;
    final w = AyahAudio.instance.wordAt(AyahAudio.instance.pos.value);
    if (w != playingWord) setState(() => playingWord = w);
  }

  @override
  void dispose() {
    AyahAudio.instance.pos.removeListener(_onRecitePos);
    _doneSub?.cancel();
    _handle?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    super.dispose();
  }

  Future<void> _ensureLoaded(String script) async {
    if (_loadedScript == script && words != null) return;
    final a = await QuranRepo.ayahs(widget.meta.n, script);
    final w = await QuranRepo.words(widget.meta.n, script);
    if (!mounted) return;
    setState(() {
      ayahs = a;
      words = w;
      _loadedScript = script;
    });
    final s = SettingsScope.of(context);
    if (s.tajwidColors && _tajwidScript != script) {
      final t = await QuranRepo.tajwid(widget.meta.n, script);
      if (mounted) {
        setState(() {
          tajwid = t;
          _tajwidScript = script;
        });
      }
    }
  }

  void _stopAll() {
    _handle?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    setState(() {
      playingAyah = -1;
      playingWord = -1;
      recitingAyah = false;
    });
  }

  void _playGroup(int ayahIdx, int firstWord, int lastWord) {
    // While this āyah is being recited with word timings, tapping a word
    // jumps the recitation to that word's timestamp. Only when the stream is
    // actually seekable (duration known) — seeking an unbuffered stream
    // restarts it at 0:00, which sounds like "the verse just repeats".
    // Otherwise the recitation stops and the tapped word itself plays.
    if (recitingAyah && playingAyah == ayahIdx) {
      final segs = AyahAudio.instance.segments;
      final dur = AyahAudio.instance.dur.value;
      if (segs != null && dur > Duration.zero) {
        // Nearest segment at/after the word — timing data occasionally
        // merges adjacent words, so an exact index may not exist.
        for (final seg in segs) {
          if (seg[0] >= firstWord) {
            final t = Duration(milliseconds: seg[1]);
            if (t < dur) {
              AyahAudio.instance.seek(t);
              AyahAudio.instance.resume();
              return;
            }
            break;
          }
        }
      }
    }
    _handle?.cancel();
    AyahAudio.instance.stop();
    setState(() {
      recitingAyah = false;
      playingAyah = ayahIdx;
    });
    _handle = WbwAudio.instance.playWords(
      widget.meta.n, ayahIdx + 1, firstWord + 1, lastWord + 1,
      (w) {
        if (!mounted) return;
        setState(() {
          playingWord = w;
          if (w == -1) playingAyah = -1;
        });
      },
    );
  }

  void _playAyahWbw(int ayahIdx) {
    if (playingAyah == ayahIdx && !recitingAyah &&
        _handle != null && !_handle!.cancelled) {
      _stopAll();
      return;
    }
    _playGroup(ayahIdx, 0, words![ayahIdx].length - 1);
  }

  Future<void> _playRecitation(int ayahIdx, {bool userTap = true}) async {
    if (userTap && recitingAyah && playingAyah == ayahIdx) {
      _stopAll();
      return;
    }
    _handle?.cancel();
    setState(() {
      playingAyah = ayahIdx;
      playingWord = -1;
      recitingAyah = true;
    });
    if (!userTap) _scrollToAyah(ayahIdx);
    final err = await AyahAudio.instance.play(widget.meta.n, ayahIdx + 1,
        reciter: SettingsScope.of(context).reciter);
    if (!mounted) return;
    if (err == null && AyahAudio.instance.fellBack && !_warnedFallback) {
      _warnedFallback = true;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(context.l10n.highlightOffline),
        ));
    }
    if (err != null) {
      setState(() {
        playingAyah = -1;
        recitingAyah = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(err),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Future<void> _download(bool recitation) async {
    if (downloading || words == null) return;
    setState(() {
      downloading = true;
      dlDone = 0;
      dlTotal = recitation
          ? widget.meta.ayahs
          : words!.fold(0, (a, w) => a + w.length);
    });
    final ok = recitation
        ? await AyahAudio.instance.downloadSurah(
            widget.meta.n,
            widget.meta.ayahs,
            (d, t) => mounted ? setState(() => dlDone = d) : null,
            reciter: SettingsScope.of(context).reciter)
        : await WbwAudio.instance.downloadSurah(
            widget.meta.n, [for (final w in words!) w.length],
            (d, t) => mounted ? setState(() => dlDone = d) : null);
    if (!mounted) return;
    setState(() => downloading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? context.l10n.surahAudioSaved(widget.meta.tname)
            : context.l10n.downloadsNeedApp)));
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    _ensureLoaded(s.quranScript);
    if (s.tajwidColors &&
        _tajwidScript != s.quranScript &&
        words != null) {
      QuranRepo.tajwid(widget.meta.n, s.quranScript).then((t) {
        if (mounted) {
          setState(() {
            tajwid = t;
            _tajwidScript = s.quranScript;
          });
        }
      });
    }
    final m = widget.meta;
    if (widget.shell) return _shellBuild(context, m);
    return Scaffold(
      bottomNavigationBar: _playerBar(context),
      appBar: AppBar(
        title: Text('${m.n} · ${m.tname}'),
        actions: [
          if (downloading)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: SizedBox(
                  width: 42,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: pal(context).accent)),
                    Text('${(100 * dlDone / dlTotal).floor()}%',
                        style: uiStyle(context,
                            size: 10, color: pal(context).textDim)),
                  ]),
                ),
              ),
            )
          else
            PopupMenuButton<int>(
              icon: Icon(Icons.download_for_offline_rounded,
                  color: pal(context).accent),
              color: pal(context).surface,
              onSelected: (v) => _download(v == 1),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 0,
                    child: Text(context.l10n.downloadWbw,
                        style: uiStyle(context, size: 14))),
                PopupMenuItem(
                    value: 1,
                    child: Text(context.l10n.downloadRecitation,
                        style: uiStyle(context, size: 14))),
              ],
            ),
          IconButton(
            tooltip: context.l10n.k15LineMushaf,
            onPressed: () async {
              final script = SettingsScope.of(context).quranScript;
              final p = await MushafRepo.pageForSurah(script, widget.meta.n);
              if (context.mounted) {
                pushAdaptive(
                    context, MushafPageScreen(startPage: p, script: script));
              }
            },
            icon: Icon(Icons.auto_stories_rounded, color: pal(context).textDim),
          ),
          IconButton(
            tooltip: context.l10n.readerOptions,
            onPressed: () => _openOptions(context),
            icon: Icon(Icons.tune_rounded, color: pal(context).textDim),
          ),
          IconButton(
            tooltip: context.l10n.video,
            onPressed: () => comingSoon(context, context.l10n.videoForThisSurah),
            icon: Icon(Icons.ondemand_video_rounded,
                color: pal(context).textDim),
          ),
        ],
      ),
      body: words == null
          ? Center(
              child: CircularProgressIndicator(color: pal(context).accent))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: useDesktop(context) ? 760 : double.infinity),
                child: Column(children: [
              _controls(context, s),
              Expanded(child: _readerList(context, s)),
            ]),
              ),
            ),
    );
  }

  /// The scrolling list of āyāt (cards or mushaf flow), shared by the mobile
  /// full-screen reader and the desktop shell-embedded reader.
  Widget _readerList(BuildContext context, AppSettings s) {
    return s.readerLayout == 'mushaf'
        ? ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            itemCount: words!.length + 1,
            itemBuilder: (context, i) {
              if (i == words!.length) return _credit(context);
              return KeyedSubtree(
                  key: _ayahKeys.putIfAbsent(i, GlobalKey.new),
                  child: _mushafAyah(context, s, i));
            },
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            itemCount: words!.length + 1,
            itemBuilder: (context, i) {
              if (i == words!.length) return _credit(context);
              return KeyedSubtree(
                  key: _ayahKeys.putIfAbsent(i, GlobalKey.new),
                  child: _ayahCard(context, s, i));
            },
          );
  }

  /// Desktop shell layout: header row + centered āyāt (left) + a persistent
  /// "Reader options" panel (right). No Scaffold/AppBar — it lives inside the
  /// desktop shell content area, so the sidebar and top bar stay visible.
  Widget _shellBuild(BuildContext context, SurahMeta m) {
    final s = SettingsScope.of(context);
    if (words == null) {
      return Center(
          child: CircularProgressIndicator(color: pal(context).accent));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── left: header + reader ──
        Expanded(
          child: Column(children: [
            Row(children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: widget.onBack,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            border: Border.all(color: pal(context).surfaceHigh),
                            borderRadius: BorderRadius.circular(13)),
                        child: Icon(Icons.arrow_back_rounded,
                            color: pal(context).text),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        context.l10n.surahMetaLine(m.n, m.type.toUpperCase(), m.ayahs),
                        style: uiStyle(context,
                            size: 12,
                            weight: FontWeight.w800,
                            color: pal(context).accent)),
                    Text('${m.tname} · ${m.name}',
                        style:
                            uiStyle(context, size: 24, weight: FontWeight.w900)),
                  ],
                ),
              ),
              _shellIconBtn(context, Icons.auto_stories_rounded, () async {
                final script = SettingsScope.of(context).quranScript;
                final p = await MushafRepo.pageForSurah(script, m.n);
                if (context.mounted) {
                  pushAdaptive(
                      context, MushafPageScreen(startPage: p, script: script));
                }
              }),
              const SizedBox(width: 8),
              _shellIconBtn(context, Icons.download_for_offline_rounded,
                  () => _download(true)),
              const SizedBox(width: 8),
              _shellIconBtn(context, Icons.ondemand_video_rounded,
                  () => comingSoon(context, context.l10n.videoForThisSurah)),
            ]),
            const SizedBox(height: 14),
            _controls(context, s),
            const SizedBox(height: 6),
            Expanded(child: _readerList(context, s)),
            if (recitingAyah && playingAyah >= 0) _playerBar(context)!,
          ]),
        ),
        const SizedBox(width: 24),
        // ── right: reader options panel ──
        SizedBox(
          width: 340,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            decoration: BoxDecoration(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: pal(context).shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: ListView(
              children: _optionsChildren(
                  context, s, (fn) => setState(() => s.update(fn)),
                  (fn) => setState(fn)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _shellIconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: pal(context).surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              border: Border.all(color: pal(context).surfaceHigh),
              borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: pal(context).accent, size: 20),
        ),
      ),
    );
  }

  /// Mushaf-style continuous flow: every āyah's words run together in one
  /// justified RTL stream with inline āyah markers — word taps, outlines,
  /// tajwīd colors and highlights all still work per word.
  /// One āyah rendered as a continuous RTL word-flow card. Building per-āyah
  /// (inside a ListView.builder) keeps a 6000-word sūrah from constructing
  /// every widget on one frame — which was freezing the app.
  Widget _mushafAyah(BuildContext context, AppSettings s, int i) {
    final children = <Widget>[];
    final tokens = words![i];
    final tj = (s.tajwidColors && tajwid != null && i < tajwid!.length)
        ? tajwid![i]
        : null;
    final group = wbwMode ? s.wbwGroup : 1;
    if (wbwMode) {
      for (var first = 0; first < tokens.length; first += group) {
        final last = (first + group - 1).clamp(0, tokens.length - 1);
        children.add(_segment(context, s, i, first, last, tokens, tj));
      }
    } else {
      children
          .add(_segment(context, s, i, 0, tokens.length - 1, tokens, tj));
    }
    // inline āyah marker — tap to recite this verse
    children.add(TapScale(
      onTap: () => _playRecitation(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (recitingAyah && playingAyah == i)
              ? pal(context).accent.withValues(alpha: .16)
              : Colors.transparent,
          border: Border.all(
              color: pal(context).accent.withValues(alpha: .55), width: 1.4),
        ),
        child: Text('${i + 1}',
            textDirection: TextDirection.ltr,
            style: uiStyle(context,
                size: 11.5,
                weight: FontWeight.w800,
                color: pal(context).accent)),
      ),
    ));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          spacing: wbwMode ? s.wbwGap : 5,
          runSpacing: wbwMode ? s.wbwGap * .9 : 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }

  // ── header: retractable; stacked in portrait, skinny & horizontal in landscape ──
  Widget _controls(BuildContext context, AppSettings s) {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final indo = s.quranScript == 'indopak';
    Widget segmented(List<(String, bool, VoidCallback)> items) => Container(
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pal(context).surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final (label, sel, onTap) in items)
                Expanded(
                  child: TapScale(
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? pal(context).accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiStyle(context,
                              size: 13,
                              weight: FontWeight.w700,
                              color: sel ? Colors.white : pal(context).text)),
                    ),
                  ),
                ),
            ],
          ),
        );

    // ── collapsed: a thin summary bar with an expand chevron ──
    if (s.readerHeaderCollapsed) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: TapScale(
          onTap: () => s.update(() => s.readerHeaderCollapsed = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 17, color: pal(context).textDim),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${indo ? context.l10n.indopak : context.l10n.madani}${wbwMode ? ' · ${context.l10n.wordByWord}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 13, color: pal(context).text),
                ),
              ),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: pal(context).textDim),
            ]),
          ),
        ),
      );
    }

    final collapseBtn = TapScale(
      onTap: () => s.update(() => s.readerHeaderCollapsed = true),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.keyboard_arrow_up_rounded,
            color: pal(context).textDim, size: 24),
      ),
    );

    // One choice: the script picks its typeface (Madani → KFGQPC Hafs,
    // IndoPak → PDMS Saleem Qur'an font).
    final scriptSeg = segmented([
      (context.l10n.madani, !indo, () => s.update(() {
            s.quranScript = 'uthmani';
            s.fontUthmani = 'UthmanicHafs';
          })),
      (context.l10n.indopak, indo, () => s.update(() {
            s.quranScript = 'indopak';
            s.fontIndopak = 'PDMSSaleem';
          })),
    ]);
    final sizeRow = Row(children: [
      Text('A', style: uiStyle(context, size: 14, color: pal(context).textDim)),
      Expanded(
        child: Slider(
          min: 0.7, max: 2.2,
          value: s.quranFontScale,
          onChanged: (v) => s.update(() => s.quranFontScale = v),
        ),
      ),
      Text('A', style: uiStyle(context, size: 22)),
    ]);
    final wbwControl = Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Text(context.l10n.wordByWord,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiStyle(context, size: 13.5, color: pal(context).text)),
      ),
      Switch(value: wbwMode, onChanged: (v) => _keepPlace(() => wbwMode = v)),
    ]);

    final body = landscape
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(flex: 6, child: scriptSeg),
              const SizedBox(width: 10),
              Flexible(flex: 4, child: wbwControl),
              collapseBtn,
            ]),
            const SizedBox(height: 4),
            sizeRow,
          ])
        : Column(children: [
            scriptSeg,
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: wbwControl),
              collapseBtn,
            ]),
            sizeRow,
          ]);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: EdgeInsets.fromLTRB(14, landscape ? 8 : 12, 14, landscape ? 6 : 10),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: body,
    );
  }

  // ── options bottom sheet ──
  void _openOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        final s = SettingsScope.of(context);
        void upd(VoidCallback fn) {
          s.update(fn);
          setSheet(() {});
          setState(() {});
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              22, 18, 22, 28 + MediaQuery.paddingOf(sheetCtx).bottom),
          child: ListView(
            shrinkWrap: true,
            children: _optionsChildren(context, s, upd, setSheet),
          ),
        );
      }),
    );
  }

  /// The reader-options controls, shared by the mobile bottom sheet and the
  /// desktop right-hand panel. [rebuild] refreshes the host (sheet or panel).
  List<Widget> _optionsChildren(BuildContext context, AppSettings s,
      void Function(VoidCallback) upd, void Function(VoidCallback) rebuild) {
    // Like [upd], but keeps the reader anchored on the same verse — used by
    // every control that changes item heights (word-by-word, grouping,
    // one-word-per-line, alignment), so toggling them doesn't teleport the
    // reader from 4:7 to 4:12.
    void updKeep(VoidCallback fn) {
      final anchor = _topVisibleAyah();
      upd(fn);
      _anchorScroll(anchor);
    }

    Widget toggle(String label, bool value, void Function(bool) set,
            {String? note, bool anchored = false}) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: uiStyle(context, size: 14.5)),
          subtitle: note == null
              ? null
              : Text(note,
                  style:
                      uiStyle(context, size: 12, color: pal(context).textDim)),
          value: value,
          onChanged: (v) => (anchored ? updKeep : upd)(() => set(v)),
        );
    return [
            Text(context.l10n.readerOptions,
                style: uiStyle(context, size: 18, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.wordByWord,
                  style: uiStyle(context, size: 14.5)),
              subtitle: Text(context.l10n.wordByWordNote,
                  style:
                      uiStyle(context, size: 12, color: pal(context).textDim)),
              value: wbwMode,
              onChanged: (v) {
                updKeep(() => s.wordByWord = v);
                rebuild(() {});
              },
            ),
            if (wbwMode) ...[
              Row(children: [
                SizedBox(
                    width: 120,
                    child: Text(context.l10n.wordGap,
                        style: uiStyle(context,
                            size: 13.5, color: pal(context).textDim))),
                Expanded(
                  child: Slider(
                    min: 4, max: 30,
                    value: s.wbwGap,
                    onChanged: (v) => upd(() => s.wbwGap = v),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 120,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(context.l10n.groupWords,
                                style: uiStyle(context,
                                    size: 13.5, color: pal(context).textDim)),
                          )),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var g = 1; g <= 6; g++)
                              ChoiceChip(
                                label: Text('$g'),
                                selected: s.wbwGroup == g,
                                selectedColor: pal(context).accent,
                                backgroundColor: pal(context).surfaceHigh,
                                labelStyle: uiStyle(context,
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: s.wbwGroup == g
                                        ? Colors.white
                                        : pal(context).text),
                                onSelected: (_) =>
                                    updKeep(() => s.wbwGroup = g),
                              ),
                          ],
                        ),
                      ),
                    ]),
              ),
            ],
            toggle(context.l10n.segmentNewline, s.wbwNewline, (v) => s.wbwNewline = v,
                anchored: true),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(context.l10n.verseAlign,
                    style: uiStyle(context,
                        size: 13.5, color: pal(context).textDim)),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (label, value) in [
                  (context.l10n.alignRight, 'right'),
                  (context.l10n.alignCenter, 'center'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: s.wbwAlign == value,
                    selectedColor: pal(context).accent,
                    backgroundColor: pal(context).surfaceHigh,
                    labelStyle: uiStyle(context,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: s.wbwAlign == value
                            ? Colors.white
                            : pal(context).text),
                    onSelected: (_) => updKeep(() => s.wbwAlign = value),
                  ),
              ]),
            ]),
            toggle(context.l10n.hideTashkil, s.stripTashkil, (v) {
              s.stripTashkil = v;
              if (v) s.tajwidColors = false;
            }),
            toggle(context.l10n.tajwidColors, s.tajwidColors, (v) {
              s.tajwidColors = v;
              if (v) s.stripTashkil = false;
            }, note: context.l10n.tajwidNeeds),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 120,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(context.l10n.reciter,
                              style: uiStyle(context,
                                  size: 13.5, color: pal(context).textDim)),
                        )),
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final (label, value) in  [
                          (context.l10n.alTunaiji, 'tunaiji'),
                          (context.l10n.afasyHighlight, 'alafasy'),
                          (context.l10n.husaryHighlight, 'husary'),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: s.reciter == value,
                            selectedColor: pal(context).accent,
                            backgroundColor: pal(context).surfaceHigh,
                            labelStyle: uiStyle(context,
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: s.reciter == value
                                    ? Colors.white
                                    : pal(context).text),
                            onSelected: (_) => upd(() => s.reciter = value),
                          ),
                      ]),
                    ),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Text(context.l10n.layout,
                          style: uiStyle(context,
                              size: 13.5, color: pal(context).textDim)),
                    ),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (label, value) in [
                        (context.l10n.ayahCards, 'cards'),
                        (context.l10n.mushafFlow, 'mushaf'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: s.readerLayout == value,
                          selectedColor: pal(context).accent,
                          backgroundColor: pal(context).surfaceHigh,
                          labelStyle: uiStyle(context,
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: s.readerLayout == value
                                  ? Colors.white
                                  : pal(context).text),
                          onSelected: (_) => upd(() => s.readerLayout = value),
                        ),
                    ]),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Text(context.l10n.afterVerse,
                          style: uiStyle(context,
                              size: 13.5, color: pal(context).textDim)),
                    ),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (label, value) in [
                        (context.l10n.flowStop, 'single'),
                        (context.l10n.flowContinue, 'auto'),
                        (context.l10n.flowRepeat, 'repeat'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: s.reciteFlow == value,
                          selectedColor: pal(context).accent,
                          backgroundColor: pal(context).surfaceHigh,
                          labelStyle: uiStyle(context,
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: s.reciteFlow == value
                                  ? Colors.white
                                  : pal(context).text),
                          onSelected: (_) => upd(() => s.reciteFlow = value),
                        ),
                    ]),
                  ]),
            ),
            if (s.tajwidColors)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (label, c) in const [
                    ('Ghunnah', AppColors.tjGhunnah),
                    ('Idgh\u0101m', AppColors.tjIdghamG),
                    ('Ikhf\u0101\u2019', AppColors.tjIkhfa),
                    ('Iql\u0101b', AppColors.tjIqlab),
                    ('Qalqalah', AppColors.tjQalqalah),
                    ('Madd 2', AppColors.tjMadd2),
                    ('Madd 4\u20135', AppColors.tjMadd4),
                    ('Madd 6', AppColors.tjMadd6),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.withValues(alpha: .6)),
                      ),
                      child: Text(label,
                          style: uiStyle(context, size: 11, color: c)),
                    ),
                ]),
              ),
    ];
  }

  // ── ayah card ──
  Widget _ayahCard(BuildContext context, AppSettings s, int i) {
    final isActive = playingAyah == i;
    final tokens = words![i];
    final tjAyah = s.tajwidColors && tajwid != null && i < tajwid!.length
        ? tajwid![i]
        : null;

    // group tokens into segments of N (remainder = smaller final segment)
    final n = wbwMode ? s.wbwGroup : 1;
    final segments = <(int first, int last)>[];
    for (var w = 0; w < tokens.length; w += n) {
      segments.add((w, (w + n - 1).clamp(0, tokens.length - 1)));
    }

    final segmentWidgets = <Widget>[
      for (final (first, last) in segments)
        _segment(context, s, i, first, last, tokens, tjAyah),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: s.paperMode ? pal(context).paper : pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive
                ? pal(context).accent.withValues(alpha: .6)
                : Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: wbwMode && s.wbwNewline
                ? Column(
                    crossAxisAlignment: s.wbwAlign == 'center'
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.stretch,
                    children: [
                      for (final w in segmentWidgets)
                        Padding(
                          padding: EdgeInsets.only(bottom: s.wbwGap * .6),
                          child: Align(
                              alignment: s.wbwAlign == 'center'
                                  ? Alignment.center
                                  : AlignmentDirectional.centerStart,
                              child: w),
                        ),
                    ],
                  )
                : Wrap(
                    spacing: wbwMode ? s.wbwGap : 3,
                    runSpacing: wbwMode ? s.wbwGap * .8 : 2,
                    alignment: s.wbwAlign == 'center'
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: segmentWidgets,
                  ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('${widget.meta.n}:${i + 1}',
                style: uiStyle(context,
                    size: 12.5,
                    color: pal(context).textDim,
                    weight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.video,
              onPressed: () => comingSoon(context, context.l10n.videoForThisAyah),
              icon: Icon(Icons.ondemand_video_rounded,
                  size: 19, color: pal(context).textDim),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.playRecitation,
              onPressed: () => _playRecitation(i),
              icon: Icon(
                  isActive && recitingAyah
                      ? Icons.stop_circle_rounded
                      : Icons.headphones_rounded,
                  size: 24,
                  color: pal(context).accent2),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.wordByWord,
              onPressed: () => _playAyahWbw(i),
              icon: Icon(
                  isActive && !recitingAyah
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 26,
                  color: pal(context).accent),
            ),
          ]),
        ],
      ),
    );
  }

  /// Compact playback bar shown while a verse recitation is active, themed to
  /// the app palette. Sits as a slim bottom bar; does not fill the screen.
  Widget? _playerBar(BuildContext context) {
    if (!recitingAyah || playingAyah < 0) return null;
    final a = AyahAudio.instance;
    final p = pal(context);
    final reciter = SettingsScope.of(context).reciter;
    final who = reciter == 'alafasy'
        ? 'Al-\u02bfAf\u0101s\u012b'
        : reciter == 'husary'
            ? 'Al-\u1e24u\u1e63ar\u012b'
            : context.l10n.alTunaiji;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.surfaceHigh),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: p.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.graphic_eq_rounded, color: p.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.nowPlaying,
                      style: uiStyle(context,
                          size: 9.5,
                          weight: FontWeight.w800,
                          color: p.textDim)),
                  Text(
                      context.l10n.ayahByReciter(
                          '${widget.meta.n}:${playingAyah + 1}', who),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 13.5, weight: FontWeight.w800)),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([a.pos, a.dur]),
              builder: (context, _) {
                final total = a.dur.value.inMilliseconds;
                final at =
                    a.pos.value.inMilliseconds.clamp(0, total > 0 ? total : 0);
                if (MediaQuery.of(context).size.width < 400) {
                  return const SizedBox.shrink();
                }
                return SizedBox(
                  width: 96,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: p.accent,
                      inactiveTrackColor: p.surfaceHigh,
                      thumbColor: p.accent,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: total > 0 ? at / total : 0,
                      onChanged: total > 0
                          ? (v) => a.seek(
                              Duration(milliseconds: (v * total).round()))
                          : null,
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: a.playing,
              builder: (context, isPlaying, _) => IconButton(
                onPressed: () => isPlaying ? a.pause() : a.resume(),
                icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: p.accent,
                    size: 34),
              ),
            ),
            IconButton(
              tooltip: context.l10n.stop,
              onPressed: _stopAll,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 38, minHeight: 38),
              icon: Icon(Icons.close_rounded, color: p.textDim, size: 22),
            ),
          ]),
        ),
      ),
    );
  }

  /// One segment = [first..last] words rendered together (chip in wbw mode,
  /// bare text in flow mode). Tapping plays its words in order.
  Widget _segment(
      BuildContext context,
      AppSettings s,
      int ayahIdx,
      int first,
      int last,
      List<String> tokens,
      TajwidAyah? tj) {
    final active = playingAyah == ayahIdx &&
        playingWord >= first &&
        playingWord <= last;

    InlineSpan wordSpan(int w) {
      var text = tokens[w];
      if (s.stripTashkil) text = stripTashkil(text);
      Color? color = active && playingWord == w
          ? pal(context).accentDeep
          : null;
      // tajwīd: char-accurate in both scripts (IndoPak spans are transferred
      // from the verified Madani spans by base-letter alignment).
      if (tj != null && color == null && !s.stripTashkil) {
        return _tajwidWordSpan(context, ayahIdx, w, text, tj);
      }
      return TextSpan(
          text: text,
          style: quranStyle(context,
              color: color,
              weight:
                  active && playingWord == w ? FontWeight.w700 : FontWeight.w400));
    }

    final spans = <InlineSpan>[];
    for (var w = first; w <= last; w++) {
      spans.add(wordSpan(w));
      if (w != last) spans.add(const TextSpan(text: ' '));
    }
    final textWidget = Text.rich(TextSpan(children: spans),
        textDirection: TextDirection.rtl);

    if (!wbwMode) {
      return GestureDetector(
        onTap: () => _playGroup(ayahIdx, first, last),
        child: textWidget,
      );
    }

    return TapScale(
      onTap: () => _playGroup(ayahIdx, first, last),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? pal(context).accent.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? pal(context).accent
                  : pal(context).surfaceHigh.withValues(alpha: .9)),
        ),
        child: textWidget,
      ),
    );
  }

  /// Char-accurate tajwīd coloring for a single word (either script).
  InlineSpan _tajwidWordSpan(BuildContext context, int ayahIdx, int w,
      String displayText, TajwidAyah tj) {
    final raw = ayahs![ayahIdx];
    final ranges = QuranRepo.wordRanges(raw);
    if (w >= ranges.length) {
      return TextSpan(text: displayText, style: quranStyle(context));
    }
    final (wa, wb) = ranges[w];
    // collect spans clipped to this word, in order
    final cuts = <(int, int, int)>[]; // local start, end, rule
    for (final sp in tj.spans) {
      final a = sp[0].clamp(wa, wb), b = sp[1].clamp(wa, wb);
      if (b > a) cuts.add((a - wa, b - wa, sp[2]));
    }
    cuts.sort((x, y) => x.$1.compareTo(y.$1));
    final word = raw.substring(wa, wb);
    final children = <TextSpan>[];
    var pos = 0;
    for (final (a, b, r) in cuts) {
      if (a < pos) continue; // skip overlaps
      if (a > pos) {
        children.add(TextSpan(
            text: word.substring(pos, a), style: quranStyle(context)));
      }
      children.add(TextSpan(
          text: word.substring(a, b),
          style: quranStyle(context, color: tajwidRuleColors[r])));
      pos = b;
    }
    if (pos < word.length) {
      children.add(
          TextSpan(text: word.substring(pos), style: quranStyle(context)));
    }
    return TextSpan(children: children);
  }

  Widget _credit(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Text(
            context.l10n.wordWordRecitationCourtesyMarkaz,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 12, color: pal(context).textDim),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.textTanzilUthmaniMadaniIndopak,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 12, color: pal(context).textDim),
          ),
        ]),
      );
}
