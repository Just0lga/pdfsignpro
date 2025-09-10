import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/models/frontend_models/ftp_file.dart';
import 'package:pdfsignpro/models/frontend_models/pdf_state.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/screens/ftp_browser_screen.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ftp_pdf_loader_service.dart';
import '../widgets/pdf_page_widget.dart';
import '../widgets/signature_dialog.dart';

class PdfSignScreen extends ConsumerWidget {
  final bool isItFtp;
  final String fileDirectory;
  const PdfSignScreen({this.isItFtp = true, required this.fileDirectory});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);
    print("ooo bu alınan $fileDirectory");
    return WillPopScope(
      onWillPop: () async {
        // PDF temizle ve geri git
        pdfNotifier.reset();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'PDF İmzala',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Color(0xFF112b66),
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
          actions: _buildActions(context, pdfState, pdfNotifier, ref),
          leading: IconButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => isItFtp
                          ? FtpBrowserScreen(fileDirectory: fileDirectory)
                          : PdfSourceSelectionScreen()),
                  (Route<dynamic> route) => false, // tüm eski route’ları sil
                );
              },
              icon: Icon(Icons.arrow_back_ios_new)),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: SafeArea(
            child: Container(
              height: 60,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: pdfState.signatures.isEmpty
                    ? null
                    : () => _showClearAllSignaturesDialog(context, pdfNotifier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  elevation: 2,
                ),
                icon: Icon(
                  Icons.clear_all,
                  size: 24,
                  color: Colors.white,
                ),
                label: Text(
                  'Tüm İmzaları Temizle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: WillPopScope(
            onWillPop: () async {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => isItFtp
                        ? FtpBrowserScreen(fileDirectory: fileDirectory)
                        : PdfSourceSelectionScreen()),
                (Route<dynamic> route) => false, // tüm eski route’ları sil
              );
              return true;
            },
            child: _buildBody(context, ref, pdfState, pdfNotifier)),
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context, PdfState state,
      PdfNotifier notifier, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);

    if (state.isLoading) {
      return [_buildLoadingIndicator()];
    }

    return [
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _sharePDF(context, notifier),
        tooltip: 'Paylaş',
      ),
      pdfState.signatures.isEmpty
          ? SizedBox()
          : IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _savePDF(context, notifier, ref),
              tooltip: 'Kaydet',
            ),
    ];
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
              'PDF işleniyor...',
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

    if (state.pdfBytes == null) {
      return FutureBuilder(
        future: Future.delayed(Duration(milliseconds: 500)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(), // veya boş Container()
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'PDF Bulunamadı',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'İmzalanacak PDF dosyası bulunamadı',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  label: Text('Geri Dön'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF112b66),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // PDF sayfalarını göster
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

  void _showSignatureDialog(
      BuildContext context, WidgetRef ref, int pageIndex, int signatureIndex) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => WillPopScope(
        onWillPop: () async => true,
        child: SignatureDialog(
          pageIndex: pageIndex,
          signatureIndex: signatureIndex,
        ),
      ),
    );
  }
// _savePDF metodundaki dosya kontrol kısmını bu kodla değiştirin:

  Future<void> _savePDF(
      BuildContext context, PdfNotifier notifier, WidgetRef ref) async {
    final connectionDetails = ref.read(ftpConnectionDetailsProvider);

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF112b66)),
              SizedBox(width: 16),
              Text('PDF kaydediliyor...'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await notifier.createSignedPDF();
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = '${result['fileName']}.pdf';

      if (connectionDetails == null ||
          connectionDetails.username.isEmpty ||
          connectionDetails.password.isEmpty) {
        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                  'Kullanıcı bilgileri eksik. FTP sayfasına dönüp bilgileri girin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Dosyaları listele
      final existingFiles = await FtpPdfLoaderService.listPdfFiles(
        host: connectionDetails.host,
        username: connectionDetails.username,
        password: connectionDetails.password,
        directory: fileDirectory,
        port: connectionDetails.port,
      );

      // GELİŞMİŞ ÇAKIŞMA KONTROLÜ
      final conflictInfo = _checkFileConflict(fileName, existingFiles);
      bool shouldOverwrite = true;

      if (context.mounted) Navigator.pop(context);

      // Çakışma varsa onay iste
      if (conflictInfo['hasConflict'] && context.mounted) {
        shouldOverwrite = await showDialog<bool>(
              barrierDismissible: false,
              context: context,
              builder: (context) => WillPopScope(
                onWillPop: () async {
                  Navigator.pop(context, false);
                  return false;
                },
                child: AlertDialog(
                  title: const Text(
                    'Bilgilendirme',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yüklenecek dosya:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('• $fileName'),
                      SizedBox(height: 8),
                      Text(
                        'İlgili dosyalar:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      ...conflictInfo['conflictingFiles']
                          .map<Widget>((file) => Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Text('• ${file.name}',
                                    style: TextStyle(color: Colors.red[700])),
                              )),
                      SizedBox(height: 12),
                      Text(
                        conflictInfo['message'],
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[800]),
                      ),
                    ],
                  ),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                            child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              "İptal",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                        SizedBox(width: 4),
                        Expanded(
                            child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              "Onayla",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ) ??
            false;
      }

      if (!shouldOverwrite) return;

      // Eğer çakışma varsa, önce çakışan dosyaları sil
      if (conflictInfo['hasConflict'] && context.mounted) {
        // Çakışan dosya silme için loading göster
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF112b66)),
                  const SizedBox(width: 16),
                  Text('İmzalı versiyon değiştiriliyor...'),
                ],
              ),
            ),
          ),
        );

        bool deleted = await _deleteConflictingFiles(
          connectionDetails: connectionDetails,
          conflictingFiles: conflictInfo['conflictingFiles'],
          directory: fileDirectory,
          context: context,
        );

        // Silme işlemi loading'ini kapat
        if (context.mounted) Navigator.pop(context);

        if (!deleted) {
          // Silme başarısızsa kullanıcıya mesaj göster ve işlemi iptal et
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text("Çakışan dosyalar silinemedi! Yükleme iptal edildi."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Upload loading - Bu kez daha net mesajla
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: PopScope(
              canPop: false,
              child: const AlertDialog(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF112b66)),
                    SizedBox(width: 16),
                    Text('FTP\'ye yükleniyor...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final success = await FtpPdfLoaderService.uploadPdfToFtp(
        host: connectionDetails.host,
        username: connectionDetails.username,
        password: connectionDetails.password,
        pdfBytes: signedPdfBytes,
        fileName: fileName,
        directory: fileDirectory,
        port: connectionDetails.port,
        overwrite: shouldOverwrite,
      );

      // Upload loading'ini kapat
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
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
                      Text(
                        'Kullanıcı: ${connectionDetails.username}',
                        style: TextStyle(
                            fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                : const Text('PDF kaydetme başarısız!'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // Herhangi bir loading dialog açıksa kapat
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'PDF kaydetme hatası: Lütfen tekrar deneyiniz, internetinizi kontrol ediniz'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Yardımcı metod: Dosya çakışma kontrolü
  Map<String, dynamic> _checkFileConflict(
      String fileName, List<FtpFile> existingFiles) {
    // Dosya adından temel adı çıkar (örn: "rapor_imzalandi_123.pdf" -> "rapor")
    String baseName = _extractBaseName(fileName);

    // Çakışan dosyaları bul
    List<FtpFile> conflictingFiles = existingFiles.where((file) {
      String existingBaseName = _extractBaseName(file.name);
      return existingBaseName == baseName;
    }).toList();

    bool hasConflict = conflictingFiles.isNotEmpty;
    String message = '';

    if (hasConflict) {
      message =
          "Eğer orijinal dosyaya ait imzalı versiyon varsa üstüne yazılacaktır.";
    }

    return {
      'hasConflict': hasConflict,
      'conflictingFiles': conflictingFiles,
      'message': message,
    };
  }

// Dosya adından temel adı çıkaran metod
  String _extractBaseName(String fileName) {
    // .pdf uzantısını kaldır
    String nameWithoutExt = fileName.toLowerCase().replaceAll('.pdf', '');

    // "_imzalandi" ve sonrasını kaldır
    if (nameWithoutExt.contains('_imzalandi')) {
      return nameWithoutExt.split('_imzalandi')[0];
    }

    return nameWithoutExt;
  }

// Çakışan dosyaları silen metod
  Future<bool> _deleteConflictingFiles({
    required dynamic connectionDetails,
    required List<FtpFile> conflictingFiles,
    required String directory,
    required BuildContext context,
  }) async {
    try {
      print('🗑️ ${conflictingFiles.length} çakışan dosya silme kontrolü...');

      for (FtpFile file in conflictingFiles) {
        // Orijinal dosya (ör: rapor.pdf) korunacak
        if (!file.name.toLowerCase().contains('_imzalandi')) {
          print('   ⏭️ Orijinal dosya korunuyor: ${file.name}');
          continue;
        }

        print('   Siliniyor: ${file.name}');

        bool deleted = await FtpPdfLoaderService.deleteFileFromFtp(
          host: connectionDetails.host,
          username: connectionDetails.username,
          password: connectionDetails.password,
          fileName: file.name,
          directory: directory,
          port: connectionDetails.port,
        );

        if (!deleted) {
          print('   ❌ Silinemedi: ${file.name}');
          return false;
        }

        print('   ✅ Silindi: ${file.name}');
      }

      print('✅ Çakışan imzalı dosyalar silindi (orijinal korundu)');
      return true;
    } catch (e) {
      print('❌ Çakışan dosya silme hatası: $e');
      return false;
    }
  }

  Future<void> _sharePDF(BuildContext context, PdfNotifier notifier) async {
    try {
      final Map<String, dynamic> result = await notifier.createSignedPDF();
      final Uint8List signedPdfBytes = result['bytes'];
      final String fileName = result['fileName'];

      await Printing.sharePdf(
        bytes: signedPdfBytes,
        filename: '$fileName.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF paylaşma hatası: $e')),
        );
      }
    }
  }
}

// Tüm imzaları temizle onay dialog'u
void _showClearAllSignaturesDialog(BuildContext context, PdfNotifier notifier) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text(
            'Dikkat!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
      content: Text(
        'Bu oturumdaki tüm imzalar silinecek.\nBu işlem geri alınamaz.\n\nDevam etmek istediğinizden emin misiniz?',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'İptal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            notifier.clearAllSignatures();
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Tüm imzalar başarıyla temizlendi'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Tümünü Sil',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
