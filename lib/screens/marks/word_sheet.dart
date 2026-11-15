import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/fluency/fluency_store.dart';
import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/adaptive_sheet.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../fluency/fluency_tools.dart';
import 'word_marks_sheet.dart';

/// A word, held: the same sheet in the muṣḥaf and the Reader. The word
/// large (arrows to the words either side), hearing it or reciting from
/// it, its marks (and adding one, a mutashābih included), and its fluency
/// marks.
///
/// [onPlayWord] and [onRecite] are the view's own (each plays as it does);
/// [onLink], where the view links a mutashābih's likenesses itself.
void showWordSheet(
  BuildContext context, {
  required String script,
  required MushafWord word,
  required String Function(int surah) surahName,
  required void Function(MushafWord) onPlayWord,
  required void Function(MushafWord) onRecite,
  String? Function()? sessionId,
  ValueChanged<Mark>? onLink,
  ValueListenable<bool>? fromLeft,
}) {
  final hasMarks = MarksScope.maybeOf(context) != null;
  final hasFluency = FluencyScope.maybeOf(context) != null;
  final tall = hasMarks || hasFluency;
  var wd = word;
  showAdaptiveSheet<void>(
    context,
    fromLeft: fromLeft,
    isScrollControlled: tall,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        final p = pal(sheet);
        final l = sheet.l10n;
        final (surah, ayahInSurah) = MushafRepo.surahAyahOf(wd.ayah);
        final tok = MushafRepo.tokenOf(script, wd.ayah, wd.wordIdx);
        // As the text runs, right to left: the previous word is on the
        // right, the next on the left.
        Widget step(int by) {
          final to = MushafRepo.wordAtToken(script, tok + by);
          return IconButton(
            tooltip: by > 0 ? l.mzNextWord : l.mzPrevWord,
            iconSize: 28,
            color: p.ink2,
            onPressed: to == null ? null : () => setSheet(() => wd = to),
            icon: Icon(by > 0 ? AppIcons.chevronLeft : AppIcons.chevronRight),
          );
        }

        final ref = WordRef.fromGlobal(wd.ayah, wd.wordIdx);
        Widget body(ScrollController? scroll) => SafeArea(
              child: ListView(
                controller: scroll,
                shrinkWrap: scroll == null,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(children: [
                      step(1),
                      Expanded(
                        child: Text(
                          wd.text,
                          key: const ValueKey('word-sheet-word'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: MushafRepo.fontFamily(script),
                            fontSize: 44,
                            color: p.ink,
                          ),
                        ),
                      ),
                      step(-1),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wd.isMarker
                        ? '${surahName(surah)}  ·  $surah:$ayahInSurah  ·  ${l.mkWholeAyah}'
                        : l.wordN(surahName(surah), '$surah:$ayahInSurah', wd.wordIdx + 1),
                    textAlign: TextAlign.center,
                    style: uiStyle(sheet, size: 13, weight: FontWeight.w600, color: p.ink3),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!wd.isMarker)
                        QPrimaryButton(
                          l.playWord,
                          icon: AppIcons.volume,
                          onTap: () {
                            Navigator.pop(sheet);
                            onPlayWord(wd);
                          },
                        ),
                      QOutlineButton(
                        l.reciteFromHere,
                        icon: AppIcons.recite,
                        onTap: () {
                          Navigator.pop(sheet);
                          onRecite(wd);
                        },
                      ),
                    ],
                  ),
                  if (hasMarks)
                    WordMarksPanel(
                      // A fresh panel for each word stepped to.
                      key: ValueKey((wd.ayah, wd.wordIdx)),
                      ref: ref,
                      sessionId: sessionId?.call(),
                      onLink: onLink == null
                          ? null
                          : (m) {
                              Navigator.pop(sheet);
                              onLink(m);
                            },
                    ),
                  if (hasFluency && !wd.isMarker)
                    FluencyWordPanel(
                      key: ValueKey(('fl', wd.ayah, wd.wordIdx)),
                      script: script,
                      ref: ref,
                    ),
                ],
              ),
            );
        if (!tall || AdaptiveSheet.isSide(sheet)) return body(null);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .94,
          builder: (_, scroll) => body(scroll),
        );
      },
    ),
  );
}
