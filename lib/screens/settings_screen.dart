import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/marks/marks_store.dart';
import '../core/sync/sync_engine.dart';
import '../core/reader_size.dart';
import '../core/reminder.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import 'about_screen.dart';
import 'downloads_screen.dart';
import 'marks/mark_books_screen.dart';
import 'marks/sync_section.dart';
import 'mushaf/mushaf_style_screen.dart';
import 'onboarding_screen.dart';

/// Settings: theme and style, reading, recitation, learning, the app itself,
/// your data, and About. Two columns on a wide window.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: DecoratedBox(
        decoration: screenDecoration(context),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1080;
            final left = [
              _Theme(),
              _Style(),
              _App(),
              _Data(),
            ];
            final right = [
              _Reading(),
              _Recitation(),
              _Learning(),
              _About(),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                QColumn(
                  kind: ContentKind.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QPageHeader(
                        title: context.l10n.settings,
                        leading: canPop
                            ? QIconButton(
                                icon: AppIcons.back,
                                tooltip: MaterialLocalizations.of(context)
                                    .backButtonTooltip,
                                onTap: () => Navigator.of(context).maybePop())
                            : null,
                      ),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(children: left)),
                            const SizedBox(width: 32),
                            Expanded(child: Column(children: right)),
                          ],
                        )
                      else ...[
                        left[0],
                        left[1],
                        ...right,
                        left[2],
                        left[3],
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const OnboardingScreen(pushed: true)));
                          },
                          child: Text(context.l10n.showWelcomeAgain),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Section(this.label, this.children);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [QSectionLabel(label), ...children],
      );
}

// ───────────────────────────────────────────────────────── theme & style

class _Theme extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final opts = [
      ('light', context.l10n.themeLight, context.l10n.themeLightSub),
      ('mono', context.l10n.themeMono, context.l10n.themeMonoSub),
      ('night', context.l10n.themeNight, context.l10n.themeNightSub),
      ('oled', context.l10n.themeOled, context.l10n.themeOledSub),
    ];
    return _Section(context.l10n.theme, [
      LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 150).floor().clamp(2, 4);
        const gap = 10.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final (id, label, sub) in opts)
            SizedBox(
              width: w,
              child: _ThemeTile(
                palette: paletteOf(appThemeFrom(id)),
                label: label,
                sub: sub,
                selected: s.appTheme == id,
                onTap: () => s.setTheme(id),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _ThemeTile extends StatelessWidget {
  final Palette palette;
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile(
      {required this.palette,
      required this.label,
      required this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final t = palette;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: QCard(
        padding: const EdgeInsets.all(10),
        borderColor: selected ? p.acc : p.line2,
        borderWidth: selected ? 2 : 1,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.line2),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 5, width: 46, color: t.ink),
                      const SizedBox(height: 5),
                      Container(height: 4, width: 30, color: t.ink3),
                    ],
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: t.accBg, shape: BoxShape.circle),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: uiStyle(context, size: 14, weight: FontWeight.w700)),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: uiStyle(context, size: 11.5, color: p.ink3)),
              ]),
            ),
            QRadioDot(on: selected, size: 18),
          ]),
        ]),
      ),
    );
  }
}

