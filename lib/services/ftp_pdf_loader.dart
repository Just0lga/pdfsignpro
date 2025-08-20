import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:pdfsignpro/helpers/ftp_file_size_helper.dart';
import 'package:pdfsignpro/turkish.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/frontend_models/ftp_file.dart';
import 'pdf_loader_service.dart';

class FtpPdfLoader implements PdfLoaderService {
  final String host;
  final String username;
  final String password;
  final String filePath;
  final int port;

  FtpPdfLoader({
    required this.host,
    required this.username,
    required this.password,
    required this.filePath,
    this.port = 21,
  });

  @override
  Future<Uint8List?> loadPdf() async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      ftpConnect = FTPConnect(host,
          user: username,
          pass: password,
          port: port,
          timeout: 15,
          showLog: false);

      bool connected = await ftpConnect.connect();
      if (!connected) throw Exception('FTP bağlantısı kurulamadı');

      await ftpConnect.setTransferType(TransferType.binary);

      String workingPath = filePath;
      int fileSize = 0;

      if (filePath.contains('/')) {
        List<String> parts = filePath.split('/');
        String fileName = parts.last;
        String directory = parts.sublist(0, parts.length - 1).join('/');

        // TurkishCharacterDecoder ile encoding varyantları oluştur
        List<String> fileNameVariants =
            TurkishCharacterDecoder.generateFtpEncodingVariants(fileName);

        print('🔄 PDF indirme: "$fileName"');
        print('   ${fileNameVariants.length} encoding varyantı deneniyor...');

        // Her varyantı dene
        for (String variant in fileNameVariants) {
          String tryPath = directory.isEmpty || directory == '/'
              ? '/$variant'
              : '$directory/$variant';

          try {
            int trySize = await ftpConnect.sizeFile(tryPath);
            if (trySize > 0) {
              workingPath = tryPath;
              fileSize = trySize;
              print('✅ Çalışan path bulundu: $tryPath ($fileSize bytes)');
              break;
            }
          } catch (e) {
            print('❌ Path başarısız: $tryPath');
            continue;
          }
        }
      } else {
        // Basit dosya adı için boyut alma
        fileSize =
            await FtpFileSizeHelper.getFileSize(ftpConnect, filePath, '/');
        if (fileSize > 0) workingPath = filePath;
      }

      if (fileSize <= 0) throw Exception('Dosya bulunamadı: $filePath');

      print('📥 İndiriliyor: $workingPath ($fileSize bytes)');

      tempFile = await _createTempFile();
      bool result = await ftpConnect
          .downloadFileWithRetry(workingPath, tempFile, pRetryCount: 3);

      if (!result) throw Exception('İndirme başarısız');

      Uint8List fileBytes = await tempFile.readAsBytes();

