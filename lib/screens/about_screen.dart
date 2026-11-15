import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../ui/app_icons.dart';
import '../ui/brand.dart';
import '../ui/kit.dart';

/// About — what Rāsikh is for, where its text, audio and fonts
/// come from, and who we thank. (The settings that used to live here are in
/// Settings.)
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget credit(String title, String body, IconData icon, double hue) {
      final t = hueTint(context, hue);
      return QCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: t.bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: t.fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body,
                  style: uiStyle(context, size: 13, color: p.ink2, height: 1.45)),
            ]),
          ),
        ]),
      );
    }

    Widget source(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: uiStyle(context, size: 14, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body,
                style: uiStyle(context, size: 12.5, color: p.ink2, height: 1.45)),
          ]),
        );

    return QScreen(
      back: !embedded,
      children: [
        QHeroCard(
          child: Row(children: [
            const AppLogoTile(
                size: 56, radius: 16, inset: 7, glyph: kHeroInk,
                background: Color(0x14F2EEE4)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.appName,
                    style: displayStyle(context, size: 26, color: kHeroInk)),
                const SizedBox(height: 4),
                Text(context.l10n.completeJourneyQurAnicArabic,
                    style: uiStyle(context, size: 13.5, color: kHeroInk2, height: 1.45)),
              ]),
            ),
          ]),
        ),
        QSectionLabel(context.l10n.whatThisAppTeaches),
        QCard(
          child: Text(context.l10n.aboutBody,
              style: uiStyle(context, size: 14, color: p.ink2, height: 1.5)),
        ),
        QSectionLabel(context.l10n.sourcesLicences),
        QCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            source(context.l10n.quranTextLabel, context.l10n.srcTextBody),
            source(context.l10n.fonts, context.l10n.srcFontsBody),
            source(context.l10n.srcMushaf15Label, context.l10n.srcMushaf15Body),
            source(context.l10n.recitation, context.l10n.srcRecitationBody),
            source(context.l10n.wordByWordLabel, context.l10n.srcWbwBody),
            source(context.l10n.qiraatBiosLabel, context.l10n.srcQiraatBody),
            QOutlineButton(context.l10n.openSourceLicences,
                icon: AppIcons.document,
                onTap: () => showLicensePage(
                    context: context, applicationName: context.l10n.appName)),
          ]),
        ),
        QSectionLabel(context.l10n.creditsGratitude),
        credit('Markaz Tafsir', context.l10n.creditMarkazBody, AppIcons.recite, 165),
        credit('Shaykh Khalifah Al-Tunaiji', context.l10n.creditTunaijiBody,
            AppIcons.volume, 75),
        credit(context.l10n.creditTextTitle, context.l10n.creditTextBody,
            AppIcons.reader, 280),
        credit(context.l10n.typefaces, context.l10n.creditFontsBody,
            AppIcons.textSize, 50),
        credit(context.l10n.creditWaqarTitle, context.l10n.creditWaqarBody,
            AppIcons.mushaf, 28),
        credit(context.l10n.creditDigitalKhattTitle,
            context.l10n.creditDigitalKhattBody, AppIcons.brush, 230),
        credit(context.l10n.followTitle, context.l10n.followCredit, AppIcons.mic, 200),
        const SizedBox(height: 18),
        Center(
          child: Text('وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 22,
                  height: 1.8,
                  color: p.dim)),
        ),
      ],
    );
  }
}
