import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ftpconnect/ftpConnect.dart';
import 'package:pdfsignpro/helpers/ftp_file_size_helper.dart';
import 'package:pdfsignpro/turkish.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
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

  /// ✅ Geliştirilmiş PDF dosyalarını listele - detaylı debug ile
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
          showLog: true); // ✅ Debug için true

      print('🔄 FTP connect çağrılıyor...');
      bool connected = await ftpConnect.connect();
      print('📡 FTP connect sonucu: $connected');

      if (!connected) {
        throw Exception('FTP bağlantısı kurulamadı - connect() false döndü');
      }

      print('🔧 Transfer modu ve dizin ayarları...');
      if (directory != '/') {
        print('📁 Dizin değiştiriliyor: $directory');
        await ftpConnect.changeDirectory(directory);
      }

      await ftpConnect.setTransferType(TransferType.binary);

      print('📋 Dizin içeriği listeleniyor...');
      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
      print('📦 Toplam ${entries.length} dosya/klasör bulundu');

      // ✅ Tüm entries'leri detaylı log
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

          // Decode edilmiş dosya adı
          String decodedName =
              TurkishCharacterDecoder.decodeFileName(entry.name);
          if (decodedName != entry.name) {
            print('   🔄 Decode: "${entry.name}" -> "$decodedName"');
          }

          // Orijinal path (indirme için kullanılacak)
          String originalPath =
              directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';
          print('   📍 Path: $originalPath');

          // Boyut alma - geliştirilmiş yöntemle
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
        // PDF olmayan dosyaları göster
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

  /// ✅ Helper: FTPEntryType'ı string'e çevir
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

  /// FTP Entry type kontrolü - boolean bazlı
static bool _isDirectory(FTPEntryType entryType) {
  return entryType == FTPEntryType.DIR;
}

/// Güncellenmiş listAllFiles metodu
static Future<List<FtpFile>> listAllFiles({
  required String host,
  required String username,
  required String password,
  String directory = '/',
  required int port,
}) async {
  FTPConnect? ftpConnect;
  try {
    print('🔗 FTP tüm içerik listesi başlatılıyor...');

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

    if (directory != '/') {
      await ftpConnect.changeDirectory(directory);
    }

    await ftpConnect.setTransferType(TransferType.binary);

    List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
    List<FtpFile> allItems = [];

    print('📦 Toplam ${entries.length} item bulundu');

    for (FTPEntry entry in entries) {
      String fullPath = directory == '/' ? '/${entry.name}' : '$directory/${entry.name}';
      String decodedName = TurkishCharacterDecoder.decodeFileName(entry.name);
      
      bool isDirectory = _isDirectory(entry.type);

      if (isDirectory) {
        // Klasör ekleme
        allItems.add(FtpFile(
          name: decodedName,
          path: fullPath,
          size: 0, // Klasörler için boyut 0
          modifyTime: entry.modifyTime,
          isDirectory: true, // FtpFile'a isDirectory field ekle
        ));
        print('📁 Klasör eklendi: "$decodedName"');
      } 
      else if (entry.type == FTPEntryType.FILE) {
        // Dosya ekleme
        int fileSize = FtpFileSizeHelper.getSafeSize(entry);

        if (fileSize <= 0) {
          try {
            fileSize = await FtpFileSizeHelper.getFileSize(
                ftpConnect, entry.name, directory);
          } catch (e) {
            print('Boyut alma hatası (${entry.name}): $e');
            fileSize = 0;
          }
        }

        allItems.add(FtpFile(
          name: decodedName,
          path: fullPath,
          size: fileSize,
          modifyTime: entry.modifyTime,
          isDirectory: false,
        ));
        print('📄 Dosya eklendi: "$decodedName" (${FtpFileSizeHelper.formatFileSize(fileSize)})');
      }
    }

    print('✅ Toplam ${allItems.length} item listelendi (dosya + klasör)');
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

/// PDF yükleme - Directory handling düzeltilmiş versiyon
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
    print('📁 Hedef directory: "$directory"');

    ftpConnect = FTPConnect(
      host,
      user: username,
      pass: password,
      port: port,
      timeout: 30,
      showLog: true, // Debug için true
    );

    bool connected = await ftpConnect.connect();
    if (!connected) {
      throw Exception('FTP bağlantısı kurulamadı');
    }

    await ftpConnect.setTransferType(TransferType.binary);

    // Directory'yi düzgün şekilde ayarla
    String normalizedDirectory = directory.trim();
    
    // Boş veya sadece "/" değilse directory'ye git
    if (normalizedDirectory.isNotEmpty && normalizedDirectory != '/') {
      // Başlangıçtaki / karakterini temizle
      if (normalizedDirectory.startsWith('/')) {
        normalizedDirectory = normalizedDirectory.substring(1);
      }
      
      // Sonundaki / karakterini temizle
      if (normalizedDirectory.endsWith('/')) {
        normalizedDirectory = normalizedDirectory.substring(0, normalizedDirectory.length - 1);
      }

      print('🔄 Directory değiştiriliyor: "$normalizedDirectory"');
      
      try {
        // Directory'yi parçalara böl ve her parçayı kontrol et
        List<String> dirParts = normalizedDirectory.split('/');
        String currentPath = '/';
        
        for (String part in dirParts) {
          if (part.trim().isEmpty) continue;
          
          currentPath = currentPath.endsWith('/') ? '$currentPath$part' : '$currentPath/$part';
          
          try {
            // Directory'nin var olup olmadığını kontrol et
            List<FTPEntry> entries = await ftpConnect.listDirectoryContent();
            bool dirExists = entries.any((entry) => 
              entry.type == FTPEntryType.DIR && entry.name == part);
            
            if (!dirExists) {
              print('📁 Directory oluşturuluyor: "$part"');
              await ftpConnect.makeDirectory(part);
            }
            
            print('📁 Directory değiştiriliyor: "$part"');
            await ftpConnect.changeDirectory(part);
            
          } catch (e) {
            print('❌ Directory işlemi hatası ($part): $e');
            // Directory yoksa oluşturmayı dene
            try {
              await ftpConnect.makeDirectory(part);
              await ftpConnect.changeDirectory(part);
              print('✅ Directory oluşturuldu ve değiştirildi: "$part"');
            } catch (createError) {
              print('❌ Directory oluşturulamadı: $createError');
              throw Exception('Directory işlemi başarısız: $part');
            }
          }
        }
        
        print('✅ Hedef directory\'ye geçildi: "$normalizedDirectory"');
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

    // Upload işlemi
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
        print('✅ Upload doğrulandı: $finalFileName (${pdfBytes.length} bytes)');
        
        // Son kontrol - mevcut directory'deki dosyaları listele
        try {
          List<FTPEntry> files = await ftpConnect.listDirectoryContent();
          bool fileFound = files.any((f) => f.name == finalFileName && f.type == FTPEntryType.FILE);
          if (fileFound) {
            print('✅ Dosya directory\'de başarıyla listeleniyor');
          } else {
            print('⚠️ Dosya upload edildi ama listede görünmüyor');
          }
        } catch (e) {
          print('⚠️ Upload sonrası dosya listesi kontrol edilemedi: $e');
        }
        
      } else {
        print('❌ Upload doğrulanamadı - boyut uyumsuzluğu: beklenen ${pdfBytes.length}, bulunan $uploadedSize');
        return false;
      }
    } catch (e) {
      print('⚠️ Upload doğrulama hatası: $e');
      // Size kontrolü başarısız olsa da upload başarılı sayabiliriz
    }

    print('✅ PDF başarıyla yüklendi: $finalFileName (${pdfBytes.length} bytes)');
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
}}