import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:pdfsignpro/turkish.dart';

class FtpUploadHelper {
  /// PDF'yi FTP'ye yükle - Türkçe karakter desteği ile
  static Future<bool> uploadPdfToFtp({
    required String host,
    required String username,
    required String password,
    required Uint8List pdfBytes,
    required String fileName,
    String directory = '/',
    int port = 21,
    bool overwrite = false,
  }) async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      // PDF doğrulama
      bool isValidPdf = await _verifyPdfFile(pdfBytes);
      if (!isValidPdf) {
        throw Exception('Geçersiz PDF dosyası');
      }

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 120,
        showLog: false,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      if (directory != '/') {
        await ftpConnect.changeDirectory(directory);
      }

      await ftpConnect.setTransferType(TransferType.binary);

      String finalFileName = _prepareFileNameForUpload(fileName);
      print(
          '🔄 Upload için dosya adı hazırlandı: "$fileName" -> "$finalFileName"');

      String filePath =
          directory == '/' ? '/$finalFileName' : '$directory/$finalFileName';

      // Dosya kontrolü
      if (!overwrite) {
        try {
          int existingSize = await ftpConnect.sizeFile(filePath);
          if (existingSize >= 0) {
            throw Exception('Dosya zaten mevcut');
          }
        } catch (e) {
          // Dosya yoksa normal, devam et
        }
      }

      tempFile = await _createTempFileForUpload(pdfBytes);

      bool uploadResult = await _uploadWithRetryMultipleEncodings(
          ftpConnect, tempFile, fileName, pdfBytes.length);

      if (!uploadResult) {
        throw Exception('Dosya yükleme başarısız');
      }

