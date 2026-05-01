import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String displayName,
    /// Ed25519 public key, base64-encoded.
    required String publicKeyBase64,
    String? avatarUrl,
    @Default([]) List<String> skills,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
