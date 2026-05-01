// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupImpl _$$GroupImplFromJson(Map<String, dynamic> json) => _$GroupImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$GroupTypeEnumMap, json['type']),
      memberIds:
          (json['memberIds'] as List<dynamic>).map((e) => e as String).toList(),
      description: json['description'] as String?,
      isEphemeral: json['isEphemeral'] as bool? ?? false,
    );

Map<String, dynamic> _$$GroupImplToJson(_$GroupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$GroupTypeEnumMap[instance.type]!,
      'memberIds': instance.memberIds,
      'description': instance.description,
      'isEphemeral': instance.isEphemeral,
    };

const _$GroupTypeEnumMap = {
  GroupType.group: 'group',
  GroupType.directMessage: 'directMessage',
  GroupType.forum: 'forum',
  GroupType.ephemeralHelp: 'ephemeralHelp',
};