      print('Dosya başarıyla yüklendi: $fileName (${pdfBytes.length} bytes)');
      return true;
    } catch (e) {
      print('FTP upload hatası: $e');
      return false;
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }

      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Geçici dosya silme hatası: $e');
      }
    }
  }

  /// Birden fazla encoding ile upload deneme
  static Future<bool> _uploadWithRetryMultipleEncodings(FTPConnect ftpConnect,
      File localFile, String originalFileName, int expectedSize) async {
    // TurkishCharacterDecoder kullanarak encoding varyantları al
    List<String> encodingVariants =
        TurkishCharacterDecoder.generateFtpEncodingVariants(originalFileName);

    print('🚀 Upload: ${encodingVariants.length} encoding varyantı deneniyor');

    for (int i = 0; i < encodingVariants.length; i++) {
      String fileName = encodingVariants[i];
      print('📤 Upload ${i + 1}/${encodingVariants.length}: "$fileName"');

      try {
        bool result = await _uploadWithRetry(
            ftpConnect, localFile, fileName, expectedSize);
        if (result) {
          print('✅ Upload başarılı!');
          return true;
        }
      } catch (e) {
        print('❌ Upload varyantı başarısız: $e');
        continue;
      }
    }

    print('❌ Tüm encoding varyantları başarısız');
    return false;
  }

  /// Tekrar deneme ile upload
  static Future<bool> _uploadWithRetry(FTPConnect ftpConnect, File localFile,
      String remoteName, int expectedSize) async {
    const int maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('   Upload denemesi $attempt/$maxRetries: "$remoteName"');

        bool result = await ftpConnect.uploadFileWithRetry(
          localFile,
          pRemoteName: remoteName,
          pRetryCount: 2,
        );

        if (result) {
          // Upload sonrası doğrulama
          await Future.delayed(Duration(milliseconds: 500));

          String remotePath = '/$remoteName';
          int uploadedSize = await ftpConnect.sizeFile(remotePath);
          if (uploadedSize >= 0 && uploadedSize == expectedSize) {
            print(
                '   ✅ Upload başarılı: "$remoteName" (${expectedSize} bytes)');
            return true;
          } else {
            print(
                '   ❌ Boyut uyumsuzluğu - beklenen $expectedSize, yüklenen $uploadedSize');
            try {
              await ftpConnect.deleteFile(remotePath);
            } catch (e) {
              print('   Bozuk dosya silinemedi: $e');
            }
          }
        }
      } catch (e) {
        print('   ❌ Upload denemesi $attempt başarısız: $e');
        if (attempt == maxRetries) rethrow;
      }

      // Tekrar denemeden önce bekle
      await Future.delayed(Duration(seconds: attempt));
    }

    return false;
  }

  /// Upload için dosya adını hazırla
  static String _prepareFileNameForUpload(String fileName) {
    return fileName.trim(); // Sadece boşluk temizle
  }

  /// Upload için geçici dosya oluştur
  static Future<File> _createTempFileForUpload(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final fileName = 'ftp_upload_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  /// PDF dosyası doğrulama
  static Future<bool> _verifyPdfFile(Uint8List bytes) async {
    try {
      if (bytes.length < 4) return false;

      String header = String.fromCharCodes(bytes.sublist(0, 4));
      if (header != '%PDF') return false;

      int searchStart = bytes.length > 1024 ? bytes.length - 1024 : 0;
      String content = String.fromCharCodes(bytes.sublist(searchStart));
      if (!content.contains('%%EOF')) return false;

      return true;
    } catch (e) {
      print('PDF doğrulama hatası: $e');
      return false;
    }
  }

  /// Karakter seti testi
  static Future<void> testUploadCharacterSet({
    required String host,
    required String username,
    required String password,
    int port = 21,
  }) async {
    print('🧪 Upload karakter seti testi...');

    String testName = 'test_ğüişöç.txt';
    String testContent = 'Test içerik - Türkçe karakterler: çğıöşü';

    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(host, user: username, pass: password, port: port);
      if (!(await ftpConnect.connect())) throw Exception('Bağlantı hatası');

      File tempFile = await _createTempFileForUpload(utf8.encode(testContent));

      // Encoding varyantlarını dene
      List<String> variants =
          TurkishCharacterDecoder.generateFtpEncodingVariants(testName);

      for (String variant in variants.take(3)) {
        // İlk 3 varyant
        try {
          bool result = await ftpConnect.uploadFileWithRetry(tempFile,
              pRemoteName: variant);
          if (result) {
            print('✅ Çalışan encoding: "$variant"');
            try {
              await ftpConnect.deleteFile(variant); // Test dosyasını sil
            } catch (e) {}
            break;
          }
        } catch (e) {
          print('❌ Encoding başarısız: "$variant"');
          continue;
        }
      }

      await tempFile.delete();
    } catch (e) {
      print('❌ Test hatası: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {}
    }
  }

  /// Batch upload (birden fazla dosya)
  static Future<Map<String, bool>> batchUpload({
    required String host,
    required String username,
    required String password,
    required Map<String, Uint8List> files, // fileName -> fileBytes
    String directory = '/',
    int port = 21,
    bool overwrite = false,
    Function(String fileName, bool success)? onFileComplete,
  }) async {
    Map<String, bool> results = {};
    int successCount = 0;

    print('📦 Batch upload başlıyor: ${files.length} dosya');

    for (MapEntry<String, Uint8List> entry in files.entries) {
      String fileName = entry.key;
      Uint8List fileBytes = entry.value;

      print('\n📤 Upload: "$fileName" (${fileBytes.length} bytes)');

      bool success = await uploadPdfToFtp(
        host: host,
        username: username,
        password: password,
        pdfBytes: fileBytes,
        fileName: fileName,
        directory: directory,
        port: port,
        overwrite: overwrite,
      );

      results[fileName] = success;
      if (success) successCount++;

      // Callback çağır
      onFileComplete?.call(fileName, success);

      // Dosyalar arası kısa bekleme
      await Future.delayed(Duration(milliseconds: 200));
    }

    print(
        '\n✅ Batch upload tamamlandı: ${successCount}/${files.length} başarılı');
    return results;
  }

  /// Upload progress callback için wrapper
  static Future<bool> uploadWithProgress({
    required String host,
    required String username,
    required String password,
    required Uint8List pdfBytes,
    required String fileName,
    String directory = '/',
    int port = 21,
    bool overwrite = false,
    Function(double progress)? onProgress,
  }) async {
    // Basit progress simulation (gerçek progress FTPConnect'te desteklenmiyor)
    onProgress?.call(0.0);

    bool result = await uploadPdfToFtp(
      host: host,
      username: username,
      password: password,
      pdfBytes: pdfBytes,
      fileName: fileName,
      directory: directory,
      port: port,
      overwrite: overwrite,
    );

    onProgress?.call(result ? 1.0 : 0.0);
    return result;
  }
}
