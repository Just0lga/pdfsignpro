import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/models/frontend_models/pdf_state.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/screens/ftp_browser_screen.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';
import 'package:printing/printing.dart';
import '../services/ftp_pdf_loader_service.dart';
import '../widgets/pdf_page_widget.dart';
import '../widgets/signature_dialog.dart';

class PdfSignScreen extends ConsumerWidget {
  final bool isItFtp;
  const PdfSignScreen({this.isItFtp = true});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

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
                          ? FtpBrowserScreen()
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
                    borderRadius: BorderRadius.circular(8),
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
                        ? FtpBrowserScreen()
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

  Future<void> _savePDF(
      BuildContext context, PdfNotifier notifier, WidgetRef ref) async {
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

      // Dosya var mı kontrol et
      final existingFiles = await FtpPdfLoaderService.listPdfFiles(
        host: connectionDetails.host,
        username: connectionDetails.username,
        password: connectionDetails.password,
        port: connectionDetails.port,
      );

      final fileExists = existingFiles.any((file) => file.name == fileName);
      bool shouldOverwrite = true;

      if (context.mounted) Navigator.pop(context);

      // Dosya varsa onay iste
      if (fileExists && context.mounted) {
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
                    'Dosya Mevcut',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                      '$fileName zaten mevcut. Üstüne yazmak istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'İptal',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Üstüne Yaz',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ) ??
            false;
      }

      if (!shouldOverwrite) return;

      // Upload loading
      if (context.mounted) {
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FTP\'ye yükleniyor...'),
                    ],
                  ),
                ],
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
        port: connectionDetails.port,
        overwrite: shouldOverwrite,
      );

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
                    ],
                  )
                : const Text('PDF kaydetme başarısız!'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                ),
                SizedBox(
                  width: 8,
                ),
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
