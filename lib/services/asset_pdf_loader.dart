import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'pdf_loader_service.dart';

class AssetPdfLoader implements PdfLoaderService {
  final String assetPath;
  AssetPdfLoader(this.assetPath);

  @override
  Future<Uint8List?> loadPdf() async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
