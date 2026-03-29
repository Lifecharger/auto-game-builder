import 'package:flutter/material.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'logs_screen.dart';

class ChatLogsScreen extends StatelessWidget {
  const ChatLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.bgCard,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: 'Chat'),
                  Tab(icon: Icon(Icons.article_outlined, size: 20), text: 'Logs'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ChatScreen(),
                LogsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
