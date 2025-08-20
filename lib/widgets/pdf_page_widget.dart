import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/models/frontend_models/pdf_state.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';

class PdfPageWidget extends ConsumerStatefulWidget {
  final int pageIndex;
  final Function(int) onSignatureTap;

  const PdfPageWidget({
    Key? key,
    required this.pageIndex,
    required this.onSignatureTap,
  }) : super(key: key);

  @override
  ConsumerState<PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends ConsumerState<PdfPageWidget> {
  Future<Uint8List?>? _renderFuture;

  @override
  void initState() {
    super.initState();
    _renderFuture = ref.read(pdfProvider.notifier).renderPage(widget.pageIndex);
  }

  Color getSignatureBoxColor(int pageIndex, int signatureIndex) {
    final pdfState = ref.watch(pdfProvider);
    final pdfNotifier = ref.read(pdfProvider.notifier);

    // Şu anda dolu imza varsa yeşil (PDF esnasında atılmış)
    final key = '${pageIndex}_$signatureIndex';
    if (pdfState.signatures.containsKey(key) &&
        pdfState.signatures[key] != null) {
      return Colors.green.withOpacity(0.4); //?? Colors.green.withOpacity(0.4);
    }

    // Dosyadan mevcut imzaları al
    final existingSignatures = pdfNotifier.getExistingSignatureIndexes();

    // 1-based index (signatureIndex 0-based olduğu için +1)
    final currentSignatureNumber = signatureIndex + 1;

    // Önceden imzalanmış kutularsa sarı
    if (existingSignatures.contains(currentSignatureNumber)) {
      return Colors.green.withOpacity(0.4); //?? Colors.green.withOpacity(0.4);
    }

    // Boş kutular kırmızı
    return Colors.red.withOpacity(0.6); //?? Colors.red.withOpacity(0.6);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfProvider);

    return FutureBuilder<Uint8List?>(
      future: _renderFuture,
      builder: (context, snapshot) {
        Widget pageContent;

        if (snapshot.connectionState == ConnectionState.waiting) {
          pageContent = _buildLoadingContent(state);
        } else if (snapshot.hasError) {
          pageContent = _buildErrorContent();
        } else if (snapshot.hasData && snapshot.data != null) {
          pageContent = _buildRenderedContent(snapshot.data!, state);
        } else {
          pageContent = _buildEmptyContent();
        }

        return Container(
          alignment: Alignment.center,
          decoration: _boxDecoration(),
          child: Stack(
            children: [
              pageContent,
              if (snapshot.hasData) _buildSignatureRow(state),
              _buildPageNumber(),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      );

  Widget _buildLoadingContent(PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null)
      return const Center(
          child: CircularProgressIndicator(
        color: Color(0xFF112b66),
      ));

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: pageSize.width,
        height: pageSize.height,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Color(0xFF112b66),
        ),
      ),
    );
  }

  Widget _buildErrorContent() => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Sayfa yüklenemedi', style: TextStyle(color: Colors.red)),
        ),
      );

  Widget _buildEmptyContent() => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Boş sayfa'),
        ),
      );

  Widget _buildRenderedContent(Uint8List imageData, PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null) return const SizedBox();

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        alignment: Alignment.center,
        width: pageSize.width,
        height: pageSize.height,
        child: Image.memory(
          imageData,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSignatureRow(PdfState state) {
    final pageSize = state.pageSizes[widget.pageIndex];
    if (pageSize == null) return const SizedBox();

    return Positioned(
      bottom: 0,
      left: 5,
      right: 5,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (signatureIndex) {
            final key = '${widget.pageIndex}_$signatureIndex';
            final hasSignature = state.signatures.containsKey(key) &&
                state.signatures[key] != null;

            return Flexible(
              child: GestureDetector(
                onTap: state.isLoading
                    ? null
                    : () => widget.onSignatureTap(signatureIndex),
                child: _buildSignatureBox(
                    key,
                    hasSignature,
                    signatureIndex,
                    state,
                    ResponsiveSize(
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width)),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSignatureBox(String key, bool hasSignature, int index,
      PdfState state, ResponsiveSize responsiveSize) {
    final boxColor = getSignatureBoxColor(widget.pageIndex, index);
    final pdfNotifier = ref.read(pdfProvider.notifier);
    final existingSignatures = pdfNotifier.getExistingSignatureIndexes();

    // Sayfa genişliğine göre dinamik imza kutu boyutları
    double boxWidth;
    double boxHeight;
    print("XXX${responsiveSize.width}");
    if (responsiveSize.width <= 400) {
      // Çok küçük ekranlar (mobil portrait)
      boxWidth = 100;
      boxHeight = 45;
    } else if (responsiveSize.width <= 600) {
      // Küçük-orta ekranlar (mobil landscape, küçük tablet)
      boxWidth = 110;
      boxHeight = 65;
    } else if (responsiveSize.width <= 800) {
      // Orta-büyük ekranlar (tablet, küçük laptop)
      boxWidth = 125;
      boxHeight = 75;
    } else {
      // Büyük ekranlar (desktop, büyük tablet)
      boxWidth = 130;
      boxHeight = 85;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: boxHeight,
      width: boxWidth,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withOpacity(0.2),
          /*hasSignature
              ? Colors.green.withOpacity(0.7)
              : Colors.red.withOpacity(0.7),*/
          width: 2,
        ),
        color: state.isLoading
            ? Colors.grey.withOpacity(0.3)
            : boxColor, // Dinamik renk
      ),
      child: hasSignature
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: Image.memory(state.signatures[key]!, fit: BoxFit.contain),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  existingSignatures.contains(index + 1)
                      ? SizedBox()
                      : Icon(Icons.edit,
                          size: 16,
                          color: state.isLoading ? Colors.grey : Colors.black),
                  Text(
                    existingSignatures.contains(index + 1)
                        ? ""
                        : 'İmza ${index + 1}',
                    style: TextStyle(
                        fontSize: 9,
                        color: state.isLoading ? Colors.grey : Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPageNumber() => Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: Colors.black54,
          child: Text(
            'Sayfa ${widget.pageIndex + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
}

class ResponsiveSize {
  final double height;
  final double width;

  ResponsiveSize({required this.height, required this.width});
}
