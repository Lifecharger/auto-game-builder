import 'package:flutter/material.dart';
import '../theme.dart';
import 'reports_screen.dart';
import 'logs_screen.dart';

/// Bottom-nav destination hosting two tabs: in-game **Reports** (bug reports /
/// suggestions pulled from the game-reports worker) and build **Logs**.
///
/// The built-in [TabBarView] swipe is disabled: its gesture arena made sloppy
/// vertical scrolls (e.g. reaching the bottom of a list) flip to the other
/// tab. Instead, [_DeliberateSwipeDetector] requires a clear, mostly
/// horizontal swipe before switching pages.
class ChatLogsScreen extends StatefulWidget {
  const ChatLogsScreen({super.key});

  @override
  State<ChatLogsScreen> createState() => _ChatLogsScreenState();
}

class _ChatLogsScreenState extends State<ChatLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int delta) {
    if (!mounted) return;
    final target = _tabController.index + delta;
    if (target < 0 || target >= _tabController.length) return;
    _tabController.animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Material(
            color: AppColors.bgCard,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.feedback_outlined, size: 20), text: 'Reports'),
                Tab(icon: Icon(Icons.article_outlined, size: 20), text: 'Logs'),
              ],
            ),
          ),
          Expanded(
            child: _DeliberateSwipeDetector(
              onSwipeLeft: () => _switchTab(1),
              onSwipeRight: () => _switchTab(-1),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  ReportsScreen(),
                  LogsScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fires [onSwipeLeft] / [onSwipeRight] only for a deliberate horizontal
/// swipe: the pointer must travel at least [_minDistance] horizontally and
/// the horizontal travel must dominate the vertical travel by
/// [_horizontalDominance]×.
///
/// Uses a [Listener] rather than a [GestureDetector] so it never enters the
/// gesture arena — child lists keep full ownership of vertical scrolling.
class _DeliberateSwipeDetector extends StatefulWidget {
  const _DeliberateSwipeDetector({
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.child,
  });

  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final Widget child;

  @override
  State<_DeliberateSwipeDetector> createState() =>
      _DeliberateSwipeDetectorState();
}

class _DeliberateSwipeDetectorState extends State<_DeliberateSwipeDetector> {
  /// Minimum horizontal travel (logical px) for a swipe to count.
  static const double _minDistance = 96;

  /// Horizontal travel must exceed vertical travel by this factor.
  static const double _horizontalDominance = 2.5;

  int? _pointer;
  Offset? _start;

  void _onDown(PointerDownEvent e) {
    // Track only the first finger; ignore multi-touch.
    if (_pointer != null) return;
    _pointer = e.pointer;
    _start = e.position;
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final start = _start;
    _reset();
    if (start == null) return;
    final delta = e.position - start;
    final dx = delta.dx.abs();
    final dy = delta.dy.abs();
    if (dx < _minDistance || dx < dy * _horizontalDominance) return;
    if (delta.dx < 0) {
      widget.onSwipeLeft();
    } else {
      widget.onSwipeRight();
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _reset();
  }

  void _reset() {
    _pointer = null;
    _start = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
