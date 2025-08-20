import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/models/frontend_models/pdf_state.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';
import 'package:pdfsignpro/services/preference_service.dart';
import 'package:printing/printing.dart';
import '../services/ftp_pdf_loader.dart';
import '../widgets/pdf_page_widget.dart';
import '../widgets/signature_dialog.dart';

class PdfImzaScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

    return WillPopScope(
      // 🔥 Sistem geri tuşu kontrolü
      onWillPop: () async {
        if (pdfState.pdfBytes != null) {
          // PDF yüklüyse PDF'yi temizle
          pdfNotifier.reset();
          return false; // Ana ekrana gitme
        }
        return true; // PDF yoksa normal geri git
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Otomatik geri tuşunu kapat
          title: Text(
              pdfState.pdfBytes == null ? 'PDF Kaynağı Seçin' : 'PDF İmzala',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Color(0xFF112b66),
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
          actions: _buildActions(context, pdfState, pdfNotifier, ref),
          leading: _buildLeading(
              context, pdfState, pdfNotifier, ref), // 🔥 Manuel geri tuşu
        ),
        body: _buildBody(context, ref, pdfState, pdfNotifier),
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context, PdfState state,
      PdfNotifier notifier, WidgetRef ref) {
    // PDF yüklü değilse sadece logout butonu göster
    if (state.pdfBytes == null) {
      return [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _logout(context, ref),
          tooltip: 'Çıkış Yap',
        ),
      ];
    }

    if (state.isLoading) {
      return [_buildLoadingIndicator()];
    }

    return [
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _sharePDF(context, notifier),
        tooltip: 'Paylaş',
      ),
      IconButton(
        icon: const Icon(Icons.save),
        onPressed: () => _savePDF(context, notifier, ref),
        tooltip: 'Kaydet',
      ),
    ];
  }

  Widget? _buildLeading(BuildContext context, PdfState state,
      PdfNotifier notifier, WidgetRef ref) {
    // PDF yüklü değilse cache refresh butonu göster
    /*if (state.pdfBytes == null) {
      return IconButton(
        onPressed: () => _refreshMainCache(context, ref),
        icon: const Icon(Icons.refresh),
        tooltip: 'Sunucuları Yenile',
      );
    }*/

    // 🔥 PDF yüklüyse GERİ BUTONU GÖSTER
    if (state.pdfBytes != null)
      return IconButton(
        onPressed: state.isLoading
            ? null
            : () {
                // PDF'yi temizle ve kaynak seçim ekranına dön
                notifier.reset();
              },
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Geri',
      );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, PdfState state,
      PdfNotifier notifier) {
    // Loading durumunda spinner göster
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF112b66)),
            SizedBox(height: 16),
            Text(
              'PDF yükleniyor...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF112b66),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // PDF yüklü değilse kaynak seçim ekranını göster
    if (state.pdfBytes == null) {
      return Container(
        child: PdfSourceSelectionScreen(),
      );
    }

    // PDF yüklü ve hazırsa sayfa listesini göster
    return ListView.builder(
      itemCount: state.totalPages,
      shrinkWrap: false,
      cacheExtent: 1000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, pageIndex) => PdfPageWidget(
        key: ValueKey('pdf_page_$pageIndex'),
        pageIndex: pageIndex,
        onSignatureTap: (signatureIndex) => _showSignatureDialog(
          context,
          ref,
          pageIndex,
          signatureIndex,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF112b66)),
            ),
          ),
        ),
      );

  Widget _buildLoadingScreen() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF112b66)),
            SizedBox(height: 16),
            Text('İşlem yapılıyor...'),
          ],
        ),
      );

  void _showSignatureDialog(
      BuildContext context, WidgetRef ref, int pageIndex, int signatureIndex) {
    showDialog(
      context: context,
      builder: (context) => SignatureDialog(
        pageIndex: pageIndex,
        signatureIndex: signatureIndex,
      ),
    );
  }

  Future<void> _refreshMainCache(BuildContext context, WidgetRef ref) async {
    print('🔄 Ana sayfa cache refresh başlatılıyor...');

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            CircularProgressIndicator(color: Color(0xFF112b66)),
            Text('Sunucular yenileniyor...'),
          ],
        ),
      ),
    );

    try {
      final authNotifier = ref.read(authProvider.notifier);

      // 🔥 ZORLA FULL REFRESH
      final success = await authNotifier.forceFullRefresh();

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'unu kapat

        if (success) {
          // Debug için yeni cache'i yazdır
          await PreferencesService.debugCacheInfo();

          // Güncel izinleri yazdır
          final currentState = ref.read(authProvider);
          if (currentState.fullResponse != null) {
            print('🎯 Yenilenmiş izinler:');
            print(
                '   Toplam izin: ${currentState.fullResponse!.perList.length}');
            for (var perm in currentState.fullResponse!.perList) {
              print('   - ${perm.name} (${perm.permtype}) - AP: ${perm.ap}');
              if (perm.permtype == 'ftp' && perm.host != null) {
                print('     Host: ${perm.host}:${perm.port}');
              }
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '🔥 Tüm eski cache temizlendi, API\'den yeni veri alındı.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          print('❌ Cache yenileme başarısız');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child:
                        Text('Yenileme başarısız\nAPI\'ye erişim sağlanamadı'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Cache refresh hatası: $e');

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'unu kapat

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Yenileme hatası:\n$e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _savePDF(
      BuildContext context, PdfNotifier notifier, WidgetRef ref) async {
    // FTP bağlantı bilgilerini al
    final connectionDetails = ref.read(ftpConnectionDetailsProvider);

    if (connectionDetails == null || !connectionDetails.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FTP bağlantı bilgileri eksik!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF112b66)),
            SizedBox(width: 16),
            Text('PDF kaydediliyor...'),
          ],
        ),
      ),
    );

    try {
      final result = await notifier.createSignedPDF();
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = '${result['fileName']}.pdf';

      // Dosya var mı kontrol et
      final existingFiles = await FtpPdfLoader.listPdfFiles(
        host: connectionDetails.host,
        username: connectionDetails.username,
        password: connectionDetails.password,
        port: connectionDetails.port,
      );

      final fileExists = existingFiles.any((file) => file.name == fileName);
      bool shouldOverwrite = true;

      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      // Eğer dosya varsa kullanıcıya sor
      if (fileExists && context.mounted) {
        shouldOverwrite = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Dosya Mevcut'),
                content: Text(
                    '$fileName zaten mevcut. Üstüne yazmak istiyor musunuz?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Üstüne Yaz'),
                  ),
                ],
              ),
            ) ??
            false;
      }

      if (!shouldOverwrite) return;

      // Upload loading göster
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF112b66)),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FTP\'ye yükleniyor...'),
                    const SizedBox(height: 4),
                    /*Text(
                      '${connectionDetails.name} (${connectionDetails.host})',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),*/
                  ],
                ),
              ],
            ),
          ),
        );
      }

      // FTP'ye yükle
      final success = await FtpPdfLoader.uploadPdfToFtp(
        host: connectionDetails.host,
        username: connectionDetails.username,
        password: connectionDetails.password,
        pdfBytes: signedPdfBytes,
        fileName: fileName,
        port: connectionDetails.port,
        overwrite: shouldOverwrite,
      );

      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      // Sonuç göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: success
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PDF kaydedildi: $fileName'),
                      const SizedBox(height: 4),
                      Text(
                        'Bağlantı: ${connectionDetails.name}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                : const Text('PDF kaydetme başarısız!'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Loading'i kapat
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          //burada normalde $e vardı çok uzun olduğu için bıraktım
          SnackBar(
            content: Text(
                'PDF kaydetme hatası: Lütfen tekrar deneyiniz, internetinizi kontrol ediniz'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF(BuildContext context, PdfNotifier notifier) async {
    try {
      // Map döndüren createSignedPDF'yi çağır
      final Map<String, dynamic> result = await notifier.createSignedPDF();

      // Map'ten bytes ve fileName'i çıkar
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = result['fileName'];

      await Printing.sharePdf(
        bytes: signedPdfBytes, // Artık doğru tip: Uint8List
        filename: '$fileName.pdf', // Dinamik dosya adı
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF paylaşma hatası: $e')),
        );
      }
    }
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Çıkış Yap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uygulamadan çıkmak istediğinizden emin misiniz?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          /*
          TextButton(
            onPressed: () {
              // 🔥 Normal çıkış - CACHE KORUNUR
              ref.read(authProvider.notifier).logout(clearRememberMe: false);
              ref.read(pdfProvider.notifier).reset();
              ref.read(selectedFtpConnectionProvider.notifier).state = null;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Oturum kapatıldı - verileriniz korundu'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: Text(
              'Normal Çıkış',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),*/
          TextButton(
            onPressed: () {
              // 🔥 Tamamen çıkış - CACHE TEMİZLE
              ref.read(authProvider.notifier).logout(clearRememberMe: true);
              ref.read(pdfProvider.notifier).reset();
              ref.read(selectedFtpConnectionProvider.notifier).state = null;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tamamen çıkış yapıldı'), //Tüm veriler silindi
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(
              'Çıkış', //Tamamen Çık
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
