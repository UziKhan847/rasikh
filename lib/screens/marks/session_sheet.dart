import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/marks/word_ref.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../ui/mark_style.dart';
import 'marking.dart';

/// "Listen & mark": pick whose recitation (the mark book), who is listening
/// and what kind of session, then start — or resume the session still open on
/// this device. Returns the session, or null if dismissed.
Future<RecitationSession?> showStartSessionSheet(BuildContext context,
    {required MarksStore store, required String script}) {
  return showModalBottomSheet<RecitationSession>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _StartSession(store: store, script: script),
    ),
  );
}

class _StartSession extends StatefulWidget {
  final MarksStore store;
  final String script;
  const _StartSession({required this.store, required this.script});

  @override
  State<_StartSession> createState() => _StartSessionState();
}

class _StartSessionState extends State<_StartSession> {
  String? _bookId;
  bool _newBook = false;
  final _bookName = TextEditingController();
  late final TextEditingController _listener;
  SessionKind _kind = SessionKind.none;

  @override
  void initState() {
    super.initState();
    final books = widget.store.books.where((b) => b.myRole.canMark).toList();
    _bookId = widget.store.activeBook?.myRole.canMark == true
        ? widget.store.activeBookId
        : (books.isEmpty ? null : books.first.id);
    _newBook = _bookId == null;
    _listener = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listener.text.isEmpty) {
      final s = SettingsScope.of(context);
      _listener.text = s.lastListener.isNotEmpty
          ? s.lastListener
          : widget.store.me.displayName;
    }
  }

  @override
  void dispose() {
    _bookName.dispose();
    _listener.dispose();
    super.dispose();
  }

  String _resolveBook() {
    final store = widget.store;
    if (_newBook || _bookId == null) {
      final name = _bookName.text.trim();
      return store
          .createBook(name.isEmpty ? context.l10n.mkYou : name)
          .id;
    }
    store.setActiveBook(_bookId!);
    return _bookId!;
  }

  void _start() {
    final store = widget.store;
    final bookId = _resolveBook();
    final s = SettingsScope.of(context);
    final listener = _listener.text.trim();
    if (listener != s.lastListener) s.update(() => s.lastListener = listener);
    final session = store.startSession(
        bookId: bookId,
        listenerName: listener,
        kind: _kind,
        script: widget.script);
    Navigator.pop(context, session);
  }

  void _resume(RecitationSession open) {
    widget.store.setActiveBook(open.bookId);
    Navigator.pop(context, open);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = pal(context);
    final books = store.books.where((b) => b.myRole.canMark).toList();
    final open = !_newBook && _bookId != null ? store.openSession(_bookId!) : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.mkListenAndMark,
                style: displayStyle(context, size: 24)),
            const SizedBox(height: 4),
            Text(context.l10n.mkMarkingHint,
                style: uiStyle(context, size: 13, color: p.ink3)),
            QSectionLabel(context.l10n.mkReciter),
            QGroup(children: [
              for (final b in books)
                QRadioRow(
                  title: b.name,
                  selected: !_newBook && _bookId == b.id,
                  onTap: () => setState(() {
                    _bookId = b.id;
                    _newBook = false;
                  }),
                ),
              QRadioRow(
                title: context.l10n.mkNewBook,
                selected: _newBook,
                onTap: () => setState(() => _newBook = true),
              ),
            ]),
            if (_newBook) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _bookName,
                autofocus: books.isNotEmpty,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(hintText: context.l10n.mkBookNameHint),
              ),
            ],
            QSectionLabel(context.l10n.mkListener),
            TextField(
              controller: _listener,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: context.l10n.mkListenerHint),
            ),
            QSectionLabel(context.l10n.mkKind),
            QSegmented<SessionKind>(
              options: [
                // Review sessions are started by review mode, not picked.
                for (final k in SessionKind.values)
                  if (k != SessionKind.review)
                    (k, sessionKindLabel(context, k), null)
              ],
              value: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: [
              QPrimaryButton(context.l10n.mkStart,
                  icon: AppIcons.pen, onTap: _start),
              if (open != null)
                QOutlineButton(context.l10n.mkResume,
                    icon: AppIcons.play, onTap: () => _resume(open)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The end-of-session summary: what was marked, the range read, a note.
/// The session is closed however the sheet is dismissed.
Future<void> showEndSessionSheet(BuildContext context,
    {required MarksStore store,
    required String bookId,
    required String sessionId,
    (int, int)? range}) async {
  final note = TextEditingController(
      text: store.session(bookId, sessionId)?.note ?? '');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final p = pal(sheet);
      final mp = markPaletteFor(p);
      final marks =
          store.marksOf(bookId).where((m) => m.sessionId == sessionId).toList();
      final fixes =
          store.fixesOf(bookId).where((f) => f.sessionId == sessionId).length;
      final counts = <MarkType, int>{
        for (final t in MarkType.values)
          t: marks.where((m) => m.type == t).length
      };
      String ref(int g) {
        final (s, a) = surahAyahFromGlobal(g);
        return '$s:$a';
      }

      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sheet.l10n.mkSessionSummary,
                    style: displayStyle(sheet, size: 24)),
                if (range != null) ...[
                  const SizedBox(height: 4),
                  Text('${ref(range.$1)} – ${ref(range.$2)}',
                      style: uiStyle(sheet, size: 13, color: p.ink3)),
                ],
                const SizedBox(height: 14),
                if (marks.isEmpty && fixes == 0)
                  Text(sheet.l10n.mkNoMarksThisSession,
                      style: uiStyle(sheet, size: 15))
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in MarkType.values)
                      if (counts[t]! > 0)
                        _CountChip(
                            swatch: MarkSwatch(type: t, pal: mp),
                            label: markTypeLabel(sheet, t),
                            n: counts[t]!),
                    if (fixes > 0)
                      _CountChip(
                          swatch: MarkSwatch(type: null, pal: mp),
                          label: sheet.l10n.mkFixed,
                          n: fixes),
                  ]),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLines: 3,
                  minLines: 1,
                  decoration:
                      InputDecoration(hintText: sheet.l10n.mkSessionNoteHint),
                ),
                const SizedBox(height: 16),
                QPrimaryButton(sheet.l10n.mkSave,
                    icon: AppIcons.check, onTap: () => Navigator.pop(sheet)),
              ],
            ),
          ),
        ),
      );
    },
  );
  store.endSession(bookId, sessionId,
      fromGlobalAyah: range?.$1, toGlobalAyah: range?.$2, note: note.text);
}

class _CountChip extends StatelessWidget {
  final Widget swatch;
  final String label;
  final int n;
  const _CountChip({required this.swatch, required this.label, required this.n});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        swatch,
        const SizedBox(width: 8),
        Text(label, style: uiStyle(context, size: 13, weight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('$n',
            style: uiStyle(context, size: 15, weight: FontWeight.w700)),
      ]),
    );
  }
}
