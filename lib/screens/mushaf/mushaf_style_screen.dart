import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/l10n.dart';
import '../../core/mushaf_style.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/quran.dart';
import '../../ui/kit.dart';
import '../../ui/ornaments/ornaments.dart';
import '../../ui/qiraah_ornaments.dart' show AyahMarker;
import '../mushaf_screen.dart';

/// A look for the muṣḥaf in one tap, for the script being edited: every
/// ornament and the paper. (The app theme is left alone; the paper applies
/// to the light theme, the others having their own.) "Printed" is the
/// script's own printed muṣḥaf.
typedef MushafPreset = ({
  String id,
  String header,
  String marker,
  String border,
  String margin,
  String? paper,
  String head,
});

final kMushafPresets = <MushafPreset>[
  (
    id: 'print',
    header: 'auto',
    marker: 'auto',
    border: 'auto',
    margin: 'auto',
    paper: null,
    head: 'auto',
  ),
  (
    id: 'madaniPrint',
    header: 'madaniColoured',
    marker: 'font',
    border: 'thinnest3',
    margin: 'lantern1',
    paper: 'madani',
    head: 'frame',
  ),
  for (final n in [1, 2, 3])
    (
      id: 'tile$n',
      header: 'tile$n',
      marker: 'auto',
      border: 'tile$n',
      margin: 'lantern1',
      paper: 'tile$n',
      head: 'auto',
    ),
  (
    id: 'plain',
    header: 'madani',
    marker: 'font',
    border: 'none',
    margin: 'none',
    paper: 'white',
    head: 'inside',
  ),
];

/// The sample pages the preview can show.
enum _Sample { surahStart, fatiha, tawbah, plain }

/// The muṣḥaf's look, every part on its own, beside a live page drawn as
/// the muṣḥaf draws it: presets; then colours, sūrah header, āyah marker,
/// page border and the juzʼ in the margin, each option drawn as it looks
/// on this paper; and a tuning panel for each ornament's size, position
/// and thickness.
class MushafStyleScreen extends StatefulWidget {
  const MushafStyleScreen({super.key});

  @override
  State<MushafStyleScreen> createState() => _MushafStyleScreenState();
}

