import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'l10n/app_localizations.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/event_service.dart';
import 'services/generate_service.dart' show QueueService;
import 'services/lifecharger_analytics.dart';
import 'services/locale_service.dart';
import 'services/mode_service.dart';
import 'services/theme_service.dart';
import 'services/update_checker.dart';
import 'services/usage_events.dart';
import 'services/user_session.dart';
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
import 'services/lifecharger_update_gate.dart';
import 'screens/delivery_screen.dart'; // #363
import 'screens/buckets_screen.dart'; // #381
import 'services/lifecharger_intro.dart';
import 'services/demo/demo_mode.dart';
import 'widgets/app_toast.dart';

/// Every `http` call of the app goes through [DemoMode.clientFactory]: the
/// normal network client, or the in-memory demo server while demo mode runs.
void main() => http.runWithClient(_main, DemoMode.clientFactory);

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge so Flutter properly handles system bar insets
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  // The LifeCharger intro is the first thing drawn: its gauge ring charges
  // with the start-up work below and it strikes into the app once attached.
  // The app has no sound-effects setting, so the intro's sound is always on.
  final intro = await LifechargerIntroController.create();
  intro.soundEnabled = true;
  runApp(LifechargerIntroHost(controller: intro));
  await Hive.initFlutter();
  await CacheService.instance.openBoxes();
  intro.progress = .2;
  try {
    await AppConfig.load();
  } catch (e) {
    debugPrint('AppConfig.load failed, using defaults: $e');
  }
  intro.progress = .3;

  await ThemeService.instance.load();
  await LocaleService.instance.load();
  await UserSession.instance.load();
  intro.progress = .4;

  // Try silent sign-in (non-blocking if it fails)
  try {
    await AuthService.instance.silentSignIn();
  } catch (e) {
    debugPrint('Silent sign-in failed: $e');
  }
  intro.progress = .75;

  await _startAnalytics();
  intro.progress = .9;

  intro.attachApp(ForcedUpdateGate(child: const AppManagerMobile()));
}

/// Brings up anonymous usage reporting: how often and how long the app is
/// used, and which mode or screen is opened. Nothing identifying the work
/// itself is ever reported - no project names, task text, paths, server
/// addresses or keys, only the fixed screen names in [_kCodeTabs] and friends.
///
/// A failure here never blocks the app: the client queues on disk and never
/// awaits the network, and an exception is printed and stepped over.
Future<void> _startAnalytics() async {
  try {
    final info = await PackageInfo.fromPlatform();
    await Analytics.init(
      package: 'com.lifecharger.appmanager',
      appVersion: '${info.version}+${info.buildNumber}',
    );
  } catch (e) {
    debugPrint('[analytics] disabled for this launch: $e');
  }
}

/// Stable, unlocalized screen names, in tab order per mode. Only these fixed
/// strings are ever reported; the tab labels the user sees are localized and
/// would not group across languages.
const _kCodeTabs = ['dashboard', 'tasklist', 'reports', 'control', 'settings'];
const _kAssetTabs = ['generate', 'gallery', 'flow', 'queue', 'settings'];
const _kDeliveryTabs = ['delivery', 'buckets', 'settings'];

/// What the red banner at the top of the shell says: the server refusing this
/// app's API key is named as that, anything else is the server being
/// unreachable.
String offlineBannerText(AppLocalizations l10n, {required bool keyRefused}) =>
    keyRefused ? l10n.apiKeyRefusedBanner : l10n.serverUnreachable;

class AppManagerMobile extends StatelessWidget {
  const AppManagerMobile({super.key});

  @override
  Widget build(BuildContext context) {
    // Entering or leaving demo mode starts the app state over (a fresh
    // AppState, event stream and navigator), so no data crosses between the
    // demo and a real server.
    return ValueListenableBuilder<bool>(
      valueListenable: DemoMode.active,
      builder:
          (context, demo, _) =>
              KeyedSubtree(key: ValueKey('demo-$demo'), child: _app(demo)),
    );
  }

  Widget _app(bool demo) {
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
        listenable: Listenable.merge([
          ThemeService.instance,
          LocaleService.instance,
        ]),
        builder: (context, _) {
          return MaterialApp(
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            locale: LocaleService.instance.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home:
                !demo && AppConfig.baseUrl.isEmpty
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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  int _currentIndex = 0;
  DateTime? _lastBackPress;
  late final AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  AppState? _appStateRef;

  /// Uygulama modu. Code Mod = proje yonetimi, Asset Mod = yerel uretim,
  /// Delivery Mod (#363) = sunum kurallari. Settings her modda son sekmedir.
  String _mode = ModeService.code;
  bool get _assetMode => _mode == ModeService.asset;
  bool get _deliveryMode => _mode == ModeService.delivery;

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

  // #381: Dagitim NE sunulacagini secer, Kovalar kovada NE VAR sorusunun cevabi.
  static const _deliveryScreens = [
    DeliveryScreen(),
    BucketsScreen(),
    SettingsScreen(),
  ];

  List<Widget> get _screens =>
      _deliveryMode
          ? _deliveryScreens
          : (_assetMode ? _assetScreens : _codeScreens);

  /// ModeService degisince modu uygular. Sekme indeksi sifirlanir,
  /// yoksa yeni moddaki daha kisa listede tasar.
  List<String> get _tabNames =>
      _deliveryMode ? _kDeliveryTabs : (_assetMode ? _kAssetTabs : _kCodeTabs);

  /// Reports the tab that is on screen right now. Every tab of the mode is
  /// built inside the [IndexedStack] below, so "built" says nothing: this is
  /// called only for the one index the stack is showing.
  void _reportVisibleScreen() {
    final names = _tabNames;
    if (_currentIndex >= 0 && _currentIndex < names.length) {
      Usage.screen(names[_currentIndex]);
    }
  }

  void _onModeChanged() {
    HapticFeedback.mediumImpact();
    Analytics.log('feature_use', {'feature': 'mode_${ModeService.mode.value}'});
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _mode = ModeService.mode.value;
        _currentIndex = 0;
      });
      _reportVisibleScreen();
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
    ModeService.mode.addListener(_onModeChanged);
    UserSession.instance.user.addListener(_onUserChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appStateRef = context.read<AppState>();
      _appStateRef!.addListener(_onAppStateChanged);
      _appStateRef!.startHealthCheck();
      _reportVisibleScreen();
    });
    _checkForUpdate();
  }

