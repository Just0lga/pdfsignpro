import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:signature/signature.dart';

class SignatureDialog extends ConsumerStatefulWidget {
  final int pageIndex;
  final int signatureIndex;

  const SignatureDialog({
    required this.pageIndex,
    required this.signatureIndex,
  });

  @override
  ConsumerState<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends ConsumerState<SignatureDialog> {
  late final SignatureController _controller;
  late final String _key;

  // ignore: unused_field
  Future<Uint8List?>? _renderFuture;

  @override
  void initState() {
    super.initState();
    _key = '${widget.pageIndex}_${widget.signatureIndex}';
    _renderFuture = ref.read(pdfProvider.notifier).renderPage(widget.pageIndex);

    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(pdfProvider.notifier);
    final state = ref.watch(pdfProvider);
    final pageSize = state.pageSizes[widget.pageIndex] ?? Size(300, 200);

    return AlertDialog(
      title: Text(
        'İmza ${widget.signatureIndex + 1}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Container(
        alignment: Alignment.center,
        width: pageSize.width * 0.8,
        height: pageSize.height * 0.2,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8)),
        child: Signature(
          controller: _controller,
          backgroundColor: Colors.transparent,
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İlk satır - Ana butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () {
                    _controller.clear();
                    notifier.clearSignature(_key);
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      "Temizle",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
                SizedBox(width: 4),
                Expanded(
                    child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      "İptal",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
                SizedBox(
                  width: 4,
                ),
                // İki
                Expanded(
                    child: GestureDetector(
                  onTap: () async {
                    final signature = await _controller.toPngBytes();
                    if (signature != null) {
                      notifier.updateSignature(_key, signature);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(
                      "Kaydet",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
              ],
            ),
            SizedBox(height: 8),
            // İkinci satır - Tüm sayfalara ekle butonu
            GestureDetector(
              onTap: () async {
                final signature = await _controller.toPngBytes();
                if (signature != null) {
                  // Tüm sayfalardaki aynı pozisyona imza ekle
                  for (int pageIndex = 0;
                      pageIndex < state.totalPages;
                      pageIndex++) {
                    final newKey = '${pageIndex}_${widget.signatureIndex}';
                    notifier.updateSignature(newKey, signature);
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                  "Bu imzayı bütün sayfalara ekle",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
