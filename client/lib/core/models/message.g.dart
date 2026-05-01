// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      ciphertext:
          const Uint8ListConverter().fromJson(json['ciphertext'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isEphemeral: json['isEphemeral'] as bool? ?? false,
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'senderId': instance.senderId,
      'ciphertext': const Uint8ListConverter().toJson(instance.ciphertext),
      'timestamp': instance.timestamp.toIso8601String(),
      'isEphemeral': instance.isEphemeral,
    };
