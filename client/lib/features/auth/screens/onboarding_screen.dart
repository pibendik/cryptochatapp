import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/contact.dart';
import '../../../core/utils/hex_utils.dart';
import '../auth_provider.dart';
import '../contacts_provider.dart';

/// 3-step key-signing ceremony:
///   1. Generate Ed25519 + X25519 keypairs; enter display name.
///   2. Show your QR code so others can scan it.
///   3. Scan every other participant's QR code to add them as contacts.
///
// BLOCKED(ceremony): key-signing ceremony must be completed in person before any encrypted communication is possible
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final _displayNameController = TextEditingController();
  final List<Contact> _scannedContacts = [];
  MobileScannerController? _scannerController;

  bool _isProcessingScan = false;

  /// Debounce: ignore re-scans of the same key within 2 s.
  String? _lastScannedKey;

  @override
  void initState() {
    super.initState();
    _prefillDisplayName();
  }

  Future<void> _prefillDisplayName() async {
    final name = await ref.read(secureStorageProvider).readDisplayName();
    if (name != null && mounted) {
      _displayNameController.text = name;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── Step transitions ──────────────────────────────────────────────────────

  void _goToStep(int step) {
    if (step == 2) {
      // Lazily create the scanner controller when entering the scan step.
      _scannerController ??= MobileScannerController();
    } else if (_step == 2) {
      _scannerController?.stop();
    }
    setState(() => _step = step);
  }

  // ── Step 1 helpers ────────────────────────────────────────────────────────

  Future<void> _onGenerate() async {
    await ref.read(authProvider.notifier).generateAndStoreKeypair();
  }

  Future<void> _onNextFromStep1() async {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(secureStorageProvider).saveDisplayName(name);
    _goToStep(1);
  }

  // ── Step 3 helpers ────────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    _isProcessingScan = true;
    try {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw == null) continue;

        Map<String, dynamic> payload;
        try {
          payload = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          _showSnackBar('Invalid QR code — not a cryptochatapp key');
          return;
        }

        if (payload['v'] != 1 ||
            payload['signing_key'] is! String ||
            payload['encryption_key'] is! String ||
            payload['display_name'] is! String) {
          _showSnackBar('Invalid QR code — not a cryptochatapp key');
          return;
        }

        final signingKey = payload['signing_key'] as String;

        // Ignore self.
        final ownKey = ref.read(authProvider).publicKey;
        if (ownKey != null && signingKey == bytesToHex(ownKey)) {
          _showSnackBar('That\'s your own QR code!');
          return;
        }

        // Debounce repeated reads of the same QR.
        if (signingKey == _lastScannedKey) return;
        _lastScannedKey = signingKey;
        Future.delayed(const Duration(seconds: 2), () => _lastScannedKey = null);

        Contact contact;
        try {
          contact = Contact.fromQrPayload(payload);
        } catch (_) {
          _showSnackBar('Invalid QR code — not a cryptochatapp key');
          return;
        }

        try {
          await ref.read(contactsProvider.notifier).addContact(contact);
          if (mounted) setState(() => _scannedContacts.add(contact));
          _showSnackBar('Added ${contact.displayName} ✓');
        } on DuplicateContactException catch (e) {
          _showSnackBar('Already have ${e.displayName} in your contacts');
        }
      }
    } finally {
      // Reset after 2 seconds to allow rescanning different codes
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Utilities ─────────────────────────────────────────────────────────────
  // Hex/fingerprint utilities are imported from core/utils/hex_utils.dart

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Key-Signing Ceremony'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goToStep(_step - 1),
              )
            : null,
      ),
      body: SafeArea(
        child: authState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildStep(context, authState),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AuthState auth) {
    switch (_step) {
      case 0:
        return _buildStep1(context, auth);
      case 1:
        return _buildStep2(context, auth);
      case 2:
        return _buildStep3(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Generate keypair + display name ───────────────────────────────

  Widget _buildStep1(BuildContext context, AuthState auth) {
    final hasKeys = auth.publicKey != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIndicator(current: 0),
          const SizedBox(height: 32),
          if (!hasKeys) ...[
            const Icon(Icons.lock_outline, size: 72),
            const SizedBox(height: 24),
            Text(
              'No password. No server knows who you are.\n'
              'Your identity is a cryptographic keypair stored only on this device.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Error: ${auth.error}',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _onGenerate,
              icon: const Icon(Icons.vpn_key),
              label: const Text('Generate my identity keys'),
            ),
          ] else ...[
            const Icon(Icons.verified_user, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Your identity keys are ready.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: const Icon(Icons.fingerprint, size: 16),
                label: Text('Fingerprint: ${keyFingerprint(auth.publicKey!)}'),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How others will see you at the ceremony',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onNextFromStep1(),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _displayNameController,
              builder: (_, value, __) => FilledButton.icon(
                onPressed:
                    value.text.trim().isEmpty ? null : _onNextFromStep1,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 2: Show QR code ──────────────────────────────────────────────────

  Widget _buildStep2(BuildContext context, AuthState auth) {
    final signingKey = auth.publicKey;
    final encKey = auth.encryptionPublicKey;
    final displayName = _displayNameController.text.trim();

    if (signingKey == null || encKey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Encryption key not found.\nPlease go back and regenerate your keys.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _goToStep(0),
                child: const Text('Back to key generation'),
              ),
            ],
          ),
        ),
      );
    }

    final qrPayload = jsonEncode({
      'v': 1,
      'display_name': displayName,
      'signing_key': bytesToHex(signingKey),
      'encryption_key': bytesToHex(encKey),
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIndicator(current: 1),
          const SizedBox(height: 24),
          Text(
            'Your QR code',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask each person at the ceremony to scan this QR code.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Chip(
              avatar: const Icon(Icons.fingerprint, size: 16),
              label: Text(keyFingerprint(signingKey)),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _goToStep(2),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("I'm done being scanned → Start scanning others"),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Scan peers ────────────────────────────────────────────────────

  Widget _buildStep3(BuildContext context) {
    final controller = _scannerController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _StepIndicator(current: 2),
        ),
        SizedBox(
          height: 260,
          child: MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) =>
                _buildScannerError(context, error),
          ),
        ),
        Expanded(
          child: _scannedContacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Scan each person\'s QR code to add them as a trusted contact.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _scannedContacts.length,
                  itemBuilder: (context, i) {
                    final c = _scannedContacts[i];
                    return ListTile(
                      leading:
                          const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(c.displayName),
                      trailing: Chip(
                        avatar: const Icon(Icons.fingerprint, size: 14),
                        label: Text(keyFingerprint(c.signingPublicKey)),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _scannedContacts.isEmpty
                ? null
                : () {
                    _scannerController?.stop();
                    context.go('/');
                  },
            icon: const Icon(Icons.check_circle),
            label: Text(
              'Ceremony complete'
              ' (${_scannedContacts.length}'
              ' contact${_scannedContacts.length == 1 ? '' : 's'} added)',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerError(
      BuildContext context, MobileScannerException error) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermission ? Icons.camera_alt : Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPermission
                  ? 'Camera permission denied'
                  : 'Camera unavailable',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPermission
                  ? 'Please enable camera access in your device settings to scan QR codes.'
                  : 'Error: ${error.errorCode}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isDone = i < current;
        final isActive = i == current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: isDone
                ? Colors.green
                : isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

