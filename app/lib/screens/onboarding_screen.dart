import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _urlController = TextEditingController();
  final _setupUrlController = TextEditingController();
  final _workerUrlController = TextEditingController();

  int _currentPage = 0;
  bool _testing = false;
  bool? _connectionResult;
  String? _connectionError;
  String _connectedServerName = '';
  bool _showSetupPage = false;
  String _detectedWorkerUrl = '';
  bool _detecting = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // Total pages: connect + (optional setup) + success
  int get _pageCount => _showSetupPage ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _tryAutoDetectServer();
  }

  /// Try to auto-detect the server URL from local settings.json
  Future<void> _tryAutoDetectServer() async {
    if (mounted) setState(() => _detecting = true);
    try {
      // Look for settings.json relative to the exe location
      final candidates = <String>[];
      final exeDir = File(Platform.resolvedExecutable).parent;
      final sep = Platform.pathSeparator;
      final settingsRel = '${sep}server${sep}config${sep}settings.json';

      // Same directory as exe (when exe is in repo root)
      candidates.add('${exeDir.path}$settingsRel');
      // Parent directory (when exe is in a subfolder)
      candidates.add('${exeDir.parent.path}$settingsRel');
      // Two levels up (when exe is in build/windows/...)
      candidates.add('${exeDir.parent.parent.path}$settingsRel');

      for (final path in candidates) {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          final host = json['server']?['host'] ?? '0.0.0.0';
          final port = json['server']?['port'] ?? 8000;
          // Use localhost instead of 0.0.0.0 for connecting
          final connectHost = (host == '0.0.0.0') ? 'localhost' : host;
          final url = 'http://$connectHost:$port';

          // Extract worker URL from cloudflare section if available
          final workerUrl =
              json['cloudflare']?['worker_url'] as String? ?? '';
          if (workerUrl.isNotEmpty && mounted) {
            setState(() {
              _detectedWorkerUrl = workerUrl;
            });
            await AppConfig.setWorkerUrl(workerUrl);
          }

          // Test if server is actually running
          try {
            final resp = await http.get(Uri.parse('$url/api/health'))
                .timeout(const Duration(seconds: 2));
            if (resp.statusCode == 200) {
              // Server is running! Auto-connect
              await AppConfig.setBaseUrl(url);
              if (mounted) {
                _urlController.text = url;
                if (_detectedWorkerUrl.isNotEmpty) {
                  _workerUrlController.text = _detectedWorkerUrl;
                }
                setState(() {
                  _connectionResult = true;
                  _connectedServerName = url;
                });
                // Skip straight to success page
                _currentPage = _showSetupPage ? 2 : 1;
                _pageController.jumpToPage(_currentPage);
              }
              return;
            }
          } catch (e) {
            debugPrint('Server connection test failed: $e');
            if (mounted) {
              _urlController.text = url;
              if (_detectedWorkerUrl.isNotEmpty) {
                _workerUrlController.text = _detectedWorkerUrl;
              }
            }
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Auto-detect server failed: $e');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _setupUrlController.dispose();
    _workerUrlController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    final host = url.replaceFirst(RegExp(r'https?://'), '').split(':').first.split('/').first;
    return host == 'localhost' || host.contains('.');
  }

  Future<void> _testConnection(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    if (!_isValidUrl(url)) {
      setState(() {
        _connectionResult = false;
        _connectionError = 'Enter a valid URL (e.g. http://192.168.1.100:8000)';
      });
      return;
    }

    // Normalize: remove trailing slash
    final normalized = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    setState(() {
      _testing = true;
      _connectionResult = null;
      _connectionError = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$normalized/api/health'))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _testing = false;
          _connectionResult = true;
          _connectedServerName = normalized;
        });
      } else {
        setState(() {
          _testing = false;
          _connectionResult = false;
          _connectionError = 'Server returned status ${response.statusCode}';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _testing = false;
          _connectionResult = false;
          _connectionError = 'Connection timed out';
        });
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _connectionResult = false;
          _connectionError = 'Cannot reach server: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _connectionResult = false;
          _connectionError = 'Error: $e';
        });
      }
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onConnectSuccess(String url) {
    // Go to the final "You're All Set" page
    final lastPage = _pageCount - 1;
    _goToPage(lastPage);
  }

  void _showSetupInstructions() {
    setState(() {
      _showSetupPage = true;
      _connectionResult = null;
      _connectionError = null;
    });
    // After rebuild, navigate to setup page (page index 1)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToPage(1);
    });
  }

  Future<void> _getStarted() async {
    final url = _connectedServerName;
    if (url.isEmpty) return;

    await AppConfig.setBaseUrl(url);

    // Save to Google Drive if signed in
    if (AuthService.instance.isSignedIn) {
      try {
        await DriveService.instance.saveServer(
          ServerConnection(
            name: Uri.parse(url).host,
            url: url,
            lastConnected: DateTime.now().toIso8601String(),
          ),
        );
      } catch (e) {
        debugPrint('Drive save failed: $e');
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildConnectPage(),
                  if (_showSetupPage) _buildSetupPage(),
                  _buildSuccessPage(),
                ],
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: () => _goToPage(_currentPage - 1),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                      ),
                    ),
                  const Spacer(),
                  if (_currentPage == 0)
                    TextButton(
                      onPressed: _showSetupInstructions,
                      child: Text(
                        'Need help setting up?',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 1: Connect to Your Server
  // ---------------------------------------------------------------------------
  Widget _buildConnectPage() {
    if (_isDesktop) {
      return _buildDesktopConnectPage();
    } else {
      return _buildMobileConnectPage();
    }
  }

  /// Desktop connect page: direct server URL (same as before)
  Widget _buildDesktopConnectPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Center(
            child: Icon(
              Icons.dns_outlined,
              size: 56,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Connect to Your Server',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Enter the URL of your Auto Game Builder server',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          if (_detecting) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Detecting server...', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              ],
            ),
          ],
          const SizedBox(height: 32),

          // URL field
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: Icon(Icons.link),
              labelText: 'Server URL',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _testConnection(_urlController.text),
          ),
          const SizedBox(height: 16),

          // Test connection button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testing
                  ? null
                  : () => _testConnection(_urlController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgCard,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering, size: 20),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),
          ),
          const SizedBox(height: 16),

          // Connection result
          if (_connectionResult != null)
            _buildConnectionResult(
              success: _connectionResult!,
              error: _connectionError,
              onContinue: () => _onConnectSuccess(_urlController.text.trim()),
            ),
        ],
      ),
    );
  }

  /// Mobile (Android) connect page: Worker URL field
  Widget _buildMobileConnectPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Center(
            child: Icon(
              Icons.cloud_outlined,
              size: 56,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Connect to Your Server',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Enter your Worker URL to connect remotely',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Worker URL field
          TextField(
            controller: _workerUrlController,
            decoration: const InputDecoration(
              hintText: 'https://auto-game-builder.you.workers.dev',
              prefixIcon: Icon(Icons.cloud),
              labelText: 'Worker URL',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                _testConnection(_workerUrlController.text),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Get this URL from the desktop app or your server admin',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // OR divider — allow direct URL too
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade700)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 16),

          // Direct server URL field (for LAN usage)
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: Icon(Icons.link),
              labelText: 'Direct Server URL (LAN)',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _testConnection(_urlController.text),
          ),
          const SizedBox(height: 16),

          // Test connection button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testing
                  ? null
                  : () {
                      // Prefer worker URL if filled, otherwise use direct URL
                      final workerUrl = _workerUrlController.text.trim();
                      final directUrl = _urlController.text.trim();
                      if (workerUrl.isNotEmpty) {
                        _testConnection(workerUrl);
                      } else if (directUrl.isNotEmpty) {
                        _testConnection(directUrl);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgCard,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering, size: 20),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),
          ),
          const SizedBox(height: 16),

          // Connection result
          if (_connectionResult != null)
            _buildConnectionResult(
              success: _connectionResult!,
              error: _connectionError,
              onContinue: () {
                // Save the worker URL if that's what was used
                final workerUrl = _workerUrlController.text.trim();
                if (workerUrl.isNotEmpty) {
                  AppConfig.setWorkerUrl(workerUrl);
                  _onConnectSuccess(workerUrl);
                } else {
                  _onConnectSuccess(_urlController.text.trim());
                }
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 2 (optional): Setup Instructions
  // ---------------------------------------------------------------------------
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Center(
            child: Icon(
              Icons.terminal,
              size: 56,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Setup Instructions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Set up the server on your PC first',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // GitHub link
          Center(
            child: InkWell(
              onTap: () => _openExternalUrl(
                  'https://github.com/Lifecharger/auto-game-builder'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.code, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    const Text(
                      'View on GitHub',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new,
                        size: 14, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildStep(1, 'Install Python 3.10+ on your PC'),
          _buildStep(2, 'Clone the repository:'),
          _buildCodeBlock(
              'git clone https://github.com/Lifecharger/auto-game-builder.git'),
          _buildStep(3, 'Install dependencies:'),
          _buildCodeBlock(
              'cd auto-game-builder\npip install -r server/requirements.txt'),
          _buildStep(4, 'Run the setup wizard:'),
          _buildCodeBlock('python setup_wizard.py'),
          _buildStep(5, 'Start the server:'),
          _buildCodeBlock('python server/main.py'),
          _buildStep(6,
              'Enter the URL shown in the terminal (e.g. http://192.168.1.100:8000):'),

          const SizedBox(height: 16),

          // URL field
          TextField(
            controller: _setupUrlController,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: Icon(Icons.link),
              labelText: 'Server URL',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _testConnection(_setupUrlController.text),
          ),
          const SizedBox(height: 16),

          // Test connection button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testing
                  ? null
                  : () => _testConnection(_setupUrlController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgCard,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering, size: 20),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),
          ),
          const SizedBox(height: 16),

          // Connection result
          if (_connectionResult != null)
            _buildConnectionResult(
              success: _connectionResult!,
              error: _connectionError,
              onContinue: () =>
                  _onConnectSuccess(_setupUrlController.text.trim()),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Final Page: You're All Set!
  // ---------------------------------------------------------------------------
  Widget _buildSuccessPage() {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.lifecharger.appmanager';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 56,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "You're All Set!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connected to $_connectedServerName',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Desktop-only: "Connect your phone" section
          if (_isDesktop) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android,
                          color: AppColors.info, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Connect your phone',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Worker URL display
                  if (_detectedWorkerUrl.isNotEmpty) ...[
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _detectedWorkerUrl,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _detectedWorkerUrl));
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
                            tooltip: 'Copy URL',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter this URL in the phone app to connect remotely',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'No Worker URL detected in settings.json.\n'
                      'Set up a Cloudflare Worker to enable remote access.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 12),

                  // Play Store section
                  const Text(
                    'Scan to install on your phone',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _openExternalUrl(playStoreUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new,
                              size: 16, color: AppColors.info),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              playStoreUrl,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.info,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _getStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open URL: $e');
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

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildConnectionResult({
    required bool success,
    String? error,
    required VoidCallback onContinue,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: success
            ? AppColors.success.withOpacity(0.12)
            : AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: success
              ? AppColors.success.withOpacity(0.4)
              : AppColors.error.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: success ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? 'Connection successful!'
                      : error ?? 'Connection failed',
                  style: TextStyle(
                    color: success ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (success) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Continue'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 40, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }
}
