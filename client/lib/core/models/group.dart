import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

enum GroupType { group, directMessage, forum, ephemeralHelp }

@freezed
class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    required GroupType type,
    /// Public key IDs of all members.
    required List<String> memberIds,
    String? description,
    @Default(false) bool isEphemeral,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
