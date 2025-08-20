import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pdfsignpro/models/backend_models/perm.dart';

part 'full_response.freezed.dart';
part 'full_response.g.dart';

@freezed
class FullResponse with _$FullResponse {
  const factory FullResponse({
    required List<Perm> perList,
    required bool success,
    required String userId,
  }) = _FullResponse;

  factory FullResponse.fromJson(Map<String, dynamic> json) =>
      _$FullResponseFromJson(json);
}
