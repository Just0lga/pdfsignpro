import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/frontend_models/ftp_file.dart';

class CacheManager {
  static const String _ftpFilesCacheKey = 'ftp_files_cache';
  static const String _lastUpdateKey = 'ftp_last_update';
  static const String _permissionsCacheKey = 'permissions_cache';
  static const String _permissionsLastUpdateKey = 'permissions_last_update';

  // Cache süresi (5 dakika)
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// FTP dosya listesini cache'e kaydet
  static Future<void> cacheFtpFiles(List<FtpFile> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Dosyaları JSON formatına çevir
      final filesJson = files
          .map((file) => {
                'name': file.name,
                'size': file.size,
                'path': file.path,
                'modifyTime': file.modifyTime?.millisecondsSinceEpoch,
              })
          .toList();

      await prefs.setString(_ftpFilesCacheKey, jsonEncode(filesJson));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print('✅ FTP dosyaları cache\'e kaydedildi: ${files.length} dosya');
    } catch (e) {
      print('❌ Cache kaydetme hatası: $e');
    }
  }

  /// Cache'den FTP dosya listesini al
  static Future<List<FtpFile>?> getCachedFtpFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache süresi kontrolü
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      if (lastUpdate == null) {
        print('📦 FTP Cache bulunamadı');
        return null;
      }

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      if (now.difference(lastUpdateTime) > _cacheExpiration) {
        print(
            '⏰ FTP Cache süresi dolmuş (${now.difference(lastUpdateTime).inMinutes} dakika önce)');
        await clearFtpCache();
        return null;
      }

      // Cache'den veri al
      final cachedData = prefs.getString(_ftpFilesCacheKey);
      if (cachedData == null) {
        print('📦 FTP Cache verisi bulunamadı');
        return null;
      }

      final List<dynamic> filesJson = jsonDecode(cachedData);
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

      print('✅ Cache\'den ${files.length} FTP dosyası alındı');
      return files;
    } catch (e) {
      print('❌ FTP Cache okuma hatası: $e');
      await clearFtpCache();
      return null;
    }
  }

  /// İzinleri cache'e kaydet
  static Future<void> cachePermissions(dynamic permissions) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_permissionsCacheKey, jsonEncode(permissions));
      await prefs.setInt(
          _permissionsLastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print('✅ İzinler cache\'e kaydedildi');
    } catch (e) {
      print('❌ İzin cache kaydetme hatası: $e');
    }
  }

  /// Cache'den izinleri al
  static Future<dynamic> getCachedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache süresi kontrolü
      final lastUpdate = prefs.getInt(_permissionsLastUpdateKey);
      if (lastUpdate == null) {
        print('📦 İzin cache\'i bulunamadı');
        return null;
      }

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      if (now.difference(lastUpdateTime) > _cacheExpiration) {
        print('⏰ İzin cache süresi dolmuş');
        await clearPermissionsCache();
        return null;
      }

      final cachedData = prefs.getString(_permissionsCacheKey);
      if (cachedData == null) {
        print('📦 İzin cache verisi bulunamadı');
        return null;
      }

      final permissions = jsonDecode(cachedData);
      print('✅ Cache\'den izinler alındı');
      return permissions;
    } catch (e) {
      print('❌ İzin cache okuma hatası: $e');
      await clearPermissionsCache();
      return null;
    }
  }

  /// FTP cache'ini temizle
  static Future<void> clearFtpCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ftpFilesCacheKey);
      await prefs.remove(_lastUpdateKey);
      print('🗑️ FTP cache temizlendi');
    } catch (e) {
      print('❌ FTP Cache temizleme hatası: $e');
    }
  }

  /// İzin cache'ini temizle
  static Future<void> clearPermissionsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_permissionsCacheKey);
      await prefs.remove(_permissionsLastUpdateKey);
      print('🗑️ İzin cache temizlendi');
    } catch (e) {
      print('❌ İzin cache temizleme hatası: $e');
    }
  }

  /// Tüm cache'i temizle
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('🗑️ TÜM cache temizlendi');
    } catch (e) {
      print('❌ Tüm cache temizleme hatası: $e');
    }
  }

  /// Cache durumunu kontrol et
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final ftpLastUpdate = prefs.getInt(_lastUpdateKey);
      final permLastUpdate = prefs.getInt(_permissionsLastUpdateKey);

      return {
        'ftpCacheExists': ftpLastUpdate != null,
        'ftpCacheAge': ftpLastUpdate != null
            ? DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(ftpLastUpdate))
            : null,
        'permissionsCacheExists': permLastUpdate != null,
        'permissionsCacheAge': permLastUpdate != null
            ? DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(permLastUpdate))
            : null,
      };
    } catch (e) {
      print('❌ Cache durum kontrolü hatası: $e');
      return {};
    }
  }

  /// Cache bilgilerini debug için yazdır
  static Future<void> debugCacheInfo() async {
    try {
      final status = await getCacheStatus();
      print('🔍 Cache Debug Bilgisi:');
      print('   FTP Cache Var: ${status['ftpCacheExists']}');
      if (status['ftpCacheAge'] != null) {
        final age = status['ftpCacheAge'] as Duration;
        print(
            '   FTP Cache Yaşı: ${age.inMinutes} dakika ${age.inSeconds % 60} saniye');
      }
      print('   İzin Cache Var: ${status['permissionsCacheExists']}');
      if (status['permissionsCacheAge'] != null) {
        final age = status['permissionsCacheAge'] as Duration;
        print(
            '   İzin Cache Yaşı: ${age.inMinutes} dakika ${age.inSeconds % 60} saniye');
      }
    } catch (e) {
      print('❌ Cache debug hatası: $e');
    }
  }

  /// Akıllı cache yenileme - sadece gerektiğinde yeniler
  static Future<bool> shouldRefreshCache(String cacheType) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String lastUpdateKey;
      switch (cacheType) {
        case 'ftp':
          lastUpdateKey = _lastUpdateKey;
          break;
        case 'permissions':
          lastUpdateKey = _permissionsLastUpdateKey;
          break;
        default:
          return true;
      }

      final lastUpdate = prefs.getInt(lastUpdateKey);
      if (lastUpdate == null) return true;

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      final shouldRefresh = now.difference(lastUpdateTime) > _cacheExpiration;

      if (shouldRefresh) {
        print('🔄 Cache yenileme gerekli ($cacheType)');
      } else {
        print('✅ Cache güncel ($cacheType)');
      }

      return shouldRefresh;
    } catch (e) {
      print('❌ Cache kontrol hatası: $e');
      return true;
    }
  }

  /// Manuel cache temizleme - debug için
  static Future<void> forceClearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('🔍 Mevcut cache anahtarları: ${keys.toList()}');

      for (String key in keys) {
        await prefs.remove(key);
      }

      print('🗑️ ${keys.length} cache anahtarı temizlendi');
    } catch (e) {
      print('❌ Manuel cache temizleme hatası: $e');
    }
  }
}
