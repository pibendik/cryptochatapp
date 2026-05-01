// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Contact _$ContactFromJson(Map<String, dynamic> json) {
  return _Contact.fromJson(json);
}

/// @nodoc
mixin _$Contact {
  /// Unique identity — equals the hex-encoded Ed25519 signing public key.
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  @_Uint8ListHexConverter()
  Uint8List get signingPublicKey => throw _privateConstructorUsedError;
  @_Uint8ListHexConverter()
  Uint8List get encryptionPublicKey => throw _privateConstructorUsedError;
  DateTime get verifiedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ContactCopyWith<Contact> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContactCopyWith<$Res> {
  factory $ContactCopyWith(Contact value, $Res Function(Contact) then) =
      _$ContactCopyWithImpl<$Res, Contact>;
  @useResult
  $Res call(
      {String id,
      String displayName,
      @_Uint8ListHexConverter() Uint8List signingPublicKey,
      @_Uint8ListHexConverter() Uint8List encryptionPublicKey,
      DateTime verifiedAt});
}

/// @nodoc
class _$ContactCopyWithImpl<$Res, $Val extends Contact>
    implements $ContactCopyWith<$Res> {
  _$ContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? signingPublicKey = null,
    Object? encryptionPublicKey = null,
    Object? verifiedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      signingPublicKey: null == signingPublicKey
          ? _value.signingPublicKey
          : signingPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      encryptionPublicKey: null == encryptionPublicKey
          ? _value.encryptionPublicKey
          : encryptionPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      verifiedAt: null == verifiedAt
          ? _value.verifiedAt
          : verifiedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ContactImplCopyWith<$Res> implements $ContactCopyWith<$Res> {
  factory _$$ContactImplCopyWith(
          _$ContactImpl value, $Res Function(_$ContactImpl) then) =
      __$$ContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String displayName,
      @_Uint8ListHexConverter() Uint8List signingPublicKey,
      @_Uint8ListHexConverter() Uint8List encryptionPublicKey,
      DateTime verifiedAt});
}

/// @nodoc
class __$$ContactImplCopyWithImpl<$Res>
    extends _$ContactCopyWithImpl<$Res, _$ContactImpl>
    implements _$$ContactImplCopyWith<$Res> {
  __$$ContactImplCopyWithImpl(
      _$ContactImpl _value, $Res Function(_$ContactImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? signingPublicKey = null,
    Object? encryptionPublicKey = null,
    Object? verifiedAt = null,
  }) {
    return _then(_$ContactImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      signingPublicKey: null == signingPublicKey
          ? _value.signingPublicKey
          : signingPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      encryptionPublicKey: null == encryptionPublicKey
          ? _value.encryptionPublicKey
          : encryptionPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      verifiedAt: null == verifiedAt
          ? _value.verifiedAt
          : verifiedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ContactImpl extends _Contact {
  const _$ContactImpl(
      {required this.id,
      required this.displayName,
      @_Uint8ListHexConverter() required this.signingPublicKey,
      @_Uint8ListHexConverter() required this.encryptionPublicKey,
      required this.verifiedAt})
      : super._();

  factory _$ContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$ContactImplFromJson(json);

  /// Unique identity — equals the hex-encoded Ed25519 signing public key.
  @override
  final String id;
  @override
  final String displayName;
  @override
  @_Uint8ListHexConverter()
  final Uint8List signingPublicKey;
  @override
  @_Uint8ListHexConverter()
  final Uint8List encryptionPublicKey;
  @override
  final DateTime verifiedAt;

  @override
  String toString() {
    return 'Contact(id: $id, displayName: $displayName, signingPublicKey: $signingPublicKey, encryptionPublicKey: $encryptionPublicKey, verifiedAt: $verifiedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            const DeepCollectionEquality()
                .equals(other.signingPublicKey, signingPublicKey) &&
            const DeepCollectionEquality()
                .equals(other.encryptionPublicKey, encryptionPublicKey) &&
            (identical(other.verifiedAt, verifiedAt) ||
                other.verifiedAt == verifiedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      displayName,
      const DeepCollectionEquality().hash(signingPublicKey),
      const DeepCollectionEquality().hash(encryptionPublicKey),
      verifiedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ContactImplCopyWith<_$ContactImpl> get copyWith =>
      __$$ContactImplCopyWithImpl<_$ContactImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ContactImplToJson(
      this,
    );
  }
}

abstract class _Contact extends Contact {
  const factory _Contact(
      {required final String id,
      required final String displayName,
      @_Uint8ListHexConverter() required final Uint8List signingPublicKey,
      @_Uint8ListHexConverter() required final Uint8List encryptionPublicKey,
      required final DateTime verifiedAt}) = _$ContactImpl;
  const _Contact._() : super._();

  factory _Contact.fromJson(Map<String, dynamic> json) = _$ContactImpl.fromJson;

  @override

  /// Unique identity — equals the hex-encoded Ed25519 signing public key.
  String get id;
  @override
  String get displayName;
  @override
  @_Uint8ListHexConverter()
  Uint8List get signingPublicKey;
  @override
  @_Uint8ListHexConverter()
  Uint8List get encryptionPublicKey;
  @override
  DateTime get verifiedAt;
  @override
  @JsonKey(ignore: true)
  _$$ContactImplCopyWith<_$ContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
