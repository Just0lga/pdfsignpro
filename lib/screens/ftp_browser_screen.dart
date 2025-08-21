import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/frontend_models/ftp_file.dart';
import '../services/ftp_pdf_loader.dart';
import '../services/cache_manager.dart';
// FTP Provider kullanmak isterseniz bu import'u açın:
// import '../provider/ftp_provider.dart';

class FtpBrowserScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<FtpBrowserScreen> createState() => _FtpBrowserScreenState();
}

class _FtpBrowserScreenState extends ConsumerState<FtpBrowserScreen> {
  final String _host = '84.51.13.196';
  final String _username = 'testuser';
  final String _password = 'testpass';
  final int _port = 9093;
  final String _directory = '/';

  bool _isLoading = false;
  bool _showAllFiles = false;
  String? _lastError;
  bool _hasInternetConnection = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionAndList();
    });
  }

  // İnternet bağlantısını kontrol et
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());

      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _hasInternetConnection = false;
          _lastError = 'İnternet bağlantısı yok';
        });
        return false;
      }

      // Gerçek ağ erişimini test et
      final result = await InternetAddress.lookup('google.com').timeout(
        Duration(seconds: 5),
        onTimeout: () => throw SocketException('Timeout'),
      );

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
          _lastError = null;
        });
        return true;
      }
    } catch (e) {
      print('İnternet bağlantı kontrolü hatası: $e');
      setState(() {
        _hasInternetConnection = false;
        _lastError = 'İnternet bağlantısı kontrol edilemiyor: ${e.toString()}';
      });
    }

    return false;
  }

  // FTP sunucuya özel ping kontrolü
  Future<bool> _checkFtpServerConnection() async {
    try {
      print('🔌 FTP sunucu bağlantısı kontrol ediliyor: $_host:$_port');

      final socket =
          await Socket.connect(_host, _port, timeout: Duration(seconds: 10));
      await socket.close();

      print('✅ FTP sunucuya bağlantı başarılı');
      return true;
    } catch (e) {
      print('❌ FTP sunucu bağlantı hatası: $e');
      setState(() {
        _lastError =
            'FTP sunucuya bağlanılamıyor: $_host:$_port\nHata: ${e.toString()}';
      });
      return false;
    }
  }

  // Geliştirilmiş bağlantı kontrol ve listeleme
  Future<void> _checkConnectionAndList() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    try {
      print('🔍 Bağlantı kontrolü başlıyor...');

      // Cache debug bilgisi
      await _debugCacheStatus();

      // 1. İnternet bağlantısını kontrol et
      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        // İnternet yoksa cache'den dene
        await _loadFromCacheIfAvailable();
        setState(() => _isLoading = false);
        return;
      }

      // 2. FTP sunucu bağlantısını kontrol et
      bool ftpReachable = await _checkFtpServerConnection();
      if (!ftpReachable) {
        // FTP sunucu erişilemezse cache'den dene
        await _loadFromCacheIfAvailable();
        setState(() => _isLoading = false);
        return;
      }

      // 3. Bağlantı başarılıysa FTP işlemlerini başlat
      await _connectAndListWithCache();
    } catch (e) {
      print('❌ Genel bağlantı hatası: $e');
      if (mounted) {
        setState(() {
          _lastError = 'Bağlantı hatası: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Cache durumunu debug et
  Future<void> _debugCacheStatus() async {
    await CacheManager.debugCacheInfo();
  }

  // Cache'den yüklemeyi dene
  Future<void> _loadFromCacheIfAvailable() async {
    print('📦 Cache\'den veri yüklemeye çalışılıyor...');
    try {
      final cachedFiles = await CacheManager.getCachedFtpFiles();
      if (cachedFiles != null && cachedFiles.isNotEmpty) {
        print('✅ Cache\'den ${cachedFiles.length} dosya yüklendi');
        setState(() {
          _lastError =
              'Offline - Cache\'den gösteriliyor (${cachedFiles.length} dosya)';
        });
        // Cache'deki dosyalar otomatik olarak FutureBuilder tarafından gösterilecek
      } else {
        print('📦 Cache boş veya süresi dolmuş');
        setState(() {
          _lastError = 'Bağlantı yok ve cache\'de veri bulunmuyor';
        });
      }
    } catch (e) {
      print('❌ Cache\'den yükleme hatası: $e');
      setState(() {
        _lastError = 'Cache hatası: ${e.toString()}';
      });
    }
  }

  // Cache ile FTP bağlantısı
  Future<void> _connectAndListWithCache() async {
    setState(() => _isLoading = true);

    try {
      print('🔄 Cache yenileme kontrol ediliyor...');

      // Önce cache'den yükle (hızlı gösterim için)
      final cachedFiles = await CacheManager.getCachedFtpFiles();
      if (cachedFiles != null) {
        print('📦 Cache\'den ${cachedFiles.length} dosya önceden yüklendi');
      }

      // Cache yenileme gerekli mi kontrol et
      final shouldRefresh = await CacheManager.shouldRefreshCache('ftp');

      if (shouldRefresh) {
        print('🔄 FTP\'den yeni veri çekiliyor...');
        // FutureBuilder yeni veri çekecek ve cache güncellenecek
      } else {
        print('✅ Cache güncel, yenileme gerekmiyor');
      }

      // Manuel refresh için setState çağırıyoruz
      setState(() {});
    } catch (e) {
      print('❌ Cache FTP hatası: $e');
      setState(() {
        _lastError = 'FTP yapılandırma hatası: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Dosyaları tarihe göre sırala (en yeni önce)
  List<FtpFile> _sortFilesByDate(List<FtpFile> files) {
    final sortedFiles = List<FtpFile>.from(files);

    sortedFiles.sort((a, b) {
      if (a.modifyTime != null && b.modifyTime != null) {
        return b.modifyTime!.compareTo(a.modifyTime!);
      } else if (a.modifyTime != null && b.modifyTime == null) {
        return -1;
      } else if (a.modifyTime == null && b.modifyTime != null) {
        return 1;
      } else {
        return a.name.compareTo(b.name);
      }
    });

    return sortedFiles;
  }

  // Dosya adından imza indexlerini çıkar
  Set<int> getSignatureIndexesFromFileName(String fileName) {
    final Set<int> indexes = <int>{};

    String baseName = fileName.toLowerCase().endsWith('.pdf')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;

    if (baseName.contains('_imzalandi_')) {
      final index = baseName.indexOf('_imzalandi_');
      final indexPart = baseName.substring(index + '_imzalandi_'.length);

      for (int i = 0; i < indexPart.length; i++) {
        final digit = int.tryParse(indexPart[i]);
        if (digit != null && digit >= 1 && digit <= 4) {
          indexes.add(digit);
        }
      }
    }

    return indexes;
  }

  // İmza kutularını oluştur
  Widget _buildSignatureBoxes(FtpFile file) {
    final signedIndexes = getSignatureIndexesFromFileName(file.name);

    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          final signatureNumber = index + 1;
          final isSigned = signedIndexes.contains(signatureNumber);

          return Container(
            margin: EdgeInsets.all(4),
            width: 70,
            height: 20,
            decoration: BoxDecoration(
              color: isSigned ? Colors.green[200] : Colors.red[200],
              border: Border.all(
                color: isSigned ? Colors.green : Colors.red,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$signatureNumber',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSigned ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP PDF Listesi',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Color(0xFF112b66),
        centerTitle: true,
        actions: [
          // Cache temizleme butonu
          /*
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Cache Temizle'),
                  content:
                      Text('Tüm cache verilerini temizlemek istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await CacheManager.clearAllCache();
                        _checkConnectionAndList();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cache temizlendi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Text('Temizle'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Cache Temizle',
          ),*/
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _checkConnectionAndList,
            tooltip: 'Yenile',
          ),
          // Bağlantı durumu göstergesi
          Container(
            margin: EdgeInsets.only(right: 8),
            child: Icon(
              _hasInternetConnection ? Icons.wifi : Icons.wifi_off,
              color: _hasInternetConnection ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionInfo(),
          Expanded(
            child: _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo() {
    return Container(
      color: Color(0xFF112b66).withOpacity(0.1),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 4),
              Text(
                'Kullanıcı: $_username',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _hasInternetConnection ? Icons.check_circle : Icons.error,
                size: 20,
                color: _hasInternetConnection ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _hasInternetConnection
                      ? 'Bağlantı durumu: Aktif'
                      : 'Bağlantı durumu: ${_lastError ?? "Bağlantı sorunu"}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _hasInternetConnection ? Colors.green : Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.sort, size: 20, color: Color(0xFF112b66)),
              const SizedBox(width: 4),
              Text(
                'Dosyalar tarihe göre sıralandı (En yeni önce)',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF112b66),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    // Bağlantı yoksa hata göster
    if (!_hasInternetConnection) {
      return _buildConnectionError();
    }

    return FutureBuilder<List<FtpFile>>(
      future: _showAllFiles
          ? FtpPdfLoader.listAllFiles(
              host: _host,
              username: _username,
              password: _password,
              directory: _directory,
              port: _port,
            )
          : FtpPdfLoader.listPdfFiles(
              host: _host,
              username: _username,
              password: _password,
              directory: _directory,
              port: _port,
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF112b66)),
                SizedBox(height: 16),
                Text('FTP sunucuya bağlanılıyor...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildFtpError(snapshot.error.toString());
        }

        final rawFiles = snapshot.data ?? [];
        final files = _sortFilesByDate(rawFiles);

        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_showAllFiles
                    ? 'Hiç dosya bulunamadı'
                    : 'PDF dosyası bulunamadı'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkConnectionAndList,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _uploadTestPdf,
                  icon: const Icon(Icons.upload),
                  label: const Text('Test PDF Yükle'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: Color(0xFF112b66),
          onRefresh: () async => _checkConnectionAndList(),
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isPdf = file.name.toLowerCase().endsWith('.pdf');

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Color(0xFF112b66)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Boyut: ${file.sizeFormatted}',
                                  style: TextStyle(color: Color(0xFF112b66)),
                                ),
                                if (file.modifyTime != null)
                                  Text(
                                    'Tarih: ${DateFormat('d MMMM y HH:mm', 'tr_TR').format(file.modifyTime!.add(Duration(hours: 3)))}',
                                    style: TextStyle(
                                      color: Color(0xFF112b66),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Icon(
                              Icons.picture_as_pdf,
                              color: Color(0xFF112b66),
                              size: 36,
                            ),
                          )
                        ],
                      ),
                      isThreeLine: file.modifyTime != null,
                      onTap: isPdf ? () => _downloadAndOpenPdf(file) : null,
                    ),
                    if (isPdf) _buildSignatureBoxes(file),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Bağlantı Sorunu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _lastError ?? 'İnternet bağlantınızı kontrol edin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _checkConnectionAndList,
            icon: Icon(Icons.refresh),
            label: Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF112b66),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFtpError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'FTP Bağlantı Hatası',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Sunucudan veri gelemiyor, internetinizi kontrol edin",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _checkConnectionAndList,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF112b66),
                  foregroundColor: Colors.white,
                ),
              ), /*
              SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _uploadTestPdf,
                icon: const Icon(Icons.upload),
                label: const Text('Test PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),*/
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _connectAndList() async {
    setState(() => _isLoading = true);

    try {
      // FTP provider'ı güncelle (opsiyonel)
      // Eğer provider kullanıyorsanız import'u ekleyin: import '../provider/ftp_provider.dart';
      // ref.read(ftpConfigProvider.notifier).state = FtpConfig(
      //   host: _host,
      //   username: _username,
      //   password: _password,
      //   directory: _directory,
      //   port: _port,
      // );
      // ref.invalidate(ftpFilesProvider);

      // Manuel refresh için setState çağırıyoruz
      setState(() {});
    } catch (e) {
      print('FTP config hatası: $e');
      setState(() {
        _lastError = 'FTP yapılandırma hatası: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadTestPdf() async {
    try {
      final testPdfBytes = await _createTestPdf();
      final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.pdf';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF112b66)),
              SizedBox(width: 16),
              Text('Test PDF yükleniyor...'),
            ],
          ),
        ),
      );

      final success = await FtpPdfLoader.uploadPdfToFtp(
        host: _host,
        username: _username,
        password: _password,
        pdfBytes: testPdfBytes,
        fileName: fileName,
      );

      if (context.mounted) {
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test PDF yüklendi: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
          _checkConnectionAndList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF yüklenemedi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<Uint8List> _createTestPdf() async {
    final pdf = sf.PdfDocument();
    final page = pdf.pages.add();

    page.graphics.drawString(
      'Test PDF - ${DateTime.now()}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 30),
      bounds: const Rect.fromLTWH(50, 100, 400, 50),
    );

    final bytes = await pdf.save();
    pdf.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<void> _downloadAndOpenPdf(FtpFile file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF112b66)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${file.name} indiriliyor...'),
                  const SizedBox(height: 8),
                  Text(
                    'Boyut: ${file.sizeFormatted}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final loader = FtpPdfLoader(
        host: _host,
        username: _username,
        password: _password,
        filePath: file.path,
        port: _port,
      );

      await ref.read(pdfProvider.notifier).loadPdf(
            loader,
            fileName: file.name,
          );

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} başarıyla yüklendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('PDF yükleme hatası: $e');

      if (context.mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF yüklenemedi: ${file.name}'),
                const SizedBox(height: 4),
                Text(
                  'Hata: $e',
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _downloadAndOpenPdf(file),
            ),
          ),
        );
      }
    }
  }
}
