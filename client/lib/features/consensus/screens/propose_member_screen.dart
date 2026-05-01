import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/hex_utils.dart';
import '../../auth/auth_provider.dart';
import '../../auth/contacts_provider.dart';
import '../consensus_provider.dart';

/// Screen for proposing a new member add (enter public key hex + label)
/// or proposing removal of an existing member (pick from the contacts list).
///
/// The route receives [action] = 'ADD' | 'REMOVE'.
class ProposeMemberScreen extends ConsumerStatefulWidget {
  const ProposeMemberScreen({super.key, required this.action});

  /// 'ADD' to propose adding a new member, 'REMOVE' to propose removing one.
  final String action;

  @override
  ConsumerState<ProposeMemberScreen> createState() =>
      _ProposeMemberScreenState();
}

class _ProposeMemberScreenState extends ConsumerState<ProposeMemberScreen> {
  final _keyController = TextEditingController();
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _selectedMemberKey;
  String? _selectedMemberLabel;

  bool get isAdd => widget.action == 'ADD';

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isAdd && !(_formKey.currentState?.validate() ?? false)) return;
    if (!isAdd && _selectedMemberKey == null) {
      _showError('Please select a member to remove.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (isAdd) {
        await ref.read(consensusProvider.notifier).proposeMemberAdd(
              _keyController.text.trim(),
              _labelController.text.trim(),
            );
      } else {
        await ref.read(consensusProvider.notifier).proposeMemberRemove(
              _selectedMemberKey!,
              label: _selectedMemberLabel,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Proposal submitted — waiting for a second approval.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Failed to submit proposal: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdd ? 'Propose Add Member' : 'Propose Remove Member'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: isAdd ? _buildAddForm() : _buildRemoveForm(),
      ),
    );
  }

  Widget _buildAddForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the public key of the person you want to add. '
            'A second member must also approve before they are added to the group.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'Public Key (hex)',
              hintText: 'e.g. a1b2c3d4…',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            autocorrect: false,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 16) return 'Key too short';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. Alice',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Proposal'),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveForm() {
    final contactsAsync = ref.watch(contactsProvider);
    // Exclude own key from the removable list.
    final ownKey = ref.watch(authProvider).publicKey;
    final ownKeyHex = ownKey != null ? bytesToHex(ownKey) : '';

    return contactsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading contacts: $e')),
      data: (contacts) {
        final removable =
            contacts.where((c) => c.id != ownKeyHex).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select the member you want to remove. '
              'A second member must also approve before they are removed.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (removable.isEmpty)
              const Text('No contacts found to remove.')
            else
              ...removable.map((c) {
                final keyHex = c.id; // contact id IS the signing key hex
                final isSelected = _selectedMemberKey == keyHex;
                return RadioListTile<String>(
                  value: keyHex,
                  groupValue: _selectedMemberKey,
                  title: Text(c.displayName),
                  subtitle: Text(
                    '${keyHex.substring(0, 16)}…',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                  onChanged: (v) => setState(() {
                    _selectedMemberKey = v;
                    _selectedMemberLabel = c.displayName;
                  }),
                  selected: isSelected,
                );
              }),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Removal Proposal'),
            ),
          ],
        );
      },
    );
  }
}
