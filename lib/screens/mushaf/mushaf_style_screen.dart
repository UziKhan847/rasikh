import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../data/quran.dart';
import '../../ui/kit.dart';
import '../mushaf_screen.dart';

/// A look for the muṣḥaf in one tap: ornaments, border, margin and paper
/// together. (The app theme is left alone; the paper applies to the light
/// theme, the others having their own.)
typedef MushafPreset = ({
  String id,
  String ornaments,
  bool border,
  String borderStyle,
  bool margin,
  String paper,
  String script,
});

const kMushafPresets = <MushafPreset>[
  (
    id: 'madani',
    ornaments: 'classic',
    border: true,
    borderStyle: 'madani',
    margin: true,
    paper: 'madani',
    script: 'uthmani',
  ),
  (
    id: 'indopak',
    ornaments: 'classic',
    border: true,
    borderStyle: 'indopak',
    margin: true,
    paper: 'cream',
    script: 'indopak',
  ),
  (
    id: 'modern',
    ornaments: 'modern',
    border: true,
    borderStyle: 'double',
    margin: false,
    paper: 'cream',
    script: 'uthmani',
  ),
  (
    id: 'plain',
    ornaments: 'plain',
    border: false,
    borderStyle: 'auto',
    margin: false,
    paper: 'white',
    script: 'uthmani',
  ),
];

/// The muṣḥaf's look, with a live page to judge it by: presets, then the
/// ornaments, border (on or off, and its style, whatever the script),
/// juzʼ margin, paper and theme one by one. The page is drawn as the muṣḥaf
/// draws it, from the setting as it changes.
class MushafStyleScreen extends StatefulWidget {
  const MushafStyleScreen({super.key});

  @override
  State<MushafStyleScreen> createState() => _MushafStyleScreenState();
}

