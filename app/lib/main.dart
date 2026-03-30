import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/update_checker.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/control_screen.dart';
import 'screens/chat_logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge so Flutter properly handles system bar insets
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  await AppConfig.load();

  // Try silent sign-in (non-blocking if it fails)
  try {
    await AuthService.instance.silentSignIn();
  } catch (_) {}

  runApp(const AppManagerMobile());
}

class AppManagerMobile extends StatelessWidget {
  const AppManagerMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadApps(),
      child: MaterialApp(
        title: 'Auto Game Builder',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AppConfig.baseUrl.isEmpty
            ? const LoginScreen()
            : const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _updateAvailable = false;
  bool _updateDismissed = false;
  bool _updating = false;
  String? _updateStatus;

  final _screens = const [
    DashboardScreen(),
    IssuesScreen(),
    ControlScreen(),
    ChatLogsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startHealthCheck();
    });
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final hasUpdate = await UpdateChecker.instance.check();
    if (hasUpdate && mounted) {
      setState(() => _updateAvailable = true);
    }
  }

  Future<void> _doPull() async {
    setState(() { _updating = true; _updateStatus = 'Pulling...'; });
    final result = await UpdateChecker.instance.pull();
    if (mounted) {
      setState(() { _updating = false; _updateStatus = result; });
    }
  }

  Future<void> _doPullAndRebuild() async {
    setState(() { _updating = true; _updateStatus = 'Pulling...'; });
    final pullResult = await UpdateChecker.instance.pull();
    if (!mounted) return;
    if (pullResult.contains('fatal') || pullResult.contains('Error')) {
      setState(() { _updating = false; _updateStatus = pullResult; });
      return;
    }
    setState(() => _updateStatus = 'Building...');
    final buildResult = await UpdateChecker.instance.rebuild();
    if (mounted) {
      setState(() { _updating = false; _updateStatus = buildResult; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final connected = appState.connected;
    final pendingCount = appState.pendingTaskCount;

    final showOffline = appState.showOfflineBanner;

    return Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: showOffline ? 32 : 0,
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.red.shade800,
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Server unreachable',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          // Update available banner (desktop only)
          if (_updateAvailable && !_updateDismissed)
            Container(
              color: AppColors.info,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.system_update, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'v${UpdateChecker.instance.latestVersion} available',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_updateStatus != null)
                          Flexible(
                            child: Text(
                              _updateStatus!,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(width: 4),
                        if (!_updating) ...[
                          TextButton(
                            onPressed: _doPull,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white24,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Pull', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: _doPullAndRebuild,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white24,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Pull & Rebuild', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ] else
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => setState(() => _updateDismissed = true),
                          icon: const Icon(Icons.close, color: Colors.white, size: 16),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.read<AppState>().setActiveTab(index);
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.dashboard),
                if (connected != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: connected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.bug_report),
            ),
            label: 'Issues',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: 'Control',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Chat & Logs',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
