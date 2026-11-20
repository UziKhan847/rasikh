import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/fluency/fluency_store.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../data/mushaf.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../ui/kit.dart' show showQToast;
import 'quick_insert.dart';
import '../../ui/bidi.dart';

String markTypeLabel(BuildContext context, MarkType t) => switch (t) {
      MarkType.mistake => context.l10n.mkMistake,
      MarkType.tajwid => context.l10n.mkTajwid,
      MarkType.hesitation => context.l10n.mkHesitation,
      MarkType.doubt => context.l10n.mkDoubt,
      MarkType.note => context.l10n.mkNote,
      MarkType.mutashabih => context.l10n.mkMutashabih,
      MarkType.breathStop => context.l10n.mkBreathStop,
      MarkType.breathStart => context.l10n.mkBreathStart,
      MarkType.fluencySlow => context.l10n.flSlow,
      MarkType.fluencyPair => context.l10n.flPair,
      MarkType.fluencyChunk => context.l10n.flChunk,
    };

String markTypeHint(BuildContext context, MarkType t) => switch (t) {
      MarkType.mistake => context.l10n.mkMistakeHint,
      MarkType.tajwid => context.l10n.mkTajwidHint,
      MarkType.hesitation => context.l10n.mkHesitationHint,
      MarkType.doubt => context.l10n.mkDoubtHint,
      MarkType.note => context.l10n.mkNoteHint,
      MarkType.mutashabih => context.l10n.mkMutashabihHint,
      MarkType.breathStop => context.l10n.mkBreathStopHint,
      MarkType.breathStart => context.l10n.mkBreathStartHint,
      MarkType.fluencySlow || MarkType.fluencyPair || MarkType.fluencyChunk =>
        context.l10n.mkFluencySub,
    };

String sessionKindLabel(BuildContext context, SessionKind k) => switch (k) {
      SessionKind.none => context.l10n.mkKindNone,
      SessionKind.sabaq => context.l10n.mkKindSabaq,
      SessionKind.sabqi => context.l10n.mkKindSabqi,
      SessionKind.manzil => context.l10n.mkKindManzil,
      SessionKind.other => context.l10n.mkKindOther,
      SessionKind.review => context.l10n.mkKindReview,
    };

/// Display name for an author id (marks made on this device say "You").
String authorLabel(BuildContext context, MarksStore store, String id,
        String name) =>
    id == store.authorId || id == store.me.id
        ? context.l10n.mkYou
        : (name.isEmpty ? '—' : name);

/// Short local date, e.g. "15 Oct" (with the year when it isn't this year).
String shortDate(BuildContext context, int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final loc = Localizations.localeOf(context).toString();
  final now = DateTime.now();
  return MaterialLocalizations.of(context).formatShortMonthDay(d) +
      (d.year == now.year || loc.isEmpty ? '' : ' ${d.year}');
}

/// A one-field text dialog (comments, names). Null if cancelled.
/// [comment]: writing that can run to several lines; on a keyboard Enter sends
/// it and Shift+Enter starts a line. [long]: a paragraph (a memory technique),
/// with room for it.
Future<String?> askText(BuildContext context,
    {required String title,
    String initial = '',
    String? hint,
    bool long = false,
    bool comment = false,
    WordRef? word,
    MarkType? markType}) {
  // The word a comment's about, as the muṣḥaf prints it, and its quick buttons.
  final script = SettingsScope.of(context).mushafScript;
  final words = word == null || word.isWholeAyah
      ? ''
      : MushafRepo.wordText(script, word.globalAyah, word.word0);
  return showDialog<String>(
    context: context,
    builder: (d) => _AskText(
        title: title,
        initial: initial,
        hint: hint,
        long: long,
        comment: comment,
        word: words,
        // The muṣḥaf's own text, in the muṣḥaf's own face (its signs, like
        // the rounded zero over a silent alif, are in no other).
        wordFont: MushafRepo.fontFamily(script),
        markType: markType),
  );
}

class _AskText extends StatefulWidget {
  final String title, initial;
  final String? hint;
  final bool long, comment;
  final String word, wordFont;
  final MarkType? markType;
  const _AskText(
      {required this.title,
      required this.initial,
      required this.hint,
      required this.long,
      required this.comment,
      required this.word,
      required this.wordFont,
      required this.markType});

  @override
  State<_AskText> createState() => _AskTextState();
}

class _AskTextState extends State<_AskText> {
  late final _text = TextEditingController(text: widget.initial);
  late final _focus = FocusNode(onKeyEvent: _onKey);

  bool get _lines => widget.long || widget.comment;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() => Navigator.pop(context, _text.text);

  /// [s] where the cursor is, set off from what's before it.
  void _insert(String s) {
    final v = _text.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final before = v.text.substring(0, sel.start);
    final piece = before.isEmpty || before.endsWith(' ') || before.endsWith('\n') ? s : ' $s';
    _text.value = TextEditingValue(
      text: before + piece + v.text.substring(sel.end),
      selection: TextSelection.collapsed(offset: before.length + piece.length),
    );
    _focus.requestFocus();
  }

