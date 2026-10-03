// All 13 prototype screens built from kb_components.dart, with the prototype's demo data.
// Use these as the reference implementation: replace the demo data with your real
// models/state, keep the layout, spacing and components as they are.
// Spacing values are the CSS margin-top / gap values from Kids Backdrops.dc.html.

import 'package:flutter/material.dart';
import 'kb_components.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';
import 'kb_ui.dart';
import 'kb_widgets.dart';

KbAvatarInfo _av(String id) => kbAvatars.firstWhere((a) => a.id == id);

/// Scrollable page over the backdrop. CSS `padding:58px 20px 130px` on tab screens
/// (58 includes the status bar; 130 clears the nav bar).
class KbPage extends StatelessWidget {
  final double top, bottom;
  final List<Widget> children;
  final CrossAxisAlignment cross;
  const KbPage({super.key, this.top = 58, this.bottom = 130, required this.children, this.cross = CrossAxisAlignment.start});
  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, top > safeTop + 8 ? top : safeTop + 8, 20, bottom),
      child: Column(crossAxisAlignment: cross, children: children),
    );
  }
}

/// Fixed-height game page (bingo, ttt, memory, lesson, write): content fills the screen height.
class KbFullPage extends StatelessWidget {
  final EdgeInsets padding;
  final List<Widget> children;
  final CrossAxisAlignment cross;
  const KbFullPage({super.key, required this.padding, required this.children, this.cross = CrossAxisAlignment.center});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: SizedBox(
            height: c.maxHeight < 700 ? 700 : c.maxHeight, // designed for 844; scrolls on very short screens
            child: Padding(padding: padding, child: Column(crossAxisAlignment: cross, children: children)),
          ),
        ),
      );
}

Widget _gap(double h) => SizedBox(height: h);

Widget _grid(int cols, double gapX, double gapY, List<Widget> items) => LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - gapX * (cols - 1)) / cols;
      return Wrap(spacing: gapX, runSpacing: gapY, children: [for (final i in items) SizedBox(width: w, child: i)]);
    });

// ───────────────────────── Home ─────────────────────────

class KbHomeScreen extends StatelessWidget {
  final KbUi ui;
  const KbHomeScreen({super.key, required this.ui});
  @override
  Widget build(BuildContext context) => KbPage(children: [
        KbHeading('Keep going!', ui: ui, fontSize: 30),
        _gap(14),
        KbNextCard(ui: ui, glyph: 'تـ', title: 'Next: Tā’', progress: .06),
        _gap(30),
        KbHeading('Joining Shapes', ui: ui, fontSize: 25),
        _gap(14),
        KbLessonPath(ui: ui, nodes: const [('مـ', KbNodeState.done), ('ـسـ', KbNodeState.done), ('ـسم', KbNodeState.current), ('نـ', KbNodeState.locked), ('ـنـ', KbNodeState.locked)]),
        _gap(22),
        Center(child: KbPill('See the whole path', ui: ui)),
        _gap(28),
        KbHeading('Practice', ui: ui, fontSize: 25),
        _gap(14),
        KbDeepCard(ui: ui, icon: 'wb_twilight', title: 'Warm-up', subtitle: '7 to practise again'),
      ]);
}

// ───────────────────────── Learn / Your Path ─────────────────────────

class KbLearnScreen extends StatelessWidget {
  final KbUi ui;
  const KbLearnScreen({super.key, required this.ui});
  @override
  Widget build(BuildContext context) {
    final items = [
      KbLearnCard(ui: ui, glyph: 'ا ب', title: 'The Letters', desc: 'See each letter, then trace it', count: 16, total: 35),
      KbLearnCard(ui: ui, glyph: 'radio_button_checked', glyphIsIcon: true, title: 'Letters Quiz', desc: 'Show what you know', count: 0, total: 1),
      KbLearnCard(ui: ui, glyph: 'ـبـ', title: 'Joining Shapes', desc: 'Start, middle and end — one shape at a time', count: 6, total: 79, current: true),
      KbLearnCard(ui: ui, glyph: 'radio_button_checked', glyphIsIcon: true, title: 'Shapes Quiz', desc: 'Show what you know', count: 0, total: 1),
      KbLearnCard(ui: ui, glyph: 'بيت', title: 'Join the letters', desc: 'Drag letters together to make real words', done: true),
    ];
    return KbPage(cross: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        KbHeading('Your Path', ui: ui, fontSize: 30),
        Text('مَسارُك', textDirection: TextDirection.rtl, style: kbText(26, kbC(ui.headInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.6, shadows: ui.subShadows)),
      ]),
      for (final c in items) ...[_gap(16), c],
    ]);
  }
}

