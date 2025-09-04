// ftp_provider.dart güncellemesi

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/services/auth_service.dart';
import '../models/backend_models/perm.dart';
import 'auth_provider.dart';
import '../services/ftp_pdf_loader_service.dart';
import '../models/frontend_models/ftp_file.dart';

// Aktif FTP bağlantısı seçici provider
final selectedFtpConnectionProvider = StateProvider<Perm?>((ref) {
  return null;
});

// ✅ YENİ: Geçici credentials provider
final temporaryFtpCredentialsProvider =
    StateProvider<Map<String, String>?>((ref) {
  return null; // {username: ..., password: ...}
});

// ✅ YENİ: Birleştirilmiş FTP credentials provider
final activeFtpCredentialsProvider = Provider<Map<String, String>?>((ref) {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);
  final tempCredentials = ref.watch(temporaryFtpCredentialsProvider);

  if (selectedConnection == null) return null;

  // Geçici credentials varsa onları kullan, yoksa connection'daki bilgileri kullan
  return {
    'host': selectedConnection.host ?? '',
    'port': (selectedConnection.port ?? 21).toString(),
    'username': tempCredentials?['username'] ?? selectedConnection.uname ?? '',
    'password': tempCredentials?['password'] ?? selectedConnection.pass ?? '',
  };
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
  final credentials = ref.watch(activeFtpCredentialsProvider);

  if (credentials == null ||
      credentials['host']!.isEmpty ||
      credentials['username']!.isEmpty ||
      credentials['password']!.isEmpty) {
    return [];
  }

  try {
    return await FtpPdfLoaderService.listPdfFiles(
      host: credentials['host']!,
      username: credentials['username']!,
      password: credentials['password']!,
      directory: '/',
      port: int.tryParse(credentials['port']!) ?? 21,
    );
  } catch (e) {
    print('FTP dosya listesi hatası: $e');
    throw Exception('FTP bağlantısı kurulamadı: $e');
  }
});

// FTP bağlantı durumu provider
final ftpConnectionStatusProvider = Provider<FtpConnectionStatus>((ref) {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);
  final credentials = ref.watch(activeFtpCredentialsProvider);
  final authState = ref.watch(authProvider);

  if (!authState.isLoggedIn) {
    return FtpConnectionStatus.notLoggedIn;
  }

  if (selectedConnection == null) {
    return FtpConnectionStatus.noPermission;
  }

  if (credentials == null ||
      credentials['username']!.isEmpty ||
      credentials['password']!.isEmpty) {
    return FtpConnectionStatus.incompleteConfig;
  }

  return FtpConnectionStatus.ready;
});

// FTP bağlantı durumu enum
enum FtpConnectionStatus { notLoggedIn, noPermission, incompleteConfig, ready }

// FTP bağlantı detayları provider - ✅ GÜNCELLENDİ
final ftpConnectionDetailsProvider = Provider<FtpConnectionDetails?>((ref) {
  final selectedConnection = ref.watch(selectedFtpConnectionProvider);
  final credentials = ref.watch(activeFtpCredentialsProvider);

  if (selectedConnection == null || credentials == null) return null;

  return FtpConnectionDetails(
    name: selectedConnection.name,
    host: credentials['host']!,
    username: credentials['username']!,
    password: credentials['password']!,
    port: int.tryParse(credentials['port']!) ?? 21,
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
    if (portValue == null) return 21;
    if (portValue is int) return portValue;
    if (portValue is String) {
      return int.tryParse(portValue) ?? 21;
    }
    return 21;
  }
}
