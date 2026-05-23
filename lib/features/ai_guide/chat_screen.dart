import 'package:flutter/material.dart';

import '../../services/gemini_service.dart';

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.fromUser,
    required this.timestamp,
  });

  final String text;
  final bool fromUser;
  final DateTime timestamp;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.guideId});

  final String guideId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];

  GuideChatSession? _session;
  GuideProfile? _guide;
  bool _loading = true;
  bool _sending = false;
  bool _apiAvailable = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final kb = await GeminiService.loadKnowledgeBase();
    final guide = kb.guides[widget.guideId];
    final session = await GeminiService.startChat(widget.guideId);
    if (!mounted) return;
    setState(() {
      _guide = guide;
      _session = session;
      _apiAvailable = session != null;
      _loading = false;
      if (guide != null) {
        _messages.add(
          _ChatMessage(
            text: guide.greeting,
            fromUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
      if (!_apiAvailable) {
        _messages.add(
          _ChatMessage(
            text: GeminiService.unavailableMessage,
            fromUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final session = _session;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          fromUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _input.clear();
      _sending = true;
    });
    _scrollToBottom();

    if (session == null) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: GeminiService.unavailableMessage,
            fromUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
      return;
    }

    final reply = await session.send(text);
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: reply,
          fromUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _sending = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = _guide;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                widget.guideId == 'apashka'
                    ? Icons.elderly_woman
                    : Icons.elderly,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                guide?.name ?? widget.guideId,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_apiAvailable)
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.errorContainer,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      GeminiService.unavailableMessage,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return _Bubble(message: m, guideId: widget.guideId);
                    },
                  ),
                ),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Гид думает...'),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText:
                                  'Спросите про правила, маршрут или историю...',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.guideId});

  final _ChatMessage message;
  final String guideId;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final theme = Theme.of(context);
    final bg = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                guideId == 'apashka' ? Icons.elderly_woman : Icons.elderly,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(color: fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
