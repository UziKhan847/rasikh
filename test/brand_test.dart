import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/ui/brand.dart';

/// The logo draws the Rāsikh calligraphy, from the asset in the bundle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the logo tile loads its calligraphy', (tester) async {
    expect(await rootBundle.loadString('assets/brand/rasikh_icon.svg'), contains('<svg'));
    await tester.pumpWidget(const MaterialApp(
        home: Center(child: AppLogoTile(size: 88, background: Colors.green))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
