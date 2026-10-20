import 'package:flutter/widgets.dart';

import '../../core/settings.dart';

/// What a screen's content is, for how wide it may grow on desktop.
enum ContentKind {
  /// The reader, word grid, memorize and review: as wide as reads well.
  reading,

  /// The Qurʼān list, Learn, Hifz books, bookmarks, downloads.
  list,

  /// Settings (two columns from 1280).
  form,
}

/// The content's max width (design handoff update 7.1). Phones and tablets
/// in portrait (under 840) use the full width; desktop content fills the
/// window up to a comfortable measure instead of the old 760 phone column.
double contentMaxWidth(BuildContext context, ContentKind kind,
    {bool? sidebarCollapsed}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 840) return double.infinity;
  return switch (kind) {
    ContentKind.reading => (sidebarCollapsed ??
            SettingsScope.maybeOf(context)?.sidebarCollapsed ??
            false)
        ? 1520
        : 1280,
    ContentKind.list => 1200,
    ContentKind.form => 1200,
  };
}

/// A centred column at [contentMaxWidth], with 32 px gutters on desktop and
/// 16 on phones.
class ContentColumn extends StatelessWidget {
  final ContentKind kind;
  final Widget child;
  final bool? sidebarCollapsed;
  const ContentColumn(
      {super.key,
      required this.kind,
      required this.child,
      this.sidebarCollapsed});

  @override
  Widget build(BuildContext context) {
    final desk = MediaQuery.sizeOf(context).width >= 840;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: contentMaxWidth(context, kind,
                sidebarCollapsed: sidebarCollapsed)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: desk ? 32 : 16),
          child: child,
        ),
      ),
    );
  }
}
