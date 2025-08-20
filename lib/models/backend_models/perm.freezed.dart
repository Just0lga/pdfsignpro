// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'perm.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Perm _$PermFromJson(Map<String, dynamic> json) {
  return _Perm.fromJson(json);
}

/// @nodoc
mixin _$Perm {
  String get permtype => throw _privateConstructorUsedError;
  String? get uname => throw _privateConstructorUsedError;
  String? get pass => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _portFromJson, toJson: _portToJson)
  int? get port => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'passive_mode')
  bool? get passiveMode => throw _privateConstructorUsedError;
  String? get host => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String? get encoding => throw _privateConstructorUsedError;
  int get ap => throw _privateConstructorUsedError;

  /// Serializes this Perm to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Perm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PermCopyWith<Perm> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PermCopyWith<$Res> {
  factory $PermCopyWith(Perm value, $Res Function(Perm) then) =
      _$PermCopyWithImpl<$Res, Perm>;
  @useResult
  $Res call(
      {String permtype,
      String? uname,
      String? pass,
      @JsonKey(fromJson: _portFromJson, toJson: _portToJson) int? port,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'passive_mode') bool? passiveMode,
      String? host,
      String name,
      String id,
      String type,
      String? encoding,
      int ap});
}

/// @nodoc
class _$PermCopyWithImpl<$Res, $Val extends Perm>
    implements $PermCopyWith<$Res> {
  _$PermCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Perm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permtype = null,
    Object? uname = freezed,
    Object? pass = freezed,
    Object? port = freezed,
    Object? userId = null,
    Object? passiveMode = freezed,
    Object? host = freezed,
    Object? name = null,
    Object? id = null,
    Object? type = null,
    Object? encoding = freezed,
    Object? ap = null,
  }) {
    return _then(_value.copyWith(
      permtype: null == permtype
          ? _value.permtype
          : permtype // ignore: cast_nullable_to_non_nullable
              as String,
      uname: freezed == uname
          ? _value.uname
          : uname // ignore: cast_nullable_to_non_nullable
              as String?,
      pass: freezed == pass
          ? _value.pass
          : pass // ignore: cast_nullable_to_non_nullable
              as String?,
      port: freezed == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      passiveMode: freezed == passiveMode
          ? _value.passiveMode
          : passiveMode // ignore: cast_nullable_to_non_nullable
              as bool?,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      encoding: freezed == encoding
          ? _value.encoding
          : encoding // ignore: cast_nullable_to_non_nullable
              as String?,
      ap: null == ap
          ? _value.ap
          : ap // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PermImplCopyWith<$Res> implements $PermCopyWith<$Res> {
  factory _$$PermImplCopyWith(
          _$PermImpl value, $Res Function(_$PermImpl) then) =
      __$$PermImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String permtype,
      String? uname,
      String? pass,
      @JsonKey(fromJson: _portFromJson, toJson: _portToJson) int? port,
      @JsonKey(name: 'user_id') String userId,
      @JsonKey(name: 'passive_mode') bool? passiveMode,
      String? host,
      String name,
      String id,
      String type,
      String? encoding,
      int ap});
}

/// @nodoc
class __$$PermImplCopyWithImpl<$Res>
    extends _$PermCopyWithImpl<$Res, _$PermImpl>
    implements _$$PermImplCopyWith<$Res> {
  __$$PermImplCopyWithImpl(_$PermImpl _value, $Res Function(_$PermImpl) _then)
      : super(_value, _then);

  /// Create a copy of Perm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permtype = null,
    Object? uname = freezed,
    Object? pass = freezed,
    Object? port = freezed,
    Object? userId = null,
    Object? passiveMode = freezed,
    Object? host = freezed,
    Object? name = null,
    Object? id = null,
    Object? type = null,
    Object? encoding = freezed,
    Object? ap = null,
  }) {
    return _then(_$PermImpl(
      permtype: null == permtype
          ? _value.permtype
          : permtype // ignore: cast_nullable_to_non_nullable
              as String,
      uname: freezed == uname
          ? _value.uname
          : uname // ignore: cast_nullable_to_non_nullable
              as String?,
      pass: freezed == pass
          ? _value.pass
          : pass // ignore: cast_nullable_to_non_nullable
              as String?,
      port: freezed == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      passiveMode: freezed == passiveMode
          ? _value.passiveMode
          : passiveMode // ignore: cast_nullable_to_non_nullable
              as bool?,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      encoding: freezed == encoding
          ? _value.encoding
          : encoding // ignore: cast_nullable_to_non_nullable
              as String?,
      ap: null == ap
          ? _value.ap
          : ap // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PermImpl implements _Perm {
  const _$PermImpl(
      {required this.permtype,
      this.uname,
      this.pass,
      @JsonKey(fromJson: _portFromJson, toJson: _portToJson) this.port,
      @JsonKey(name: 'user_id') required this.userId,
      @JsonKey(name: 'passive_mode') this.passiveMode,
      this.host,
      required this.name,
      required this.id,
      required this.type,
      this.encoding,
      required this.ap});

  factory _$PermImpl.fromJson(Map<String, dynamic> json) =>
      _$$PermImplFromJson(json);

  @override
  final String permtype;
  @override
  final String? uname;
  @override
  final String? pass;
  @override
  @JsonKey(fromJson: _portFromJson, toJson: _portToJson)
  final int? port;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'passive_mode')
  final bool? passiveMode;
  @override
  final String? host;
  @override
  final String name;
  @override
  final String id;
  @override
  final String type;
  @override
  final String? encoding;
  @override
  final int ap;

  @override
  String toString() {
    return 'Perm(permtype: $permtype, uname: $uname, pass: $pass, port: $port, userId: $userId, passiveMode: $passiveMode, host: $host, name: $name, id: $id, type: $type, encoding: $encoding, ap: $ap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PermImpl &&
            (identical(other.permtype, permtype) ||
                other.permtype == permtype) &&
            (identical(other.uname, uname) || other.uname == uname) &&
            (identical(other.pass, pass) || other.pass == pass) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.passiveMode, passiveMode) ||
                other.passiveMode == passiveMode) &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.encoding, encoding) ||
                other.encoding == encoding) &&
            (identical(other.ap, ap) || other.ap == ap));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, permtype, uname, pass, port,
      userId, passiveMode, host, name, id, type, encoding, ap);

  /// Create a copy of Perm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PermImplCopyWith<_$PermImpl> get copyWith =>
      __$$PermImplCopyWithImpl<_$PermImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PermImplToJson(
      this,
    );
  }
}

abstract class _Perm implements Perm {
  const factory _Perm(
      {required final String permtype,
      final String? uname,
      final String? pass,
      @JsonKey(fromJson: _portFromJson, toJson: _portToJson) final int? port,
      @JsonKey(name: 'user_id') required final String userId,
      @JsonKey(name: 'passive_mode') final bool? passiveMode,
      final String? host,
      required final String name,
      required final String id,
      required final String type,
      final String? encoding,
      required final int ap}) = _$PermImpl;

  factory _Perm.fromJson(Map<String, dynamic> json) = _$PermImpl.fromJson;

  @override
  String get permtype;
  @override
  String? get uname;
  @override
  String? get pass;
  @override
  @JsonKey(fromJson: _portFromJson, toJson: _portToJson)
  int? get port;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'passive_mode')
  bool? get passiveMode;
  @override
  String? get host;
  @override
  String get name;
  @override
  String get id;
  @override
  String get type;
  @override
  String? get encoding;
  @override
  int get ap;

  /// Create a copy of Perm
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PermImplCopyWith<_$PermImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
