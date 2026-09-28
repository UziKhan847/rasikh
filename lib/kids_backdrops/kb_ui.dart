// UI colour tokens — port of the `uiv` object in renderVals() of Kids Backdrops.dc.html.
// Every card, tile, nav item and heading in the app reads from here. Don't pick colours in widgets.

import 'package:flutter/widgets.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';

/// CSS blur radius -> Flutter blurRadius (CSS sigma = blur/2; Flutter sigma = r*0.57735+0.5).
double kbCssBlur(double css) => ((css / 2 - .5) / .57735).clamp(0, double.infinity).toDouble();

/// The "3D" card edge used everywhere: CSS `0 {edgeY}px 0 edge, 0 {softY}px {blur}px rgba(0,0,0,alpha)`.
/// Flutter paints the list bottom-up, so the soft shadow comes first (CSS lists top-down).
List<BoxShadow> kbCardShadow(Color edge, {double edgeY = 5, double? softY, double blur = 20, double alpha = .18}) => [
      if (blur > 0) BoxShadow(color: kbC(kBlack, alpha), offset: Offset(0, softY ?? edgeY * 2), blurRadius: kbCssBlur(blur)),
      BoxShadow(color: edge, offset: Offset(0, edgeY)),
    ];

class KbUi {
  final KbTheme th;
  final KbMode mode;
  final KbStyle style;
  final String headingStyle; // 'outline' | 'banner'

  KbUi(this.th, this.mode, this.style, {this.headingStyle = 'outline'});

  bool get light => mode == KbMode.light;
  bool get vivid => style == KbStyle.vivid;

  int get surface => light ? kWhite : mode == KbMode.dark ? kbMix(th.dark, kWhite, .09) : 0x161618;
  int get edge => light ? kbMix(th.deep, kWhite, .45) : kBlack;
  int get ink => light ? th.text : 0xF5F2EE;
  int get inkSoft => light ? kbMix(th.text, kWhite, .3) : kbMix(0xF5F2EE, surface, .35);
  int get outlineC => kbMix(th.deep, kBlack, light ? .3 : .55);
  int get reward => th.reward;
  int get rewardEdge => kbMix(th.reward, kBlack, .3);
  int get rewardInk => kbMix(th.text, kBlack, .35);
  int get cardDeep => light ? th.deep : kbMix(th.deep, th.accent, .25);
  int get cardDeepEdge => kbMix(cardDeep, kBlack, .45);
  int get tile => light ? kbMix(th.bright, kWhite, .72) : kbMix(th.dark, th.accent, .35);
  int get tileInk => light ? th.deep : kbMix(th.bright, kWhite, .3);
  int get accent => th.accent;
  int get accentEdge => light ? th.deep : kbMix(th.deep, kBlack, .4);
  int get track => light ? kbMix(th.bright, kWhite, .78) : kbMix(surface, kBlack, .35);
  int get linkInk => light ? th.deep : th.bright;
  Color get pathLine => vivid ? kbC(kWhite, .75) : kbC(th.text, .18);
  Color get dot => light ? kbC(th.deep, .14) : kbC(kWhite, .1);
  int get wordBg => light ? kbMix(th.bright, kWhite, .88) : kbMix(surface, kBlack, .25);
  int get lockBg => light ? kbMix(th.text, kWhite, .3) : 0x55555A;
  int get disabledBg => light ? kbMix(surface, th.bright, .18) : kbMix(surface, kBlack, .3);
  int get cpuBg => light ? kbMix(th.accent2, kWhite, .7) : kbMix(th.accent2, surface, .55); // opponent tiles
  int get cpuEdge => kbMix(th.accent2, kBlack, .3);

  // Feedback
  int get goodBg => kbMix(0x3DBE6E, surface, light ? .75 : .6);
  static const goodLine = 0x2E9E5B, goodEdge = 0x237A46;
  int get badBg => kbMix(0xE2574C, surface, light ? .75 : .6);
  static const badLine = 0xD2463B, badEdge = 0x9E2F27;

  // Headings drawn on top of the backdrop sky.
  bool get banner => vivid && headingStyle == 'banner';
  int get headInk => vivid ? kWhite : (light ? th.text : kbMix(th.bg, kWhite, .3));
  int get subInk => vivid ? kWhite : inkSoft;

  List<Shadow> _outline(double w, List<Offset> extra) => [
        for (final o in [Offset(0, w), Offset(w, 0), Offset(-w, 0), Offset(0, -w), Offset(w * .75, w * .75), Offset(-w * .75, w * .75), Offset(w * .75, -w * .75), Offset(-w * .75, -w * .75), ...extra])
          Shadow(color: kbC(outlineC), offset: o),
      ];

  /// Page title (e.g. "Your Path"). 2px outline + 4px drop edge + soft shadow.
  List<Shadow> get headShadows => vivid && headingStyle == 'outline'
      ? [..._outline(2, const [Offset(0, 4), Offset(1.5, 4), Offset(-1.5, 4)]), Shadow(color: kbC(kBlack, .25), offset: const Offset(0, 7), blurRadius: kbCssBlur(14))]
      : const [];

  /// Section labels ("Themes", "Looks").
  List<Shadow> get subShadows => vivid ? _outline(1.5, const [Offset(0, 3)]) : const [];
}
