import 'dart:convert';

class TurkishCharacterDecoder {
  // Ana decode fonksiyonu - birden fazla yöntemi sırayla dener
  static String decodeFileName(String fileName) {
    print('🔄 Decode başlangıcı: "$fileName"');

    // Önce hızlı kontrol - zaten Türkçe karakterler düzgünse dokunma
    if (_isTurkishTextClean(fileName)) {
      print('✅ Türkçe metin zaten temiz: "$fileName"');
      return fileName;
    }

    List<String> attempts = [];

    // 1. Orijinal dosya adı
    attempts.add(fileName);

    // 2. Agresif manuel patterns (en yaygın FTP sorunları)
    String aggressiveResult = _tryAggressivePatternDecode(fileName);
    if (aggressiveResult != fileName) attempts.add(aggressiveResult);

    // 3. Windows-1254 (Türkçe) decode
    String windows1254Result = _tryWindows1254Decode(fileName);
    if (windows1254Result != fileName) attempts.add(windows1254Result);

    // 4. ISO-8859-9 (Latin-5 Türkçe) decode
    String iso88599Result = _tryISO88599Decode(fileName);
    if (iso88599Result != fileName) attempts.add(iso88599Result);

    // 5. CP1252 (Windows Latin) decode
    String cp1252Result = _tryCP1252Decode(fileName);
    if (cp1252Result != fileName) attempts.add(cp1252Result);

    // 6. Byte-by-byte manual decode
    String manualResult = _tryManualDecode(fileName);
    if (manualResult != fileName) attempts.add(manualResult);

    // 7. UTF-8 malformed repair
    String utf8Result = _tryUTF8Repair(fileName);
    if (utf8Result != fileName) attempts.add(utf8Result);

    // 8. URL decode denemeleri
    String urlResult = _tryURLDecode(fileName);
    if (urlResult != fileName) attempts.add(urlResult);

    // 9. Latin-1 byte decode (FTP'de yaygın)
    String latin1Result = _tryLatin1ByteDecode(fileName);
    if (latin1Result != fileName) attempts.add(latin1Result);

    // En iyi sonucu seç
    String bestResult = _selectBestResult(attempts);
    print('✅ En iyi sonuç: "$bestResult"');

    return bestResult;
  }

  // Yeni: Türkçe metnin temiz olup olmadığını kontrol et
  static bool _isTurkishTextClean(String text) {
    // Türkçe karakterler mevcut ve bozuk karakter yok
    final turkishChars = RegExp(r'[çğıöşüÇĞIİÖŞÜ]');
    final badChars = RegExp(r'[ÄÅÃ�]');

    bool hasTurkish = turkishChars.hasMatch(text);
    bool hasBadChars = badChars.hasMatch(text);

    return hasTurkish && !hasBadChars;
  }

  // Yeni: Agresif pattern matching (en yaygın FTP sorunları için)
  static String _tryAggressivePatternDecode(String input) {
    String result = input;

    // En yaygın FTP encoding sorunları - spesifik patterns
    final Map<String, String> aggressivePatterns = {
      // Tam kelime patterns
      'gÃ¼iÅÃ§Ã¶': 'güişçö',
      'gÃ¼ÄÅÃ§Ã¶': 'güışçö',
      'TahsÄÂ±lat': 'Tahsilat',
      'Ã\u0096rnek': 'Örnek',
      'belÃ\u00BCt': 'belüt',
      'Ã¼Ã§': 'üç',
      'Ä±ÅÃ§': 'ışç',
      'gÃ¼': 'gü',
      'ÄÅ': 'ış',
      'Ã§Ã¶': 'çö',

      // Tek karakter sorunları
      'Ã¼': 'ü',
      'Ã§': 'ç',
      'Ã¶': 'ö',
      'ÄŸ': 'ğ',
      'Ä±': 'ı',
      'Åž': 'Ş',
      'Å': 'ş',
      'Ä°': 'İ',
      'Ã‡': 'Ç',
      'Ã–': 'Ö',
      'Ãœ': 'Ü',
      'Ä': 'ğ',

      // Özel byte sequences
      '\u00C3\u00BC': 'ü',
      '\u00C3\u00A7': 'ç',
      '\u00C3\u00B6': 'ö',
      '\u00C4\u009F': 'ğ',
      '\u00C4\u00B1': 'ı',
      '\u00C5\u009F': 'ş',

      // Hexadecimal
      'Ãü': 'ü',
      'Ã§': 'ç',
      'Ã¶': 'ö',
    };

    // En uzun pattern'ler önce işlensin
    List<String> sortedKeys = aggressivePatterns.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String pattern in sortedKeys) {
      if (result.contains(pattern)) {
        String oldResult = result;
        result = result.replaceAll(pattern, aggressivePatterns[pattern]!);
        if (result != oldResult) {
          print(
              '   Agresif pattern: "$pattern" -> "${aggressivePatterns[pattern]}"');
        }
      }
    }

