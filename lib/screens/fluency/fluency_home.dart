import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/fluency_tiers.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../core/fluency/plan.dart';
import 'cold_read_screen.dart';
import 'deck_screen.dart';
import 'tracker_screen.dart';
import 'madd_screen.dart';
import 'passage_screen.dart';

/// The Reader's fluency practice, after the plan for adult readers: the
/// warm-up of words to read at once, the reader's own marks (not fluent,
/// pairs, chunks) and the plan's word lists.
class FluencyHome extends StatefulWidget with DesktopAware {
  const FluencyHome({super.key});

  @override
  State<FluencyHome> createState() => _FluencyHomeState();
}

class _FluencyHomeState extends State<FluencyHome> {
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    MushafRepo.ensure(SettingsScope.of(context).mushafScript).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _open(Deck deck, String title, {String? block}) =>
      pushAdaptive(context, DeckScreen(deck: deck, title: title, block: block));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final store = FluencyScope.maybeOf(context);
    final script = SettingsScope.of(context).mushafScript;
    if (store == null || !_ready) {
      return Scaffold(
          appBar: AppBar(title: Text(l.flHome)),
          body: Center(child: CircularProgressIndicator(color: p.acc)));
    }
    int due(Deck d) => deckCards(context, store, script, d, limit: 1 << 30).length;
    final tiers = tierWords(script);
    String tierLine(int t) {
      final ws = tiers.where((w) => w.tier == t).toList();
      final instant = ws.where((w) => store.progressOf(w.cardId)?.retired ?? false).length;
      return l.flTierProgress(instant, ws.length);
    }

    Widget row(IconData icon, String title, String sub, VoidCallback onTap) => QRow(
          leading: Icon(icon, color: p.acc),
          title: title,
          subtitle: sub,
          chevron: true,
          onTap: onTap,
        );
    void passage() {
      // From the last āyah read (else the start of al-Baqarah).
      final last = ProgressScope.read(context).lastRead;
      final g = last == null ? 7 : MushafRepo.globalAyahOf(last.$1, last.$2);
      final (a, b) = passageFrom(script, g);
      openPassage(context, a, b);
    }

    void coldRead() => pushAdaptive(context, const ColdReadScreen());
    void tracker() => pushAdaptive(context, const TrackerScreen());
    return Scaffold(
      appBar: AppBar(title: Text(l.flHome)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            QColumn(child: _PlanCard(store: store, script: script, onStart: () {
              store.startPlan();
              coldRead();
            })),
            if (store.planStart != null) ...[
              QColumn(child: QSectionLabel(l.plToday)),
              QColumn(
                child: QGroup(children: [
                  for (final (id, icon, name, open) in [
                    ('warmup', AppIcons.bolt, l.plBlockWarmup,
                        () => _open(Deck.warmup, l.flWarmup, block: 'warmup')),
                    ('pairs', AppIcons.link, l.plBlockChunks,
                        () => _open(Deck.pairs, l.flPairs, block: 'pairs')),
                    ('buildup', AppIcons.recite, l.plBlockBuildup, passage),
                    ('timing', AppIcons.timer, l.plBlockTiming,
                        () => pushAdaptive(context, const MaddScreen())),
                    ('cold', AppIcons.mic, l.plBlockCold, coldRead),
                    ('wrapup', AppIcons.chart, l.plBlockWrapup, tracker),
                  ])
                    QRow(
                      leading: Icon(
                          store.blocksDoneToday.contains(id) ||
                                  (id == 'pairs' && store.blocksDoneToday.contains('chunks'))
                              ? AppIcons.check
                              : icon,
                          color: p.acc),
                      title: name,
                      chevron: true,
                      onTap: open,
                    ),
                ]),
              ),
              QColumn(child: _HomePractice(week: store.week)),
            ],
            QColumn(child: QSectionLabel(l.flWarmup)),
            QColumn(
              child: QHeroCard(
                padding: const EdgeInsets.all(18),
                onTap: () => _open(Deck.warmup, l.flWarmup, block: 'warmup'),
                child: Row(children: [
                  const Icon(AppIcons.bolt, color: kHeroInk, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.flWarmup, style: displayStyle(context, size: 20, color: kHeroInk)),
                      Text(l.flWarmupSub(due(Deck.warmup)),
                          style: uiStyle(context, size: 13, color: kHeroInk.withValues(alpha: .8))),
                    ]),
                  ),
                ]),
              ),
            ),
            QColumn(child: QSectionLabel(l.flYourMarks)),
            QColumn(
              child: QGroup(children: [
                row(AppIcons.bolt, l.flSlow, l.flDue(due(Deck.words)),
                    () => _open(Deck.words, l.flSlow)),
                row(AppIcons.link, l.flPairs, l.flDue(due(Deck.pairs)),
                    () => _open(Deck.pairs, l.flPairs, block: 'pairs')),
                row(AppIcons.shapeJoin, l.flChunks, l.flDue(due(Deck.chunks)),
                    () => _open(Deck.chunks, l.flChunks, block: 'chunks')),
              ]),
            ),
            QColumn(child: QSectionLabel(l.flPassages)),
            QColumn(
              child: QGroup(children: [
                row(AppIcons.recite, l.psPractisePassage, l.psPractisePassageSub, passage),
                row(AppIcons.timer, l.mdTitle, l.mdSub,
                    () => pushAdaptive(context, const MaddScreen())),
              ]),
            ),
            QColumn(child: QSectionLabel(l.plMeasure)),
            QColumn(
              child: QGroup(children: [
                row(AppIcons.mic, l.crTitle, l.crSub, coldRead),
                row(AppIcons.chart, l.tkTitle, l.tkSub, tracker),
              ]),
            ),
            QColumn(child: QSectionLabel(l.flWordLists)),
            QColumn(
              child: QGroup(children: [
                for (final (t, deck, name) in [
                  (1, Deck.tier1, l.flTier1),
                  (2, Deck.tier2, l.flTier2),
                  (3, Deck.tier3, l.flTier3),
                ])
                  row(AppIcons.cards, name, tierLine(t), () => _open(deck, name)),
              ]),
            ),
            if (store.planStart != null) ...[
              QColumn(child: QSectionLabel(l.plSupports)),
              QColumn(child: _Supports(week: store.week)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Reader home's way in: the warm-up waiting.
class FluencyEntryCard extends StatelessWidget {
  const FluencyEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FluencyScope.maybeOf(context);
    if (store == null) return const SizedBox.shrink();
    final l = context.l10n;
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QCard(
        padding: const EdgeInsets.all(14),
        onTap: () => pushAdaptive(context, const FluencyHome()),
        child: Row(children: [
          Icon(AppIcons.bolt, color: p.acc, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.flHome, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              Text(l.flHomeSub, style: uiStyle(context, size: 12.5, color: p.ink3)),
            ]),
          ),
          Icon(AppIcons.chevronRight, color: p.ink3),
        ]),
      ),
    );
  }
}

