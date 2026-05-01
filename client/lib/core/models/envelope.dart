import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'message.dart';

part 'envelope.freezed.dart';
part 'envelope.g.dart';

/// Wire-format wrapper for all WebSocket messages.
/// The server only sees [to], [from], and opaque [payload] ciphertext.
@freezed
class Envelope with _$Envelope {
  const factory Envelope({
    required String to,
    required String from,
    /// Encrypted payload — always ciphertext, never plaintext.
    @Uint8ListConverter() required Uint8List payload,
    /// Ed25519 signature over payload bytes.
    @Uint8ListConverter() required Uint8List signature,
  }) = _Envelope;

  factory Envelope.fromJson(Map<String, dynamic> json) =>
      _$EnvelopeFromJson(json);
}
