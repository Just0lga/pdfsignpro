import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdfsignpro/screens/login_screen.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';
import 'package:pdfsignpro/services/preference_service.dart';
import 'screens/pdf_imza_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null); // Türkçe tarih formatı için
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //gite yüklüyorum
      title: 'PDF İmza',
      theme: ThemeData(primarySwatch: Colors.cyan),
      home: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authProvider);

          // Otomatik giriş kontrol ediliyor
          if (authState.isCheckingAutoLogin) {
            return _buildAutoLoginLoadingScreen();
          }

          // Eğer giriş yapılmışsa PDF ekranına git
          if (authState.isLoggedIn) {
            return PdfImzaScreen();
          }

          return LoginScreen();
        },
      ),
      // Navigation error handling
      builder: (context, child) {
        return child ?? Container();
      },
    );
  }

  Widget _buildAutoLoginLoadingScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF112b66),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                "assets/logo_rectangle.png",
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Giriş kontrol ediliyor...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