/// The 12-week plan: not started (what the baseline is, and a start), or
/// its week and phase, what the phase works on, and its checks before
/// moving on.
class _PlanCard extends StatelessWidget {
  final FluencyStore store;
  final String script;
  final VoidCallback onStart;
  const _PlanCard({required this.store, required this.script, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    if (store.planStart == null) {
      return QCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.plTitle, style: displayStyle(context, size: 20)),
          const SizedBox(height: 6),
          Text(l.plIntro, style: uiStyle(context, size: 13.5, color: p.ink2, height: 1.45)),
          const SizedBox(height: 12),
          QPrimaryButton(l.plStart, onTap: onStart),
        ]),
      );
    }
    final week = store.week;
    final phase = phaseOfWeek(week);
    final (name, focus) = switch (phase) {
      PlanPhase.foundation => (l.plFoundation, l.plFoundationFocus),
      PlanPhase.building => (l.plBuilding, l.plBuildingFocus),
      PlanPhase.transfer => (l.plTransfer, l.plTransferFocus),
      PlanPhase.independence => (l.plIndependence, l.plIndependenceFocus),
    };
    String checkName(String id) => switch (id) {
          'tier1' => l.plCheckTier1,
          'stalls' => l.plCheckStalls,
          'tier2' => l.plCheckTier2,
          'perception' => l.plCheckPerception,
          'cold25' => l.plCheckCold,
          _ => l.plCheckThree,
        };
    final reads = store.coldReads;
    // Little progress after six weeks of steady practice: worth a look.
    final refer = week > 6 &&
        reads.length >= 3 &&
        reads.last.perMinute < reads.first.perMinute * 1.1;
    return QCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.plWeek(week.clamp(1, 12), name), style: displayStyle(context, size: 20)),
        const SizedBox(height: 4),
        Text(focus, style: uiStyle(context, size: 13.5, color: p.ink2, height: 1.45)),
        const SizedBox(height: 10),
        Text(l.plMoveOn, style: uiStyle(context, size: 12.5, weight: FontWeight.w700, color: p.ink3)),
        for (final c in checksOf(phase, store, script))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(c.met == true ? AppIcons.check : AppIcons.dot,
                  size: 16, color: c.met == true ? p.acc : p.ink3),
              const SizedBox(width: 8),
              Expanded(child: Text(checkName(c.id), style: uiStyle(context, size: 13.5))),
            ]),
          ),
        if (refer) ...[
          const SizedBox(height: 10),
          Text(l.plRefer, style: uiStyle(context, size: 12.5, color: p.ink3, height: 1.45)),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
              onPressed: () => store.resetPlan(),
              child: Text(l.plRestart, style: uiStyle(context, size: 13, color: p.ink3))),
        ),
      ]),
    );
  }
}

/// The plan's home practice, 10–15 minutes a day.
class _HomePractice extends StatelessWidget {
  final int week;
  const _HomePractice({required this.week});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(context.l10n.plHome,
          style: uiStyle(context, size: 13, color: p.ink3, height: 1.45)),
    );
  }
}

/// The supports, each for its weeks and then faded: tajwīd colours (a
/// switch here), extra spacing, the reading window, hearing it first.
class _Supports extends StatelessWidget {
  final int week;
  const _Supports({required this.week});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = SettingsScope.of(context);
    String when(int until, String after) => week <= until ? l.plNow : after;
    return QGroup(children: [
      QRow(
        title: l.tajwidColors,
        subtitle: when(9, l.plFadeTajwid),
        control: QSwitch(
            value: s.tajwidColors || s.mushafTajwid,
            onChanged: (v) => s.update(() {
                  s.tajwidColors = v;
                  s.mushafTajwid = v;
                  if (v) s.stripTashkil = false;
                })),
      ),
      QRow(title: l.plSpacing, subtitle: when(6, l.plFadeSpacing)),
      QRow(title: l.plWindow, subtitle: when(8, l.plFadeWindow)),
      QRow(title: l.psModeling, subtitle: when(6, week <= 9 ? l.plFadeModel : l.plFadeModelNone)),
    ]);
  }
}
