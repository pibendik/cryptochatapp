import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../auth/auth_provider.dart';
import '../../chat/chat_provider.dart';
import '../ephemeral_provider.dart';
import '../ephemeral_session.dart';

/// Full-screen ephemeral help-request chat.
///
/// Shows a participant list and an "End session" button. Navigates back
/// automatically when the server sends an `ephemeral_deleted` event.
class EphemeralChatScreen extends ConsumerStatefulWidget {
  const EphemeralChatScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<EphemeralChatScreen> createState() =>
      _EphemeralChatScreenState();
}

class _EphemeralChatScreenState extends ConsumerState<EphemeralChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  late final Stream<List<MessagesTableData>> _messageStream;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _messageStream = ref.read(chatProvider).watchMessages(widget.sessionId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(chatMessagesProvider(widget.sessionId).notifier)
        .sendMessage(widget.sessionId, text);
    _textController.clear();
  }

  Future<void> _confirmEndSession(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End help session?'),
        content: const Text(
          'This will close the session and permanently delete all messages for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _closing = true);
    try {
      await ref.read(ephemeralProvider.notifier).closeSession(sessionId);
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        setState(() => _closing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the session disappears from state (server deleted it), navigate back.
    ref.listen<List<EphemeralSession>>(ephemeralProvider, (prev, next) {
      final wasPresent = prev?.any((s) => s.id == widget.sessionId) ?? false;
      final isPresent = next.any((s) => s.id == widget.sessionId);
      if (wasPresent && !isPresent && mounted && !_closing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session ended by another participant.')),
        );
        context.go('/');
      }
    });

    final sessions = ref.watch(ephemeralProvider);
    final session =
        sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final ownUserId =
        ref.watch(authProvider.select((s) => s.userId)) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('👋 Help Session'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        actions: [
          TextButton.icon(
            onPressed: _closing
                ? null
                : () => _confirmEndSession(context, ref, widget.sessionId),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End session'),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Participant chip strip ──────────────────────────────────────
          if (session != null && session.participants.isNotEmpty)
            Container(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withOpacity(0.3),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.group, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: session.participants
                            .map(
                              (uid) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Chip(
                                  label: Text(
                                    uid == ownUserId
                                        ? 'You'
                                        : uid.length > 8
                                            ? uid.substring(0, 8)
                                            : uid,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Message list ───────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<MessagesTableData>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nSay hello! 👋',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  },
                );
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isOwn = msg.senderId == ownUserId;
                    final text = msg.plaintextCache != null
                        ? String.fromCharCodes(msg.plaintextCache!)
                        : '🔒 Encrypted';
                    return Align(
                      alignment: isOwn
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isOwn
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isOwn
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
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
