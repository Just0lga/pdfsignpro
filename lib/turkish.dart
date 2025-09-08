class TurkishCharacterDecoder {
  /// Bozuk Türkçe karakterleri düzelt
  static String pathReplacer(String orj) {
    // Ã§ # Ä # Ä± # Ã¶ # Å # Ã¼ # Ã # Ä # I # Ä° # Ã # Å # Ã
    Map<String, String> replacements = {
      'Ã§': 'ç',
      'Ä': 'ğ',
      'Ä±': 'ı',
      'Ã¶': 'ö',
      'Å': 'ş',
      'Ã¼': 'ü',
      'Ã': 'Ç',
      'Ä': 'Ğ',
      'I': 'I',
      'Ä°': 'İ',
      'Ã': 'Ö',
      'Å': 'Ş',
      'Ã': 'Ü',
    };

    // ç#ğ#ı#ö#ş#ü#Ç#Ğ#I#İ#Ö#Ş#Ü
    if (replacements.isEmpty) return orj;

    String pattern = replacements.keys.map(RegExp.escape).join('|');
    return orj.replaceAllMapped(
        RegExp(pattern), (match) => replacements[match.group(0)]!);
  }

  /// Türkçe karakterleri bozuk hale çevir (tersine çevirme)
  static String pathEncoder(String orj) {
    // ç#ğ#ı#ö#ş#ü#Ç#Ğ#I#İ#Ö#Ş#Ü -> Ã§ # Ä # Ä± # Ã¶ # Å # Ã¼ # Ã # Ä # I # Ä° # Ã # Å # Ã
    Map<String, String> reverseReplacements = {
      'ç': 'Ã§',
      'ğ': 'Ä',
      'ı': 'Ä±',
      'ö': 'Ã¶',
      'ş': 'Å',
      'ü': 'Ã¼',
      'Ç': 'Ã¼',
      'Ğ': 'Ä',
      'I': 'I',
      'İ': 'Ä°',
      'Ö': 'Ã',
      'Ş': 'Å',
      'Ü': 'Ã',
    };

    if (reverseReplacements.isEmpty) return orj;

    String pattern = reverseReplacements.keys.map(RegExp.escape).join('|');
    return orj.replaceAllMapped(
        RegExp(pattern), (match) => reverseReplacements[match.group(0)]!);
  }

  /// Geriye uyumluluk için - eskiden kullanılan metodlar
  static String decodeFileName(String fileName) {
    return pathReplacer(fileName);
  }

  static List<String> generateFtpEncodingVariants(String fileName) {
    List<String> variants = [];

    // 1. Orijinal dosya adı
    variants.add(fileName);

    // 2. pathReplacer ile düzeltilmiş
    String decoded = pathReplacer(fileName);
    if (decoded != fileName) {
      variants.add(decoded);
    }

    // 3. pathEncoder ile encode edilmiş
    String encoded = pathEncoder(fileName);
    if (encoded != fileName && encoded != decoded) {
      variants.add(encoded);
    }

    // Duplikatları kaldır ve maksimum 3 varyant döndür
    return variants.toSet().take(3).toList();
  }
}
