import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// What a key can do. Each has its default keys ([kDefaultKeys]); settings keep
/// only what's been changed.
enum KeyAction {
  nextPage(KeyGroup.pages),
  prevPage(KeyGroup.pages),
  togglePages(KeyGroup.pages),
  bookmarkPage(KeyGroup.pages),
  review(KeyGroup.pages),
  memorize(KeyGroup.pages),
  recitation(KeyGroup.pages),
  follow(KeyGroup.pages),
  history(KeyGroup.view),
  openIndex(KeyGroup.pages),
  search(KeyGroup.pages),
  goToPage(KeyGroup.pages),
  playPause(KeyGroup.pages),
  markMode(KeyGroup.marks),
  undo(KeyGroup.marks),
  redo(KeyGroup.marks),
  pen1(KeyGroup.marks),
  pen2(KeyGroup.marks),
  pen3(KeyGroup.marks),
  pen4(KeyGroup.marks),
  pen5(KeyGroup.marks),
  zoomIn(KeyGroup.view),
  zoomOut(KeyGroup.view),
  zoomReset(KeyGroup.view),
  fullscreen(KeyGroup.view),
  darkMode(KeyGroup.view),
  settings(KeyGroup.view),
  export(KeyGroup.view),
  shortcuts(KeyGroup.view),
  leave(KeyGroup.view),
  toggleLayout(KeyGroup.view),
  memoNextWord(KeyGroup.memorize),
  memoPrevWord(KeyGroup.memorize),
  memoNextVerse(KeyGroup.memorize),
  memoPrevVerse(KeyGroup.memorize),
  memoNextPage(KeyGroup.memorize),
  memoPlay(KeyGroup.memorize),
  memoPlayPage(KeyGroup.memorize),
  reviewNext(KeyGroup.review),
  reviewPrev(KeyGroup.review),
  reviewRepeat(KeyGroup.review),
  reviewRepeatVerse(KeyGroup.review),
  reviewFix(KeyGroup.review),
  fluencyInstant(KeyGroup.review),
  fluencySlow(KeyGroup.review),
  fluencyWrong(KeyGroup.review);

  final KeyGroup group;
  const KeyAction(this.group);

  /// Which others a key can't be shared with: while memorizing or reviewing
  /// the keys are that mode's own first, so those may reuse the page's.
  bool clashesWith(KeyAction o) {
    bool everywhere(KeyGroup g) =>
        g == KeyGroup.pages || g == KeyGroup.marks || g == KeyGroup.view;
    return everywhere(group) ? everywhere(o.group) : group == o.group;
  }
}

enum KeyGroup { pages, marks, view, memorize, review }

/// A key and the modifiers held with it (Ctrl and ⌘ are one).
class KeyCombo {
  final LogicalKeyboardKey key;
  final bool ctrl, shift, alt;
  const KeyCombo(this.key, {this.ctrl = false, this.shift = false, this.alt = false});

  bool matchesEvent(LogicalKeyboardKey k, HardwareKeyboard keys) =>
      k == key &&
      ctrl == (keys.isControlPressed || keys.isMetaPressed) &&
      shift == keys.isShiftPressed &&
      alt == keys.isAltPressed;

  String encode() => '${ctrl ? 1 : 0}${shift ? 1 : 0}${alt ? 1 : 0}:${key.keyId}';

  static KeyCombo? decode(String s) {
    final i = s.indexOf(':');
    if (i != 3) return null;
    final id = int.tryParse(s.substring(4));
    if (id == null) return null;
    return KeyCombo(LogicalKeyboardKey(id),
        ctrl: s[0] == '1', shift: s[1] == '1', alt: s[2] == '1');
  }