// ───────────────────────── Rank ─────────────────────────

class KbRankScreen extends StatelessWidget {
  final KbUi ui;
  const KbRankScreen({super.key, required this.ui});
  @override
  Widget build(BuildContext context) => KbPage(cross: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: KbHeading('Rank', ui: ui, fontSize: 30)),
        _gap(12),
        KbSubtitle('See how your family is doing this week', ui: ui, fontSize: 18),
        _gap(26),
        KbRankRow(ui: ui, rank: 1, avatar: _av('camel'), name: 'You', level: 'Level 12', xp: '1110 XP', me: true),
        _gap(12),
        KbRankRow(ui: ui, rank: 2, avatar: _av('koala'), name: 'walla', level: 'Level 1', xp: '30 XP'),
      ]);
}

// ───────────────────────── Rewards (badges + shop) ─────────────────────────

class KbRewardsScreen extends StatefulWidget {
  final KbUi ui;
  final String currentThemeId;
  final ValueChanged<String> onApplyTheme;
  const KbRewardsScreen({super.key, required this.ui, required this.currentThemeId, required this.onApplyTheme});
  @override
  State<KbRewardsScreen> createState() => _KbRewardsScreenState();
}

class _KbRewardsScreenState extends State<KbRewardsScreen> {
  final owned = <String>{};
  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    const badges = [('🌱', 'First Letter', true), ('🚀', 'Halfway There', false), ('🔗', 'Joining Forms', false), ('⭐', '5 Letters', true), ('👑', 'Alphabet Master', false), ('✨', 'Special Shapes', false), ('📗', '10 Letters', true), ('✍️', 'Steady Hand', false), ('🎵', 'Vowel Marks', false)];
    return KbPage(cross: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [KbHeading('Rewards', ui: ui, fontSize: 30), KbGemCounter(105, ui: ui)]),
      _gap(22),
      Align(alignment: Alignment.centerLeft, child: KbHeading('Badges', ui: ui, fontSize: 23)),
      _gap(14),
      _grid(3, 12, 12, [for (final b in badges) KbBadgeTile(ui: ui, emoji: b.$1, label: b.$2, earned: b.$3)]),
      _gap(28),
      Align(alignment: Alignment.centerLeft, child: KbHeading('Shop', ui: ui, fontSize: 23)),
      _gap(10),
      KbSubtitle('Themes', ui: ui),
      _gap(10),
      _grid(3, 12, 12, [
        for (final t in kbThemes)
          KbThemeShopTile(
            theme: t, ui: ui, owned: t.price == 0 || owned.contains(t.id), inUse: t.id == widget.currentThemeId,
            onTap: () => (t.price == 0 || owned.contains(t.id)) ? widget.onApplyTheme(t.id) : setState(() => owned.add(t.id)),
          ),
      ]),
      _gap(20),
      KbSubtitle('Looks', ui: ui),
      _gap(10),
      KbLooksRow(ui: ui, avatar: _av('camel'), owned: true),
      _gap(14),
      KbLooksRow(ui: ui, avatar: _av('bee'), owned: false),
    ]);
  }
}

// ───────────────────────── Me ─────────────────────────