      // PDF kontrolü
      if (fileBytes.length < 4 ||
          String.fromCharCodes(fileBytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Geçersiz PDF dosyası');
      }

      print('✅ PDF başarıyla indirildi: ${fileBytes.length} bytes');
      return fileBytes;
    } catch (e) {
      print('❌ FTP hatası: $e');
      rethrow;
    } finally {
      try {
        await ftpConnect?.disconnect();
        if (tempFile != null && await tempFile.exists())
          await tempFile.delete();
      } catch (e) {
        print('Cleanup hatası: $e');
      }
    }
  }

  Future<File> _createTempFile() async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'ftp_download_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return File('${tempDir.path}/$fileName');
  }

  /// PDF dosyalarını listele - iyileştirilmiş boyut alma ile
  static Future<List<FtpFile>> listPdfFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(host,
          user: username,
          pass: password,
          port: port,
          timeout: 8,
          showLog: false);

      bool connected = await ftpConnect.connect();
      if (!connected) throw Exception('FTP bağlantısı kurulamadı');

      if (directory != '/') await ftpConnect.changeDirectory(directory);
      await ftpConnect.setTransferType(TransferType.binary);

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      print('🔍 FTP\'den ${entries.length} dosya bulundu');

      List<FtpFile> pdfFiles = [];

      for (FTPEntry entry in entries) {
        if (entry.type == FTPEntryType.FILE &&
            entry.name.toLowerCase().endsWith('.pdf')) {
          print('\n📄 İşlenen PDF: "${entry.name}"');
          print('   Entry size: ${entry.size}');

          // Decode edilmiş dosya adı
          String decodedName =
              TurkishCharacterDecoder.decodeFileName(entry.name);
          if (decodedName != entry.name) {
            print('   🔄 Decode: "${entry.name}" -> "$decodedName"');
          }

          // Orijinal path (indirme için kullanılacak)
          String originalPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';

          // Boyut alma - önce entry'den, hata durumunda gelişmiş yöntemler
          int fileSize = FtpFileSizeHelper.getSafeSize(entry);

          if (fileSize <= 0) {
            print(
                '   🔍 Entry\'de geçerli boyut yok, gelişmiş yöntem deneniyor...');
            fileSize = await FtpFileSizeHelper.getFileSize(
                ftpConnect, entry.name, directory);

            if (fileSize <= 0) {
              print('   ⚠️ Boyut alınamadı, dosya atlanıyor: ${entry.name}');
              continue;
            }
            print('   ✅ Gelişmiş yöntemle boyut alındı: $fileSize bytes');
          } else {
            print('   ✅ Entry\'den boyut alındı: $fileSize bytes');
          }

          pdfFiles.add(FtpFile(
            name: decodedName, // UI'da decode edilmiş ad göster
            path: originalPath, // İndirme için orijinal path kullan
            size: fileSize,
            modifyTime: entry.modifyTime,
          ));

          print(
              '   ✅ PDF eklendi: "$decodedName" (${FtpFileSizeHelper.formatFileSize(fileSize)})');
        }
      }

      print('\n🎯 Toplam PDF sayısı: ${pdfFiles.length}');

      // Boyutu 0 olan dosyalar varsa uyar
      int zeroSizeFiles = pdfFiles.where((f) => f.size == 0).length;
      if (zeroSizeFiles > 0) {
        print(
            '⚠️  UYARI: ${zeroSizeFiles} adet dosyanın boyutu 0 byte olarak algılandı');
      }

      return pdfFiles;
    } catch (e) {
      print('💥 FTP hatası: $e');
      throw Exception('Dosya listesi alınamadı: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }
    }
  }

  /// Tüm dosyaları listele - iyileştirilmiş boyut alma ile
  static Future<List<FtpFile>> listAllFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    int port = 21,
  }) async {
    FTPConnect? ftpConnect;
    try {
      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 8,
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

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      List<FtpFile> allFiles = [];

      for (FTPEntry entry in entries) {
        if (entry.type == FTPEntryType.FILE) {
          String fullPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';

          // Türkçe karakter decode
          String decodedName =
              TurkishCharacterDecoder.decodeFileName(entry.name);

          // Boyut alma - geliştirilmiş yöntem
          int fileSize = FtpFileSizeHelper.getSafeSize(entry);

          if (fileSize <= 0) {
            fileSize = await FtpFileSizeHelper.getFileSize(
                ftpConnect, entry.name, directory);
          }

          allFiles.add(FtpFile(
            name: decodedName,
            path: fullPath,
            size: fileSize,
            modifyTime: entry.modifyTime,
          ));
        }
      }

      return allFiles;
    } catch (e) {
      print('FTP tüm dosya listeleme hatası: $e');
      throw Exception('Dosya listesi alınamadı: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }
    }
  }

  static Future<bool> verifyPdfFile(Uint8List bytes) async {
    try {
      if (bytes.length < 4) return false;

      String header = String.fromCharCodes(bytes.sublist(0, 4));
      if (header != '%PDF') return false;

      int searchStart = bytes.length > 1024 ? bytes.length - 1024 : 0;
      String content = String.fromCharCodes(bytes.sublist(searchStart));
      if (!content.contains('%%EOF')) return false;

      try {
        final document = sf.PdfDocument(inputBytes: bytes);
        bool isValid = document.pages.count > 0;
        document.dispose();
        return isValid;
      } catch (e) {
        print('PDF doğrulama hatası: $e');
        return false;
      }
    } catch (e) {
      print('PDF doğrulama genel hatası: $e');
      return false;
    }
  }
  // Mevcut FtpPdfLoader sınıfına bu metodu ekleyin

  /// PDF yükleme - FtpUploadHelper kullanarak
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
      bool isValidPdf = await verifyPdfFile(pdfBytes);
      if (!isValidPdf) {
        throw Exception('Geçersiz PDF dosyası');
      }

      print('📤 PDF yükleme başlıyor: "$fileName" (${pdfBytes.length} bytes)');

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
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

      // Dosya adını hazırla
      String finalFileName = fileName.trim();
      print('🔄 Upload için dosya adı: "$finalFileName"');

      String filePath =
          directory == '/' ? '/$finalFileName' : '$directory/$finalFileName';

      // Dosya mevcut mu kontrol et
      if (!overwrite) {
        try {
          int existingSize = await ftpConnect.sizeFile(filePath);
          if (existingSize >= 0) {
            print('⚠️ Dosya zaten mevcut: $filePath');
            throw Exception('Dosya zaten mevcut. overwrite: true yapın.');
          }
        } catch (e) {
          // Dosya yoksa normal, devam et
          print('✅ Dosya mevcut değil, upload devam edecek');
        }
      }

      // Geçici dosya oluştur
      tempFile = await _createTempFileForUpload(pdfBytes);

      // Türkçe karakter desteği ile upload
      bool uploadResult = await _uploadWithRetryMultipleEncodings(
          ftpConnect, tempFile, fileName, pdfBytes.length);

      if (!uploadResult) {
        throw Exception('Dosya yükleme başarısız');
      }

      print('✅ PDF başarıyla yüklendi: $fileName (${pdfBytes.length} bytes)');
      return true;
    } catch (e) {
      print('❌ FTP upload hatası: $e');
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

  // Yardımcı metodlar

  static Future<File> _createTempFileForUpload(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final fileName = 'ftp_upload_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  static Future<bool> _uploadWithRetryMultipleEncodings(FTPConnect ftpConnect,
      File localFile, String originalFileName, int expectedSize) async {
    // Encoding varyantları oluştur
    List<String> encodingVariants =
        _generateUploadEncodingVariants(originalFileName);

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

          try {
            String remotePath = '/$remoteName';
            int uploadedSize = await ftpConnect.sizeFile(remotePath);
            if (uploadedSize >= 0 && uploadedSize == expectedSize) {
              print(
                  '   ✅ Upload doğrulandı: "$remoteName" (${expectedSize} bytes)');
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
          } catch (e) {
            // Size kontrolü başarısız ama upload başarılı
            print('   ⚠️ Boyut kontrolü başarısız ama upload tamamlandı: $e');
            return true; // Upload başarılı sayalım
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

  static List<String> _generateUploadEncodingVariants(String fileName) {
    List<String> variants = [];

    // 1. Orijinal dosya adı (en yaygın)
    variants.add(fileName);

    // 2. Türkçe karakterler varsa encoding dene
    if (fileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      // UTF-8 → Latin-1 (en hızlı ve yaygın)
      try {
        List<int> utf8Bytes = utf8.encode(fileName);
        String latin1Encoded = latin1.decode(utf8Bytes, allowInvalid: true);
        if (latin1Encoded != fileName) {
          variants.add(latin1Encoded);
        }
      } catch (e) {/* ignore */}

      // Manuel hızlı mapping
      String manualEncoded = _fastTurkishEncode(fileName);
      if (manualEncoded != fileName) {
        variants.add(manualEncoded);
      }
    }

    // 3. Boşluk → alt çizgi
    if (fileName.contains(' ')) {
      variants.add(fileName.replaceAll(' ', '_'));
    }

    return variants.take(4).toList();
  }

  static String _fastTurkishEncode(String input) {
    if (!input.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      return input;
    }

    StringBuffer result = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      switch (char) {
        case 'ğ':
          result.write('\u00F0');
          break; // ð
        case 'Ğ':
          result.write('\u00D0');
          break; // Ð
        case 'ı':
          result.write('\u00FD');
          break; // ý
        case 'İ':
          result.write('\u00DD');
          break; // Ý
        case 'ş':
          result.write('\u00FE');
          break; // þ
        case 'Ş':
          result.write('\u00DE');
          break; // Þ
        case 'ç':
          result.write('\u00E7');
          break; // ç
        case 'Ç':
          result.write('\u00C7');
          break; // Ç
        case 'ö':
          result.write('\u00F6');
          break; // ö
        case 'Ö':
          result.write('\u00D6');
          break; // Ö
        case 'ü':
          result.write('\u00FC');
          break; // ü
        case 'Ü':
          result.write('\u00DC');
          break; // Ü
        default:
          result.write(char);
          break;
      }
    }

    return result.toString();
  }
}
