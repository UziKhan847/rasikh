import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_line.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The 15-line page: justified lines reach the full line width — including
/// lines with an āyah marker, where Skia used to drop the gaps beside the
/// marker — and the gaps either side of a marker match the line's others.
Future<void> _pump(WidgetTester tester,
    {required String script,
    required int page,
    required Size size,
    required bool desktop}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.desktopMode = desktop ? 'on' : 'off';
  await tester.pumpWidget(SettingsScope(
    settings: s,
    child: ProgressScope(
      progress: p,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MushafPageScreen(startPage: page, script: script),
      ),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// One rendered muṣḥaf line: its width and each token's extent and kind.
class _Line {
  final double width;
  final List<(double, double)> extents;
  final List<bool> markers;
  _Line(this.width, this.extents, this.markers);
}

List<List<_Line>> _pages(WidgetTester tester) {
  final pages = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_MushafPageView');
  final out = <List<_Line>>[];
  for (final pg in pages.evaluate()) {
    final lines = <_Line>[];
    for (final el in find
        .descendant(
            of: find.byWidget(pg.widget), matching: find.byType(MushafLineView))
        .evaluate()) {
      final r = el.renderObject! as RenderMushafLine;
      final laid = r.laidLine;
      if (laid == null) continue;
      final words = r.spec.line.words;
      if (words.length < 2) continue;
      lines.add(_Line(laid.width, laid.boxes,
          [for (final w in words) w.isMarker]));
    }
    if (lines.isNotEmpty) out.add(lines);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    // Real glyph widths: the default test font would make every glyph 1 em.
    await loadFonts();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  const cases = [
    ('desktop spread', Size(1500, 1000), true),
    ('phone', Size(393, 852), false),
  ];
  for (final script in ['uthmani', 'indopak']) {
    for (final (label, size, desktop) in cases) {
      for (final page in [3, 50, 300, script == 'uthmani' ? 603 : 609]) {
        testWidgets('$script · $label · page $page', (tester) async {
          await _pump(tester,
              script: script, page: page, size: size, desktop: desktop);
          final pages = _pages(tester);
          expect(pages, isNotEmpty);
          var markerLines = 0;
          for (final lines in pages) {
            final target =
                lines.map((l) => l.width).reduce((a, b) => a > b ? a : b);
            for (final line in lines) {
              final w = line.width;
              // Lines under ~45% natural width are centred, not justified;
              // the Madani's come set, its short last lines narrow (as
              // 60–70% of the measure).
              if (w < target * (script == 'uthmani' ? .9 : .6)) continue;
              expect(w, closeTo(target, 1.5),
                  reason: 'line not full width ($w vs $target)');
              // Gaps between neighbouring tokens (RTL: token i+1 is left).
              final ext = line.extents;
              final gaps = [
                for (var i = 0; i + 1 < ext.length; i++)
                  ext[i].$1 - ext[i + 1].$2
              ];
              final plain = [
                for (var i = 0; i < gaps.length; i++)
                  if (!line.markers[i] && !line.markers[i + 1]) gaps[i]
              ];
              if (plain.isEmpty) continue;
              plain.sort();
              final median = plain[plain.length ~/ 2];
              for (var i = 0; i < gaps.length; i++) {
                if (line.markers[i] || line.markers[i + 1]) {
                  markerLines++;
                  expect(gaps[i], greaterThan(median * .6),
                      reason: 'gap beside an āyah marker collapsed '
                          '(${gaps[i]} vs median $median)');
                }
              }
            }
          }
          if (page != 3) expect(markerLines, greaterThan(0));
        });
      }
    }
  }

  test('page box: text drives its shape, within the room given', () {
    // Short room: height-limited, so the page is narrower than the room
    // instead of stretching its lines.
    final tall = MushafGeometry.pageBox(const Size(700, 900), 'uthmani',
        look: MushafLook.framed, header: true);
    expect(tall.height, closeTo(900, .01));
    expect(tall.width, lessThan(690));
    // Tall room: width-limited, so the page is shorter than the room.
    final wide = MushafGeometry.pageBox(const Size(700, 3000), 'uthmani',
        look: MushafLook.framed, header: true);
    expect(wide.width, closeTo(700, .01));
    expect(wide.height, lessThan(3000));
  });
}
