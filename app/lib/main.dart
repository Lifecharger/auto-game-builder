import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/event_service.dart';
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
  await Hive.initFlutter();
  await CacheService.instance.openBoxes();
  // Enable edge-to-edge so Flutter properly handles system bar insets
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  try {
    await AppConfig.load();
  } catch (e) {
    debugPrint('AppConfig.load failed, using defaults: $e');
  }

  // Try silent sign-in (non-blocking if it fails)
  try {
    await AuthService.instance.silentSignIn();
  } catch (e) {
    debugPrint('Silent sign-in failed: $e');
  }

  runApp(const AppManagerMobile());
}

class AppManagerMobile extends StatelessWidget {
  const AppManagerMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = AppState();
        // Bind EventService so force-refresh can stop/restart it to
        // prevent replayed old events from overwriting fresh sync data.
        final events = EventService(state);
        state.bindEventService(events);
        // Initial sync first, then start the SSE event stream.
        state.loadApps().then((_) => events.start());
        return state;
      },
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

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBackPress;
  late final AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  AppState? _appStateRef;

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
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appStateRef = context.read<AppState>();
      _appStateRef!.addListener(_onAppStateChanged);
      _appStateRef!.startHealthCheck();
    });
    _checkForUpdate();
  }

  @override
  void dispose() {
    _appStateRef?.removeListener(_onAppStateChanged);
    _fadeController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = _appStateRef;
    if (appState != null && appState.issuesRequestedAppId != null && _currentIndex != 1) {
      _switchTab(1);
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    _fadeController.reverse().then((_) {
      setState(() => _currentIndex = index);
      context.read<AppState>().setActiveTab(index);
      _fadeController.forward();
    });
  }

  Future<void> _checkForUpdate() async {
    final hasUpdate = await UpdateChecker.instance.check();
    if (hasUpdate && mounted) {
      _showUpdateDialog();
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 40, color: AppColors.info),
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'v${UpdateChecker.instance.latestVersion}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'A new version is available on GitHub.\nPull the latest code and rebuild to update.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await UpdateChecker.instance.pull();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result), duration: const Duration(seconds: 3)),
                );
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Pull Only'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              UpdateChecker.instance.launchUpdateAndExit();
            },
            icon: const Icon(Icons.build, size: 18),
            label: const Text('Pull & Rebuild'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final connected = appState.connected;
    final pendingCount = appState.pendingTaskCount;

    final showOffline = appState.showOfflineBanner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on Dashboard, go to Dashboard first
        if (_currentIndex != 0) {
          _switchTab(0);
          return;
        }
        // On Dashboard: require double-tap back to exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
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
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
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
    ),
    );
  }
}
