import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/learning_path.dart';
import '../ui/kit.dart';
import 'shell/app_mode.dart' show SettingsButton;
import 'learning_path_screen.dart';
import '../learn/qaidah/qaidah_home.dart';
import 'shell/modules.dart';

/// Learn: the step-by-step path as a hero card, then every learning module.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final units = courseItems(context);
    final unitsDone = units.where((u) => prog.starsFor(u.progressId) > 0).length;
    final path = learningPath();
    final done = path.where((s) => pathStepDone(prog.starsFor, s)).length;
    final next = nextPathStep(prog, path);
    return Scaffold(
      body: QPage(
        title: context.l10n.navLearn,
        subtitle: context.l10n.learnSubtitle,
        actions: const [SettingsButton()],
        children: [
          QHeroCard(
            padding: const EdgeInsets.all(18),
            onTap: () => Navigator.of(context, rootNavigator: !useDesktop(context))
                .push(MaterialPageRoute(builder: (_) => const LearningPathScreen())),
            child: Row(children: [
              _Ring(done: done, total: path.length),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.l10n.pathTitle.toUpperCase(),
                      style: uiStyle(context,
                          size: 11.5,
                          weight: FontWeight.w700,
                          letterSpacing: 1,
                          color: kHeroInk2)),
                  const SizedBox(height: 4),
                  Text(next < 0 ? context.l10n.pathDone : pathStepTitle(context, path[next]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: displayStyle(context, size: 22, color: kHeroInk)),
                  const SizedBox(height: 3),
                  Text(next < 0 ? context.l10n.pathLead : context.l10n.pathStepOf(next + 1, path.length),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context, size: 13, color: kHeroInk2)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          for (final m in LearnModule.values)
            if (m.shown(context) && !m.reference)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ModuleCard(
                  module: m,
                  tag: m == LearnModule.qaidah ? '$unitsDone/${units.length}' : null,
                ),
              ),
          // To look things up: the courses teach the same, in order.
          QSectionLabel(context.l10n.learnReference),
          for (final m in LearnModule.values)
            if (m.shown(context) && m.reference)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ModuleCard(module: m),
              ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final int done, total;
  const _Ring({required this.done, required this.total});
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 60,
        child: CustomPaint(
          painter: _RingPainter(total == 0 ? 0 : done / total),
          child: Center(
            child: Text('$done/$total',
                style: uiStyle(context,
                    size: 14, weight: FontWeight.w700, color: kHeroInk)),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  _RingPainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: .14);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * v.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = kHeroGold);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}
