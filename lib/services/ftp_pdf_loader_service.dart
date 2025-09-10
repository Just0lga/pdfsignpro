import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:pdfsignpro/helpers/ftp_file_size_helper.dart';
import 'package:pdfsignpro/turkish.dart';
import '../models/frontend_models/ftp_file.dart';
import 'pdf_loader_service.dart';

class FtpPdfLoaderService implements PdfLoaderService {
  final String host;
  final String username;
  final String password;
  final String filePath;
  final int port;

  FtpPdfLoaderService({
    required this.host,
    required this.username,
    required this.password,
    required this.filePath,
    required this.port,
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
          timeout: 60,
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

        // Directory parçalarını decode et
        if (directory != '/' && directory.isNotEmpty) {
          List<String> dirParts =
              directory.split('/').where((s) => s.isNotEmpty).toList();
          List<String> decodedDirParts = dirParts
              .map((part) => TurkishCharacterDecoder.pathReplacer(part))
              .toList();
          String decodedDirectory = '/' + decodedDirParts.join('/');

          await ftpConnect.changeDirectory(decodedDirectory);
        }

        // Dosya adı varyantları
        List<String> fileNameVariants =
            TurkishCharacterDecoder.generateFtpEncodingVariants(fileName);

        for (String variant in fileNameVariants) {
          try {
            int trySize = await ftpConnect.sizeFile(variant);
            if (trySize > 0) {
              workingPath = variant;
              fileSize = trySize;
              break;
            }
          } catch (e) {
            continue;
          }
        }
      } else {
        fileSize =
            await FtpFileSizeHelper.getFileSize(ftpConnect, filePath, '/');
        if (fileSize > 0) workingPath = filePath;
      }

      if (fileSize <= 0) throw Exception('Dosya bulunamadı: $filePath');

      tempFile = await _createTempFile();
      bool result = await ftpConnect
          .downloadFileWithRetry(workingPath, tempFile, pRetryCount: 3);

      if (!result) throw Exception('İndirme başarısız');

      Uint8List fileBytes = await tempFile.readAsBytes();

      if (fileBytes.length < 4 ||
          String.fromCharCodes(fileBytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Geçersiz PDF dosyası');
      }

      return fileBytes;
    } catch (e) {
      rethrow;
    } finally {
      try {
        await ftpConnect?.disconnect();
        if (tempFile != null && await tempFile.exists())
          await tempFile.delete();
      } catch (e) {
        // ignore
      }
    }
  }

