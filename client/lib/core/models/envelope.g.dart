// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EnvelopeImpl _$$EnvelopeImplFromJson(Map<String, dynamic> json) =>
    _$EnvelopeImpl(
      to: json['to'] as String,
      from: json['from'] as String,
      payload: const Uint8ListConverter().fromJson(json['payload'] as String),
      signature:
          const Uint8ListConverter().fromJson(json['signature'] as String),
    );

Map<String, dynamic> _$$EnvelopeImplToJson(_$EnvelopeImpl instance) =>
    <String, dynamic>{
      'to': instance.to,
      'from': instance.from,
      'payload': const Uint8ListConverter().toJson(instance.payload),
      'signature': const Uint8ListConverter().toJson(instance.signature),
    };
