import 'dart:io';

import 'package:flutter/services.dart';

/// Loads every font family declared in pubspec.yaml (and Material Icons) into
/// the test engine, so screenshots show the real type instead of Ahem boxes.
Future<void> loadShotFonts() async {
  // Every family declared in pubspec.yaml, from the test bundle.
  final lines = File('pubspec.yaml').readAsLinesSync();
  String? family;
  final assets = <String, List<String>>{};
  for (final l in lines) {
    final f = RegExp(r'^\s*- family:\s*(.+)$').firstMatch(l);
    if (f != null) family = f.group(1)!.trim();
    final a = RegExp(r'^\s*- asset:\s*(assets/fonts/\S+)$').firstMatch(l);
    if (a != null && family != null) (assets[family] ??= []).add(a.group(1)!);
  }
  for (final e in assets.entries) {
    final loader = FontLoader(e.key);
    for (final a in e.value) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/home/uzi/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}