  Future<File> _createTempFile() async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'ftp_download_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return File('${tempDir.path}/$fileName');
  }

  /// PDF dosyalarını listele - sadeleştirilmiş decode ile
  static Future<List<FtpFile>> listPdfFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    required int port,
  }) async {
    FTPConnect? ftpConnect;
    try {
      print('🔗 FTP PDF listesi başlatılıyor...');
      print('   Host: $host:$port');
      print('   Username: $username');
      print('   Directory: $directory');

      ftpConnect = FTPConnect(host,
          user: username,
          pass: password,
          port: port,
          timeout: 30,
          showLog: true);

      print('🔄 FTP connect çağrılıyor...');
      bool connected = await ftpConnect.connect();
      print('📡 FTP connect sonucu: $connected');

      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı - connect() false döndü');
      }

      print('🔧 Transfer modu ve dizin ayarları...');
      if (directory != '/') {
        print('📁 Dizin değiştiriliyor: $directory');
        await _changeToDirectory(ftpConnect, directory);
      }

      await ftpConnect.setTransferType(TransferType.binary);

      print('📋 Dizin içeriği listeleniyor...');
      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      print('📦 Toplam ${entries.length} dosya/klasör bulundu');

      if (entries.isEmpty) {
        print('⚠️ Dizin boş veya listelenemiyor!');
        return [];
      }

      for (int i = 0; i < entries.length; i++) {
        FTPEntry entry = entries[i];
        print(
            '   [$i] ${_entryTypeToString(entry.type)} - "${entry.name}" (${entry.size} bytes) ${entry.modifyTime}');
      }

      List<FtpFile> pdfFiles = [];
      int pdfCount = 0;
      int skippedCount = 0;

      for (FTPEntry entry in entries) {
        if (entry.type == FTPEntryType.FILE &&
            entry.name.toLowerCase().endsWith('.pdf')) {
          pdfCount++;
          print('\n📄 PDF #$pdfCount işleniyor: "${entry.name}"');
          print('   Entry size: ${entry.size}');
          print('   Entry modifyTime: ${entry.modifyTime}');

          // Basitleştirilmiş decode
          String decodedName = TurkishCharacterDecoder.pathReplacer(entry.name);
          if (decodedName != entry.name) {
            print('   🔄 Decode: "${entry.name}" -> "$decodedName"');
          }

          // Orijinal path (indirme için kullanılacak)
          String originalPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';
          print('   📍 Path: $originalPath');

          // Boyut alma
          int fileSize = FtpFileSizeHelper.getSafeSize(entry);
          print('   📏 Entry\'den boyut: $fileSize');

          if (fileSize <= 0) {
            print(
                '   🔍 Entry\'de geçerli boyut yok, gelişmiş yöntem deneniyor...');
            try {
              fileSize = await FtpFileSizeHelper.getFileSize(
                  ftpConnect, entry.name, directory);
              print('   📏 Gelişmiş yöntemle boyut: $fileSize');
            } catch (e) {
              print('   ❌ Boyut alma hatası: $e');
              fileSize = 0;
            }
          }

          if (fileSize <= 0) {
            print('   ⚠️ Boyut 0 veya negatif, dosya atlanıyor: ${entry.name}');
            skippedCount++;
            continue;
          }

          // FtpFile oluştur
          FtpFile ftpFile = FtpFile(
            name: decodedName, // UI'da decode edilmiş ad göster
            path: originalPath, // İndirme için orijinal path kullan
            size: fileSize,
            modifyTime: entry.modifyTime,
          );

          pdfFiles.add(ftpFile);
          print(
              '   ✅ PDF eklendi: "$decodedName" (${FtpFileSizeHelper.formatFileSize(fileSize)})');
        }
      }

      print('\n🎯 PDF Listeleme Özeti:');
      print('   Toplam dosya/klasör: ${entries.length}');
      print('   PDF dosya sayısı: $pdfCount');
      print('   Başarıyla eklenen: ${pdfFiles.length}');
      print('   Atlanan (boyut sorunu): $skippedCount');

      if (pdfFiles.isEmpty && entries.isNotEmpty) {
        print('⚠️ UYARI: Dosyalar var ama hiç PDF bulunamadı!');
        final nonPdfFiles = entries
            .where((e) =>
                e.type == FTPEntryType.FILE &&
                !e.name.toLowerCase().endsWith('.pdf'))
            .toList();
        if (nonPdfFiles.isNotEmpty) {
          print('   PDF olmayan dosyalar:');
          for (var file in nonPdfFiles.take(5)) {
            print('     - ${file.name}');
          }
        }
      }

      return pdfFiles;
    } catch (e, stackTrace) {
      print('💥 FTP listPdfFiles KRITIK HATA:');
      print('   Hata türü: ${e.runtimeType}');
      print('   Hata mesajı: $e');
      print('   Stack trace: $stackTrace');

      // Özel hata türlerine göre daha açıklayıcı mesajlar
      if (e.toString().contains('SocketException')) {
        throw Exception('FTP sunucuya bağlanılamıyor - Ağ hatası: $e');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('FTP bağlantısı zaman aşımına uğradı: $e');
      } else if (e.toString().contains('Authentication')) {
        throw Exception('FTP kimlik doğrulama hatası: $e');
      } else {
        throw Exception('FTP dosya listesi alınamadı: $e');
      }
    } finally {
      try {
        if (ftpConnect != null) {
          print('🔌 FTP bağlantısı kapatılıyor...');
          await ftpConnect.disconnect();
          print('✅ FTP bağlantısı kapatıldı');
        }
      } catch (e) {
        print('❌ FTP disconnect hatası: $e');
      }
    }
  }

  /// Helper: FTPEntryType'ı string'e çevir
  static String _entryTypeToString(FTPEntryType type) {
    switch (type) {
      case FTPEntryType.FILE:
        return 'FILE';
      case FTPEntryType.DIR:
        return 'DIR';
      case FTPEntryType.LINK:
        return 'LINK';
      default:
        return 'UNKNOWN';
    }
  }

  /// FTP Entry type kontrolü
  static bool _isDirectory(FTPEntryType entryType) {
    return entryType == FTPEntryType.DIR;
  }

  /// Directory değiştirme helper - decoded path kullanır
  static Future<void> _changeToDirectory(
      FTPConnect ftpConnect, String directory) async {
    if (directory == '/') return;

    // Path'i parçalara ayır
    List<String> pathParts =
        directory.split('/').where((s) => s.isNotEmpty).toList();

    // Her klasöre sırayla gir
    for (String part in pathParts) {
      print('📁 Alt klasöre giriliyor (DECODED): "$part"');

      try {
        // Doğrudan decoded adla dizin değiştirmeyi dene
        await ftpConnect.changeDirectory(part);
        print('   ✅ Klasöre girildi (DECODED): "$part"');
      } catch (e) {
        print('   ❌ Decoded ad çalışmadı: "$part", varyantları deneniyor...');

        // Önce listeleme yap ve doğru klasör adını bul
        List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
        String? actualFolderName;

        // Klasör adının varyantlarını kontrol et
        for (FTPEntry entry in entries) {
          if (entry.type == FTPEntryType.DIR) {
            // Decoded hali eşleşiyor mu?
            String decodedEntryName =
                TurkishCharacterDecoder.pathReplacer(entry.name);

            if (decodedEntryName == part) {
              actualFolderName = part; // DECODED ADI KULLAN
              print(
                  '   🔄 Eşleşen klasör bulundu: "${entry.name}" -> decoded: "$part"');
              break;
            }

            // Case-insensitive karşılaştırma
            if (decodedEntryName.toLowerCase() == part.toLowerCase()) {
              actualFolderName = part; // DECODED ADI KULLAN
              print('   🔄 Case-insensitive eşleşme: "$part"');
              break;
            }
          }
        }

        if (actualFolderName != null) {
          await ftpConnect.changeDirectory(actualFolderName);
          print('   ✅ Klasöre girildi (DECODED): "$actualFolderName"');
        } else {
          print('   ❌ Klasör bulunamadı: "$part"');
          print('   📋 Mevcut klasörler:');
          for (FTPEntry entry in entries) {
            if (entry.type == FTPEntryType.DIR) {
              print(
                  '     - "${entry.name}" (decode: "${TurkishCharacterDecoder.pathReplacer(entry.name)}")');
            }
          }
          throw Exception('Klasör bulunamadı: $part');
        }
      }
    }
  }

  /// Güncellenmiş listAllFiles metodu - decoded directory kullanır
  static Future<List<FtpFile>> listAllFiles({
    required String host,
    required String username,
    required String password,
    String directory = '/',
    required int port,
  }) async {
    FTPConnect? ftpConnect;
    try {
      directory = TurkishCharacterDecoder.pathReplacer(directory);

      print('🔗 FTP tüm içerik listesi başlatılıyor...');
      print('📁 Hedef directory (DECODED): "$directory"');

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
        showLog: true,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      // Directory değişimi - decoded path kullan
      if (directory != '/' && directory.isNotEmpty) {
        try {
          await _changeToDirectory(ftpConnect, directory);
          print('✅ Hedef dizine ulaşıldı (DECODED): $directory');
        } catch (e) {
          print('❌ Directory değiştirme hatası: $e');
          // Hata durumunda root'a dön
          try {
            await ftpConnect.changeDirectory('/');
            print('⚠️ Root dizine dönüldü');
            directory = '/';
          } catch (e2) {
            print('❌ Root\'a dönme hatası: $e2');
          }
        }
      }

      await ftpConnect.setTransferType(TransferType.binary);

      // Mevcut dizini kontrol et (debug için)
      try {
        String currentDir = await ftpConnect.currentDirectory();
        print('📍 Mevcut dizin: "$currentDir"');
      } catch (e) {
        print('⚠️ Mevcut dizin alınamadı');
      }

      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      List<FtpFile> allItems = [];

      print('📦 Toplam ${entries.length} item bulundu');

      for (FTPEntry entry in entries) {
        // Skip . and .. entries
        if (entry.name == '.' || entry.name == '..') {
          continue;
        }

        // Path oluşturma - mevcut dizinden devam et
        String fullPath;
        String decodedName = TurkishCharacterDecoder.pathReplacer(entry.name);

        // Mevcut dizin bilgisini kullan
        try {
          String currentDir = await ftpConnect.currentDirectory();
          if (currentDir == '/') {
            fullPath = '/${entry.name}';
          } else {
            fullPath = '$currentDir/${entry.name}';
          }
        } catch (e) {
          // Fallback
          if (directory == '/') {
            fullPath = '/${entry.name}';
          } else {
            fullPath = '$directory/${entry.name}';
          }
        }

        bool isDirectory = _isDirectory(entry.type);

        if (isDirectory) {
          allItems.add(FtpFile(
            name: decodedName, // UI için decode edilmiş
            path: fullPath, // FTP işlemleri için orijinal
            size: 0,
            modifyTime: entry.modifyTime,
            isDirectory: true,
          ));
          print('📁 Klasör: "$decodedName" (orijinal: "${entry.name}")');
        } else if (entry.type == FTPEntryType.FILE) {
          int fileSize = FtpFileSizeHelper.getSafeSize(entry);

          if (fileSize <= 0) {
            try {
              fileSize = await FtpFileSizeHelper.getFileSize(
                  ftpConnect, entry.name, directory);
            } catch (e) {
              fileSize = 0;
            }
          }

          allItems.add(FtpFile(
            name: decodedName, // UI için decode edilmiş
            path: fullPath, // İndirme için orijinal
            size: fileSize,
            modifyTime: entry.modifyTime,
            isDirectory: false,
          ));
          print(
              '📄 Dosya: "$decodedName" (${FtpFileSizeHelper.formatFileSize(fileSize)})');
        }
      }

      print('✅ Toplam ${allItems.length} item listelendi');
      return allItems;
    } catch (e, stackTrace) {
      print('❌ FTP içerik listeleme hatası: $e');
      print('Stack trace: $stackTrace');
      throw Exception('İçerik listesi alınamadı: $e');
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
      }
    }
  }

  /// PDF yükleme - decoded directory kullanır
  static Future<bool> uploadPdfToFtp({
    required String host,
    required String username,
    required String password,
    required Uint8List pdfBytes,
    required String fileName,
    required String directory,
    required int port,
    bool overwrite = false,
  }) async {
    FTPConnect? ftpConnect;
    File? tempFile;

    try {
      print('📤 PDF yükleme başlıyor: "$fileName" (${pdfBytes.length} bytes)');
      print('📁 Hedef directory (DECODED): "$directory"');

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
        showLog: true,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      await ftpConnect.setTransferType(TransferType.binary);

      // Directory'ye git - decoded path kullan
      if (directory != '/' && directory.isNotEmpty) {
        try {
          await _changeToDirectory(ftpConnect, directory);
          print('✅ Hedef directory\'ye geçildi (DECODED): "$directory"');
        } catch (e) {
          print('❌ Directory değiştirme hatası: $e');
          throw Exception('Directory değiştirme başarısız: $e');
        }
      } else {
        print('📁 Ana directory kullanılıyor (/)');
      }

      // Mevcut directory'yi kontrol et
      try {
        String currentDir = await ftpConnect.currentDirectory();
        print('📍 Mevcut çalışma directory: "$currentDir"');
      } catch (e) {
        print('⚠️ Mevcut directory bilgisi alınamadı: $e');
      }

      // Dosya adını hazırla
      String finalFileName = fileName.trim();
      print('🔄 Upload için dosya adı: "$finalFileName"');

      // Dosya mevcut mu kontrol et
      if (!overwrite) {
        try {
          int existingSize = await ftpConnect.sizeFile(finalFileName);
          if (existingSize >= 0) {
            print('⚠️ Dosya zaten mevcut: $finalFileName');
            throw Exception('Dosya zaten mevcut. overwrite: true yapın.');
          }
        } catch (e) {
          // Dosya yoksa normal, devam et
          print('✅ Dosya mevcut değil, upload devam edecek');
        }
      }

      // Geçici dosya oluştur
      tempFile = await _createTempFileForUpload(pdfBytes);

      // Upload işlemi - sadeleştirilmiş encoding varyantları ile
      print('🚀 Upload başlatılıyor...');
      bool uploadResult = await _uploadWithRetryMultipleEncodings(
          ftpConnect, tempFile, finalFileName, pdfBytes.length);

      if (!uploadResult) {
        throw Exception('Dosya yükleme başarısız');
      }

      // Upload sonrası doğrulama
      try {
        int uploadedSize = await ftpConnect.sizeFile(finalFileName);
        if (uploadedSize == pdfBytes.length) {
          print(
              '✅ Upload doğrulandı: $finalFileName (${pdfBytes.length} bytes)');

          // Son kontrol - mevcut directory'deki dosyaları listele
          try {
            List<FTPEntry> files = await ftpConnect.listDirectoryContent();
            bool fileFound = files.any(
                (f) => f.name == finalFileName && f.type == FTPEntryType.FILE);
            if (fileFound) {
              print('✅ Dosya directory\'de başarıyla listeleniyor');
            } else {
              print('⚠️ Dosya upload edildi ama listede görünmüyor');
            }
          } catch (e) {
            print('⚠️ Upload sonrası dosya listesi kontrol edilemedi: $e');
          }
        } else {
          print(
              '❌ Upload doğrulanamadı - boyut uyumsuzluğu: beklenen ${pdfBytes.length}, bulunan $uploadedSize');
          return false;
        }
      } catch (e) {
        print('⚠️ Upload doğrulama hatası: $e');
        // Size kontrolü başarısız olsa da upload başarılı sayabiliriz
      }

      print(
          '✅ PDF başarıyla yüklendi: $finalFileName (${pdfBytes.length} bytes)');
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

  /// FTP'den dosya silme
  static Future<bool> deleteFileFromFtp({
    required String host,
    required String username,
    required String password,
    required String fileName,
    required String directory,
    required int port,
  }) async {
    FTPConnect? ftpConnect;

    try {
      print('🗑️ FTP dosya silme başlıyor: "$fileName"');
      print('📁 Directory (DECODED): "$directory"');

      ftpConnect = FTPConnect(
        host,
        user: username,
        pass: password,
        port: port,
        timeout: 30,
        showLog: true,
      );

      bool connected = await ftpConnect.connect();
      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı');
      }

      // Directory'ye git
      if (directory != '/' && directory.isNotEmpty) {
        try {
          await _changeToDirectory(ftpConnect, directory);
          print('✅ Directory\'ye geçildi: "$directory"');
        } catch (e) {
          print('❌ Directory değiştirme hatası: $e');
          throw Exception('Directory değiştirme başarısız: $e');
        }
      }

      // Dosyayı sil - önce orijinal adla dene
      bool deleted = false;

      try {
        print('🗑️ Silme denemesi: "$fileName"');
        deleted = await ftpConnect.deleteFile(fileName);

        if (deleted) {
          print('✅ Dosya silindi: "$fileName"');
          return true;
        }
      } catch (e) {
        print('❌ İlk silme denemesi başarısız: $e');
      }

      // Orijinal ad başarısız olduysa, encoding varyantlarını dene
      if (!deleted) {
        List<String> variants =
            TurkishCharacterDecoder.generateFtpEncodingVariants(fileName);

        for (String variant in variants) {
          if (variant == fileName) continue; // Zaten denendi

          try {
            print('🗑️ Varyant silme denemesi: "$variant"');
            deleted = await ftpConnect.deleteFile(variant);

            if (deleted) {
              print('✅ Varyant ile dosya silindi: "$variant"');
              return true;
            }
          } catch (e) {
            print('❌ Varyant silme başarısız: "$variant" - $e');
            continue;
          }
        }
      }

      // Son kontrol - dosya gerçekten silinmiş mi?
      if (deleted) {
        try {
          // Dosya boyutunu kontrol et, bulunamayacak
          await ftpConnect.sizeFile(fileName);
          print('⚠️ Dosya hala mevcut görünüyor: $fileName');
          return false;
        } catch (e) {
          // Dosya bulunamadı = başarıyla silindi
          print('✅ Dosya silme doğrulandı: $fileName');
          return true;
        }
      }

      print('❌ Dosya silinemedi: $fileName');
      return false;
    } catch (e) {
      print('❌ FTP dosya silme hatası: $e');
      return false;
    } finally {
      try {
        await ftpConnect?.disconnect();
      } catch (e) {
        print('FTP bağlantı kesme hatası: $e');
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
    // Sadeleştirilmiş encoding varyantları
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
            int uploadedSize = await ftpConnect.sizeFile(remoteName);
            if (uploadedSize >= 0 && uploadedSize == expectedSize) {
              print(
                  '   ✅ Upload doğrulandı: "$remoteName" (${expectedSize} bytes)');
              return true;
            } else {
              print(
                  '   ❌ Boyut uyumsuzluğu - beklenen $expectedSize, yüklenen $uploadedSize');
              try {
                await ftpConnect.deleteFile(remoteName);
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

  /// Sadeleştirilmiş upload encoding varyantları
  static List<String> _generateUploadEncodingVariants(String fileName) {
    List<String> variants = [];

    // 1. Orijinal dosya adı (en yaygın)
    variants.add(fileName);

    // 2. Türkçe karakterler varsa sadece pathEncoder kullan
    if (fileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      String encoded = TurkishCharacterDecoder.pathEncoder(fileName);
      if (encoded != fileName) {
        variants.add(encoded);
      }
    }

    // 3. Boşluk → alt çizgi
    if (fileName.contains(' ')) {
      variants.add(fileName.replaceAll(' ', '_'));
    }

    return variants.take(3).toList(); // Maksimum 3 varyant
  }
}
