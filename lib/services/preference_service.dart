import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/backend_models/full_response.dart';

class PreferencesService {
  static const String _rememberMeKey = 'remember_me';
  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';
  static const String _fullResponseKey = 'cached_full_response';

  // Beni hatırla durumunu kaydet
  static Future<void> setRememberMe(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
  }

  // Beni hatırla durumunu al
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Kullanıcı bilgilerini kaydet - RAW şifre
  static Future<void> saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password); // RAW şifre
    print('💾 RAW şifre kaydedildi: "$password"');
  }

  // Kullanıcı bilgilerini al - RAW şifre
  static Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey); // RAW şifre

    if (password != null) {
      print('📦 RAW şifre okundu: "$password"');
    }

    return {
      'username': username,
      'password': password, // RAW şifre
    };
  }

  // FullResponse'u cache'le (API'den gelen izinler)
  static Future<void> cacheFullResponse(FullResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(response.toJson());
      await prefs.setString(_fullResponseKey, jsonString);

      print('💾 API Response cache\'lendi: ${response.perList.length} izin');
    } catch (e) {
      print('❌ Cache kaydetme hatası: $e');
    }
  }

  // Cache'lenmiş FullResponse'u al
  static Future<FullResponse?> getCachedFullResponse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_fullResponseKey);

      if (jsonString != null) {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final response = FullResponse.fromJson(jsonMap);

        print('📦 Cache\'den response alındı:');
        print('   İzin sayısı: ${response.perList.length}');
        print('   User ID: ${response.userId}');
        for (var perm in response.perList.take(3)) {
          print('   - ${perm.name} (${perm.permtype}) AP:${perm.ap}');
        }
        return response;
      } else {
        print('❌ Cache\'de veri bulunamadı');
      }
    } catch (e) {
      print('❌ Cache okuma hatası: $e');
    }

    return null;
  }

  // Cache var mı kontrol et
  static Future<bool> hasCache() async {
    final cachedResponse = await getCachedFullResponse();
    return cachedResponse != null;
  }

  // Tüm kayıtlı bilgileri temizle (tamamen çıkış)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_fullResponseKey);
    print('🗑️ Tüm veriler temizlendi (cache dahil)');
  }

  // Sadece oturum kapat (cache'i koru, remember me'yi koru)
  static Future<void> clearSessionOnly() async {
    // Hiçbir şey silme, sadece uygulama seviyesinde oturum kapat
    print('📴 Oturum kapatıldı, cache ve remember me korundu');
  }

  // Cache'i manuel olarak temizle (ama remember me'yi koru)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fullResponseKey);
    print('🗑️ Cache temizlendi');
  }

  // Sadece credentials'ları temizle, cache'i koru
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    print('🔄 Credentials temizlendi, cache korundu');
  }

  // Debug: Cache bilgilerini göster
  static Future<void> debugCacheInfo() async {
    try {
      final hasCache = await getCachedFullResponse() != null;
      final credentials = await getCredentials();

      print('🔍 PREFERENCES DEBUG:');
      print('   Cache var: $hasCache');
      print('   Username var: ${credentials['username'] != null}');
      print('   Password var: ${credentials['password'] != null}');
      if (credentials['username'] != null) {
        print('   Username: "${credentials['username']}"');
      }
      if (credentials['password'] != null) {
        print('   Password: "${credentials['password']}"');
      }

      if (hasCache) {
        final cachedResponse = await getCachedFullResponse();
        print(
            '   Cache\'deki izin sayısı: ${cachedResponse?.perList.length ?? 0}');
        print('   Cache\'deki userId: ${cachedResponse?.userId}');
      }
    } catch (e) {
      print('❌ Debug hatası: $e');
    }
  }
}