  String get label {
    final name = switch (key) {
      LogicalKeyboardKey.arrowLeft => '←',
      LogicalKeyboardKey.arrowRight => '→',
      LogicalKeyboardKey.arrowUp => '↑',
      LogicalKeyboardKey.arrowDown => '↓',
      LogicalKeyboardKey.space => 'Space',
      LogicalKeyboardKey.escape => 'Esc',
      LogicalKeyboardKey.pageUp => 'PgUp',
      LogicalKeyboardKey.pageDown => 'PgDn',
      LogicalKeyboardKey.backspace => 'Backspace',
      LogicalKeyboardKey.numpadAdd => 'Num +',
      LogicalKeyboardKey.numpadSubtract => 'Num −',
      _ => key.keyLabel.isEmpty ? '#${key.keyId}' : key.keyLabel,
    };
    return [if (ctrl) 'Ctrl', if (alt) 'Alt', if (shift) 'Shift', name].join('+');
  }

  @override
  bool operator ==(Object other) =>
      other is KeyCombo &&
      other.key == key &&
      other.ctrl == ctrl &&
      other.shift == shift &&
      other.alt == alt;
  @override
  int get hashCode => Object.hash(key, ctrl, shift, alt);
}

const _space = LogicalKeyboardKey.space;
const _back = LogicalKeyboardKey.backspace;
const _left = LogicalKeyboardKey.arrowLeft;
const _right = LogicalKeyboardKey.arrowRight;

/// The keys out of the box. The muṣḥaf reads right to left: ← is onward.
const Map<KeyAction, List<KeyCombo>> kDefaultKeys = {
  KeyAction.nextPage: [KeyCombo(_left), KeyCombo(LogicalKeyboardKey.pageDown)],
  KeyAction.prevPage: [KeyCombo(_right), KeyCombo(LogicalKeyboardKey.pageUp)],
  KeyAction.togglePages: [KeyCombo(LogicalKeyboardKey.keyD)],
  KeyAction.bookmarkPage: [KeyCombo(LogicalKeyboardKey.keyB)],
  KeyAction.review: [KeyCombo(LogicalKeyboardKey.keyR)],
  KeyAction.memorize: [KeyCombo(LogicalKeyboardKey.keyN)],
  KeyAction.recitation: [KeyCombo(LogicalKeyboardKey.keyA)],
  KeyAction.follow: [KeyCombo(LogicalKeyboardKey.keyV)],
  KeyAction.history: [KeyCombo(LogicalKeyboardKey.keyH)],
  KeyAction.openIndex: [KeyCombo(LogicalKeyboardKey.keyI)],
  KeyAction.search: [KeyCombo(LogicalKeyboardKey.keyF, ctrl: true)],
  KeyAction.goToPage: [KeyCombo(LogicalKeyboardKey.keyG, ctrl: true)],
  KeyAction.playPause: [KeyCombo(_space)],
  KeyAction.markMode: [KeyCombo(LogicalKeyboardKey.keyM)],
  KeyAction.undo: [KeyCombo(LogicalKeyboardKey.keyZ, ctrl: true)],
  KeyAction.redo: [
    KeyCombo(LogicalKeyboardKey.keyY, ctrl: true),
    KeyCombo(LogicalKeyboardKey.keyZ, ctrl: true, shift: true),
  ],
  KeyAction.pen1: [KeyCombo(LogicalKeyboardKey.digit1)],
  KeyAction.pen2: [KeyCombo(LogicalKeyboardKey.digit2)],
  KeyAction.pen3: [KeyCombo(LogicalKeyboardKey.digit3)],
  KeyAction.pen4: [KeyCombo(LogicalKeyboardKey.digit4)],
  KeyAction.pen5: [KeyCombo(LogicalKeyboardKey.digit5)],
  KeyAction.zoomIn: [
    KeyCombo(LogicalKeyboardKey.equal, ctrl: true),
    KeyCombo(LogicalKeyboardKey.equal, ctrl: true, shift: true),
    KeyCombo(LogicalKeyboardKey.add, ctrl: true),
    KeyCombo(LogicalKeyboardKey.add, ctrl: true, shift: true),
    KeyCombo(LogicalKeyboardKey.numpadAdd, ctrl: true),
  ],
  KeyAction.zoomOut: [
    KeyCombo(LogicalKeyboardKey.minus, ctrl: true),
    KeyCombo(LogicalKeyboardKey.numpadSubtract, ctrl: true),
  ],
  KeyAction.zoomReset: [KeyCombo(LogicalKeyboardKey.digit0, ctrl: true)],
  KeyAction.fullscreen: [KeyCombo(LogicalKeyboardKey.f11)],
  KeyAction.darkMode: [KeyCombo(LogicalKeyboardKey.keyT)],
  KeyAction.settings: [KeyCombo(LogicalKeyboardKey.comma, ctrl: true)],
  KeyAction.export: [KeyCombo(LogicalKeyboardKey.keyE, ctrl: true)],
  KeyAction.shortcuts: [
    KeyCombo(LogicalKeyboardKey.slash, shift: true),
    KeyCombo(LogicalKeyboardKey.question, shift: true),
    KeyCombo(LogicalKeyboardKey.question),
  ],
  KeyAction.leave: [KeyCombo(LogicalKeyboardKey.escape)],
  KeyAction.toggleLayout: [KeyCombo(LogicalKeyboardKey.keyL, ctrl: true, shift: true)],
  KeyAction.memoNextWord: [KeyCombo(_left), KeyCombo(_space)],
  KeyAction.memoPrevWord: [KeyCombo(_right), KeyCombo(_back)],
  KeyAction.memoNextVerse: [KeyCombo(_left, shift: true), KeyCombo(_space, shift: true)],
  KeyAction.memoPrevVerse: [KeyCombo(_right, shift: true), KeyCombo(_back, shift: true)],
  KeyAction.memoNextPage: [KeyCombo(LogicalKeyboardKey.pageDown)],
  KeyAction.memoPlay: [KeyCombo(LogicalKeyboardKey.keyP)],
  KeyAction.memoPlayPage: [KeyCombo(LogicalKeyboardKey.keyP, shift: true)],
  KeyAction.reviewNext: [KeyCombo(_left), KeyCombo(_space)],
  KeyAction.reviewPrev: [KeyCombo(_right), KeyCombo(_back)],
  KeyAction.reviewRepeat: [KeyCombo(LogicalKeyboardKey.keyR)],
  KeyAction.reviewRepeatVerse: [KeyCombo(LogicalKeyboardKey.keyR, shift: true)],
  KeyAction.reviewFix: [KeyCombo(LogicalKeyboardKey.keyF)],
  KeyAction.fluencyInstant: [KeyCombo(LogicalKeyboardKey.digit1)],
  KeyAction.fluencySlow: [KeyCombo(LogicalKeyboardKey.digit2)],
  KeyAction.fluencyWrong: [KeyCombo(LogicalKeyboardKey.digit3)],
};