class KbMeScreen extends StatelessWidget {
  final KbUi ui;
  final ValueChanged<KbMode> onMode;
  final ValueChanged<KbStyle> onStyle;
  final String textSize;
  final ValueChanged<String> onTextSize;
  const KbMeScreen({super.key, required this.ui, required this.onMode, required this.onStyle, this.textSize = 'large', required this.onTextSize});
  @override
  Widget build(BuildContext context) {
    const modes = [(KbMode.light, 'light_mode', 'Light'), (KbMode.dark, 'dark_mode', 'Dark'), (KbMode.oled, 'bedtime', 'OLED')];
    const sizes = [('small', 'Small', 20.0), ('medium', 'Medium', 28.0), ('large', 'Large', 38.0)];
    return KbPage(top: 50, cross: CrossAxisAlignment.stretch, children: [
      Center(child: KbSurface(color: ui.surface, edge: ui.edge, elev: KbElev.cardHi, circle: true, width: 112, height: 112, alignment: Alignment.center, child: Image.asset(_av('camel').asset, width: 96, height: 96))),
      _gap(14),
      Center(child: KbHeading('Wazzup', ui: ui, fontSize: 32)),
      _gap(6),
      Center(child: KbSubtitle('Level 12', ui: ui)),
      _gap(20),
      _grid(3, 12, 12, [KbStatTile(ui: ui, value: '1110', label: 'Total XP'), KbStatTile(ui: ui, value: '1', label: 'Streak'), KbStatTile(ui: ui, value: '13/28', label: 'Letters')]),
      _gap(24),
      Align(alignment: Alignment.centerLeft, child: KbHeading('Appearance', ui: ui, fontSize: 21)),
      _gap(12),
      _grid(3, 12, 12, [
        for (final m in modes)
          KbOptionTile(ui: ui, selected: ui.mode == m.$1, label: m.$3, onTap: () => onMode(m.$1), top: KbIcon(m.$2, size: 28, color: KbOptionTile.inkOf(ui, ui.mode == m.$1))),
      ]),
      _gap(24),
      Align(alignment: Alignment.centerLeft, child: KbHeading('Text size', ui: ui, fontSize: 21)),
      _gap(12),
      _grid(3, 12, 12, [
        for (final s in sizes)
          KbOptionTile(ui: ui, selected: textSize == s.$1, label: s.$2, minHeight: 92, padding: const EdgeInsets.fromLTRB(6, 10, 6, 8), onTap: () => onTextSize(s.$1),
              top: Text('A', style: kbText(s.$3, KbOptionTile.inkOf(ui, textSize == s.$1), height: 1))),
      ]),
      _gap(24),
      KbSettingCard(ui: ui, title: 'High detail', desc: 'Fancier backgrounds and a bigger finish screen. Turn off for a plainer, faster look.',
          trailing: KbToggle(value: ui.vivid, ui: ui, onChanged: (v) => onStyle(v ? KbStyle.vivid : KbStyle.original))),
    ]);
  }
}

// ───────────────────────── New Profile ─────────────────────────

class KbProfileScreen extends StatefulWidget {
  final KbUi ui;
  const KbProfileScreen({super.key, required this.ui});
  @override
  State<KbProfileScreen> createState() => _KbProfileScreenState();
}

class _KbProfileScreenState extends State<KbProfileScreen> {
  String avatar = 'fox', gender = 'skip', name = '';
  final owned = <String>{};
  bool locked(KbAvatarInfo a) => a.price > 0 && !owned.contains(a.id);
  @override
  Widget build(BuildContext context) {
    final ui = widget.ui, cur = _av(avatar), curLocked = locked(cur), canStart = name.trim().isNotEmpty && !curLocked;
    return KbPage(top: 52, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft, child: KbHeading('New Profile', ui: ui, fontSize: 30)),
      _gap(22),
      Row(children: [
        KbSurface(color: ui.surface, edge: ui.edge, elev: KbElev.big, circle: true, width: 128, height: 128, alignment: Alignment.center, child: Image.asset(cur.asset, width: 108, height: 108)),
        const SizedBox(width: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cur.name, style: kbText(24, kbC(ui.headInk), height: 1.1, shadows: ui.headShadows)),
          if (curLocked) ...[
            _gap(8),
            KbPill('Get for ${cur.price}', ui: ui, kind: KbPillKind.deep, icon: 'diamond', iconSize: 20, padding: const EdgeInsets.fromLTRB(14, 8, 18, 6), onTap: () => setState(() => owned.add(cur.id))),
          ],
        ]),
      ]),
      _gap(24),
      _grid(6, 8, 10, [
        for (final a in kbAvatars) KbAvatarPickerTile(avatar: a, ui: ui, selected: a.id == avatar, locked: locked(a), onTap: () => setState(() => avatar = a.id)),
      ]),
      _gap(24),
      KbTextField(ui: ui, hint: "What's your name?", onChanged: (v) => setState(() => name = v)),
      _gap(18),
      KbSubtitle('This helps us cheer you on correctly!', ui: ui, fontSize: 18),
      _gap(12),
      Wrap(spacing: 10, children: [
        for (final g in const [('boy', 'Boy'), ('girl', 'Girl'), ('skip', 'Skip')]) KbChoiceChip(g.$2, ui: ui, selected: gender == g.$1, onTap: () => setState(() => gender = g.$1)),
      ]),
      _gap(28),
      KbBigButton('Start Learning', ui: ui, enabled: canStart),
      _gap(18),
      Center(child: KbPill('Cancel', ui: ui, elev: KbElev.edge4, padding: const EdgeInsets.fromLTRB(20, 7, 20, 5))),
    ]);
  }
}

