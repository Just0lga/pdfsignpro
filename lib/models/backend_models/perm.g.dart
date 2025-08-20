// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perm.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PermImpl _$$PermImplFromJson(Map<String, dynamic> json) => _$PermImpl(
      permtype: json['permtype'] as String,
      uname: json['uname'] as String?,
      pass: json['pass'] as String?,
      port: _portFromJson(json['port']),
      userId: json['user_id'] as String,
      passiveMode: json['passive_mode'] as bool?,
      host: json['host'] as String?,
      name: json['name'] as String,
      id: json['id'] as String,
      type: json['type'] as String,
      encoding: json['encoding'] as String?,
      ap: (json['ap'] as num).toInt(),
    );

Map<String, dynamic> _$$PermImplToJson(_$PermImpl instance) =>
    <String, dynamic>{
      'permtype': instance.permtype,
      'uname': instance.uname,
      'pass': instance.pass,
      'port': _portToJson(instance.port),
      'user_id': instance.userId,
      'passive_mode': instance.passiveMode,
      'host': instance.host,
      'name': instance.name,
      'id': instance.id,
      'type': instance.type,
      'encoding': instance.encoding,
      'ap': instance.ap,
    };
