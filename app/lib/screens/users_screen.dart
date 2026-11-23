import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// One server user as the admin sees it (never with a key).
class UserEntry {
  final int id;
  final String name;
  final String role;
  final bool active;
  final String projectsRoot;
  final int appCount;

  const UserEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.projectsRoot = '',
    this.appCount = 0,
  });

  bool get isAdmin => role == 'admin';

  /// User 1 is the server's main admin (the settings key): it can't be
  /// turned off or re-keyed from here.
  bool get isMainAdmin => id == 1;

  factory UserEntry.fromJson(Map<String, dynamic> j) => UserEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        role: j['role'] as String? ?? 'member',
        active: j['active'] as bool? ?? true,
        projectsRoot: j['projects_root'] as String? ?? '',
        appCount: (j['app_count'] as num?)?.toInt() ?? 0,
      );
}

/// A user with its freshly made key (shown once).
class IssuedKey {
  final UserEntry user;
  final String apiKey;
  const IssuedKey(this.user, this.apiKey);
}

/// What the Users screen needs from the server; tests pass a fake.
abstract class UsersApi {
  Future<ApiResult<List<UserEntry>>> list();
  Future<ApiResult<IssuedKey>> addMember(String name, String projectsRoot);
  Future<ApiResult<bool>> deactivate(int id);
  Future<ApiResult<IssuedKey>> rotateKey(int id);
}

class ServerUsersApi implements UsersApi {
  const ServerUsersApi();

  static ApiResult<IssuedKey> _issued(ApiResult<Map<String, dynamic>> r) {
    if (!r.ok) return ApiResult.failure(r.error ?? '');
    return ApiResult.success(IssuedKey(
      UserEntry.fromJson(r.data!['user'] as Map<String, dynamic>),
      r.data!['api_key'] as String,
    ));
  }

  @override
  Future<ApiResult<List<UserEntry>>> list() async {
    final r = await ApiService.getUsers();
    if (!r.ok) return ApiResult.failure(r.error ?? '');
    return ApiResult.success(r.data!.map(UserEntry.fromJson).toList());
  }

  @override
  Future<ApiResult<IssuedKey>> addMember(String name, String projectsRoot) async =>
      _issued(await ApiService.createUser(name: name, projectsRoot: projectsRoot));

  @override
  Future<ApiResult<bool>> deactivate(int id) => ApiService.deactivateUser(id);

  @override
  Future<ApiResult<IssuedKey>> rotateKey(int id) async =>
      _issued(await ApiService.rotateUserKey(id));
}

/// Admin-only: who can use this server. Add a member (its key is shown once,
/// with a pairing QR), give someone a new key, or turn a key off.
class UsersScreen extends StatefulWidget {
  final UsersApi api;

  /// Worker URL put into the pairing code next to the key; defaults to the
  /// one this app is paired with.
  final String? workerUrl;

