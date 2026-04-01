import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  final _urlController = TextEditingController();
  final _workerUrlController = TextEditingController();
  bool _testing = false;
  bool? _connectionResult;
  String _version = '';
  String _playStoreUrl = '';
  bool _editingWorkerUrl = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  final AuthService _auth = AuthService.instance;
  final BillingService _billing = BillingService.instance;
  bool _billingReady = false;
  bool _serverRunning = false;
  Process? _serverProcess;
  Map<String, dynamic>? _serverSettings;
  bool _settingsEditing = false;
  final Map<String, TextEditingController> _settingsControllers = {};

  @override
  void initState() {
    super.initState();
    _urlController.text = AppConfig.baseUrl;
    _workerUrlController.text = AppConfig.workerUrl;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
          _playStoreUrl =
              'https://play.google.com/store/apps/details?id=${info.packageName}';
        });
      }
    });
    _auth.silentSignIn().then((_) {
      if (mounted) setState(() {});
    });
    if (_isDesktop) _loadServerSettings();
    _billing.initialize().then((_) {
      if (mounted) {
        setState(() => _billingReady = true);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _workerUrlController.dispose();
    for (final c in _settingsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _findSettingsPath() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final sep = Platform.pathSeparator;
    final rel = '${sep}server${sep}config${sep}settings.json';
    // Walk up to 8 levels from exe dir to find the project root
    Directory dir = exeDir;
    for (int i = 0; i < 8; i++) {
      final p = '${dir.path}$rel';
      if (File(p).existsSync()) return p;
      final parent = dir.parent;
      if (parent.path == dir.path) break; // reached filesystem root
      dir = parent;
    }
    return null;
  }

  Future<void> _loadServerSettings() async {
    final path = _findSettingsPath();
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Sync worker URL and server URL from settings.json into AppConfig
      // Always update from settings.json on desktop (settings.json is the source of truth)
      final workerUrl = (json['cloudflare'] as Map<String, dynamic>?)?['worker_url'] as String? ?? '';
      if (workerUrl.isNotEmpty) {
        await AppConfig.setWorkerUrl(workerUrl);
        await AppConfig.setBaseUrl(workerUrl);
        _workerUrlController.text = workerUrl;
        _urlController.text = workerUrl;
      }
      // Also sync API key from settings.json on desktop
      final apiKey = (json['security'] as Map<String, dynamic>?)?['api_key'] as String? ?? '';
      if (apiKey.isNotEmpty) {
        await AppConfig.setApiKey(apiKey);
      }
      final host = (json['server'] as Map<String, dynamic>?)?['host'] as String? ?? '0.0.0.0';
      final port = (json['server'] as Map<String, dynamic>?)?['port'] ?? 8000;
      final connectHost = (host == '0.0.0.0') ? 'localhost' : host;
      final serverUrl = 'http://$connectHost:$port';
      if (AppConfig.baseUrl.isEmpty) {
        await AppConfig.setBaseUrl(serverUrl);
        _urlController.text = serverUrl;
      }

      if (mounted) {
        setState(() {
          _serverSettings = json;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveServerSettings() async {
    final path = _findSettingsPath();
    if (path == null || _serverSettings == null) return;

    // Apply controller values back to the settings map
    for (final entry in _settingsControllers.entries) {
      final keys = entry.key.split('.');
      if (keys.length == 2) {
        final section = _serverSettings![keys[0]];
        if (section is Map<String, dynamic>) {
          final val = entry.value.text.trim();
          // Preserve booleans and ints
          if (section[keys[1]] is bool) {
            section[keys[1]] = val.toLowerCase() == 'true';
          } else if (section[keys[1]] is int) {
            section[keys[1]] = int.tryParse(val) ?? section[keys[1]];
          } else {
            section[keys[1]] = val;
          }
        }
      }
    }

    try {
      final encoder = const JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(_serverSettings));
      if (mounted) {
        setState(() => _settingsEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved — restart server to apply'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

            // Server Control (desktop only)
            if (_isDesktop) _buildServerControlCard(),

            // Server Configuration (all paths, desktop only)
            if (_isDesktop) ...[
              _buildServerConfigCard(),
              const SizedBox(height: 16),
            ],

            // Server Connection (Worker URL) card
            _buildServerConnectionCard(),
            const SizedBox(height: 16),

            // Donate card (always show on Android)
            if (!_isDesktop)
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
                          onPressed: (_billingReady && _billing.isAvailable)
                              ? () async {
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
                                }
                              : () {
                                  _openUrl(_playStoreUrl);
                                },
                          icon: const Icon(Icons.coffee),
                          label: Text(
                            (_billingReady && _billing.isAvailable)
                                ? 'Buy me a coffee  ${_billing.donatePrice ?? ''}'
                                : 'Buy me a coffee',
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
            if (!_isDesktop) const SizedBox(height: 16),

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

  Future<void> _toggleServer() async {
    if (_serverRunning && _serverProcess != null) {
      _serverProcess!.kill();
      _serverProcess = null;
      setState(() => _serverRunning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server stopped'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Find start_server.py relative to exe
    final exeDir = File(Platform.resolvedExecutable).parent;
    final sep = Platform.pathSeparator;
    final candidates = [
      '${exeDir.path}${sep}start_server.py',
      '${exeDir.parent.path}${sep}start_server.py',
      '${exeDir.parent.parent.path}${sep}start_server.py',
    ];

    String? scriptPath;
    for (final c in candidates) {
      if (File(c).existsSync()) {
        scriptPath = c;
        break;
      }
    }

    if (scriptPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('start_server.py not found'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      _serverProcess = await Process.start(
        'python',
        [scriptPath],
        mode: ProcessStartMode.detached,
      );
      setState(() => _serverRunning = true);

      // Wait a moment then test connection
      await Future.delayed(const Duration(seconds: 3));
      final ok = await ApiService.healthCheck();
      if (mounted) {
        setState(() => _serverRunning = ok);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Server started!' : 'Server started but health check failed'),
            backgroundColor: ok ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start server: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildServerControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _serverRunning ? Icons.dns : Icons.dns_outlined,
                  color: _serverRunning ? AppColors.success : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Server',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _serverRunning
                        ? AppColors.success.withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _serverRunning ? 'Running' : 'Stopped',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _serverRunning ? AppColors.success : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleServer,
                icon: Icon(_serverRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_serverRunning ? 'Stop Server' : 'Start Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _serverRunning ? AppColors.error : AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
    if (_serverSettings == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.settings_applications, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Server Configuration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text('settings.json not found',
                  style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    // Editable fields grouped by section
    const sectionLabels = {
      'paths': 'Paths',
      'ai_agents': 'AI Agents',
      'engines': 'Game Engines',
      'system': 'System Tools',
      'cloudflare': 'Cloudflare',
      'developer': 'Developer',
      'server': 'Server',
      'services': 'Services',
    };

    const fieldIcons = {
      'projects_root': Icons.folder,
      'keys_dir': Icons.key,
      'tools_dir': Icons.build,
      'service_account_key': Icons.vpn_key,
      'claude_path': Icons.smart_toy,
      'gemini_path': Icons.smart_toy,
      'codex_path': Icons.smart_toy,
      'aider_path': Icons.smart_toy,
      'flutter_path': Icons.flutter_dash,
      'godot_path': Icons.videogame_asset,
      'bash_path': Icons.terminal,
      'cloudflared_path': Icons.cloud,
      'npx_path': Icons.code,
      'tunnel_enabled': Icons.router,
      'kv_namespace_id': Icons.storage,
      'account_id': Icons.account_box,
      'worker_url': Icons.link,
      'developer_name': Icons.person,
      'host': Icons.dns,
      'port': Icons.numbers,
      'ollama_url': Icons.psychology,
    };

    Widget buildField(String section, String key, dynamic value) {
      final fullKey = '$section.$key';
      if (!_settingsControllers.containsKey(fullKey)) {
        _settingsControllers[fullKey] = TextEditingController(text: value.toString());
      }
      final controller = _settingsControllers[fullKey]!;
      if (!_settingsEditing) {
        controller.text = value.toString();
      }
      final icon = fieldIcons[key] ?? Icons.settings;
      final label = key.replaceAll('_', ' ').replaceAllMapped(
          RegExp(r'(^|\s)(\w)'), (m) => '${m[1]}${m[2]!.toUpperCase()}');

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          readOnly: !_settingsEditing,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            isDense: true,
            filled: !_settingsEditing,
            fillColor: _settingsEditing ? null : Colors.grey.withAlpha(15),
          ),
          style: TextStyle(
            fontSize: 13,
            color: _settingsEditing ? Colors.white : Colors.grey.shade400,
          ),
        ),
      );
    }

    final sections = <Widget>[];
    for (final sectionKey in sectionLabels.keys) {
      final sectionData = _serverSettings![sectionKey];
      if (sectionData is! Map<String, dynamic> || sectionData.isEmpty) continue;

      sections.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          sectionLabels[sectionKey]!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            letterSpacing: 1,
          ),
        ),
      ));

      for (final entry in sectionData.entries) {
        sections.add(buildField(sectionKey, entry.key, entry.value));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.settings_applications, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Server Configuration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'settings.json — restart server after changes',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            ...sections,
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_settingsEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _settingsEditing = true),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                if (_settingsEditing) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _loadServerSettings();
                        setState(() => _settingsEditing = false);
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveServerSettings,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadServerSettings,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Reload',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConnectionCard() {
    final workerUrl = AppConfig.workerUrl;
    final hasWorkerUrl = workerUrl.isNotEmpty;

    if (_isDesktop) {
      // Windows/desktop: read-only display
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_sync, color: AppColors.info),
                  SizedBox(width: 8),
                  Text(
                    'Server Connection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Worker URL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasWorkerUrl ? workerUrl : 'Not configured',
                        style: TextStyle(
                          fontFamily: hasWorkerUrl ? 'monospace' : null,
                          fontSize: 13,
                          color: hasWorkerUrl
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (hasWorkerUrl)
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: workerUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Worker URL copied'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        color: Colors.grey.shade400,
                        tooltip: 'Copy',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasWorkerUrl
                    ? 'Auto-detected from settings.json (read-only)'
                    : 'Set cloudflare.worker_url in server/config/settings.json',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              // Pairing QR code button (desktop only)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showPairingQr,
                  icon: const Icon(Icons.qr_code, size: 20),
                  label: const Text('Show Pairing QR Code'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Server URL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Text(
                  AppConfig.baseUrl.isNotEmpty
                      ? AppConfig.baseUrl
                      : 'Not connected',
                  style: TextStyle(
                    fontFamily: AppConfig.baseUrl.isNotEmpty ? 'monospace' : null,
                    fontSize: 13,
                    color: AppConfig.baseUrl.isNotEmpty
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Android/mobile: editable worker URL
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync, color: AppColors.info),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Server Connection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Pairing status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConfig.isPaired
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppConfig.isPaired ? Icons.lock : Icons.lock_open,
                        size: 14,
                        color: AppConfig.isPaired ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppConfig.isPaired ? 'Paired' : 'Not paired',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppConfig.isPaired ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // QR Scan pairing button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _scanQrToPair,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: Text(AppConfig.isPaired ? 'Re-pair with QR Code' : 'Scan QR Code to Pair'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppConfig.isPaired ? Colors.grey.shade700 : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_editingWorkerUrl && hasWorkerUrl) ...[
              // Show current worker URL with Edit button
              Text(
                'Worker URL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Text(
                  workerUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _workerUrlController.text = workerUrl;
                    setState(() => _editingWorkerUrl = true);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Worker URL'),
                ),
              ),
            ] else ...[
              // Edit mode or no URL set
              TextField(
                controller: _workerUrlController,
                decoration: const InputDecoration(
                  hintText: 'https://auto-game-builder.you.workers.dev',
                  prefixIcon: Icon(Icons.cloud),
                  labelText: 'Worker URL',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Text(
                'Get this URL from the desktop app or your server admin',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_editingWorkerUrl)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _editingWorkerUrl = false);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                  if (_editingWorkerUrl) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveWorkerUrl,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Server URL',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Text(
                AppConfig.baseUrl.isNotEmpty
                    ? AppConfig.baseUrl
                    : 'Not connected',
                style: TextStyle(
                  fontFamily: AppConfig.baseUrl.isNotEmpty ? 'monospace' : null,
                  fontSize: 13,
                  color: AppConfig.baseUrl.isNotEmpty
                      ? Colors.white
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPairingQr() {
    // Read API key from server settings.json (desktop only)
    final apiKey = (_serverSettings?['security']
            as Map<String, dynamic>?)?['api_key'] as String? ??
        '';
    final workerUrl = (_serverSettings?['cloudflare']
            as Map<String, dynamic>?)?['worker_url'] as String? ??
        '';

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No API key found — restart the server to generate one'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final pairData = base64Encode(
      utf8.encode(jsonEncode({'api_key': apiKey, 'worker_url': workerUrl})),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan this QR from your phone'),
        content: SizedBox(
          width: 280,
          height: 280,
          child: Center(
            child: QrImageView(
              data: pairData,
              version: QrVersions.auto,
              size: 260,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQrToPair() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QrScanScreen(),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await AppConfig.applyPairingData(result);
      _workerUrlController.text = AppConfig.workerUrl;
      _urlController.text = AppConfig.baseUrl;
      setState(() => _editingWorkerUrl = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paired successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveWorkerUrl() async {
    final url = _workerUrlController.text.trim();
    if (url.isEmpty) return;
    await AppConfig.setWorkerUrl(url);
    if (mounted) {
      setState(() => _editingWorkerUrl = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker URL saved'),
          backgroundColor: AppColors.success,
        ),
      );
    }
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


/// Full-screen QR scanner for pairing.
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Pairing QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode?.rawValue == null) return;
          _scanned = true;
          Navigator.of(context).pop(barcode!.rawValue);
        },
      ),
    );
  }
}