// ───────────────────────── Lesson step ─────────────────────────

class KbLessonScreen extends StatelessWidget {
  final KbUi ui;
  const KbLessonScreen({super.key, required this.ui});
  @override
  Widget build(BuildContext context) {
    Widget letterCard(String g, double size) => Expanded(
          child: AspectRatio(aspectRatio: 1, child: KbSurface(color: ui.surface, edge: ui.edge, elev: KbElev.big, radius: 28, alignment: Alignment.center,
              child: Text(g, textDirection: TextDirection.rtl, style: kbText(size, kbC(ui.ink), family: kbFontArabic, weight: FontWeight.w600, height: 1.3)))),
        );
    return KbFullPage(padding: const EdgeInsets.fromLTRB(20, 50, 20, 36), cross: CrossAxisAlignment.stretch, children: [
      Row(children: [KbRoundButton('arrow_back', ui: ui), const SizedBox(width: 16), KbSubtitle('Step 1 of 7', ui: ui)]),
      _gap(22),
      Text('Wāw never joins to the letter after it', style: kbText(29, kbC(ui.headInk), height: 1.25, shadows: ui.headShadows)),
      Expanded(child: Row(children: [
        letterCard('و', 110),
        const SizedBox(width: 10),
        KbSurface(color: ui.surface, edge: ui.edge, elev: KbElev.edge3, circle: true, width: 34, height: 34, alignment: Alignment.center, child: KbIcon('arrow_forward', size: 22, color: kbC(ui.ink))),
        const SizedBox(width: 10),
        letterCard('ـو', 72),
      ])),
      Center(child: KbPill('Listen', ui: ui, icon: 'volume_up', fontSize: 20, iconSize: 24, padding: const EdgeInsets.fromLTRB(24, 10, 24, 8))),
      _gap(24),
      KbBigButton('Next', ui: ui, highlight: true, fontSize: 22),
    ]);
  }
}

// ───────────────────────── Write ─────────────────────────

class KbWriteScreen extends StatefulWidget {
  final KbUi ui;
  const KbWriteScreen({super.key, required this.ui});
  @override
  State<KbWriteScreen> createState() => _KbWriteScreenState();
}

