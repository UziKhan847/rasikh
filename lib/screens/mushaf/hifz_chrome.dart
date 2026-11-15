part of '../mushaf_screen.dart';

/// Hifẓ mode's tools that aren't modes of their own: a tap on a word then
/// opens its comments, wipes its marks, or plays it. (The pen is marking
/// mode, memorize is memorize mode.)
enum _HifzTool { none, comment, eraser, breath, audio, follow }

/// The height the view switch needs of the band above the page.
const _kSwitchBand = 34.0;

/// The button out of zoom, and half what the page number takes beside it.
const _kZoomExit = 32.0;
const _kPageNumberHalf = 22.0;

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
            align: s.pagesAlign,
            pageBox: (a) => MushafGeometry.pageBox(a, _script,
                look: _look(s), header: s.mushafHeaderShown, compact: true));
        // Immersive, on end: the band the status bar leaves empty takes the
        // view switch.
        final switchInBand =
            !layout.landscape && s.immersive && pad.top >= _kSwitchBand;
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
              head: _wideHead,
              margin: EdgeInsets.fromLTRB(inset.left + side, 6,
                  inset.right + side,
                  layout.slotAxis == Axis.horizontal
                      ? layout.slot.height + 12
                      : 6));
        } else {
          pages = _pager(s, paper,
              fitWidth: false,
              margin: EdgeInsets.symmetric(
                  horizontal: c.maxWidth * (_script == 'indopak' ? .01 : .025),
                  vertical: 2),
              // The line keeps its place; the view switch sits in it, between
              // the page number and the juzʼ (unless a tool's bar hides it).
              head: (page, _) => RepaintBoundary(
                  child: _hifzHeader(context, paper, page,
                      chips: !switchInBand,
                      // The switch is there whatever's on: it takes the mode
                      // along (see _hifzVerses).
                      between: switchInBand ? null : _viewSwitch(paper, dense: true))));
        }
        MushafZoom.zoomHeld = () => s.keymap.zoomHeld;
        final pager = WheelPager(
          onTurn: _turn,
          trackpadTurns: !_zoom && !(layout.landscape && layout.pages == 'wide'),
          turnOfButton: (buttons) => switch (s.keymap.mouseActionFor(buttons)) {
            MouseAction.nextPage => 1,
            MouseAction.prevPage => -1,
            _ => null,
          },
          child: ClipRect(
            child: MushafZoom(
              active: _zoom,
              onActive: _hifzSetZoom,
              controller: _zoomCtrl,
              child: KeyedSubtree(key: _pagerKey, child: pages),
            ),
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
            final desktop = useDesktop(context);
            final (row, rest) = dockLayout(
              _hifzItems(context, s, paper, dockSide),
              _hifzFanItems(context, s, paper, dockSide, landscape: layout.landscape),
              desktop: desktop,
              length: layout.landscape
                  ? layout.dock.height - pad.vertical
                  : layout.dock.width - pad.horizontal,
              gear: (menu) => gearItem(context, menu),
            );
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
              // Zoomed: one tap out, in the line above the page, between the
              // sūrah and the page number. Over the pager, not in that line,
              // which zooms and pans with the page.
              if (_zoom)
                () {
                  final inset = layout.landscape ? layout.pagesInset : EdgeInsets.zero;
                  final middle = layout.pager.left + inset.left +
                      (layout.pager.width - inset.horizontal) / 2;
                  return Positioned(
                    top: layout.pager.top + (_MushafPageScreenState._headH - _kZoomExit) / 2,
                    left: spread
                        ? middle - _kZoomExit / 2
                        : middle - _kPageNumberHalf - _kZoomExit,
                    child: ToolCircle(
                      paper: paper,
                      size: _kZoomExit,
                      item: DockItem(
                        icon: AppIcons.close,
                        tooltip: context.l10n.hzZoomExit,
                        onTap: (_) => _hifzSetZoom(false),
                      ),
                    ),
                  );
                }(),
              if (_exportPick != null)
                Positioned(
                  top: layout.pager.top + 8,
                  left: layout.pager.left + 16,
                  right: c.maxWidth - layout.pager.right + 16,
                  child: IgnorePointer(child: Center(child: _exportPickPill(paper))),
                ),

              Positioned.fromRect(
                rect: layout.dock,
                child: ToolCircles(
                  axis: dockAxis,
                  onLeft: layout.dockLeft,
                  paper: paper,
                  items: row,
                  circleSize: desktop ? ToolCircles.desktopSize : ToolCircles.size,
                  showMore: rest.isNotEmpty,
                  fanOpen: _fanOpen && bar == null && rest.isNotEmpty,
                  onFan: (open) => _update(() => _fanOpen = open),
                  moreKey: _moreKey,
                  moreLabel: context.l10n.tcMore,
                  onUse: s.toolHintSeen ? null : () => s.update(() => s.toolHintSeen = true),
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
                      : _hifzSlot(paper, Axis.horizontal, bar),
                ),
              ),
              // Across to the Verses view, where it isn't in the line above
              // the page: in the band up top, or at the top of the side by the
              // dock. A tool's bar takes the moment.
              // Immersive: its toggles go up into the band with the view switch;
              // the line stays as it is. The page's bookmark just left of where
              // its number is, below.
              if (switchInBand) ...[
                if (_profileChip(paper) case final chip?)
                  Positioned(
                    top: 0,
                    height: pad.top,
                    left: pad.left + 12,
                    child: Center(child: chip),
                  ),
                Positioned(
                  top: 0,
                  height: pad.top,
                  right: c.maxWidth / 2 + _kPageNumberHalf,
                  child: Center(child: _bookmarkChip(paper, _pendingPage ?? _page)),
                ),
              ],
              if (layout.landscape || switchInBand)
                Positioned(
                  top: switchInBand ? 0 : layout.pager.top + 2,
                  height: layout.landscape ? null : pad.top,
                  left: layout.landscape && layout.dockLeft ? layout.dock.right + 4 : null,
                  right: !layout.landscape
                      ? pad.right + 8
                      : layout.dockLeft
                          ? null
                          : c.maxWidth - layout.dock.left + 4,
                  child: Center(
                    child: layout.landscape
                        // Beside the dock: the switch, and who's reading under it.
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            _viewSwitch(paper, dense: true, axis: Axis.vertical),
                            if (_profileChip(paper) case final chip?) ...[
                              const SizedBox(height: 8),
                              Padding(
                                // (The chip's own nudge left, undone here.)
                                padding: const EdgeInsets.only(right: 2),
                                child: chip,
                              ),
                            ],
                            // The bookmarks, a tap away.
                            const SizedBox(height: 8),
                            _headerChip(
                              paper,
                              AppIcons.bookmark,
                              context.l10n.bookmarksTab,
                              (_) => _hifzIndex(Division.surah, bookmarks: true),
                              key: const ValueKey('bookmarks-chip'),
                            ),
                          ])
                        : _viewSwitch(paper, dense: true),
                  ),
                ),
              // Memorizing, revealing what's recited: its status (and the
              // warning) in a pill at the top of the pages, clear of the bar.
              if (_memoFollow)
                Positioned(
                  top: layout.pager.top + 6,
                  left: layout.pager.left + 8,
                  width: layout.pager.width - 16,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: paper.chrome,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: paper.line),
                      ),
                      child: FollowStrip(
                          ink: paper.ink,
                          sub: paper.sub,
                          accent: paper.id == 'mono' ? paper.ink : paper.acc),
                    ),
                  ),
                ),
              // The first time: what the circles do.
              if (!s.toolHintSeen && bar == null && !_fanOpen)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: layout.landscape ? 16 + pad.bottom : layout.dock.height + 6,
                  child: IgnorePointer(
                    child: Center(child: _hifzHintPill(paper, context.l10n.tcHint)),
                  ),
                ),
              // The ⋯ fan, over the page; a tap outside (or a swipe down)
              // folds it.
              if (_fanOpen && bar == null && rest.isNotEmpty) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _update(() => _fanOpen = false),
                    onVerticalDragEnd: (_) => _update(() => _fanOpen = false),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (layout.landscape)
                  Positioned(
                    top: pad.top + 8,
                    bottom: pad.bottom + 8,
                    left: layout.dockLeft ? layout.dock.right + 6 : null,
                    right: layout.dockLeft ? null : c.maxWidth - layout.dock.left + 6,
                    child: Center(
                      child: ToolFan(
                        paper: paper,
                        maxWidth: 252,
                        items: rest,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 12 + pad.left,
                    right: 12 + pad.right,
                    bottom: layout.dock.height + 2,
                    child: Center(
                      child: ToolFan(
                        paper: paper,
                        items: rest,
                      ),
                    ),
                  ),
              ],
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
  bool get _hasMouse =>
      isDesktopPlatform() || RendererBinding.instance.mouseTracker.mouseIsConnected;

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

  /// The Verses view of the page in view; back on the page it ends at.
  /// The switch to the verses, whatever's on carrying on there: memorizing and
  /// reviewing as cards; marking (the same session) and the recitation in the
  /// Reader.
  Future<void> _hifzVerses() async {
    if (_reviewing && _review != null) return _reviewAsCards();
    if (_memorizing) return _memorizeAsCards();
    final mode = ViewMode(
      markKind: _marking.active ? 'recitation' : _fluencyTool?.name,
      sessionId: _marking.active ? _marking.sessionId : null,
      audio: _hifzTool == _HifzTool.audio,
      follow: _following && _fs.active,
    );
    // Following goes on in the verses: it's theirs now.
    if (mode.follow) _fs.owner = #verses;
    if (_marking.active) _marking.stop();
    _stopAudio();
    _update(() {
      _fluencyTool = null;
      _hifzTool = _HifzTool.none;
    });
    final exit = await openVerses(context, _script, _pendingPage ?? _page, mode: mode);
    if (exit == null || !mounted) return;
    _jump(exit.page);
    _carryOn(exit.mode);
  }

  /// The pages button's options: two pages, one as wide as they are, or
  /// one across the whole width.
  void _hifzPagesOptions(BuildContext anchor, AxisDirection side, AppSettings s) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
      final l = pop.l10n;
      return _popoverBody(pop, [
        _popoverLabel(pop, l.hzLandscapePages),
        QSegmented<String>(
          options: [
            ('two', l.hzPagesTwo, null),
            ('one', l.hzPagesOne, null),
            ('wide', l.hzPagesWide, null),
          ],
          value: s.hifzLandscapePages,
          onChanged: (v) {
            Navigator.pop(pop);
            if (v != 'two') _lastSingle = v;
            s.update(() => s.hifzLandscapePages = v);
          },
        ),
        _popoverLabel(pop, l.hzAlign),
        StatefulBuilder(
          builder: (pop, setPop) => QSegmented<String>(
            options: [
              ('left', l.hzAlignLeft, null),
              ('center', l.hzAlignCenter, null),
              ('right', l.hzAlignRight, null),
            ],
            value: s.pagesAlign == 'auto' ? (_dockLeft ? 'right' : 'left') : s.pagesAlign,
            onChanged: (v) {
              s.update(() => s.pagesAlign = v);
              setPop(() {});
            },
          ),
        ),
      ]);
    });
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
    if (isOriginalScript(_script)) return;
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
    final byCamera = SettingsScope.of(context).dockByCamera;
    if (size == _rotationFor && byCamera == _dockByCamera) return;
    _rotationFor = size;
    _dockByCamera = byCamera;
    if (size.width <= size.height) return;
    displayRotation().then(_onRotation);
  }

  /// 270°: the camera on the right, the dock on the left (or, by the
  /// camera if so set, the other way round).
  void _onRotation(int r) {
    if (!mounted) return;
    final left = (r == 3) != SettingsScope.of(context).dockByCamera;
    if (mounted && left != _dockLeft) _update(() => _dockLeftOn.value = left);
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

  /// One page across the landscape width: its line above it, as in
  /// portrait, sized to the page (a page as wide as a portrait one has
  /// portrait's 14 px; wider, up to 24).
  Widget _hifzWideHead(int page, double width) {
    final paper = mushafPaperOf(SettingsScope.of(context), _script);
    final size = (width / 26).clamp(14.0, 24.0);
    return SizedBox(
      height: _MushafPageScreenState._headH * size / 14,
      child: RepaintBoundary(
          child: _hifzHeader(context, paper, page, size: size)),
    );
  }

  Widget _hifzHeader(BuildContext context, MushafPaper paper, int page,
      {double size = 14, Widget? between, bool chips = true}) {
    final juz = MushafRepo.juzOfPage(_script, page);
    final surah = MushafRepo.firstVerseOfPage(_script, page).$1;
    // In the ornaments' colour, as the sūrah headers and the margin's labels.
    final ink = paper.frameInk ?? Color.lerp(paper.frame, paper.ink, .25)!;
    final style = uiStyle(context, size: size, weight: FontWeight.w600, color: ink);
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
                      decorationColor: ink.withValues(alpha: .4))),
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
            // Sūrah · its profile toggle ... the page's bookmark · page. The
            // page number stays in the middle, whatever's beside it.
            Expanded(
                child: Row(children: [
              // The name as long as it needs; shortened only if it must be.
              Expanded(
                child: Row(children: [
                  Flexible(
                      child: item(_tnames[surah] ?? '', Division.surah, align: TextAlign.left)),
                  if (chips) ?_profileChip(paper),
                ]),
              ),
              // (The button out of zoom stands here, over the line.)
              if (_zoom)
                const SizedBox(width: _kZoomExit + 4)
              else if (chips)
                _bookmarkChip(paper, page),
            ])),
            item('$page', Division.page),
            Expanded(
                child: Row(children: [
              Expanded(
                  child: between == null
                      ? const SizedBox.shrink()
                      : Center(child: FittedBox(fit: BoxFit.scaleDown, child: between))),
              Flexible(
                  flex: 0,
                  child: item(context.l10n.juzN(juz), Division.juz,
                      align: TextAlign.right)),
            ])),
          ]),
        ),
      ),
    );
  }

  /// A small toggle in the line above the page, like the view switch beside it.
  Widget _headerChip(MushafPaper paper, IconData icon, String tip,
      void Function(BuildContext anchor) onTap, {bool on = false, Key? key}) {
    final ornament = paper.frameInk ?? Color.lerp(paper.frame, paper.ink, .25)!;
    return HeaderChip(
      key: key,
      icon: icon,
      tooltip: tip,
      onTap: onTap,
      on: on,
      track: paper.frame.withValues(alpha: .12),
      onTrack: paper.frame.withValues(alpha: .4),
      ink: ornament,
    );
  }

  Widget _bookmarkChip(MushafPaper paper, int page) {
    final prog = ProgressScope.read(context);
    return ValueListenableBuilder<int>(
      valueListenable: prog.readingSignal,
      builder: (context, _, _) {
        final on = prog.isPageBookmarked(_script, page);
        final l = context.l10n;
        return _headerChip(
          paper,
          on ? AppIcons.bookmarkFilled : AppIcons.bookmark,
          on ? l.removeBookmark : _tip(l.bmPage, KeyAction.bookmarkPage),
          (_) => prog.togglePageBookmark(_script, page),
          on: on,
          key: ValueKey('page-bookmark-$page'),
        );
      },
    );
  }

  /// Who's reading, a click from anyone else (none without profiles).
  Widget? _profileChip(MushafPaper paper) {
    if (ProfileScope.maybeOf(context) == null) return null;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: _headerChip(paper, AppIcons.person, context.l10n.prfSwitch,
          (anchor) => showProfileMenu(context, anchor),
          key: const ValueKey('profile-chip')),
    );
  }

  /// A spread page's rail (see [PageRail]).
  Widget _hifzRail(int page, MushafPaper paper, double width) => PageRail(
        above: _bookmarkChip(paper, page),
        // (The profile toggle is by the view switch, beside the dock.)
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

  void _hifzIndex(Division d, {bool focusField = false, bool bookmarks = false}) =>
      showMushafIndex(
        context,
        focusField: focusField,
        bookmarks: bookmarks,
        fromLeft: _dockLeftOn,
        script: _script,
        currentPage: _pendingPage ?? _page,
        initial: d,
        onPage: (p) => _jump(p),
        onWord: _focusWord,
      );

  // ── the circles ──

  /// Review · Memorize · Mark · Audio: tap to start (or end), hold for
  /// what kind.
  List<DockItem> _hifzItems(
      BuildContext context, AppSettings s, MushafPaper paper, AxisDirection side) {
    final l = context.l10n;
    return [
      DockItem(
        icon: AppIcons.indexList,
        tooltip: _tip(l.idxIndex, KeyAction.openIndex),
        onTap: (_) => _hifzIndex(Division.surah),
      ),
      if (MarksScope.maybeOf(context) != null)
        DockItem(
          icon: AppIcons.review,
          tooltip: l.rvReview,
          selected: _reviewing,
          onTap: (_) => _hifzReview(),
          onOptions: (b) => _hifzReviewOptions(b, side),
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
          icon: AppIcons.pen,
          tooltip: _tip(l.tcMark, KeyAction.markMode),
          selected: _marking.active || _fluencyTool != null,
          onTap: (_) => _hifzMark(),
          onOptions: (b) => _hifzMarkOptions(b, side),
        ),
      DockItem(
        icon: AppIcons.volume,
        tooltip: l.recitation,
        selected: _hifzTool == _HifzTool.audio,
        onTap: (_) => _hifzSetTool(_HifzTool.audio),
        onOptions: (b) => _hifzAudioOptions(b, side, s),
      ),
      DockItem(
        icon: AppIcons.mic,
        tooltip: _tip(l.followTitle, KeyAction.follow),
        selected: _following,
        onTap: (_) => _hifzFollow(),
        onOptions: (b) => showFollowOptions(context, b, side),
      ),
    ];
  }

  /// The ⋯ fan: View · Script · Theme · (Pages) · Zoom · Practice ·
  /// Export · History · Profile · Settings. Its popovers open from ⋯.
  List<DockItem> _hifzFanItems(BuildContext context, AppSettings s,
      MushafPaper paper, AxisDirection side, {bool landscape = false}) {
    final l = context.l10n;
    // Folds the fan, then acts from the ⋯ button (still there).
    void Function(BuildContext) fold(void Function(BuildContext more) f) => (button) {
          // From the fan, which folds: its ⋯. From the row: the button itself.
          final at = _fanOpen ? _moreKey.currentContext : button;
          _update(() => _fanOpen = false);
          if (at != null) f(at);
        };
    final store = MarksScope.maybeOf(context);
    final view = DockItem(
      icon: AppIcons.reader,
      tooltip: l.hzView,
      onTap: fold((b) => _hifzView(b, side, s)),
    );
    // Which muṣḥaf: generated or the original print.
    final script = DockItem(
      icon: AppIcons.textSize,
      label: mushafEditionName(l, _script),
      tooltip: '${l.arabicScript}: ${mushafEditionName(l, _script)}',
      onTap: fold((b) => _hifzEdition(b, side)),
    );
    final theme = DockItem(
      icon: AppIcons.pageColour,
      tooltip: l.theme,
      onTap: fold((b) => _hifzTheme(b, side, s)),
    );
    // Dark or light, a tap away; the fan stays, to tap it back or go on.
    final dark = DockItem(
      icon: s.isDarkTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: _tip(s.isDarkTheme ? l.themeLight : l.themeDark, KeyAction.darkMode),
      onTap: (_) => s.update(s.toggleDark),
    );
    // On its side only: two facing pages or one, a tap apart (holding it,
    // which one: as wide as the two, or the whole width).
    final pages = !landscape
        ? null
        : DockItem(
            icon: s.hifzLandscapePages == 'two' ? AppIcons.viewSpread : AppIcons.viewSingle,
            tooltip: _tip(
                switch (s.hifzLandscapePages) {
                  'one' => l.hzPagesOne,
                  'wide' => l.hzPagesWide,
                  _ => l.hzPagesTwo,
                },
                KeyAction.togglePages),
            onTap: fold((_) => _toggleTwoPages(s)),
            onOptions: fold((b) => _hifzPagesOptions(b, side, s)),
          );
    // A finger's zoom needs turning on (it would swipe the page); a mouse's
    // doesn't (Ctrl and the wheel, from anywhere).
    final zoom = _hasMouse
        ? null
        : DockItem(
            icon: AppIcons.zoom,
            tooltip: l.hzZoom,
            selected: _zoom,
            onTap: fold(_hifzZoomButton),
          );
    final export = store == null
        ? null
        : DockItem(
            icon: AppIcons.pdf,
            tooltip: _tip(l.tcExport, KeyAction.export),
            onTap: fold((_) => _hifzExport()),
          );
    final history = DockItem(
      inMenu: true,
      icon: AppIcons.chart,
      tooltip: l.hsTitle,
      onTap: fold((_) => openSection(context, AppSection.hifz, fromLeft: _dockLeftOn)),
    );
    final profile = ProfileScope.maybeOf(context) == null
        ? null
        : DockItem(
            inMenu: true,
            icon: AppIcons.person,
            tooltip: l.prfTitle,
            onTap: fold((_) => showProfilesSheet(context)),
          );
    final settings = DockItem(
      inMenu: true,
      icon: AppIcons.settings,
      tooltip: _tip(l.settings, KeyAction.settings),
      onTap: fold((_) => openSection(context, AppSection.settings, fromLeft: _dockLeftOn)),
      // Holding it: the profiles.
      onOptions: fold((_) => showProfilesSheet(context)),
    );
    // Desktop mode's row: what's reached for most comes first, in case it
    // doesn't all fit.
    return useDesktop(context)
        ? [
            ?pages, theme, dark, view, script, ?zoom, ?export, history, ?profile, settings,
          ]
        : [
            view, script, theme, dark, ?pages, ?zoom, ?export, history, ?profile, settings,
          ];
  }

  /// [text], with its key in desktop mode.
  String _tip(String text, KeyAction a) => useDesktop(context)
      ? '$text (${SettingsScope.of(context).keymap.label(a)})'
      : text;

  void _toggleTwoPages(AppSettings s) {
    final now = s.hifzLandscapePages;
    if (now != 'two') _lastSingle = now;
    s.update(() => s.hifzLandscapePages = now == 'two' ? _lastSingle : 'two');
  }

  /// The active mode's own bar laid along [axis], or null for none.
  Widget? _hifzToolBar(
      BuildContext context, AppSettings s, MushafPaper paper, Axis axis) {
    final l = context.l10n;
    final vertical = axis == Axis.vertical;
    if (_exportPick != null) return _exportPickBar(paper, axis);
    if (_memorizing) {
      return vertical
          ? _memorizeBar(paper, vertical: true)
          : _memorizeBar(paper, compact: true);
    }
    if (_reviewing) return _reviewBar(paper, axis: axis);
    if (_marking.active) {
      return _markingBar(paper, axis: axis, tools: _markTools(paper));
    }
    if (_fluencyTool != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _fluencyBar(paper, hint: vertical),
      );
    }
    if (_following) return _followBar(paper, axis);
    if (_hifzTool != _HifzTool.audio) return null;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    final done = TextButton(
      onPressed: () => _hifzSetTool(_HifzTool.none),
      child: Text(l.nbDone,
          style: uiStyle(context, size: 14, weight: FontWeight.w700, color: accent)),
    );
    final hint = Text(l.hzAudioHint,
        maxLines: vertical ? 6 : 2,
        overflow: TextOverflow.ellipsis,
        textAlign: vertical ? TextAlign.center : TextAlign.start,
        style: uiStyle(context, size: 12.5, color: paper.sub));
    final parts = [
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
    if (vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in parts) ...[p, const SizedBox(height: 6)],
        hint,
        const SizedBox(height: 6),
        done,
      ]);
    }
    return Row(children: [
      for (final p in parts) ...[p, const SizedBox(width: 6)],
      Expanded(child: hint),
      done,
    ]);
  }

  /// Mark mode's own tools, beside the pens: Comment (a tap on a word opens
  /// its comments) and Eraser (a tap wipes a word's marks; holding it, the
  /// page's). Each a tap on, a tap off — back to the pens.
  List<Widget> _markTools(MushafPaper paper) {
    final l = context.l10n;
    final accent = paper.id == 'mono' ? paper.ink : paper.acc;
    Widget tool(IconData icon, String tip, _HifzTool t, {VoidCallback? onHold}) {
      final on = _hifzTool == t;
      return Tooltip(
        message: tip,
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? accent.withValues(alpha: .16) : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _update(() => _hifzTool = on ? _HifzTool.none : t),
              onLongPress: onHold,
              child: SizedBox.square(
                dimension: 40,
                child: Icon(icon, size: 21, color: on ? accent : paper.ink),
              ),
            ),
          ),
        ),
      );
    }

    return [
      tool(AppIcons.comment, l.mkComment, _HifzTool.comment),
      tool(AppIcons.eraser, l.hzEraser, _HifzTool.eraser, onHold: _hifzErasePage),
      tool(Icons.air, l.mkBreath, _HifzTool.breath),
      // Which the breath tool's next tap puts down; a tap on it switches.
      if (_hifzTool == _HifzTool.breath)
        ListenableBuilder(
          listenable: _marking,
          builder: (context, _) {
            final stop = _marking.breathNext == MarkType.breathStop;
            return IconButton(
              tooltip: stop ? l.mkBreathNextStop : l.mkBreathNextStart,
              onPressed: _marking.toggleBreathNext,
              icon: Transform.flip(
                flipX: !stop,
                child: Icon(stop ? Icons.pause : Icons.play_arrow, color: accent),
              ),
            );
          },
        ),
    ];
  }

  void _hifzSetTool(_HifzTool t) {
    if (_marking.active) _marking.stop();
    if (_memorizing) _endMemorize();
    _update(() {
      _fluencyTool = null;
      _hifzTool = _hifzTool == t ? _HifzTool.none : t;
    });
  }

  void _hifzMemorize() {
    _update(() {
      _hifzTool = _HifzTool.none;
      _fluencyTool = null;
    });
    if (_marking.active) _toggleMarking();
    if (_memorizing) {
      _endMemorize();
    } else {
      _startMemorize();
    }
  }

  /// Mark, tapped: on with the kind used last (recitation the first
  /// time), or off.
  void _hifzMark() {
    if (_marking.active) {
      _toggleMarking();
    } else if (_fluencyTool != null) {
      _update(() => _fluencyTool = null);
    } else {
      _hifzStartMark(SettingsScope.of(context).markKind);
    }
  }

  /// Marking with [kind]: 'recitation', or a fluency tool's name — and
  /// remembered for the next tap.
  Future<void> _hifzStartMark(String kind) async {
    final s = SettingsScope.of(context);
    final tool = FluencyTool.values.asNameMap()[kind];
    if (s.markKind != kind) s.update(() => s.markKind = kind);
    if (_memorizing) _endMemorize();
    if (_reviewing) await _endReview();
    if (!mounted) return;
    if (tool == null) {
      _update(() {
        _fluencyTool = null;
        _hifzTool = _HifzTool.none;
      });
      if (!_marking.active) await _toggleMarking();
      return;
    }
    // From recitation marks to fluency: that session ends (and is kept).
    if (_marking.active) await _toggleMarking();
    if (!mounted) return;
    _stopAudio();
    _update(() {
      _hifzTool = _HifzTool.none;
      _fluencyTool = tool;
    });
  }

  /// Review, tapped: on at once, as it went last (the muṣḥaf, cards, or
  /// fluency verse by verse) — or off.
  void _hifzReview() {
    if (_reviewing) {
      _endReview();
    } else {
      _hifzStartReview(SettingsScope.of(context).reviewAs);
    }
  }

  Future<void> _hifzStartReview(String as, {bool ask = false}) async {
    final s = SettingsScope.of(context);
    if (!ask && s.reviewAs != as) s.update(() => s.reviewAs = as);
    if (_marking.active) await _toggleMarking();
    if (_memorizing) _endMemorize();
    if (!mounted) return;
    _update(() {
      _hifzTool = _HifzTool.none;
      _fluencyTool = null;
    });
    await _startReview(ask: ask, as: as == 'cards' ? ReviewView.cards : ReviewView.mushaf);
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

  /// A popover's choice: an icon, a title (and a line under it), ticked
  /// if it's the one a tap starts.
  Widget _popoverRow(BuildContext c, IconData icon, String title, VoidCallback onTap,
          {String? sub, bool on = false}) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: pal(c).acc),
        title: Text(title, style: uiStyle(c, size: 14.5, weight: FontWeight.w700)),
        subtitle:
            sub == null ? null : Text(sub, style: uiStyle(c, size: 12.5, color: pal(c).ink3)),
        trailing: on ? Icon(AppIcons.check, size: 18, color: pal(c).acc) : null,
        onTap: () {
          Navigator.pop(c);
          onTap();
        },
      );

  /// Mark, held: recitation marks (the four pens, a tap cycling them) or
  /// fluency marks (not fluent, a pair, a chunk).
  void _hifzMarkOptions(BuildContext anchor, AxisDirection side) {
    final kind = SettingsScope.of(context).markKind;
    final s = SettingsScope.of(context);
    final desktop = useDesktop(context);
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      final l = c.l10n;
      return _popoverBody(c, [
        // Desktop mode: a tap steps through the kinds, or uses a chosen pen.
        if (desktop) ...[
          _popoverLabel(c, l.mkMethod),
          StatefulBuilder(
            builder: (c, setPop) => QSegmented<String>(
              options: [
                ('tap', l.mkMethodTap, null),
                ('pen', l.mkMethodPen, null),
              ],
              value: s.markMethod,
              onChanged: (v) {
                s.update(() => s.markMethod = v);
                setPop(() {});
              },
            ),
          ),
        ],
        _popoverRow(c, AppIcons.pen, l.mkRecitationMarks, () => _hifzStartMark('recitation'),
            sub: l.mkRecitationSub, on: kind == 'recitation'),
        _popoverRow(c, AppIcons.bolt, l.mkFluencyMarks, () => _hifzStartMark('fluency'),
            sub: l.mkFluencySub, on: kind == 'fluency'),
      ]);
    });
  }

  /// Review, held: the recitation marks on the muṣḥaf or as cards, the
  /// fluency marks verse by verse, or what and where, chosen.
  void _hifzReviewOptions(BuildContext anchor, AxisDirection side) {
    final s = SettingsScope.of(context);
    final as = s.reviewAs;
    final scope = s.reviewScope;
    void go(String sc) {
      s.update(() => s.reviewScope = sc);
      _hifzStartReview(as);
    }

    showToolPopover<void>(context, anchor: anchor, side: side, builder: (c) {
      final l = c.l10n;
      return _popoverBody(c, [
        // What, then where it's shown.
        _popoverLabel(c, l.rvWhat),
        _popoverRow(c, AppIcons.pen, l.rvScopeMarks, () => go('marks'), on: scope == 'marks'),
        _popoverRow(c, AppIcons.bolt, l.rvScopeFluency, () => go('fluency'),
            on: scope == 'fluency'),
        _popoverRow(c, AppIcons.review, l.rvScopeAll, () => go('all'), on: scope == 'all'),
        _popoverLabel(c, l.rvView),
        _popoverRow(c, AppIcons.mushaf, l.rvViewMushaf, () => _hifzStartReview('mushaf'),
            on: as == 'mushaf'),
        _popoverRow(c, AppIcons.cards, l.rvViewCards, () => _hifzStartReview('cards'),
            on: as == 'cards'),
        _popoverRow(c, AppIcons.tune, l.rvChoose, () => _hifzStartReview(as, ask: true)),
      ]);
    });
  }

  /// Export: a report of the marks, the pages themselves marked, or both.
  void _hifzExport() {
    final store = MarksScope.maybeOf(context);
    final book = store?.ensureActiveBook(context.l10n.mkMe);
    if (store == null || book == null) return;
    showExportSheet(context,
        store: store,
        bookId: book.id,
        script: _script,
        currentPage: _pendingPage ?? _page,
        pickRange: _pickExportRange,
        fromLeft: _dockLeftOn);
  }

  /// The export's range, tapped on the muṣḥaf: the first page, sūrah or verse,
  /// then (a swipe away) the last; another tap starts again. Null: cancelled.
  Future<ExportPicked?> _pickExportRange(ExportPickUnit unit) {
    final pick = _ExportPick(unit);
    _update(() => _exportPick = pick);
    return pick.done.future;
  }

  /// A tap while picking: on [page], and on [ayah] if on a verse (a tap on
  /// the bare page chooses only a page).
  void _pickExportAt({required int page, int? ayah}) {
    final pick = _exportPick;
    if (pick == null) return;
    final at = switch (pick.unit) {
      ExportPickUnit.page => page,
      ExportPickUnit.surah => ayah == null ? null : MushafRepo.surahAyahOf(ayah).$1,
      ExportPickUnit.verse => ayah,
    };
    if (at == null) return;
    _update(() {
      if (pick.first == null || pick.last != null) {
        pick
          ..first = at
          ..last = null;
      } else {
        pick.last = at;
      }
    });
  }

  void _setExportUnit(ExportPickUnit unit) {
    final pick = _exportPick;
    if (pick == null || pick.unit == unit) return;
    _update(() {
      pick
        ..unit = unit
        ..first = null
        ..last = null;
    });
  }

  void _endExportPick({required bool cancel}) {
    final pick = _exportPick;
    if (pick == null) return;
    _update(() => _exportPick = null);
    final a = pick.first;
    if (cancel || a == null) return pick.done.complete(null);
    final b = pick.last ?? a;
    pick.done.complete((unit: pick.unit, a: a < b ? a : b, b: a < b ? b : a));
  }

  /// The page under the last touch: of two facing, the first is on the right.
  int _pageUnderTap() {
    if (!_phoneSpread) return _pendingPage ?? _page;
    final first = _spreadStart(_pendingPage ?? _page);
    final box = _pagerKey.currentContext?.findRenderObject() as RenderBox?;
    final mid = box == null
        ? MediaQuery.sizeOf(context).width / 2
        : box.localToGlobal(box.size.center(Offset.zero)).dx;
    return _lastDown.dx < mid && first < _total ? first + 1 : first;
  }

  /// What to tap, then what's been chosen: above the page, under the finger's
  /// way (taps go through it).
  Widget _exportPickPill(MushafPaper paper) {
    final l = context.l10n;
    final pick = _exportPick!;
    String name(int v) => switch (pick.unit) {
          ExportPickUnit.verse => () {
              final (su, ay) = MushafRepo.surahAyahOf(v);
              return '$su:$ay';
            }(),
          _ => '$v',
        };
    final a = pick.first, b = pick.last ?? pick.first;
    final text = a == null
        ? switch (pick.unit) {
            ExportPickUnit.page => l.exPickHint,
            ExportPickUnit.surah => l.exPickHintSurah,
            ExportPickUnit.verse => l.exPickHintVerse,
          }
        : (a == b ? name(a) : '${name(a < b! ? a : b)} – ${name(a < b ? b : a)}');
    return KeyedSubtree(
        key: const ValueKey('export-pick-range'), child: _hifzHintPill(paper, text));
  }

  Widget _exportPickBar(MushafPaper paper, Axis axis) {
    final l = context.l10n;
    final pick = _exportPick!;
    final cancel = TextButton(
        onPressed: () => _endExportPick(cancel: true),
        child: Text(l.cancel, style: TextStyle(color: paper.sub)));
    final done = TextButton(
        onPressed: pick.first == null ? null : () => _endExportPick(cancel: false),
        child: Text(l.exPickDone));
    Widget unit(ExportPickUnit u, String label) {
      final on = pick.unit == u;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _setExportUnit(u),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? paper.ink.withValues(alpha: .1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              maxLines: 1,
              style: uiStyle(context,
                  size: 12.5,
                  weight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? paper.ink : paper.sub)),
        ),
      );
    }

    final units = [
      unit(ExportPickUnit.page, l.ppPages),
      unit(ExportPickUnit.surah, l.idxSurah),
      unit(ExportPickUnit.verse, l.exVerses),
    ];
    if (axis == Axis.vertical) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [cancel, ...units, done]),
      );
    }
    return Row(children: [
      cancel,
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: units),
        ),
      ),
      done,
    ]);
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
          ..onTapWord = ((wd) => _hifzErase([ref(wd)], breath: true))
          ..onLongPressWord = ((wd) => _hifzErase([ref(wd)], breath: true))
          ..onTapVerse = ((g) => _hifzErase([WordRef.fromGlobal(g, -1)]))
          ..onLongPressVerse = ((wd) => _hifzErase([ref(wd)]));
      case _HifzTool.breath:
        _handlers
          ..onTapWord = ((wd) {
            _lastWordTap = DateTime.now();
            if (!wd.isMarker) _marking.applyBreath(context, ref(wd));
          })
          ..onLongPressWord = _showWord
          ..onTapVerse = ((_) => _lastWordTap = DateTime.now())
          ..onLongPressVerse = _showWord;
      case _HifzTool.follow:
        // A word tapped: they'll recite from it.
        _handlers
          ..onTapWord = ((wd) => _followFrom(wd.ayah, wd.wordIdx))
          ..onLongPressWord = _showWord
          ..onTapVerse = ((g) => _followFrom(g, 0))
          ..onLongPressVerse = _showWord;
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
  /// [breath]: a word's breath marks go too (not when clearing a page).
  void _hifzErase(List<WordRef> refs, {bool quiet = false, bool breath = false}) {
    _lastWordTap = DateTime.now();
    final store = MarksScope.maybeOf(context);
    final book = store?.activeBook;
    if (store == null || book == null) return;
    final ops = <MarkOp>[];
    for (final r in refs) {
      for (final m in [
        ...store.marksAt(book.id, r),
        if (breath) ...store.breathAt(book.id, r),
      ]) {
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
        // (With an action Flutter would keep it until it's swiped away.)
        persist: false,
        duration: const Duration(seconds: 4),
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

  /// Which muṣḥaf.
  void _hifzEdition(BuildContext anchor, AxisDirection side) => showEditionPopover(context,
      anchor: anchor, side: side, script: _script, onChanged: _switchScript);

  // ── View ──

  /// The page or its verses, and the colouring.
  void _hifzView(BuildContext anchor, AxisDirection side, AppSettings s) {
    showToolPopover<void>(context, anchor: anchor, side: side, builder: (pop) {
      return StatefulBuilder(builder: (pop, setPop) {
        final l = pop.l10n;
        void set(VoidCallback f) {
          s.update(f);
          setPop(() {});
        }

        return _popoverBody(pop, [
          // The page, or its verses (the reader's cards, grid or flow).
          QSegmented<String>(
            options: [
              ('page', l.rdPage, null),
              ('verses', l.rdVerses, null),
            ],
            value: 'page',
            onChanged: (v) {
              if (v != 'verses') return;
              Navigator.pop(pop);
              _hifzVerses();
            },
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            dense: true,
            title: Text(l.mkShowBreath, style: uiStyle(pop, size: 14)),
            value: s.showBreath,
            onChanged: (v) => set(() => s.showBreath = v),
          ),
          _popoverLabel(pop, l.hzColouring),
          // (A printed word is one image: it can't colour its letters.)
          if (isOriginalScript(_script))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(l.edNoColouring,
                  style: uiStyle(pop, size: 12.5, color: pal(pop).ink3)),
            )
          else
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
        ]);
      });
    });
  }

  /// Light / dark / OLED, the page's colour and its ornaments'.
  void _hifzTheme(BuildContext anchor, AxisDirection side, AppSettings s) =>
      showThemePopover(context, anchor: anchor, side: side, s: s, script: _script);
}

/// Desktop mode's gear: [menu] (the tools not in the row), then the keys and
/// the button guide, in a small menu.
DockItem gearItem(BuildContext context, List<DockItem> menu) {
  final l = context.l10n;
  return DockItem(
    icon: AppIcons.settings,
    tooltip: l.settings,
    onTap: (b) => showDockMenu(b, [
      ...menu.where((d) => d.icon != AppIcons.settings),
      DockItem(
          icon: Icons.keyboard_outlined,
          tooltip: l.kaTitle,
          onTap: (_) => showKeyboardSheet(context)),
      DockItem(
          icon: AppIcons.info, tooltip: l.gdTitle, onTap: (_) => showButtonGuide(context)),
      ...menu.where((d) => d.icon == AppIcons.settings),
    ]),
  );
}