  /// A member key has no Asset / Delivery tools: drop back to Code mode.
  void _onUserChanged() {
    if (UserSession.instance.isMember && !ModeService.isCode) {
      ModeService.setMode(ModeService.code);
    }
  }

  @override
  void dispose() {
    UserSession.instance.user.removeListener(_onUserChanged);
    ModeService.mode.removeListener(_onModeChanged);
    _appStateRef?.removeListener(_onAppStateChanged);
    _fadeController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = _appStateRef;
    if (appState != null &&
        appState.issuesRequestedAppId != null &&
        _currentIndex != 1) {
      _switchTab(1);
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    _fadeController.reverse().then((_) {
      setState(() => _currentIndex = index);
      _reportVisibleScreen();
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
      builder:
          (ctx) => AlertDialog(
            icon: Icon(Icons.system_update, size: 40, color: AppColors.info),
            title: Text(l10n.updateAvailable),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.versionWithNumber(
                    '${UpdateChecker.instance.latestVersion}',
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                    AppToast.of(context).show(result);
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.info),
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

    final demo = DemoMode.isActive;
    final showOffline = appState.showOfflineBanner && !demo;
    final keyRefused = appState.keyRefused;
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
        // Delivery -> Asset -> Code sirasiyla geri.
        if (_deliveryMode) {
          ModeService.setMode(ModeService.asset);
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
        AppToast.of(context).show(l10n.pressBackAgainToExit);
      },
      child: Scaffold(
        body: Column(
          children: [
            if (demo) DemoBanner(topInset: topInset),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: showOffline ? 32 + topInset : 0,
              padding: EdgeInsets.only(top: showOffline ? topInset : 0),
              curve: Curves.easeInOut,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(color: Colors.red.shade800),
              // A refused key is not an outage: the banner names it and a tap
              // opens Settings (always the last tab), where the key is set.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    keyRefused ? () => _switchTab(_screens.length - 1) : null,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        keyRefused ? Icons.key_off : Icons.cloud_off,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          offlineBannerText(l10n, keyRefused: keyRefused),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                    data:
                        showOffline || demo
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
          items:
              _deliveryMode
                  ? [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: l10n.navDelivery,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: l10n.navBuckets,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.settings),
                      label: l10n.settings,
                    ),
                  ]
                  : _assetMode
                  ? [
                    // #352: sira = Uretim | Uretilenler | Hat | Sira | Ayarlar
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.auto_awesome),
                      label: l10n.navGenerate,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.photo_library),
                      label: l10n.navGallery,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.conveyor_belt),
                      label: l10n.navFlow,
                    ),
                    BottomNavigationBarItem(
                      // #299: butun isler tek sunucu sirasina girer - rozet
                      // sirada kac is oldugunu gosterir (dinleyen varken 5 sn'de
                      // bir sorulur, Asset Mod disinda ag trafigi olmaz).
                      icon: ValueListenableBuilder<int>(
                        valueListenable: QueueService.depth,
                        builder:
                            (_, derinlik, child) => Badge(
                              isLabelVisible: derinlik > 0,
                              label: Text(
                                '$derinlik',
                                style: const TextStyle(fontSize: 10),
                              ),
                              child: child,
                            ),
                        child: const Icon(Icons.playlist_play),
                      ),
                      label: l10n.navQueue,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.settings),
                      label: l10n.settings,
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
                                  color:
                                      connected
                                          ? AppColors.success
                                          : AppColors.error,
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
                        label: Text(
                          '$pendingCount',
                          style: const TextStyle(fontSize: 10),
                        ),
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

/// Top strip while demo mode runs: says the data is sample data and offers
/// the way back to pairing. Takes the status-bar inset itself, like the
/// offline banner, so nothing is drawn under the status bar.
class DemoBanner extends StatelessWidget {
  final double topInset;
  const DemoBanner({super.key, required this.topInset});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('demo-banner'),
      color: AppColors.accent,
      padding: EdgeInsets.only(top: topInset, left: 12, right: 4),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.demoBanner,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: DemoMode.exit,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 44),
            ),
            child: Text(l10n.exitDemo),
          ),
        ],
      ),
    );
  }
}
