import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_service.dart';

/// Exception wrapping cryptographic failures.
class CryptoException implements Exception {
  const CryptoException(this.message);
  final String message;

  @override
  String toString() => 'CryptoException: $message';
}

/// CryptoService implementation backed by the `cryptography` Dart package.
///
/// No native libraries required — works on all Flutter platforms including web.
/// On Android/iOS, add `cryptography_flutter` initialisation in main.dart:
///   `FlutterCryptography.enable();`
/// to enable hardware-accelerated AES-GCM where available.
class DartCryptographyService implements CryptoService {
  // Security note: Ed25519 provides 128-bit security with compact 64-byte
  // signatures and fast batch verification. Chosen over ECDSA (P-256) because
  // it is immune to weak random-number generators during signing.
  static final _ed25519 = Ed25519();

  // Security note: X25519 (Curve25519 Diffie-Hellman) is the standard for
  // ephemeral key agreement. It is constant-time by design, preventing
  // timing-side-channel attacks, and does not require a trusted curve seed.
  static final _x25519 = X25519();

  // Security note: ChaCha20-Poly1305 is an AEAD cipher that combines stream
  // encryption (ChaCha20) with a MAC (Poly1305). Preferred over AES-GCM on
  // platforms without AES hardware acceleration because it is constant-time in
  // software. 256-bit key, 96-bit nonce, 128-bit authentication tag.
  static final _chacha20 = Chacha20.poly1305Aead();

  // Security note: HKDF-SHA256 conditions the raw X25519 shared secret into a
  // uniformly-random key before passing it to ChaCha20-Poly1305. Raw X25519
  // output is not uniformly random (it is a point on the curve), so direct use
  // as a cipher key is unsafe.
  static final _hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);

  // ── Keypair generation ────────────────────────────────────────────────────

  @override
  Future<Keypair> generateKeypair() async {
    try {
      final keyPair = await _ed25519.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      return Keypair(
        publicKey: Uint8List.fromList(publicKey.bytes),
        secretKey: Uint8List.fromList(privateKeyBytes),
      );
    } catch (e) {
      throw CryptoException('Failed to generate Ed25519 keypair: $e');
    }
  }

  @override
  Future<EncryptionKeypair> generateEncryptionKeypair() async {
    try {
      final keyPair = await _x25519.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      return EncryptionKeypair(
        publicKey: Uint8List.fromList(publicKey.bytes),
        privateKey: Uint8List.fromList(privateKeyBytes),
      );
    } catch (e) {
      throw CryptoException('Failed to generate X25519 keypair: $e');
    }
  }

  // ── Signing ───────────────────────────────────────────────────────────────

  @override
  Future<Uint8List> sign(Uint8List message, Uint8List secretKey) async {
    try {
      // Reconstruct the Ed25519 keypair from the stored 32-byte seed.
      final keyPair = await _ed25519.newKeyPairFromSeed(secretKey);
      final sig = await _ed25519.sign(message, keyPair: keyPair);
      return Uint8List.fromList(sig.bytes);
    } catch (e) {
      throw CryptoException('Failed to sign message: $e');
    }
  }

  @override
  Future<bool> verify(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    try {
      final sig = Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      );
      return await _ed25519.verify(message, signature: sig);
    } catch (e) {
      throw CryptoException('Failed to verify signature: $e');
    }
  }

  // ── Encryption ────────────────────────────────────────────────────────────

  /// Wire format: ephemeralPublicKey (32 B) || nonce (12 B) || ciphertext || MAC (16 B)
  ///
  // BLOCKED(phase-3): group key management uses per-message ephemeral keys —
  // MLS epoch-based rotation planned for Phase 3
  @override
  Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List recipientPublicKey,
  ) async {
    try {
      // 1. Generate a fresh ephemeral X25519 keypair for this message.
      //    Never reusing ephemeral keys preserves forward secrecy.
      final ephemeralKP = await _x25519.newKeyPair();
      final ephemeralPublicKey = await ephemeralKP.extractPublicKey();

      // 2. Derive the X25519 shared secret.
      final remotePublicKey = SimplePublicKey(
        recipientPublicKey,
        type: KeyPairType.x25519,
      );
      final rawSharedSecret = await _x25519.sharedSecretKey(
        keyPair: ephemeralKP,
        remotePublicKey: remotePublicKey,
      );

      // 3. Condition the shared secret through HKDF-SHA256.
      //    The ephemeral public key bytes serve as the HKDF salt, binding
      //    the derived key to this specific ephemeral exchange.
      final encKey = await _hkdf.deriveKey(
        secretKey: rawSharedSecret,
        nonce: ephemeralPublicKey.bytes,
      );

      // 4. Encrypt with ChaCha20-Poly1305 (random 12-byte nonce).
      final nonce = _randomBytes(12);
      final secretBox = await _chacha20.encrypt(
        plaintext,
        secretKey: encKey,
        nonce: nonce,
      );

      // 5. Assemble wire format.
      final out = BytesBuilder(copy: false)
        ..add(ephemeralPublicKey.bytes) // 32 bytes
        ..add(nonce) //  12 bytes
        ..add(secretBox.cipherText) // variable
        ..add(secretBox.mac.bytes); //  16 bytes (Poly1305 tag)
      return out.toBytes();
    } catch (e) {
      throw CryptoException('Failed to encrypt: $e');
    }
  }

  @override
  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List privateKey,
  ) async {
    const ephPubLen = 32;
    const nonceLen = 12;
    const macLen = 16;
    const minLen = ephPubLen + nonceLen + macLen; // 60 bytes minimum

    if (ciphertext.length < minLen) {
      throw CryptoException(
        'Ciphertext too short (${ciphertext.length} < $minLen)',
      );
    }

    try {
      // Parse wire format: ephemeralPublicKey || nonce || ciphertext || MAC.
      var offset = 0;
      final ephPubBytes = ciphertext.sublist(offset, offset += ephPubLen);
      final nonce = ciphertext.sublist(offset, offset += nonceLen);
      final mac = ciphertext.sublist(ciphertext.length - macLen);
      final encData = ciphertext.sublist(offset, ciphertext.length - macLen);

      // Reconstruct recipient X25519 keypair from stored 32-byte private key.
      final recipientKP = await _x25519.newKeyPairFromSeed(privateKey);

      // Derive the same shared secret the sender used.
      final ephPublicKey = SimplePublicKey(ephPubBytes, type: KeyPairType.x25519);
      final rawSharedSecret = await _x25519.sharedSecretKey(
        keyPair: recipientKP,
        remotePublicKey: ephPublicKey,
      );

      // Condition through HKDF-SHA256 with the same salt (ephemeral public key).
      final encKey = await _hkdf.deriveKey(
        secretKey: rawSharedSecret,
        nonce: ephPubBytes,
      );

      // Decrypt + authenticate with ChaCha20-Poly1305.
      final secretBox = SecretBox(encData, nonce: nonce, mac: Mac(mac));
      final plaintext = await _chacha20.decrypt(
        secretBox,
        secretKey: encKey,
      );
      return Uint8List.fromList(plaintext);
    } on CryptoException {
      rethrow;
    } catch (e) {
      throw CryptoException('Failed to decrypt: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }
}
