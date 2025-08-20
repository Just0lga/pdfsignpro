// services/unified_cache_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/frontend_models/ftp_file.dart';
import '../models/backend_models/full_response.dart';

class UnifiedCacheManager {
  // Auth cache keys
  static const String _authCacheKey = 'auth_full_response';
  static const String _authTimestampKey = 'auth_timestamp';

  // FTP cache keys - sunucu bazlı
  static const String _ftpCachePrefix = 'ftp_files_';
  static const String _ftpTimestampPrefix = 'ftp_timestamp_';

  // Cache süreleri
  static const Duration _authCacheExpiration = Duration(hours: 24);
  static const Duration _ftpCacheExpiration = Duration(minutes: 5);

  /// ====== AUTH CACHE METHODS ======

  /// API response'unu cache'le
  static Future<void> cacheAuthResponse(FullResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authCacheKey, jsonEncode(response.toJson()));
      await prefs.setInt(
          _authTimestampKey, DateTime.now().millisecondsSinceEpoch);
      print('💾 Auth response cache\'lendi: ${response.perList.length} izin');
    } catch (e) {
      print('❌ Auth cache kaydetme hatası: $e');
    }
  }

  /// Cached auth response'unu al
  static Future<FullResponse?> getCachedAuthResponse() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Timestamp kontrolü
      final timestamp = prefs.getInt(_authTimestampKey);
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _authCacheExpiration) {
        print('⏰ Auth cache süresi dolmuş');
        await clearAuthCache();
        return null;
      }

      // Data'yı al
      final jsonString = prefs.getString(_authCacheKey);
      if (jsonString == null) return null;

      final response = FullResponse.fromJson(jsonDecode(jsonString));
      print('📦 Auth cache\'den alındı: ${response.perList.length} izin');
      return response;
    } catch (e) {
      print('❌ Auth cache okuma hatası: $e');
      await clearAuthCache();
      return null;
    }
  }

  /// Auth cache'ini temizle
  static Future<void> clearAuthCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authCacheKey);
    await prefs.remove(_authTimestampKey);
    print('🗑️ Auth cache temizlendi');
  }

  /// ====== FTP CACHE METHODS ======

  /// FTP dosyalarını sunucu bazlı cache'le
  static Future<void> cacheFtpFiles(
      String serverKey, List<FtpFile> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final filesJson = files
          .map((file) => {
                'name': file.name,
                'size': file.size,
                'path': file.path,
                'modifyTime': file.modifyTime?.millisecondsSinceEpoch,
              })
          .toList();

      await prefs.setString(
          '$_ftpCachePrefix$serverKey', jsonEncode(filesJson));
      await prefs.setInt('$_ftpTimestampPrefix$serverKey',
          DateTime.now().millisecondsSinceEpoch);

      print('💾 FTP cache kaydedildi [$serverKey]: ${files.length} dosya');
    } catch (e) {
      print('❌ FTP cache kaydetme hatası: $e');
    }
  }

  /// FTP cache'den dosyaları al
  static Future<List<FtpFile>?> getCachedFtpFiles(String serverKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Timestamp kontrolü
      final timestamp = prefs.getInt('$_ftpTimestampPrefix$serverKey');
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _ftpCacheExpiration) {
        print('⏰ FTP cache süresi dolmuş [$serverKey]');
        await clearFtpCache(serverKey);
        return null;
      }

      // Data'yı al
      final jsonString = prefs.getString('$_ftpCachePrefix$serverKey');
      if (jsonString == null) return null;

      final List<dynamic> filesJson = jsonDecode(jsonString);
      final files = filesJson
          .map((json) => FtpFile(
                name: json['name'] as String,
                size: json['size'] as int,
                path: json['path'] as String,
                modifyTime: json['modifyTime'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                        json['modifyTime'] as int)
                    : null,
              ))
          .toList();

      print('📦 FTP cache\'den alındı [$serverKey]: ${files.length} dosya');
      return files;
    } catch (e) {
      print('❌ FTP cache okuma hatası: $e');
      await clearFtpCache(serverKey);
      return null;
    }
  }

  /// Belirli sunucunun FTP cache'ini temizle
  static Future<void> clearFtpCache(String serverKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_ftpCachePrefix$serverKey');
    await prefs.remove('$_ftpTimestampPrefix$serverKey');
    print('🗑️ FTP cache temizlendi [$serverKey]');
  }

  /// ====== UNIFIED METHODS ======

  /// Server key oluştur (host:port formatında)
  static String createServerKey(String host, int port, String username) {
    return '${host}_${port}_$username'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Tüm cache'leri temizle
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();

    // Tüm anahtarları al
    final keys = prefs.getKeys();

    // Cache anahtarlarını filtrele ve temizle
    for (String key in keys) {
      if (key.startsWith(_authCacheKey) ||
          key.startsWith(_authTimestampKey) ||
          key.startsWith(_ftpCachePrefix) ||
          key.startsWith(_ftpTimestampPrefix)) {
        await prefs.remove(key);
      }
    }

    print('🗑️ TÜM cache temizlendi');
  }

  /// Cache durumunu al
  static Future<Map<String, dynamic>> getCacheStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Auth cache durumu
    final authTimestamp = prefs.getInt(_authTimestampKey);
    final authCacheExists = authTimestamp != null;
    Duration? authAge;
    if (authTimestamp != null) {
      authAge = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(authTimestamp));
    }

    // FTP cache sayısı
    final keys = prefs.getKeys();
    final ftpCacheCount =
        keys.where((k) => k.startsWith(_ftpCachePrefix)).length;

    return {
      'authCacheExists': authCacheExists,
      'authCacheAge': authAge,
      'ftpCacheCount': ftpCacheCount,
      'totalCacheKeys': keys.length,
    };
  }

  /// Smart refresh - sadece gerekirse yenile
  static Future<bool> shouldRefreshAuth() async {
    final authResponse = await getCachedAuthResponse();
    return authResponse == null; // Cache yoksa veya süresi dolmuşsa yenile
  }

  static Future<bool> shouldRefreshFtp(String serverKey) async {
    final ftpFiles = await getCachedFtpFiles(serverKey);
    return ftpFiles == null; // Cache yoksa veya süresi dolmuşsa yenile
  }
}
