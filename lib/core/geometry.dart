/// Shared corner-radius / spacing tokens. Introduced alongside Kids Mode so
/// its screens (built from scratch) draw from one small vocabulary instead of
/// hand-picked literals scattered per-widget. Existing adult screens keep
/// their own inline values for now — see the Kids Mode plan's Phase 0:
/// migrate to these opportunistically as screens are touched anyway, not in
/// one big-bang pass.
class Geo {
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 26.0;
  static const radiusPill = 999.0;

  static const gapXs = 6.0;
  static const gapSm = 10.0;
  static const gapMd = 14.0;
  static const gapLg = 20.0;
  static const gapXl = 28.0;
}
