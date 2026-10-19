import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import 'app_icons.dart';
import 'qiraah_ornaments.dart';

/// The redesign's building blocks (design_handoff_qiraah_flutter). Every
/// colour comes from [pal]; nothing here hard-codes a theme.

// ───────────────────────────────────────────────────────── colour helpers

/// An OKLCH colour (the prototype tints module tiles and tajwīd chips this
/// way: a hue angle at fixed lightness and chroma) converted to sRGB.
Color oklch(double l, double c, double hueDeg) {
  final h = hueDeg * math.pi / 180;
  final a = c * math.cos(h), b = c * math.sin(h);
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
  final ll = l_ * l_ * l_, mm = m_ * m_ * m_, ss = s_ * s_ * s_;
  final r = 4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss;
  final g = -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss;
  final bl = -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss;
  int ch(double x) {
    final v = x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
    return (v.clamp(0.0, 1.0) * 255).round();
  }

  return Color.fromARGB(255, ch(r), ch(g), ch(bl));
}

/// A hue-tinted tile: soft background and strong foreground, per theme.
({Color bg, Color fg, Color border}) hueTint(BuildContext context, double h) {
  final dark = pal(context).isDark;
  if (pal(context).theme == AppTheme.mono) {
    final p = pal(context);
    return (bg: p.track, fg: p.ink, border: p.line3);
  }
  return dark
      ? (
          bg: oklch(.25, .045, h),
          fg: oklch(.82, .12, h),
          border: oklch(.36, .07, h),
        )
      : (
          bg: oklch(.95, .03, h),
          fg: oklch(.45, .1, h),
          border: oklch(.87, .06, h),
        );
}

QGradients gradientsOf(BuildContext context) =>
    QGradients.of(SettingsScope.of(context).theme);

bool gradientsOn(BuildContext context) =>
    SettingsScope.of(context).useGradients;

/// Lite mode is on (see [AppSettings.lite]).
bool liteOn(BuildContext context) => SettingsScope.of(context).lite;

/// Whether to skip animations: Lite mode, or the system's "remove
/// animations" setting (Lite mode sets MediaQuery's flag for the whole app,
/// so this one check covers both).
bool noMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [d], or zero when animations are off (see [noMotion]).
Duration motion(BuildContext context, Duration d) =>
    noMotion(context) ? Duration.zero : d;

/// [shadows], or none in Lite mode: blurred shadows are among the costliest
/// things a slow GPU draws, and nothing depends on them.
List<BoxShadow>? qShadows(BuildContext context, List<BoxShadow>? shadows) =>
    liteOn(context) ? null : shadows;

/// The screen background: a near-flat gradient, or flat when Gradients is off.
BoxDecoration screenDecoration(BuildContext context) {
  final g = gradientsOf(context);
  return gradientsOn(context)
      ? BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: g.screen,
          ),
        )
      : BoxDecoration(color: pal(context).bg);
}

BoxDecoration heroDecoration(BuildContext context, {double radius = 22}) {
  final g = gradientsOf(context);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: gradientsOn(context) ? null : g.heroFlat,
    gradient: gradientsOn(context)
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: g.hero,
            stops: const [0, .55, 1],
          )
        : null,
  );
}

/// Text and accents on the hero card: cream and gold.
const kHeroInk = Color(0xFFF2EEE4);
const kHeroInk2 = Color(0xFFB7CFC6);
const kHeroGold = Color(0xFFE3C27A);

// ───────────────────────────────────────────────────────── layout

/// A content column: max 760px (1080 with the desktop sidebar collapsed),
/// centred, with side padding of at least 16.
class QColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const QColumn({super.key, required this.child, this.maxWidth = 760});

  // The child always gets the column's full width, so a narrow child (a Wrap
  // of chips, a short label) starts at the column's edge instead of centring.
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// A page: the screen background, an optional big title, and a scrolling
/// column of [children].
class QPage extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? leading;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsets padding;
  final ScrollController? controller;
  const QPage({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.leading,
    this.actions = const [],
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: screenDecoration(context),
      child: SafeArea(
        bottom: false,
        child: ListView(
          controller: controller,
          padding: padding,
          children: [
            QColumn(
              maxWidth: maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null || leading != null || actions.isNotEmpty)
                    QPageHeader(
                      title: title,
                      subtitle: subtitle,
                      leading: leading,
                      actions: actions,
                    ),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen with a back button: [QPage] inside a [Scaffold].
class QScreen extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final double maxWidth;
  final bool back;
  const QScreen({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.maxWidth = 760,
    this.back = true,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pal(context).bg,
    body: QPage(
      title: title,
      subtitle: subtitle,
      maxWidth: maxWidth,
      leading: back && Navigator.of(context).canPop()
          ? QIconButton(
              icon: AppIcons.back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: actions,
      children: children,
    ),
  );
}

/// Title (Source Serif 4 30) with an optional subtitle, a leading button and
/// trailing actions.
class QPageHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  const QPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null || actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ?leading,
                  const Spacer(),
                  for (final a in actions)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: a,
                    ),
                ],
              ),
            ),
          if (title != null)
            Text(title!, style: displayStyle(context, size: 30)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                subtitle!,
                style: uiStyle(context, size: 14, color: p.ink2, height: 1.45),
              ),
            ),
        ],
      ),
    );
  }
}

