import 'dart:convert';

class TurkishCharacterDecoder {
  // Ana decode fonksiyonu - birden fazla yöntemi sırayla dener
  static String decodeFileName(String fileName) {
    print('🔄 Decode başlangıcı: "$fileName"');

    List<String> attempts = [];

    // 1. Orijinal dosya adı
    attempts.add(fileName);

    // 2. Windows-1254 (Türkçe) decode
    String windows1254Result = _tryWindows1254Decode(fileName);
    if (windows1254Result != fileName) attempts.add(windows1254Result);

    // 3. ISO-8859-9 (Latin-5 Türkçe) decode
    String iso88599Result = _tryISO88599Decode(fileName);
    if (iso88599Result != fileName) attempts.add(iso88599Result);

    // 4. CP1252 (Windows Latin) decode
    String cp1252Result = _tryCP1252Decode(fileName);
    if (cp1252Result != fileName) attempts.add(cp1252Result);

    // 5. Byte-by-byte manual decode
    String manualResult = _tryManualDecode(fileName);
    if (manualResult != fileName) attempts.add(manualResult);

    // 6. UTF-8 malformed repair
    String utf8Result = _tryUTF8Repair(fileName);
    if (utf8Result != fileName) attempts.add(utf8Result);

    // 7. URL decode denemeleri
    String urlResult = _tryURLDecode(fileName);
    if (urlResult != fileName) attempts.add(urlResult);

    // En iyi sonucu seç
    String bestResult = _selectBestResult(attempts);
    print('✅ En iyi sonuç: "$bestResult"');

    return bestResult;
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

  // Türkçe karakter kalitesi skorlama
  static int _calculateTurkishScore(String text) {
    int score = 0;

    // Türkçe karakterler +3 puan
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
      score += char.allMatches(text).length * 3;
    }

    // Normal karakterler +1 puan
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
        score += 1;
      }
    }

    // Kötü karakterler -5 puan
    final badChars = ['Ä', 'Å', 'Ã', '�', '', '\uFFFD'];
    for (String char in badChars) {
      score -= char.allMatches(text).length * 5;
    }

    // Garip byte sequences -3 puan
    if (text.contains(RegExp(r'[^\x00-\x7F\u00C0-\u017F\u0100-\u024F]'))) {
      score -= 3;
    }

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

  // Test fonksiyonu
  static void testDecoding() {
    List<String> testCases = [
      'satÄ±Å.pdf',
      'Ã¶rnek_dosya.pdf',
      'Ã¼Ã§Ã¼ncÃ¼_ÄŸÃ¼n.pdf',
      'test_Ä±Å_ç.pdf',
      'türkçe%20dosya.pdf',
    ];

    print('🧪 Test başlangıcı:');
    for (String testCase in testCases) {
      print('\n--- Test: "$testCase" ---');
      debugCharacterCodes(testCase);
      String result = decodeFileName(testCase);
      print('✅ Sonuç: "$result"');
    }
  }

  // 🆕 FTP için özel encoding varyantları oluştur
  static List<String> generateFtpEncodingVariants(String fileName) {
    List<String> variants = [];

    // 1. Orijinal dosya adı
    variants.add(fileName);

    // 2. Ana decode fonksiyonu ile
    String decoded = decodeFileName(fileName);
    if (decoded != fileName) {
      variants.add(decoded);
    }

    // 3. Türkçe karakterler varsa ek encoding'ler
    if (fileName.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]')) ||
        decoded.contains(RegExp(r'[çğıöşüÇĞIİÖŞÜ]'))) {
      // UTF-8 → Latin-1 dönüşümü
      try {
        List<int> utf8Bytes = utf8.encode(fileName);
        String latin1Str = latin1.decode(utf8Bytes, allowInvalid: true);
        if (latin1Str != fileName) {
          variants.add(latin1Str);
        }
      } catch (e) {/* ignore */}

      // Decode edilmiş dosya için de UTF-8 → Latin-1
      if (decoded != fileName) {
        try {
          List<int> utf8Bytes = utf8.encode(decoded);
          String latin1Str = latin1.decode(utf8Bytes, allowInvalid: true);
          if (latin1Str != decoded && latin1Str != fileName) {
            variants.add(latin1Str);
          }
        } catch (e) {/* ignore */}
      }

      // Windows-1254 benzeri encoding
      String winEncoded = encodeForWindows1254(fileName);
      if (winEncoded != fileName) {
        variants.add(winEncoded);
      }

      // Decode edilmiş dosya için Windows encoding
      if (decoded != fileName) {
        String decodedWinEncoded = encodeForWindows1254(decoded);
        if (decodedWinEncoded != decoded &&
            !variants.contains(decodedWinEncoded)) {
          variants.add(decodedWinEncoded);
        }
      }
    }

    // 4. URL encode/decode varyantları
    try {
      String urlEncoded = Uri.encodeComponent(fileName);
      if (!variants.contains(urlEncoded)) {
        variants.add(urlEncoded);
      }

      if (decoded != fileName) {
        String decodedUrlEncoded = Uri.encodeComponent(decoded);
        if (!variants.contains(decodedUrlEncoded)) {
          variants.add(decodedUrlEncoded);
        }
      }
    } catch (e) {/* ignore */}

    // Duplikat'ları kaldır
    return variants.toSet().toList();
  }

  // 🆕 Windows-1254 benzeri encoding
  static String encodeForWindows1254(String input) {
    Map<String, String> charMap = {
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

    String result = input;
    charMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    return result;
  }
}
