// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      publicKeyBase64: json['publicKeyBase64'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'publicKeyBase64': instance.publicKeyBase64,
      'avatarUrl': instance.avatarUrl,
      'skills': instance.skills,
    };