class _Style extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    // Lite mode overrides the two below: they show off, and can't be
    // changed, while it's on (their own values come back after).
    return _Section(context.l10n.style, [
      QGroup(children: [
        QRow(
          title: context.l10n.liteMode,
          subtitle: context.l10n.liteModeSub,
          control: QSwitch(
              value: s.lite, onChanged: (v) => s.update(() => s.lite = v)),
        ),
        // Ornaments, border, margin and paper: on their own screen, with a
        // live page to judge them by.
        QRow(
          title: context.l10n.msTitle,
          subtitle: context.l10n.msTitleSub,
          chevron: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const MushafStyleScreen())),
        ),
        QRow(
          title: context.l10n.gradients,
          subtitle:
              s.lite ? context.l10n.liteOffNote : context.l10n.gradientsSub,
          control: QSwitch(
              value: s.useGradients,
              onChanged:
                  s.lite ? null : (v) => s.update(() => s.gradients = v)),
        ),
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── reading

class _Reading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = pal(context);
    final layout = s.readerLayout == 'mushaf'
        ? 'flow'
        : (s.wordByWord ? 'grid' : 'cards');
    final maxPx = useDesktop(context)
        ? readerMaxDesktopFor(MediaQuery.sizeOf(context).width)
        : kReaderMaxMobile;
    final px = readerPx(s).clamp(kReaderMinPx, maxPx);
    return _Section(context.l10n.reading, [
      QGroup(children: [
        if (s.theme == AppTheme.light)
          QRow(
            title: context.l10n.mushafPaper,
            subtitle: context.l10n.mushafPaperSub,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('cream', context.l10n.paperCream, null),
                ('white', context.l10n.paperWhite, null),
                ('madani', context.l10n.paperMadani, null),
                ('mono', context.l10n.paperMono, null),
              ],
              value: s.mushafPaper,
              onChanged: (v) => s.update(() => s.mushafPaper = v),
            ),
          ),
        if (s.theme == AppTheme.night || s.theme == AppTheme.oled)
          QRow(
            title: context.l10n.mushafPaper,
            subtitle: context.l10n.paperDarkSub,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('default', context.l10n.paperDefault, null),
                ('mono', context.l10n.paperMono, null),
              ],
              value: s.mushafPaperDark,
              onChanged: (v) => s.update(() => s.mushafPaperDark = v),
            ),
          ),
        QRow(
          title: context.l10n.arabicScript,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('uthmani', context.l10n.madani, null),
              ('indopak', context.l10n.indoPak, null),
            ],
            value: s.quranScript,
            onChanged: (v) => s.update(() {
              s.quranScript = v;
              s.mushafScript = v;
            }),
          ),
        ),
        QRow(
          title: context.l10n.readerLayout,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('cards', context.l10n.layoutAyahCards, null),
              ('grid', context.l10n.layoutWordGrid, null),
              ('flow', context.l10n.mushafFlow, null),
            ],
            value: layout,
            onChanged: (v) => s.update(() {
              s.readerLayout = v == 'flow' ? 'mushaf' : 'cards';
              s.wordByWord = v == 'grid';
            }),
          ),
        ),
        if (layout == 'grid') ...[
          QRow(
            title: context.l10n.wordsPerCard,
            control: QSegmented<int>(
              expand: false,
              options: [for (var i = 1; i <= 6; i++) (i, '$i', null)],
              value: s.wbwGroup,
              onChanged: (v) => s.update(() => s.wbwGroup = v),
            ),
          ),
          QRow(
            title: context.l10n.verseAlign,
            control: QSegmented<String>(
              expand: false,
              options: [
                ('right', context.l10n.alignRight, null),
                ('center', context.l10n.alignCenter, null),
              ],
              value: s.wbwAlign,
              onChanged: (v) => s.update(() => s.wbwAlign = v),
            ),
          ),
          QRow(
            title: context.l10n.eachCardOwnLine,
            control: QSwitch(
                value: s.wbwNewline,
                onChanged: (v) => s.update(() => s.wbwNewline = v)),
          ),
          QRow(
            title: context.l10n.gapBetweenCards,
            control: QStepper(
              label: '${s.wbwGap.round()}',
              minusChild: Icon(AppIcons.gapDecrease, size: 18, color: p.ink),
              plusChild: Icon(AppIcons.gapIncrease, size: 18, color: p.ink),
              onMinus: s.wbwGap <= 0
                  ? null
                  : () => s.update(() => s.wbwGap = (s.wbwGap - 4).clamp(0, 64)),
              onPlus: s.wbwGap >= 64
                  ? null
                  : () => s.update(() => s.wbwGap = (s.wbwGap + 4).clamp(0, 64)),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(context.l10n.arabicTextSize,
                    style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              ),
              QStepper(
                label: '${px.round()}',
                minusChild: Text('A−',
                    style: uiStyle(context, size: 13, weight: FontWeight.w700)),
                plusChild: Text('A+',
                    style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                onMinus: px <= kReaderMinPx
                    ? null
                    : () => setReaderPx(s, readerStepDown(px)),
                onPlus: px >= maxPx
                    ? null
                    : () => setReaderPx(s, readerStepUp(px, maxPx)),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: px > 72 ? 72 : px,
                      height: 1.8,
                      color: p.ink)),
            ),
          ]),
        ),
        QRow(
          title: context.l10n.tajwidColors,
          control: QSwitch(
              value: s.tajwidColors,
              onChanged: (v) => s.update(() => s.tajwidColors = v)),
        ),
        QRow(
          title: context.l10n.tashkilTermsLabel,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('arabic', context.l10n.arabicTerms, null),
              ('indopak', context.l10n.indopak, null),
            ],
            value: s.tashkilTerms,
            onChanged: (v) => s.update(() => s.tashkilTerms = v),
          ),
        ),
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── recitation

