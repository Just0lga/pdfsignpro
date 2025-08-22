// Asset izinleri provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/models/backend_models/perm.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';

final assetPermissionsProvider = Provider<List<Perm>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.fullResponse == null) return [];

  return authState.fullResponse!.perList
      .where((perm) => perm.type == 'asset' && perm.ap == 1)
      .toList();
});
