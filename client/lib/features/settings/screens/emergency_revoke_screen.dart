import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/hex_utils.dart';
import '../../auth/auth_provider.dart';
import '../../auth/contacts_provider.dart';

/// Emergency revocation screen — any authenticated member can report a
/// compromised key and initiate a group vote to remove it from the allowlist.
///
/// Scenario: "Someone stole my phone" — another member uses this screen to
/// create an emergency REMOVE proposal. Once 2 members approve, the
/// compromised key is locked out.
class EmergencyRevokeScreen extends ConsumerStatefulWidget {
  const EmergencyRevokeScreen({super.key});

  @override
  ConsumerState<EmergencyRevokeScreen> createState() =>
      _EmergencyRevokeScreenState();
}

class _EmergencyRevokeScreenState
    extends ConsumerState<EmergencyRevokeScreen> {
  final Map<String, _ProposalStatus> _proposalByKey = {};

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final serverUrl = ref.watch(appConfigProvider).serverUrl;
    final authState = ref.watch(authProvider);
    final myPublicKeyHex =
        authState.publicKey != null ? bytesToHex(authState.publicKey!) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Compromised Key')),
      body: Column(
        children: [
          // ── Info banner ──
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Report a stolen or compromised device. '
              'Two members must approve before the key is locked out. '
              'The affected member must attend a new key-signing ceremony with a fresh device.',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),

          // ── Members list ──
          Expanded(
            child: contactsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(
                    child: Text('No contacts found.\nAdd contacts first.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final keyHex = bytesToHex(contact.signingPublicKey);
                    final isMe = keyHex == myPublicKeyHex;
                    final status = _proposalByKey[keyHex];

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(contact.displayName),
                      subtitle: Text(
                        contact.fingerprint,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                      trailing: isMe
                          ? const Chip(label: Text('You'))
                          : status != null
                              ? _statusChip(context, status)
                              : TextButton.icon(
                                  icon:
                                      const Icon(Icons.report_problem_outlined),
                                  label: const Text('Report compromised'),
                                  style: TextButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.error),
                                  onPressed: () => _confirmRevoke(
                                      context, serverUrl, contact.displayName, keyHex),
                                ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, _ProposalStatus status) {
    switch (status) {
      case _ProposalStatus.loading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _ProposalStatus.submitted:
        return const Chip(
          label: Text('Pending'),
          avatar: Icon(Icons.hourglass_top, size: 14),
        );
      case _ProposalStatus.alreadyOpen:
        return const Chip(
          label: Text('Vote open'),
          avatar: Icon(Icons.how_to_vote, size: 14),
        );
      case _ProposalStatus.error:
        return const Chip(
          label: Text('Error'),
          avatar: Icon(Icons.error_outline, size: 14),
        );
    }
  }

  void _confirmRevoke(
    BuildContext context,
    String serverUrl,
    String displayName,
    String keyHex,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report compromised key?'),
        content: Text(
          'Are you sure? This will lock out $displayName until they attend '
          'a new key-signing ceremony with a fresh device.\n\n'
          'Two members must approve before the key is actually removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _submitRevoke(serverUrl, keyHex);
            },
            child: const Text('Yes, report'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRevoke(String serverUrl, String keyHex) async {
    final sessionToken = ref.read(authProvider).sessionToken;
    if (sessionToken == null) return;

    setState(() => _proposalByKey[keyHex] = _ProposalStatus.loading);

    try {
      final res = await http.post(
        Uri.parse('$serverUrl/keys/emergency-revoke'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({'target_key_hex': keyHex}),
      );

      if (res.statusCode == 201) {
        setState(() => _proposalByKey[keyHex] = _ProposalStatus.submitted);
      } else if (res.statusCode == 200) {
        // An open proposal already existed — surface that.
        setState(
            () => _proposalByKey[keyHex] = _ProposalStatus.alreadyOpen);
      } else {
        setState(() => _proposalByKey[keyHex] = _ProposalStatus.error);
      }
    } catch (_) {
      setState(() => _proposalByKey[keyHex] = _ProposalStatus.error);
    }
  }
}

enum _ProposalStatus { loading, submitted, alreadyOpen, error }
