import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../screens/qaidah_screen.dart' show QaidahUnit, QaidahUnitHub, qaidahUnits;
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../widgets/common.dart' show StarRow;
import 'families.dart';
import 'lesson.dart';
import 'lesson_player.dart';

/// One thing the course teaches, in its order: a family's lesson, or a
/// unit (Learn · Test · Practice) for the shapes, signs and reading.
class CourseItem {
  final LetterFamily? family;
  final QaidahUnit? unit;
  const CourseItem.family(LetterFamily this.family) : unit = null;
  const CourseItem.unit(QaidahUnit this.unit) : family = null;

  String get progressId => family?.progressId ?? unit!.progressId;
  String title(BuildContext context) =>
      family != null ? familyTitle(context, family!) : unit!.title;
}

/// The units in their sections: the letters (their families, then the
/// special shapes), the vowels and signs, and reading.
(List<CourseItem>, List<CourseItem>, List<CourseItem>) courseSections(BuildContext context) {
  final units = {for (final u in qaidahUnits(context)) u.progressId: u};
  CourseItem u(String id) => CourseItem.unit(units[id]!);
  return (
    [for (final f in letterFamilies) CourseItem.family(f), u('qaidah.forms')],
    [u('qaidah.harakat'), u('qaidah.tanwin'), u('qaidah.sukun'), u('qaidah.shadda'), u('qaidah.madd')],
    [u('qaidah.words'), u('qaidah.wasl'), u('qaidah.muqattaat'), u('qaidah.review')],
  );
}

/// Every item, in order.
List<CourseItem> courseItems(BuildContext context) {
  final (a, b, c) = courseSections(context);
  return [...a, ...b, ...c];
}

/// Opens [item]: a family's lesson (its "next" the item after), or a unit.
Future<void> openCourseItem(BuildContext context, CourseItem item) {
  final f = item.family;
  if (f == null) return pushAdaptive(context, QaidahUnitHub(unit: item.unit!));
  final items = courseItems(context);
  final at = items.indexWhere((x) => x.progressId == item.progressId);
  final next = at >= 0 && at + 1 < items.length ? items[at + 1] : null;
  return pushAdaptive(
    context,
    familyLessonPlayer(context, f,
        onNext: next == null ? null : () => openCourseItem(context, next)),
  );
}

/// [f]'s lesson in the player (resumed where it was left).
LessonPlayer familyLessonPlayer(BuildContext context, LetterFamily f, {VoidCallback? onNext}) =>
    LessonPlayer(
      id: f.progressId,
      build: (seed) => familyLesson(context, f, rng: math.Random(seed)),
      onNext: onNext,
    );

/// The Qāʿidah: the next lesson to take, then the course in its sections —
/// a card per family (its letters, its stars), the units after. Nothing
/// is locked.
class QaidahHome extends StatelessWidget with DesktopAware {
  const QaidahHome({super.key});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final (letters, signs, reading) = courseSections(context);
    final all = [...letters, ...signs, ...reading];
    final next = all.firstWhere((i) => prog.starsFor(i.progressId) == 0,
        orElse: () => all.first);
    Widget section(String label, List<CourseItem> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QSectionLabel(label),
            LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 280).floor().clamp(1, 4);
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final i in items)
                  SizedBox(
                    width: w,
                    child: _ItemCard(
                        item: i, stars: prog.starsFor(i.progressId), current: identical(i, next)),
                  ),
              ]);
            }),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.qaidahPath)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            QColumn(
              child: QHeroCard(
                padding: const EdgeInsets.all(18),
                onTap: () => openCourseItem(context, next),
                child: Row(children: [
                  const Icon(AppIcons.play, color: kHeroInk, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(context.l10n.qcContinueWith(next.title(context)),
                        style: displayStyle(context, size: 20, color: kHeroInk)),
                  ),
                ]),
              ),
            ),
            QColumn(child: section(context.l10n.qcSectionLetters, letters)),
            QColumn(child: section(context.l10n.qcSectionSigns, signs)),
            QColumn(child: section(context.l10n.qcSectionReading, reading)),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final CourseItem item;
  final int stars;
  final bool current;
  const _ItemCard({required this.item, required this.stars, required this.current});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final f = item.family;
    final glyphs = f != null ? f.chars.join(' ') : item.unit!.arabicBadge;
    // A lesson left halfway: where.
    final place = f == null ? null : ProgressScope.of(context).lessonPlace(f.progressId);
    final sub = f == null
        ? item.unit!.subtitle
        : f.id == 'alif'
            ? context.l10n.qcAlifTitle
            : context.l10n.qcLessonSub(f.chars.join(' '));
    return QCard(
      padding: const EdgeInsets.all(14),
      borderColor: current ? p.acc : null,
      onTap: () => openCourseItem(context, item),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(16)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(glyphs,
                  textDirection: TextDirection.rtl,
                  style: quranicStyle(context, size: 26, height: 1.5, color: p.acc)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 12.5, color: p.ink3, height: 1.35)),
            const SizedBox(height: 6),
            if (place != null)
              Text(context.l10n.qcResume(place.step + 1, place.total),
                  style: uiStyle(context, size: 12.5, weight: FontWeight.w700, color: p.acc))
            else
              StarRow(stars, size: 14),
          ]),
        ),
      ]),
    );
  }
}
