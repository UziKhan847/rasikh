import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/marks/marks_model.dart';
import '../../core/marks/marks_store.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/sync/pocketbase_backend.dart';
import '../../core/sync/sync_backend.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import 'marking.dart';

String syncErrorText(BuildContext context, Object e) {
  if (e is! SyncException) return context.l10n.mkSyncError;
  if (e.message == 'no server') return context.l10n.mkErrNoServer;
  return switch (e.error) {
    SyncError.taken => context.l10n.mkErrTaken,
    SyncError.invalid => context.l10n.mkErrInvalid,
    SyncError.network => context.l10n.mkErrNetwork,
    SyncError.forbidden => context.l10n.mkErrForbidden,
    _ => context.l10n.mkSyncError,
  };
}

/// Hifz: account & sync, and sharing the active book. Shows nothing when the
/// app has no sync engine.
class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    final store = MarksScope.maybeOf(context);
    if (sync == null || store == null) return const SizedBox.shrink();
    final p = pal(context);
    final acct = sync.account;
    if (acct == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        QSectionLabel(context.l10n.mkAccountSync),
        QCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.mkAccountSyncSub,
                    style: uiStyle(context, size: 13.5, color: p.ink2)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  QPrimaryButton(context.l10n.mkSignIn,
                      icon: AppIcons.cloud,
                      onTap: () => showAccountSheet(context, signUp: false)),
                  QOutlineButton(context.l10n.mkCreateAccount,
                      icon: AppIcons.person,
                      onTap: () => showAccountSheet(context, signUp: true)),
                ]),
              ]),
        ),
      ]);
    }
    final book = store.activeBook;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      QSectionLabel(context.l10n.mkAccountSync,
          trailing: Text(_statusText(context, sync),
              style: uiStyle(context, size: 12.5, color: p.ink3))),
      QGroup(children: [
        if (book != null && !book.synced && book.myRole == BookRole.owner)
          QRow(
            title: context.l10n.mkShareBook,
            subtitle: context.l10n.mkShareBookSub,
            leading: Icon(AppIcons.cloud, color: p.ink3),
            control: QOutlineButton(context.l10n.mkSyncThisBook,
                onTap: () => _guard(context, () => sync.enableSync(book.id))),
          ),
        if (book != null && book.synced && book.myRole == BookRole.owner) ...[
          QRow(
            title: context.l10n.mkInviteListener,
            leading: Icon(AppIcons.link, color: p.ink3),
            chevron: true,
            onTap: () => _invite(context, sync, book.id, BookRole.listener),
          ),
          QRow(
            title: context.l10n.mkInviteChecker,
            leading: Icon(AppIcons.link, color: p.ink3),
            chevron: true,
            onTap: () => _invite(context, sync, book.id, BookRole.checker),
          ),
        ],
        if (book != null && book.synced)
          QRow(
            title: context.l10n.mkMembers,
            leading: Icon(AppIcons.group, color: p.ink3),
            chevron: true,
            onTap: () => pushAdaptive(context, _MembersScreen(bookId: book.id)),
          ),
        QRow(
          title: context.l10n.mkJoinBook,
          leading: Icon(AppIcons.add, color: p.ink3),
          chevron: true,
          onTap: () async {
            final code = await askText(context,
                title: context.l10n.mkJoinBook,
                hint: context.l10n.mkJoinCodeHint);
            if (code == null || code.trim().isEmpty || !context.mounted) return;
            await _guard(context, () => sync.join(code.trim()),
                codeError: true);
          },
        ),
        QRow(
          title: context.l10n.mkSignedInAs(acct.username),
          leading: Icon(AppIcons.person, color: p.ink3),
          chevron: true,
          onTap: () => pushAdaptive(context, const AccountScreen()),
        ),
      ]),
    ]);
  }

  static String _statusText(BuildContext context, SyncEngine s) =>
      switch (s.status) {
        SyncStatus.syncing => context.l10n.mkSyncing,
        SyncStatus.offline => context.l10n.mkOffline,
        SyncStatus.error => context.l10n.mkSyncError,
        _ => s.lastSync == null
            ? context.l10n.mkNotSynced
            : context.l10n.mkSyncedAt(TimeOfDay.fromDateTime(s.lastSync!)
                .format(context)),
      };

  Future<void> _invite(BuildContext context, SyncEngine sync, String bookId,
      BookRole role) async {
    try {
      final inv = await sync.invite(bookId, role);
      if (!context.mounted) return;
      final code = '${inv.code.substring(0, 4)}-${inv.code.substring(4)}';
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(d.l10n.mkInviteCode),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(code,
                style: displayStyle(d, size: 34)
                    .copyWith(letterSpacing: 3)),
            const SizedBox(height: 10),
            Text(d.l10n.mkInviteCodeSub,
                textAlign: TextAlign.center,
                style: uiStyle(d, size: 13, color: pal(d).ink3)),
          ]),
          actions: [
            TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.code));
                  showQToast(context, context.l10n.mkCopied);
                },
                child: Text(MaterialLocalizations.of(d).copyButtonLabel)),
            TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(MaterialLocalizations.of(d).okButtonLabel)),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showQToast(context, syncErrorText(context, e));
    }
  }
}

