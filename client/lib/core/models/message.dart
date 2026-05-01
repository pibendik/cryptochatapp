import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Uint8List JSON converter — base64 encode/decode for transport.
class Uint8ListConverter implements JsonConverter<Uint8List, String> {
  const Uint8ListConverter();

  @override
  Uint8List fromJson(String json) {
    // TODO: replace with base64 decode
    throw UnimplementedError('Uint8ListConverter.fromJson not yet implemented');
  }

  @override
  String toJson(Uint8List object) {
    // TODO: replace with base64 encode
    throw UnimplementedError('Uint8ListConverter.toJson not yet implemented');
  }
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String groupId,
    required String senderId,
    /// Encrypted ciphertext. NEVER store or log as String.
    @Uint8ListConverter() required Uint8List ciphertext,
    required DateTime timestamp,
    @Default(false) bool isEphemeral,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
