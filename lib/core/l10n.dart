import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// 🌍 Localization (en · ar · ur · fr · es).
///
/// Strings live in `lib/l10n/app_<lang>.arb`, one file per language, and
/// `flutter gen-l10n` (wired via `generate: true` + `l10n.yaml`) turns them
/// into `lib/l10n/app_localizations.dart` — so a typo is a compile error
/// rather than a silent fallback, and translators get a standard ARB file per
/// language.
///
/// That generated file does not exist until the first `flutter pub get` /
/// build; until then the import below is reported as missing. That is
/// expected — it is generated code and is not checked in.
///
/// Read a string with `context.l10n.someKey`.
///
/// A key missing from a locale falls back to the English template, and every
/// such key is listed in `lib/l10n/untranslated.json` after each build.
class L10n {
  /// The languages offered by the in-app picker. Keep in step with
  /// `lib/l10n/app_*.arb` and [AppLocalizations.supportedLocales].
  static const supported = [
    ('en', 'English'),
    ('ar', 'العربية'),
    ('ur', 'اردو'),
    ('fr', 'Français'),
    ('es', 'Español'),
  ];

  static bool isRtl(String lang) => lang == 'ar' || lang == 'ur';
}

extension L10nContext on BuildContext {
  /// The translated strings for the current language.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
