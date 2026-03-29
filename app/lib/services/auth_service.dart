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

  GoogleSignIn _getGoogleSignIn() {
    if (_googleSignIn != null) return _googleSignIn!;

    // Use serverClientId on platforms that need the web client ID
    // (Windows, web). On Android, the google-services.json handles it.
    final bool needsWebClientId = kIsWeb || (!kIsWeb && Platform.isWindows);

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
    final gsi = _getGoogleSignIn();
    try {
      _currentUser = await gsi.signInSilently();
      return _currentUser;
    } catch (e) {
      // Silent sign-in failed — user will need interactive sign-in
      return null;
    }
  }

  /// Interactive sign-in flow.
  Future<GoogleSignInAccount?> signIn() async {
    final gsi = _getGoogleSignIn();
    try {
      _currentUser = await gsi.signIn();
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out and clear cached credentials.
  Future<void> signOut() async {
    final gsi = _getGoogleSignIn();
    await gsi.signOut();
    _currentUser = null;
  }

  /// Returns auth headers suitable for Google API calls.
  /// Returns null if user is not signed in or auth fails.
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