Future<void> _guard(BuildContext context, Future<void> Function() f,
    {bool codeError = false}) async {
  try {
    await f();
  } catch (e) {
    if (!context.mounted) return;
    final invalid = e is SyncException && e.error == SyncError.invalid;
    showQToast(
        context,
        codeError && invalid
            ? context.l10n.mkErrCode
            : syncErrorText(context, e));
  }
}

/// Sign in / create account. Asks for the server address too when none is
/// set (or under "advanced" to change it).
Future<void> showAccountSheet(BuildContext context, {required bool signUp}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _AccountForm(signUp: signUp),
    ),
  );
}

class _AccountForm extends StatefulWidget {
  final bool signUp;
  const _AccountForm({required this.signUp});
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late bool _signUp = widget.signUp;
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _showServer = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_server.text.isEmpty) {
      final s = SettingsScope.of(context);
      _server.text = s.syncServer;
      _showServer = s.syncServer.isEmpty;
      _name.text = MarksScope.maybeOf(context)?.me.displayName ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_server, _user, _pass, _name, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final sync = SyncScope.maybeOf(context);
    final s = SettingsScope.of(context);
    if (sync == null) return;
    final user = _user.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.-]{3,32}$').hasMatch(user)) {
      setState(() => _error = context.l10n.mkUsernameRule);
      return;
    }
    if (_pass.text.length < 8) {
      setState(() => _error = context.l10n.mkPasswordShort);
      return;
    }
    var server = _server.text.trim();
    if (server.isNotEmpty && !server.startsWith('http')) {
      server = 'https://$server';
    }
    while (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }
    if (server.isEmpty) {
      setState(() => _error = context.l10n.mkErrNoServer);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (server != s.syncServer) {
        s.update(() => s.syncServer = server);
        await sync.replaceBackend(await PocketBaseSyncBackend.create(server));
      }
      if (_signUp) {
        await sync.signUp(user, _pass.text,
            displayName: _name.text, email: _email.text);
      } else {
        await sync.signIn(user, _pass.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = syncErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final sync = SyncScope.maybeOf(context);
    final email = await askText(context,
        title: context.l10n.mkForgotPassword,
        hint: context.l10n.mkRecoveryEmail);
    if (sync == null || email == null || email.trim().isEmpty) return;
    try {
      await sync.backend.requestPasswordReset(email.trim());
    } catch (_) {
      // Same answer either way: don't reveal which emails have accounts.
    }
    if (mounted) showQToast(context, context.l10n.mkResetSent);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final server = _server.text.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_signUp ? context.l10n.mkCreateAccount : context.l10n.mkSignIn,
                  style: displayStyle(context, size: 24)),
              const SizedBox(height: 14),
              if (_showServer) ...[
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                      labelText: context.l10n.mkServer,
                      hintText: context.l10n.mkServerHint),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _user,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                    labelText: context.l10n.mkUsername,
                    helperText: _signUp ? context.l10n.mkUsernameRule : null),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                obscureText: true,
                autofillHints: [
                  _signUp ? AutofillHints.newPassword : AutofillHints.password
                ],
                decoration: InputDecoration(
                    labelText: context.l10n.mkPassword,
                    helperText: _signUp ? context.l10n.mkPasswordShort : null),
                onSubmitted: (_) => _submit(),
              ),
              if (_signUp) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      InputDecoration(labelText: context.l10n.mkDisplayName),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                      labelText: context.l10n.mkRecoveryEmail,
                      helperText: context.l10n.mkRecoveryEmailHint,
                      helperMaxLines: 3),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: uiStyle(context, size: 13.5, color: p.red)),
              ],
              const SizedBox(height: 16),
              QPrimaryButton(
                  _signUp ? context.l10n.mkCreateAccount : context.l10n.mkSignIn,
                  icon: AppIcons.cloud,
                  onTap: _busy ? null : _submit),
              const SizedBox(height: 6),
              Wrap(spacing: 4, children: [
                TextButton(
                    onPressed: () => setState(() => _signUp = !_signUp),
                    child: Text(_signUp
                        ? context.l10n.mkSignIn
                        : context.l10n.mkCreateAccount)),
                if (!_signUp)
                  TextButton(
                      onPressed: _forgot,
                      child: Text(context.l10n.mkForgotPassword)),
                if (!_showServer)
                  TextButton(
                      onPressed: () => setState(() => _showServer = true),
                      child: Text(context.l10n.mkServer)),
              ]),
              if (server.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(context.l10n.mkSyncPrivacy(Uri.tryParse(server)?.host ?? server),
                    style: uiStyle(context, size: 12, color: p.ink3)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings → Account & sync.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    final p = pal(context);
    final acct = sync?.account;
    final server = SettingsScope.of(context).syncServer;
    return QScreen(title: context.l10n.mkAccountSync, children: [
      if (sync == null || acct == null)
        const SyncSection()
      else ...[
        QGroup(children: [
          QRow(
            title: acct.displayName.isEmpty ? acct.username : acct.displayName,
            subtitle: '@${acct.username}'
                '${server.isEmpty ? '' : ' · ${Uri.tryParse(server)?.host ?? server}'}',
            leading: Icon(AppIcons.person, color: p.ink3),
          ),
          QRow(
            title: context.l10n.mkSyncNow,
            subtitle: SyncSection._statusText(context, sync),
            leading: Icon(AppIcons.sync, color: p.ink3),
            onTap: sync.syncNow,
          ),
        ]),
        const SizedBox(height: 10),
        Text(
            context.l10n.mkSyncPrivacy(Uri.tryParse(server)?.host ?? server),
            style: uiStyle(context, size: 12.5, color: p.ink3)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          QOutlineButton(context.l10n.mkSignOut,
              onTap: () => _guard(context, sync.signOut)),
          QOutlineButton(context.l10n.mkDeleteAccount,
              icon: AppIcons.delete, onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: Text(d.l10n.mkDeleteAccount),
                content: Text(d.l10n.mkDeleteAccountQ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: Text(d.l10n.cancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: Text(d.l10n.mkDelete)),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await _guard(context, sync.deleteAccount);
            }
          }),
        ]),
      ],
    ]);
  }
}

