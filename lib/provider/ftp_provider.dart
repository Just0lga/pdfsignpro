import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/services/auth_service.dart';
import '../models/backend_models/perm.dart';
import '../provider/auth_provider.dart';
import '../services/ftp_pdf_loader.dart';
import '../models/frontend_models/ftp_file.dart';

// Aktif FTP bağlantısı seçici provider
final selectedFtpConnectionProvider = StateProvider<Perm?>((ref) {
  return null; // Varsayılan olarak hiçbir sunucu seçili değil
});

// Tüm FTP izinleri (dolu olsun olmasın) - seçim ekranı için
final allFtpPermissionsProvider = Provider<List<Perm>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.fullResponse == null) return [];

  return authState.fullResponse!.perList
      .where((perm) => perm.permtype == 'ftp' && perm.ap == 1)
      .toList();
});

// Sadece dolu FTP izinleri - eski provider
final ftpPermissionsProvider = Provider<List<Perm>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.fullResponse == null) return [];
  return AuthService.getFtpPermissions(authState.fullResponse!);
});

// FTP dosyaları provider - seçili bağlantıya göre
final ftpFilesProvider = FutureProvider<List<FtpFile>>((ref) async {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);

  if (selectedConnection == null ||
      selectedConnection.host == null ||
      selectedConnection.uname == null ||
      selectedConnection.pass == null) {
    return [];
  }

  try {
    return await FtpPdfLoader.listPdfFiles(
      host: selectedConnection.host!,
      username: selectedConnection.uname!,
      password: selectedConnection.pass!,
      directory: '/',
      port: selectedConnection.port ?? 9093,
    );
  } catch (e) {
    print('FTP dosya listesi hatası: $e');
    throw Exception('FTP bağlantısı kurulamadı: $e');
  }
});

// FTP bağlantı durumu provider
final ftpConnectionStatusProvider = Provider<FtpConnectionStatus>((ref) {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);
  final authState = ref.watch(authProvider);

  if (!authState.isLoggedIn) {
    return FtpConnectionStatus.notLoggedIn;
  }

  if (selectedConnection == null) {
    return FtpConnectionStatus.noPermission;
  }

  if (selectedConnection.host == null ||
      selectedConnection.uname == null ||
      selectedConnection.pass == null) {
    return FtpConnectionStatus.incompleteConfig;
  }

  return FtpConnectionStatus.ready;
});

// FTP bağlantı durumu enum
enum FtpConnectionStatus {
  notLoggedIn,
  noPermission,
  incompleteConfig,
  ready,
}

// FTP bağlantı detayları provider
final ftpConnectionDetailsProvider = Provider<FtpConnectionDetails?>((ref) {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);

  if (selectedConnection == null) return null;

  return FtpConnectionDetails(
    name: selectedConnection.name,
    host: selectedConnection.host ?? '',
    username: selectedConnection.uname ?? '',
    password: selectedConnection.pass ?? '',
    port: FtpConnectionDetails._parsePort(selectedConnection.port),
    encoding: selectedConnection.encoding,
    isPassiveMode: selectedConnection.passiveMode ?? false,
  );
});

// FTP bağlantı detayları model
class FtpConnectionDetails {
  final String name;
  final String host;
  final String username;
  final String password;
  final int port;
  final String? encoding;
  final bool isPassiveMode;

  FtpConnectionDetails({
    required this.name,
    required this.host,
    required this.username,
    required this.password,
    required this.port,
    this.encoding,
    required this.isPassiveMode,
  });

  bool get isValid =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  // Port'u güvenli şekilde int'e çevir
  static int _parsePort(dynamic portValue) {
    if (portValue == null) return 9093;
    if (portValue is int) return portValue;
    if (portValue is String) {
      return int.tryParse(portValue) ?? 9093;
    }
    return 9093;
  }
}
