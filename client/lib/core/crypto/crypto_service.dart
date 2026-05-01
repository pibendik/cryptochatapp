import 'dart:typed_data';

/// Ed25519 signing keypair.
class Keypair {
  /// 32-byte Ed25519 public key.
  final Uint8List publicKey;

  /// 32-byte Ed25519 private key seed. Keep in memory only; persist via SecureStorageService.
  final Uint8List secretKey;

  const Keypair({required this.publicKey, required this.secretKey});
}

/// X25519 encryption keypair (separate from the Ed25519 signing keypair).
///
/// Ed25519 and X25519 use different elliptic curves and must NOT share key material.
class EncryptionKeypair {
  /// 32-byte X25519 public key.
  final Uint8List publicKey;

  /// 32-byte X25519 private key. Keep in memory only; persist via SecureStorageService.
  final Uint8List privateKey;

  const EncryptionKeypair({required this.publicKey, required this.privateKey});
}

/// Abstract crypto interface.
/// Concrete implementations use the `cryptography` Dart package; tests inject a mock.
abstract class CryptoService {
  /// Generate a new Ed25519 signing keypair.
  Future<Keypair> generateKeypair();

  /// Generate a new X25519 encryption keypair (separate from the signing keypair).
  Future<EncryptionKeypair> generateEncryptionKeypair();

  /// Sign [message] bytes with [secretKey] (32-byte Ed25519 seed). Returns 64-byte signature.
  Future<Uint8List> sign(Uint8List message, Uint8List secretKey);

  /// Verify [signature] over [message] with [publicKey].
  Future<bool> verify(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  );

  /// Encrypt [plaintext] for [recipientPublicKey] (32-byte X25519 public key).
  ///
  /// Uses ECIES-style ephemeral X25519 + ChaCha20-Poly1305.
  /// Wire format: ephemeralPublicKey (32 B) || nonce (12 B) || ciphertext || MAC (16 B).
  Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List recipientPublicKey,
  );

  /// Decrypt [ciphertext] using [privateKey] (32-byte X25519 private key).
  ///
  /// Parses the ephemeral public key from the wire format, derives the shared
  /// secret, and decrypts with ChaCha20-Poly1305.
  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List privateKey,
  );
}
