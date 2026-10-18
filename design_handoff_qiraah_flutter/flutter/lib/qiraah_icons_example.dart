import 'package:flutter/material.dart';
import 'qiraah_icons.dart';

/// Use exactly like Material Icons:
///   Icon(QiraahIcons.play, size: 24, color: context.qc.ink)
///   IconButton(icon: const Icon(QiraahIcons.settings), onPressed: ...)
class QiraahIconGallery extends StatelessWidget {
  const QiraahIconGallery({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.extent(
      maxCrossAxisExtent: 120,
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in QiraahIcons.all.entries)
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(e.value, size: 32),
            const SizedBox(height: 8),
            Text(e.key, style: const TextStyle(fontSize: 11)),
          ]),
      ],
    );
  }
}