class _MushafStyleScreenState extends State<MushafStyleScreen> {
  /// The script the preview shows.
  String _script = 'uthmani';
  _Sample _sample = _Sample.surahStart;
  final Map<String, Map<_Sample, int>> _pages = {};
  Map<int, String> _names = {};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _script = SettingsScope.of(context).mushafScript == 'indopak'
        ? 'indopak'
        : 'uthmani';
    _load(_script);
  }

  /// Loads [script] and finds its sample pages: where Āl ʿImrān starts (a
  /// heading over its basmala, āyah markers, the juzʼ), al-Fātiḥah,
  /// at-Tawbah (a heading with no basmala) and an ordinary page.
  Future<void> _load(String script) async {
    if (_pages.containsKey(script)) return;
    await MushafRepo.ensure(script);
    await MushafAtlas.load(script, MushafRepo.tokensSync(script));
    final imran = await MushafRepo.pageForSurah(script, 3);
    final tawbah = await MushafRepo.pageForSurah(script, 9);
    final baqarah = await MushafRepo.pageForSurah(script, 2);
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    setState(() {
      _pages[script] = {
        _Sample.surahStart: imran,
        _Sample.fatiha: 1,
        _Sample.tawbah: tawbah,
        _Sample.plain: baqarah + 20,
      };
      _names = {for (final m in metas) m.n: m.name};
    });
  }

  void _showScript(String script) {
    setState(() => _script = script);
    _load(script);
  }

  /// [p] on the script being edited (a preset's paper, or the script's own).
  void _apply(AppSettings s, MushafPreset p) {
    final st = s.styleFor(_script);
    s.update(() {
      st.header = p.header;
      st.marker = p.marker;
      st.border = p.border;
      st.margin = p.margin;
      st.paper = p.paper ?? MushafStyle.defaultsFor(_script).paper;
      st.head = p.head;
    });
  }

  bool _matches(AppSettings s, MushafPreset p) {
    final st = s.styleFor(_script);
    return st.header == p.header &&
        st.marker == p.marker &&
        st.border == p.border &&
        st.margin == p.margin &&
        st.head == p.head &&
        st.paper == (p.paper ?? MushafStyle.defaultsFor(_script).paper);
  }

  String _presetName(BuildContext context, String id) => switch (id) {
    'print' => context.l10n.msPresetPrint,
    'madaniPrint' => context.l10n.msPresetMadaniPrint,
    'tile1' => context.l10n.paperTile1,
    'tile2' => context.l10n.paperTile2,
    'tile3' => context.l10n.paperTile3,
    _ => context.l10n.ornPlain,
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    final paper = mushafPaperOf(s);
    final page = _pages[_script]?[_sample];
    final preview = ColoredBox(
      color: paper.bg,
      child: page == null
          ? Center(child: CircularProgressIndicator(color: paper.acc))
          : Padding(
              padding: const EdgeInsets.all(14),
              child: MushafPagePreview(
                key: ValueKey('$_script/$page'),
                script: _script,
                page: page,
                names: _names,
              ),
            ),
    );
    final controls = _controls(context, s);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, title: Text(context.l10n.msTitle)),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 820) {
            // Side by side: the page as large as the window allows.
            return Row(
              children: [
                Expanded(child: preview),
                SizedBox(
                  width: 440,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: controls,
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: c.maxHeight * .5, child: preview),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: controls,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _controls(BuildContext context, AppSettings s) {
    final p = pal(context);
    // The look being edited: the previewed script's own.
    final st = s.styleFor(_script);
    final paper = mushafPaperOf(s, _script);
    final l = context.l10n;
    final light = s.theme == AppTheme.light;
    final dark = s.theme == AppTheme.night || s.theme == AppTheme.oled;
    // What "auto" resolves to here, for its swatch.
    final auto = MushafLook.resolve(
      _script,
      header: 'auto',
      marker: 'auto',
      border: 'auto',
      margin: 'auto',
    );
    final tune = st.tuning;
    final presetId = kMushafPresets
        .where((pr) => _matches(s, pr))
        .map((pr) => pr.id)
        .firstOrNull;

    Widget gallery(String title, List<Widget> swatches, {String? sub}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QSectionLabel(title),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  sub,
                  style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
                ),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: swatches),
          ],
        );
    Widget swatch(
      String label,
      bool on,
      VoidCallback? onTap,
      Widget art, {
      double width = 96,
      double height = 56,
    }) => _Swatch(
      label: label,
      selected: on,
      onTap: onTap,
      width: width,
      height: height,
      bg: paper.inner ?? paper.paper,
      accent: p.acc,
      child: art,
    );
    final header = st.header, marker = st.marker;
    final border = st.border, margin = st.margin;
    void set(void Function() f) => s.update(f);

    Widget headerArt(String kind) => SizedBox(
      width: 136,
      height: 40,
      child: MushafSurahHeader(
        kind: kind,
        lineHeight: 40,
        title: Text(
          kind == 'indopak' ? 'سُوْرَةُ' : 'سورة',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: kind == 'indopak'
                ? MushafRepo.fontFamily('indopak')
                : 'UthmanicHafs',
            fontSize: 40,
            color: paper.ink,
          ),
        ),
        plainTitle: 'سورة',
        plainStyle: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 16),
        frame: paper.frame,
        paper: paper.paper,
        soft: paper.soft,
        ink: paper.ink,
        fill: paper.inner,
        mono: paper.mono,
        dark: paper.dark,
        tune: tune,
      ),
    );
    Widget markerArt(String kind) => kind == 'font'
        ? Text(
            '۝١٢',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: MushafRepo.fontFamily(_script),
              fontSize: 30,
              color: paper.ink,
            ),
          )
        : AyahMarker(
            numeralAr: '١٢',
            size: 30,
            stroke: paper.frame,
            fill: paper.inner ?? paper.paper,
            textColor: paper.ink,
            art: kind,
          );
    Widget borderArt(String kind) => SizedBox(
      width: 84,
      height: 52,
      child: MushafPageBorder(
        kind: kind,
        band: kind.startsWith('thinnest')
            ? 7
            : kind.startsWith('tile') || kind.startsWith('thin')
            ? 12
            : 8,
        frame: paper.frame,
        cut: paper.inner ?? paper.paper,
        hairline: paper.paper,
        inner: paper.inner,
        padding: EdgeInsets.zero,
        mono: paper.mono,
        dark: paper.dark,
        child: const SizedBox.expand(),
      ),
    );
    Widget marginArt(String kind) => switch (kind) {
      'none' => Text('—', style: TextStyle(color: paper.sub, fontSize: 20)),
      'text' => EdgeLabel(
          text: _script == 'indopak' ? 'سَيَقُوْلُ  ٢' : 'الجزء الثاني',
          size: 11,
          color: paper.ink,
          quarterTurns: 3,
        ),
      _ => MarginLantern(
          kind: kind,
          width: 26,
          text: 'ربع الحزب\n٣',
          ink: paper.ink,
          fill: paper.inner,
        ),
    };
    String autoLabel(String what) => '${l.msBorderAuto} · $what';
    String artName(String v) => switch (v) {
      'madani' => l.madani,
      'madaniColoured' => l.msMadaniColoured,
      'indopak' => l.indopak,
      'tile1' => l.paperTile1,
      'tile2' => l.paperTile2,
      'tile3' => l.paperTile3,
      'thin1' => l.msThin1,
      'thin2' => l.msThin2,
      'thin3' => l.msThin3,
      'thinnest1' => l.msThinnest1,
      'thinnest2' => l.msThinnest2,
      'thinnest3' => l.msThinnest3,
      'lantern1' => l.msLantern1,
      'lantern2' => l.msLantern2,
      'text' => l.msText,
      _ => v,
    };

    return [
      // ── preview: script and sample page ──
      QSectionLabel(l.msPreviewScript),
      QSegmented<String>(
        options: [('uthmani', l.madani, null), ('indopak', l.indopak, null)],
        value: _script,
        onChanged: _showScript,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (v, label) in [
            (_Sample.surahStart, l.msPageSurahStart),
            (_Sample.fatiha, l.msPageFatiha),
            (_Sample.tawbah, l.msPageTawbah),
            (_Sample.plain, l.msPagePlain),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _sample == v,
              onSelected: (_) => setState(() => _sample = v),
            ),
        ],
      ),

      // ── presets ──
      QSectionLabel(l.msPresets),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pr in kMushafPresets)
            if (pr.id != 'madaniPrint' || _script != 'indopak')
            ChoiceChip(
              label: Text(_presetName(context, pr.id)),
              selected: presetId == pr.id,
              onSelected: (_) => _apply(s, pr),
            ),
          if (presetId == null)
            ChoiceChip(
              label: Text(l.msCustom),
              selected: true,
              onSelected: (_) {},
            ),
        ],
      ),

      // ── edge to edge ──
      const SizedBox(height: 12),
      QGroup(children: [
        QRow(
          title: l.msEdgeToEdge,
          subtitle: l.msEdgeToEdgeSub,
          control: QSwitch(
            value: st.edge,
            onChanged: (v) => set(() => st.edge = v),
          ),
        ),
      ]),

      // ── colours ──
      gallery(l.msColours, [
        if (dark)
          for (final (id, label) in [
            ('default', l.paperDefault),
            ('mono', l.paperMono),
          ])
            swatch(
              label,
              s.mushafPaperDark == id,
              () => set(() => s.mushafPaperDark = id),
              _PaperChip(
                kMushafPapers['${s.appTheme}${id == 'mono' ? '_mono' : ''}'] ??
                    paper,
              ),
            )
        else
          for (final (id, label) in [
            ('cream', l.paperCream),
            ('white', l.paperWhite),
            ('madani', l.paperMadani),
            ('mono', l.paperMono),
            ('tile1', l.paperTile1),
            ('tile2', l.paperTile2),
            ('tile3', l.paperTile3),
          ])
            swatch(
              label,
              light && st.paper == id,
              light ? () => set(() => st.paper = id) : null,
              _PaperChip(kMushafPapers[id]!),
            ),
      ], sub: light || dark ? null : l.msPaperLight),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (id, label) in [
            ('light', l.themeLight),
            ('mono', l.themeMono),
            ('night', l.themeNight),
            ('oled', l.themeOled),
          ])
            ChoiceChip(
              label: Text(label),
              selected: s.appTheme == id,
              onSelected: (_) => set(() => s.appTheme = id),
            ),
        ],
      ),

      // ── sūrah header ──
      gallery(l.msHeader, [
        for (final k in [
          'auto',
          'madani',
          'madaniColoured',
          'indopak',
          'tile1',
          'tile2',
          'tile3',
        ])
          swatch(
            k == 'auto' ? autoLabel(artName(auto.header)) : artName(k),
            header == k,
            s.lite ? null : () => set(() => st.header = k),
            headerArt(k == 'auto' ? auto.header : k),
            width: 152,
          ),
      ], sub: s.lite ? l.liteOffNote : l.msAutoSub),

      // ── āyah marker ──
      gallery(l.msMarker, [
        for (final k in ['auto', 'font', 'indopak'])
          swatch(
            switch (k) {
              'auto' => autoLabel(artName(auto.marker)),
              'font' => l.msFont,
              _ => artName(k),
            },
            marker == k,
            s.lite ? null : () => set(() => st.marker = k),
            markerArt(k == 'auto' ? auto.marker : k),
          ),
      ]),

      // ── page border ──
      gallery(l.msBorder, [
        for (final k in [
          'none',
          'auto',
          'line',
          'double',
          'madani',
          'indopak',
          'tile1',
          'tile2',
          'tile3',
          'thin1',
          'thin2',
          'thin3',
          'thinnest1',
          'thinnest2',
          'thinnest3',
        ])
          swatch(
            switch (k) {
              'none' => l.msNone,
              'auto' => autoLabel(artName(auto.border)),
              'line' => l.msBorderLine,
              'double' => l.msBorderDouble,
              _ => artName(k),
            },
            border == k,
            () => set(() => st.border = k),
            borderArt(k == 'auto' ? auto.border : k),
          ),
      ]),

      // ── the margins ──
      gallery(l.marginInfo, [
        for (final k in ['none', 'auto', 'lantern1', 'lantern2', 'text'])
          swatch(
            switch (k) {
              'none' => l.msNone,
              'auto' => autoLabel(artName(auto.margin)),
              _ => artName(k),
            },
            margin == k,
            () => set(() => st.margin = k),
            marginArt(k == 'auto' ? auto.margin : k),
            width: 76,
            height: 72,
          ),
      ], sub: l.msMarginSub),

      // ── the running head ──
      QSectionLabel(l.pageHeader),
      QGroup(
        children: [
          QRow(
            title: l.pageHeader,
            control: QSwitch(
              value: s.mushafHeader,
              onChanged: (v) => set(() => s.mushafHeader = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in [
                  ('auto', autoLabel(_script == 'indopak' ? l.msHeadEdges : l.msHeadInside)),
                  ('inside', l.msHeadInside),
                  ('frame', l.msHeadFrame),
                  ('edges', l.msHeadEdges),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: st.head == id,
                    onSelected: (_) => set(() => st.head = id),
                  ),
              ],
            ),
          ),
          if (MushafLook.resolve(_script,
                  header: 'auto',
                  marker: 'auto',
                  border: 'auto',
                  margin: 'auto',
                  head: st.head)
              .headOnEdges) ...[
            QRow(
              title: l.msEdgeTop,
              control: QSwitch(
                value: st.edgeTop,
                onChanged: (v) => set(() => st.edgeTop = v),
              ),
            ),
            QRow(
              title: l.msEdgeRuku,
              control: QSwitch(
                value: st.edgeRuku,
                onChanged: (v) => set(() => st.edgeRuku = v),
              ),
            ),
            QRow(
              title: l.msEdgeBottom,
              control: QSwitch(
                value: st.edgeBottom,
                onChanged: (v) => set(() => st.edgeBottom = v),
              ),
            ),
          ],
        ],
      ),

      // ── tuning ──
      const SizedBox(height: 12),
      _TuningPanel(settings: s, style: st),
      const SizedBox(height: 8),
      Text(
        l.msNote,
        style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
      ),
    ];
  }
}

