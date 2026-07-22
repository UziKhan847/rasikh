import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/tap_longpress.dart';
import '../core/theme.dart';
import '../data/mushaf.dart';
import '../data/quran.dart';

/// 📖 True 15-line Muṣḥaf — page-for-page and line-for-line with the printed
/// QUL/DigitalKhatt layout, in Madani (Uthmānī) *and* Indo-Pak scripts.
/// • Tap a word → hear that word.  • Tap the āyah number → recite the āyah.
/// • Long-press a word → its meaning.  Verse-by-verse or continuous playback
/// (auto page-turn). Pages turn right-to-left like the physical book.
class MushafPageScreen extends StatefulWidget with DesktopAware {
  final int startPage;
  final String? script; // 'uthmani' | 'indopak'; null → current setting
  const MushafPageScreen({super.key, this.startPage = 1, this.script});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  PageController? _ctrl;
  String _script = 'uthmani';
  int _page = 1;
  int _total = 604;
  int _curSurah = 1;
  Map<int, String> _names = {};
  bool _ready = false;
  bool _booted = false;
  bool _dual = false; // desktop: two facing pages, like the open book

  /// PageView slots: one per page, or one per spread in dual mode.
  int get _viewCount => _dual ? (_total + 1) >> 1 : _total;

  /// PageView index that shows [page].
  int _indexOf(int page) => _dual ? (page - 1) >> 1 : page - 1;

