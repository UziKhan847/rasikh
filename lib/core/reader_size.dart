import 'settings.dart';

/// The reader's Arabic size in pixels. Stored as `quranFontScale` × [kReaderBase].
const double kReaderBase = 26;
const double kReaderMinPx = 18;
/// Desktop's cap on the smallest window; it grows with the window (see
/// [readerMaxDesktopFor]).
const double kReaderMaxDesktop = 120;
const double kReaderMaxMobile = 64;

double readerPx(AppSettings s) => kReaderBase * s.quranFontScale;

/// The desktop cap for a window [windowWidth] wide: a sixth of it — so the
/// longest Qurʼānic words (about six ems) still fit — and never under
/// [kReaderMaxDesktop]. A big screen can take a huge text.
double readerMaxDesktopFor(double windowWidth) {
  final w = windowWidth / 6;
  return w > kReaderMaxDesktop ? w : kReaderMaxDesktop;
}

/// One step larger: +3 up to 44, then +6 (design Update 2 §5).
double readerStepUp(double px, double max) {
  final next = px < 44 ? px + 3 : px + 6;
  return next > max ? max : next;
}

/// One step smaller: −6 above 44, then −3.
double readerStepDown(double px) {
  final next = px > 44 ? px - 6 : px - 3;
  return next < kReaderMinPx ? kReaderMinPx : next;
}

void setReaderPx(AppSettings s, double px) =>
    s.update(() => s.quranFontScale = px / kReaderBase);
