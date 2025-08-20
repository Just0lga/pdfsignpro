import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PdfState {
  final sf.PdfDocument? document;
  final Map<String, Uint8List?> signatures;
  final int totalPages;
  final Uint8List? pdfBytes;
  final Map<int, Size> pageSizes;
  final Map<int, Uint8List?> renderedImages;
  final bool isLoading;
  final String? pdfName;

  const PdfState({
    this.document,
    this.signatures = const {},
    this.totalPages = 0,
    this.pdfBytes,
    this.pageSizes = const {},
    this.renderedImages = const {},
    this.isLoading = false,
    this.pdfName,
  });

  PdfState copyWith({
    sf.PdfDocument? document,
    Map<String, Uint8List?>? signatures,
    int? totalPages,
    Uint8List? pdfBytes,
    Map<int, Size>? pageSizes,
    Map<int, Uint8List?>? renderedImages,
    bool? isLoading,
    String? pdfName,
    bool? Function()? documentClear,
  }) =>
      PdfState(
        document: documentClear != null
            ? (documentClear != null ? null : document)
            : (document ?? this.document),
        signatures: signatures ?? this.signatures,
        totalPages: totalPages ?? this.totalPages,
        pdfBytes: pdfBytes ?? this.pdfBytes,
        pageSizes: pageSizes ?? this.pageSizes,
        renderedImages: renderedImages ?? this.renderedImages,
        isLoading: isLoading ?? this.isLoading,
        pdfName: pdfName ?? this.pdfName,
      );
}
