import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../auth/auth_provider.dart';
import '../../presence/presence_provider.dart';
import '../profile_provider.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _nameFilter = '';
  final Set<String> _selectedSkills = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfilesTableData> _applyFilters(
      List<UserProfilesTableData> members) {
    return members.where((m) {
      final nameLower = m.displayName.toLowerCase();
      final (bio: _, :skills) = decodeProfileData(m.skillsJson);
      final matchesName =
          _nameFilter.isEmpty || nameLower.contains(_nameFilter.toLowerCase());
      final matchesSkills = _selectedSkills.isEmpty ||
          _selectedSkills.every((s) => skills.contains(s));
      return matchesName && matchesSkills;
    }).toList();
  }

  Set<String> _allSkills(List<UserProfilesTableData> members) {
    final all = <String>{};
    for (final m in members) {
      all.addAll(decodeProfileData(m.skillsJson).skills);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final ownUserId = ref.watch(authProvider).userId ?? '';
    final membersAsync = ref.watch(watchGroupMembersProvider(ownUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_vote_outlined),
            tooltip: 'Proposals',
            onPressed: () => context.push('/proposals'),
          ),
          IconButton(
            icon: Icon(_searchActive ? Icons.search_off : Icons.search),
            tooltip: _searchActive ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) {
                _nameFilter = '';
                _selectedSkills.clear();
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          final allSkills = _allSkills(members);
          final filtered = _applyFilters(members);

          return Column(
            children: [
              if (_searchActive) _buildFilterBar(allSkills),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No group members found.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _MemberTile(member: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(Set<String> allSkills) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Filter by name…',
              prefixIcon: Icon(Icons.person_search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _nameFilter = v),
          ),
          if (allSkills.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...allSkills.map((skill) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(skill),
                          selected: _selectedSkills.contains(skill),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          }),
                        ),
                      )),
                  if (_selectedSkills.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedSkills.clear()),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final UserProfilesTableData member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceProvider);
    final status = presence[member.userId] ?? PresenceStatus.offline;
    final (:bio, :skills) = decodeProfileData(member.skillsJson);
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(child: Text(initial)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: skills.isEmpty
          ? null
          : Wrap(
              spacing: 4,
              children: [
                ...skills.take(3).map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )),
                if (skills.length > 3)
                  Chip(
                    label: Text('+${skills.length - 3}',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
      onTap: () => _showMemberSheet(context, ref, bio, skills),
    );
  }

  void _showMemberSheet(BuildContext context, WidgetRef ref, String bio,
      List<String> skills) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MemberSheet(
        member: member,
        bio: bio,
        skills: skills,
      ),
    );
  }
}

class _MemberSheet extends StatelessWidget {
  const _MemberSheet({
    required this.member,
    required this.bio,
    required this.skills,
  });

  final UserProfilesTableData member;
  final String bio;
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(child: CircleAvatar(radius: 36, child: Text(initial, style: const TextStyle(fontSize: 28)))),
          const SizedBox(height: 12),
          Center(
            child: Text(member.displayName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          // ── Bio ──
          if (bio.isNotEmpty) ...[
            const Text('Bio',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(bio),
            const SizedBox(height: 12),
          ],
          // ── Skills ──
          if (skills.isNotEmpty) ...[
            const Text('Skills',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  skills.map((s) => Chip(label: Text(s))).toList(),
            ),
            const SizedBox(height: 16),
          ],
          // BLOCKED(phase-2): show "✓ Key verified" if this user is in local contacts list
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/chat/${member.userId}');
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Send message'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/proposals/remove?label=${Uri.encodeComponent(member.displayName)}');
            },
            icon: Icon(Icons.person_remove,
                color: Theme.of(context).colorScheme.error),
            label: Text(
              'Propose remove',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
