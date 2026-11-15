import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/keymap.dart';
import '../core/l10n.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/adaptive_sheet.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';

/// Keyboard shortcuts: what each key does, and changing it.
Future<void> showKeyboardSheet(BuildContext context, {bool rootNavigator = true}) =>
    showAdaptiveSheet<void>(
      context,
      useRootNavigator: rootNavigator,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: AdaptiveSheet.isSide(sheet) ? 1 : .9,
        child: const KeyboardSheet(),
      ),
    );

String keyActionLabel(AppLocalizations l, KeyAction a) => switch (a) {
      KeyAction.nextPage => l.kaNextPage,
      KeyAction.prevPage => l.kaPrevPage,
      KeyAction.togglePages => l.kaTogglePages,
      KeyAction.bookmarkPage => l.bmPage,
      KeyAction.review => l.rvReview,
      KeyAction.memorize => l.mzMemorize,
      KeyAction.recitation => l.recitation,
      KeyAction.follow => l.followTitle,
      KeyAction.history => l.hsTitle,
      KeyAction.openIndex => l.idxIndex,
      KeyAction.search => l.kaSearch,
      KeyAction.goToPage => l.kaGoToPage,
      KeyAction.playPause => l.kaPlayPause,
      KeyAction.markMode => l.tcMark,
      KeyAction.undo => l.mkUndo,
      KeyAction.redo => l.kaRedo,
      KeyAction.pen1 => l.mkMistake,
      KeyAction.pen2 => l.mkTajwid,
      KeyAction.pen3 => l.mkHesitation,
      KeyAction.pen4 => l.mkDoubt,
      KeyAction.pen5 => l.mkNote,
      KeyAction.zoomIn => l.kaZoomIn,
      KeyAction.zoomOut => l.kaZoomOut,
      KeyAction.zoomReset => l.kaZoomReset,
      KeyAction.fullscreen => l.kaFullscreen,
      KeyAction.darkMode => l.kaDarkMode,
      KeyAction.settings => l.settings,
      KeyAction.export => l.tcExport,
      KeyAction.shortcuts => l.kaShortcuts,
      KeyAction.leave => l.kaLeave,
      KeyAction.memoNextWord => l.mzNextWord,
      KeyAction.memoPrevWord => l.kaMemoPrevWord,
      KeyAction.memoNextVerse => l.kaMemoNextVerse,
      KeyAction.memoPrevVerse => l.kaMemoPrevVerse,
      KeyAction.memoNextPage => l.kaMemoNextPage,
      KeyAction.memoPlay => l.kaMemoPlay,
      KeyAction.memoPlayPage => l.kaMemoPlayPage,
      KeyAction.reviewNext => l.kaReviewNext,
      KeyAction.reviewPrev => l.kaReviewPrev,
      KeyAction.reviewRepeat => l.kaReviewRepeat,
      KeyAction.reviewRepeatVerse => l.kaReviewRepeatVerse,
      KeyAction.reviewFix => l.mkMarkFixed,
      KeyAction.toggleLayout => l.layout,
      KeyAction.fluencyInstant => l.flInstant,
      KeyAction.fluencySlow => l.flSlowRead,
      KeyAction.fluencyWrong => l.flWrong,
    };

String mouseActionLabel(AppLocalizations l, MouseAction a) => switch (a) {
      MouseAction.stepMark => l.kaMouseStep,
      MouseAction.fluencyStep => l.kaMouseFluency,
      MouseAction.comment => l.kaMouseComment,
      MouseAction.menu => l.kaMouseMenu,
      MouseAction.nextPage => l.kaNextPage,
      MouseAction.prevPage => l.kaPrevPage,
      MouseAction.zoom => l.kaMouseZoom,
      MouseAction.pan => l.kaMousePan,
    };

String _groupLabel(AppLocalizations l, KeyGroup g) => switch (g) {
      KeyGroup.pages => l.kaGroupPages,
      KeyGroup.marks => l.tcMark,
      KeyGroup.view => l.hzView,
      KeyGroup.memorize => l.mzMemorize,
      KeyGroup.review => l.rvReview,
    };

class KeyboardSheet extends StatelessWidget {
  const KeyboardSheet({super.key});