  const UsersScreen({super.key, this.api = const ServerUsersApi(), this.workerUrl});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<UserEntry> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.api.list();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _users = r.data!;
      } else {
        _error = r.error;
      }
    });
  }

  Future<void> _addMember() async {
    final issued = await showDialog<IssuedKey>(
      context: context,
      builder: (_) => _AddMemberDialog(api: widget.api),
    );
    if (issued == null || !mounted) return;
    await _showKey(issued);
    _load();
  }

  Future<void> _rotate(UserEntry u) async {
    final ok = await _confirm(l10n.usersRotateTitle(u.name), l10n.usersRotateBody,
        l10n.usersRotateKey);
    if (ok != true || !mounted) return;
    final r = await widget.api.rotateKey(u.id);
    if (!mounted) return;
    if (r.ok) {
      await _showKey(r.data!);
    } else {
      setState(() => _error = r.error);
    }
  }

  Future<void> _deactivate(UserEntry u) async {
    final ok = await _confirm(l10n.usersDeactivateTitle(u.name),
        l10n.usersDeactivateBody, l10n.usersDeactivate);
    if (ok != true || !mounted) return;
    final r = await widget.api.deactivate(u.id);
    if (!mounted) return;
    if (r.ok) {
      _load();
    } else {
      setState(() => _error = r.error);
    }
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
  }

  Future<void> _showKey(IssuedKey issued) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KeyOnceDialog(
        issued: issued,
        workerUrl: widget.workerUrl ?? AppConfig.workerUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usersTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('users-add'),
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(l10n.usersAddMember),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              if (_loading && _users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_users.isEmpty && _error == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.usersEmpty)),
                )
              else
                for (final u in _users) _userCard(u),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(UserEntry u) {
    final details = <String>[
      u.isAdmin ? l10n.roleAdmin : l10n.roleMember,
      l10n.usersAppCount(u.appCount),
      if (!u.active) l10n.usersInactive,
    ].join(' · ');
    return Card(
      key: ValueKey('user-${u.id}'),
      child: ListTile(
        leading: Icon(
          u.isAdmin ? Icons.admin_panel_settings : Icons.person,
          color: u.active ? AppColors.accent : Colors.grey,
        ),
        title: Text(u.name),
        subtitle: Text(
          u.projectsRoot.isEmpty ? details : '$details\n${u.projectsRoot}',
        ),
        isThreeLine: u.projectsRoot.isNotEmpty,
        trailing: (u.isMainAdmin || !u.active)
            ? null
            : PopupMenuButton<String>(
                key: ValueKey('user-menu-${u.id}'),
                onSelected: (v) => v == 'rotate' ? _rotate(u) : _deactivate(u),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rotate', child: Text(l10n.usersRotateKey)),
                  PopupMenuItem(value: 'deactivate', child: Text(l10n.usersDeactivate)),
                ],
              ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final UsersApi api;
  const _AddMemberDialog({required this.api});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _name = TextEditingController();
  final _root = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _root.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.usersNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.addMember(name, _root.text.trim());
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, r.data);
    } else {
      setState(() {
        _busy = false;
        _error = r.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.usersAddMember),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('users-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.usersName),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('users-root'),
              controller: _root,
              decoration: InputDecoration(
                labelText: l10n.usersProjectsRoot,
                helperText: l10n.usersProjectsRootHint,
                helperMaxLines: 3,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('users-create'),
          onPressed: _busy ? null : _create,
          child: Text(l10n.usersCreate),
        ),
      ],
    );
  }
}

/// Shows a new key once: copyable text plus a pairing QR (key + worker URL)
/// that the member's phone scans from Settings.
class KeyOnceDialog extends StatefulWidget {
  final IssuedKey issued;
  final String workerUrl;

  const KeyOnceDialog({super.key, required this.issued, required this.workerUrl});

  /// Same format the server's pairing code and show_pairing_qr.py use.
  static String pairingCode(String apiKey, String workerUrl) => base64Encode(
      utf8.encode(jsonEncode({'api_key': apiKey, 'worker_url': workerUrl})));

  @override
  State<KeyOnceDialog> createState() => _KeyOnceDialogState();
}

class _KeyOnceDialogState extends State<KeyOnceDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.issued.apiKey));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final apiKey = widget.issued.apiKey;
    return AlertDialog(
      title: Text(l10n.usersKeyTitle(widget.issued.user.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.usersKeyOnce),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: SelectableText(
                apiKey,
                key: const ValueKey('users-key-text'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('users-copy'),
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
              label: Text(_copied ? l10n.usersKeyCopied : l10n.usersCopyKey),
            ),
            if (widget.workerUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  // Fixed size: AlertDialog measures intrinsic sizes and
                  // QrImageView (a LayoutBuilder) can't answer them.
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: KeyOnceDialog.pairingCode(apiKey, widget.workerUrl),
                      size: 200,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.usersScanToPair, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('users-key-done'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
