// ftp_credentials_storage.dart - Yeni dosya
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FtpCredentialsStorage {
  static const String _storageKey = 'ftp_saved_credentials';

  /// Server ismine göre credentials kaydet
  static Future<void> saveCredentials({
    required String serverName,
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Mevcut kayıtlı credentials'ları al
      final String? existingData = prefs.getString(_storageKey);
      Map<String, dynamic> allCredentials = {};

      if (existingData != null) {
        allCredentials = Map<String, dynamic>.from(jsonDecode(existingData));
      }

      // Yeni credentials'ı ekle/güncelle
      allCredentials[serverName] = {
        'username': username,
        'password': password,
        'savedAt': DateTime.now().toIso8601String(),
      };

      // Kaydet
      await prefs.setString(_storageKey, jsonEncode(allCredentials));

      print('✅ Credentials kaydedildi: $serverName');
    } catch (e) {
      print('❌ Credentials kaydetme hatası: $e');
    }
  }

  /// Server ismine göre credentials al
  static Future<Map<String, String>?> getCredentials(String serverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_storageKey);

      if (existingData == null) return null;

      final Map<String, dynamic> allCredentials =
          Map<String, dynamic>.from(jsonDecode(existingData));

      if (!allCredentials.containsKey(serverName)) return null;

      final savedCreds = allCredentials[serverName];

      print('✅ Kayıtlı credentials bulundu: $serverName');

      return {
        'username': savedCreds['username'] as String,
        'password': savedCreds['password'] as String,
      };
    } catch (e) {
      print('❌ Credentials okuma hatası: $e');
      return null;
    }
  }

  /// Server için kayıtlı credentials var mı kontrol et
  static Future<bool> hasCredentials(String serverName) async {
    final creds = await getCredentials(serverName);
    return creds != null;
  }

  /// Belirli bir server'ın credentials'ını sil
  static Future<void> removeCredentials(String serverName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_storageKey);

      if (existingData == null) return;

      final Map<String, dynamic> allCredentials =
          Map<String, dynamic>.from(jsonDecode(existingData));

      allCredentials.remove(serverName);

      if (allCredentials.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(allCredentials));
      }

      print('✅ Credentials silindi: $serverName');
    } catch (e) {
      print('❌ Credentials silme hatası: $e');
    }
  }

  /// Tüm kayıtlı credentials'ları temizle (logout için)
  static Future<void> clearAllCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('✅ Tüm FTP credentials temizlendi');
    } catch (e) {
      print('❌ Credentials temizleme hatası: $e');
    }
  }

  /// Debug için: Tüm kayıtlı server isimlerini listele
  static Future<List<String>> getSavedServerNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_storageKey);

      if (existingData == null) return [];

      final Map<String, dynamic> allCredentials =
          Map<String, dynamic>.from(jsonDecode(existingData));

      return allCredentials.keys.toList();
    } catch (e) {
      print('❌ Server listesi alma hatası: $e');
      return [];
    }
  }
}
