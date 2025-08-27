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
  // Uygulama başlatıldığında otomatik giriş kontrolü
  Future<void> _checkAutoLogin() async {
    state = state.copyWith(isCheckingAutoLogin: true);

    try {
      final rememberMe = await PreferencesService.getRememberMe();

      if (!rememberMe) {
        print('❌ Remember Me aktif değil - normal login');
        state = state.copyWith(isCheckingAutoLogin: false);
        return;
      }

      print('🔐 Remember Me aktif - otomatik giriş deneniyor');

      // Credentials kontrolü
      final credentials = await PreferencesService.getCredentials();
      final username = credentials['username'];
      final rawPassword = credentials['password'];

      if (username == null || rawPassword == null) {
        print('❌ Credentials eksik - normal login');
        state = state.copyWith(isCheckingAutoLogin: false);
        return;
      }

      // API ile giriş yapmayı dene (cache backup ile)
      final success = await login(username, rawPassword, isAutoLogin: true);

      // 🔥 BURADA EKSİK OLAN KISIM: Başarılı olursa state'i güncelle
      if (success) {
        print(
            '✅ Otomatik giriş başarılı - kullanıcı ana ekrana yönlendirilecek');
        // state zaten login metodunda güncellenmiş olmalı
        // Sadece checking durumunu false yap
        state = state.copyWith(isCheckingAutoLogin: false);
      } else {
        // Otomatik giriş başarısız - normal login ekranına git
        print('❌ Otomatik giriş başarısız - normal login gerekli');
        state = state.copyWith(isCheckingAutoLogin: false);
      }
    } catch (e) {
      print('❌ Otomatik giriş hatası: $e');
      state = state.copyWith(isCheckingAutoLogin: false);
    }
  }

  Future<bool> login(String username, String hashPassword,
      {bool rememberMe = false, bool isAutoLogin = false}) async {
    if (!isAutoLogin) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      // Şifre işleme

      // ÖNCE API'yi dene - Retry mechanism ile
      try {
        final response = await AuthService.loginWithRetry(
          username: username,
          password: hashPassword,
          maxRetries: isAutoLogin ? 1 : 2, // AutoLogin için daha az retry
          isAutoLogin: isAutoLogin,
        );

        if (response != null) {
          // API başarılı - normal giriş
          state = state.copyWith(
            fullResponse: response,
            isLoading: false,
            isLoggedIn: true,
          );

          // Remember me seçilmişse bilgileri kaydet
          if (rememberMe) {
            await PreferencesService.setRememberMe(true);
            print('💾 Remember me aktif edildi');
          }
          await PreferencesService.saveCredentials(username, hashPassword);

          return true;
        }
      } catch (e) {
        print('❌ API hatası: $e');

        // API başarısızsa SADECE OTOMATIK GİRİŞTE cache'den dene
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
            return true;
          } else {
            print('❌ Cache boş - otomatik giriş başarısız');
            return false; // Cache yoksa başarısız
          }
        }

        // MANUEL GİRİŞTE API başarısızsa HATA VER
        if (!isAutoLogin) {
          String errorMessage =
              "API'ye erişilemiyor. İnternet bağlantınızı kontrol edin.";

          if (e.toString().contains("SocketException") ||
              e.toString().contains("TimeoutException")) {
            errorMessage =
                "Sunucuya bağlanılamıyor. İnternet bağlantınızı kontrol edin.";
          } else if (e.toString().contains("401") ||
              e.toString().contains("403")) {
            errorMessage = "Kullanıcı adı veya şifre hatalı";
          } else if (e.toString().contains("500")) {
            errorMessage = "Sunucu hatası. Lütfen daha sonra tekrar deneyin.";
          }

          state = state.copyWith(
            isLoading: false,
            error: errorMessage,
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
      // SADECE OTURUM KAPAT - CACHE'İ KORUMA!
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

  // Cache'i manuel yenile - SADECE API BAŞARILI OLURSA
  Future<bool> refreshCache() async {
    try {
      print('🔄 Cache yenileme deneniyor - API\'den çekiliyor...');

      final credentials = await PreferencesService.getCredentials();
      final username = credentials['username'];
      final rawPassword = credentials['password'];

      if (username != null && rawPassword != null) {
        // Şifreyi işle ve AuthService'e gönder

        // API'den çekmeyi dene - BAŞARISIZ OLURSA CACHE'İ TEMİZLEME!
        final response = await AuthService.login(
            username: username,
            hashedPassword: rawPassword,
            useCache: false,
            isAutoLogin: false);

        if (response != null) {
          // SADECE BAŞARILI OLURSA cache'i güncelle
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

  // Manuel full refresh - SADECE API BAŞARILI OLURSA TEMİZLE
  Future<bool> forceFullRefresh() async {
    try {
      print('FULL REFRESH başlıyor...');

      final credentials = await PreferencesService.getCredentials();
      final username = credentials['username'];
      final rawPassword = credentials['password'];

      print('Refresh için credentials:');
      print('  Username: ${username ?? "NULL"}');
      print('  Raw Password uzunluk: ${rawPassword?.length ?? 0}');

      if (username == null || rawPassword == null) {
        print('Refresh için credentials eksik');
        state = state.copyWith(isLoading: false);
        return false;
      }

      // Loading state
      state = state.copyWith(isLoading: true, clearError: true);

      // Şifreyi işle
      print('Şifre işlendi: ${rawPassword} -> ${rawPassword.length} karakter');

      // API çağrısı - TIMEOUT İLE
      print('Retry ile API çağrısı yapılıyor...');
      final response = await AuthService.loginWithRetry(
        username: username,
        password: rawPassword,
        maxRetries: 3,
        isAutoLogin: false,
      ).timeout(
        Duration(seconds: 25), // loginWithRetry için timeout
        onTimeout: () {
          print('API çağrısı timeout');
          return null;
        },
      );

      if (response != null) {
        print('API başarılı - ${response.perList.length} izin alındı');

        // Cache güncelle
        await PreferencesService.clearCache();
        await PreferencesService.cacheFullResponse(response);

        // State güncelle
        state = state.copyWith(
          fullResponse: response,
          isLoading: false,
          clearError: true,
        );

        return true;
      } else {
        print('API null response döndü');

        // Fallback cache
        final cachedResponse = await PreferencesService.getCachedFullResponse();
        if (cachedResponse != null) {
          print(
              'Fallback cache yüklendi - ${cachedResponse.perList.length} izin');
          state = state.copyWith(
            fullResponse: cachedResponse,
            isLoading: false,
            error: 'API erişilemez - cache kullanılıyor',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'API erişilemez ve cache yok',
          );
        }
        return false;
      }
    } catch (e) {
      print('Full refresh hatası: $e');

      // Emergency fallback
      try {
        final cachedResponse = await PreferencesService.getCachedFullResponse();
        if (cachedResponse != null) {
          print('Emergency cache yüklendi');
          state = state.copyWith(
            fullResponse: cachedResponse,
            isLoading: false,
            error: 'Ağ hatası - cache kullanılıyor',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'Tamamen başarısız - cache de yok',
          );
        }
      } catch (cacheError) {
        print('Emergency cache de başarısız: $cacheError');
        state = state.copyWith(
          isLoading: false,
          error: 'Tam başarısızlık',
        );
      }
      return false;
    }
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