  /// With a real keyboard. (A phone's on-screen one can send Enter as a key
  /// too, and there it's a new line: it has the Save button.)
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (!_lines || e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey != LogicalKeyboardKey.enter &&
        e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (!mounted || !useDesktop(context)) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    // An input method's word in the making: Enter is its own.
    if (_text.value.composing.isValid && !_text.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.comment)
            QuickInsertBar(
                word: widget.word,
                wordFont: widget.wordFont,
                markType: widget.markType,
                onInsert: _insert),
          // Reads the way it will show: all Arabic right to left, mixed the
          // app language's way.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (context, v, field) => Directionality(
              textDirection: directionOf(v.text, ui: Directionality.of(context)) ??
                  Directionality.of(context),
              child: field!,
            ),
            child: TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            minLines: widget.long ? 4 : 1,
            maxLines: widget.long ? 12 : 5,
            maxLength: widget.long ? 4000 : null,
            keyboardType: _lines ? TextInputType.multiline : null,
            textInputAction: _lines ? TextInputAction.newline : null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: widget.hint ?? l.mkCommentHint),
            onSubmitted: _lines ? null : (_) => _send(),
          ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(onPressed: _send, child: Text(l.mkSave)),
      ],
    );
  }
}

/// One step undo takes back: applied, it gives the step that redoes it.
abstract class UndoStep {
  UndoStep? apply(BuildContext context);
}

/// A marks edit.
class MarkStep implements UndoStep {
  final MarkOp op;
  MarkStep(this.op);
  @override
  UndoStep? apply(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    return store == null ? null : MarkStep(store.undo(op));
  }
}

/// A word's fluency marks, as they were.
class FluencyStep implements UndoStep {
  final FluencyStore store;
  final Map<String, FluencyMark?> before;
  FluencyStep(this.store, this.before);
  @override
  UndoStep? apply(BuildContext context) => FluencyStep(store, store.restoreSnapshot(before));
}

/// Marking-mode state shared by the muṣḥaf and the card reader: the open
/// session, the undo stack, the range read so far and what the last tap did.
///
/// In marking mode a tap on a word steps its mark through the types
/// (mistake → tajwīd → hesitation → doubt → off; see [MarksStore.cycle]);
/// holding it opens the word's sheet to fix, comment, reply or delete.
class MarkingController extends ChangeNotifier {
  bool _active = false;
  String? bookId;
  String? sessionId;
  final List<UndoStep> _undo = [], _redo = [];
  String? resumeNext;
  int? _fromG, _toG;

  bool get active => _active;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// The range of global āyahs read in this session so far.
  (int, int)? get range =>
      _fromG == null ? null : (_fromG!, _toG!);

  /// Widen the session's range to include global āyahs [from]..[to].
  void noteRange(int from, int to) {
    if (!_active) return;
    _fromG = _fromG == null || from < _fromG! ? from : _fromG;
    _toG = _toG == null || to > _toG! ? to : _toG;
  }

  /// What the last tap left on its word: a type, or null once cleared
  /// (and before any tap, see [tapped]).
  MarkType? lastType;
  bool tapped = false;

