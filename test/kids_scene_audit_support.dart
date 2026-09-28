import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/kids_backdrops/kb_app.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_scene.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_widgets.dart';

/// Every piece of on-screen text that sits directly on the backdrop scene with
/// nothing solid behind it and is not a heading or subtitle (`KbHeading`,
/// `KbSubtitle`, `KbArabicTitle`).
///
/// This is the design's rule made checkable: *only headings and one-line
/// subtitles sit on the scene; everything else sits on a solid surface.* Each
/// entry names the text, so a failure reads as a work list rather than a
/// count.
///
/// Walks the real element tree, so it sees exactly what a child would: text
/// inside a card is fine, text inside a heading is fine, anything left over is
/// a place the vivid scene would swallow.
List<String> kidsTextsOnScene(WidgetTester tester) {
  final found = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    var reachedScene = false;
    var covered = false;
    e.visitAncestorElements((a) {
      final w = a.widget;
      // An Icon is a glyph in a RichText, not text a child reads.
      if (w is Icon || w is KbIcon || w is KbHeading || w is KbSubtitle || w is KbArabicTitle || kidsIsSolid(w)) {
        covered = true;
        return false;
      }
      if (w is KbSceneScope && w.style == KbStyle.vivid) {
        reachedScene = true;
        return false;
      }
      return true;
    });
    if (!reachedScene || covered) continue;
    final text = (e.widget as RichText).text.toPlainText().trim();
    if (text.isNotEmpty) found.add(text);
  }
  return found;
}

/// Whether [w] paints something solid behind whatever it wraps — a card, a
/// filled button, a coloured box. Deliberately generous about what counts: the
/// question is only "can text here be read against this widget's own
/// background, whatever scene is behind it".
/// `KbSurface` counts: it is a `DecoratedBox` with an opaque colour.
bool kidsIsSolid(Widget w) {
  bool opaque(Color? c) => c != null && c.a >= .9;
  if (w is DecoratedBox) {
    final d = w.decoration;
    if (d is BoxDecoration) {
      return opaque(d.color) || d.gradient != null || d.image != null;
    }
    return false;
  }
  if (w is ColoredBox) return opaque(w.color);
  if (w is Material) {
    return w.type != MaterialType.transparency &&
        (w.color == null || opaque(w.color));
  }
  if (w is PhysicalModel) return opaque(w.color);
  if (w is PhysicalShape) return opaque(w.color);
  return false;
}
