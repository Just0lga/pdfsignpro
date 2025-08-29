import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pdfsignpro/services/preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backend_models/full_response.dart';
import '../models/backend_models/perm.dart';

class AuthService {
  static const String baseUrl = "http://78.187.11.150:9092/"; // Port düzeltildi

  // Cache'de saklanan son başarılı giriş bilgileri
  static const String _lastSuccessfulUsernameKey = 'last_successful_username';
  static const String _lastSuccessfulPasswordHashKey =
      'last_successful_password_hash';

  //✅ Klasik login bu
  static Future<FullResponse?> login({
    required String username,
    required String hashedPassword, // İşlenmiş şifre geliyor
    bool useCache = true,
    bool isAutoLogin = false,
  }) async {
    print('🔑 İşlenmiş şifre: $hashedPassword');

    if (useCache) {
      final cachedResponse = await _tryLoginWithCache(username, hashedPassword);
      if (cachedResponse != null) {
        return cachedResponse;
      }
    }

    try {
      final uri = Uri.parse("$baseUrl/full/login");

      final body = jsonEncode({
        "username": username,
        "passwordHash": hashedPassword,
      });

      print('🔗 API isteği: $uri');
      print('📦 Body: $body');

      // Düzeltilmiş timeout - AutoLogin için daha uzun
      final timeoutDuration = isAutoLogin
          ? Duration(seconds: 8) // AutoLogin için uzun timeout
          : Duration(seconds: 10); // Manuel login için orta timeout

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(timeoutDuration);

      print('📡 Response Status: ${response.statusCode}');

      // Response body'yi log et ama sadece başlangıç kısmını
      final responseBodyPreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      print('📄 Response Body: $responseBodyPreview');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Başarı kontrolü - perList varsa başarılı sayıyoruz
        if (data["success"] == true || data["perList"] != null) {
          print(
              '✅ Login başarılı, ${data["perList"]?.length ?? 0} izin bulundu');

          // Port string'i int'e çevir
          if (data["perList"] is List) {
            for (var perm in data["perList"]) {
              if (perm is Map<String, dynamic> && perm["port"] is String) {
                perm["port"] = int.tryParse(perm["port"]) ?? 21;
              }
            }
          }

          // success field eksikse manuel ekleme
          if (data["success"] == null && data["perList"] != null) {
            data["success"] = true;
          }

          // userId field eksikse manuel ekleme
          if (data["userId"] == null) {
            // perList'ten ilk user_id'yi al
            if (data["perList"] is List && data["perList"].isNotEmpty) {
              final firstPerm = data["perList"][0];
              if (firstPerm is Map<String, dynamic> &&
                  firstPerm["user_id"] != null) {
                data["userId"] = firstPerm["user_id"];
              } else {
                data["userId"] = username; // Fallback
              }
            } else {
              data["userId"] = username; // Fallback
            }
          }

          final fullResponse = FullResponse.fromJson(data);

          // Başarılı giriş bilgilerini kaydet
          await _saveSuccessfulLoginCredentials(username, hashedPassword);

          // Cache'e kaydet
          await PreferencesService.cacheFullResponse(fullResponse);
          print(
              '💾 API Response cache\'lendi: ${fullResponse.perList.length} izin');

          return fullResponse;
        } else {
          throw Exception(data["message"] ?? "Giriş başarısız");
        }
      } else if (response.statusCode == 401) {
        throw Exception("Kullanıcı adı veya şifre hatalı");
      } else if (response.statusCode == 500) {
        throw Exception("Sunucu hatası");
      } else {
        throw Exception("HTTP hatası: ${response.statusCode}");
      }
    } on SocketException catch (e) {
      print('❌ Network Error: $e');
      throw Exception("İnternet bağlantısı hatası");
    } on HttpException catch (e) {
      print('❌ HTTP Error: $e');
      throw Exception("Sunucu bağlantı hatası");
    } catch (e) {
      print('❌ API Error: $e');

      if (useCache) {
        print('🔄 API başarısız, cache\'den deneniyor...');
        final cachedResponse =
            await _tryLoginWithCache(username, hashedPassword);
        if (cachedResponse != null) {
          print('✅ Cache\'den giriş başarılı');
          return cachedResponse;
        }
      }

      rethrow;
    }
  }

  //✅ Login retry: Eğer ilk deneme başarısız olursa tekrar deniyor
  static Future<FullResponse?> loginWithRetry({
    required String username,
    required String password,
    int maxRetries = 3,
    bool isAutoLogin = false,
  }) async {
    Exception? lastException;

    print('LoginWithRetry başladı:');
    print('  Username: $username');
    print('  Password uzunluk: ${password.length}');
    print('  Max retry: $maxRetries');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('API Deneme $attempt/$maxRetries');
        // ... mevcut kod devam eder

        final result = await login(
          username: username,
          hashedPassword: password,
          useCache: false, // Retry'da cache kullanma
          isAutoLogin: isAutoLogin,
        );

        if (result != null) {
          print('✅ API Deneme $attempt başarılı');
          return result;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('❌ API Deneme $attempt başarısız: $e');

        if (attempt == maxRetries) {
          break; // Son deneme, exception'ı fırlat
        }

        // Deneme arasında bekleme (exponential backoff)
        await Future.delayed(Duration(seconds: 1));
      }
    }

    // Tüm denemeler başarısız
    if (lastException != null) {
      throw lastException;
    }

    return null;
  }

  //✅ Login gerçekleştiyse username ve hashli passwordu tutuyor
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

  //✅ Apiye erişilemediği durumda cacheden gelen bilgilerle login denemesi yapar
  static Future<FullResponse?> _tryLoginWithCache(
      String username, String passwordHash) async {
    try {
      final hasCache = await PreferencesService.hasCache();

      if (!hasCache) {
        print('❌ Cache yok');
        return null;
      }

      // Kullanıcı bilgilerini kontrol et
      final prefs = await SharedPreferences.getInstance();
      final lastUsername = prefs.getString(_lastSuccessfulUsernameKey);
      final lastPasswordHash = prefs.getString(_lastSuccessfulPasswordHashKey);

      print('🔍 Cache giriş kontrolü:');
      print('   Gelen username: "$username"');
      print('   Cache\'deki username: "$lastUsername"');
      print('   Password hash eşleşiyor: ${passwordHash == lastPasswordHash}');

      // Username ve password hash kontrol et
      if (lastUsername != username) {
        print('❌ Username eşleşmiyor - cache girişi reddedildi');
        return null;
      }

      if (lastPasswordHash != passwordHash) {
        print('❌ Password hash eşleşmiyor - cache girişi reddedildi');
        return null;
      }

      // Bilgiler eşleşiyorsa cache'den response al
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

  //✅ Tüm ftp izinleri
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

  //😡 Silinebilir sanırım ilk izni dönüyor
  static Perm? getFirstValidFtpPermission(FullResponse response) {
    final ftpPerms = getFtpPermissions(response);
    return ftpPerms.isNotEmpty ? ftpPerms.first : null;
  }

  //✅ Silinemez, isimle ftp sunucusunu buluyor
  static Perm? getFtpPermissionByName(FullResponse response, String name) {
    return getFtpPermissions(response).cast<Perm?>().firstWhere(
          (perm) => perm?.name == name,
          orElse: () => null,
        );
  }

  //✅ Silinemez, cachete veri var mı kontrol eder, son giriş yapan kullanıcının bilgisini döner
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

  //✅ Silinemez, cache yenilemek için var
  static Future<bool> refreshCache(String username, String password) async {
    try {
      print('🔄 Cache yenileniyor...');
      final response = await login(
        username: username,
        hashedPassword: password,
        useCache: false,
        isAutoLogin: false,
      );
      return response != null;
    } catch (e) {
      print('❌ Cache yenileme hatası: $e');
      return false;
    }
  }

  //✅ Silinemez, cache temizlerken giriş bilgilerini de temizliyor
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

  //✅ Silinemez, cache durumunu konsola yazdırır, tester için gerekli bir fonksiyon
  static Future<void> debugCacheStatus() async {
    try {
      final status = await getCacheStatus();
      final prefs = await SharedPreferences.getInstance();
      final lastPasswordHash = prefs.getString(_lastSuccessfulPasswordHashKey);

      print('🔍 AUTH SERVICE Debug:');
      print('   Cache var: ${status['hasCache']}');
      print('   Credentials var: ${status['hasCredentials']}');
      print('   Son username: ${status['lastUsername']}');
      if (lastPasswordHash != null) {
        print('   Son password hash: ${lastPasswordHash.substring(0, 10)}...');
      }

      final cachedResponse = await PreferencesService.getCachedFullResponse();
      if (cachedResponse != null) {
        print('   Cache\'deki userId: ${cachedResponse.userId}');
        print('   Cache\'deki izin sayısı: ${cachedResponse.perList.length}');
      }
    } catch (e) {
      print('❌ Debug hatası: $e');
    }
  }

  //✅ Silinemez, yarın bir gün test için kullanılabilir
  static Future<bool> testConnection() async {
    try {
      final uri = Uri.parse("$baseUrl/full/login");

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "username": "test_connection",
              "passwordHash": "test_hash",
            }),
          )
          .timeout(Duration(seconds: 3));

      // 200-499 arası response gelirse sunucu erişilebilir
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      print('❌ Bağlantı testi başarısız: $e');
      return false;
    }
  }
}
