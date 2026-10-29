import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart';
import '../../core/fluency/joins.dart';
import '../../core/fluency/madd.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/fluency_tiers.dart';
import '../../data/mushaf.dart';
import '../../ui/kit.dart';

/// The fluency plan's "count and say" (D3), its timing block: a word the
/// reader already reads easily, with a madd in it — they say its count
/// ("this one is two"), then read it; the count and the madd's letter are
/// shown after.
class MaddScreen extends StatefulWidget with DesktopAware {
  const MaddScreen({super.key});

  @override
  State<MaddScreen> createState() => _MaddScreenState();
}

/// Words for the drill: the reader's own read at once first, then the
/// common words; each with a madd (the long ones first), at most [limit].
List<(String, Madd)> maddWords(FluencyStore store, String script, {int limit = 15}) {
  final forms = <String>{
    for (final m in store.marksOf(FluencyKind.word))
      if (store.progressOf(m.cardId)?.last == Recall.instant) m.form,
    for (final w in tierWords(script))
      if (w.words == 1) w.form,
  };
  final out = <(String, Madd)>[];
  for (final f in forms) {
    final ms = maddsIn(f);
    if (ms.isEmpty) continue;
    final long = ms.where((m) => m.kind != 'natural');
    out.add((f, long.isNotEmpty ? long.first : ms.first));
  }
  out.sort((a, b) => (a.$2.kind == 'natural' ? 1 : 0).compareTo(b.$2.kind == 'natural' ? 1 : 0));
  return out.take(limit).toList();
}

class _MaddScreenState extends State<MaddScreen> {
  List<(String, Madd)>? _words;
  int _at = 0;
  bool _shown = false;

  String get _script => SettingsScope.of(context).mushafScript;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words != null) return;
    final store = FluencyScope.read(context);
    MushafRepo.ensure(_script).then((_) {
      if (mounted && store != null) setState(() => _words = maddWords(store, _script));
    });
  }

  String _kind(BuildContext context, String k) => switch (k) {
        'lazim' => context.l10n.mdNecessary,
        'muttasil' => context.l10n.mdConnected,
        'munfasil' => context.l10n.mdSeparate,
        _ => context.l10n.mdNatural,
      };

  void _next() {
    setState(() {
      _at++;
      _shown = false;
    });
    if (_at >= (_words?.length ?? 0)) FluencyScope.read(context)?.blockDone('timing');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final ws = _words;
    return Scaffold(
      appBar: AppBar(title: Text(l.mdTitle)),
      body: SafeArea(
        child: ws == null
            ? Center(child: CircularProgressIndicator(color: p.acc))
            : _at >= ws.length
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ws.isEmpty ? l.flDeckEmpty : l.flDeckDone,
                          textAlign: TextAlign.center, style: displayStyle(context, size: 22)),
                      const SizedBox(height: 20),
                      QPrimaryButton(l.rvDone, onTap: () => Navigator.maybePop(context)),
                    ]),
                  )
                : QColumn(child: _card(context, ws[_at])),
      ),
    );
  }

  Widget _card(BuildContext context, (String, Madd) w) {
    final l = context.l10n;
    final p = pal(context);
    final (form, madd) = w;
    final big = TextStyle(
        fontFamily: MushafRepo.fontFamily(_script), fontSize: 72, height: 1.9, color: p.ink);
    final cs = clustersOf(form);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text(l.flDeckAt(_at + 1, _words!.length), style: uiStyle(context, size: 13, color: p.ink3)),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                child: Text.rich(
                  TextSpan(children: [
                    for (final (i, c) in cs.indexed)
                      TextSpan(
                          text: '${c.base}${c.marks}',
                          style: _shown && i == madd.at ? big.copyWith(color: p.acc) : big),
                  ]),
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (_shown) ...[
                Text(l.mdCounts(madd.counts), style: displayStyle(context, size: 26, color: p.acc)),
                Text(_kind(context, madd.kind), style: uiStyle(context, size: 14, color: p.ink3)),
              ],
            ]),
          ),
        ),
        Text(l.mdSay, textAlign: TextAlign.center, style: uiStyle(context, size: 13, color: p.ink3)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _shown
              ? QPrimaryButton(l.flNext, onTap: _next)
              : QOutlineButton(l.mdShow, onTap: () => setState(() => _shown = true)),
        ),
      ]),
    );
  }
}