class _Recitation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _Section(context.l10n.recitation, [
      QGroup(children: [
        for (final (id, name) in [
          ('tunaiji', context.l10n.alTunaiji),
          ('alafasy', context.l10n.afasyName),
          ('husary', context.l10n.husaryName),
        ])
          QRadioRow(
            title: name,
            subtitle: id == 'tunaiji' ? null : context.l10n.wordHighlighting,
            selected: s.reciter == id,
            onTap: () => s.update(() => s.reciter = id),
          ),
      ]),
      const SizedBox(height: 10),
      QGroup(children: [
        QRow(
          title: context.l10n.afterVerse,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('single', context.l10n.flowStop, null),
              ('auto', context.l10n.flowContinue, null),
              ('repeat', context.l10n.flowRepeat, null),
            ],
            value: s.reciteFlow,
            onChanged: (v) => s.update(() => s.reciteFlow = v),
          ),
        ),
        QRow(
          title: context.l10n.playbackSpeed,
          control: QSegmented<double>(
            expand: false,
            options: const [(0.75, '0.75×', null), (1.0, '1×', null), (1.25, '1.25×', null)],
            value: s.playbackSpeed,
            onChanged: (v) => s.update(() => s.playbackSpeed = v),
          ),
        ),
        QRow(
          title: context.l10n.followAlong,
          subtitle: context.l10n.followAlongSub,
          control: QSwitch(
              value: s.followAlong,
              onChanged: (v) => s.update(() => s.followAlong = v)),
        ),
        QRow(
          title: context.l10n.audioPlayer,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('pinned', context.l10n.playerPinned, null),
              ('floating', context.l10n.playerFloating, null),
              ('hidden', context.l10n.playerHidden, null),
            ],
            value: s.playerDock,
            onChanged: (v) => s.update(() => s.playerDock = v),
          ),
        ),
        QRow(
          title: context.l10n.manageDownloads,
          subtitle: context.l10n.downloadsIntro,
          chevron: true,
          onTap: () => pushAdaptive(context, const DownloadsScreen()),
        ),
      ]),
    ]);
  }
}

// ───────────────────────────────────────────────────────── learning

class _Learning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = TimeOfDay(hour: s.reminderMinutes ~/ 60, minute: s.reminderMinutes % 60);
    return _Section(context.l10n.learning, [
      QGroup(children: [
        QRow(
          title: context.l10n.dailyGoal,
          control: QSegmented<int>(
            expand: false,
            options: [
              for (final m in const [5, 10, 15, 20])
                (m, context.l10n.minutesShort(m), null)
            ],
            value: s.dailyGoalMinutes,
            onChanged: (v) => s.update(() => s.dailyGoalMinutes = v),
          ),
        ),
        if (DailyReminder.supported) ...[
          QRow(
            title: context.l10n.dailyReminder,
            subtitle: context.l10n.dailyReminderSub,
            control: QSwitch(
              value: s.reminderOn,
              onChanged: (v) => setReminder(context, v),
            ),
          ),
          if (s.reminderOn)
            QRow(
              title: context.l10n.reminderTime,
              control: QOutlineButton(t.format(context), onTap: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: t);
                if (picked == null || !context.mounted) return;
                s.update(() => s.reminderMinutes = picked.hour * 60 + picked.minute);
                await setReminder(context, true);
              }),
            ),
        ],
      ]),
    ]);
  }
}

/// Turns the daily reminder on (asking for permission) or off, and says so
/// when the system refuses.
Future<void> setReminder(BuildContext context, bool on) async {
  final s = SettingsScope.of(context);
  if (!on) {
    s.update(() => s.reminderOn = false);
    await DailyReminder.disable();
    return;
  }
  final title = context.l10n.reminderTitle;
  final body = context.l10n.reminderBody;
  final denied = context.l10n.reminderDenied;
  final ok = await DailyReminder.enable(
      minutesOfDay: s.reminderMinutes, title: title, body: body);
  s.update(() => s.reminderOn = ok);
  if (!ok && context.mounted) showQToast(context, denied);
}

