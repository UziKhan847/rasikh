import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// ℹ️ About — what Qiraah Arabiyyah is, and who we thank.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.about)),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  pal(context).accent,
                  pal(context).accentBright,
                ]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قِرَاءَة',
                      textDirection: TextDirection.rtl,
                      style: arabicStyle(context,
                          size: 40, height: 1.4, color: Colors.white)),
                  Text(context.l10n.qiraahArabiyyah,
                      style: uiStyle(context,
                          size: 22,
                          weight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.completeJourneyQurAnicArabic,
                    style: uiStyle(context,
                        size: 13.5,
                        color: Colors.white.withValues(alpha: .9)),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(context.l10n.language),
          _languageCard(context),
          SectionHeader(context.l10n.yourData),
          _backupCard(context),
          SectionHeader(context.l10n.sourcesLicences),
          _creditsCard(context),
          SectionHeader(context.l10n.display),
          _layoutCard(context),
          _colorCard(context),
           SectionHeader(context.l10n.whatThisAppTeaches),
          _card(
            context,
            context.l10n.aboutBody,
          ),
           SectionHeader(context.l10n.creditsGratitude),
          _creditCard(
            context,
            'Markaz Tafsir',
            context.l10n.creditMarkazBody,
            Icons.record_voice_over_rounded,
            pal(context).accent,
          ),
          _creditCard(
            context,
            'Shaykh Khalifah Al-Tunaiji',
            context.l10n.creditTunaijiBody,
            Icons.headphones_rounded,
            pal(context).accent2,
          ),
          _creditCard(
            context,
            context.l10n.creditTextTitle,
            context.l10n.creditTextBody,
            Icons.menu_book_rounded,
            AppColors.lilac,
          ),
          _creditCard(
            context,
            'Typefaces',
            context.l10n.creditFontsBody,
            Icons.text_fields_rounded,
            AppColors.star,
          ),
          _creditCard(
            context,
            context.l10n.creditWaqarTitle,
            context.l10n.creditWaqarBody,
            Icons.auto_stories_rounded,
            AppColors.tjMadd4,
          ),
          _creditCard(
            context,
            context.l10n.creditDigitalKhattTitle,
            context.l10n.creditDigitalKhattBody,
            Icons.brush_rounded,
            AppColors.tjQalqalah,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا',
              textDirection: TextDirection.rtl,
              style: arabicStyle(context,
                  size: 22, height: 1.6, color: pal(context).textDim),
            ),
          ),
        ],
      )),
    );
  }

  Widget _layoutCard(BuildContext context) {
    final s = SettingsScope.of(context);
    final opts = [
      ('auto', context.l10n.layoutAuto, Icons.devices_rounded),
      ('off', context.l10n.layoutMobile, Icons.smartphone_rounded),
      // The desktop shell needs real screen space to make sense — a phone
      // can't meaningfully offer it, tablets and up can.
      if (canUseDesktopShell(context))
        ('on', context.l10n.layoutDesktop, Icons.desktop_windows_rounded),
    ];
    // If a synced setting somehow left 'on' selected on a device that can no
    // longer offer it (e.g. this build's phone-vs-tablet rule changed since
    // it was set), fall back to auto rather than show a selection with no
    // matching option in the list above.
    if (s.desktopMode == 'on' && !canUseDesktopShell(context)) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => s.update(() => s.desktopMode = 'auto'));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.layout,
              style: uiStyle(context, size: 15.5, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            context.l10n.desktopModeShowsSidebarDashboard,
            style: uiStyle(context, size: 13, color: pal(context).textDim),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
                color: pal(context).bg, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final (val, label, icon) in opts)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => s.update(() => s.desktopMode = val),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: s.desktopMode == val
                              ? pal(context).accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Column(
                          children: [
                            Icon(icon,
                                size: 19,
                                color: s.desktopMode == val
                                    ? Colors.white
                                    : pal(context).textDim),
                            const SizedBox(height: 4),
                            Text(label,
                                style: uiStyle(context,
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: s.desktopMode == val
                                        ? Colors.white
                                        : pal(context).text)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard(BuildContext context) {
    final s = SettingsScope.of(context);
    const langs = [
      ('en', 'English'),
      ('ar', 'العربية'),
      ('ur', 'اردو'),
      ('fr', 'Français'),
      ('es', 'Español'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (code, label) in langs)
          ChoiceChip(
            label: Text(label),
            selected: s.language == code,
            selectedColor: pal(context).accent,
            backgroundColor: pal(context).surfaceHigh,
            labelStyle: uiStyle(context,
                size: 13.5,
                weight: FontWeight.w700,
                color: s.language == code ? Colors.white : pal(context).text),
            onSelected: (_) => s.update(() => s.language = code),
          ),
      ]),
    );
  }

  Widget _backupCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.everythingVeEarnedStarsStreak,
            style: uiStyle(context, size: 13, color: pal(context).textDim)
                .copyWith(height: 1.45)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: pal(context).accent,
                  side: BorderSide(color: pal(context).accent),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                final path = await BackupService.export();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                      content: Text(path == null
                          ? context.l10n.backupFailed
                          : context.l10n.backedUpTo(path))));
              },
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(context.l10n.backUp),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: pal(context).textDim,
                  side: BorderSide(color: pal(context).surfaceHigh),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () async {
                final ok = await BackupService.restore(
                    SettingsScope.of(context), ProgressScope.of(context));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                      content: Text(ok
                          ? context.l10n.backupRestored
                          : context.l10n.noBackupFound)));
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(context.l10n.restore),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _creditsCard(BuildContext context) {
    Widget line(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: uiStyle(context, size: 13.5, weight: FontWeight.w800)),
            Text(body,
                style: uiStyle(context, size: 12.5, color: pal(context).textDim)
                    .copyWith(height: 1.45)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(context.l10n.quranTextLabel,
            context.l10n.srcTextBody),
        line('Fonts',
            context.l10n.srcFontsBody),
        line(context.l10n.srcMushaf15Label,
            context.l10n.srcMushaf15Body),
        line('Recitation',
            context.l10n.srcRecitationBody),
        line(context.l10n.wordByWordLabel,
            context.l10n.srcWbwBody),
        line(context.l10n.qiraatBiosLabel,
            context.l10n.srcQiraatBody),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showLicensePage(
                context: context, applicationName: 'Qiraah Arabiyyah'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label:  Text(context.l10n.openSourceLicences),
          ),
        ),
      ]),
    );
  }

  Widget _colorCard(BuildContext context) {
    final s = SettingsScope.of(context);
    const opts = [
      ('mint', 'Green', Color(0xFF14C18E)),
      ('noor', 'Coral', Color(0xFFE96A4B)),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: pal(context).shadow,
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.color,
              style: uiStyle(context, size: 15.5, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(context.l10n.accentFamilyUsedAcrossWhole,
              style: uiStyle(context, size: 13, color: pal(context).textDim)),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (val, label, color) in opts)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => s.update(() => s.themeFamily = val),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: s.themeFamily == val
                              ? color.withValues(alpha: .14)
                              : pal(context).bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: s.themeFamily == val
                                  ? color
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(label,
                                style: uiStyle(context,
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: s.themeFamily == val
                                        ? color
                                        : pal(context).text)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String body) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Text(body,
            style: uiStyle(context,
                size: 14, color: pal(context).textDim)),
      );

  Widget _creditCard(BuildContext context, String title, String body,
          IconData icon, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: pal(context).shadow,
                blurRadius: 12,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: uiStyle(context,
                          size: 15.5, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(body,
                      style: uiStyle(context,
                          size: 13, color: pal(context).textDim)),
                ],
              ),
            ),
          ],
        ),
      );
}
