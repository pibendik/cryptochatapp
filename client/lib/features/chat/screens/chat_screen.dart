import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/widgets/presence_dot.dart';
import '../../auth/auth_provider.dart';
import '../../auth/contacts_provider.dart';
import '../chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  late final Stream<List<MessagesTableData>> _messageStream;

  @override
  void initState() {
    super.initState();
    _messageStream =
        ref.read(chatProvider).watchMessages(widget.conversationId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    // BLOCKED(phase-3): encrypt with recipient's X25519 key before sending
    final bytes = Uint8List.fromList(text.codeUnits);
    await ref.read(chatProvider).sendMessage(widget.conversationId, bytes);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ownUserId = ref.watch(authProvider.select((s) => s.userId));
    final contacts = ref.watch(contactsProvider).valueOrNull ?? [];
    final contact =
        contacts.where((c) => c.id == widget.conversationId).firstOrNull;
    final displayName = contact?.displayName ?? widget.conversationId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(displayName)),
            const SizedBox(width: 8),
            PresenceDot(userId: widget.conversationId, size: 10),
            // BLOCKED(phase-2): show "verified ✓" badge if contact is key-signed
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessagesTableData>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isNotEmpty) _scrollToBottom();

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _MessageBubble(
                      message: msg,
                      isOwn: msg.senderId == ownUserId,
                    );
                  },
                );
              },
            ),
          ),
          _ComposeBar(
            controller: _textController,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOwn});

  final MessagesTableData message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor =
        isOwn ? cs.primaryContainer : cs.secondaryContainer;
    final textColor =
        isOwn ? cs.onPrimaryContainer : cs.onSecondaryContainer;

    // Show cached plaintext when available; otherwise encrypted placeholder.
    // BLOCKED(phase-3): wire DartCryptographyService.decrypt() here
    final displayText = message.plaintextCache != null
        ? String.fromCharCodes(message.plaintextCache!)
        : '[encrypted]';

    final t = message.createdAt.toLocal();
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isOwn ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isOwn ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText, style: TextStyle(color: textColor)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                if (!message.isDelivered) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.access_time,
                      size: 12, color: textColor.withOpacity(0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compose bar ────────────────────────────────────────────────────────────

class _ComposeBar extends StatefulWidget {
  const _ComposeBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  State<_ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<_ComposeBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: const InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => widget.onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _hasText ? widget.onSend : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
