part of '../mushaf_screen.dart';

/// Hifẓ mode's tools that aren't modes of their own: a tap on a word then
/// opens its comments, wipes its marks, or plays it. (The pen is marking
/// mode, memorize is memorize mode.)
enum _HifzTool { none, comment, eraser, audio }

/// The muṣḥaf as Hifẓ mode's home ([MushafPageScreen.home]): the page
/// borderless at 95% of the width (its height by its shape, fitted to the
/// height when that's shorter), a line above it — sūrah · page · juzʼ, each
/// opening its list — and one toolbar: Settings · Index · Pen · Comment ·
/// Eraser · Audio · Memorize · View. Along the bottom in portrait; down the
/// right edge beside two facing pages in landscape, on tablets and desktop.
/// The pen, audio, memorize, comment and eraser bring their own row of
/// tools (in landscape it floats over the pages' foot).
extension _HifzChrome on _MushafPageScreenState {
  Widget _hifzBody(BuildContext context, AppSettings s, MushafPaper paper) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > c.maxHeight;
        _setPhoneSpread(wide);
        _setLandscape(wide && c.maxHeight < 520);
        final pad = MediaQuery.paddingOf(context);
        final pager = wide
            ? _spreadPager(s, paper,
                margin: EdgeInsets.fromLTRB(8, 2, 8, 4 + _hifzFloatRoom))
            : _pager(s, paper,
                fitWidth: false,
                margin: EdgeInsets.symmetric(
                    horizontal: c.maxWidth * .025, vertical: 2));
        return ValueListenableBuilder<int>(
          valueListenable: _pageN,
          child: pager,
          builder: (context, _, pager) {
            final header = _hifzHeader(context, paper, wide);
            if (!wide) {
              return Column(children: [
                SizedBox(height: pad.top),
                header,
                Expanded(child: pager!),
                _hifzBar(context, s, paper),
              ]);
            }
            final row = _hifzToolRow(context, s, paper);
            return Row(children: [
              Expanded(
                child: Stack(children: [
                  Column(children: [
                    SizedBox(height: pad.top),
                    header,
                    Expanded(child: pager!),
                  ]),
                  // A tool's own row floats over the pages' foot.
                  if (row != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: pad.bottom + 8,
                      child: Center(child: _hifzFloating(paper, row)),
                    ),
                ]),
              ),
              _hifzMainTools(context, s, paper, vertical: true),
            ]);
          },
        );
      }),
    );
  }

  /// Room kept under two facing pages for a tool's floating row.
  double get _hifzFloatRoom =>
      _marking.active || _memorizing || _reviewing || _hifzTool != _HifzTool.none
          ? 64
          : 0;

  // ── the line above the page ──

  Widget _hifzHeader(BuildContext context, MushafPaper paper, bool spread) {
    final page = _pendingPage ?? _page;
    final first = spread ? _spreadStart(page) : page;
    final juz = MushafRepo.juzOfPage(_script, first);
    final surah = MushafRepo.firstVerseOfPage(_script, first).$1;
    final pages = spread && first < _total ? '$first – ${first + 1}' : '$first';
    final style = uiStyle(context, size: 14, weight: FontWeight.w600, color: paper.acc);
    Widget item(String text, Division d, {TextAlign align = TextAlign.center}) =>
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _hifzIndex(d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(text,
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(decoration: TextDecoration.underline,
                    decorationColor: paper.acc.withValues(alpha: .4))),
          ),
        );
    // Fixed left to right, as a printed page's head: sūrah · page · juzʼ.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: item(_tnames[surah] ?? '', Division.surah,
                      align: TextAlign.left))),
          item(pages, Division.page),
          Expanded(
              child: Align(
                  alignment: Alignment.centerRight,
                  child: item(context.l10n.juzN(juz), Division.juz,
                      align: TextAlign.right))),
        ]),
      ),
    );
  }

  void _hifzIndex(Division d) => showMushafIndex(
        context,
        script: _script,
        currentPage: _pendingPage ?? _page,
        initial: d,
        onPage: (p) => _jump(p),
        onWord: _focusWord,
      );

  // ── the toolbar ──

  /// Portrait: a tool's own row in place of the main one.
  Widget _hifzBar(BuildContext context, AppSettings s, MushafPaper paper) {
    final pad = MediaQuery.paddingOf(context);
    final row = _hifzToolRow(context, s, paper);
    return Container(
      padding: EdgeInsets.fromLTRB(8, 6, 8, pad.bottom + 6),
      decoration: BoxDecoration(
        color: paper.chrome,
        border: Border(top: BorderSide(color: paper.line)),
      ),
      child: row ?? _hifzMainTools(context, s, paper, vertical: false),
    );
  }

  Widget _hifzFloating(MushafPaper paper, Widget row) => Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: paper.chrome,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: paper.line),
        ),
        child: row,
      );

  /// Settings · Index · Pen · Comment · Eraser · Audio · Memorize · View.
  Widget _hifzMainTools(BuildContext context, AppSettings s, MushafPaper paper,
      {required bool vertical}) {
    final l = context.l10n;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    Widget tool(IconData icon, String tip, VoidCallback onTap,
            {bool on = false, VoidCallback? onLong}) =>
        Tooltip(
          message: tip,
          triggerMode: onLong == null ? TooltipTriggerMode.longPress : TooltipTriggerMode.manual,
          child: Material(
            color: on ? accent.withValues(alpha: .14) : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLong,
              child: SizedBox.square(
                dimension: 44,
                child: Icon(icon, size: 22, color: on ? accent : paper.ink),
              ),
            ),
          ),
        );
    final tools = <Widget>[
      // Settings; holding it: the mode switcher.
      GestureDetector(
        onLongPress: () => showModeSheet(context),
        child: tool(AppIcons.settings, l.settings,
            () => openSection(context, AppSection.settings),
            onLong: () => showModeSheet(context)),
      ),
      tool(AppIcons.indexList, l.idxIndex, () => _hifzIndex(Division.surah)),
      tool(AppIcons.pen, l.mkMarkRecitation, _hifzPen, on: _marking.active),
      tool(AppIcons.comment, l.mkComment, () => _hifzSetTool(_HifzTool.comment),
          on: _hifzTool == _HifzTool.comment),
      tool(AppIcons.eraser, l.hzEraser, () => _hifzSetTool(_HifzTool.eraser),
          on: _hifzTool == _HifzTool.eraser, onLong: _hifzErasePage),
      tool(AppIcons.volume, l.recitation, () => _hifzSetTool(_HifzTool.audio),
          on: _hifzTool == _HifzTool.audio),
      tool(AppIcons.memorize, l.mzMemorize, _hifzMemorize, on: _memorizing),
      tool(AppIcons.pageColour, l.hzView, () => _hifzView(s)),
    ];
    if (vertical) {
      final pad = MediaQuery.paddingOf(context);
      return Container(
        width: 60 + pad.right,
        padding: EdgeInsets.fromLTRB(4, pad.top + 6, 4 + pad.right, pad.bottom + 6),
        decoration: BoxDecoration(
          color: paper.chrome,
          border: Border(left: BorderSide(color: paper.line)),
        ),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: tools,
              ),
            ),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final t in tools) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: t),
        ]),
      ),
    );
  }

  /// The active tool's own row, or null for the main tools.
  Widget? _hifzToolRow(BuildContext context, AppSettings s, MushafPaper paper) {
    final l = context.l10n;
    if (_memorizing) return _memorizeBar(paper, compact: true);
    if (_reviewing) return _reviewBar(paper);
    if (_marking.active) return _markingBar(paper);
    if (_hifzTool == _HifzTool.none) return null;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    Widget done() => TextButton(
          onPressed: () => _hifzSetTool(_HifzTool.none),
          child: Text(l.nbDone,
              style: uiStyle(context, size: 14, weight: FontWeight.w700, color: accent)),
        );
    Widget hint(String t) => Expanded(
          child: Text(t,
              maxLines: 2,
              style: uiStyle(context, size: 13, color: paper.sub)),
        );
    return Row(children: [
      if (_hifzTool == _HifzTool.audio) ...[
        _reciteButton(context, paper, size: 42),
        const SizedBox(width: 6),
        IconButton(
          tooltip: l.stop,
          onPressed: _stopAudio,
          icon: Icon(AppIcons.stop, color: paper.ink),
        ),
        TextButton.icon(
          onPressed: () => s.update(() => s.playbackSpeed =
              s.playbackSpeed >= 1.25 ? .75 : s.playbackSpeed + .25),
          icon: Icon(AppIcons.speed, size: 18, color: paper.ink),
          label: Text('${s.playbackSpeed}×',
              style: uiStyle(context, size: 13.5, weight: FontWeight.w700, color: paper.ink)),
        ),
        hint(l.hzAudioHint),
      ] else if (_hifzTool == _HifzTool.comment) ...[
        Icon(AppIcons.comment, color: accent),
        const SizedBox(width: 10),
        hint(l.hzCommentHint),
      ] else ...[
        Icon(AppIcons.eraser, color: accent),
        const SizedBox(width: 10),
        hint(l.hzEraserHint),
        TextButton(
          onPressed: _hifzErasePage,
          child: Text(l.hzErasePage,
              style: uiStyle(context, size: 13.5, weight: FontWeight.w700, color: paper.ink)),
        ),
      ],
      done(),
    ]);
  }

  void _hifzSetTool(_HifzTool t) {
    if (_marking.active) _marking.stop();
    if (_memorizing) _endMemorize();
    _update(() => _hifzTool = _hifzTool == t ? _HifzTool.none : t);
  }

  void _hifzPen() {
    _update(() => _hifzTool = _HifzTool.none);
    if (_memorizing) _endMemorize();
    _toggleMarking();
  }

  void _hifzMemorize() {
    _update(() => _hifzTool = _HifzTool.none);
    if (_memorizing) {
      _endMemorize();
    } else {
      _startMemorize();
    }
  }

  // ── tool taps ──

  /// The tap handlers for the active tool (Hifẓ mode, nothing else on).
  void _hifzHandlers() {
    WordRef ref(MushafWord wd) => WordRef.fromGlobal(wd.ayah, wd.wordIdx);
    switch (_hifzTool) {
      case _HifzTool.comment:
        _handlers
          ..onTapWord = ((wd) => _hifzComment(ref(wd)))
          ..onLongPressWord = ((wd) => _hifzComment(ref(wd)))
          ..onTapVerse = ((g) => _hifzComment(WordRef.fromGlobal(g, -1)))
          ..onLongPressVerse = ((wd) => _hifzComment(ref(wd)));
      case _HifzTool.eraser:
        _handlers
          ..onTapWord = ((wd) => _hifzErase([ref(wd)]))
          ..onLongPressWord = ((wd) => _hifzErase([ref(wd)]))
          ..onTapVerse = ((g) => _hifzErase([WordRef.fromGlobal(g, -1)]))
          ..onLongPressVerse = ((wd) => _hifzErase([ref(wd)]));
      case _HifzTool.audio:
        _handlers
          ..onTapWord = _playWordAudio
          ..onLongPressWord = _showWord
          ..onTapVerse = _playVerse
          ..onLongPressVerse = _showWord;
      case _HifzTool.none:
        // No tool: the page is for reading; holding a word opens its sheet.
        _handlers
          ..onTapWord = ((_) => _lastWordTap = DateTime.now())
          ..onLongPressWord = _showWord
          ..onTapVerse = ((_) => _lastWordTap = DateTime.now())
          ..onLongPressVerse = _showWord;
    }
  }

  /// A word's comments, in a bubble beside it: its marks, their comments
  /// and replies, and adding one (a note mark, on a word without marks).
  void _hifzComment(WordRef ref) {
    _lastWordTap = DateTime.now();
    final at = _lastDown;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .08),
      pageBuilder: (dialog, _, _) {
        final size = MediaQuery.sizeOf(dialog);
        const w = 340.0, maxH = 440.0;
        final left = (at.dx - w / 2).clamp(8.0, (size.width - w - 8).clamp(8.0, 1e9));
        final below = at.dy + 24 + maxH < size.height;
        return Stack(children: [
          Positioned(
            left: left,
            top: below ? at.dy + 24 : null,
            bottom: below ? null : (size.height - at.dy + 24).clamp(8.0, 1e9),
            width: w,
            child: Material(
              color: pal(dialog).card,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: maxH),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: WordMarksPanel(
                    ref: ref,
                    sessionId: _marking.active ? _marking.sessionId : null,
                    onLink: (m) {
                      Navigator.pop(dialog);
                      _startLinking(m);
                    },
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  /// Wipes the marks (their fixes, comments and links) on [refs] in the
  /// active book; an Undo brings them back.
  void _hifzErase(List<WordRef> refs, {bool quiet = false}) {
    _lastWordTap = DateTime.now();
    final store = MarksScope.maybeOf(context);
    final book = store?.activeBook;
    if (store == null || book == null) return;
    final ops = <MarkOp>[];
    for (final r in refs) {
      for (final m in [...store.marksAt(book.id, r)]) {
        ops.add(store.deleteMark(m));
      }
    }
    if (ops.isEmpty) {
      if (!quiet) showQToast(context, context.l10n.hzNothingToErase);
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.hzErased(ops.length)),
        action: SnackBarAction(
          label: context.l10n.hzUndo,
          onPressed: () {
            for (final op in ops.reversed) {
              store.undo(op);
            }
          },
        ),
      ));
  }

  /// Holding the eraser: everything marked on the page (or both pages)
  /// in view, after a confirmation — and still undoable.
  Future<void> _hifzErasePage() async {
    final page = _pendingPage ?? _page;
    final pages = _phoneSpread
        ? [_spreadStart(page), _spreadStart(page) + 1]
        : [page];
    final refs = <WordRef>[];
    for (final p in pages) {
      for (final l in MushafRepo.pageSync(_script, p) ?? const <MushafLine>[]) {
        for (final w in l.words) {
          refs.add(WordRef.fromGlobal(w.ayah, w.isMarker ? -1 : w.wordIdx));
        }
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(d.l10n.hzErasePageQ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(d.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(d.l10n.hzErasePage)),
        ],
      ),
    );
    if (ok == true && mounted) _hifzErase(refs);
  }

  // ── View ──

  /// Script, colouring, the page's colour, and light / dark / OLED.
  void _hifzView(AppSettings s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final l = sheet.l10n;
        final p = pal(sheet);
        void set(VoidCallback f) {
          s.update(f);
          setSheet(() {});
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              QRow(
                title: l.arabicScript,
                control: QSegmented<String>(
                  expand: false,
                  options: [
                    ('uthmani', l.madani, null),
                    ('indopak', l.indoPak, null),
                  ],
                  value: _script,
                  onChanged: (v) {
                    Navigator.pop(sheet);
                    _switchScript(v);
                  },
                ),
              ),
              QRow(
                title: l.hzColouring,
                control: QSegmented<String>(
                  expand: false,
                  options: [
                    ('off', l.hzOff, null),
                    ('tajwid', l.tajwid, null),
                    ('nabr', l.hzNabr, null),
                  ],
                  value: s.mushafTajwid ? 'tajwid' : 'off',
                  onChanged: (v) {
                    if (v == 'nabr') {
                      showQToast(sheet, l.nbFuture);
                      return;
                    }
                    set(() => s.mushafTajwid = v == 'tajwid');
                  },
                ),
              ),
              QRow(
                title: l.theme,
                control: QSegmented<String>(
                  expand: false,
                  options: [
                    ('light', l.themeLight, null),
                    ('night', l.themeDark, null),
                    ('oled', l.themeOled, null),
                  ],
                  value: s.appTheme == 'mono' ? 'light' : s.appTheme,
                  onChanged: (v) => set(() {
                    s.appTheme = v;
                    s.mushafPaperDark = 'default';
                  }),
                ),
              ),
              if (s.theme == AppTheme.light) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(l.pageColour,
                      style: uiStyle(sheet, size: 13, weight: FontWeight.w700, color: p.ink3)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(spacing: 12, runSpacing: 10, children: [
                    for (final id in const ['cream', 'white', 'madani', 'tile1', 'tile2', 'tile3'])
                      _Swatch(
                        paper: kMushafPapers[id]!,
                        selected: mushafPaperOf(s, _script).id == id,
                        onTap: () => set(() => s.mushafPaper = id),
                      ),
                  ]),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// A page colour to pick: the paper with its accent.
class _Swatch extends StatelessWidget {
  final MushafPaper paper;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.paper, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: paper.paper,
            border: Border.all(
                color: selected ? paper.acc : pal(context).line2, width: selected ? 3 : 1),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: paper.acc),
          ),
        ),
      );
}