class _MembersScreen extends StatefulWidget {
  final String bookId;
  const _MembersScreen({required this.bookId});
  @override
  State<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<_MembersScreen> {
  Future<List<BookMember>>? _members;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _members ??= SyncScope.maybeOf(context)?.members(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    final store = MarksScope.maybeOf(context);
    final book = store?.book(widget.bookId);
    final p = pal(context);
    if (sync == null || book == null) return const SizedBox.shrink();
    final owner = book.myRole == BookRole.owner;
    return QScreen(title: context.l10n.mkMembers, subtitle: book.name, children: [
      FutureBuilder<List<BookMember>>(
        future: _members,
        builder: (context, snap) {
          if (snap.hasError) {
            return Text(syncErrorText(context, snap.error!),
                style: uiStyle(context, size: 13.5, color: p.ink3));
          }
          final list = snap.data;
          if (list == null) {
            return Center(child: CircularProgressIndicator(color: p.acc));
          }
          return QGroup(children: [
            for (final m in list)
              QRow(
                title: m.displayName.isEmpty ? m.username : m.displayName,
                subtitle: '@${m.username} · ${switch (m.role) {
                  BookRole.owner => context.l10n.mkOwner,
                  BookRole.listener => context.l10n.mkListener,
                  BookRole.checker => context.l10n.mkChecker,
                }}',
                control: owner && m.role != BookRole.owner
                    ? TextButton(
                        onPressed: () async {
                          await _guard(context,
                              () => sync.removeMember(book.id, m.id));
                          setState(() => _members = sync.members(book.id));
                        },
                        child: Text(context.l10n.mkRemove))
                    : null,
              ),
          ]);
        },
      ),
      if (!owner) ...[
        const SizedBox(height: 16),
        QOutlineButton(context.l10n.mkLeaveBook, onTap: () async {
          await _guard(context, () => sync.leave(book.id));
          if (context.mounted) Navigator.pop(context);
        }),
      ],
    ]);
  }
}
