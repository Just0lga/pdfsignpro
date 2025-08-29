import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';
import 'package:pdfsignpro/services/preference_service.dart';
import 'package:pdfsignpro/widgets/app_text_field.dart';
import 'package:crypto/crypto.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    print("xxx login screen");
    super.initState();

    // Kayıtlı remember me durumunu yükle
    _loadRememberMeState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadRememberMeState() async {
    try {
      final remember = await PreferencesService.getRememberMe();
      if (remember) {
        final credentials = await PreferencesService.getCredentials();
        final username = credentials['username'];
        final hashedPassword =
            credentials['password']; // 🔥 Bu artık hash şifre

        if (username != null && hashedPassword != null && mounted) {
          setState(() {
            usernameController.text = username;
            passwordController.text = hashedPassword; // 🔥 RAW şifreyi göster
            rememberMe = true;
          });
        }
      }
    } catch (e) {
      print('Remember me state yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // LoginScreen - Düzeltilmiş login metodunda

  Future<void> login() async {
    final username = usernameController.text.trim();
    final rawPassword = passwordController.text.trim();
    final processedPassword = rawPassword + "pdfSignPro2024!@";

    // Gelen şifre zaten işlenmiş, sadece SHA256 hash yapılacak
    final bytes = utf8.encode(processedPassword);
    final hash = sha256.convert(bytes).toString();

    if (username.isEmpty || rawPassword.isEmpty) {
      _showCustomSnackBar("Lütfen tüm alanları doldurun", Colors.orange);
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);

    // ✅ MANUEL GİRİŞ - API zorunlu
    print('🔐 Manuel giriş başlatılıyor: $username');

    final success = await authNotifier.login(
      username,
      hash,
      rememberMe: rememberMe,
      isAutoLogin: false, // ✅ Manuel giriş
    );

    if (!mounted) return;

    if (success) {
      final validFtpPermissions = authNotifier.getFtpPermissions();

      // Cache durumunu kontrol et
      final cacheStatus = await authNotifier.getCacheStatus();

      // ✅ Login kaynak bilgisi
      String loginSource = 'API\'den giriş yapıldı';
      if (cacheStatus['hasCache'] == true && validFtpPermissions.isEmpty) {
        loginSource = 'Cache\'den giriş yapıldı (API erişilemedi)';
      }

      print('🎯 Login başarılı:');
      print('   Geçerli FTP izin sayısı: ${validFtpPermissions.length}');
      print('   Kaynak: $loginSource');

      _showCustomSnackBar(
        "Giriş başarılı!",
        Colors.green,
      );

      await Future.delayed(Duration(milliseconds: 800));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => PdfSourceSelectionScreen()),
          (Route<dynamic> route) => false, // tüm eski route’ları sil
        );
      }
    } else {
      final authState = ref.read(authProvider);

      // ✅ Daha açıklayıcı hata mesajları
      String errorMessage = authState.error ?? "Giriş başarısız";

      if (errorMessage.contains("API'ye erişilemiyor")) {
        errorMessage =
            "Kullanıcı adı veya şifre hatalı.\nİnternet bağlantınızı kontrol edin.";
      } else if (errorMessage.contains("Kullanıcı adı veya şifre")) {
        errorMessage =
            "Kullanıcı adı veya şifre hatalı.\nLütfen bilgilerinizi kontrol edin.";
      }

      _showCustomSnackBar(errorMessage, Colors.red);
    }
  }

  void _showCustomSnackBar(String message, Color color) {
    // Widget hala mounted mı kontrol et
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.orange
                      ? Icons.warning
                      : Icons.error,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Hoşgeldiniz",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 24,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF112b66),
              Color(0xFF1e3a8a),
              Colors.grey.shade50,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: height -
                    MediaQuery.of(context).padding.top -
                    kToolbarHeight,
              ),
              child: Column(
                children: [
                  SizedBox(height: height * 0.08),

                  // Logo Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                        position: _slideAnimation,
                        child: Hero(
                          tag: "logo",
                          child: Container(
                            height: height * 0.14,
                            padding: EdgeInsets.all(height * 0.01),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                "assets/logo_rectangle.png",
                                height: height * 0.12,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        )),
                  ),

                  SizedBox(height: height * 0.04),

                  // Welcome Text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          "Tekrar Hoşgeldiniz!",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Hesabınıza giriş yapın",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: height * 0.05),

                  // Login Form
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: Offset(0, 15),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Username Field
                            AppTextField(
                              label: "Kullanıcı Adı",
                              controller: usernameController,
                            ),

                            SizedBox(height: 20),

                            // Password Field
                            AppTextField(
                              label: "Şifre",
                              controller: passwordController,
                            ),

                            SizedBox(height: 8),

                            // Remember Me Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      rememberMe = value ?? false;
                                    });
                                  },
                                  activeColor: Color(0xFF112b66),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        rememberMe = !rememberMe;
                                      });
                                    },
                                    child: Text(
                                      'Beni hatırla',
                                      style: TextStyle(
                                        color: Color(0xFF112b66),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // Login Button
                            Container(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF112b66),
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor:
                                      Color(0xFF112b66).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: authState.isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.login,
                                            size: 28,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "Giriş Yap",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Forgot Password
                            /*
                            TextButton(
                              onPressed: () {
                                // Şifremi unuttum fonksiyonu
                              },
                              child: Text(
                                "Şifremi Unuttum?",
                                style: TextStyle(
                                  color: Color(0xFF112b66),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),*/
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
