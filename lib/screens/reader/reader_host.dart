import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/mushaf.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../mushaf_screen.dart';
import '../quran_screen.dart';

/// What the Reader's two views hand each other: a way across to the other
/// view at a place, and to another place in the verses view.
class ReaderLink {
  /// To the 15-line page [page].
  final void Function(int page) toPage;

  /// To the verses, at [surah]:[ayah].
  final void Function(int surah, int ayah) toVerses;
  const ReaderLink({required this.toPage, required this.toVerses});
}

/// The Reader: one place, two views — the verses (cards, word grid or
/// flow) and the 15-line page — a switch apart, the place kept across.
/// Back from either goes to the index; the view last used comes back.
class ReaderHost extends StatefulWidget with DesktopAware {
  final SurahMeta meta;
  final int? startAyah;
  const ReaderHost({super.key, required this.meta, this.startAyah});

  @override
  State<ReaderHost> createState() => _ReaderHostState();
}

class _ReaderHostState extends State<ReaderHost> {
  late SurahMeta _meta = widget.meta;
  late int? _ayah = widget.startAyah;

  /// The page view's page; null until it's been worked out.
  int? _page;
  String? _view;

  late final _link = ReaderLink(toPage: _toPage, toVerses: _toVerses);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_view != null) return;
    _view = SettingsScope.of(context).readerView;
    if (_view == 'page') _pageForPlace();
  }

  /// Opening on the page view: the page of the place asked for.
  Future<void> _pageForPlace() async {
    final script = SettingsScope.of(context).mushafScript;
    await MushafRepo.ensure(script);
    final a = _ayah;
    final p = a == null
        ? await MushafRepo.pageForSurah(script, _meta.n)
        : MushafRepo.pageForGlobalAyah(script, MushafRepo.globalAyahOf(_meta.n, a));
    if (mounted) setState(() => _page = p);
  }

  void _remember(String view) {
    final s = SettingsScope.of(context);
    if (s.readerView != view) s.update(() => s.readerView = view);
  }

  void _toPage(int page) {
    _remember('page');
    setState(() {
      _view = 'page';
      _page = page;
    });
  }

  Future<void> _toVerses(int surah, int ayah) async {
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    _remember('verses');
    setState(() {
      _view = 'verses';
      _meta = metas[surah - 1];
      _ayah = ayah;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_view == 'page') {
      final page = _page;
      if (page == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return MushafPageScreen(
        key: ValueKey('page/$page'),
        startPage: page,
        script: SettingsScope.of(context).mushafScript,
        reader: _link,
      );
    }
    return SurahReaderScreen(
      key: ValueKey('verses/${_meta.n}/$_ayah'),
      meta: _meta,
      startAyah: _ayah,
      link: _link,
    );
  }
}

/// The Reader's view switch: Verses | Page, in the colours of the bar it
/// sits in.
class ReaderViewSwitch extends StatelessWidget {
  final bool page;
  final ValueChanged<bool> onChanged;
  final Color ink, accent, track, onAccent;

  /// Icons for the words, where room is short (a phone's bar).
  final bool compact;
  const ReaderViewSwitch({
    super.key,
    required this.page,
    this.compact = false,
    required this.onChanged,
    required this.ink,
    required this.accent,
    required this.track,
    required this.onAccent,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget seg(String label, bool isPage) {
      final on = isPage == page;
      return Semantics(
        selected: on,
        button: true,
        label: compact ? label : null,
        child: Tooltip(
          message: label,
          child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: on ? null : () => onChanged(isPage),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: compact
                ? Icon(isPage ? AppIcons.mushaf : AppIcons.reader,
                    size: 18, color: on ? onAccent : ink)
                : Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: on ? onAccent : ink)),
          ),
        ),
        ),
      );
    }

    return Material(
      color: track,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          seg(l.rdVerses, false),
          seg(l.rdPage, true),
        ]),
      ),
    );
  }
}
