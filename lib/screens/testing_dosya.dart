import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:pdfsignpro/turkish.dart';

class FtpFileCheckScreen extends StatefulWidget {
  const FtpFileCheckScreen({super.key});

  @override
  State<FtpFileCheckScreen> createState() => _FtpFileCheckScreenState();
}

class _FtpFileCheckScreenState extends State<FtpFileCheckScreen> {
  String result = "Kontrol edilmedi";

  Future<void> checkFileExists() async {
    // FTP bilgilerini buraya yaz
    final ftpConnect = FTPConnect(
      "78.187.11.150",
      user: "testuser",
      pass: "testpass",
      port: 9093,
      timeout: 10,
    );

    try {
      await ftpConnect.connect();

      // Statik path ve dosya adı
      String path = "/tolga";
      String fileName = TurkishCharacterDecoder.pathEncoder(
          "ğüişçöşiüüğşçÖIIıĞĞÜŞİÖ.pdf"); // test etmek istediğin dosya

      // Dizine git
      await ftpConnect.changeDirectory(path);

      // Klasördeki dosyaları al
      List<FTPEntry> list = await ftpConnect.listDirectoryContent();

      bool exists = list.any((f) => f.name == fileName);

      setState(() {
        result =
            exists ? "✅ Dosya bulundu: $fileName" : "❌ Dosya yok: $fileName";
      });

      await ftpConnect.disconnect();
    } catch (e) {
      setState(() {
        result = "Hata: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FTP Dosya Kontrol")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(result),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: checkFileExists,
              child: const Text("Dosyayı Kontrol Et"),
            ),
          ],
        ),
      ),
    );
  }
}
