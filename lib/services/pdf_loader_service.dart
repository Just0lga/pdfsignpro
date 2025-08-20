import 'dart:typed_data';

abstract class PdfLoaderService {
  Future<Uint8List?> loadPdf();
}
