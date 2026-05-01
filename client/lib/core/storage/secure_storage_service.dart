import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage.
/// Private keys are ONLY persisted here — never in SharedPreferences, files, or logs.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _keyPrivateKey = 'ed25519_secret_key';
  static const _keyPublicKey = 'ed25519_public_key';
  static const _keyEncPrivateKey = 'x25519_private_key';
  static const _keyEncPublicKey = 'x25519_public_key';
  static const _keyUserId = 'user_id';
  static const _keyDisplayName = 'display_name';

  static const _keySessionToken = 'session_token';

  // ── Key material ──────────────────────────────────────────────────────────

  /// Persist the Ed25519 secret key. [secretKey] is 64 bytes.
  Future<void> saveSecretKey(Uint8List secretKey) async {
    await _storage.write(
      key: _keyPrivateKey,
      value: base64.encode(secretKey),
    );
  }

  /// Read the stored Ed25519 secret key, or null if not yet generated.
  Future<Uint8List?> readSecretKey() async {
    final encoded = await _storage.read(key: _keyPrivateKey);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  /// Persist the Ed25519 public key. [publicKey] is 32 bytes.
  Future<void> savePublicKey(Uint8List publicKey) async {
    await _storage.write(
      key: _keyPublicKey,
      value: base64.encode(publicKey),
    );
  }

  Future<Uint8List?> readPublicKey() async {
    final encoded = await _storage.read(key: _keyPublicKey);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  // ── X25519 encryption keypair ─────────────────────────────────────────────

  /// Persist the X25519 encryption private key. [privateKey] is 32 bytes.
  Future<void> storeEncryptionPrivateKey(Uint8List privateKey) async {
    await _storage.write(
      key: _keyEncPrivateKey,
      value: base64.encode(privateKey),
    );
  }

  /// Read the stored X25519 encryption private key, or null if not yet generated.
  Future<Uint8List?> getEncryptionPrivateKey() async {
    final encoded = await _storage.read(key: _keyEncPrivateKey);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  /// Persist the X25519 encryption public key. [publicKey] is 32 bytes.
  Future<void> storeEncryptionPublicKey(Uint8List publicKey) async {
    await _storage.write(
      key: _keyEncPublicKey,
      value: base64.encode(publicKey),
    );
  }

  /// Read the stored X25519 encryption public key, or null if not yet generated.
  Future<Uint8List?> getEncryptionPublicKey() async {
    final encoded = await _storage.read(key: _keyEncPublicKey);
    if (encoded == null) return null;
    return base64.decode(encoded);
  }

  // ── User identity ─────────────────────────────────────────────────────────

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<String?> readUserId() => _storage.read(key: _keyUserId);

  // ── Display name ──────────────────────────────────────────────────────────

  Future<void> saveDisplayName(String name) =>
      _storage.write(key: _keyDisplayName, value: name);

  Future<String?> readDisplayName() => _storage.read(key: _keyDisplayName);

  Future<void> storeSessionToken(String token) =>
      _storage.write(key: _keySessionToken, value: token);

  Future<String?> getSessionToken() => _storage.read(key: _keySessionToken);

  Future<void> deleteSessionToken() => _storage.delete(key: _keySessionToken);

  // ── Misc helpers ──────────────────────────────────────────────────────────

  /// Delete all stored secrets (e.g. on sign-out / key rotation).
  Future<void> deleteAll() => _storage.deleteAll();

  /// Generic write for arbitrary secure values (e.g. per-group session keys).
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);
}
