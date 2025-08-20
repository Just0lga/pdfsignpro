// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'full_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FullResponse _$FullResponseFromJson(Map<String, dynamic> json) {
  return _FullResponse.fromJson(json);
}

/// @nodoc
mixin _$FullResponse {
  List<Perm> get perList => throw _privateConstructorUsedError;
  bool get success => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;

  /// Serializes this FullResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FullResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FullResponseCopyWith<FullResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FullResponseCopyWith<$Res> {
  factory $FullResponseCopyWith(
          FullResponse value, $Res Function(FullResponse) then) =
      _$FullResponseCopyWithImpl<$Res, FullResponse>;
  @useResult
  $Res call({List<Perm> perList, bool success, String userId});
}

/// @nodoc
class _$FullResponseCopyWithImpl<$Res, $Val extends FullResponse>
    implements $FullResponseCopyWith<$Res> {
  _$FullResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FullResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? perList = null,
    Object? success = null,
    Object? userId = null,
  }) {
    return _then(_value.copyWith(
      perList: null == perList
          ? _value.perList
          : perList // ignore: cast_nullable_to_non_nullable
              as List<Perm>,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FullResponseImplCopyWith<$Res>
    implements $FullResponseCopyWith<$Res> {
  factory _$$FullResponseImplCopyWith(
          _$FullResponseImpl value, $Res Function(_$FullResponseImpl) then) =
      __$$FullResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Perm> perList, bool success, String userId});
}

/// @nodoc
class __$$FullResponseImplCopyWithImpl<$Res>
    extends _$FullResponseCopyWithImpl<$Res, _$FullResponseImpl>
    implements _$$FullResponseImplCopyWith<$Res> {
  __$$FullResponseImplCopyWithImpl(
      _$FullResponseImpl _value, $Res Function(_$FullResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of FullResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? perList = null,
    Object? success = null,
    Object? userId = null,
  }) {
    return _then(_$FullResponseImpl(
      perList: null == perList
          ? _value._perList
          : perList // ignore: cast_nullable_to_non_nullable
              as List<Perm>,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FullResponseImpl implements _FullResponse {
  const _$FullResponseImpl(
      {required final List<Perm> perList,
      required this.success,
      required this.userId})
      : _perList = perList;

  factory _$FullResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$FullResponseImplFromJson(json);

  final List<Perm> _perList;
  @override
  List<Perm> get perList {
    if (_perList is EqualUnmodifiableListView) return _perList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_perList);
  }

  @override
  final bool success;
  @override
  final String userId;

  @override
  String toString() {
    return 'FullResponse(perList: $perList, success: $success, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FullResponseImpl &&
            const DeepCollectionEquality().equals(other._perList, _perList) &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.userId, userId) || other.userId == userId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_perList), success, userId);

  /// Create a copy of FullResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FullResponseImplCopyWith<_$FullResponseImpl> get copyWith =>
      __$$FullResponseImplCopyWithImpl<_$FullResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FullResponseImplToJson(
      this,
    );
  }
}

abstract class _FullResponse implements FullResponse {
  const factory _FullResponse(
      {required final List<Perm> perList,
      required final bool success,
      required final String userId}) = _$FullResponseImpl;

  factory _FullResponse.fromJson(Map<String, dynamic> json) =
      _$FullResponseImpl.fromJson;

  @override
  List<Perm> get perList;
  @override
  bool get success;
  @override
  String get userId;

  /// Create a copy of FullResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FullResponseImplCopyWith<_$FullResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