  // ── audio state ──
  int _playAyah = -1; // global ayah index highlighted (-1 none)
  int _playWord = -1; // word index within _playAyah (-1 none)
  bool _reciting = false; // true = full-verse recitation (tints the verse)
  bool _warnedFallback = false;
  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    AyahAudio.instance.pos.addListener(_onRecitePos);
    _doneSub = AyahAudio.instance.onComplete.listen(_onVerseDone);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _script = widget.script ?? SettingsScope.of(context).quranScript;
    _page = widget.startPage < 1 ? 1 : widget.startPage;
    _ctrl = PageController(initialPage: _indexOf(_page));
    _load();
  }

  Future<void> _load() async {
    await MushafRepo.ensure(_script);
    final total = MushafRepo.pageCountSync(_script);
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    if (_page > total) _page = total;
    final v = MushafRepo.firstVerseOfPage(_script, _page);
    setState(() {
      _total = total;
      _names = {for (final m in metas) m.n: m.name};
      _curSurah = v.$1;
      _ready = true;
    });
  }

  @override
  void dispose() {
    AyahAudio.instance.pos.removeListener(_onRecitePos);
    _doneSub?.cancel();
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    _ctrl?.dispose();
    super.dispose();
  }

  void _jump(int p) {
    final t = p < 1 ? 1 : (p > _total ? _total : p);
    final idx = _indexOf(t);
    if (_ctrl != null && _ctrl!.hasClients && _ctrl!.page?.round() == idx) {
      // Same spread — the PageView won't fire onPageChanged, so track here.
      setState(() {
        _page = t;
        _curSurah = MushafRepo.firstVerseOfPage(_script, _page).$1;
      });
      return;
    }
    _ctrl?.jumpToPage(idx);
  }

  void _onPage(int i) {
    setState(() {
      _page = _dual ? i * 2 + 1 : i + 1;
      _curSurah = MushafRepo.firstVerseOfPage(_script, _page).$1;
    });
  }

  void _toggleDual() {
    setState(() {
      _dual = !_dual;
      final idx = _indexOf(_page);
      _ctrl?.dispose();
      _ctrl = PageController(initialPage: idx);
    });
  }

  Future<void> _switchScript(String v) async {
    if (v == _script) return;
    _stopAudio();
    final keepSurah = _curSurah;
    setState(() {
      _ready = false;
      _script = v;
    });
    final st = SettingsScope.of(context);
    st.update(() => st.quranScript = v);
    await MushafRepo.ensure(v);
    final p = await MushafRepo.pageForSurah(v, keepSurah);
    if (!mounted) return;
    _page = p;
    _ctrl?.dispose();
    _ctrl = PageController(initialPage: _indexOf(p));
    await _load();
  }

  // ── audio ──────────────────────────────────────────────────────────────
  void _onRecitePos() {
    if (!mounted || !_reciting) return;
    final w = AyahAudio.instance.wordAt(AyahAudio.instance.pos.value);
    if (w != _playWord) setState(() => _playWord = w);
  }

  void _onVerseDone(void _) {
    if (!mounted || !_reciting) return;
    final flow = SettingsScope.of(context).reciteFlow;
    if (flow == 'repeat') {
      _playVerse(_playAyah, userTap: false);
      return;
    }
    if (flow == 'auto') {
      final next = _playAyah + 1;
      if (next <= MushafRepo.lastGlobalAyah) {
        _advanceTo(next);
        return;
      }
    }
    setState(() {
      _playAyah = -1;
      _playWord = -1;
      _reciting = false;
    });
  }

  void _advanceTo(int global) {
    final pg = MushafRepo.pageForGlobalAyah(_script, global);
    final idx = _indexOf(pg);
    if (_ctrl != null && _ctrl!.hasClients && idx != _indexOf(_page)) {
      _ctrl!.animateToPage(idx,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else if (pg != _page) {
      setState(() => _page = pg); // moved within the open spread
    }
    _playVerse(global, userTap: false);
  }

  void _stopAudio() {
    WbwAudio.instance.stop();
    AyahAudio.instance.stop();
    setState(() {
      _playAyah = -1;
      _playWord = -1;
      _reciting = false;
    });
  }

  Future<void> _playVerse(int global, {bool userTap = true}) async {
    if (userTap && _reciting && _playAyah == global) {
      _stopAudio();
      return;
    }
    WbwAudio.instance.stop();
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(global);
    setState(() {
      _reciting = true;
      _playAyah = global;
      _playWord = -1;
    });
    final err = await AyahAudio.instance
        .play(surah, ayahInSurah, reciter: SettingsScope.of(context).reciter);
    if (!mounted) return;
    if (err != null) {
      _stopAudio();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(err)));
    } else if (AyahAudio.instance.fellBack && !_warnedFallback) {
      _warnedFallback = true;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar( SnackBar(
            content: Text(
                context.l10n.wordHighlightingNeedsInternetVerse)));
    }
  }

  void _playWordAudio(MushafWord wd) {
    AyahAudio.instance.stop();
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(wd.ayah);
    setState(() {
      _reciting = false;
      _playAyah = wd.ayah;
      _playWord = wd.wordIdx;
    });
    WbwAudio.instance
        .playWords(surah, ayahInSurah, wd.wordIdx + 1, wd.wordIdx + 1, (idx) {
      if (!mounted) return;
      setState(() {
        _playWord = idx;
        if (idx == -1) _playAyah = -1;
      });
    });
  }

  void _togglePlay() {
    if (_reciting) {
      if (AyahAudio.instance.playing.value) {
        AyahAudio.instance.pause();
      } else {
        AyahAudio.instance.resume();
      }
    } else {
      final fv = MushafRepo.firstVerseOfPage(_script, _page);
      _playVerse(MushafRepo.globalAyahOf(fv.$1, fv.$2), userTap: true);
    }
  }

  // ── word meaning (long-press) ──
  void _showWord(MushafWord wd) {
    final (surah, ayahInSurah) = MushafRepo.surahAyahOf(wd.ayah);
    showModalBottomSheet(
      context: context,
      backgroundColor: pal(context).surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(wd.text,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: MushafRepo.fontFamily(_script),
                      fontSize: 40,
                      color: pal(context).text)),
              const SizedBox(height: 6),
              Text(
                  context.l10n.wordN(_names[surah] ?? '',
                      '$surah:$ayahInSurah', wd.wordIdx + 1),
                  style: uiStyle(context,
                      size: 13,
                      weight: FontWeight.w700,
                      color: pal(context).textDim)),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _playWordAudio(wd);
                },
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label:  Text(context.l10n.playWord),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSurah() {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal(context).surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 460,
          child: ListView.builder(
            itemCount: 114,
            itemBuilder: (context, i) {
              final n = i + 1;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: pal(context).surfaceHigh,
                  child: Text('$n',
                      style:
                          uiStyle(context, size: 12, weight: FontWeight.w800)),
                ),
                title: Text(_names[n] ?? '',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: 'ScheherazadeNew', fontSize: 19)),
                onTap: () async {
                  final p = await MushafRepo.pageForSurah(_script, n);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _jump(p);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _onAudioMenu(String v, AppSettings s) {
    final parts = v.split(':');
    if (parts[0] == 'r') {
      s.update(() => s.reciter = parts[1]);
    } else {
      s.update(() => s.reciteFlow = parts[1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (_booted && _ready && s.quranScript != _script) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && s.quranScript != _script) _switchScript(s.quranScript);
      });
    }
    return Scaffold(
      backgroundColor: pal(context).bg,
      appBar: AppBar(
        title: Text(
            _script == 'indopak' ? context.l10n.mushafIndoPakTitle : context.l10n.mushafMadaniTitle),
        actions: [
          if (useDesktop(context))
            IconButton(
              tooltip: _dual
                  ? context.l10n.singlePage
                  : context.l10n.twoPageSpread,
              icon: Icon(_dual
                  ? Icons.description_rounded
                  : Icons.auto_stories_rounded),
              onPressed: _ready ? _toggleDual : null,
            ),
          PopupMenuButton<String>(
            tooltip: context.l10n.view,
            icon: Icon(s.immersive
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded),
            onSelected: (v) {
              if (v == 'i') {
                s.update(() => s.immersive = !s.immersive);
              } else if (v == 'h') {
                s.update(() => s.mushafHeader = !s.mushafHeader);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'i',
                  checked: s.immersive,
                  child:  Text(context.l10n.immersiveHideSystemBars)),
              CheckedPopupMenuItem(
                  value: 'h',
                  checked: s.mushafHeader,
                  child:  Text(context.l10n.pageHeader)),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.recitation,
            icon: const Icon(Icons.headphones_rounded),
            onSelected: (v) => _onAudioMenu(v, s),
            itemBuilder: (_) => [
               PopupMenuItem(
                  enabled: false,
                  child: Text(context.l10n.reciter,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              CheckedPopupMenuItem(
                  value: 'r:tunaiji',
                  checked: s.reciter == 'tunaiji',
                  child:  Text(context.l10n.alTunaiji)),
              CheckedPopupMenuItem(
                  value: 'r:alafasy',
                  checked: s.reciter == 'alafasy',
                  child:  Text(context.l10n.alAfasiWordSync)),
              CheckedPopupMenuItem(
                  value: 'r:husary',
                  checked: s.reciter == 'husary',
                  child:  Text(context.l10n.alHusariWordSync)),
              const PopupMenuDivider(),
               PopupMenuItem(
                  enabled: false,
                  child: Text(context.l10n.playback,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              CheckedPopupMenuItem(
                  value: 'f:single',
                  checked: s.reciteFlow == 'single',
                  child:  Text(context.l10n.verseByVerse)),
              CheckedPopupMenuItem(
                  value: 'f:auto',
                  checked: s.reciteFlow == 'auto',
                  child:  Text(context.l10n.continuous)),
              CheckedPopupMenuItem(
                  value: 'f:repeat',
                  checked: s.reciteFlow == 'repeat',
                  child:  Text(context.l10n.repeatVerse)),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.script,
            icon: const Icon(Icons.translate_rounded),
            onSelected: _switchScript,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'uthmani',
                  checked: _script == 'uthmani',
                  child:  Text(context.l10n.madaniUthmani)),
              CheckedPopupMenuItem(
                  value: 'indopak',
                  checked: _script == 'indopak',
                  child:  Text(context.l10n.indoPak)),
            ],
          ),
          IconButton(
            tooltip: context.l10n.jumpToSurah,
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: _ready ? _pickSurah : null,
          ),
        ],
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator(color: pal(context).accent))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    // A phone on its side: short and wide. There the page uses
                    // the FULL width so the lines grow, and scrolls vertically
                    // instead of shrinking to fit the short side. Desktop and
                    // tablets are wide but tall enough, so they keep the
                    // centred book column.
                    final wide =
                        c.maxWidth > c.maxHeight && c.maxHeight < 520;
                    final maxW =
                        wide ? double.infinity : (_dual ? 1440.0 : 720.0);
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: PageView.builder(
                          key: ValueKey('$_script-$_dual'),
                          controller: _ctrl,
                          reverse: true, // right-to-left page turning
                          itemCount: _viewCount,
                          onPageChanged: _onPage,
                          itemBuilder: (context, i) {
                            if (!_dual) {
                              return _buildPage(i + 1, wide, s);
                            }
                            // A spread, like the open book: the LOWER page on
                            // the right, its successor on the left.
                            final right = i * 2 + 1;
                            final left = right + 1;
                            return Row(children: [
                              Expanded(
                                  child: left <= _total
                                      ? _buildPage(left, wide, s)
                                      : const SizedBox()),
                              Expanded(child: _buildPage(right, wide, s)),
                            ]);
                          },
                        ),
                      ),
                    );
                  }),
                ),
                _bottomBar(context),
              ],
            ),
    );
  }

  Widget _buildPage(int page, bool wide, AppSettings s) => _MushafPageView(
        page: page,
        script: _script,
        names: _names,
        wideLayout: wide,
        showHeader: s.mushafHeader,
        playAyah: _playAyah,
        playWord: _playWord,
        reciting: _reciting,
        onTapWord: _playWordAudio,
        onLongPressWord: _showWord,
        onTapVerse: (g) => _playVerse(g),
      );

  Widget _bottomBar(BuildContext context) {
    final juz = MushafRepo.juzOfPage(_script, _page);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      decoration: BoxDecoration(
        color: pal(context).surface,
        border: Border(top: BorderSide(color: pal(context).surfaceHigh)),
      ),
      // SafeArea INSIDE the container: the bar's surface extends behind the
      // system navigation area, while the controls sit above it — so devices
      // with gesture pills or 3-button nav (e.g. Pixel 7 Pro) can't overlap
      // the play button or the page slider.
      child: SafeArea(
        top: false,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              Text(_names[_curSurah] ?? '',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontFamily: 'ScheherazadeNew', fontSize: 18)),
              const Spacer(),
              Text(context.l10n.juzPageOf(juz, _page, _total),
                  style: uiStyle(context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: pal(context).textDim)),
              const SizedBox(width: 6),
            ],
          ),
          // The page rail is a BOOK control, not UI chrome: its geometry is
          // fixed in every language (page 1 at the right, left chevron turns
          // to the next page). Pinned to LTR so the chevrons keep their sides
          // when the app itself is Arabic or Urdu; the slider below carries
          // its own RTL so page 1 still sits at the right-hand end.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
            children: [
              // play / pause the page (continues per playback mode)
              ValueListenableBuilder<bool>(
                valueListenable: AyahAudio.instance.playing,
                builder: (context, playing, _) => IconButton(
                  tooltip: _reciting
                      ? (playing ? context.l10n.pause : context.l10n.resume)
                      : context.l10n.playPage,
                  icon: Icon(
                      _reciting && playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 34,
                      color: pal(context).accent),
                  onPressed: _togglePlay,
                ),
              ),
              if (_reciting)
                IconButton(
                  tooltip: context.l10n.stop,
                  icon: Icon(Icons.stop_circle_rounded,
                      size: 26, color: pal(context).textDim),
                  onPressed: _stopAudio,
                ),
              // The book reads right-to-left, so the page rail does too: page 1
              // sits at the RIGHT end and the LEFT chevron turns to the next
              // page. Forced RTL here regardless of the app's language.
              IconButton(
                tooltip: context.l10n.nextPage,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _page < _total ? () => _jump(_page + 1) : null,
              ),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Slider(
                    min: 1,
                    max: _total.toDouble(),
                    value: _page.toDouble().clamp(1, _total.toDouble()),
                    onChanged: (v) => _jump(v.round()),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.previousPage,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _page > 1 ? () => _jump(_page - 1) : null,
              ),
            ],
          ),
          ),
        ],
        ),
      ),
    );
  }
}

