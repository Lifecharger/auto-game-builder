import 'package:flutter/material.dart';
import '../theme.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import 'onboarding_screen.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // On platforms without Google Sign-In (Windows, Linux), skip to onboarding
    if (!AuthService.instance.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateTo(const OnboardingScreen());
      });
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final account = await AuthService.instance.signIn();
      if (account == null) {
        setState(() {
          _loading = false;
          _error = 'Sign-in was cancelled';
        });
        return;
      }

      // Try to load saved servers from Google Drive
      final servers = await DriveService.instance.loadServers();
      if (!mounted) return;

      if (servers.isNotEmpty) {
        // Sort by lastConnected descending and pick the most recent
        servers.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
        final mostRecent = servers.first;

        // Save the URL locally and navigate to MainShell
        await AppConfig.setBaseUrl(mostRecent.url);
        if (!mounted) return;

        _navigateTo(const MainShell());
      } else {
        // No saved servers -- go to onboarding
        _navigateTo(const OnboardingScreen());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign-in failed: $e';
        });
      }
    }
  }

  void _skipForNow() {
    _navigateTo(const OnboardingScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.sports_esports,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 24),

                // App name
                const Text(
                  'Auto Game Builder',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Manage your game projects from anywhere',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Error message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : Image.network(
                            'https://developers.google.com/identity/images/g-logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata,
                              size: 24,
                              color: Colors.blue,
                            ),
                          ),
                    label: Text(
                      _loading ? 'Signing in...' : 'Sign in with Google',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Skip button
                TextButton(
                  onPressed: _loading ? null : _skipForNow,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