  Future<void> _rebind(BuildContext context, AppSettings s, KeyAction a) async {
    final combo = await showDialog<KeyCombo>(
      context: context,
      builder: (_) => _CaptureDialog(title: keyActionLabel(context.l10n, a)),
    );
    if (combo == null || !context.mounted) return;
    final km = s.keymap;
    final clash = km.clashOf(a, combo);
    if (clash != null) {
      final l = context.l10n;
      final swap = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(l.kaClash(combo.label, keyActionLabel(l, clash))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(l.kaSwap)),
          ],
        ),
      );
      if (swap != true) return;
      final mine = km.combosOf(a).first;
      s.update(() => s.keyBindings[clash.name] = mine.encode());
    }
    s.update(() => s.keyBindings[a.name] = combo.encode());
  }

  Future<void> _rebindMouse(BuildContext context, AppSettings s, MouseAction a) async {
    final combo = await showDialog<MouseCombo>(
      context: context,
      builder: (_) => _MouseCaptureDialog(
          title: mouseActionLabel(context.l10n, a), scroll: a == MouseAction.zoom),
    );
    if (combo == null || !context.mounted) return;
    final km = s.keymap;
    final clash = km.mouseClashOf(a, combo);
    if (clash != null) {
      final l = context.l10n;
      final swap = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          content: Text(l.kaClash(combo.label, mouseActionLabel(l, clash))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(l.kaSwap)),
          ],
        ),
      );
      if (swap != true) return;
      final mine = km.mouseOf(a);
      s.update(() => s.keyBindings[Keymap.mouseKey(clash)] = mine.encode());
    }
    s.update(() => s.keyBindings[Keymap.mouseKey(a)] = combo.encode());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    final s = SettingsScope.of(context);
    final km = s.keymap;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(children: [
          Expanded(child: Text(l.kaTitle, style: displayStyle(context, size: 24))),
          if (s.keyBindings.isNotEmpty)
            TextButton(
              onPressed: () => s.update(s.keyBindings.clear),
              child: Text(l.kaResetAll),
            ),
        ]),
        for (final g in KeyGroup.values) ...[
          QSectionLabel(_groupLabel(l, g)),
          for (final a in KeyAction.values)
            if (a.group == g)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                      child: Text(keyActionLabel(l, a), style: uiStyle(context, size: 14))),
                  if (km.isCustom(a))
                    IconButton(
                      tooltip: l.kaReset,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => s.update(() => s.keyBindings.remove(a.name)),
                      icon: Icon(AppIcons.undo, size: 16, color: p.ink3),
                    ),
                  OutlinedButton(
                    key: ValueKey('key-${a.name}'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () => _rebind(context, s, a),
                    child: Text(km.allLabels(a),
                        style: uiStyle(context, size: 13, weight: FontWeight.w600)),
                  ),
                ]),
              ),
        ],
        QSectionLabel(l.kaGroupMouse),
        for (final a in MouseAction.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                  child: Text(mouseActionLabel(l, a), style: uiStyle(context, size: 14))),
              if (km.isMouseCustom(a))
                IconButton(
                  tooltip: l.kaReset,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => s.update(() => s.keyBindings.remove(Keymap.mouseKey(a))),
                  icon: Icon(AppIcons.undo, size: 16, color: p.ink3),
                ),
              OutlinedButton(
                key: ValueKey('mouse-${a.name}'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: () => _rebindMouse(context, s, a),
                child: Text(km.mouseOf(a).label,
                    style: uiStyle(context, size: 13, weight: FontWeight.w600)),
              ),
            ]),
          ),
      ],
    );
  }
}

class _CaptureDialog extends StatelessWidget {
  final String title;
  const _CaptureDialog({required this.title});

  static final _modifiers = {
    LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
    LogicalKeyboardKey.alt, LogicalKeyboardKey.meta,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.handled;
        if (_modifiers.contains(e.logicalKey)) return KeyEventResult.handled;
        final k = HardwareKeyboard.instance;
        Navigator.pop(
            context,
            KeyCombo(e.logicalKey,
                ctrl: k.isControlPressed || k.isMetaPressed,
                shift: k.isShiftPressed,
                alt: k.isAltPressed));
        return KeyEventResult.handled;
      },
      child: AlertDialog(
        title: Text(title),
        content: Text(l.kaPress),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ],
      ),
    );
  }
}

/// A mouse button pressed here, or (the zoom's) a key held and the wheel turned.
class _MouseCaptureDialog extends StatefulWidget {
  final String title;
  final bool scroll;
  const _MouseCaptureDialog({required this.title, required this.scroll});

  @override
  State<_MouseCaptureDialog> createState() => _MouseCaptureDialogState();
}

class _MouseCaptureDialogState extends State<_MouseCaptureDialog> {
  bool _refused = false;

  void _take(int button) {
    final k = HardwareKeyboard.instance;
    final combo = MouseCombo(button,
        ctrl: k.isControlPressed || k.isMetaPressed,
        shift: k.isShiftPressed,
        alt: k.isAltPressed);
    if (combo.isReserved) {
      setState(() => _refused = true);
    } else {
      Navigator.pop(context, combo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = pal(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Listener(
        key: const ValueKey('mouse-capture'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.scroll ? null : (e) => _take(e.buttons),
        onPointerSignal: !widget.scroll
            ? null
            : (e) {
                if (e is PointerScrollEvent) _take(MouseCombo.scroll);
              },
        child: Container(
          height: 110,
          width: 280,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.line2),
          ),
          child: Text(
            _refused
                ? (widget.scroll ? l.kaPlainScroll : l.kaPlainClick)
                : (widget.scroll ? l.kaScrollHere : l.kaClickHere),
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 13.5, color: _refused ? p.acc : p.ink2),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
      ],
    );
  }
}