/// What a mouse can do. [zoom] goes by the wheel; the rest by a button.
enum MouseAction { stepMark, fluencyStep, comment, menu, nextPage, prevPage, zoom, pan }

/// A mouse button (or the wheel: [scroll]) and the keys held with it.
class MouseCombo {
  /// The button's bit ([kPrimaryButton] and so on), or [scroll].
  final int button;
  final bool ctrl, shift, alt;
  const MouseCombo(this.button, {this.ctrl = false, this.shift = false, this.alt = false});

  static const scroll = 0;

  /// A plain left click is the word's own, a plain scroll turns the page.
  bool get isReserved => (button == kPrimaryButton || button == scroll) && !ctrl && !shift && !alt;

  String encode() => '${ctrl ? 1 : 0}${shift ? 1 : 0}${alt ? 1 : 0}:$button';

  static MouseCombo? decode(String s) {
    if (s.length < 5 || s[3] != ':') return null;
    final b = int.tryParse(s.substring(4));
    if (b == null) return null;
    return MouseCombo(b, ctrl: s[0] == '1', shift: s[1] == '1', alt: s[2] == '1');
  }

  String get label {
    final name = switch (button) {
      scroll => 'Scroll',
      kPrimaryButton => 'Left click',
      kSecondaryButton => 'Right click',
      kMiddleMouseButton => 'Wheel click',
      kBackMouseButton => 'Back button',
      kForwardMouseButton => 'Forward button',
      _ => 'Button $button',
    };
    return [if (ctrl) 'Ctrl', if (alt) 'Alt', if (shift) 'Shift', name].join('+');
  }

