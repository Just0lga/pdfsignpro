import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdfsignpro/screens/login_screen.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';

//SVN
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null); // Türkçe tarih formatı için
  runApp(ProviderScope(child: MyApp()));
}

//ok
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF İmza',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Color(0xFF112b66),
          selectionColor: Color(0xFF112b66).withOpacity(0.3),
          selectionHandleColor: Color(
            0xFF112b66,
          ), // Bu damla şeklindeki handle'ı değiştirir
        ),
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authProvider);

          // Otomatik giriş kontrol ediliyor
          if (authState.isCheckingAutoLogin) {
            return _buildAutoLoginLoadingScreen(width, height);
          }

          // Eğer giriş yapılmışsa PDF ekranına git
          if (authState.isLoggedIn) {
            return PdfSourceSelectionScreen();
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

  Widget _buildAutoLoginLoadingScreen(double width, double height) {
    return Scaffold(
      backgroundColor: Color(0xFF112b66),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
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
