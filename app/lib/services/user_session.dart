import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// The AGB user this app's API key belongs to (`GET /api/me`).
class CurrentUser {
  final int id;
  final String name;
  final String role; // admin | member

  const CurrentUser({required this.id, required this.name, required this.role});

  bool get isAdmin => role != 'member';

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'admin',
      );
}

/// Who is signed in to the server, and therefore what the app shows.
///
/// Members see only their own apps (the server filters every list) and none
/// of the server-wide tools: Asset and Delivery modes, the build queue,
/// server reset, project scan, report pulling and user management are hidden.
/// The server refuses those calls for members anyway; hiding them keeps the
/// app from offering what can't work.
///
/// The last known user is kept on disk so a member never sees admin tools
/// flash up at start. Until the server has answered once, the app behaves as
/// before (admin): a single-key server is always admin.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  static const _idKey = 'agb_user_id';
  static const _nameKey = 'agb_user_name';
  static const _roleKey = 'agb_user_role';

  final ValueNotifier<CurrentUser?> user = ValueNotifier<CurrentUser?>(null);

  bool _fetched = false;
  Future<void>? _inFlight;

  /// True once `/api/me` answered in this app session.
  bool get fetched => _fetched;
  bool get isMember => user.value?.isAdmin == false;
  bool get isAdmin => !isMember;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_roleKey);
      if (role != null) {
        user.value = CurrentUser(
          id: prefs.getInt(_idKey) ?? 0,
          name: prefs.getString(_nameKey) ?? '',
          role: role,
        );
      }
    } catch (e) {
      debugPrint('UserSession.load failed: $e');
    }
  }

  /// Ask the server who this key belongs to ([ApiService.getMe] treats an
  /// older single-key server, which has no `/api/me`, as the admin).
  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    final result = await ApiService.getMe();
    if (result.ok) await _set(result.data!);
    // Any failure (offline, key refused) keeps the last known user.
  }

  Future<void> _set(CurrentUser u) async {
    _fetched = true;
    user.value = u;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_idKey, u.id);
      await prefs.setString(_nameKey, u.name);
      await prefs.setString(_roleKey, u.role);
    } catch (e) {
      debugPrint('UserSession save failed: $e');
    }
  }

  /// Forget the user, e.g. right after pairing with a different key.
  Future<void> clear() async {
    _fetched = false;
    user.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_idKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_roleKey);
    } catch (e) {
      debugPrint('UserSession clear failed: $e');
    }
  }

  @visibleForTesting
  void setForTest(CurrentUser? u) {
    user.value = u;
    _fetched = u != null;
  }
}

/// Shows [child] only to admins; members get [fallback] (nothing by default).
class AdminOnly extends StatelessWidget {
  final Widget child;
  final Widget fallback;

  const AdminOnly({super.key, required this.child, this.fallback = const SizedBox.shrink()});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CurrentUser?>(
      valueListenable: UserSession.instance.user,
      builder: (_, u, _) => (u?.isAdmin ?? true) ? child : fallback,
    );
  }
}