  bool heldNow(HardwareKeyboard keys) =>
      ctrl == (keys.isControlPressed || keys.isMetaPressed) &&
      shift == keys.isShiftPressed &&
      alt == keys.isAltPressed;

  @override
  bool operator ==(Object other) =>
      other is MouseCombo &&
      other.button == button &&
      other.ctrl == ctrl &&
      other.shift == shift &&
      other.alt == alt;
  @override
  int get hashCode => Object.hash(button, ctrl, shift, alt);
}

const Map<MouseAction, MouseCombo> kDefaultMouse = {
  MouseAction.stepMark: MouseCombo(kPrimaryButton, shift: true),
  MouseAction.fluencyStep: MouseCombo(kPrimaryButton, alt: true),
  MouseAction.comment: MouseCombo(kMiddleMouseButton),
  MouseAction.menu: MouseCombo(kSecondaryButton),
  MouseAction.nextPage: MouseCombo(kForwardMouseButton),
  MouseAction.prevPage: MouseCombo(kBackMouseButton),
  MouseAction.zoom: MouseCombo(MouseCombo.scroll, ctrl: true),
  // Held and dragged: the zoomed page moves (the wheel's click alone is a
  // comment).
  MouseAction.pan: MouseCombo(kMiddleMouseButton, ctrl: true),
};

/// The keys in use: the defaults, with [bindings] (an action's name → its
/// encoded key) over them.
class Keymap {
  final Map<String, String> bindings;
  const Keymap(this.bindings);

  List<KeyCombo> combosOf(KeyAction a) {
    final set = bindings[a.name];
    final custom = set == null ? null : KeyCombo.decode(set);
    return custom == null ? kDefaultKeys[a]! : [custom];
  }

  bool isCustom(KeyAction a) => bindings.containsKey(a.name);

  /// What to show for [a]: its first key.
  String label(KeyAction a) => combosOf(a).first.label;

  /// Every key [a] answers to, for the shortcuts list: the first two, a key
  /// shown once (Ctrl+= stands for Ctrl+Shift+= too).
  String allLabels(KeyAction a) {
    final shown = <KeyCombo>[];
    for (final c in combosOf(a)) {
      if (shown.any((o) => o.key == c.key)) continue;
      shown.add(c);
      if (shown.length == 2) break;
    }
    return shown.map((c) => c.label).join('  ·  ');
  }

  /// Whether [e] is [a]'s. (A held Space doesn't repeat: it would flicker.)
  bool matches(KeyAction a, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (e is KeyRepeatEvent && e.logicalKey == LogicalKeyboardKey.space) return false;
    final keys = HardwareKeyboard.instance;
    return combosOf(a).any((c) => c.matchesEvent(e.logicalKey, keys));
  }

  static String mouseKey(MouseAction a) => 'mouse.${a.name}';

  MouseCombo mouseOf(MouseAction a) {
    final set = bindings[mouseKey(a)];
    return (set == null ? null : MouseCombo.decode(set)) ?? kDefaultMouse[a]!;
  }

  bool isMouseCustom(MouseAction a) => bindings.containsKey(mouseKey(a));

  /// What [buttons] pressed, with the keys held now, does.
  MouseAction? mouseActionFor(int buttons) {
    final keys = HardwareKeyboard.instance;
    for (final a in MouseAction.values) {
      final c = mouseOf(a);
      if (c.button == buttons && c.heldNow(keys)) return a;
    }
    return null;
  }

  /// Whether the keys held now make the wheel, or a trackpad, zoom.
  bool get zoomHeld => mouseOf(MouseAction.zoom).heldNow(HardwareKeyboard.instance);

  MouseAction? mouseClashOf(MouseAction a, MouseCombo combo) {
    for (final o in MouseAction.values) {
      if (o != a && mouseOf(o) == combo) return o;
    }
    return null;
  }

  /// What else [combo] already does that [a] would clash with.
  KeyAction? clashOf(KeyAction a, KeyCombo combo) {
    for (final o in KeyAction.values) {
      if (o != a && a.clashesWith(o) && combosOf(o).contains(combo)) return o;
    }
    return null;
  }
}