class _KbWriteScreenState extends State<KbWriteScreen> {
  final strokes = <List<Offset>>[];
  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    return KbFullPage(padding: const EdgeInsets.fromLTRB(20, 54, 20, 30), children: [
      KbSubtitle('Step 1 of 5', ui: ui),
      _gap(10),
      Align(alignment: Alignment.centerLeft, child: KbHeading('Write Tā’ from memory', ui: ui, fontSize: 29)),
      Expanded(child: Center(
        child: KbSurface(
          color: ui.surface, edge: ui.edge, elev: KbElev.board, radius: 30, width: 350, height: 350, alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onPanStart: (d) => setState(() => strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => strokes.last.add(d.localPosition)),
              child: CustomPaint(size: const Size(310, 310), painter: _WritePainter(strokes, ui.dot, kbC(ui.th.accent2))),
            ),
          ),
        ),
      )),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        KbPill('Clear', ui: ui, icon: 'refresh', fontSize: 20, iconSize: 22, elev: KbElev.edge5, padding: const EdgeInsets.fromLTRB(28, 11, 28, 9), onTap: () => setState(strokes.clear)),
        const SizedBox(width: 14),
        KbPill('Check', ui: ui, icon: 'check', kind: KbPillKind.deep, fontSize: 20, iconSize: 22, elev: KbElev.edge5, padding: const EdgeInsets.fromLTRB(32, 11, 32, 9)),
      ]),
      _gap(14),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 3, 14, 1),
        decoration: BoxDecoration(color: kbC(ui.surface), borderRadius: BorderRadius.circular(999)),
        child: Text('${strokes.length.clamp(0, 2)}/2 strokes · 0/2 dots', style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Dot grid: CSS `radial-gradient(dot 1.5px, transparent 1.5px); background-size:22px 22px`. Ink: accent2, width 16, round.
class _WritePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color dot, ink;
  _WritePainter(this.strokes, this.dot, this.ink);
  @override
  void paint(Canvas c, Size s) {
    final d = Paint()..color = dot;
    for (double y = 11; y < s.height; y += 22) {
      for (double x = 11; x < s.width; x += 22) {
        c.drawCircle(Offset(x, y), 1.5, d);
      }
    }
    final p = Paint()..color = ink..strokeWidth = 16..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (final st in strokes) {
      final path = Path()..moveTo(st.first.dx, st.first.dy);
      for (final o in st.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      if (st.length == 1) path.lineTo(st.first.dx + .1, st.first.dy);
      c.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(_WritePainter o) => true;
}

// ───────────────────────── Games ─────────────────────────

class KbBingoScreen extends StatefulWidget {
  final KbUi ui;
  const KbBingoScreen({super.key, required this.ui});
  @override
  State<KbBingoScreen> createState() => _KbBingoScreenState();
}

class _KbBingoScreenState extends State<KbBingoScreen> {
  static const letters = ['خ', 'ب', 'ح', 'ذ', 'ث', 'ت', 'ج', 'ز', 'ش', 'س', 'ر', 'ا', 'د', 'خ', 'ب', 'ح'];
  final picked = <int>{5};
  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    return KbFullPage(padding: const EdgeInsets.fromLTRB(20, 200, 20, 40), children: [
      KbHeading('Letter Bingo', ui: ui, fontSize: 32),
      _gap(10),
      KbSubtitle('Listen for the letter, then tap it', ui: ui),
      _gap(16),
      KbPill('Listen', ui: ui, icon: 'volume_up', fontSize: 20, iconSize: 24),
      _gap(22),
      _grid(4, 12, 12, [
        for (var i = 0; i < letters.length; i++)
          KbGlyphCell(ui: ui, glyph: letters[i], state: picked.contains(i) ? KbCellState.selected : KbCellState.idle,
              onTap: () => setState(() => picked.contains(i) ? picked.remove(i) : picked.add(i))),
      ]),
    ]);
  }
}

class KbTttScreen extends StatelessWidget {
  final KbUi ui;
  const KbTttScreen({super.key, required this.ui});
  static const letters = ['س', 'ز', 'ش', 'ت', 'ا', 'ج', 'ح', 'ب', 'ث'];
  static const marks = {4: KbCellState.mine, 0: KbCellState.cpu};
  @override
  Widget build(BuildContext context) => KbFullPage(padding: const EdgeInsets.fromLTRB(20, 210, 20, 40), children: [
        KbHeading('Three in a Row', ui: ui, fontSize: 32),
        _gap(10),
        KbSubtitle('Your turn — tap a square', ui: ui),
        _gap(24),
        _grid(3, 14, 14, [
          for (var i = 0; i < 9; i++) KbGlyphCell(ui: ui, glyph: letters[i], state: marks[i] ?? KbCellState.idle, radius: 24, fontSize: 46, elev: KbElev.game),
        ]),
      ]);
}

class KbMemoryScreen extends StatelessWidget {
  final KbUi ui;
  const KbMemoryScreen({super.key, required this.ui});
  static const cards = ['ب', 'Bā’', 'ج', 'Jīm', 'ث', 'ت', 'Tā’', 'Thā’', 'ح', 'Ḥā’', 'خ', 'Khā’'];
  static const states = {4: KbCellState.good, 5: KbCellState.bad, 7: KbCellState.good};
  @override
  Widget build(BuildContext context) => KbFullPage(padding: const EdgeInsets.fromLTRB(20, 150, 20, 40), children: [
        KbHeading('Memory Match', ui: ui, fontSize: 32),
        _gap(10),
        KbSubtitle('Flip two cards — find the letter and its name', ui: ui, align: TextAlign.center),
        _gap(22),
        _grid(3, 14, 14, [
          for (var i = 0; i < cards.length; i++)
            () {
              final latin = RegExp(r'[a-z]', caseSensitive: false).hasMatch(cards[i]);
              final st = states[i];
              return KbGlyphCell(
                ui: ui, glyph: cards[i], state: st ?? KbCellState.idle, faceDown: st == null, radius: 22, elev: KbElev.game,
                family: latin ? kbFontUi : kbFontArabic, fontSize: latin ? 24 : 44, weight: latin ? FontWeight.w800 : FontWeight.w600,
              );
            }(),
        ]),
      ]);
}

class KbQuizScreen extends StatefulWidget {
  final KbUi ui;
  const KbQuizScreen({super.key, required this.ui});
  @override
  State<KbQuizScreen> createState() => _KbQuizScreenState();
}

class _KbQuizScreenState extends State<KbQuizScreen> {
  static const options = ['ف', 'ق', 'ـفـ', 'ـخ', 'خـ'];
  static const correct = 1;
  int? pick;
  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    KbCellState stateOf(int i) => pick == null ? KbCellState.idle : i == correct ? KbCellState.good : i == pick ? KbCellState.bad : KbCellState.idle;
    return KbPage(top: 50, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
      Row(children: [
        KbRoundButton('arrow_back', ui: ui),
        const SizedBox(width: 14),
        Expanded(child: Text('Warm-up', style: kbText(24, kbC(ui.headInk), shadows: ui.headShadows))),
        KbSubtitle('Question 1 of 7', ui: ui, fontSize: 17),
      ]),
      _gap(20),
      KbFramedProgress(value: .14, ui: ui),
      _gap(22),
      Text('You missed this before — what is it?', textAlign: TextAlign.center, style: kbText(22, kbC(ui.subInk), weight: FontWeight.w700, height: 1.3, shadows: ui.subShadows)),
      _gap(18),
      Center(child: KbSurface(color: ui.surface, edge: ui.edge, elev: KbElev.big, radius: 28, padding: const EdgeInsets.fromLTRB(40, 10, 40, 0),
          child: Text('قَالُوٓا۟', textDirection: TextDirection.rtl, style: kbText(84, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9)))),
      _gap(26),
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) _gap(12),
        KbGlyphCell(ui: ui, glyph: options[i], state: stateOf(i), height: 64, fontSize: 34, elev: KbElev.option,
            faceDown: false, onTap: () => setState(() => pick = pick == i ? null : i)),
      ],
    ]);
  }
}

