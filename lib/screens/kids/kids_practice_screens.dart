import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../widgets/common.dart';

/// The letters a child has already met — the same set the Home screen's
/// letter path marks "done" or "current". Flashcards/Listening review this
/// set rather than the whole alphabet, so early practice isn't drowned in
/// letters not taught yet.
List<ArabicLetter> _reviewableLetters(ProgressStore prog) {
  final doneCount = (prog.kidsLettersLearned + 1).clamp(1, kidsLetterPath.length);
  return kidsLetterPath.sublist(0, doneCount);
}

/// A flip-card review of every letter learned so far: tap to reveal the name
/// and an example word, then swipe to the next.
class KidsFlashcardsScreen extends StatefulWidget {
  const KidsFlashcardsScreen({super.key});
  @override
  State<KidsFlashcardsScreen> createState() => _KidsFlashcardsScreenState();
}

class _KidsFlashcardsScreenState extends State<KidsFlashcardsScreen> {
  int _i = 0;
  bool _flipped = false;

  Widget _card(BuildContext context, ArabicLetter letter, double width) {
    return TapScale(
      onTap: () => setState(() => _flipped = !_flipped),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey('$_i-$_flipped'),
          width: width,
          height: width * 1.25,
          alignment: Alignment.center,
          decoration: kidsCard(context, radius: Geo.radiusXl),
          padding: const EdgeInsets.all(Geo.gapLg),
          child: _flipped
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(letterName(context, letter),
                        style:
                            kidsStyle(context, size: 22, weight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Text(letter.exampleWord,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 30)),
                  ],
                )
              : Text(letter.char,
                  textDirection: TextDirection.rtl,
                  style: quranicStyle(context, size: 72)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ArabicLetter letter, int poolLength) {
    return Column(children: [
      Expanded(
        child: Center(
          child: LayoutBuilder(builder: (context, c) {
            final width = c.maxHeight < c.maxWidth
                ? (c.maxHeight * .8).clamp(180.0, 320.0)
                : (c.maxWidth * .8).clamp(180.0, 320.0);
            return _card(context, letter, width);
          }),
        ),
      ),
      const SizedBox(height: Geo.gapMd),
      Text(context.l10n.kidsTapToFlip,
          style: kidsStyle(context, size: 12.5, color: kidsPal(context).textDim)),
      const SizedBox(height: Geo.gapMd),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kidsPal(context).accent),
          onPressed: () => setState(() {
            _i = (_i + 1) % poolLength;
            _flipped = false;
          }),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(context.l10n.kidsNextCard),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final pool = _reviewableLetters(prog);
    final letter = pool[_i % pool.length];

    if (useDesktop(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(Geo.gapXl),
            child: _body(context, letter, pool.length),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.l10n.kidsFlashcards,
              style: kidsStyle(context, size: 17, weight: FontWeight.w800))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Geo.gapLg),
          child: _body(context, letter, pool.length),
        ),
      ),
    );
  }
}

/// Plays each learned letter's real Qur'anic example word — the same
/// [AyahAudio] recitation every other "Listen" control in the app uses.
class KidsListeningScreen extends StatelessWidget {
  const KidsListeningScreen({super.key});

  Future<void> _play(String ref) async {
    final parts = ref.split(':');
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (s == null || a == null) return;
    await AyahAudio.instance.play(s, a);
  }

  Widget _row(BuildContext context, ArabicLetter letter) {
    final p = kidsPal(context);
    return TapScale(
      onTap: () => _play(letter.exampleRef),
      child: Container(
        padding: const EdgeInsets.all(Geo.gapMd),
        decoration: kidsCard(context),
        child: Row(children: [
          Text(letter.char,
              textDirection: TextDirection.rtl,
              style: quranicStyle(context, size: 30)),
          const SizedBox(width: Geo.gapMd),
          Expanded(
            child: Text(letterName(context, letter),
                style: kidsStyle(context, size: 15, weight: FontWeight.w700)),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent2, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 20),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final pool = _reviewableLetters(prog);

    final list = ListView.separated(
      padding: const EdgeInsets.all(Geo.gapLg),
      itemCount: pool.length,
      separatorBuilder: (_, _) => const SizedBox(height: Geo.gapSm),
      itemBuilder: (context, i) => _row(context, pool[i]),
    );

    if (useDesktop(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: list,
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.l10n.kidsListening,
              style: kidsStyle(context, size: 17, weight: FontWeight.w800))),
      body: SafeArea(child: list),
    );
  }
}
