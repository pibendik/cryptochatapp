import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/crypto/crypto_service.dart';
import '../../core/crypto/dart_cryptography_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/hex_utils.dart';

part 'auth_provider.g.dart';

// ── Service providers ─────────────────────────────────────────────────────

@riverpod
FlutterSecureStorage flutterSecureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}

@riverpod
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService(ref.read(flutterSecureStorageProvider));
}

@riverpod
CryptoService cryptoService(Ref ref) {
  // Swap DartCryptographyService for a mock in tests by overriding this provider.
  return DartCryptographyService();
}

// ── Auth state ────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.publicKey,
    this.secretKey,
    this.encryptionPublicKey,
    this.encryptionPrivateKey,
    this.sessionToken,
    this.userId,
    this.isLoading = false,
    this.error,
  });

  final Uint8List? publicKey;

  /// Secret key held in memory only. SecureStorageService owns persistence.
  final Uint8List? secretKey;

  final Uint8List? encryptionPublicKey;
  final Uint8List? encryptionPrivateKey;

  final String? sessionToken;
  final String? userId;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated =>
      publicKey != null && secretKey != null && sessionToken != null;

  AuthState copyWith({
    Uint8List? publicKey,
    Uint8List? secretKey,
    Uint8List? encryptionPublicKey,
    Uint8List? encryptionPrivateKey,
    String? sessionToken,
    String? userId,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      publicKey: publicKey ?? this.publicKey,
      secretKey: secretKey ?? this.secretKey,
      encryptionPublicKey: encryptionPublicKey ?? this.encryptionPublicKey,
      encryptionPrivateKey: encryptionPrivateKey ?? this.encryptionPrivateKey,
      sessionToken: sessionToken ?? this.sessionToken,
      userId: userId ?? this.userId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState(isLoading: true);
  }

  // ── Public methods ───────────────────────────────────────────────────────

  /// Full challenge-response auth handshake against the backend.
  ///
  /// 1. Load or generate Ed25519 signing keypair.
  /// 2. Load or generate X25519 encryption keypair.
  /// 3. POST /auth/challenge → receive challenge bytes.
  /// 4. Sign challenge bytes with Ed25519 secret key.
  /// 5. POST /auth/verify → receive session_token + user_id.
  /// 6. Persist session_token and user_id.
  /// 7. Update state to authenticated.
  Future<void> requestChallenge(String serverUrl, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final crypto = ref.read(cryptoServiceProvider);
      final storage = ref.read(secureStorageProvider);

      // ── 1. Signing keypair ───────────────────────────────────────────────
      Keypair signingKp;
      final storedSecret = await storage.readSecretKey();
      final storedPublic = await storage.readPublicKey();
      if (storedSecret != null && storedPublic != null) {
        signingKp = Keypair(publicKey: storedPublic, secretKey: storedSecret);
      } else {
        signingKp = await crypto.generateKeypair();
        await storage.saveSecretKey(signingKp.secretKey);
        await storage.savePublicKey(signingKp.publicKey);
      }

      // ── 2. Encryption keypair ────────────────────────────────────────────
      EncryptionKeypair encKp;
      final storedEncPriv = await storage.getEncryptionPrivateKey();
      final storedEncPub = await storage.getEncryptionPublicKey();
      if (storedEncPriv != null && storedEncPub != null) {
        encKp = EncryptionKeypair(
          publicKey: storedEncPub,
          privateKey: storedEncPriv,
        );
      } else {
        encKp = await crypto.generateEncryptionKeypair();
        await storage.storeEncryptionPrivateKey(encKp.privateKey);
        await storage.storeEncryptionPublicKey(encKp.publicKey);
      }

      final sigPubHex = bytesToHex(signingKp.publicKey);
      final encPubHex = bytesToHex(encKp.publicKey);

      // ── 3. POST /auth/challenge ──────────────────────────────────────────
      final challengeRes = await http.post(
        Uri.parse('$serverUrl/auth/challenge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'public_key': sigPubHex}),
      );

      if (challengeRes.statusCode != 200) {
        throw Exception(
            'Challenge request failed: ${challengeRes.statusCode} ${challengeRes.body}');
      }

      final challengeJson =
          jsonDecode(challengeRes.body) as Map<String, dynamic>;
      final challengeId = challengeJson['challenge_id'] as String;
      final challengeHex = challengeJson['challenge'] as String;
      final challengeBytes = hexToBytes(challengeHex);

      // ── 4. Sign the challenge ────────────────────────────────────────────
      final signature = await crypto.sign(challengeBytes, signingKp.secretKey);
      final sigHex = bytesToHex(signature);

      // ── 5. POST /auth/verify ─────────────────────────────────────────────
      final verifyRes = await http.post(
        Uri.parse('$serverUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'challenge_id': challengeId,
          'signature': sigHex,
          'display_name': displayName,
          'encryption_public_key': encPubHex,
        }),
      );

      if (verifyRes.statusCode != 200) {
        throw Exception(
            'Verify request failed: ${verifyRes.statusCode} ${verifyRes.body}');
      }

      final verifyJson = jsonDecode(verifyRes.body) as Map<String, dynamic>;
      final sessionToken = verifyJson['session_token'] as String;
      final userId = verifyJson['user_id'] as String;

      // ── 6. Persist session ───────────────────────────────────────────────
      await storage.storeSessionToken(sessionToken);
      await storage.saveUserId(userId);

      // ── 7. Update state ──────────────────────────────────────────────────
      // BLOCKED(allowlist): server currently accepts any keypair — requires server-side allowlist before first real deployment
      state = AuthState(
        publicKey: signingKp.publicKey,
        secretKey: signingKp.secretKey,
        encryptionPublicKey: encKp.publicKey,
        encryptionPrivateKey: encKp.privateKey,
        sessionToken: sessionToken,
        userId: userId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Generate both Ed25519 signing and X25519 encryption keypairs, persist
  /// them, and update state. Used during the local key-signing ceremony before
  /// any server connection is established.
  Future<void> generateAndStoreKeypair() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final crypto = ref.read(cryptoServiceProvider);
      final storage = ref.read(secureStorageProvider);

      final keypair = await crypto.generateKeypair();
      final encKeypair = await crypto.generateEncryptionKeypair();

      await storage.saveSecretKey(keypair.secretKey);
      await storage.savePublicKey(keypair.publicKey);
      await storage.storeEncryptionPrivateKey(encKeypair.privateKey);
      await storage.storeEncryptionPublicKey(encKeypair.publicKey);

      // userId is assigned by the server after /auth/verify — never derive it locally
      state = state.copyWith(
        publicKey: keypair.publicKey,
        secretKey: keypair.secretKey,
        encryptionPublicKey: encKeypair.publicKey,
        encryptionPrivateKey: encKeypair.privateKey,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign a server-issued challenge bytes. Used in the WebSocket auth handshake.
  Future<Uint8List> signChallenge(Uint8List challenge) async {
    final secretKey = state.secretKey;
    if (secretKey == null) {
      throw StateError('Cannot sign challenge: no secret key loaded');
    }
    final crypto = ref.read(cryptoServiceProvider);
    return crypto.sign(challenge, secretKey);
  }

  /// Update the in-memory keypair after a key rotation proposal is submitted.
  ///
  /// The new keypair has already been persisted to secure storage by the caller.
  /// The session token is unchanged — the user re-authenticates once the proposal
  /// is approved and they tap "Clear & re-authenticate".
  void updateKeypairAfterRotation({
    required Uint8List newPublicKey,
    required Uint8List newSecretKey,
    required Uint8List newEncPublicKey,
    required Uint8List newEncPrivateKey,
  }) {
    state = state.copyWith(
      publicKey: newPublicKey,
      secretKey: newSecretKey,
      encryptionPublicKey: newEncPublicKey,
      encryptionPrivateKey: newEncPrivateKey,
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final storage = ref.read(secureStorageProvider);

      final secretKey = await storage.readSecretKey();
      final publicKey = await storage.readPublicKey();
      final encPriv = await storage.getEncryptionPrivateKey();
      final encPub = await storage.getEncryptionPublicKey();
      final sessionToken = await storage.getSessionToken();
      final userId = await storage.readUserId();

      // Restore keys even without a session token so the onboarding redirect
      // (which checks publicKey != null) works correctly after a restart.
      if (secretKey != null && publicKey != null) {
        state = AuthState(
          secretKey: secretKey,
          publicKey: publicKey,
          encryptionPrivateKey: encPriv,
          encryptionPublicKey: encPub,
          sessionToken: sessionToken,
          userId: userId,
          isLoading: false,
        );
      } else {
        state = const AuthState(isLoading: false);
      }
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

}

// authProvider (NotifierProvider<Auth, AuthState>) is generated by build_runner.
// ref.watch(authProvider) returns AuthState; ref.read(authProvider.notifier) returns Auth.
