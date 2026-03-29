import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _webClientId =
      '690975384091-q12j999ied80kavhjjrbo666t61jg7dp.apps.googleusercontent.com';

  static const List<String> _scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userName => _currentUser?.displayName;
  String? get userEmail => _currentUser?.email;
  String? get userPhoto => _currentUser?.photoUrl;

  /// Whether Google Sign-In is supported on this platform.
  bool get isSupported {
    if (kIsWeb) return true;
    // google_sign_in supports Android, iOS, macOS, web — NOT Windows/Linux
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  GoogleSignIn _getGoogleSignIn() {
    if (_googleSignIn != null) return _googleSignIn!;

    final bool needsWebClientId = kIsWeb || (!kIsWeb && !Platform.isAndroid);

    _googleSignIn = GoogleSignIn(
      scopes: _scopes,
      serverClientId: needsWebClientId ? _webClientId : null,
    );

    _googleSignIn!.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
    });

    return _googleSignIn!;
  }

  /// Attempt a silent sign-in (uses cached credentials).
  Future<GoogleSignInAccount?> silentSignIn() async {
    if (!isSupported) return null;
    try {
      final gsi = _getGoogleSignIn();
      _currentUser = await gsi.signInSilently();
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Interactive sign-in flow.
  Future<GoogleSignInAccount?> signIn() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform. '
        'Use manual server URL entry instead.',
      );
    }
    try {
      final gsi = _getGoogleSignIn();
      _currentUser = await gsi.signIn();
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out and clear cached credentials.
  Future<void> signOut() async {
    if (!isSupported) return;
    try {
      final gsi = _getGoogleSignIn();
      await gsi.signOut();
    } catch (_) {}
    _currentUser = null;
  }

  /// Returns auth headers suitable for Google API calls.
  Future<Map<String, String>?> getAuthHeaders() async {
    final account = _currentUser;
    if (account == null) return null;
    try {
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) return null;
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      return null;
    }
  }
}