/// Section label: 12/700 uppercase, `mut`.
class QSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsets padding;
  const QSectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(2, 22, 2, 10),
  });

  @override
  Widget build(BuildContext context) {
    final upper = SettingsScope.of(context).language;
    final latin = upper == 'en' || upper == 'fr' || upper == 'es';
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              latin ? text.toUpperCase() : text,
              style: labelStyle(context),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── surfaces

/// A card: radius 20, `card` fill, 1px `line2` border.
class QCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  const QCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? p.line2, width: borderWidth),
    );
    final body = Padding(padding: padding, child: child);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color ?? p.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// The deep-green feature card (hero gradient).
class QHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  const QHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final body = DecoratedBox(
      decoration: heroDecoration(context, radius: radius),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

/// A grouped card of rows, divided by 1px `line2`.
class QGroup extends StatelessWidget {
  final List<Widget> children;
  const QGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: p.line2),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A settings-style row: title 15/700, optional subtitle 12 `ink3`, and a
/// control that wraps below the text when the row is narrow.
class QRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? control;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;
  const QRow({
    super.key,
    required this.title,
    this.subtitle,
    this.control,
    this.leading,
    this.onTap,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: uiStyle(context, size: 12, color: p.ink3, height: 1.4),
            ),
          ),
      ],
    );
    final row = LayoutBuilder(
      builder: (context, c) {
        final narrow = control != null && c.maxWidth < 420;
        final head = Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: leading!,
              ),
            Expanded(child: text),
            if (control != null && !narrow)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: control!,
              ),
            if (chevron)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Icon(AppIcons.chevronRight, size: 18, color: p.ink3),
              ),
          ],
        );
        if (!narrow) return head;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: control!),
          ],
        );
      },
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: row,
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

// ───────────────────────────────────────────────────────── controls

/// A 40px round icon button with a 1px `line` border.
class QIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool active;
  final Color? color;
  final bool border;
  const QIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.active = false,
    this.color,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final btn = Material(
      color: active ? p.accBg : (color ?? p.card),
      shape: CircleBorder(
        side: border && !active ? BorderSide(color: p.line) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: iconSize,
            color: active ? Colors.white : (onTap == null ? p.dim : p.ink2),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// The filled primary button (primary gradient, or `accBg` when flat).
class QPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;
  const QPrimaryButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.height = 48,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final g = gradientsOf(context);
    final on = gradientsOn(context) && onTap != null;
    final body = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: onTap == null ? p.line3 : (on ? null : g.primaryFlat),
        gradient: on
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: g.primary,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiStyle(
                context,
                size: 15,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(height / 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

/// The outlined secondary button.
class QOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final Color? color;
  const QOutlineButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.height = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final c = color ?? p.ink;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: p.line3)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: c),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(
                    context,
                    size: 14,
                    weight: FontWeight.w700,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A segmented control: `track` background, the selected segment on `segOn`.
class QSegmented<T> extends StatelessWidget {
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final bool expand;
  const QSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 38,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget seg((T, String, IconData?) o) {
      final on = o.$1 == value;
      final child = AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 200)),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.segOn : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: on && !p.isDark
              ? qShadows(context, const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ])
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (o.$3 != null) ...[
              Icon(o.$3, size: 16, color: on ? p.acc : p.ink3),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                o.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(
                  context,
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: on ? p.ink : p.ink2,
                ),
              ),
            ),
          ],
        ),
      );
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(o.$1),
          child: child,
        ),
      );
    }

    final box = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final o in options) expand ? Expanded(child: seg(o)) : seg(o),
        ],
      ),
    );
    if (expand) return box;
    // Sized to its options; on a very narrow screen it scrolls sideways
    // rather than overflowing.
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: box);
  }
}