// ───────────────────────────────────────────────────────── app & data

class _App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    const langs = [
      ('en', 'English'),
      ('ar', 'العربية'),
      ('ur', 'اردو'),
      ('fr', 'Français'),
      ('es', 'Español'),
    ];
    final layouts = [
      ('auto', context.l10n.layoutAuto, AppIcons.devices),
      ('off', context.l10n.layoutMobile, AppIcons.phone),
      if (canUseDesktopShell(context))
        ('on', context.l10n.layoutDesktop, AppIcons.desktop),
    ];
    return _Section(context.l10n.appSection, [
      QGroup(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.language,
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (code, label) in langs)
                ChoiceChip(
                  label: Text(label),
                  selected: s.language == code,
                  showCheckmark: false,
                  onSelected: (_) => s.update(() => s.language = code),
                ),
            ]),
          ]),
        ),
        if (canUseDesktopShell(context))
          QRow(
            title: context.l10n.layout,
            subtitle: context.l10n.desktopModeShowsSidebarDashboard,
            control: QSegmented<String>(
              expand: false,
              options: [for (final l in layouts) (l.$1, l.$2, l.$3)],
              value: s.desktopMode == 'on' && !canUseDesktopShell(context)
                  ? 'auto'
                  : s.desktopMode,
              onChanged: (v) => s.update(() => s.desktopMode = v),
            ),
          ),
        if (!isDesktopPlatform())
          QRow(
            title: context.l10n.immersiveHideSystemBars,
            control: QSwitch(
                value: s.immersive,
                onChanged: (v) => s.update(() => s.immersive = v)),
          ),
        QRow(
          title: context.l10n.hapticFeedback,
          control: QSwitch(
              value: s.haptics, onChanged: (v) => s.update(() => s.haptics = v)),
        ),
      ]),
    ]);
  }
}

class _Data extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return _Section(context.l10n.yourData, [
      QCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.everythingVeEarnedStarsStreak,
              style: uiStyle(context, size: 13, color: p.ink2, height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            QOutlineButton(context.l10n.backUp,
                icon: AppIcons.upload, onTap: () async {
              final path = await BackupService.export(SettingsScope.of(context),
                  marks: MarksScope.maybeOf(context));
              if (!context.mounted) return;
              showQToast(
                  context,
                  path == null
                      ? context.l10n.backupFailed
                      : context.l10n.backedUpTo(path));
            }),
            QOutlineButton(context.l10n.restore,
                icon: AppIcons.download, onTap: () async {
              final ok = await BackupService.restore(
                  SettingsScope.of(context), ProgressScope.read(context),
                  marks: MarksScope.maybeOf(context));
              if (!context.mounted) return;
              showQToast(context,
                  ok ? context.l10n.backupRestored : context.l10n.noBackupFound);
            }),
          ]),
        ]),
      ),
      if (MarksScope.maybeOf(context) != null) ...[
        const SizedBox(height: 10),
        QGroup(children: [
          QRow(
            title: context.l10n.mkManageBooks,
            leading: Icon(AppIcons.person, color: p.ink3),
            chevron: true,
            onTap: () => pushAdaptive(context, const MarkBooksScreen()),
          ),
          if (SyncScope.maybeOf(context) != null)
            QRow(
              title: context.l10n.mkAccountSync,
              subtitle: SyncScope.maybeOf(context)!.account?.username,
              leading: Icon(AppIcons.cloud, color: p.ink3),
              chevron: true,
              onTap: () => pushAdaptive(context, const AccountScreen()),
            ),
        ]),
      ],
    ]);
  }
}

class _About extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Section(context.l10n.about, [
        QGroup(children: [
          QRow(
            title: context.l10n.aboutQiraah,
            subtitle: context.l10n.creditsGratitude,
            chevron: true,
            onTap: () => pushAdaptive(context, const AboutScreen()),
          ),
          QRow(
            title: context.l10n.openSourceLicences,
            chevron: true,
            onTap: () => showLicensePage(
                context: context, applicationName: 'Qiraah Arabiyyah'),
          ),
        ]),
      ]);
}