class _MushafPageView extends StatelessWidget {
  final int page;
  final String script;
  final Map<int, String> names;
  final bool wideLayout;
  final bool showHeader;
  final int playAyah;
  final int playWord;
  final bool reciting;
  final void Function(MushafWord) onTapWord;
  final void Function(MushafWord) onLongPressWord;
  final void Function(int globalAyah) onTapVerse;
  const _MushafPageView({
    required this.page,
    required this.script,
    required this.names,
    required this.wideLayout,
    required this.showHeader,
    required this.playAyah,
    required this.playWord,
    required this.reciting,
    required this.onTapWord,
    required this.onLongPressWord,
    required this.onTapVerse,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final lines = MushafRepo.pageSync(script, page);
    if (lines == null || lines.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: pal(context).accent));
    }
    final paper = s.paperMode ? pal(context).paper : pal(context).surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: pal(context).accent.withValues(alpha: .35), width: 1.4),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              if (showHeader) _pageHeader(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) =>
                      _grid(context, lines, c.maxWidth, c.maxHeight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Traditional muṣḥaf running head: sūrah on the left, page in the middle,
  /// juzʼ on the right.
  Widget _pageHeader(BuildContext context) {
    final on = SettingsScope.of(context).paperMode;
    final ink = on ? pal(context).paperInk : pal(context).text;
    final v = MushafRepo.firstVerseOfPage(script, page);
    final juz = MushafRepo.juzOfPage(script, page);
    final label = uiStyle(context,
        size: 11.5, weight: FontWeight.w700, color: ink.withValues(alpha: .7));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: pal(context).accent.withValues(alpha: .35), width: .8)),
      ),
      // The running head is part of the PAGE, not the UI chrome: sūrah left,
      // page centre, juzʼ right, exactly as it is printed. A bare Row would
      // follow the app language and mirror the whole thing in Arabic/Urdu, so
      // the direction is pinned here.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Text(names[v.$1] ?? '',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 15,
                      height: 1.35,
                      color: pal(context).accentDeep)),
            ),
            Text('$page', style: label),
            Expanded(
              child: Text(context.l10n.juzOnly(juz),
                  textAlign: TextAlign.right, style: label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(
      BuildContext context, List<MushafLine> lines, double vw, double vh) {
    final ink = SettingsScope.of(context).paperMode
        ? pal(context).paperInk
        : pal(context).text;
    final fam = MushafRepo.fontFamily(script);
    final n = lines.isEmpty ? 1 : lines.length;

    // A short-and-wide viewport (phone landscape) lays the page out to the
    // FULL width and lets it run taller than the viewport — the page then
    // scrolls vertically instead of being squeezed down to fit the short side.
    final fitWidth = wideLayout;
    final targetW = vw;

    const ref = 44.0;
    final refStyle = TextStyle(fontFamily: fam, fontSize: ref, height: 1.0);
    double widest = 1;
    for (final l in lines) {
      if (!l.isText) continue;
      final tp = TextPainter(
          text: TextSpan(
              text: l.words.map((e) => e.text).join(' '), style: refStyle),
          textDirection: TextDirection.rtl,
          maxLines: 1)
        ..layout();
      if (tp.width > widest) widest = tp.width;
      tp.dispose();
    }
    final byWidth = ref * (targetW / widest);

    final double fs;
    final double slotH;
    if (fitWidth) {
      fs = byWidth.clamp(11.0, 96.0);
      slotH = fs / 0.62;
    } else {
      slotH = vh / n;
      final byHeight = slotH * 0.62;
      fs = (byWidth < byHeight ? byWidth : byHeight).clamp(11.0, 46.0);
    }
    final base = TextStyle(fontFamily: fam, fontSize: fs, color: ink);
    final contentH = fitWidth ? slotH * n : vh;

    final page = SizedBox(
      height: contentH,
      width: targetW,
      child: Column(
        children: [
          for (final l in lines)
            Expanded(
                child: Center(
                    child: _slot(context, l, base, targetW, slotH, ink))),
        ],
      ),
    );
    if (!fitWidth) return page;

    // Flutter desktop only drags scrollables with touch by default — extend
    // that to mouse and trackpad so the tall page can be panned with a
    // pointer too.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      }),
      child: SingleChildScrollView(child: page),
    );
  }

  Widget _slot(BuildContext context, MushafLine l, TextStyle base,
      double targetW, double slotH, Color ink) {
    if (l.isHeader) {
      final glyph = (l.surah >= 1 && l.surah <= surahGlyphCodes.length)
          ? surahGlyphCodes[l.surah - 1]
          : null;
      return Container(
        width: targetW,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: pal(context).accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pal(context).accent.withValues(alpha: .45)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: glyph == null
              ? Text(names[l.surah] ?? '',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 20,
                      color: pal(context).accentDeep))
              : Text(String.fromCharCodes([glyph, 0xe903]),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: 'SurahNames',
                      fontSize: slotH * 0.82,
                      color: pal(context).accentDeep)),
        ),
      );
    }
    if (l.isBasmala) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(MushafRepo.bismillahChar,
            textDirection: TextDirection.rtl,
            style: TextStyle(
                fontFamily: 'Bismillah',
                fontSize: slotH * 0.62,
                color: pal(context).accentDeep)),
      );
    }
    return _textLine(context, l, base, targetW, slotH, ink);
  }

  Widget _textLine(BuildContext context, MushafLine l, TextStyle base,
      double targetW, double slotH, Color ink) {
    final accent = pal(context).accent;
    final strongBg = accent.withValues(alpha: .30);
    final verseBg = accent.withValues(alpha: .10);

    final spans = <InlineSpan>[];
    // Character ranges of the āyah markers, for the enlarged hit targets.
    final markers = <(int start, int end, int ayah)>[];
    var chars = 0;
    for (var i = 0; i < l.words.length; i++) {
      final wd = l.words[i];
      final onVerse = reciting && wd.ayah == playAyah;
      final active = wd.ayah == playAyah &&
          !wd.isMarker &&
          wd.wordIdx == playWord;
      final style = base.copyWith(
        color: active ? pal(context).accentDeep : ink,
        backgroundColor: active ? strongBg : (onVerse ? verseBg : null),
      );
      if (wd.isMarker) {
        markers.add((chars, chars + wd.text.length, wd.ayah));
      }
      spans.add(TextSpan(
        text: wd.text,
        style: style,
        // Both branches use the SAME recognizer: it invokes onTap straight
        // from the pointer-up, instead of waiting to win the gesture arena
        // the way a plain TapGestureRecognizer does. That arena wait is what
        // swallowed clicks on the āyah circles with a mouse, while the words
        // beside them (already on this recognizer) kept working.
        mouseCursor: SystemMouseCursors.click,
        recognizer: wd.isMarker
            ? TapAndLongPressGestureRecognizer(
                onTap: () => onTapVerse(wd.ayah),
                onLongPress: () => onTapVerse(wd.ayah),
              )
            : TapAndLongPressGestureRecognizer(
                onTap: () => onTapWord(wd),
                onLongPress: () => onLongPressWord(wd),
              ),
      ));
      chars += wd.text.length;
      if (i != l.words.length - 1) {
        spans.add(TextSpan(text: ' ', style: base));
        chars += 1;
      }
    }

    final measure = TextPainter(
        text: TextSpan(children: spans, style: base),
        textDirection: TextDirection.rtl,
        maxLines: 1)
      ..layout();
    final natural = measure.width;
    measure.dispose();

    // NOTE textScaler.noScaling on both branches: the page sizes its own text
    // to fit the printed geometry, but Text.rich would additionally inherit
    // the SYSTEM font scale that TextPainter above knows nothing about. With
    // any accessibility scale >1 the mismatch clipped words at the left
    // margin and left "justified" lines short of it.
    final spaces = l.words.length - 1;
    final justified = natural >= targetW * 0.45 && spaces > 0;
    final wordSpacing =
        justified ? ((targetW - natural) / spaces).clamp(0.0, 1e6) : 0.0;
    final rootStyle =
        justified ? base.copyWith(wordSpacing: wordSpacing) : base;

    final text = Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      softWrap: false,
      maxLines: 1,
      style: rootStyle,
    );

    if (markers.isEmpty) {
      return justified
          ? SizedBox(width: targetW, child: text)
          : Center(child: text);
    }

    // ── enlarged hit targets over the āyah circles ──
    // The circle's own glyph box is small and sits inside big justified gaps,
    // so near-misses land on a bare space span and nothing happens. Lay the
    // final line out once more and float an invisible tap target over each
    // marker: full slot height, widened into the surrounding gaps.
    final tp = TextPainter(
        text: TextSpan(children: spans, style: rootStyle),
        textDirection: TextDirection.rtl,
        maxLines: 1)
      ..layout();
    final lineW = justified ? targetW : tp.width;
    final extra = slotH - tp.height;
    final vPad = extra > 0 ? (extra / 2).clamp(0.0, 14.0) : 0.0;
    final boxH = tp.height + vPad * 2;
    final hPad = (8.0 + wordSpacing / 2).clamp(8.0, 26.0);
    final xOff = (lineW - tp.width) / 2;

    final hits = <Positioned>[];
    for (final m in markers) {
      final boxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: m.$1, extentOffset: m.$2));
      if (boxes.isEmpty) continue;
      var left = boxes.first.left, right = boxes.first.right;
      for (final b in boxes) {
        if (b.left < left) left = b.left;
        if (b.right > right) right = b.right;
      }
      final ayah = m.$3;
      hits.add(Positioned(
        left: (xOff + left - hPad).clamp(0.0, lineW),
        top: 0,
        width: (right - left) + hPad * 2,
        height: boxH,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTapVerse(ayah),
          ),
        ),
      ));
    }
    tp.dispose();

    final stack = Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(width: lineW, height: boxH),
        text,
        ...hits,
      ],
    );
    return justified ? stack : Center(child: stack);
  }
}
