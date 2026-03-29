import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _consoleUrlKey = 'google_console_url';

  final _urlController = TextEditingController();
  final _consoleUrlController = TextEditingController();
  bool _testing = false;
  bool? _connectionResult;
  String _version = '';
  String _playStoreUrl = '';

  final AuthService _auth = AuthService.instance;
  final BillingService _billing = BillingService.instance;
  bool _billingReady = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = AppConfig.baseUrl;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
          _playStoreUrl =
              'https://play.google.com/store/apps/details?id=${info.packageName}';
        });
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        _consoleUrlController.text = prefs.getString(_consoleUrlKey) ?? '';
      }
    });
    _auth.silentSignIn().then((_) {
      if (mounted) setState(() {});
    });
    _billing.initialize().then((_) {
      if (mounted) {
        setState(() => _billingReady = true);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _consoleUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await AppConfig.setBaseUrl(url);
    if (mounted) {
      setState(() => _connectionResult = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API URL saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveConsoleUrl() async {
    final url = _consoleUrlController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_consoleUrlKey, url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Console URL saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _connectionResult = null;
    });
    final result = await ApiService.healthCheck();
    if (mounted) {
      setState(() {
        _testing = false;
        _connectionResult = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'Connected successfully' : 'Connection failed'),
          backgroundColor: result ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {},
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
          children: [
            // Google Account card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_circle, color: AppColors.info),
                        SizedBox(width: 8),
                        Text(
                          'Google Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_auth.isSignedIn) ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: _auth.userPhoto != null
                                ? NetworkImage(_auth.userPhoto!)
                                : null,
                            child: _auth.userPhoto == null
                                ? const Icon(Icons.person, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _auth.userName ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_auth.userEmail != null)
                                  Text(
                                    _auth.userEmail!,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _auth.signOut();
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              await _auth.signIn();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sign-in failed: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // API URL card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud, color: AppColors.info),
                        SizedBox(width: 8),
                        Text(
                          'API Connection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'http://localhost:8000',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _connectionResult != null
                            ? Icon(
                                _connectionResult!
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _connectionResult!
                                    ? AppColors.success
                                    : AppColors.error,
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_find),
                            label: const Text('Test'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveUrl,
                            icon: const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Google Play links card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shop, color: AppColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Google Play',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(_playStoreUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in Google Play'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: AppColors.info),
                        SizedBox(width: 8),
                        Text(
                          'Play Console',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste your internal testing page URL below',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _consoleUrlController,
                      decoration: const InputDecoration(
                        hintText: 'https://play.google.com/console/...',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final url = _consoleUrlController.text.trim();
                              if (url.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Paste a Console URL first'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }
                              _openUrl(url);
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open Console'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveConsoleUrl,
                            icon: const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hint card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.warning),
                        SizedBox(width: 8),
                        Text(
                          'Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _tipItem('For local dev, use your machine\'s IP address'),
                    _tipItem('For remote access, use a Cloudflare tunnel URL'),
                    _tipItem('The URL should point to the FastAPI backend'),
                    _tipItem('Default port is 8000'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Donate card
            if (_billingReady && _billing.isAvailable)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            'Support Development',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enjoying the app? Consider supporting development!',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              await _billing.donate();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Purchase failed: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.coffee),
                          label: Text(
                            'Buy me a coffee  ${_billing.donatePrice ?? ''}',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_billingReady && _billing.isAvailable)
              const SizedBox(height: 16),

            // About card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _aboutItem('App', 'AppManager Mobile'),
                    _aboutItem('Version', _version.isEmpty ? '...' : _version),
                    _aboutItem('Backend', 'FastAPI'),
                    _aboutItem('Developer', 'LifeCharger'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('  -  ', style: TextStyle(color: Colors.grey.shade500)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
