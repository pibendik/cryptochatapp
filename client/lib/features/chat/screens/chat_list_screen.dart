import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/widgets/connection_banner.dart';
import '../../../core/widgets/presence_dot.dart';
import '../../auth/contacts_provider.dart';
import '../../ephemeral/ephemeral_provider.dart';
import '../../ephemeral/ephemeral_session.dart';
import '../chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>?
      _activeBanner;

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    // Show a dismissable banner whenever a new RAISED session appears.
    ref.listen<List<EphemeralSession>>(ephemeralProvider, (prev, next) {
      final prevIds = prev?.map((s) => s.id).toSet() ?? {};
      for (final session in next) {
        if (session.state == EphemeralSessionState.raised &&
            !prevIds.contains(session.id)) {
          _activeBanner?.close();
          _activeBanner = ScaffoldMessenger.of(context).showMaterialBanner(
            MaterialBanner(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              content: Text(
                '👋 Someone needs help — tap Join to assist.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              leading: const Icon(Icons.front_hand_outlined),
              actions: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                    _joinAndNavigate(session.id);
                  },
                  child: const Text('Join'),
                ),
                TextButton(
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Help board',
            onPressed: () => context.go('/forum'),
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Group members',
            onPressed: () => context.go('/members'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (contacts) {
                // Permanent group chat + one entry per saved contact.
                final items = <_ConversationEntry>[
                  const _ConversationEntry(
                    conversationId: 'group',
                    displayName: 'Group Chat',
                    isGroup: true,
                  ),
                  ...contacts.map(
                    (c) => _ConversationEntry(
                      conversationId: c.id,
                      displayName: c.displayName,
                    ),
                  ),
                ];

                if (contacts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No conversations yet.\nTap + to start one.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ConversationTile(entry: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Raise a help flag',
        onPressed: _raiseFlag,
        child: const Icon(Icons.front_hand_outlined),
      ),
    );
  }

  Future<void> _raiseFlag() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise a help flag?'),
        content: const Text(
          'Everyone in your group will be notified and can join a temporary chat session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Raise flag'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final session =
          await ref.read(ephemeralProvider.notifier).raiseFlag();
      if (mounted) context.go('/ephemeral/${session.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to raise flag: $e')),
        );
      }
    }
  }

  Future<void> _joinAndNavigate(String sessionId) async {
    try {
      await ref.read(ephemeralProvider.notifier).joinSession(sessionId);
      if (mounted) context.go('/ephemeral/$sessionId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join session: $e')),
        );
      }
    }
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

class _ConversationEntry {
  const _ConversationEntry({
    required this.conversationId,
    required this.displayName,
    this.isGroup = false,
  });

  final String conversationId;
  final String displayName;
  final bool isGroup;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// Returns a display-safe preview string for a message body.
///
/// Returns `🔒 Encrypted message` when [plaintextCache] is null (not yet
/// decrypted) or starts with the `[encrypted]` sentinel.  Long messages are
/// capped at 50 characters.
String _previewBody(Uint8List? plaintextCache) {
  if (plaintextCache == null || plaintextCache.isEmpty) {
    return '🔒 Encrypted message';
  }
  final text = utf8.decode(plaintextCache, allowMalformed: true);
  if (text.startsWith('[encrypted]')) return '🔒 Encrypted message';
  return text.length > 50 ? '${text.substring(0, 50)}...' : text;
}

// ── Conversation tile ──────────────────────────────────────────────────────

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.entry});

  final _ConversationEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial =
        entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?';

    final lastMsgAsync = ref.watch(lastMessageProvider(entry.conversationId));

    final subtitle = lastMsgAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const Text('No messages yet'),
      data: (MessagesTableData? msg) {
        if (msg == null) {
          return Text(
            'No messages yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          );
        }
        final preview = _previewBody(msg.plaintextCache);
        final timestamp = _formatTimestamp(msg.createdAt);
        return Row(
          children: [
            Expanded(
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ],
        );
      },
    );

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            child: entry.isGroup
                ? const Icon(Icons.group)
                : Text(initial),
          ),
          if (!entry.isGroup)
            Positioned(
              right: -2,
              bottom: -2,
              child: PresenceDot(userId: entry.conversationId, size: 10),
            ),
        ],
      ),
      title: Text(entry.displayName),
      subtitle: subtitle,
      onTap: () => context.go('/chat/${entry.conversationId}'),
    );
  }
}
