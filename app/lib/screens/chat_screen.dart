import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _sessionsKey = 'chat_sessions';
  static const _activeKey = 'chat_active_session';
  static const _legacyKey = 'chat_history';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<_ChatSession> _sessions = [];
  String? _activeId;
  int? _selectedAppId;
  String _selectedAgent = 'claude';
  bool _sending = false;

  _ChatSession? get _active {
    if (_activeId == null) return null;
    for (final s in _sessions) {
      if (s.id == _activeId) return s;
    }
    return null;
  }

  List<_ChatMessage> get _messages => _active?.messages ?? [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy single-chat history
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      final list = jsonDecode(legacy) as List;
      if (list.isNotEmpty) {
        final s = _ChatSession(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          title: 'Previous Chat',
          createdAt: DateTime.now(),
          messages: list
              .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
        _sessions.add(s);
        _activeId = s.id;
      }
      await prefs.remove(_legacyKey);
    }

    // Load sessions
    final json = prefs.getString(_sessionsKey);
    if (json != null) {
      final decoded = jsonDecode(json) as List;
      _sessions =
          decoded.map((e) => _ChatSession.fromJson(e as Map<String, dynamic>)).toList();
      _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Restore active session
    _activeId = prefs.getString(_activeKey);
    if (_active == null && _sessions.isNotEmpty) {
      _activeId = _sessions.first.id;
    }

    if (legacy != null && _sessions.isNotEmpty) {
      await _save();
    }

    setState(() {});
    _scrollToBottom();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
    if (_activeId != null) {
      await prefs.setString(_activeKey, _activeId!);
    } else {
      await prefs.remove(_activeKey);
    }
  }

  void _newChat() {
    final s = _ChatSession(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Chat',
      createdAt: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, s);
      _activeId = s.id;
    });
    _save();
  }

  void _switchTo(String id) {
    setState(() => _activeId = id);
    _save();
    Navigator.pop(context);
    _scrollToBottom();
  }

  void _deleteSession(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Delete this conversation?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _sessions.removeWhere((s) => s.id == id);
                if (_activeId == id) {
                  _activeId =
                      _sessions.isNotEmpty ? _sessions.first.id : null;
                }
              });
              _save();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending) return;
    HapticFeedback.lightImpact();

    if (_active == null) _newChat();
    final session = _active!;

    setState(() {
      session.messages.add(_ChatMessage(text: question, isUser: true));
      if (session.title == 'New Chat') {
        session.title = question.length > 30
            ? '${question.substring(0, 30)}...'
            : question;
      }
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    // After 20 messages, reset CLI session but send last 10 as compacted context
    final needsReset = session.messages.length > 20;
    final sessionId = needsReset ? null : session.agentSessionId;

    List<Map<String, String>>? history;
    if (needsReset) {
      final recent = session.messages
          .where((m) => !m.isError && !m.isSystem)
          .toList();
      final last10 = recent.length > 10 ? recent.sublist(recent.length - 10) : recent;
      history = last10
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      setState(() {
        session.messages.add(_ChatMessage(
          text: 'Session refreshed \u2014 recent context preserved',
          isUser: false,
          isSystem: true,
        ));
      });
      _scrollToBottom();
    }

    // Build app context so the agent has info without needing shell access
    String? appContext;
    if (_selectedAppId != null) {
      final apps = context.read<AppState>().apps;
      final app = apps.where((a) => a.id == _selectedAppId).firstOrNull;
      if (app != null) {
        appContext = 'App: ${app.name} (${app.appType}), v${app.currentVersion}, status: ${app.status}, path: ${app.projectPath}';
      }
    }

    final result = await ApiService.askAgent(
      question: question,
      appId: _selectedAppId,
      agent: _selectedAgent,
      sessionId: sessionId,
      history: history,
      appContext: appContext,
    );

    if (mounted) {
      if (result.ok) HapticFeedback.lightImpact();
      setState(() {
        if (result.ok) {
          final data = result.data!;
          session.messages.add(_ChatMessage(
            text: data['response'] ?? '',
            isUser: false,
          ));
          // Store session ID for future --resume (resets after 20 messages)
          if (data['session_id'] != null) {
            session.agentSessionId = data['session_id'] as String;
          } else if (sessionId == null) {
            // Context was reset, clear old session ID
            session.agentSessionId = null;
          }
        } else {
          session.messages.add(_ChatMessage(
            text: result.error!,
            isUser: false,
            isError: true,
          ));
        }
        _sending = false;
      });
      _save();
      _scrollToBottom();
    }
  }

  void _retry(int errorIndex) {
    if (_sending) return;
    HapticFeedback.lightImpact();
    final session = _active;
    if (session == null) return;

    // Find the user message right before this error
    String? question;
    for (int i = errorIndex - 1; i >= 0; i--) {
      if (session.messages[i].isUser) {
        question = session.messages[i].text;
        break;
      }
    }
    if (question == null) return;

    // Remove the error message
    setState(() {
      session.messages.removeAt(errorIndex);
    });
    _save();

    // Resend by putting the question in the controller and calling _send
    _controller.text = question;
    _send();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppState>().apps;
    final mq = MediaQuery.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Chat History',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _active?.title ?? 'Ask Agent',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _newChat,
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear Messages',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Messages'),
                    content:
                        Text('Delete all ${_messages.length} messages in this chat?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _active?.messages.clear());
                          _save();
                        },
                        child: const Text('Clear',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.bgDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Text('Chat History',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 22),
                      tooltip: 'New Chat',
                      onPressed: () {
                        Navigator.pop(context);
                        _newChat();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade600),
                            const SizedBox(height: 12),
                            const Text('No chats yet',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Tap + to start a conversation',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _newChat();
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Chat'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, i) {
                          final s = _sessions[i];
                          final isActive = s.id == _activeId;
                          return ListTile(
                            dense: true,
                            selected: isActive,
                            selectedTileColor:
                                AppColors.accent.withValues(alpha: 0.1),
                            leading: Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: isActive
                                  ? AppColors.accent
                                  : Colors.grey,
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${s.messages.length} messages \u2022 ${_formatDate(s.createdAt)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close,
                                  size: 16,
                                  color: Colors.grey.shade600),
                              onPressed: () => _deleteSession(s.id),
                            ),
                            onTap: () => _switchTo(s.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Agent + App selector
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.bgSidebar,
            child: Row(
              children: [
                ...['claude', 'gemini', 'codex', 'local'].map((agent) {
                  final selected = agent == _selectedAgent;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                          agent[0].toUpperCase() + agent.substring(1),
                          style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      selectedColor: AppColors.agentColor(agent),
                      visualDensity: VisualDensity.compact,
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedAgent = agent);
                      },
                    ),
                  );
                }),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    value: _selectedAppId,
                    decoration: const InputDecoration(
                      hintText: 'All apps',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: AppColors.bgCard,
                    style: const TextStyle(fontSize: 12),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('All Apps')),
                      ...apps.map((app) => DropdownMenuItem(
                            value: app.id,
                            child: Text(app.name,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedAppId = val),
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Icon(Icons.chat_bubble_outline,
                          size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Ask anything about your apps',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Select an app for context, or ask general questions',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Agent runs on the server with project-level access',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 11),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _sending) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Thinking...',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      final msg = _messages[index];
                      return _MessageBubble(
                        message: msg,
                        onRetry: msg.isError ? () => _retry(index) : null,
                      );
                    },
                  ),
            ),
          ),
          // Input
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: mq.viewInsets.bottom + mq.padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgSidebar,
              border:
                  Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<_ChatMessage> messages;
  String? agentSessionId; // Claude CLI session ID for --resume

  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    List<_ChatMessage>? messages,
    this.agentSessionId,
  }) : messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (agentSessionId != null) 'agentSessionId': agentSessionId,
      };

  factory _ChatSession.fromJson(Map<String, dynamic> json) => _ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        messages: (json['messages'] as List)
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        agentSessionId: json['agentSessionId'] as String?,
      );
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isSystem;
  _ChatMessage(
      {required this.text, required this.isUser, this.isError = false, this.isSystem = false});

  Map<String, dynamic> toJson() =>
      {'text': text, 'isUser': isUser, 'isError': isError, 'isSystem': isSystem};

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        isError: json['isError'] as bool? ?? false,
        isSystem: json['isSystem'] as bool? ?? false,
      );
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;
  const _MessageBubble({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade300),
              const SizedBox(width: 6),
              Text(
                message.text,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade300, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.isUser;
    final textColor = message.isError ? AppColors.error : Colors.grey.shade200;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.accent.withValues(alpha: 0.2)
              : message.isError
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: message.isError
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3))
              : null,
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textColor,
                ),
              )
            : message.isError && onRetry != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        message.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onRetry,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 16, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 14, height: 1.4, color: textColor),
                      h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      code: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Colors.amber.shade200,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: TextStyle(fontSize: 14, color: textColor),
                      strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                      em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.accent.withValues(alpha: 0.5), width: 3),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                      a: TextStyle(color: AppColors.accent, decoration: TextDecoration.underline),
                    ),
                    builders: {
                      'code': _CodeBlockBuilder(),
                    },
                  ),
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Only handle fenced code blocks (pre > code), not inline code
    if (element.tag != 'code') return const SizedBox.shrink();
    final parent = element.attributes['class'];
    // Inline code is handled by the default styleSheet.code
    if (parent == null && !element.textContent.contains('\n')) {
      return Text.rich(
        TextSpan(
          text: element.textContent,
          style: preferredStyle,
        ),
      );
    }

    final language = parent?.replaceFirst('language-', '') ?? '';
    final code = element.textContent.trimRight();

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              code,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.green.shade200,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (language.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    language,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