// ───────────────────────── Hamzah card ─────────────────────────

class KbHamzahScreen extends StatelessWidget {
  final KbUi ui;
  const KbHamzahScreen({super.key, required this.ui});
  @override
  Widget build(BuildContext context) => KbPage(top: 96, bottom: 40, cross: CrossAxisAlignment.stretch, children: [
        KbSurface(
          color: ui.surface, edge: ui.edge, elev: KbElev.hero, radius: 32, padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
          child: Column(children: [
            KbGlyphTile('ئ', bg: ui.tile, ink: ui.tileInk, size: 110, radius: 30, fontSize: 66),
            _gap(18),
            Text('Hamzah on Yā’', style: kbText(30, kbC(ui.ink))),
            _gap(4),
            Text('Hamzah sits on a Yā’ with no dots.', textAlign: TextAlign.center, style: kbText(19, kbC(ui.inkSoft), weight: FontWeight.w600)),
            _gap(14),
            for (final w in const ['شِئْتُمْ', 'أُو۟لَـٰٓئِكَ', 'وَأُو۟لَـٰٓئِكَ']) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: kbC(ui.wordBg), borderRadius: BorderRadius.circular(22)),
                child: Column(children: [
                  Text(w, textDirection: TextDirection.rtl, style: kbText(38, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    KbPill('Listen', ui: ui, kind: KbPillKind.deep, icon: 'play_arrow', fontSize: 16, iconSize: 20, elev: KbElev.edge3, padding: const EdgeInsets.fromLTRB(12, 6, 16, 4)),
                    const SizedBox(width: 10),
                    KbPill('Watch', ui: ui, icon: 'play_circle', fontSize: 16, iconSize: 20, elev: KbElev.edge3, padding: const EdgeInsets.fromLTRB(12, 6, 16, 4)),
                  ]),
                ]),
              ),
            ],
          ]),
        ),
      ]);
}

