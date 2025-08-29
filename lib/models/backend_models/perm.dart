// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
part 'perm.freezed.dart';
part 'perm.g.dart';

@freezed
class Perm with _$Perm {
  const factory Perm({
    required String permtype,
    String? uname,
    String? pass,
    @JsonKey(fromJson: _portFromJson, toJson: _portToJson) int? port,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'passive_mode') bool? passiveMode,
    String? host,
    required String name,
    required String id,
    required String type,
    String? encoding,
    required int ap,
  }) = _Perm;

  factory Perm.fromJson(Map<String, dynamic> json) => _$PermFromJson(json);
}

// Port için özel converter fonksiyonları
int? _portFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

dynamic _portToJson(int? value) => value;
