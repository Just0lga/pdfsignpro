import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/services/preference_service.dart';
import '../models/backend_models/full_response.dart';
import '../models/backend_models/perm.dart';
import '../services/auth_service.dart';

// Auth state
class AuthState {
  final FullResponse? fullResponse;
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;
  final bool isCheckingAutoLogin;

  const AuthState({
    this.fullResponse,
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
    this.isCheckingAutoLogin = false,
  });

  AuthState copyWith({
    FullResponse? fullResponse,
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
    bool? isCheckingAutoLogin,
    bool clearError = false,
  }) {
    return AuthState(
      fullResponse: fullResponse ?? this.fullResponse,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isCheckingAutoLogin: isCheckingAutoLogin ?? this.isCheckingAutoLogin,
    );
  }
}

// Auth Provider
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkAutoLogin();
  }

  // Uygulama başlatıldığında otomatik giriş kontrolü
  Future<void> _checkAutoLogin() async {
    state = state.copyWith(isCheckingAutoLogin: true);

    try {
      final rememberMe = await PreferencesService.getRememberMe();

      if (rememberMe) {
        print('🔐 Remember Me aktif - otomatik giriş yapılıyor');

        // 🔥 BASIT ÇÖZÜM: Remember me varsa direkt giriş yap
        final cachedResponse = await PreferencesService.getCachedFullResponse();

        if (cachedResponse != null) {
          // Cache varsa direkt giriş yap
          print('✅ Cache\'den ${cachedResponse.perList.length} izin yüklendi');
          state = state.copyWith(
            fullResponse: cachedResponse,
            isLoggedIn: true,
            isCheckingAutoLogin: false,
          );
          print('✅ Cache\'den otomatik giriş başarılı');
          return;
        } else {
          // Cache yoksa da giriş yap (offline mode)
          print('⚠️ Cache boş - offline modda giriş');
          state = state.copyWith(
            fullResponse: null,
            isLoggedIn: true,
            isCheckingAutoLogin: false,
          );
          print('✅ Offline otomatik giriş başarılı');
          return;
        }
      }
    } catch (e) {
      print('❌ Otomatik giriş hatası: $e');
    }

    state = state.copyWith(isCheckingAutoLogin: false);
  }

  Future<bool> login(String username, String rawPassword,
      {bool rememberMe = false, bool isAutoLogin = false}) async {
    if (!isAutoLogin) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      // 🔥 Şifre işleme
      final processedPassword = rawPassword + "pdfSignPro2024!@";

      // 🔥 ÖNCE API'yi dene
      try {
        final response = await AuthService.login(
          username: username,
          password: processedPassword,
          useCache: false, // Önce fresh API'yi dene
        );

        if (response != null) {
          // ✅ API başarılı - normal giriş
          state = state.copyWith(
            fullResponse: response,
            isLoading: false,
            isLoggedIn: true,
          );

          // Remember me seçilmişse bilgileri kaydet
          if (rememberMe) {
            await PreferencesService.setRememberMe(true);
            await PreferencesService.saveCredentials(username, rawPassword);
            print('💾 Remember me aktif edildi');
          }

          return true;
        }
      } catch (e) {
        print('❌ API hatası: $e');

        // 🔥 API başarısızsa SADECE OTOMATIK GİRİŞTE cache'den dene
        if (isAutoLogin && await PreferencesService.getRememberMe()) {
          print(
              '🔄 Otomatik giriş - API çalışmıyor ama remember me var, cache\'den giriş');

          final cachedResponse =
              await PreferencesService.getCachedFullResponse();

          if (cachedResponse != null) {
            print(
                '✅ Cache\'den ${cachedResponse.perList.length} izin yüklendi');
            state = state.copyWith(
              fullResponse: cachedResponse,
              isLoading: false,
              isLoggedIn: true,
            );
          } else {
            print('⚠️ Cache boş - offline modda giriş');
            state = state.copyWith(
              fullResponse: null,
              isLoading: false,
              isLoggedIn: true,
            );
          }

          return true;
        }

        // 🔥 MANUEL GİRİŞTE API başarısızsa HATA VER
        if (!isAutoLogin) {
          state = state.copyWith(
            isLoading: false,
            error: "Kullanıcı adı veya şifre hatalı",
          );
          return false;
        }
      }

      // Hiçbir şey işe yaramadı
      state = state.copyWith(
        isLoading: false,
        error: "Giriş başarısız - Bilgilerinizi kontrol edin",
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void logout({bool clearRememberMe = false}) {
    if (clearRememberMe) {
      // Tamamen temizle (cache dahil)
      PreferencesService.clearAll();
      print('🗑️ Tüm kullanıcı bilgileri ve cache temizlendi');
    } else {
      // 🔥 SADECE OTURUM KAPAT - CACHE'İ KORUMA!
      // Cache'i ve remember me'yi koru, sadece state'i temizle
      print('📴 Oturum kapatıldı - cache ve remember me korundu');
    }

    state = const AuthState();
  }

  // Cache durumunu kontrol et
  Future<Map<String, dynamic>> getCacheStatus() async {
    final hasCache = await PreferencesService.hasCache();
    final rememberMe = await PreferencesService.getRememberMe();

    return {
      'hasCache': hasCache,
      'rememberMe': rememberMe,
      'source': hasCache ? 'cache' : 'offline',
    };
  }

  // 🔧 Cache'i manuel yenile - SADECE API BAŞARILI OLURSA
  Future<bool> refreshCache() async {
    try {
      print('🔄 Cache yenileme deneniyor - API\'den çekiliyor...');

      final credentials = await PreferencesService.getCredentials();
      final username = credentials['username'];
      final rawPassword = credentials['password'];

      if (username != null && rawPassword != null) {
        // 🔧 Şifreyi işle ve AuthService'e gönder
        final processedPassword = rawPassword + "pdfSignPro2024!@";

        // 🔧 API'den çekmeyi dene - BAŞARISIZ OLURSA CACHE'İ TEMİZLEME!
        final response = await AuthService.login(
            username: username, password: processedPassword, useCache: false);

        if (response != null) {
          // 🔥 SADECE BAŞARILI OLURSA cache'i güncelle
          await PreferencesService.clearCache(); // Eski cache'i temizle
          await PreferencesService.cacheFullResponse(
              response); // Yeni cache'i kaydet

          // State'i güncelle
          state = state.copyWith(fullResponse: response);
          print('✅ Cache başarıyla yenilendi ve state güncellendi');
          return true;
        } else {
          print('❌ API başarısız - eski cache korundu');
          return false;
        }
      }
    } catch (e) {
      print('❌ Cache yenileme hatası: $e - eski cache korundu');
    }

    return false;
  }

  // 🆕 Manuel full refresh - SADECE API BAŞARILI OLURSA TEMİZLE
  Future<bool> forceFullRefresh() async {
    try {
      print('🔥 FULL REFRESH başlıyor - API deneniyor...');

      final credentials = await PreferencesService.getCredentials();
      final username = credentials['username'];
      final rawPassword = credentials['password'];

      if (username != null && rawPassword != null) {
        // State'i loading yap
        state = state.copyWith(isLoading: true);

        // 🔧 Şifreyi işle ve AuthService'e gönder
        final processedPassword = rawPassword + "pdfSignPro2024!@";

        // API'den yeni veri almaya çalış
        final response = await AuthService.login(
          username: username,
          password: processedPassword,
          useCache: false,
        );

        if (response != null) {
          // 🔥 SADECE BAŞARILI OLURSA eski cache'i temizle
          await PreferencesService.clearCache();
          await PreferencesService.cacheFullResponse(response);

          state = state.copyWith(
            fullResponse: response,
            isLoading: false,
          );

          print('✅ Full refresh tamamlandı - yeni veri alındı');
          return true;
        } else {
          // API başarısız - eski cache'i koru
          final cachedResponse =
              await PreferencesService.getCachedFullResponse();
          state = state.copyWith(
            fullResponse: cachedResponse,
            isLoading: false,
          );
          print('❌ API başarısız - eski cache korundu');
          return false;
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      print('❌ Full refresh hatası: $e - eski cache korundu');

      // Hata durumunda eski cache'i yükle
      final cachedResponse = await PreferencesService.getCachedFullResponse();
      state = state.copyWith(
        fullResponse: cachedResponse,
        isLoading: false,
      );
    }

    return false;
  }

  // FTP izinlerini al
  List<Perm> getFtpPermissions() {
    if (state.fullResponse == null) return [];
    return AuthService.getFtpPermissions(state.fullResponse!);
  }

  // İlk geçerli FTP iznini al
  Perm? getFirstValidFtpPermission() {
    if (state.fullResponse == null) return null;
    return AuthService.getFirstValidFtpPermission(state.fullResponse!);
  }

  // İsme göre FTP izni al
  Perm? getFtpPermissionByName(String name) {
    if (state.fullResponse == null) return null;
    return AuthService.getFtpPermissionByName(state.fullResponse!, name);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

// FTP izinleri için ayrı provider
final validFtpPermissionsProvider = Provider<List<Perm>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.fullResponse == null) return [];
  return AuthService.getFtpPermissions(authState.fullResponse!);
});

// Aktif FTP konfigürasyonu provider
final activeFtpConfigProvider = StateProvider<Perm?>((ref) {
  final ftpPermissions = ref.watch(validFtpPermissionsProvider);
  return ftpPermissions.isNotEmpty ? ftpPermissions.first : null;
});
