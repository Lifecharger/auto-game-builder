import 'package:flutter/material.dart';
import '../theme.dart';
import 'reports_screen.dart';
import 'logs_screen.dart';

/// Bottom-nav destination hosting two tabs: in-game **Reports** (bug reports /
/// suggestions pulled from the game-reports worker) and build **Logs**.
class ChatLogsScreen extends StatelessWidget {
  const ChatLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Material(
              color: AppColors.bgCard,
              child: TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.feedback_outlined, size: 20), text: 'Reports'),
                  Tab(icon: Icon(Icons.article_outlined, size: 20), text: 'Logs'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ReportsScreen(),
                  LogsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
