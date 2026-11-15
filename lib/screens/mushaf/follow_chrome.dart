part of '../mushaf_screen.dart';

/// Follow my recitation on the muṣḥaf: the word they're on lit (its āyah
/// tinted), the page turned as they finish it, and the page shown where
/// they started if elsewhere. It keeps their place; it doesn't judge the
/// recitation.
extension _FollowChrome on _MushafPageScreenState {
  FollowSession get _fs => FollowSession.instance;

  bool get _following => _hifzTool == _HifzTool.follow;

  /// The word followed, (global āyah, muṣḥaf word0), while it's this tool.
  (int, int)? get _followPlace => _following ? _fs.place : null;

  /// The tool, on or off: on starts from the first word in view.
  Future<void> _hifzFollow() async {
    if (_following) {
      _hifzSetTool(_HifzTool.none);
      if (identical(_fs.owner, this)) await _fs.stop();
      return;
    }
    _stopAudio();
    _hifzSetTool(_HifzTool.follow);
    final (g, w) = _followFirstInView();
    final ok = await startFollow(context, this, g, w);
    if (!mounted) return;
    if (!ok && _following) _update(() => _hifzTool = _HifzTool.none);
  }

  /// The first word of the page (or spread) in view.
  (int, int) _followFirstInView() {
    final s = SettingsScope.of(context);
    final page = _pendingPage ?? _page;
    final spread = (_desktop && _view(s) == 'spread') || _phoneSpread;
    final (first, end) = MushafRepo.pageTokens(_script, spread ? _spreadStart(page) : page);
    for (var t = first; t < end; t++) {
      final (g, w) = MushafRepo.tokenAt(_script, t);
      if (w >= 0) return (g, w);
    }
    return MushafRepo.tokenAt(_script, first);
  }

  /// A word heard: lit, and the page turned once its last word is heard.
  void _onFollowWord() {
    if (mounted && _memoFollow) return _memoHeard();
    if (!mounted || !_following) return;
    final place = _fs.place;
    if (place == null) {
      _update(() {});
      return;
    }
    final (g, w) = place;
    final pg = MushafRepo.pageOfWord(_script, g, w);
    var target = pg;
    final words = _fs.words;
    final i = _fs.word.value;
    if (words != null && i + 1 < words.length) {
      final next = MushafRepo.pageOfWord(_script, words.ayahOf[i + 1], words.word0Of[i + 1]);
      // The page's last word: on to the next, where they'll go on.
      if (next != pg) target = next;
    }
    _followTurnTo = target;
    _showPage(target);
    _update(() {});
  }

  /// They started elsewhere: said, briefly.
  void _onFollowJump() {
    if (!mounted || !_following) return;
    if (_fs.place case (final g, _)) {
      showQToast(context, context.l10n.followFound(followRef(g)));
    }
  }

  void _onFollowStatus() {
    if (!mounted) return;
    if (_memoFollow && !_fs.active && !identical(_fs.owner, #verses)) {
      _update(() => _memoFollow = false);
      return;
    }
    // Stopped elsewhere (its options, another view): the tool goes too.
    if (_following && !_fs.active && identical(_fs.owner, this)) {
      _update(() => _hifzTool = _HifzTool.none);
    } else if (_following) {
      _update(() {});
    }
  }

  /// A page settled: one they turned to themselves is where they'll go on.
  void _followSettled(int page) {
    if (!_following || !_fs.active) return;
    final s = SettingsScope.of(context);
    final spread = (_desktop && _view(s) == 'spread') || _phoneSpread;
    bool same(int a, int b) => spread ? _spreadStart(a) == _spreadStart(b) : a == b;
    final to = _followTurnTo;
    if (to != null && same(to, page)) return;
    _followTurnTo = null;
    if (_fs.place case (final g, final w) when same(MushafRepo.pageOfWord(_script, g, w), page)) {
      return;
    }
    final (g, w) = _followFirstInView();
    _fs.setPosition(g, w);
  }

  /// A word tapped while following: "from here".
  void _followFrom(int g, int word0) {
    _fs.setPosition(g, word0 < 0 ? 0 : word0);
    _update(() {});
  }

  Widget _followBar(MushafPaper paper, Axis axis) => FollowBar(
        ink: paper.ink,
        sub: paper.sub,
        accent: paper.id == 'mono' ? paper.ink : paper.acc,
        axis: axis,
        onDone: _hifzFollow,
      );
}