// ───────────────────────── Gallery (debug) ─────────────────────────

/// Debug screen that mirrors the prototype's control panel. Run it on a 390-wide simulator
/// next to Kids Backdrops.dc.html in Chrome and compare screen by screen.
/// Long-press anywhere to open the switcher.
class KbGallery extends StatefulWidget {
  const KbGallery({super.key});
  @override
  State<KbGallery> createState() => _KbGalleryState();
}

class _KbGalleryState extends State<KbGallery> {
  String themeId = 'sunset', screen = 'home', textSize = 'large';
  KbMode mode = KbMode.light;
  KbStyle style = KbStyle.vivid;
  static const screens = ['home', 'learn', 'rank', 'rewards', 'me', 'profile', 'lesson', 'write', 'bingo', 'ttt', 'memory', 'quiz', 'hamzah'];

  @override
  Widget build(BuildContext context) {
    final th = kbThemes.firstWhere((t) => t.id == themeId);
    final ui = KbUi(th, mode, style);
    final page = switch (screen) {
      'home' => KbHomeScreen(ui: ui),
      'learn' => KbLearnScreen(ui: ui),
      'rank' => KbRankScreen(ui: ui),
      'rewards' => KbRewardsScreen(ui: ui, currentThemeId: themeId, onApplyTheme: (id) => setState(() => themeId = id)),
      'me' => KbMeScreen(ui: ui, textSize: textSize, onMode: (m) => setState(() => mode = m), onStyle: (s) => setState(() => style = s), onTextSize: (s) => setState(() => textSize = s)),
      'profile' => KbProfileScreen(ui: ui),
      'lesson' => KbLessonScreen(ui: ui),
      'write' => KbWriteScreen(ui: ui),
      'bingo' => KbBingoScreen(ui: ui),
      'ttt' => KbTttScreen(ui: ui),
      'memory' => KbMemoryScreen(ui: ui),
      'quiz' => KbQuizScreen(ui: ui),
      _ => KbHamzahScreen(ui: ui),
    };
    final tab = kbNavItems.any((n) => n.id == screen);
    return Material(
      color: kbC(kBlack),
      child: GestureDetector(
        onLongPress: () => _switcher(context),
        child: KbBackdrop(
          theme: th, mode: mode, style: style,
          child: Stack(children: [
            Positioned.fill(child: page),
            if (tab) Positioned(left: 0, right: 0, bottom: 0, child: KbNavBar(ui: ui, current: screen, onSelect: (s) => setState(() => screen = s))),
          ]),
        ),
      ),
    );
  }

  void _switcher(BuildContext context) => showModalBottomSheet(
        context: context,
        builder: (_) => StatefulBuilder(builder: (context, set) {
          void up(VoidCallback f) { setState(f); set(() {}); }
          Widget row(List<String> items, String cur, void Function(String) on) => Wrap(spacing: 6, runSpacing: 6, children: [
                for (final i in items) ChoiceChip(label: Text(i), selected: i == cur, onSelected: (_) => up(() => on(i))),
              ]);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              row(screens, screen, (v) => screen = v), const Divider(),
              row([for (final t in kbThemes) t.id], themeId, (v) => themeId = v), const Divider(),
              row(['light', 'dark', 'oled'], mode.name, (v) => mode = KbMode.values.byName(v)),
              const SizedBox(height: 6),
              row(['vivid', 'original'], style.name, (v) => style = KbStyle.values.byName(v)),
            ]),
          );
        }),
      );
}