/// A pill stepper: [−] value [+].
class QStepper extends StatelessWidget {
  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final Widget? minusChild;
  final Widget? plusChild;
  final double height;
  final String? minusTooltip;
  final String? plusTooltip;
  const QStepper({
    super.key,
    required this.label,
    this.onMinus,
    this.onPlus,
    this.minusChild,
    this.plusChild,
    this.height = 40,
    this.minusTooltip,
    this.plusTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Widget btn(VoidCallback? f, Widget? child, String fallback, String? tip) {
      final b = InkWell(
        onTap: f,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: height - 6,
          child: Center(
            child:
                child ??
                Text(
                  fallback,
                  style: uiStyle(
                    context,
                    size: 17,
                    weight: FontWeight.w700,
                    color: f == null ? p.dim : p.ink,
                  ),
                ),
          ),
        ),
      );
      return tip == null ? b : Tooltip(message: tip, child: b);
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(onMinus, minusChild, '−', minusTooltip),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 13, weight: FontWeight.w700),
            ),
          ),
          btn(onPlus, plusChild, '+', plusTooltip),
        ],
      ),
    );
  }
}

/// A rounded tile holding an Arabic glyph, tinted by [hue] (OKLCH degrees).
class QGlyphTile extends StatelessWidget {
  final String glyph;
  final double hue;
  final double size;
  final double radius;
  const QGlyphTile(
    this.glyph, {
    super.key,
    required this.hue,
    this.size = 48,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final t = hueTint(context, hue);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        glyph,
        textDirection: TextDirection.rtl,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: size * .42,
          height: 1.2,
          color: t.fg,
        ),
      ),
    );
  }
}

/// A small uppercase tag (e.g. "7 RULES", "SOON").
class QTag extends StatelessWidget {
  final String text;
  final Color? color;
  const QTag(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? p.acc).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: uiStyle(
          context,
          size: 10.5,
          weight: FontWeight.w700,
          letterSpacing: .6,
          color: color ?? p.acc,
        ),
      ),
    );
  }
}

/// A thin progress bar: 4px, `line2` track, accent fill.
class QProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? track;
  final double height;
  const QProgressBar({
    super.key,
    required this.value,
    this.color,
    this.track,
    this.height = 4,
  });
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track ?? p.line2)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? p.acc),
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty state: a soft circle with an icon, a Source Serif 4 title, a hint and
/// an optional action. Rises in.
class QEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final Widget? action;
  final double circle;
  const QEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
    this.circle = 72,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QRiseIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
        child: Column(
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: p.accSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: circle * .4, color: p.accInk),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: displayStyle(context, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: uiStyle(context, size: 14, color: p.ink2, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Opacity plus an 8px rise, 280ms.
class QRiseIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const QRiseIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280) + delay,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A toast: a floating snackbar for 2.4s.
void showQToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2400),
      ),
    );
}

/// A radio dot (filled ring when selected).
class QRadioDot extends StatelessWidget {
  final bool on;
  final double size;
  const QRadioDot({super.key, required this.on, this.size = 20});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? p.acc : p.line3,
          width: on ? size * .3 : 1.5,
        ),
        color: p.card,
      ),
    );
  }
}

/// A choice row with a radio dot (reciter lists and the like).
class QRadioRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const QRadioRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => QRow(
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    control: QRadioDot(on: selected),
  );
}

/// A Material [Switch] in the redesign's colours (white knob).
class QSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged; // null: shown disabled
  const QSwitch({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) =>
      Switch(value: value, onChanged: onChanged);
}

/// A slider bound to a setting. The thumb follows the finger locally; the
/// setting (which rebuilds everything that reads it) is written at most every
/// [every] while dragging, and once more when the drag ends.
class SettingsSlider extends StatefulWidget {
  final double value, min, max;
  final ValueChanged<double> onCommit;
  final Duration every;
  const SettingsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.every = const Duration(milliseconds: 150),
  });

  @override
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  double? _drag;
  DateTime _last = DateTime(0);

  @override
  Widget build(BuildContext context) => Slider(
        value: (_drag ?? widget.value).clamp(widget.min, widget.max),
        min: widget.min,
        max: widget.max,
        onChanged: (v) {
          setState(() => _drag = v);
          final now = DateTime.now();
          if (now.difference(_last) >= widget.every) {
            _last = now;
            widget.onCommit(v);
          }
        },
        onChangeEnd: (v) {
          widget.onCommit(v);
          setState(() => _drag = null);
        },
      );
}
