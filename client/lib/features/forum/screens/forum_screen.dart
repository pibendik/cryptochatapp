import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../auth/contacts_provider.dart';
import '../forum_provider.dart';

class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forum = ref.watch(forumNotifierProvider);
    final serverUrl = ref.watch(appConfigProvider).serverUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh posts',
            onPressed: () async {
              try {
                await forum.refreshFromServer(serverUrl);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ForumPostsTableData>>(
        stream: forum.watchPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () => forum.refreshFromServer(serverUrl),
            child: posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 400,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.help_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No help requests yet.\nBe the first to ask!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) =>
                        _PostCard(post: posts[index]),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostSheet(context, forum, serverUrl),
        icon: const Icon(Icons.add),
        label: const Text('Ask for help'),
      ),
    );
  }

  void _showCreatePostSheet(
    BuildContext context,
    ForumNotifier forum,
    String serverUrl,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePostSheet(forum: forum, serverUrl: serverUrl),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final ForumPostsTableData post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider).valueOrNull ?? [];
    final forum = ref.watch(forumNotifierProvider);
    final serverUrl = ref.watch(appConfigProvider).serverUrl;

    final matchingContacts = contacts.where((c) => c.id == post.authorId);
    final authorName = matchingContacts.isNotEmpty
        ? matchingContacts.first.displayName
        : post.authorId;

    // BLOCKED(phase-3): decrypt forum post body with group key
    const bodyText = '[encrypted body]';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(
          post.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _resolvedBadge(post.resolved),
              Text(authorName, style: const TextStyle(fontSize: 12)),
              Text(
                _formatRelativeTime(post.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(bodyText),
              // BLOCKED(phase-2): restrict resolve to author + group members once group membership API is complete
              if (!post.resolved)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      try {
                        await forum.resolvePost(serverUrl, post.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to resolve: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Mark resolved'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resolvedBadge(bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: resolved ? Colors.green[100] : Colors.amber[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        resolved ? '✓ Resolved' : 'Needs help',
        style: TextStyle(
          fontSize: 11,
          color: resolved ? Colors.green[800] : Colors.amber[800],
        ),
      ),
    );
  }
}

// ── Create post bottom sheet ───────────────────────────────────────────────────

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet({required this.forum, required this.serverUrl});

  final ForumNotifier forum;
  final String serverUrl;

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      // BLOCKED(phase-3): encrypt body before posting
      await widget.forum.createPost(
        widget.serverUrl,
        title,
        Uint8List.fromList(utf8.encode(_bodyController.text)),
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Help request posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleFilled = _titleController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask for help',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'Brief summary of what you need',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'Describe what you need help with...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: titleFilled && !_isPosting ? _submit : null,
            child: _isPosting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes == 1) return '1 min ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours == 1) return '1 hour ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${time.day}/${time.month}/${time.year}';
}