  /// Opens the start-session sheet (or resumes this device's open session)
  /// and switches marking on. Returns whether marking is now on.
  ///
  /// [resumeNext]: a session to carry on with instead (set by a switch from
  /// the other view; used once).
  Future<bool> start(BuildContext context, {required String script}) async {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready) return false;
    // At once: the profile's marks (one book, never named), a session of
    // their own opened quietly — saved to History when it ends.
    final book = store.ensureActiveBook(context.l10n.mkMe);
    // Carried over from the other view: the same session, if it's still open.
    final carried = resumeNext == null ? null : store.session(book.id, resumeNext!);
    resumeNext = null;
    final s = carried != null && carried.isOpen
        ? carried
        : store.startSession(bookId: book.id, script: script);
    _active = true;
    bookId = s.bookId;
    sessionId = s.id;
    _undo.clear();
    _redo.clear();
    tapped = false;
    lastType = null;
    _fromG = s.fromGlobalAyah;
    _toG = s.toGlobalAyah;
    notifyListeners();
    return true;
  }

  /// A tap on [ref] in marking mode: its mark steps to the next type (or
  /// off). Returns false if there's no book to mark in.
  bool apply(BuildContext context, WordRef ref) {
    final store = MarksScope.maybeOf(context);
    final b = bookId;
    if (store == null || b == null || store.book(b) == null) return false;
    final s = SettingsScope.of(context);
    final pen = useDesktop(context) && s.markMethod == 'pen'
        ? MarkType.fromCode(s.markPen)
        : null;
    // The note pen, on a word without its note: the note's words first.
    if (pen == MarkType.note &&
        store.ownMarkAt(b, ref, sessionId: sessionId)?.type != MarkType.note) {
      _penNote(context, store, b, ref);
      return true;
    }
    final (op, type) = pen == null
        ? store.cycle(b, ref, sessionId: sessionId)
        : store.applyPen(b, ref, pen, sessionId: sessionId);
    _record(s, ref, op, type);
    return true;
  }

  Future<void> _penNote(BuildContext context, MarksStore store, String b, WordRef ref) async {
    final s = SettingsScope.of(context);
    final text = await askText(context,
        title: context.l10n.mkNote, comment: true, word: ref, markType: MarkType.note);
    if (text == null || text.trim().isEmpty) return;
    final (op, type) =
        store.applyPen(b, ref, MarkType.note, sessionId: sessionId, comment: text);
    _record(s, ref, op, type);
  }

  void _record(AppSettings s, WordRef ref, MarkOp op, MarkType? type) {
    tapped = true;
    lastType = type;
    _undo.add(MarkStep(op));
    _redo.clear();
    if (_undo.length > 100) _undo.removeAt(0);
    noteRange(ref.globalAyah, ref.globalAyah);
    if (s.haptics) HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Shift and a click: the word's mark steps on through the kinds, in Mark
  /// mode or not.
  void stepMark(BuildContext context, WordRef ref) {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready) return;
    final b = _active ? bookId : store.ensureActiveBook(context.l10n.mkMe).id;
    if (b == null || store.book(b) == null) return;
    final (op, type) = store.cycle(b, ref, sessionId: _active ? sessionId : null);
    _record(SettingsScope.of(context), ref, op, type);
  }

  /// Shift and a drag: one mistake over every word from [a] to [b] (in
  /// either order, across āyāt). Shift and a click on any of them then
  /// steps its kind, as for one word.
  void markSpan(BuildContext context, WordRef a, WordRef b) {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready) return;
    final bk = _active ? bookId : store.ensureActiveBook(context.l10n.mkMe).id;
    if (bk == null || store.book(bk) == null) return;
    final forward = a.globalAyah < b.globalAyah ||
        (a.globalAyah == b.globalAyah && a.word0 <= b.word0);
    final (from, to) = forward ? (a, b) : (b, a);
    final op = store.addMark(bk, from, MarkType.mistake,
        sessionId: _active ? sessionId : null, to: to);
    _record(SettingsScope.of(context), from, op, MarkType.mistake);
    noteRange(from.globalAyah, to.globalAyah);
  }

  /// An edit made elsewhere (a right-click's menu), for undo.
  void recordOp(MarkOp op) => recordStep(MarkStep(op));

  void recordStep(UndoStep step) {
    _undo.add(step);
    _redo.clear();
    if (_undo.length > 100) _undo.removeAt(0);
    notifyListeners();
  }

  /// What the breath tool's next tap puts down.
  MarkType breathNext = MarkType.breathStop;

  void toggleBreathNext() {
    breathNext =
        breathNext == MarkType.breathStop ? MarkType.breathStart : MarkType.breathStop;
    notifyListeners();
  }

  /// The breath tool's tap: a stop, then a start, by turns; a tap on a sign
  /// takes it off, and that sign is next again. Part of no session: they stay,
  /// whatever comes of the session they were placed in.
  void applyBreath(BuildContext context, WordRef ref) {
    final store = MarksScope.maybeOf(context);
    final b = bookId;
    if (store == null || b == null || store.book(b) == null) return;
    final (op, removed) = store.breathTap(b, ref, breathNext);
    if (removed != null) {
      breathNext = removed;
    } else {
      toggleBreathNext();
    }
    _undo.add(MarkStep(op));
    _redo.clear();
    if (_undo.length > 100) _undo.removeAt(0);
    if (SettingsScope.of(context).haptics) HapticFeedback.selectionClick();
    notifyListeners();
  }

  void undo(BuildContext context) {
    if (_undo.isEmpty) return;
    final back = _undo.removeLast().apply(context);
    if (back != null) _redo.add(back);
    notifyListeners();
  }

  void redo(BuildContext context) {
    if (_redo.isEmpty) return;
    final back = _redo.removeLast().apply(context);
    if (back != null) _undo.add(back);
    notifyListeners();
  }

  /// Closes the session quietly — with what was read — and says it's in
  /// History; a session with nothing marked isn't kept.
  Future<void> end(BuildContext context) async {
    final store = MarksScope.maybeOf(context);
    final b = bookId, sid = sessionId;
    if (store != null && b != null && sid != null) {
      final (from, to) = range ?? (null, null);
      if (store.marksOf(b).any((m) => m.sessionId == sid)) {
        store.endSession(b, sid, fromGlobalAyah: from, toGlobalAyah: to);
        showSessionSaved(context);
      } else {
        store.deleteSession(b, sid);
      }
    }
    stop();
  }

  /// Leaves marking mode without the summary (the session stays open and
  /// resumes next time, until it idles out). What was done can still be undone
  /// until the next session starts.
  void stop() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}

/// "Saved to History · Thu 30 Oct, 21:14": a session ended, kept quietly.
void showSessionSaved(BuildContext context) {
  final when = DateFormat.MMMEd(Localizations.localeOf(context).toString())
      .add_Hm()
      .format(DateTime.now());
  showQToast(context, context.l10n.sessionSaved(when));
}
