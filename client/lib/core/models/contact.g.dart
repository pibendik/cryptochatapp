// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ContactImpl _$$ContactImplFromJson(Map<String, dynamic> json) =>
    _$ContactImpl(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      signingPublicKey: const _Uint8ListHexConverter()
          .fromJson(json['signingPublicKey'] as String),
      encryptionPublicKey: const _Uint8ListHexConverter()
          .fromJson(json['encryptionPublicKey'] as String),
      verifiedAt: DateTime.parse(json['verifiedAt'] as String),
    );

Map<String, dynamic> _$$ContactImplToJson(_$ContactImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'signingPublicKey':
          const _Uint8ListHexConverter().toJson(instance.signingPublicKey),
      'encryptionPublicKey':
          const _Uint8ListHexConverter().toJson(instance.encryptionPublicKey),
      'verifiedAt': instance.verifiedAt.toIso8601String(),
    };
