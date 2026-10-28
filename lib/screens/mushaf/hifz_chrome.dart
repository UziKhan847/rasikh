part of '../mushaf_screen.dart';

/// Hifẓ mode's tools that aren't modes of their own: a tap on a word then
/// opens its comments, wipes its marks, or plays it. (The pen is marking
/// mode, memorize is memorize mode.)
enum _HifzTool { none, comment, eraser, audio }

/// The muṣḥaf as Hifẓ mode's home ([MushafPageScreen.home]), laid out by
/// [HifzLayout] — fixed by the window, so turning a tool on never moves the
/// pages. Portrait: the line above the page (sūrah · page · juzʼ, each
/// opening its list), the page, the dock along the bottom. Landscape: two
/// facing pages with a line between them and a margin rail each (juzʼ,
/// page in a lantern, sūrah), the dock down the right edge. The dock:
/// Settings · Index · Pen · Comment · Eraser · Audio · Memorize · View;
/// holding a tool (or tapping it while it's on) opens its options in a
/// popover beside it. The pen, audio, memorize, comment and eraser bring
/// their own bar: in the dock's place in portrait, in the slot beside the
/// dock (or under the pages) in landscape.
extension _HifzChrome on _MushafPageScreenState {
  Widget _hifzBody(BuildContext context, AppSettings s, MushafPaper paper) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, c) {
        final pad = MediaQuery.paddingOf(context);
        _checkRotation(c.biggest);
        final layout = HifzLayout.resolve(c.biggest, pad,
            dockLeft: _dockLeft,
            pages: s.hifzLandscapePages,
            pageBox: (a) => MushafGeometry.pageBox(a, _script,
                look: _look(s), header: s.mushafHeaderShown, compact: true));
        final spread = layout.landscape && layout.pages == 'two';
        _setPhoneSpread(spread);
        _setLandscape(layout.landscape && c.maxHeight < 520);
        _preloadGlyphs(layout, s);
        final Widget pages;
        if (spread) {
          pages = _spreadPager(s, paper,
              margin: layout.pagesInset, rail: layout.rail, gap: layout.gap);
        } else if (layout.landscape) {
          // One page as wide as the spread was (the bars keep their slot
          // beside it), or across the whole width (they float over its
          // foot): either way it runs as tall as it is and scrolls, with
          // room past its end to bring all of it clear of a bar.
          final inset = layout.pagesInset;
          final side = layout.pages == 'one'
              ? ((layout.pager.width - inset.horizontal - layout.spreadWidth) / 2)
                  .clamp(0.0, double.infinity)
              : 0.0;
          pages = _pager(s, paper,
              fitWidth: true,
              margin: EdgeInsets.fromLTRB(inset.left + side, 6,
                  inset.right + side,
                  layout.slotAxis == Axis.horizontal
                      ? layout.slot.height + 12
                      : 6));
        } else {
          pages = _pager(s, paper,
              fitWidth: false,
              margin: EdgeInsets.symmetric(
                  horizontal: c.maxWidth * .025, vertical: 2),
              head: (page, _) =>
                  RepaintBoundary(child: _hifzHeader(context, paper, page)));
        }
        final pager = ClipRect(
          child: MushafZoom(
            active: _zoom,
            onActive: _hifzSetZoom,
            controller: _zoomCtrl,
            child: KeyedSubtree(key: _pagerKey, child: pages),
          ),
        );
        return ValueListenableBuilder<int>(
          valueListenable: _pageN,
          child: pager,
          builder: (context, _, pager) {
            final bar = _hifzToolBar(context, s, paper, layout.slotAxis);
            final dockAxis = layout.landscape ? Axis.vertical : Axis.horizontal;
            final dockSide = !layout.landscape
                ? AxisDirection.up
                : (layout.dockLeft ? AxisDirection.right : AxisDirection.left);
            return Stack(children: [
              Positioned.fromRect(rect: layout.pager, child: pager!),
              Positioned(
                top: layout.pager.top + 8,
                left: layout.pager.left + 16,
                right: c.maxWidth - layout.pager.right + 16,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _zoom && _zoomHint ? 1 : 0,
                      duration: motion(context, const Duration(milliseconds: 250)),
                      child: _hifzHintPill(paper, context.l10n.hzZoomHint),
                    ),
                  ),
                ),
              ),

              Positioned.fromRect(
                rect: layout.dock,
                child: HifzDock(
                  axis: dockAxis,
                  onLeft: layout.dockLeft,
                  paper: paper,
                  items: _hifzItems(context, s, paper, dockSide),
                  safe: layout.landscape
                      ? EdgeInsets.only(
                          top: pad.top,
                          bottom: pad.bottom,
                          left: layout.dockLeft ? pad.left : 0,
                          right: layout.dockLeft ? 0 : pad.right)
                      : EdgeInsets.only(
                          left: pad.left, right: pad.right, bottom: pad.bottom),
                  replacement: layout.landscape || bar == null
                      ? null
                      : Center(child: bar),
                ),
              ),
              if (layout.landscape && bar != null)
                Positioned.fromRect(
                  rect: layout.slot,
                  child: _hifzSlot(paper, layout.slotAxis, bar),
                ),
            ]);
          },
        );
      }),
    );
  }

  /// The dock's zoom. Touch: the swipe stops and two fingers pinch (a
  /// word of how, the first times). A mouse: in a little, to drag about
  /// (Ctrl and the wheel zoom from anywhere, without it).
  void _hifzZoomButton(BuildContext button) {
    if (_zoom) return _hifzSetZoom(false);
    _hifzSetZoom(true);
    final mouse = RendererBinding.instance.mouseTracker.mouseIsConnected;
    if (mouse) {
      _hifzZoomBy(1.6);
    } else {
      // Over the page rather than as a toast, which would cover the dock.
      _update(() => _zoomHint = true);
      _zoomHintTimer?.cancel();
      _zoomHintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _update(() => _zoomHint = false);
      });
    }
  }

  /// Zooms by [f] about the pages' middle (the keyboard's Ctrl + and −).
  void _hifzZoomBy(double f) {
    final box = _pagerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.size.center(Offset.zero);
    final m = Matrix4.identity()
      ..translateByDouble(at.dx, at.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-at.dx, -at.dy, 0, 1)
      ..multiply(_zoomCtrl.value);
    final s = m.getMaxScaleOnAxis();
    if (s <= 1.001) return _hifzSetZoom(false);
    if (s > MushafZoom.maxScale) return;
    // Kept to the window, as MushafZoom keeps it.
    final w = box.size.width, h = box.size.height;
    final tx = m.getTranslation().x.clamp(w * (1 - s), 0.0);
    final ty = m.getTranslation().y.clamp(h * (1 - s), 0.0);
    _zoomCtrl.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    _hifzSetZoom(true);
  }

  /// Zoom on or off; off, back to the whole page.
  void _hifzSetZoom(bool on) {
    if (!on) {
      _zoomCtrl.value = Matrix4.identity();
      _zoomHint = false;
    }
    if (on != _zoom) _update(() => _zoom = on);
  }

  Widget _hifzHintPill(MushafPaper paper, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: paper.chrome,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: paper.line.withValues(alpha: .6), width: .5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: paper.dark ? .45 : .12),
              blurRadius: 12,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 13, weight: FontWeight.w600, color: paper.ink)),
      );

  /// The glyph sheets the pages' size calls for, loading now rather than
  /// after the first paint (which would draw every line twice).
  void _preloadGlyphs(HifzLayout layout, AppSettings s) {
    final atlas = MushafAtlas.of(_script);
    if (atlas == null) return;
    final w = !layout.landscape
        ? layout.pager.width
        : switch (layout.pages) {
            'one' => layout.spreadWidth,
            'wide' => layout.pager.width,
            _ => (layout.pager.width - layout.gap - 2 * layout.rail) / 2,
          };
    final fs = w / MushafGeometry.refEmOf(_script);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final tier = atlas.tierFor(fs * dpr);
    if (atlas.tiers[tier].images == null) atlas.tiers[tier].load();
  }

  /// On its side, which way round the phone is held: the dock goes on the
  /// side away from the camera. Asked again whenever the window changes.
  void _checkRotation(Size size) {
    if (size == _rotationFor) return;
    _rotationFor = size;
    if (size.width <= size.height) return;
    displayRotation().then(_onRotation);
  }

  /// 270°: the camera on the right, the dock on the left.
  void _onRotation(int r) {
    final left = r == 3;
    if (mounted && left != _dockLeft) _update(() => _dockLeft = left);
  }

  /// A tool's bar in landscape: a panel beside the dock (down the side) or
  /// under the pages.
  Widget _hifzSlot(MushafPaper paper, Axis axis, Widget bar) {
    final vertical = axis == Axis.vertical;
    return RepaintBoundary(
      child: Align(
        alignment: vertical ? Alignment.center : Alignment.bottomCenter,
        child: Container(
          constraints: vertical ? null : const BoxConstraints(maxWidth: 760),
          padding: vertical
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: paper.chrome,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: paper.line.withValues(alpha: .6), width: .5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: paper.dark ? .45 : .12),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: vertical ? SingleChildScrollView(child: bar) : bar,
        ),
      ),
    );
  }

  // ── the line above the page (portrait) and the rails (landscape) ──

  Widget _hifzHeader(BuildContext context, MushafPaper paper, int page) {
    final juz = MushafRepo.juzOfPage(_script, page);
    final surah = MushafRepo.firstVerseOfPage(_script, page).$1;
    final style = uiStyle(context, size: 14, weight: FontWeight.w600, color: paper.acc);
    Widget item(String text, Division d, {TextAlign align = TextAlign.center}) =>
        Builder(
          builder: (anchor) => InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _hifzJumpList(d, anchor, AxisDirection.down),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(text,
                  textAlign: align,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: paper.acc.withValues(alpha: .4))),
            ),
          ),
        );
    // Fixed left to right, as a printed page's head: sūrah · page · juzʼ.
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: item(_tnames[surah] ?? '', Division.surah,
                        align: TextAlign.left))),
            item('$page', Division.page),
            Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: item(context.l10n.juzN(juz), Division.juz,
                        align: TextAlign.right))),
          ]),
        ),
      ),
    );
  }

  /// A spread page's rail (see [PageRail]).
  Widget _hifzRail(int page, MushafPaper paper, double width) => PageRail(
        script: _script,
        page: page,
        width: width,
        paper: paper,
        onTap: (d, anchor) => _hifzJumpList(d, anchor,
            page.isOdd ? AxisDirection.left : AxisDirection.right),
      );

  /// The sūrahs, pages or juzʼ in a list beside [anchor], opened on the
  /// current one; picking one goes there (once the list has closed).
  Future<void> _hifzJumpList(
      Division d, BuildContext anchor, AxisDirection side) async {
    final page = _pendingPage ?? _page;
    final count = d == Division.page ? _total : divisionCount(d);
    final current = switch (d) {
      Division.page => page,
      Division.juz => MushafRepo.juzOfPage(_script, page),
      _ => MushafRepo.firstVerseOfPage(_script, page).$1,
    };
    final l = context.l10n;
    final picked = await showAnchoredList(
      context,
      anchor: anchor,
      side: side,
      count: count,
      selected: current - 1,
      width: d == Division.surah ? 280 : 200,
      item: (c, i, sel) {
        final p = pal(c);
        final n = i + 1;
        final text = switch (d) {
          Division.page => l.pageN(n),
          Division.juz => l.juzN(n),
          _ => '$n. ${_tnames[n] ?? ''}',
        };
        return Container(
          color: sel ? p.accSoft : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: AlignmentDirectional.centerStart,
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiStyle(c,
                  size: 14.5,
                  weight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? p.acc : p.ink)),
        );
      },
    );
    if (picked == null || !mounted) return;
    _jump(divisionFirstPage(_script, d, picked + 1));
  }

  void _hifzIndex(Division d) => showMushafIndex(
        context,
        script: _script,
        currentPage: _pendingPage ?? _page,
        initial: d,
        onPage: (p) => _jump(p),
        onWord: _focusWord,
      );

  // ── the dock ──

  /// Settings · Index · Pen · Comment · Eraser · Audio · Memorize · View.
  List<DockItem> _hifzItems(
      BuildContext context, AppSettings s, MushafPaper paper, AxisDirection side) {
    final l = context.l10n;
    // Popovers open toward the page ([side]: above a bottom dock, beside a
    // side one).
    return [
      DockItem(
        icon: AppIcons.settings,
        tooltip: l.settings,
        onTap: (_) => openSection(context, AppSection.settings),
        // Holding it: the mode switcher.
        onOptions: (_) => showModeSheet(context),
      ),
      if (ProfileScope.maybeOf(context) != null)
        DockItem(
          icon: AppIcons.person,
          tooltip: l.prfTitle,
          onTap: (_) => showProfilesSheet(context),
        ),
      DockItem(
        icon: AppIcons.indexList,
        tooltip: l.idxIndex,
        onTap: (_) => _hifzIndex(Division.surah),
      ),
      DockItem(
        icon: AppIcons.pen,
        tooltip: l.mkMarkRecitation,
        selected: _marking.active,
        onTap: (_) => _hifzPen(),
        onOptions: (b) => _hifzPenOptions(b, side, paper),
      ),
      DockItem(
        icon: AppIcons.comment,
        tooltip: l.mkComment,
        selected: _hifzTool == _HifzTool.comment,
        onTap: (_) => _hifzSetTool(_HifzTool.comment),
      ),
      DockItem(
        icon: AppIcons.eraser,
        tooltip: l.hzEraser,
        selected: _hifzTool == _HifzTool.eraser,
        onTap: (_) => _hifzSetTool(_HifzTool.eraser),
        onOptions: (b) => _hifzEraserOptions(b, side),
      ),
      DockItem(
        icon: AppIcons.volume,
        tooltip: l.recitation,
        selected: _hifzTool == _HifzTool.audio,
        onTap: (_) => _hifzSetTool(_HifzTool.audio),
        onOptions: (b) => _hifzAudioOptions(b, side, s),
      ),
      DockItem(
        icon: AppIcons.memorize,
        tooltip: l.mzMemorize,
        selected: _memorizing,
        onTap: (_) => _hifzMemorize(),
        onOptions: (b) => _hifzMemorizeOptions(b, side),
      ),
      if (MarksScope.maybeOf(context) != null)
        DockItem(
          icon: AppIcons.review,
          tooltip: l.rvReview,
          selected: _reviewing,
          onTap: (b) => _hifzReviewOptions(b, side),
          onOptions: (b) => _hifzReviewOptions(b, side),
        ),
      DockItem(
        icon: AppIcons.zoom,
        tooltip: l.hzZoom,
        selected: _zoom,
        onTap: (b) => _hifzZoomButton(b),
      ),
      DockItem(
        icon: AppIcons.pageColour,
        tooltip: l.hzView,
        onTap: (b) => _hifzView(b, side, s),
      ),
    ];
  }

  /// The active tool's own bar laid along [axis], or null for none.
  Widget? _hifzToolBar(
      BuildContext context, AppSettings s, MushafPaper paper, Axis axis) {
    final l = context.l10n;
    final vertical = axis == Axis.vertical;
    if (_memorizing) {
      return vertical
          ? _memorizeBar(paper, vertical: true)
          : _memorizeBar(paper, compact: true);
    }
    if (_reviewing) return _reviewBar(paper, axis: axis);
    if (_marking.active) return _markingBar(paper, axis: axis);
    if (_hifzTool == _HifzTool.none) return null;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    final done = TextButton(
      onPressed: () => _hifzSetTool(_HifzTool.none),
      child: Text(l.nbDone,
          style: uiStyle(context, size: 14, weight: FontWeight.w700, color: accent)),
    );
    Widget hint(String t) => Text(t,
        maxLines: vertical ? 6 : 2,
        overflow: TextOverflow.ellipsis,
        textAlign: vertical ? TextAlign.center : TextAlign.start,
        style: uiStyle(context, size: 12.5, color: paper.sub));
    final List<Widget> parts;
    final String help;
    switch (_hifzTool) {
      case _HifzTool.audio:
        help = l.hzAudioHint;
        parts = [
          _reciteButton(context, paper, size: 42),
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
                style: uiStyle(context,
                    size: 13.5, weight: FontWeight.w700, color: paper.ink)),
          ),
        ];
      case _HifzTool.comment:
        help = l.hzCommentHint;
        parts = [Icon(AppIcons.comment, color: accent)];
      case _HifzTool.eraser:
        help = l.hzEraserHint;
        parts = [
          Icon(AppIcons.eraser, color: accent),
          TextButton(
            onPressed: _hifzErasePage,
            child: Text(l.hzErasePage,
                style: uiStyle(context,
                    size: 13.5, weight: FontWeight.w700, color: paper.ink)),
          ),
        ];
      case _HifzTool.none:
        return null;
    }
    if (vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in parts) ...[p, const SizedBox(height: 6)],
        hint(help),
        const SizedBox(height: 6),
        done,
      ]);
    }
    return Row(children: [
      for (final p in parts) ...[p, const SizedBox(width: 6)],
      Expanded(child: hint(help)),
      done,
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

  // ── tool options (popovers) ──

  Widget _popoverBody(BuildContext c, List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );

  Widget _popoverLabel(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text(t,
            style: uiStyle(c, size: 12.5, weight: FontWeight.w700, color: pal(c).ink3)),
      );

  /// The pen's options: what each colour means, and reviewing the marks.
  void _hifzPenOptions(BuildContext anchor, AxisDirection side, MushafPaper paper) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      return _popoverBody(c, [
        MarkLegend(pal: markPaletteForPaper(paper)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(c);
            _startReview();
          },
          icon: const Icon(AppIcons.repeat, size: 18),
          label: Text(c.l10n.rvSetupTitle),
        ),
      ]);
    });
  }

  /// Going over the marks: review them, a PDF report, the mark books.
  void _hifzReviewOptions(BuildContext anchor, AxisDirection side) {
    final store = MarksScope.maybeOf(context);
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      final l = c.l10n;
      final book = store?.activeBook;
      Widget row(IconData icon, String title, VoidCallback? onTap) => ListTile(
            leading: Icon(icon, color: onTap == null ? pal(c).ink3 : pal(c).acc),
            title: Text(title, style: uiStyle(c, size: 14.5, weight: FontWeight.w700)),
            enabled: onTap != null,
            onTap: onTap == null
                ? null
                : () {
                    Navigator.pop(c);
                    onTap();
                  },
          );
      return _popoverBody(c, [
        row(AppIcons.review, l.rvSetupTitle, book == null ? null : () {
          if (_marking.active) _marking.stop();
          if (_memorizing) _endMemorize();
          _startReview();
        }),
        row(AppIcons.pdf, l.rpExport, store == null || book == null
            ? null
            : () => showReportSheet(context,
                store: store, bookId: book.id, script: _script)),
        row(AppIcons.hifz, l.mkHifz, () => openSection(context, AppSection.hifz)),
      ]);
    });
  }

  /// The eraser's options: clear the page (or both pages).
  void _hifzEraserOptions(BuildContext anchor, AxisDirection side) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      return _popoverBody(c, [
        Text(c.l10n.hzEraserHint, style: uiStyle(c, size: 13, color: pal(c).ink2)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(c);
            _hifzErasePage();
          },
          icon: const Icon(AppIcons.eraser, size: 18),
          label: Text(c.l10n.hzErasePage),
        ),
      ]);
    });
  }

  /// The audio's options: reciter, speed, and what follows an āyah.
  void _hifzAudioOptions(BuildContext anchor, AxisDirection side, AppSettings s) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      return StatefulBuilder(builder: (c, setPop) {
        final l = c.l10n;
        void set(VoidCallback f) {
          s.update(f);
          setPop(() {});
        }

        return _popoverBody(c, [
          _popoverLabel(c, l.reciter),
          QSegmented<String>(
            options: [
              ('tunaiji', l.alTunaiji, null),
              ('alafasy', l.afasyName, null),
              ('husary', l.husaryName, null),
            ],
            value: s.reciter,
            onChanged: (v) => set(() => s.reciter = v),
          ),
          _popoverLabel(c, l.playbackSpeed),
          QSegmented<double>(
            options: const [(0.75, '0.75×', null), (1.0, '1×', null), (1.25, '1.25×', null)],
            value: s.playbackSpeed,
            onChanged: (v) {
              set(() => s.playbackSpeed = v);
              AyahAudio.instance.setRate(v);
              WbwAudio.instance.setRate(v);
            },
          ),
          _popoverLabel(c, l.afterVerse),
          QSegmented<String>(
            options: [
              ('single', l.flowStop, null),
              ('auto', l.flowContinue, null),
              ('repeat', l.flowRepeat, null),
            ],
            value: s.reciteFlow,
            onChanged: (v) => set(() => s.reciteFlow = v),
          ),
        ]);
      });
    });
  }

  /// Memorize's options: from a chosen place, or as verse cards.
  void _hifzMemorizeOptions(BuildContext anchor, AxisDirection side) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      final l = c.l10n;
      Widget row(IconData icon, String title, String sub, VoidCallback onTap) =>
          ListTile(
            leading: Icon(icon, color: pal(c).acc),
            title: Text(title, style: uiStyle(c, size: 14.5, weight: FontWeight.w700)),
            subtitle: Text(sub, style: uiStyle(c, size: 12.5, color: pal(c).ink3)),
            onTap: () {
              Navigator.pop(c);
              onTap();
            },
          );
      return _popoverBody(c, [
        row(AppIcons.indexList, l.mzStartFrom, l.mzStartFromSub, _memorizeFrom),
        row(AppIcons.memorize, l.mzStartCards, l.mzStartCardsSub, _memorizeAsCards),
      ]);
    });
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

  /// Script, colouring, light / dark / OLED, and the page's colour — in a
  /// popover beside the View button.
  void _hifzView(BuildContext anchor, AxisDirection side, AppSettings s) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
      return StatefulBuilder(builder: (pop, setPop) {
        final l = pop.l10n;
        void set(VoidCallback f) {
          s.update(f);
          setPop(() {});
        }

        final wide = MediaQuery.sizeOf(context);
        return _popoverBody(pop, [
          // On its side: two facing pages, or one (as wide as they are, or
          // the whole width).
          if (wide.width > wide.height) ...[
            _popoverLabel(pop, l.hzLandscapePages),
            QSegmented<String>(
              options: [
                ('two', l.hzPagesTwo, null),
                ('one', l.hzPagesOne, null),
                ('wide', l.hzPagesWide, null),
              ],
              value: s.hifzLandscapePages,
              onChanged: (v) => set(() => s.hifzLandscapePages = v),
            ),
          ],
          _popoverLabel(pop, l.arabicScript),
          QSegmented<String>(
            options: [
              ('uthmani', l.madani, null),
              ('indopak', l.indoPak, null),
            ],
            value: _script,
            onChanged: (v) {
              Navigator.pop(pop);
              _switchScript(v);
            },
          ),
          _popoverLabel(pop, l.hzColouring),
          QSegmented<String>(
            options: [
              ('off', l.hzOff, null),
              ('tajwid', l.tajwid, null),
              ('nabr', l.hzNabr, null),
            ],
            value: s.mushafTajwid ? 'tajwid' : 'off',
            onChanged: (v) {
              if (v == 'nabr') {
                showQToast(pop, l.nbFuture);
                return;
              }
              set(() => s.mushafTajwid = v == 'tajwid');
            },
          ),
          _popoverLabel(pop, l.theme),
          QSegmented<String>(
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
          // The page and its ornaments, each chosen on its own.
          if (s.theme == AppTheme.light) ...[
            _popoverLabel(pop, l.pageColour),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final id in const ['cream', 'white', 'madani'])
                _Swatch(
                  colour: kMushafPapers[id]!.paper,
                  selected: mushafPaperOf(s, _script).id == id,
                  onTap: () => set(() => s.mushafPaper = id),
                ),
            ]),
          ],
          if (!mushafPaperOf(s, _script).mono) ...[
            _popoverLabel(pop, l.ornamentColour),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final id in kOrnamentSeeds.keys)
                _Swatch(
                  colour: ornamentColours(id, dark: mushafPaperOf(s, _script).dark).art,
                  selected: s.styleFor(_script).ornament == id,
                  onTap: () => set(() => s.styleFor(_script).ornament = id),
                ),
            ]),
          ],
        ]);
      });
    });
  }
}

/// A colour to pick: the page's, or its ornaments'.
class _Swatch extends StatelessWidget {
  final Color colour;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.colour, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour,
            border: Border.all(
                color: selected ? pal(context).acc : pal(context).line2,
                width: selected ? 3 : 1),
          ),
        ),
      );
}
