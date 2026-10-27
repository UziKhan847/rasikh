import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'app_mode.dart';
import 'modules.dart';

/// Each mode's home in miniature, so the choice is seen, not just named:
/// the setup's mode step and Settings' Mode section show the four side by
/// side. Drawn, not live: the real homes take the screen over (orientation,
/// system bars, last page) and are heavy four at a time. They follow the
/// theme and the language like the real ones.

/// The previews are drawn on this canvas, then scaled to the tile.
const _canvas = Size(200, 300);

/// The modes as tiles, two or four to a row: each a preview, its name and a
/// line; [selected] ringed. [onDark] on the setup's hero gradient.
class ModeGrid extends StatelessWidget {
  final AppMode? selected;
  final ValueChanged<AppMode> onPicked;
  final bool onDark;
  const ModeGrid({super.key, required this.selected, required this.onPicked, this.onDark = false});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        // Four in a row once each would still be ~120 wide.
        final cols = c.maxWidth >= 520 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final m in AppMode.values)
            SizedBox(
              width: w,
              child: _ModeTile(
                  mode: m, selected: selected == m, onDark: onDark, onTap: () => onPicked(m)),
            ),
        ]);
      });
}

class _ModeTile extends StatelessWidget {
  final AppMode mode;
  final bool selected, onDark;
  final VoidCallback onTap;
  const _ModeTile({required this.mode, required this.selected, required this.onDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final ring = onDark ? kHeroGold : p.acc;
    final ink = onDark ? kHeroInk : p.ink;
    final ink2 = onDark ? kHeroInk2 : p.ink3;
    return Semantics(
      button: true,
      selected: selected,
      label: mode.title(context),
      child: Material(
        color: selected ? ring.withValues(alpha: .10) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: selected ? ring : (onDark ? kHeroInk.withValues(alpha: .16) : p.line2),
              width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: _canvas.width / _canvas.height,
                child: Stack(children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ExcludeSemantics(
                        child: FittedBox(
                            child: SizedBox.fromSize(size: _canvas, child: ModePreview(mode))),
                      ),
                    ),
                  ),
                  if (selected)
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: ring,
                        child: Icon(AppIcons.check, size: 14, color: onDark ? const Color(0xFF0F3B32) : Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(mode.title(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 14, height: 1.25, weight: FontWeight.w700, color: ink)),
              const SizedBox(height: 2),
              Text(mode.subtitle(context),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context, size: 11.5, height: 1.3, color: ink2)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// [mode]'s home, on the [_canvas].
class ModePreview extends StatelessWidget {
  final AppMode mode;
  const ModePreview(this.mode, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: pal(context).bg),
        child: switch (mode) {
          AppMode.hifz => const _Hifz(),
          AppMode.reader => const _Reader(),
          AppMode.learn => const _Learn(),
          AppMode.write => const _Write(),
        },
      );
}

Widget _icons(BuildContext context, List<IconData> icons, {double size = 11}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final i in icons) Icon(i, size: size, color: pal(context).ink2)],
    );

Widget _bar(BuildContext context, double w, {double h = 4, Color? color}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
          color: color ?? pal(context).line3, borderRadius: BorderRadius.circular(h / 2)),
    );

/// The Hifẓ home: a page of the muṣḥaf, borderless, its header line, the
/// toolbar.
class _Hifz extends StatelessWidget {
  const _Hifz();

  static const _page = 3;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final script = SettingsScope.of(context).mushafScript;
    final head = uiStyle(context, size: 7.5, weight: FontWeight.w700, color: p.acc);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: Row(children: [
          Text('Al-Baqarah', style: head),
          const Spacer(),
          Text('$_page', style: head),
          const Spacer(),
          Text(context.l10n.juzN(1), style: head),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FutureBuilder(
            future: MushafRepo.ensure(script),
            builder: (context, _) {
              final lines = MushafRepo.pageSync(script, _page);
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final l in lines ?? List.filled(15, const MushafLine.basmala()))
                    SizedBox(
                      width: double.infinity,
                      height: 14,
                      child: lines == null || !l.isText
                          ? Align(child: _bar(context, 160, h: 3))
                          // Each line scaled to the width: justified, near enough.
                          : FittedBox(
                              fit: BoxFit.fill,
                              child: Text(l.words.map((w) => w.text).join(' '),
                                  textDirection: TextDirection.rtl,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontFamily: MushafRepo.fontFamily(script),
                                      fontSize: 20,
                                      height: 1.5,
                                      color: p.ink)),
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      Container(
        height: 24,
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line2))),
        child: _icons(context, const [
          AppIcons.settings,
          AppIcons.indexList,
          AppIcons.pen,
          AppIcons.comment,
          AppIcons.eraser,
          AppIcons.volume,
          AppIcons.memorize,
        ]),
      ),
    ]);
  }
}

