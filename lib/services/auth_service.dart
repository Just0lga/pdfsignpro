import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pdfsignpro/services/preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backend_models/full_response.dart';
import '../models/backend_models/perm.dart';

class AuthService {
  static const String baseUrl = "http://192.168.2.77:9090"; // Test API URL'iniz

  // 🔒 Cache'de saklanan son başarılı giriş bilgileri
  static const String _lastSuccessfulUsernameKey = 'last_successful_username';
  static const String _lastSuccessfulPasswordHashKey =
      'last_successful_password_hash';

  static Future<FullResponse?> login({
    required String username,
    required String
        password, // 🔥 Bu artık işlenmiş şifre geliyor (rawPassword + "pdfSignPro2024!@")
    bool useCache = true,
  }) async {
    // 🔥 ÇÖZÜM: Gelen şifre zaten işlenmiş, sadece SHA256 hash yapılacak
    final bytes = utf8.encode(password); // string -> byte
    final hash = sha256.convert(bytes).toString();

    print('🔑 İşlenmiş şifre: $password');
    print('🔒 SHA256 hash: $hash');

    if (useCache) {
      final cachedResponse = await _tryLoginWithCache(username, hash);
      if (cachedResponse != null) {
        return cachedResponse;
      }
    }

    try {
      final uri = Uri.parse("$baseUrl/full/login");

      final body = jsonEncode({
        "username": username,
        "passwordHash": hash,
      });

      print('🔗 API isteği: $uri');
      print('📦 Body: $body');

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(Duration(seconds: 10));

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          print(
              '✅ Login başarılı, ${data["perList"]?.length ?? 0} izin bulundu');

          if (data["perList"] is List) {
            for (var perm in data["perList"]) {
              if (perm is Map<String, dynamic> && perm["port"] is String) {
                perm["port"] = int.tryParse(perm["port"]) ?? 21;
              }
            }
          }

          final fullResponse = FullResponse.fromJson(data);

          // 🔥 Başarılı giriş bilgilerini kaydet
          await _saveSuccessfulLoginCredentials(username, hash);

          await PreferencesService.cacheFullResponse(fullResponse);
          print('💾 API yanıtı cache\'lendi');

          return fullResponse;
        } else {
          throw Exception(data["message"] ?? "Giriş başarısız");
        }
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      print('❌ API Error: $e');

      if (useCache) {
        print('🔄 API başarısız, cache\'den deneniyor...');
        final cachedResponse = await _tryLoginWithCache(username, hash);
        if (cachedResponse != null) {
          print('✅ Cache\'den giriş başarılı');
          return cachedResponse;
        }
      }

      rethrow;
    }
  }

  // 🔥 Başarılı giriş bilgilerini kaydet
  static Future<void> _saveSuccessfulLoginCredentials(
      String username, String passwordHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSuccessfulUsernameKey, username);
      await prefs.setString(_lastSuccessfulPasswordHashKey, passwordHash);
      print('🔒 Başarılı giriş bilgileri kaydedildi');
    } catch (e) {
      print('❌ Giriş bilgileri kaydetme hatası: $e');
    }
  }

  // 🔥 Cache'den login deneme - GELİŞTİRİLMİŞ
  static Future<FullResponse?> _tryLoginWithCache(
      String username, String passwordHash) async {
    try {
      final hasCache = await PreferencesService.hasCache();

      if (!hasCache) {
        print('❌ Cache yok');
        return null;
      }

      // 🔥 Kullanıcı bilgilerini kontrol et
      final prefs = await SharedPreferences.getInstance();
      final lastUsername = prefs.getString(_lastSuccessfulUsernameKey);
      final lastPasswordHash = prefs.getString(_lastSuccessfulPasswordHashKey);

      print('🔍 Cache giriş kontrolü:');
      print('   Gelen username: "$username"');
      print('   Cache\'deki username: "$lastUsername"');
      print('   Password hash eşleşiyor: ${passwordHash == lastPasswordHash}');

      // 🔥 Username ve password hash kontrol et
      if (lastUsername != username) {
        print('❌ Username eşleşmiyor - cache girişi reddedildi');
        return null;
      }

      if (lastPasswordHash != passwordHash) {
        print('❌ Password hash eşleşmiyor - cache girişi reddedildi');
        return null;
      }

      // 🔥 Bilgiler eşleşiyorsa cache'den response al
      final cachedResponse = await PreferencesService.getCachedFullResponse();

      if (cachedResponse != null) {
        if (cachedResponse.userId.isNotEmpty) {
          print(
              '✅ Cache\'den giriş BAŞARILI: ${cachedResponse.perList.length} izin');
          print('   Username: $username');
          print('   Cache\'deki userId: ${cachedResponse.userId}');
          return cachedResponse;
        }
      }

      print('❌ Cache\'de geçerli response bulunamadı');
    } catch (e) {
      print('❌ Cache login hatası: $e');
    }

    return null;
  }

  /// FTP izinlerini filtrele
  static List<Perm> getFtpPermissions(FullResponse response) {
    return response.perList
        .where((perm) =>
            perm.permtype == 'ftp' &&
            perm.ap == 1 &&
            perm.host != null &&
            perm.host!.isNotEmpty &&
            perm.uname != null &&
            perm.uname!.isNotEmpty &&
            perm.pass != null &&
            perm.pass!.isNotEmpty)
        .toList();
  }

  static Perm? getFirstValidFtpPermission(FullResponse response) {
    final ftpPerms = getFtpPermissions(response);
    return ftpPerms.isNotEmpty ? ftpPerms.first : null;
  }

  static Perm? getFtpPermissionByName(FullResponse response, String name) {
    return getFtpPermissions(response).cast<Perm?>().firstWhere(
          (perm) => perm?.name == name,
          orElse: () => null,
        );
  }

  static Future<Map<String, dynamic>> getCacheStatus() async {
    final hasCache = await PreferencesService.hasCache();

    // Cache'deki kullanıcı bilgilerini de kontrol et
    final prefs = await SharedPreferences.getInstance();
    final lastUsername = prefs.getString(_lastSuccessfulUsernameKey);
    final hasCredentials = lastUsername != null;

    return {
      'hasCache': hasCache,
      'hasCredentials': hasCredentials,
      'lastUsername': lastUsername,
      'source': hasCache ? 'cache' : 'api',
    };
  }

  static Future<bool> refreshCache(String username, String password) async {
    try {
      print('🔄 Cache yenileniyor...');
      final response =
          await login(username: username, password: password, useCache: false);
      return response != null;
    } catch (e) {
      print('❌ Cache yenileme hatası: $e');
      return false;
    }
  }

  // 🔥 Cache temizlerken giriş bilgilerini de temizle
  static Future<void> clearCacheAndCredentials() async {
    try {
      await PreferencesService.clearCache();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSuccessfulUsernameKey);
      await prefs.remove(_lastSuccessfulPasswordHashKey);

      print('🗑️ Cache ve giriş bilgileri temizlendi');
    } catch (e) {
      print('❌ Cache temizleme hatası: $e');
    }
  }

  // 🔥 Debug: Cache durumunu detaylı göster
  static Future<void> debugCacheStatus() async {
    try {
      final status = await getCacheStatus();
      final prefs = await SharedPreferences.getInstance();
      final lastPasswordHash = prefs.getString(_lastSuccessfulPasswordHashKey);

      print('🔍 AUTH SERVICE Debug:');
      print('   Cache var: ${status['hasCache']}');
      print('   Credentials var: ${status['hasCredentials']}');
      print('   Son username: ${status['lastUsername']}');
      print('   Son password hash: ${lastPasswordHash?.substring(0, 10)}...');

      final cachedResponse = await PreferencesService.getCachedFullResponse();
      if (cachedResponse != null) {
        print('   Cache\'deki userId: ${cachedResponse.userId}');
        print('   Cache\'deki izin sayısı: ${cachedResponse.perList.length}');
      }
    } catch (e) {
      print('❌ Debug hatası: $e');
    }
  }
}