/// One option, drawn as it looks: [child] on the page's paper, the label
/// under it, an accent outline when chosen.
class _Swatch extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double width, height;
  final Color bg, accent;
  final Widget child;
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.width,
    required this.height,
    required this.bg,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            width: width,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? accent : p.line2,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(
                    context,
                    size: 11.5,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A paper's colours in small: its margin, the inside, a band of its frame
/// colour, a line of ink and an accent dot.
class _PaperChip extends StatelessWidget {
  final MushafPaper paper;
  const _PaperChip(this.paper);

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 44,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: paper.paper,
      border: Border.all(color: paper.frame, width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Container(
      color: paper.inner ?? paper.paper,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 22, height: 3, color: paper.ink),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: paper.acc,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Each ornament's size, position and thickness, adjusted live (the page
/// above redraws), with the numbers shown and a way to copy them all.
class _TuningPanel extends StatelessWidget {
  final AppSettings settings;
  final MushafStyle style;
  const _TuningPanel({required this.settings, required this.style});

  String _label(BuildContext context, String key) {
    final l = context.l10n;
    return switch (key) {
      'headerScale' => l.tuneHeaderScale,
      'headerDy' => l.tuneHeaderDy,
      'twoTierScale' => l.tuneTwoTierScale,
      'headerNameScale' => l.tuneHeaderNameScale,
      'headerNameDy' => l.tuneHeaderNameDy,
      'markerIndopakScale' => l.tuneMarkerIndopakScale,
      'markerIndopakDy' => l.tuneMarkerIndopakDy,
      'lanternScale' => l.tuneLanternScale,
      'borderMadani' => l.tuneBorderMadani,
      'borderIndopak' => l.tuneBorderIndopak,
      'borderTile' => l.tuneBorderTile,
      'borderThin' => l.tuneBorderThin,
      'borderThinnest' => l.tuneBorderThinnest,
      'basmalaScale' => l.tuneBasmalaScale,
      'lanternGap' => l.tuneLanternGap,
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final p = pal(context);
    final l = context.l10n;
    final tune = style.tuning;
    return QGroup(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text(
              l.msTune,
              style: uiStyle(context, size: 15, weight: FontWeight.w700),
            ),
            subtitle: Text(
              l.msTuneSub,
              style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
            ),
            children: [
              for (final MapEntry(:key, value: spec)
                  in OrnamentTuning.specs.entries) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _label(context, key),
                        style: uiStyle(context, size: 13),
                      ),
                    ),
                    Text(
                      tune[key].toStringAsFixed(2),
                      style: uiStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: tune.overrides.containsKey(key)
                            ? p.acc
                            : p.ink3,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: tune[key].clamp(spec.min, spec.max),
                  min: spec.min,
                  max: spec.max,
                  onChanged: (v) => s.update(
                    () => style.tune = Map.of(tune.withValue(key, v).overrides),
                  ),
                ),
              ],
              Row(
                children: [
                  TextButton(
                    onPressed: tune.overrides.isEmpty
                        ? null
                        : () => s.update(() => style.tune = {}),
                    child: Text(l.msTuneReset),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: tune.describe()),
                      );
                      if (context.mounted) {
                        showQToast(context, l.msTuneCopied);
                      }
                    },
                    child: Text(l.msTuneCopy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
