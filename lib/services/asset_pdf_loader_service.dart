import 'package:flutter/services.dart';
import 'pdf_loader_service.dart';

class AssetPdfLoaderService implements PdfLoaderService {
  final String assetPath;
  AssetPdfLoaderService(this.assetPath);

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
