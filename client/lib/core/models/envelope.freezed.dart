// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Envelope _$EnvelopeFromJson(Map<String, dynamic> json) {
  return _Envelope.fromJson(json);
}

/// @nodoc
mixin _$Envelope {
  String get to => throw _privateConstructorUsedError;
  String get from => throw _privateConstructorUsedError;

  /// Encrypted payload — always ciphertext, never plaintext.
  @Uint8ListConverter()
  Uint8List get payload => throw _privateConstructorUsedError;

  /// Ed25519 signature over payload bytes.
  @Uint8ListConverter()
  Uint8List get signature => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EnvelopeCopyWith<Envelope> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnvelopeCopyWith<$Res> {
  factory $EnvelopeCopyWith(Envelope value, $Res Function(Envelope) then) =
      _$EnvelopeCopyWithImpl<$Res, Envelope>;
  @useResult
  $Res call(
      {String to,
      String from,
      @Uint8ListConverter() Uint8List payload,
      @Uint8ListConverter() Uint8List signature});
}

/// @nodoc
class _$EnvelopeCopyWithImpl<$Res, $Val extends Envelope>
    implements $EnvelopeCopyWith<$Res> {
  _$EnvelopeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? to = null,
    Object? from = null,
    Object? payload = null,
    Object? signature = null,
  }) {
    return _then(_value.copyWith(
      to: null == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _value.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      signature: null == signature
          ? _value.signature
          : signature // ignore: cast_nullable_to_non_nullable
              as Uint8List,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EnvelopeImplCopyWith<$Res>
    implements $EnvelopeCopyWith<$Res> {
  factory _$$EnvelopeImplCopyWith(
          _$EnvelopeImpl value, $Res Function(_$EnvelopeImpl) then) =
      __$$EnvelopeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String to,
      String from,
      @Uint8ListConverter() Uint8List payload,
      @Uint8ListConverter() Uint8List signature});
}

/// @nodoc
class __$$EnvelopeImplCopyWithImpl<$Res>
    extends _$EnvelopeCopyWithImpl<$Res, _$EnvelopeImpl>
    implements _$$EnvelopeImplCopyWith<$Res> {
  __$$EnvelopeImplCopyWithImpl(
      _$EnvelopeImpl _value, $Res Function(_$EnvelopeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? to = null,
    Object? from = null,
    Object? payload = null,
    Object? signature = null,
  }) {
    return _then(_$EnvelopeImpl(
      to: null == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _value.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      signature: null == signature
          ? _value.signature
          : signature // ignore: cast_nullable_to_non_nullable
              as Uint8List,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EnvelopeImpl implements _Envelope {
  const _$EnvelopeImpl(
      {required this.to,
      required this.from,
      @Uint8ListConverter() required this.payload,
      @Uint8ListConverter() required this.signature});

  factory _$EnvelopeImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnvelopeImplFromJson(json);

  @override
  final String to;
  @override
  final String from;

  /// Encrypted payload — always ciphertext, never plaintext.
  @override
  @Uint8ListConverter()
  final Uint8List payload;

  /// Ed25519 signature over payload bytes.
  @override
  @Uint8ListConverter()
  final Uint8List signature;

  @override
  String toString() {
    return 'Envelope(to: $to, from: $from, payload: $payload, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnvelopeImpl &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.from, from) || other.from == from) &&
            const DeepCollectionEquality().equals(other.payload, payload) &&
            const DeepCollectionEquality().equals(other.signature, signature));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      to,
      from,
      const DeepCollectionEquality().hash(payload),
      const DeepCollectionEquality().hash(signature));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EnvelopeImplCopyWith<_$EnvelopeImpl> get copyWith =>
      __$$EnvelopeImplCopyWithImpl<_$EnvelopeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EnvelopeImplToJson(
      this,
    );
  }
}

abstract class _Envelope implements Envelope {
  const factory _Envelope(
          {required final String to,
          required final String from,
          @Uint8ListConverter() required final Uint8List payload,
          @Uint8ListConverter() required final Uint8List signature}) =
      _$EnvelopeImpl;

  factory _Envelope.fromJson(Map<String, dynamic> json) =
      _$EnvelopeImpl.fromJson;

  @override
  String get to;
  @override
  String get from;
  @override

  /// Encrypted payload — always ciphertext, never plaintext.
  @Uint8ListConverter()
  Uint8List get payload;
  @override

  /// Ed25519 signature over payload bytes.
  @Uint8ListConverter()
  Uint8List get signature;
  @override
  @JsonKey(ignore: true)
  _$$EnvelopeImplCopyWith<_$EnvelopeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