class _MushafStyleScreenState extends State<MushafStyleScreen> {
  /// The script the preview shows (both have their own artwork).
  String _script = 'uthmani';
  final Map<String, int> _pages = {};
  Map<int, String> _names = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_names.isEmpty && _pages.isEmpty) {
      _script = SettingsScope.of(context).mushafScript == 'indopak'
          ? 'indopak'
          : 'uthmani';
      _load(_script);
    }
  }

  /// Loads [script] and finds the page Āl ʿImrān starts on: a sūrah
  /// heading, the basmala, āyah markers and the juzʼ, all on one page.
  Future<void> _load(String script) async {
    if (_pages.containsKey(script)) return;
    await MushafRepo.ensure(script);
    await MushafAtlas.load(script, MushafRepo.tokensSync(script));
    final page = await MushafRepo.pageForSurah(script, 3);
    final metas = await QuranRepo.meta();
    if (!mounted) return;
    setState(() {
      _pages[script] = page;
      _names = {for (final m in metas) m.n: m.name};
    });
  }

  void _showScript(String script) {
    setState(() => _script = script);
    _load(script);
  }

  void _apply(AppSettings s, MushafPreset p) {
    s.update(() {
      s.ornaments = p.ornaments;
      s.mushafBorder = p.border;
      s.mushafBorderStyle = p.borderStyle;
      s.mushafMarginInfo = p.margin;
      s.mushafPaper = p.paper;
    });
    if (p.script != _script) _showScript(p.script);
  }

  bool _matches(AppSettings s, MushafPreset p) =>
      s.ornaments == p.ornaments &&
      s.mushafBorder == p.border &&
      s.mushafBorderStyle == p.borderStyle &&
      s.mushafMarginInfo == p.margin &&
      s.mushafPaper == p.paper;

  String _presetName(BuildContext context, String id) => switch (id) {
    'madani' => context.l10n.msPresetMadani,
    'indopak' => context.l10n.msPresetIndopak,
    'modern' => context.l10n.ornModern,
    _ => context.l10n.ornPlain,
  };

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    final paper = mushafPaperOf(s);
    final page = _pages[_script];
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
      appBar: AppBar(
        backgroundColor: p.bg,
        title: Text(context.l10n.msTitle),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 820) {
            // Side by side: the page as large as the window allows.
            return Row(
              children: [
                Expanded(child: preview),
                SizedBox(
                  width: 420,
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
    Widget full(String title, Widget control, {String? sub}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                sub,
                style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
              ),
            ),
          const SizedBox(height: 10),
          control,
        ],
      ),
    );
    Widget choices(
      List<(String, String)> opts,
      String value,
      ValueChanged<String>? onChanged,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in opts)
          ChoiceChip(
            label: Text(label),
            selected: value == id,
            onSelected: onChanged == null ? null : (_) => onChanged(id),
          ),
      ],
    );
    final light = s.theme == AppTheme.light;
    final dark = s.theme == AppTheme.night || s.theme == AppTheme.oled;
    return [
      QSectionLabel(context.l10n.msPreviewScript),
      QSegmented<String>(
        options: [
          ('uthmani', context.l10n.madani, null),
          ('indopak', context.l10n.indopak, null),
        ],
        value: _script,
        onChanged: _showScript,
      ),
      QSectionLabel(context.l10n.msPresets),
      choices(
        [for (final pr in kMushafPresets) (pr.id, _presetName(context, pr.id))],
        kMushafPresets
                .where((pr) => _matches(s, pr))
                .map((pr) => pr.id)
                .firstOrNull ??
            '',
        (id) => _apply(s, kMushafPresets.firstWhere((pr) => pr.id == id)),
      ),
      QSectionLabel(context.l10n.style),
      QGroup(
        children: [
          full(
            context.l10n.ornaments,
            choices(
              [
                ('plain', context.l10n.ornPlain),
                ('modern', context.l10n.ornModern),
                ('classic', context.l10n.ornClassic),
              ],
              s.ornamentStyle,
              s.lite ? null : (v) => s.update(() => s.ornaments = v),
            ),
            sub: s.lite ? context.l10n.liteOffNote : context.l10n.ornamentsSub,
          ),
          QRow(
            title: context.l10n.pageBorder,
            subtitle: context.l10n.pageBorderSub,
            control: QSwitch(
              value: s.mushafBorder,
              onChanged: (v) => s.update(() => s.mushafBorder = v),
            ),
          ),
          if (s.mushafBorder)
            full(
              context.l10n.msBorderStyle,
              choices(
                [
                  ('auto', context.l10n.msBorderAuto),
                  ('line', context.l10n.msBorderLine),
                  ('double', context.l10n.msBorderDouble),
                  ('madani', context.l10n.madani),
                  ('indopak', context.l10n.indopak),
                ],
                s.mushafBorderStyle,
                (v) => s.update(() => s.mushafBorderStyle = v),
              ),
              sub: context.l10n.msBorderStyleSub,
            ),
          QRow(
            title: context.l10n.marginInfo,
            subtitle: s.useClassic
                ? context.l10n.marginInfoSub
                : context.l10n.msMarginClassicOnly,
            control: QSwitch(
              value: s.mushafMarginInfo,
              onChanged: s.useClassic
                  ? (v) => s.update(() => s.mushafMarginInfo = v)
                  : null,
            ),
          ),
          QRow(
            title: context.l10n.pageHeader,
            control: QSwitch(
              value: s.mushafHeader,
              onChanged: (v) => s.update(() => s.mushafHeader = v),
            ),
          ),
        ],
      ),
      QSectionLabel(context.l10n.mushafPaper),
      QGroup(
        children: [
          if (dark)
            full(
              context.l10n.mushafPaper,
              choices(
                [
                  ('default', context.l10n.paperDefault),
                  ('mono', context.l10n.paperMono),
                ],
                s.mushafPaperDark,
                (v) => s.update(() => s.mushafPaperDark = v),
              ),
              sub: context.l10n.paperDarkSub,
            )
          else
            full(
              context.l10n.mushafPaper,
              choices(
                [
                  ('cream', context.l10n.paperCream),
                  ('white', context.l10n.paperWhite),
                  ('madani', context.l10n.paperMadani),
                  ('mono', context.l10n.paperMono),
                ],
                s.mushafPaper,
                light ? (v) => s.update(() => s.mushafPaper = v) : null,
              ),
              sub: light
                  ? context.l10n.mushafPaperSub
                  : context.l10n.msPaperLight,
            ),
          full(
            context.l10n.theme,
            choices(
              [
                ('light', context.l10n.themeLight),
                ('mono', context.l10n.themeMono),
                ('night', context.l10n.themeNight),
                ('oled', context.l10n.themeOled),
              ],
              s.appTheme,
              (v) => s.update(() => s.appTheme = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.msNote,
        style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
      ),
    ];
  }
}
