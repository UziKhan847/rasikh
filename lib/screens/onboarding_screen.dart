import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/app_icons.dart';
import '../ui/brand.dart';
import '../ui/kit.dart';

/// The first launch: welcome, how to read (script and reciter), and the
/// look. Skip or finish both mark it done. [pushed] when reopened from
/// Settings ("Show welcome again").
class OnboardingScreen extends StatefulWidget {
  final bool pushed;
  const OnboardingScreen({super.key, this.pushed = false});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _cream = kHeroInk;
const _creamSoft = kHeroInk2;
const _gold = kHeroGold;

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  void _finish() {
    final s = SettingsScope.of(context);
    s.update(() => s.onboarded = true);
    if (widget.pushed && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = gradientsOf(context);
    final steps = [_welcome(context), _read(context), _look(context)];
    if (_step >= steps.length) _step = steps.length - 1;
    final last = _step == steps.length - 1;
    final cta = last
        ? context.l10n.obStartReading
        : _step == 0
            ? context.l10n.obBegin
            : context.l10n.continueLabel;
    return Scaffold(
      backgroundColor: g.heroFlat,
      body: DecoratedBox(
        decoration: gradientsOn(context)
            ? BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: g.hero,
                    stops: const [0, .55, 1]),
              )
            : BoxDecoration(color: g.heroFlat),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // The mode step's four previews take a wider row.
              constraints: BoxConstraints(
                  maxWidth: 560),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 18, 0),
                  child: Row(children: [
                    for (var i = 0; i < steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        width: i == _step ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _step
                              ? _gold
                              : _cream.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(foregroundColor: _creamSoft),
                      child: Text(context.l10n.obSkip),
                    ),
                  ]),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: KeyedSubtree(
                                key: ValueKey(_step), child: steps[_step]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(children: [
                    if (_step > 0) ...[
                      _Round(
                        onTap: () => setState(() => _step--),
                        child: const Icon(AppIcons.back, color: _cream, size: 22),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Material(
                        color: _cream,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => last ? _finish() : setState(() => _step++),
                          child: SizedBox(
                            height: 54,
                            child: Center(
                              child: Text(cta,
                                  style: uiStyle(context,
                                      size: 16,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF0F3B32))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogoTile(
              size: 88,
              radius: 26,
              inset: 10,
              glyph: _cream,
              background: Color(0x14F2EEE4)),
          const SizedBox(height: 22),
          const Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 30,
                  height: 1.8,
                  color: _gold)),
          const SizedBox(height: 4),
          Text(context.l10n.appName,
              style: const TextStyle(
                  fontFamily: 'SourceSerif4',
                  // Its name in Arabic and Urdu.
                  fontFamilyFallback: ['NotoNaskhArabic'],
                  fontSize: 46,
                  height: 1.05,
                  color: _cream)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(context.l10n.obPromise,
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 16, height: 1.55, color: _creamSoft)),
          ),
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, label) in const [
                ('en', 'English'),
                ('ar', 'العربية'),
                ('ur', 'اردو'),
                ('fr', 'Français'),
                ('es', 'Español'),
              ])
                _Pill(
                  label: label,
                  selected: SettingsScope.of(context).language == code,
                  onTap: () {
                    final s = SettingsScope.of(context);
                    s.update(() => s.language = code);
                  },
                ),
            ],
          ),
        ],
      );

  /// Light, dark or OLED.
  Widget _look(BuildContext context) {
    final s = SettingsScope.of(context);
    Widget choice(String id, String label, Color page, Color ink) => Expanded(
          child: _Choice(
            selected: s.appTheme == id,
            onTap: () => s.update(() {
              s.appTheme = id;
              s.mushafPaperDark = 'default';
            }),
            child: Column(children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                    color: page,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cream.withValues(alpha: .3))),
                alignment: Alignment.center,
                child: Text('بِسۡمِ ٱللَّهِ',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'UthmanicHafs', fontSize: 18, height: 1.6, color: ink)),
              ),
              const SizedBox(height: 8),
              Text(label, style: uiStyle(context, size: 14, weight: FontWeight.w700, color: _cream)),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _title(context, context.l10n.obLookTitle, context.l10n.obLookSub),
      Row(children: [
        choice('light', context.l10n.themeLight, const Color(0xFFFBF7EC), const Color(0xFF1D2420)),
        const SizedBox(width: 10),
        choice('night', context.l10n.themeDark, const Color(0xFF1B2220), const Color(0xFFE8ECE9)),
        const SizedBox(width: 10),
        choice('oled', context.l10n.themeOled, Colors.black, const Color(0xFFE8ECE9)),
      ]),
    ]);
  }

  Widget _title(BuildContext context, String t, String sub) => Column(children: [
        Text(t,
            textAlign: TextAlign.center,
            style: displayStyle(context, size: 30, color: _cream)),
        const SizedBox(height: 8),
        Text(sub,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 14.5, height: 1.5, color: _creamSoft)),
        const SizedBox(height: 22),
      ]);

  Widget _read(BuildContext context) {
    final s = SettingsScope.of(context);
    Widget script(String id, String label, String font) {
      final on = s.quranScript == id;
      return Expanded(
        child: _Choice(
          selected: on,
          onTap: () => s.update(() {
            s.quranScript = id;
            s.mushafScript = id;
          }),
          child: Column(children: [
            Text('بِسۡمِ ٱللَّهِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: font, fontSize: 26, height: 2.2, color: _cream)),
            Text(label,
                style: uiStyle(context,
                    size: 14, weight: FontWeight.w700, color: _cream)),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _title(context, context.l10n.obHowRead, context.l10n.obHowReadSub),
      Row(children: [
        script('uthmani', context.l10n.madani, 'DigitalKhattV2'),
        const SizedBox(width: 12),
        script('indopak', context.l10n.indoPak, 'DigitalKhattIndoPak'),
      ]),
      const SizedBox(height: 20),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(context.l10n.reciter,
            style: uiStyle(context,
                size: 13, weight: FontWeight.w700, color: _creamSoft)),
      ),
      const SizedBox(height: 8),
      for (final (id, name) in [
        ('tunaiji', context.l10n.alTunaiji),
        ('alafasy', context.l10n.afasyName),
        ('husary', context.l10n.husaryName),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Choice(
            selected: s.reciter == id,
            onTap: () => s.update(() => s.reciter = id),
            child: Row(children: [
              Expanded(
                child: Text(name,
                    style: uiStyle(context,
                        size: 15, weight: FontWeight.w600, color: _cream)),
              ),
              _Dot(on: s.reciter == id),
            ]),
          ),
        ),
    ]);
  }

}

class _Choice extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Choice({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _gold.withValues(alpha: .10) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: selected ? _gold : _cream.withValues(alpha: .16),
              width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: child,
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  final bool on;
  const _Dot({required this.on});
  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: on ? _gold : _cream.withValues(alpha: .35),
              width: on ? 6 : 1.5),
        ),
      );
}

class _Round extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Round({required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: _cream.withValues(alpha: .3))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: 54, child: Center(child: child)),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _gold.withValues(alpha: .16) : Colors.transparent,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? _gold : _cream.withValues(alpha: .25))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label,
                style: uiStyle(context,
                    size: 14, weight: FontWeight.w600, color: selected ? _gold : _cream)),
          ),
        ),
      );
}