    return result;
  }

  // Yeni: Latin-1 byte düzeyinde decode
  static String _tryLatin1ByteDecode(String input) {
    try {
      List<int> bytes = [];

      // String'i byte array'e çevir
      for (int i = 0; i < input.length; i++) {
        int code = input.codeUnitAt(i);
        bytes.add(code > 255 ? code & 0xFF : code);
      }

      // Latin-1 olarak decode et, sonra UTF-8 olarak yorumla
      String latin1String = latin1.decode(bytes);

      // Türkçe karakter mapping
      final Map<String, String> latin1TurkishMap = {
        'ÃŸ': 'ş',
        'Ã°': 'ğ',
        'Ãœ': 'Ü',
        'Ã¼': 'ü',
        'Ã§': 'ç',
        'Ã‡': 'Ç',
        'Ã¶': 'ö',
        'Ã–': 'Ö',
        'Ä±': 'ı',
        'Ä°': 'İ',
      };

      String result = latin1String;
      latin1TurkishMap.forEach((key, value) {
        result = result.replaceAll(key, value);
      });

      return result;
    } catch (e) {
      return input;
    }
  }

  // Windows-1254 (Türkçe) karakter seti decode
  static String _tryWindows1254Decode(String input) {
    try {
      // Windows-1254 karakter haritası
      final Map<int, String> windows1254Map = {
        0x80: '€',
        0x82: '‚',
        0x83: 'ƒ',
        0x84: '„',
        0x85: '…',
        0x86: '†',
        0x87: '‡',
        0x88: 'ˆ',
        0x89: '‰',
        0x8A: 'Š',
        0x8B: '‹',
        0x8C: 'Œ',
        0x91: ''', 0x92: ''',
        0x93: '"',
        0x94: '"',
        0x95: '•',
        0x96: '–',
        0x97: '—',
        0x98: '˜',
        0x99: '™',
        0x9A: 'š',
        0x9B: '›',
        0x9C: 'œ',
        0x9F: 'Ÿ',
        0xD0: 'Ğ',
        0xDD: 'İ',
        0xDE: 'Ş',
        0xF0: 'ğ',
        0xFD: 'ı',
        0xFE: 'ş'
      };

      List<int> bytes = latin1.encode(input);
      StringBuffer result = StringBuffer();

      for (int byte in bytes) {
        if (windows1254Map.containsKey(byte)) {
          result.write(windows1254Map[byte]);
        } else if (byte >= 32 && byte <= 126) {
          result.write(String.fromCharCode(byte));
        } else if (byte >= 160) {
          result.write(String.fromCharCode(byte));
        } else {
          result.write(String.fromCharCode(byte));
        }
      }

      return result.toString();
    } catch (e) {
      return input;
    }
  }

  // ISO-8859-9 (Latin-5) decode
  static String _tryISO88599Decode(String input) {
    try {
      final Map<int, String> iso88599Map = {
        0xD0: 'Ğ',
        0xDD: 'İ',
        0xDE: 'Ş',
        0xF0: 'ğ',
        0xFD: 'ı',
        0xFE: 'ş'
      };

      List<int> bytes = latin1.encode(input);
      StringBuffer result = StringBuffer();

      for (int byte in bytes) {
        if (iso88599Map.containsKey(byte)) {
          result.write(iso88599Map[byte]);
        } else {
          result.write(String.fromCharCode(byte));
        }
      }

      return result.toString();
    } catch (e) {
      return input;
    }
  }

  // CP1252 (Windows Latin-1) decode
  static String _tryCP1252Decode(String input) {
    try {
      final Map<int, String> cp1252Map = {
        0x80: '€',
        0x82: '‚',
        0x83: 'ƒ',
        0x84: '„',
        0x85: '…',
        0x86: '†',
        0x87: '‡',
        0x88: 'ˆ',
        0x89: '‰',
        0x8A: 'Š',
        0x8B: '‹',
        0x8C: 'Œ',
        0x8E: 'Ž',
        0x91: ''', 0x92: ''',
        0x93: '"',
        0x94: '"',
        0x95: '•',
        0x96: '–',
        0x97: '—',
        0x98: '˜',
        0x99: '™',
        0x9A: 'š',
        0x9B: '›',
        0x9C: 'œ',
        0x9E: 'ž',
        0x9F: 'Ÿ'
      };

      List<int> bytes = latin1.encode(input);
      StringBuffer result = StringBuffer();

      for (int byte in bytes) {
        if (cp1252Map.containsKey(byte)) {
          result.write(cp1252Map[byte]);
        } else {
          result.write(String.fromCharCode(byte));
        }
      }

      return result.toString();
    } catch (e) {
      return input;
    }
  }

  // Manuel karakter değiştirme
  static String _tryManualDecode(String input) {
    String result = input;

    // Yaygın bozuk karakter patterns
    final Map<String, String> patterns = {
      // Çok karakterli patterns (önce bunları kontrol et)
      'Ä±Å': 'ış',
      'Ã¼Ã§': 'üç',
      'Ã§Ä±': 'çı',
      'Å ': 'ş ',
      'ÄŸ': 'ğ',
      'Äž': 'ğ',
      'Å¾': 'ş',

      // Tek karakterli replacements
      'Ä±': 'ı',
      'Å': 'ş',
      'Ã§': 'ç',
      'Ã¼': 'ü',
      'Ã¶': 'ö',
      'Ä': 'ğ',
      'Ä°': 'İ',
      'Åž': 'Ş',
      'Ã‡': 'Ç',
      'Ãœ': 'Ü',
      'Ã–': 'Ö',

      // Hex patterns
      'Â': '', // Sık görülen gereksiz karakter
      '': '', // NULL karakter

      // Specific problematic sequences
      'Ã¼\u009F': 'ü',
      'Ã§\u009F': 'ç',
      'Ã¶\u009F': 'ö',
    };

    // Uzun patterns önce işlensin
    List<String> sortedKeys = patterns.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String pattern in sortedKeys) {
      result = result.replaceAll(pattern, patterns[pattern]!);
    }

    // Dikdörtgen içinde X karakterlerini temizle
    result = result.replaceAll(RegExp(r'[\uFFFD\uFEFF\u00AD]'), '');

    return result;
  }

  // UTF-8 onarım denemesi
  static String _tryUTF8Repair(String input) {
    try {
      // Önce Latin-1 olarak encode et, sonra UTF-8 olarak decode et
      List<int> latin1Bytes = latin1.encode(input);
      String utf8Result = utf8.decode(latin1Bytes, allowMalformed: true);

      // Eğer sonuç farklıysa ve daha iyi görünüyorsa kullan
      if (utf8Result != input && !utf8Result.contains('�')) {
        return utf8Result;
      }
    } catch (e) {
      // Ignore
    }

    try {
      // UTF-8 bytes'ı onar
      List<int> inputBytes = input.codeUnits;
      return utf8.decode(inputBytes, allowMalformed: true);
    } catch (e) {
      return input;
    }
  }

  // URL decode denemeleri
  static String _tryURLDecode(String input) {
    String result = input;

    try {
      // Normal URL decode
      String decoded = Uri.decodeComponent(input);
      if (decoded != input && !decoded.contains('�')) {
        result = decoded;
      }
    } catch (e) {
      // Ignore
    }

    try {
      // Percent-encoded Türkçe karakterleri manuel decode
      result = result.replaceAllMapped(RegExp(r'%[0-9A-Fa-f]{2}'), (match) {
        try {
          int value = int.parse(match.group(0)!.substring(1), radix: 16);
          return String.fromCharCode(value);
        } catch (e) {
          return match.group(0)!;
        }
      });
    } catch (e) {
      // Ignore
    }

    return result;
  }

  // En iyi sonucu seç
  static String _selectBestResult(List<String> attempts) {
    if (attempts.isEmpty) return '';

    String best = attempts.first;
    int bestScore = _calculateTurkishScore(best);

    print('🎯 Sonuç karşılaştırması:');
    for (String attempt in attempts) {
      int score = _calculateTurkishScore(attempt);
      print('   "$attempt" -> Skor: $score');

      if (score > bestScore) {
        best = attempt;
        bestScore = score;
      }
    }

    return best;
  }

  // Geliştirilmiş Türkçe karakter kalitesi skorlama
  static int _calculateTurkishScore(String text) {
    int score = 0;

    // Türkçe karakterler +5 puan (artırıldı)
    final turkishChars = [
      'ı',
      'ş',
      'ç',
      'ü',
      'ö',
      'ğ',
      'İ',
      'Ş',
      'Ç',
      'Ü',
      'Ö',
      'Ğ'
    ];
    for (String char in turkishChars) {
      score += char.allMatches(text).length * 5;
    }

    // Normal ASCII karakterler +1 puan
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          (code >= 48 && code <= 57)) {
        score += 1;
      }
    }

    // Kötü karakterler -10 puan (artırıldı)
    final badChars = ['Ä', 'Å', 'Ã', '�', '', '\uFFFD', '?'];
    for (String char in badChars) {
      score -= char.allMatches(text).length * 10;
    }

    // Çok uzun veya çok kısa metinler için ceza
    if (text.length < 2) score -= 5;
    if (text.length > 50) score -= 3;

    // Sadece ASCII karakterler varsa bonus (doğru decode'lanmış olabilir)
    bool hasOnlyAsciiAndTurkish = true;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code > 127 && !turkishChars.contains(text[i])) {
        hasOnlyAsciiAndTurkish = false;
        break;
      }
    }
    if (hasOnlyAsciiAndTurkish) score += 10;

    return score;
  }

  // Debug için - karakter kodlarını göster
  static void debugCharacterCodes(String text) {
    print('🔍 Karakter analizi: "$text"');
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      String char = text[i];
      print(
          '   [$i] "$char" = U+${code.toRadixString(16).padLeft(4, '0').toUpperCase()} (${code})');
    }
  }

  // Debug: Karakter kodları analizi - detaylı
  static void analyzeCharacterCodes(String text, {String? label}) {
    print('🔍 ${label ?? 'Karakter'} analizi: "$text"');
    for (int i = 0; i < text.length && i < 20; i++) {
      // İlk 20 karakter
      int code = text.codeUnitAt(i);
      String char = text[i];
      String hex = code.toRadixString(16).padLeft(4, '0').toUpperCase();
      String type = '';

      if (code >= 65 && code <= 90)
        type = ' (ASCII Büyük)';
      else if (code >= 97 && code <= 122)
        type = ' (ASCII Küçük)';
      else if (code >= 48 && code <= 57)
        type = ' (Rakam)';
      else if ('çğıöşüÇĞIİÖŞÜ'.contains(char))
        type = ' (Türkçe)';
      else if (code > 127) type = ' (Non-ASCII)';

      print('   [$i] "$char" = U+$hex ($code)$type');
    }
  }

  // Test fonksiyonu
  static void testDecoding() {
    List<String> testCases = [
      'satÄ±Å.pdf',
      'Ã¶rnek_dosya.pdf',
      'Ã¼Ã§Ã¼ncÃ¼_ÄŸÃ¼n.pdf',
      'test_Ä±Å_ç.pdf',
      'türkçe%20dosya.pdf',
      'gÃ¼iÅÃ§Ã¶', // Özel test case
    ];

    print('🧪 Test başlangıcı:');
    for (String testCase in testCases) {
      print('\n--- Test: "$testCase" ---');
      debugCharacterCodes(testCase);
      String result = decodeFileName(testCase);
      print('✅ Sonuç: "$result"');
    }
  }

  // FTP için özel encoding varyantları oluştur
  static List<String> generateFtpEncodingVariants(String fileName) {
    List<String> variants = [];

    print('🔄 Encoding varyantları oluşturuluyor: "$fileName"');

    // 1. Orijinal dosya/klasör adı (en yaygın)
    variants.add(fileName);

    // 2. Ana decode fonksiyonu ile tersten encode edilmiş
    String decoded = decodeFileName(fileName);
    if (decoded != fileName) {
      variants.add(decoded);
      print('   Decode sonucu: "$decoded"');
    }

    // 3. Türkçe karakterler varsa ek encoding'ler
    if (fileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]')) ||
        decoded.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      // UTF-8 → Latin-1 dönüşümü (klasörler için çok kritik)
      try {
        List<int> utf8Bytes = utf8.encode(fileName);
        String latin1Str = latin1.decode(utf8Bytes, allowInvalid: true);
        if (latin1Str != fileName && !variants.contains(latin1Str)) {
          variants.add(latin1Str);
          print('   UTF8->Latin1: "$latin1Str"');
        }
      } catch (e) {
        print('   UTF8->Latin1 hatası: $e');
      }

      // Decode edilmiş için de UTF-8 → Latin-1
      if (decoded != fileName) {
        try {
          List<int> utf8Bytes = utf8.encode(decoded);
          String latin1Str = latin1.decode(utf8Bytes, allowInvalid: true);
          if (latin1Str != decoded &&
              latin1Str != fileName &&
              !variants.contains(latin1Str)) {
            variants.add(latin1Str);
            print('   Decoded UTF8->Latin1: "$latin1Str"');
          }
        } catch (e) {
          print('   Decoded UTF8->Latin1 hatası: $e');
        }
      }

      // Windows-1254 benzeri encoding (klasörler için)
      String winEncoded = encodeForWindows1254(fileName);
      if (winEncoded != fileName && !variants.contains(winEncoded)) {
        variants.add(winEncoded);
        print('   Windows-1254: "$winEncoded"');
      }

      // Decode edilmiş dosya için Windows encoding
      if (decoded != fileName) {
        String decodedWinEncoded = encodeForWindows1254(decoded);
        if (decodedWinEncoded != decoded &&
            !variants.contains(decodedWinEncoded)) {
          variants.add(decodedWinEncoded);
          print('   Decoded Windows-1254: "$decodedWinEncoded"');
        }
      }

      // Özel klasör encoding'i - FTP sunucularında yaygın
      String folderEncoded = encodeFolderNameForFtp(fileName);
      if (folderEncoded != fileName && !variants.contains(folderEncoded)) {
        variants.add(folderEncoded);
        print('   Folder encoded: "$folderEncoded"');
      }
    }

    // 4. URL encode varyantları (bazı FTP sunucuları için)
    try {
      String urlEncoded = Uri.encodeComponent(fileName);
      if (!variants.contains(urlEncoded)) {
        variants.add(urlEncoded);
        print('   URL encoded: "$urlEncoded"');
      }

      if (decoded != fileName) {
        String decodedUrlEncoded = Uri.encodeComponent(decoded);
        if (!variants.contains(decodedUrlEncoded)) {
          variants.add(decodedUrlEncoded);
          print('   Decoded URL encoded: "$decodedUrlEncoded"');
        }
      }
    } catch (e) {
      print('   URL encoding hatası: $e');
    }

    // 5. Boşluk karakteri düzeltmeleri (klasörler için)
    if (fileName.contains(' ')) {
      String spaceReplaced = fileName.replaceAll(' ', '_');
      if (!variants.contains(spaceReplaced)) {
        variants.add(spaceReplaced);
        print('   Boşluk->Alt çizgi: "$spaceReplaced"');
      }

      String spaceReplaced2 = fileName.replaceAll(' ', '%20');
      if (!variants.contains(spaceReplaced2)) {
        variants.add(spaceReplaced2);
        print('   Boşluk->%20: "$spaceReplaced2"');
      }
    }

    // Duplikat'ları kaldır ve sırala (en olası ilk sırada)
    List<String> uniqueVariants = variants.toSet().toList();

    print('✅ Toplam ${uniqueVariants.length} encoding varyantı oluşturuldu');
    for (int i = 0; i < uniqueVariants.length; i++) {
      print('   [$i] "${uniqueVariants[i]}"');
    }

    return uniqueVariants;
  }

  // Klasör adları için özel FTP encoding
  static String encodeFolderNameForFtp(String folderName) {
    String result = folderName;

    // Özel klasör encoding patterns
    final Map<String, String> folderCharMap = {
      // Ana Türkçe karakterler için FTP-safe encoding
      'ç': 'c', // Bazı FTP sunucuları için
      'Ç': 'C',
      'ğ': 'g',
      'Ğ': 'G',
      'ı': 'i',
      'İ': 'I',
      'ö': 'o',
      'Ö': 'O',
      'ş': 's',
      'Ş': 'S',
      'ü': 'u',
      'Ü': 'U',
    };

    // Sadece klasör isimlerinde problematik olan karakterler
    folderCharMap.forEach((turkish, safe) {
      result = result.replaceAll(turkish, safe);
    });

    return result;
  }

  // Windows-1254 benzeri encoding
  static String encodeForWindows1254(String input) {
    Map<String, String> charMap = {
      // Temel Türkçe karakterler
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

      // Ek karakterler - klasörler için
      ' ': '\u0020', // Boşluk
      '-': '\u002D', // Tire
      '_': '\u005F', // Alt çizgi
    };

    String result = input;
    charMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }

  // Klasör adı doğrulama
  static bool isFolderNameValid(String folderName) {
    // Geçersiz karakterleri kontrol et
    final RegExp invalidChars = RegExp(r'[<>:"/\\|?*]');

    if (invalidChars.hasMatch(folderName)) {
      return false;
    }

    // Windows reserved names kontrolü
    final List<String> reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9'
    ];

    String upperName = folderName.toUpperCase();
    if (reservedNames.contains(upperName)) {
      return false;
    }

    return true;
  }

  // Test fonksiyonu - klasör adları için
  static void testFolderDecoding() {
    List<String> testFolders = [
      'türkçe_klasör',
      'Yönetim Belgeler',
      'İşçi Dosyaları',
      'Güvenlik & Şifre',
      'ÇalışanBelgeleri',
      'Müşteri_Şikayetleri',
      'Özgeçmişler',
      'gÃ¼iÅÃ§Ã¶', // Problemli örnek
    ];

    print('🧪 Klasör encoding test başlıyor:');
    for (String folderName in testFolders) {
      print('\n--- Test Klasör: "$folderName" ---');

      // Geçerlilik kontrolü
      bool isValid = isFolderNameValid(folderName);
      print('Geçerli: $isValid');

      // Encoding varyantları
      List<String> variants = generateFtpEncodingVariants(folderName);
      print('Toplam varyant: ${variants.length}');

      // Decode testi
      String decoded = decodeFileName(folderName);
      print('Decode sonucu: "$decoded"');
    }
  }

  // Debug: FTP path analizi
  static void debugFtpPath(String fullPath) {
    print('🔍 FTP Path Analizi: "$fullPath"');

    // Path parçalarına böl
    List<String> pathParts =
        fullPath.split('/').where((s) => s.isNotEmpty).toList();

    print('Path parça sayısı: ${pathParts.length}');

    for (int i = 0; i < pathParts.length; i++) {
      String part = pathParts[i];
      print('  [$i] Orijinal: "$part"');

      // Karakter analizi
      analyzeCharacterCodes(part, label: 'Part $i');

      // Decode edilmiş hali
      String decoded = decodeFileName(part);
      if (decoded != part) {
        print('      Decoded: "$decoded"');
      }

      // Encoding varyantları
      List<String> variants = generateFtpEncodingVariants(part);
      print('      Varyant sayısı: ${variants.length}');

      for (int j = 0; j < variants.length && j < 3; j++) {
        print('        [$j] "${variants[j]}"');
      }
    }
  }

  // Klasör navigasyonu için path birleştirme
  static String joinFtpPath(String basePath, String folderName) {
    // Base path temizleme
    String cleanBasePath = basePath.trim();
    if (cleanBasePath.isEmpty) cleanBasePath = '/';

    // Folder name temizleme
    String cleanFolderName = folderName.trim();
    if (cleanFolderName.isEmpty) return cleanBasePath;

    // Path birleştirme
    if (cleanBasePath == '/') {
      return '/$cleanFolderName';
    } else if (cleanBasePath.endsWith('/')) {
      return '$cleanBasePath$cleanFolderName';
    } else {
      return '$cleanBasePath/$cleanFolderName';
    }
  }

  // Parent directory hesaplama (Türkçe karakter destekli)
  static String getParentPath(String currentPath) {
    if (currentPath == '/' || currentPath.isEmpty) {
      return '/';
    }

    String cleanPath = currentPath.endsWith('/')
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;

    int lastSlashIndex = cleanPath.lastIndexOf('/');

    if (lastSlashIndex <= 0) {
      return '/';
    }

    return cleanPath.substring(0, lastSlashIndex);
  }
}
