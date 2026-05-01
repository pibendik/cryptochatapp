import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/hex_utils.dart';

part 'contact.freezed.dart';
part 'contact.g.dart';

/// JSON converter: Uint8List ↔ lowercase hex string.
class _Uint8ListHexConverter implements JsonConverter<Uint8List, String> {
  const _Uint8ListHexConverter();

  @override
  Uint8List fromJson(String hex) {
    if (hex.isEmpty) return Uint8List(0);
    return hexToBytes(hex);
  }

  @override
  String toJson(Uint8List bytes) => bytesToHex(bytes);
}

@freezed
class Contact with _$Contact {
  const Contact._();

  /// Returns a short human-readable fingerprint (80-bit, 20 hex chars).
  /// Use for visual verification only — NOT for crypto operations.
  String get fingerprint => keyFingerprint(signingPublicKey);

  const factory Contact({
    /// Unique identity — equals the hex-encoded Ed25519 signing public key.
    required String id,
    required String displayName,
    @_Uint8ListHexConverter() required Uint8List signingPublicKey,
    @_Uint8ListHexConverter() required Uint8List encryptionPublicKey,
    required DateTime verifiedAt,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);

  /// Construct a Contact from a scanned QR payload map.
  ///
  /// Expected keys: `v`, `display_name`, `signing_key`, `encryption_key`.
  factory Contact.fromQrPayload(Map<String, dynamic> payload) {
    const converter = _Uint8ListHexConverter();
    final signingHex = payload['signing_key'] as String;
    final encHex = payload['encryption_key'] as String;
    return Contact(
      id: signingHex,
      displayName: payload['display_name'] as String,
      signingPublicKey: converter.fromJson(signingHex),
      encryptionPublicKey: converter.fromJson(encHex),
      verifiedAt: DateTime.now(),
    );
  }
}
