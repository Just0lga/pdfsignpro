import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/frontend_models/pdf_state.dart';
import '../services/pdf_loader_service.dart';

final pdfProvider = StateNotifierProvider<PdfNotifier, PdfState>(
  (ref) => PdfNotifier(),
);

class PdfNotifier extends StateNotifier<PdfState> {
  PdfNotifier() : super(const PdfState());

  Future<void> loadPdf(PdfLoaderService loader, {String? fileName}) async {
    state = state.copyWith(isLoading: true);

    try {
      final bytes = await loader.loadPdf();
      if (bytes == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final document = sf.PdfDocument(inputBytes: bytes);
      final totalPages = document.pages.count;
      final pageSizes = <int, Size>{};

      for (int i = 0; i < totalPages; i++) {
        final pageSize = document.pages[i].getClientSize();
        pageSizes[i] = Size(pageSize.width, pageSize.height);
      }

      // Dosya adını temizle (.pdf uzantısını kaldır)
      String? cleanFileName;
      if (fileName != null) {
        cleanFileName = fileName.toLowerCase().endsWith('.pdf')
            ? fileName.substring(0, fileName.length - 4)
            : fileName;
      }

      state = PdfState(
        pdfBytes: bytes,
        document: document,
        totalPages: totalPages,
        pageSizes: pageSizes,
        signatures: {},
        renderedImages: {},
        pdfName: cleanFileName, // pdfName alanını kullan
      );
    } catch (e) {
      print('PDF yükleme hatası: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<Uint8List?> renderPage(int pageIndex) async {
    if (state.pdfBytes == null) return null;

    if (state.renderedImages.containsKey(pageIndex)) {
      return state.renderedImages[pageIndex];
    }

    try {
      await for (final page in Printing.raster(
        state.pdfBytes!,
        pages: [pageIndex],
        dpi: 150,
      )) {
        final image = await page.toPng();

        Future.delayed(Duration.zero, () {
          state = state.copyWith(
            renderedImages: {...state.renderedImages, pageIndex: image},
          );
        });

        return image;
      }
    } catch (e) {
      print('Render hatası sayfa $pageIndex: $e');
    }

    return null;
  }

  void updateSignature(String key, Uint8List? signature) {
    state = state.copyWith(
      signatures: {...state.signatures, key: signature},
    );
  }

  void clearSignature(String key) {
    final signatures = Map<String, Uint8List?>.from(state.signatures);
    signatures.remove(key);
    state = state.copyWith(signatures: signatures);
  }

  void reset() {
    state.document?.dispose();
    state = const PdfState();
  }

  Future<Map<String, dynamic>> createSignedPDF() async {
    if (state.pdfBytes == null || state.document == null) {
      throw Exception('PDF yüklenmemiş');
    }

    final document = sf.PdfDocument(inputBytes: state.pdfBytes!);

    try {
      for (int pageIndex = 0; pageIndex < state.totalPages; pageIndex++) {
        final page = document.pages[pageIndex];
        final graphics = page.graphics;
        final pageSize = page.getClientSize();

        const signatureWidth = 120.0;
        const signatureHeight = 60.0;
        const bottomMargin = 20.0;
        final spacing = (pageSize.width - signatureWidth * 4) / 5;

        for (int signatureIndex = 0; signatureIndex < 4; signatureIndex++) {
          final key = '${pageIndex}_$signatureIndex';
          final xPosition =
              spacing + (signatureIndex * (signatureWidth + spacing));
          final yPosition = pageSize.height - signatureHeight - bottomMargin;

          if (state.signatures.containsKey(key) &&
              state.signatures[key] != null) {
            try {
              final signatureImage = sf.PdfBitmap(state.signatures[key]!);
              graphics.drawImage(
                signatureImage,
                Rect.fromLTWH(
                    xPosition, yPosition, signatureWidth, signatureHeight),
              );
            } catch (e) {
              _drawEmptyBox(graphics, xPosition, yPosition, signatureWidth,
                  signatureHeight, signatureIndex);
            }
          }
        }
      }

      final bytes = await document.save();
      final fileName = finalName(); // Parametresiz çağır

      return {
        'bytes': Uint8List.fromList(bytes),
        'fileName': fileName,
      };
    } finally {
      document.dispose();
    }
  }

  void _drawEmptyBox(sf.PdfGraphics graphics, double x, double y, double width,
      double height, int index) {
    graphics.drawRectangle(
      pen: sf.PdfPen(sf.PdfColor(255, 0, 0), width: 2),
      bounds: Rect.fromLTWH(x, y, width, height),
    );

    graphics.drawString(
      'İmza ${index + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10),
      bounds: Rect.fromLTWH(x + 5, y + height / 2 - 5, width - 10, 20),
      brush: sf.PdfSolidBrush(sf.PdfColor(255, 0, 0)),
    );
  }

  String finalName() {
    // PdfState'teki pdfName alanını kullan
    String baseName = state.pdfName ?? 'document';

    // Mevcut imzalanmış indexleri al (dosya adından)
    final Set<int> existingIndexes = <int>{};

    // Eğer dosya adında "_imzalandı_" varsa, mevcut imzaları çıkar
    if (baseName.contains('_imzalandi_')) {
      final index = baseName.indexOf('_imzalandi_');
      final originalName = baseName.substring(0, index);
      final indexPart = baseName.substring(index + '_imzalandi_'.length);

      // Mevcut indexleri parse et (örn: "14" → [1, 4])
      for (int i = 0; i < indexPart.length; i++) {
        final digit = int.tryParse(indexPart[i]);
        if (digit != null && digit >= 1 && digit <= 4) {
          existingIndexes.add(digit);
        }
      }

      baseName = originalName; // Orijinal dosya adını al
    }

    // Şu anda aktif olan imzaları al
    final Set<int> currentSignatureIndexes = <int>{};

    for (final key in state.signatures.keys) {
      if (state.signatures[key] != null) {
        // Sadece dolu imzaları say
        final parts = key.split('_');
        if (parts.length == 2) {
          final signatureIndex = int.tryParse(parts[1]);
          if (signatureIndex != null) {
            currentSignatureIndexes
                .add(signatureIndex + 1); // 0-based'den 1-based'e çevir
          }
        }
      }
    }

    // Mevcut ve yeni imzaları birleştir
    final Set<int> allSignatureIndexes = <int>{};
    allSignatureIndexes.addAll(existingIndexes);
    allSignatureIndexes.addAll(currentSignatureIndexes);

    // Hiç imza yoksa unsigned
    if (allSignatureIndexes.isEmpty) {
      return '${baseName}';
    }

    // Sırala ve string'e çevir
    final sortedIndexes = allSignatureIndexes.toList()..sort();
    final indexString = sortedIndexes.join('');

    return '${baseName}_imzalandi_$indexString';
  }

  Set<int> getExistingSignatureIndexes() {
    final Set<int> existingIndexes = <int>{};
    String baseName = state.pdfName ?? 'document';

    // Eğer dosya adında "_imzalandi_" varsa, mevcut imzaları çıkar
    if (baseName.contains('_imzalandi_')) {
      final index = baseName.indexOf('_imzalandi_');
      final indexPart = baseName.substring(index + '_imzalandi_'.length);

      // Mevcut indexleri parse et (örn: "13" → [1, 3])
      for (int i = 0; i < indexPart.length; i++) {
        final digit = int.tryParse(indexPart[i]);
        if (digit != null && digit >= 1 && digit <= 4) {
          existingIndexes.add(digit);
        }
      }
    }

    return existingIndexes;
  }

  // Tüm imzaları temizle
  void clearAllSignatures() {
    state = state.copyWith(signatures: {});
  }
}
