import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/hex_utils.dart';
import '../../auth/auth_provider.dart';

/// Key rotation screen — lets the current device holder propose a key swap.
///
/// Scenario: user has a new phone or reinstalled the app.
/// 1. Generate a fresh Ed25519 + X25519 keypair on the new device.
/// 2. Submit a ROTATE proposal via POST /keys/rotate.
/// 3. Wait for 2 peer approvals.
/// 4. On approval: clear local state, log out, restart onboarding with the
///    new keypair already pre-loaded in secure storage.
class KeyRotationScreen extends ConsumerStatefulWidget {
  const KeyRotationScreen({super.key});

  @override
  ConsumerState<KeyRotationScreen> createState() => _KeyRotationScreenState();
}

class _KeyRotationScreenState extends ConsumerState<KeyRotationScreen> {
  bool _isLoading = false;
  String? _proposalId;
  String? _error;

  String? _newKeyHex;
  final _labelController = TextEditingController(text: 'My new device');

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _generateAndSubmit() async {
    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);
    final serverUrl = ref.read(appConfigProvider).serverUrl;
    final sessionToken = authState.sessionToken;

    if (sessionToken == null) {
      setState(() => _error = 'Not authenticated — please log in first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _proposalId = null;
    });

    try {
      // Generate a fresh keypair on the new device.
      final crypto = ref.read(cryptoServiceProvider);
      final newSigningKp = await crypto.generateKeypair();
      final newEncKp = await crypto.generateEncryptionKeypair();
      final newPubHex = bytesToHex(newSigningKp.publicKey);

      // Persist the new keypair in secure storage (replaces the old one).
      final storage = ref.read(secureStorageProvider);
      await storage.saveSecretKey(newSigningKp.secretKey);
      await storage.savePublicKey(newSigningKp.publicKey);
      await storage.storeEncryptionPrivateKey(newEncKp.privateKey);
      await storage.storeEncryptionPublicKey(newEncKp.publicKey);

      // Submit the rotation proposal using the CURRENT session token (signed
      // with the old key). After this, the server holds both keys; the old key
      // remains active until 2 peers approve the swap.
      final res = await http.post(
        Uri.parse('$serverUrl/keys/rotate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({
          'new_public_key_hex': newPubHex,
          'new_label': _labelController.text.trim().isEmpty
              ? null
              : _labelController.text.trim(),
        }),
      );

      if (res.statusCode != 201) {
        throw Exception(
            'Server returned ${res.statusCode}: ${res.body}');
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _proposalId = json['proposal_id'] as String?;
        _newKeyHex = newPubHex;
        _isLoading = false;
      });

      // Update in-memory auth state with the new keypair.
      // The session token stays the same until the rotation is approved and
      // the user re-authenticates.
      authNotifier.updateKeypairAfterRotation(
        newPublicKey: newSigningKp.publicKey,
        newSecretKey: newSigningKp.secretKey,
        newEncPublicKey: newEncKp.publicKey,
        newEncPrivateKey: newEncKp.privateKey,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _clearAndLogout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.deleteAll();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final fingerprint = authState.publicKey != null
        ? keyFingerprint(authState.publicKey!)
        : '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Rotate My Key')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Warning banner ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ Rotating your key will temporarily disconnect you. '
                    'All group members will be notified. '
                    'You will need to re-authenticate after 2 peers approve the change.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Current fingerprint ──
          Card(
            child: ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Current key fingerprint'),
              subtitle: Text(
                fingerprint,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_proposalId == null) ...[
            // ── Label field ──
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'New device label (optional)',
                hintText: 'e.g. My new phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Rotate button ──
            FilledButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rotate_right),
              label: const Text('Rotate my key'),
              onPressed: _isLoading ? null : _generateAndSubmit,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ] else ...[
            // ── Waiting for approvals ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Waiting for 2 approvals from group members.',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Proposal ID: ${_proposalId!}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    if (_newKeyHex != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          'New key fingerprint: ${keyFingerprint(hexToBytes(_newKeyHex!))}',
                          style: const TextStyle(fontFamily: 'monospace')),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Share your new fingerprint with your group members so they can verify and approve the rotation.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Clear local data and return to onboarding ──
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Clear local data & re-authenticate'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear local data?'),
                  content: const Text(
                    'This will delete all local messages and keys. '
                    'You will be taken to the onboarding screen. '
                    'Your new keypair is already saved in secure storage.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearAndLogout();
                      },
                      child: const Text('Clear & continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
