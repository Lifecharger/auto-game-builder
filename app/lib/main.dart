import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'l10n/app_localizations.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/event_service.dart';
import 'services/generate_service.dart' show QueueService;
import 'services/locale_service.dart';
import 'services/mode_service.dart';
import 'services/theme_service.dart';
import 'services/update_checker.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/control_screen.dart';
import 'screens/chat_logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/asset_generate_screen.dart';
import 'screens/asset_gallery_screen.dart';
import 'screens/asset_queue_screen.dart';
import 'screens/asset_flow_hub.dart';

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

  await ThemeService.instance.load();
  await LocaleService.instance.load();

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
      child: ListenableBuilder(
        listenable: Listenable.merge(
          [ThemeService.instance, LocaleService.instance],
        ),
        builder: (context, _) {
          return MaterialApp(
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            locale: LocaleService.instance.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppConfig.baseUrl.isEmpty
                ? const LoginScreen()
                : const MainShell(),
          );
        },
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  int _currentIndex = 0;
  DateTime? _lastBackPress;
  late final AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  AppState? _appStateRef;

  /// Uygulama modu. Code Mod = proje yonetimi, Asset Mod = yerel uretim.
  /// Settings her iki modda da son sekme olarak sabit kalir.
  bool _assetMode = false;

  static const _codeScreens = [
    DashboardScreen(),
    IssuesScreen(),
    ChatLogsScreen(), // Reports & Logs
    ControlScreen(),
    SettingsScreen(),
  ];

  // #352: sekme sirasi kullanicinin istedigi gibi - 1 Uretim, 2 Uretilenler,
  // 3 Hat, 4 Sira, 5 Ayarlar (Sira en sona yakin; Uretilenler uretimin yani).
  static const _assetScreens = [
    AssetGenerateScreen(),
    AssetGalleryScreen(),
    FlowHub(),
    AssetQueueScreen(),
    SettingsScreen(),
  ];

  List<Widget> get _screens => _assetMode ? _assetScreens : _codeScreens;

  /// ModeService degisince modu uygular. Sekme indeksi sifirlanir,
  /// yoksa yeni moddaki daha kisa listede tasar.
  void _onModeChanged() {
    HapticFeedback.mediumImpact();
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _assetMode = ModeService.isAsset;
        _currentIndex = 0;
      });
      context.read<AppState>().setActiveTab(0);
      _fadeController.forward();
    });
  }

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
    ModeService.assetMode.addListener(_onModeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appStateRef = context.read<AppState>();
      _appStateRef!.addListener(_onAppStateChanged);
      _appStateRef!.startHealthCheck();
    });
    _checkForUpdate();
  }

  @override
  void dispose() {
    ModeService.assetMode.removeListener(_onModeChanged);
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
        icon: Icon(Icons.system_update, size: 40, color: AppColors.info),
        title: Text(l10n.updateAvailable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.versionWithNumber('${UpdateChecker.instance.latestVersion}'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.updateAvailableBody,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.later),
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
            label: Text(l10n.pullOnly),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              UpdateChecker.instance.launchUpdateAndExit();
            },
            icon: const Icon(Icons.build, size: 18),
            label: Text(l10n.pullAndRebuild),
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
    final l10n = AppLocalizations.of(context)!;

    final showOffline = appState.showOfflineBanner;
    // gorev #289: edge-to-edge'de icerik durum cubugunun ARKASINDAN basliyor;
    // banner gorunurken ust guvenli alani banner tuketir, sekmelerden dusulur.
    final topInset = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on Dashboard, go to Dashboard first
        if (_currentIndex != 0) {
          _switchTab(0);
          return;
        }
        // Asset Mod'un ilk sekmesindeysek once Code Mod'a don
        if (_assetMode) {
          ModeService.set(false);
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
          SnackBar(
            content: Text(l10n.pressBackAgainToExit),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: showOffline ? 32 + topInset : 0,
            padding: EdgeInsets.only(top: showOffline ? topInset : 0),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.red.shade800,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    l10n.serverUnreachable,
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            // gorev #289: banner ust boslugu zaten yedi; sekmelerin AppBar'lari
            // ayni boslugu ikinci kez eklemesin diye MediaQuery govde
            // context'inden (Scaffold'un ICINDEN) yeniden kuruluyor.
            child: Builder(
              builder: (bodyContext) {
                final bodyMq = MediaQuery.of(bodyContext);
                return MediaQuery(
                  data: showOffline
                      ? bodyMq.removePadding(removeTop: true)
                      : bodyMq,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        type: BottomNavigationBarType.fixed,
        items: _assetMode
            ? [
                // #352: sira = Uretim | Uretilenler | Hat | Sira | Ayarlar
                const BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome),
                  label: 'Uretim',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.photo_library),
                  label: 'Uretilenler',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.conveyor_belt),
                  label: 'Hat',
                ),
                BottomNavigationBarItem(
                  // #299: butun isler tek sunucu sirasina girer - rozet
                  // sirada kac is oldugunu gosterir (dinleyen varken 5 sn'de
                  // bir sorulur, Asset Mod disinda ag trafigi olmaz).
                  icon: ValueListenableBuilder<int>(
                    valueListenable: QueueService.depth,
                    builder: (_, derinlik, child) => Badge(
                      isLabelVisible: derinlik > 0,
                      label: Text('$derinlik',
                          style: const TextStyle(fontSize: 10)),
                      child: child,
                    ),
                    child: const Icon(Icons.playlist_play),
                  ),
                  label: 'Sira',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Ayarlar',
                ),
              ]
            : [
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
                              color: connected ? AppColors.success : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: l10n.dashboard,
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.bug_report),
                  ),
                  label: l10n.issues,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.feedback_outlined),
                  label: l10n.chatLogs,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.tune),
                  label: l10n.control,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: l10n.settings,
                ),
              ],
      ),
    ),
    );
  }
}