/// The Reader: the sūrah's bar, āyah cards, the player.
class _Reader extends StatelessWidget {
  const _Reader();

  static const _ayat = [
    'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
    'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    'مَٰلِكِ يَوْمِ ٱلدِّينِ',
    'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
  ];

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget card(int i) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: p.line2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_ayat[i],
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: quranicStyle(context, size: 13, height: 1.7, color: p.ink)),
            const SizedBox(height: 3),
            Row(children: [
              Text('${i + 2}', style: uiStyle(context, size: 7, color: p.acc, weight: FontWeight.w700)),
              const Spacer(),
              Icon(AppIcons.bookmark, size: 9, color: p.ink3),
              const SizedBox(width: 6),
              Icon(AppIcons.play, size: 9, color: p.ink3),
            ]),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Al-Fātiḥah',
                  maxLines: 1, style: uiStyle(context, size: 10, weight: FontWeight.w700, color: p.ink)),
              _bar(context, 40, h: 3),
            ]),
          ),
          for (final i in const [AppIcons.indexList, AppIcons.mushaf, AppIcons.tune])
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: CircleAvatar(
                  radius: 8, backgroundColor: p.card, child: Icon(i, size: 9, color: p.ink2)),
            ),
        ]),
      ),
      for (var i = 0; i < _ayat.length; i++) card(i),
      const Spacer(),
      Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line2))),
        child: Row(children: [
          _bar(context, 34, h: 3),
          const Spacer(),
          CircleAvatar(
              radius: 9, backgroundColor: p.acc,
              child: const Icon(AppIcons.play, size: 10, color: Colors.white)),
          const Spacer(),
          _bar(context, 20, h: 3),
        ]),
      ),
    ]);
  }
}

/// Learning: the path's card, then the modules.
class _Learn extends StatelessWidget {
  const _Learn();

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.navLearn, style: displayStyle(context, size: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientsOf(context).hero),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(children: [
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                  value: .2, strokeWidth: 3, color: kHeroGold,
                  backgroundColor: Colors.white.withValues(alpha: .14)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.pathTitle.toUpperCase(),
                    maxLines: 1,
                    style: uiStyle(context, size: 6.5, weight: FontWeight.w700, color: kHeroInk2)),
                Text('ا ب ت',
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context, size: 13, height: 1.5, color: kHeroInk)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        for (final m in const [LearnModule.qaidah, LearnModule.tajwid, LearnModule.tashkil, LearnModule.script])
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: p.line2),
            ),
            child: Row(children: [
              QGlyphTile(m.glyph, hue: m.hue, size: 24, radius: 7),
              const SizedBox(width: 7),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context, size: 8, weight: FontWeight.w700, color: p.ink)),
                  const SizedBox(height: 3),
                  _bar(context, 70, h: 3),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Writing: the levels, the letters, and the board with a letter to trace.
class _Write extends StatelessWidget {
  const _Write();

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.l10n.tracingStudio,
            maxLines: 1, style: uiStyle(context, size: 10.5, weight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 7),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(right: 5),
              width: 38,
              height: 13,
              decoration: BoxDecoration(
                color: i == 0 ? p.acc : p.card,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: i == 0 ? p.acc : p.line2),
              ),
            ),
        ]),
        const SizedBox(height: 7),
        Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (i, l) in const ['ا', 'ب', 'ت', 'ث', 'ج', 'ح'].indexed)
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == 1 ? p.accSoft : p.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: i == 1 ? p.acc : p.line2),
                ),
                child: Text(l, style: quranicStyle(context, size: 12, height: 1.3, color: p.ink)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line2),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Text('ب',
                  style: quranicStyle(context,
                      size: 110, height: 1.2, color: p.ink.withValues(alpha: .13))),
              Positioned(
                right: 46,
                top: 92,
                child: CircleAvatar(radius: 6, backgroundColor: p.acc),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
