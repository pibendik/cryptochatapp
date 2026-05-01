import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/hex_utils.dart';
import '../../auth/auth_provider.dart';
import '../profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  List<String> _editSkills = [];

  @override
  void dispose() {
    _bioController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _startEditing(String currentBio, List<String> currentSkills) {
    _bioController.text = currentBio;
    _editSkills = List<String>.from(currentSkills);
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _save(String serverUrl) async {
    await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile(serverUrl, _bioController.text, _editSkills);
    if (mounted) setState(() => _editing = false);
  }

  void _addSkill() {
    final s = _skillController.text.trim();
    if (s.isEmpty || _editSkills.length >= 10 || _editSkills.contains(s)) return;
    setState(() {
      _editSkills.add(s);
      _skillController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final authState = ref.watch(authProvider);
    // ServerUrl: read from app config provider.
    final serverUrl = ref.watch(appConfigProvider).serverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final profileData = profile as dynamic;
          final displayName = profileData?.displayName ??
              authState.userId?.substring(0, 8) ??
              'You';
          final (:bio, :skills) =
              decodeProfileData(profileData?.skillsJson ?? '[]');
          final publicKey = authState.publicKey;
          final fingerprint = publicKey != null && publicKey.isNotEmpty
              ? keyFingerprint(publicKey)
              : '—';

          if (_editing) {
            return _buildEditView(serverUrl, displayName, fingerprint);
          }
          return _buildViewMode(
              context, displayName, fingerprint, bio, skills, serverUrl);
        },
      ),
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    String displayName,
    String fingerprint,
    String bio,
    List<String> skills,
    String serverUrl,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(displayName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        // ── Fingerprint ──
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Identity fingerprint',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Share this with group members to verify your identity',
                      child: Icon(Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fingerprint,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy fingerprint',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fingerprint));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Fingerprint copied'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Bio ──
        const Text('Bio',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text(
          bio.isNotEmpty ? bio : 'No bio yet.',
          style: TextStyle(
              color: bio.isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : null),
        ),
        const SizedBox(height: 16),
        // ── Skills ──
        const Text('Skills',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        if (skills.isEmpty)
          Text('No skills listed yet.',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: skills
                .map((s) => FilterChip(
                      label: Text(s),
                      selected: false,
                      onSelected: (_) {},
                    ))
                .toList(),
          ),
        const SizedBox(height: 24),
        FilledButton.tonal(
          onPressed: () => _startEditing(bio, skills),
          child: const Text('Edit profile'),
        ),
      ],
    );
  }

  Widget _buildEditView(
      String serverUrl, String displayName, String fingerprint) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(displayName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        // ── Bio field ──
        TextField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Bio',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // ── Skills ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Skills',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text('${_editSkills.length}/10',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _editSkills
              .map((s) => InputChip(
                    label: Text(s),
                    onDeleted: () => setState(() => _editSkills.remove(s)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        if (_editSkills.length < 10)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skillController,
                  decoration: const InputDecoration(
                    hintText: 'New skill…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addSkill(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addSkill,
                child: const Text('Add'),
              ),
            ],
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _save(serverUrl),
                child: const Text('Save'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelEdit,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
