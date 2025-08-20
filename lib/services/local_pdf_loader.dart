import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'pdf_loader_service.dart';

class LocalPdfLoader implements PdfLoaderService {
  @override
  Future<Uint8List?> loadPdf() async {
    print('📁 File picker açılıyor...');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    print('📋 File picker sonucu: ${result?.files.length ?? 0} dosya');

    if (result == null) {
      print('❌ Kullanıcı dosya seçimini iptal etti');
      return null;
    }

    try {
      Uint8List? bytes;

      if (kIsWeb) {
        print('🌐 Web platformu - bytes alınıyor...');
        bytes = result.files.single.bytes;
      } else {
        print('📱 Mobil/Desktop platform - dosya okunuyor...');
        final file = File(result.files.single.path!);
        bytes = await file.readAsBytes();
      }

      print('✅ PDF dosyası okundu: ${bytes?.length ?? 0} bytes');
      return bytes;
    } catch (e) {
      print('❌ PDF okuma hatası: $e');
      rethrow;
    }
  }
}
