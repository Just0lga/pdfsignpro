import 'dart:convert';
import 'package:ftpconnect/ftpConnect.dart';
import '../turkish.dart';

class FtpFileSizeHelper {
  /// Türkçe karakterli dosyalar için gelişmiş boyut alma
  static Future<int> getFileSize(
      FTPConnect ftpConnect, String originalFileName, String directory) async {
    print('🔍 Boyut alma işlemi başlıyor: "$originalFileName"');
    print('🔍 Boyut alma işlemi başlıyor: "$directory"');

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

  /// SIZE komutu için encoding varyantları oluştur - basitleştirilmiş
  static List<String> _generateSizeCommandVariants(
      String originalFileName, String directory) {
    String basePath = directory == '/' ? '' : directory;

    // Sadece 3 varyant: orijinal, decode, encode
    List<String> fileNameVariants = [
      originalFileName,
      TurkishCharacterDecoder.pathReplacer(originalFileName),
      TurkishCharacterDecoder.pathEncoder(originalFileName),
    ];

    // Duplikatları kaldır
    fileNameVariants = fileNameVariants.toSet().toList();

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
}
