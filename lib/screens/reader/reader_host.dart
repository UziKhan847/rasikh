import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/mushaf.dart';
import '../../data/quran.dart';
import '../../ui/app_icons.dart';
import '../quran_screen.dart';

/// What the Reader's two views hand each other: a way across to the other
/// view at a place, and to another place in the verses view.
/// What's on, carried across the switch between the page and the verses: a
/// kind of marking (its session going on), or the recitation's tool.
class ViewMode {
  /// 'recitation', or a fluency kind; null: not marking.
  final String? markKind;
  final String? sessionId;
  final bool audio;

  /// Following the recitation (its session goes on).
  final bool follow;
  const ViewMode({this.markKind, this.sessionId, this.audio = false, this.follow = false});
  static const none = ViewMode();
}

/// The verses closed: the page to show, and what to carry on with there.
class ReaderExit {
  final int page;
  final ViewMode mode;
  const ReaderExit(this.page, [this.mode = ViewMode.none]);
}

class ReaderLink {
  /// To the 15-line page [page], carrying on with [mode] there.
  final void Function(int page, [ViewMode mode]) toPage;

  /// To the verses, at [surah]:[ayah].
  final void Function(int surah, int ayah) toVerses;
  const ReaderLink({required this.toPage, required this.toVerses});
}

/// The muṣḥaf's Verses view: the reader (cards, word grid or flow) at a
/// place, its switch back to the page. Opened over the muṣḥaf with
/// [openVerses]; it closes with the page to show, or none (back).
class VersesView extends StatefulWidget with DesktopAware {
  final SurahMeta meta;
  final int? startAyah;

  /// The page it was opened from (in [script]): back on it if the reading
  /// hasn't moved on (its first āyah may have begun on the page before).
  final int? fromPage;
  final String script;
  /// What was on in the page view: carried on here.
  final ViewMode mode;
  const VersesView(
      {super.key,
      required this.meta,
      this.startAyah,
      this.fromPage,
      this.script = 'uthmani',
      this.mode = ViewMode.none});

  @override
  State<VersesView> createState() => _VersesViewState();
}

class _VersesViewState extends State<VersesView> {
  late SurahMeta _meta = widget.meta;
  late int? _ayah = widget.startAyah;
  // Only for the first sūrah it opens on.
  late ViewMode? _mode = widget.mode;

  /// Open now: the app comes back here if it's left (backing out clears it;
  /// a killed app never gets that far).
  ProgressStore? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress ??= ProgressScope.read(context)..setInVerses(true);
  }

  @override
  void dispose() {
    _progress?.setInVerses(false);
    super.dispose();
  }

  late final _link = ReaderLink(
    // Back to the page: the muṣḥaf shows it — the one it came from, if the
    // reading is still where it began.
    toPage: (page, [mode = ViewMode.none]) => Navigator.of(context)
        .pop(ReaderExit(_unmoved(page) ? widget.fromPage! : page, mode)),
    toVerses: _toVerses,
  );

  bool _unmoved(int page) {
    final a = widget.startAyah, from = widget.fromPage;
    if (a == null || from == null || _meta.n != widget.meta.n) return false;
    return page == MushafRepo.pageForGlobalAyah(widget.script, MushafRepo.globalAyahOf(_meta.n, a));
  }

  Future<void> _toVerses(int surah, int ayah) async {
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    setState(() {
      _meta = metas[surah - 1];
      _ayah = ayah;
      _mode = null;
    });
  }

  @override
  Widget build(BuildContext context) => SurahReaderScreen(
        key: ValueKey('verses/${_meta.n}/$_ayah'),
        meta: _meta,
        startAyah: _ayah,
        link: _link,
        startMode: _mode,
      );
}

/// The Verses view of [page] (its first āyah), over the muṣḥaf: the page
/// to show once it's switched back, or null.
Future<ReaderExit?> openVerses(BuildContext context, String script, int page,
    {ViewMode mode = ViewMode.none}) async {
  final (s, a) = MushafRepo.firstVerseOfPage(script, page);
  final metas = await QuranRepo.meta();
  if (!context.mounted) return null;
  return Navigator.of(context).push<ReaderExit>(
      MaterialPageRoute(
          builder: (_) => VersesView(
              meta: metas[s - 1], startAyah: a, fromPage: page, script: script, mode: mode)));
}

/// The Verses view at [surah]:[ayah], over the muṣḥaf, already there (the
/// app coming back to it): the page to show once it's switched back, or null.
/// [onPushed]: it's on its way up (the caller can stop covering what's under).
Future<ReaderExit?> resumeVerses(BuildContext context, String script, int surah, int ayah,
    {VoidCallback? onPushed}) async {
  final metas = await QuranRepo.meta();
  if (!context.mounted) {
    onPushed?.call();
    return null;
  }
  final done = Navigator.of(context).push<ReaderExit>(_ArrivedRoute(
    builder: (_) => VersesView(meta: metas[surah - 1], startAyah: ayah, script: script),
  ));
  onPushed?.call();
  return done;
}

/// A page that's already there when it opens, and leaves like any other.
class _ArrivedRoute extends MaterialPageRoute<ReaderExit> {
  _ArrivedRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// The Reader's view switch: Verses | Page, in the colours of the bar it
/// sits in.
class ReaderViewSwitch extends StatelessWidget {
  final bool page;
  final ValueChanged<bool> onChanged;
  final Color ink, accent, track, onAccent;

  /// Icons for the words, where room is short (a phone's bar).
  final bool compact;

  /// Smaller still, icons only: in the line above the 15-line page.
  final bool dense;

  /// Down the side, in landscape.
  final Axis axis;
  const ReaderViewSwitch({
    super.key,
    required this.page,
    this.compact = false,
    this.dense = false,
    this.axis = Axis.horizontal,
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
        label: compact || dense ? label : null,
        child: Tooltip(
          message: label,
          child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: on ? null : () => onChanged(isPage),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: dense
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: compact || dense
                ? Icon(isPage ? AppIcons.mushaf : AppIcons.reader,
                    size: dense ? 13 : 18, color: on ? onAccent : ink)
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
        padding: EdgeInsets.all(dense ? 2 : 3),
        child: Flex(direction: axis, mainAxisSize: MainAxisSize.min, children: [
          seg(l.rdVerses, false),
          seg(l.rdPage, true),
        ]),
      ),
    );
  }
}
