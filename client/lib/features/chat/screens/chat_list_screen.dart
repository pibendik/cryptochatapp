import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/connection_banner.dart';
import '../../../core/widgets/presence_dot.dart';
import '../../auth/contacts_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

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
        tooltip: 'New message',
        onPressed: () {
          // BLOCKED(phase-3): ephemeral help-request chat creation
        },
        child: const Icon(Icons.add),
      ),
    );
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

// ── Conversation tile ──────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.entry});

  final _ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?';

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
      subtitle: const Text('Tap to open chat'),
      onTap: () => context.go('/chat/${entry.conversationId}'),
    );
  }
}
