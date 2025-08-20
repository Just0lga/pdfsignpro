import 'dart:convert';
import 'package:ftpconnect/ftpConnect.dart';
import '../turkish.dart';

class FtpFileSizeHelper {
  /// Türkçe karakterli dosyalar için gelişmiş boyut alma
  static Future<int> getFileSize(
      FTPConnect ftpConnect, String originalFileName, String directory) async {
    print('🔍 Boyut alma işlemi başlıyor: "$originalFileName"');

    // SIZE komutu ile farklı encoding'leri dene (daha hızlı)
    List<String> variants =
        _generateSizeCommandVariants(originalFileName, directory);

    for (String path in variants) {
      try {
        // Binary moda geç
        await ftpConnect.setTransferType(TransferType.binary);
        int size = await ftpConnect.sizeFile(path);
        if (size > 0) {
          print('✅ SIZE komutu ile boyut alındı: $path -> $size bytes');
          return size;
        }
      } catch (e) {
        print(
            '❌ SIZE komutu başarısız: $path - ${e.toString().substring(0, 50)}...');
        continue;
      }
    }

    // Backup: Listeleme ile boyut alma (daha yavaş ama güvenilir)
    try {
      print('📋 Listeleme ile boyut alma deneniyor...');
      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();

      // Orijinal dosya adı ile eşleşen entry'yi bul
      for (FTPEntry entry in entries) {
        if (entry.name == originalFileName &&
            entry.size != null &&
            entry.size! > 0) {
          print(
              '✅ Listeleme ile boyut alındı: ${originalFileName} -> ${entry.size} bytes');
          return entry.size!;
        }
      }

      // Encode/decode varyantları ile eşleştir
      for (String variant in variants.map((p) => p.split('/').last)) {
        for (FTPEntry entry in entries) {
          if (entry.name == variant && entry.size != null && entry.size! > 0) {
            print(
                '✅ Listeleme ile boyut alındı (varyant): ${variant} -> ${entry.size} bytes');
            return entry.size!;
          }
        }
      }
    } catch (e) {
      print('📋 Listeleme ile boyut alma başarısız: $e');
    }

    print('⚠️ Hiçbir yöntemle boyut alınamadı: $originalFileName');
    return 0;
  }

  /// SIZE komutu için encoding varyantları oluştur
  static List<String> _generateSizeCommandVariants(
      String originalFileName, String directory) {
    String basePath = directory == '/' ? '' : directory;

    // TurkishCharacterDecoder kullanarak varyantları al
    List<String> fileNameVariants =
        TurkishCharacterDecoder.generateFtpEncodingVariants(originalFileName);

    // Her varyant için full path oluştur
    List<String> pathVariants =
        fileNameVariants.map((fileName) => '$basePath/$fileName').toList();

    print('📝 Toplam ${pathVariants.length} boyut alma varyantı oluşturuldu');
    for (int i = 0; i < pathVariants.length; i++) {
      print('   ${i + 1}. ${pathVariants[i].split('/').last}');
    }

    return pathVariants;
  }

  /// FTPEntry'den güvenli boyut alma
  static int getSafeSize(FTPEntry entry) {
    if (entry.size != null && entry.size! > 0) {
      return entry.size!;
    }
    return 0;
  }

  /// Boyut formatı (KB, MB)
  static String formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';

    const List<String> units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  /// Birden fazla dosya için batch boyut alma
  static Future<Map<String, int>> getBatchFileSizes(
      FTPConnect ftpConnect, List<String> fileNames, String directory) async {
    Map<String, int> results = {};

    print('📦 Batch boyut alma başlıyor: ${fileNames.length} dosya');

    for (String fileName in fileNames) {
      int size = await getFileSize(ftpConnect, fileName, directory);
      results[fileName] = size;

      // Kısa bekleme (FTP sunucu yükünü azaltmak için)
      await Future.delayed(Duration(milliseconds: 50));
    }

    int successCount = results.values.where((size) => size > 0).length;
    print(
        '✅ Batch sonucu: ${successCount}/${fileNames.length} dosyanın boyutu alındı');

    return results;
  }

  /// FTP sunucusunun karakter encoding desteğini test et
  static Future<String?> detectServerEncoding(
      FTPConnect ftpConnect, String testFileName) async {
    List<String> encodingTests = [
      'UTF-8',
      'Windows-1254',
      'ISO-8859-9',
      'Latin-1'
    ];

    print('🧪 Sunucu encoding testi: "$testFileName"');

    for (String encoding in encodingTests) {
      try {
        // Encoding'e göre dosya adını dönüştür ve SIZE komutu dene
        String encodedFileName = _encodeFileName(testFileName, encoding);
        int size = await ftpConnect.sizeFile('/$encodedFileName');

        if (size >= 0) {
          print('✅ Çalışan encoding: $encoding');
          return encoding;
        }
      } catch (e) {
        continue;
      }
    }

    print('❌ Hiçbir encoding çalışmadı');
    return null;
  }

  /// Encoding'e göre dosya adını dönüştür
  static String _encodeFileName(String fileName, String encoding) {
    switch (encoding) {
      case 'UTF-8':
        return fileName; // Zaten UTF-8
      case 'Windows-1254':
        return TurkishCharacterDecoder.encodeForWindows1254(fileName);
      case 'ISO-8859-9':
        // ISO-8859-9 encoding (basit versiyonu)
        return fileName.replaceAllMapped(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'), (match) {
          Map<String, String> isoMap = {
            'ç': '\u00E7',
            'Ç': '\u00C7',
            'ğ': '\u011F',
            'Ğ': '\u011E',
            'ı': '\u0131',
            'İ': '\u0130',
            'ö': '\u00F6',
            'Ö': '\u00D6',
            'ş': '\u015F',
            'Ş': '\u015E',
            'ü': '\u00FC',
            'Ü': '\u00DC',
          };
          return isoMap[match.group(0)] ?? match.group(0)!;
        });
      case 'Latin-1':
        try {
          List<int> utf8Bytes = utf8.encode(fileName);
          return latin1.decode(utf8Bytes, allowInvalid: true);
        } catch (e) {
          return fileName;
        }
      default:
        return fileName;
    }
  }

  /// Debug: Dosya boyutlarını karşılaştır
  static Future<void> debugFileSizes(
      FTPConnect ftpConnect, String fileName, String directory) async {
    print('\n🔍 Debug: Dosya boyutu karşılaştırması');
    print('Dosya: "$fileName"');

    // 1. SIZE komutu ile deneme
    List<String> variants = _generateSizeCommandVariants(fileName, directory);
    print('\n📏 SIZE komutu sonuçları:');
    for (String path in variants) {
      try {
        int size = await ftpConnect.sizeFile(path);
        print('   ✅ $path -> $size bytes');
      } catch (e) {
        print('   ❌ $path -> HATA');
      }
    }

    // 2. Listeleme ile karşılaştırma
    try {
      print('\n📋 Listeleme sonuçları:');
      List<FTPEntry> entries = await ftpConnect.listDirectoryContent();

      for (FTPEntry entry in entries) {
        if (entry.name.toLowerCase().endsWith('.pdf')) {
          print('   📄 "${entry.name}" -> ${entry.size ?? 'NULL'} bytes');
        }
      }
    } catch (e) {
      print('   ❌ Listeleme hatası: $e');
    }
  }
}
