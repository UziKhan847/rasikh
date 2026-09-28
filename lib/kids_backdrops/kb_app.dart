// The seam between the design kit (kb_*.dart, ported from the design handoff) and
// the app. The kit knows only its prototype's demo state; this file answers its
// questions from the app's real settings, so no kit widget reads AppSettings and no
// app screen picks a colour.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../core/settings.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';
import 'kb_ui.dart';

/// The app's default Kids Mode palette ('kids': coral, teal and amber on cream),
/// which the design's twelve shop themes do not include. Colours are the app's own
/// `kids` palette (core/theme.dart); the scene is plain rolling hills under a sun,
/// the design's most neutral recipe, so it sits under any child's first sessions
/// without looking like one of the themes they could buy.
const kbDefaultTheme = KbTheme(
  id: 'kids', name: 'Kids', bg: 0xFFF8F0, text: 0x3B2E22, accent: 0xEC6A4B, bright: 0xF2917A, deep: 0xD1502F, accent2: 0x1FA89B, reward: 0xF4B23E, dark: 0x231911,
  orn: KbOrnament('sun', x: 0.76, y: 0.14, r: 0.1),
  ridges: [KbRidge('hill', 0.6, 0.07, 1), KbRidge('hill', 0.77, 0.085, 0.75), KbRidge('hill', 0.92, 0.08, 0.55)],
  moteType: 'dust', moteCount: 14,
);

/// The design theme for an app theme family: `kids_ocean` → `ocean`, and the
/// default (or anything unknown) → [kbDefaultTheme].
KbTheme kbThemeFor(String? family) {
  if (family != null && family.startsWith('kids_')) {
    final id = family.substring(5);
    for (final t in kbThemes) {
      if (t.id == id) return t;
    }
  }
  return kbDefaultTheme;
}

/// The app family id for a design theme — the inverse of [kbThemeFor].
String kbFamilyOf(KbTheme t) => t.id == kbDefaultTheme.id ? 'kids' : 'kids_${t.id}';

KbMode kbModeFor(String kidsThemeMode) => switch (kidsThemeMode) {
  'dark' => KbMode.dark,
  'oled' => KbMode.oled,
  _ => KbMode.light,
};

/// Which look the Detail dial asks for. Plain paints no scene at all (the flat
/// background it always was); medium is the design's soft `original` scene with no
/// moving layer; high is the `vivid` scene with motes.
KbStyle kbStyleFor(KidsDetail d) => d == KidsDetail.high ? KbStyle.vivid : KbStyle.original;

/// The design tokens for whatever Kids Mode is showing right now.
KbUi kbUiFor(AppSettings s) => KbUi(
  kbThemeFor(s.activeKidsProfile?.theme),
  kbModeFor(s.kidsThemeMode),
  kbStyleFor(s.kidsDetail),
);

/// Shorthand for screens: `final ui = kbUi(context);`. Subscribes to settings, so a
/// theme or appearance change restyles every widget that asked.
///
/// The style is what is actually PAINTED behind [context] (the nearest
/// [KbSceneScope]), not the Detail setting: headings are white with an outline
/// only over the vivid sky. With no scene (plain detail, the desktop pane) they
/// are the palette's own ink on a flat background.
KbUi kbUi(BuildContext context) {
  final s = SettingsScope.of(context);
  return KbUi(
    kbThemeFor(s.activeKidsProfile?.theme),
    kbModeFor(s.kidsThemeMode),
    KbSceneScope.maybeOf(context) ?? KbStyle.original,
  );
}

/// The flat page colour under the scene — what a Scaffold behind a
/// `KidsBackdrop` paints, and all there is on plain detail.
Color kbPageBg(KbUi ui) => kbC(kbPalette(ui.th, ui.mode, ui.style).base);

/// Marks the subtree painted over a Kids Mode scene, and which style it is — so a
/// heading can tell whether the sky is really behind it.
/// Provided by `KidsBackdrop`; absent on plain detail, where there is no scene.
class KbSceneScope extends InheritedWidget {
  final KbStyle style;
  const KbSceneScope({super.key, required this.style, required super.child});

  static KbStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KbSceneScope>()?.style;

