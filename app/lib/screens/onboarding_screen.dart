import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  int _currentPage = 0;
  bool _testing = false;
  bool? _connectionResult;
  String? _connectionError;
  String _connectedServerName = '';
  bool _showSetupPage = false;

  // Total pages: connect + (optional setup) + success
  int get _pageCount => _showSetupPage ? 3 : 2;

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _setupUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

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
      } catch (_) {
        // Non-fatal: Drive save failed
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

          _buildStep(1, 'Install Python 3.10+ on your PC'),
          _buildStep(2, 'Open a terminal and run:'),
          _buildCodeBlock(
              'git clone https://github.com/Lifecharger/auto-game-builder.git'),
          _buildStep(3, 'Install dependencies:'),
          _buildCodeBlock(
              'cd auto-game-builder && pip install -r server/requirements.txt'),
          _buildStep(4, 'Run the setup wizard:'),
          _buildCodeBlock('python setup_wizard.py'),
          _buildStep(5, 'Start the server:'),
          _buildCodeBlock('python server/main.py'),
          _buildStep(6, 'Enter the URL shown after setup below:'),

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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          const SizedBox(height: 40),
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
