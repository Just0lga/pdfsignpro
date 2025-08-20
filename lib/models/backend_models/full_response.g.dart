// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'full_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FullResponseImpl _$$FullResponseImplFromJson(Map<String, dynamic> json) =>
    _$FullResponseImpl(
      perList: (json['perList'] as List<dynamic>)
          .map((e) => Perm.fromJson(e as Map<String, dynamic>))
          .toList(),
      success: json['success'] as bool,
      userId: json['userId'] as String,
    );

Map<String, dynamic> _$$FullResponseImplToJson(_$FullResponseImpl instance) =>
    <String, dynamic>{
      'perList': instance.perList,
      'success': instance.success,
      'userId': instance.userId,
    };
