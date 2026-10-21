import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import 'session_sheet.dart';

String markTypeLabel(BuildContext context, MarkType t) => switch (t) {
      MarkType.mistake => context.l10n.mkMistake,
      MarkType.tajwid => context.l10n.mkTajwid,
      MarkType.hesitation => context.l10n.mkHesitation,
      MarkType.doubt => context.l10n.mkDoubt,
      MarkType.note => context.l10n.mkNote,
      MarkType.mutashabih => context.l10n.mkMutashabih,
    };

String markTypeHint(BuildContext context, MarkType t) => switch (t) {
      MarkType.mistake => context.l10n.mkMistakeHint,
      MarkType.tajwid => context.l10n.mkTajwidHint,
      MarkType.hesitation => context.l10n.mkHesitationHint,
      MarkType.doubt => context.l10n.mkDoubtHint,
      MarkType.note => context.l10n.mkNoteHint,
      MarkType.mutashabih => context.l10n.mkMutashabihHint,
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
Future<String?> askText(BuildContext context,
    {required String title,
    String initial = '',
    String? hint,
    bool long = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      // [long]: a paragraph (a memory technique) — Enter starts a new line.
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: long ? 4 : 1,
        maxLines: long ? 12 : 5,
        maxLength: long ? 4000 : null,
        keyboardType: long ? TextInputType.multiline : null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint ?? d.l10n.mkCommentHint),
        onSubmitted: long ? null : (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d), child: Text(d.l10n.cancel)),
        TextButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: Text(d.l10n.mkSave)),
      ],
    ),
  );
  // (The controller is left to the GC: the dialog's exit animation can still
  // be using it when this future completes.)
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
  final List<MarkOp> _undo = [];
  int? _fromG, _toG;

  bool get active => _active;
  bool get canUndo => _undo.isNotEmpty;

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
  Future<bool> start(BuildContext context, {required String script}) async {
    final store = MarksScope.maybeOf(context);
    if (store == null || !store.ready) return false;
    final s = await showStartSessionSheet(context, store: store, script: script);
    if (s == null) return false;
    _active = true;
    bookId = s.bookId;
    sessionId = s.id;
    _undo.clear();
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
    final (op, type) = store.cycle(b, ref, sessionId: sessionId);
    tapped = true;
    lastType = type;
    _undo.add(op);
    if (_undo.length > 100) _undo.removeAt(0);
    noteRange(ref.globalAyah, ref.globalAyah);
    if (SettingsScope.of(context).haptics) HapticFeedback.selectionClick();
    notifyListeners();
    return true;
  }

  void undo(BuildContext context) {
    final store = MarksScope.maybeOf(context);
    if (store == null || _undo.isEmpty) return;
    store.undo(_undo.removeLast());
    notifyListeners();
  }

  /// Shows the session summary and closes the session.
  Future<void> end(BuildContext context) async {
    final store = MarksScope.maybeOf(context);
    final b = bookId, sid = sessionId;
    if (store != null && b != null && sid != null) {
      await showEndSessionSheet(context,
          store: store, bookId: b, sessionId: sid, range: range);
    }
    stop();
  }

  /// Leaves marking mode without the summary (the session stays open and
  /// resumes next time, until it idles out).
  void stop() {
    if (!_active) return;
    _active = false;
    _undo.clear();
    notifyListeners();
  }
}