  @override
  bool updateShouldNotify(KbSceneScope old) => old.style != style;
}

/// The Material Symbols name the kit draws for one of the app's Material
/// icons — Kids Mode's content (path items, practice shortcuts) names its icons
/// as `IconData`, the kit (`KbIcon`) by symbol name. Every icon Kids Mode uses
/// is listed; anything else falls back to a plain dot rather than a blank.
String kbIconName(IconData icon) => _kbIconNames[icon] ?? 'circle';

final _kbIconNames = <IconData, String>{
  Icons.add_rounded: 'add',
  Icons.arrow_back_rounded: 'arrow_back',
  Icons.arrow_forward_rounded: 'arrow_forward',
  Icons.auto_awesome_rounded: 'auto_awesome',
  Icons.auto_stories_rounded: 'auto_stories',
  Icons.bolt_rounded: 'bolt',
  Icons.brightness_2_rounded: 'brightness_2',
  Icons.card_giftcard_rounded: 'card_giftcard',
  Icons.casino_rounded: 'casino',
  Icons.check_circle_rounded: 'check_circle',
  Icons.check_rounded: 'check',
  Icons.chevron_right_rounded: 'chevron_right',
  Icons.circle_outlined: 'radio_button_unchecked',
  Icons.close_rounded: 'close',
  Icons.compare_rounded: 'compare',
  Icons.crop_square_rounded: 'crop_square',
  Icons.dark_mode_rounded: 'dark_mode',
  Icons.diamond_rounded: 'diamond',
  Icons.download_for_offline_rounded: 'download_for_offline',
  Icons.download_rounded: 'download',
  Icons.draw_rounded: 'draw',
  Icons.emoji_events_rounded: 'emoji_events',
  Icons.exit_to_app_rounded: 'exit_to_app',
  Icons.extension_rounded: 'extension',
  Icons.face_retouching_natural_rounded: 'face_retouching_natural',
  Icons.face_rounded: 'face',
  Icons.fact_check_rounded: 'fact_check',
  Icons.graphic_eq_rounded: 'graphic_eq',
  Icons.grid_3x3_rounded: 'grid_3x3',
  Icons.grid_view_rounded: 'grid_view',
  Icons.group_rounded: 'group',
  Icons.headphones_rounded: 'headphones',
  Icons.hearing_rounded: 'hearing',
  Icons.height_rounded: 'height',
  Icons.help_outline_rounded: 'help_outline',
  Icons.home_rounded: 'home',
  Icons.insights_rounded: 'insights',
  Icons.landscape_rounded: 'landscape',
  Icons.layers_rounded: 'layers',
  Icons.lightbulb_rounded: 'lightbulb',
  Icons.light_mode_rounded: 'light_mode',
  Icons.link_rounded: 'link',
  Icons.local_fire_department_rounded: 'local_fire_department',
  Icons.lock_open_rounded: 'lock_open',
  Icons.lock_rounded: 'lock',
  Icons.looks_rounded: 'looks',
  Icons.menu_book_rounded: 'menu_book',
  Icons.play_arrow_rounded: 'play_arrow',
  Icons.psychology_alt_rounded: 'psychology_alt',
  Icons.quiz_rounded: 'quiz',
  Icons.record_voice_over_rounded: 'record_voice_over',
  Icons.refresh_rounded: 'refresh',
  Icons.replay_rounded: 'replay',
  Icons.route_rounded: 'route',
  Icons.school_rounded: 'school',
  Icons.search_rounded: 'search',
  Icons.spellcheck_rounded: 'spellcheck',
  Icons.star_outline_rounded: 'star_outline',
  Icons.star_rounded: 'star',
  Icons.style_rounded: 'style',
  Icons.switch_access_shortcut_rounded: 'switch_access_shortcut',
  Icons.timelapse_rounded: 'timelapse',
  Icons.traffic_rounded: 'traffic',
  Icons.upload_rounded: 'upload',
  Icons.videogame_asset_rounded: 'videogame_asset',
  Icons.visibility_rounded: 'visibility',
  Icons.volume_up_rounded: 'volume_up',
  Icons.wb_sunny_rounded: 'wb_sunny',
  Icons.wb_twilight_rounded: 'wb_twilight',
};
