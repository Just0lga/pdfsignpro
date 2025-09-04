import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/helpers/has_internet.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:pdfsignpro/screens/pdf_sign_screen.dart';
import 'package:pdfsignpro/screens/pdf_source_selection_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pdfsignpro/turkish.dart';
import 'package:pdfsignpro/widgets/user_pass_request_dialog.dart';
import '../models/frontend_models/ftp_file.dart';
import '../services/ftp_pdf_loader_service.dart';

// Updated FTP Browser Screen
class FtpBrowserScreen extends ConsumerStatefulWidget {
  final String? fileDirectory;
  const FtpBrowserScreen({Key? key, this.fileDirectory}) : super(key: key);

  @override
  ConsumerState<FtpBrowserScreen> createState() => _FtpBrowserScreenState();
}

class _FtpBrowserScreenState extends ConsumerState<FtpBrowserScreen> {
  bool _isLoading = false;
  bool _showAllFiles = false;
  String? _lastError;
  bool _hasInternetConnection = true;

  // Folder navigation için
  String _currentDirectory = '/';
  List<String> _directoryHistory = ['/'];

  // Geçici credentials
  String? _tempUsername;
  String? _tempPassword;

  Future<List<FtpFile>>? _ftpFilesFuture;

  @override
  void initState() {
    if (widget.fileDirectory != null) {
      _directoryHistory[0] = widget.fileDirectory!;
      _currentDirectory = widget.fileDirectory!;
    }
    print("XXX ftp_browser_screen.dart");
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCredentialsAndConnect();
    });
  }

  // Credentials kontrolü ve gerekirse dialog göster
  Future<void> _checkCredentialsAndConnect() async {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);
    final tempCredentials = ref.watch(temporaryFtpCredentialsProvider);

    if (selectedFtpConnection == null) {
      _showError('FTP sunucu seçilmedi');
      return;
    }

    // Host ve port kontrolü - bunlar backend'den geldiği için boş olamaz
    if (selectedFtpConnection.host == null ||
        selectedFtpConnection.host!.isEmpty ||
        selectedFtpConnection.port == null) {
      _showError('Sunucu bilgileri eksik (host/port)');
      return;
    }

    // Kullanıcı adı ve şifreyi belirle (öncelik geçici credentials'ta)
    final username =
        tempCredentials?['username'] ?? selectedFtpConnection.uname ?? '';
    final password =
        tempCredentials?['password'] ?? selectedFtpConnection.pass ?? '';

    final hasUsername = username.trim().isNotEmpty;
    final hasPassword = password.trim().isNotEmpty;

    if (!hasUsername || !hasPassword) {
      await _showCredentialsDialog();
    } else {
      _checkConnectionAndList();
    }
  }

  Future<void> _showCredentialsDialog() async {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);

    if (selectedFtpConnection == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserPassRequestDialog(
        initialUsername: selectedFtpConnection.uname,
        initialPassword: selectedFtpConnection.pass,
        serverName: selectedFtpConnection.name,
        host: selectedFtpConnection.host!,
        port: selectedFtpConnection.port!,
      ),
    );

    if (result != null) {
      // ✅ YENİ: Geçici credentials'ı provider'a kaydet
      ref.read(temporaryFtpCredentialsProvider.notifier).state = {
        'username': result['username']!,
        'password': result['password']!,
      };

      setState(() {
        _tempUsername = result['username'];
        _tempPassword = result['password'];
      });
      _checkConnectionAndList();
    } else {
      // Kullanıcı iptal etti, geri git
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => PdfSourceSelectionScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _lastError = message;
      _hasInternetConnection = false;
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
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);

    try {
      print(
          '🔌 FTP sunucu bağlantısı kontrol ediliyor: ${selectedFtpConnection?.host}:${selectedFtpConnection?.port}');

      final socket = await Socket.connect(
          selectedFtpConnection?.host, selectedFtpConnection?.port ?? 21,
          timeout: Duration(seconds: 10));
      await socket.close();

      print('✅ FTP sunucuya bağlantı başarılı');
      return true;
    } catch (e) {
      print('❌ FTP sunucu bağlantı hatası: $e');
      setState(() {
        _lastError =
            'FTP sunucuya bağlanılamıyor: ${selectedFtpConnection?.host}:${selectedFtpConnection?.port}\nHata: ${e.toString()}';
      });
      return false;
    }
  }

  // Ana bağlantı kontrolü
  Future<void> _checkConnectionAndList() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _lastError = null;
      _ftpFilesFuture = null;
    });

    try {
      print('🔍 Bağlantı kontrolü başlıyor...');

      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        setState(() {
          _lastError = 'İnternet bağlantısı yok';
          _isLoading = false;
        });
        return;
      }

      bool ftpReachable = await _checkFtpServerConnection();
      if (!ftpReachable) {
        setState(() {
          _lastError = 'FTP sunucuya bağlanılamıyor';
          _isLoading = false;
        });
        return;
      }

      await _loadFtpFiles();
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

  // FTP dosyalarını yükle - credentials ile
  Future<void> _loadFtpFiles() async {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);
    final credentials = ref.watch(activeFtpCredentialsProvider); // ✅ YENİ

    // ✅ Artık activeFtpCredentialsProvider'dan al
    final username = credentials?['username'] ?? '';
    final password = credentials?['password'] ?? '';

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _lastError = 'Kullanıcı adı veya şifre eksik';
        _isLoading = false;
      });
      return;
    }

    try {
      print('🔄 FTP dosya listesi yükleniyor...');
      print('📁 Mevcut dizin: $_currentDirectory');
      print('👤 Kullanıcı: $username');

      _ftpFilesFuture = FtpPdfLoaderService.listAllFiles(
        host: selectedFtpConnection?.host ?? "",
        username: username, // ✅ Güncel credentials
        password: password, // ✅ Güncel credentials
        directory: _currentDirectory,
        port: selectedFtpConnection?.port ?? 21,
      );

      final files = await _ftpFilesFuture!;
      print('✅ FTP dosya listesi yüklendi: ${files.length} dosya/klasör');

      setState(() {
        _isLoading = false;
        _lastError = null;
      });
    } catch (e, stackTrace) {
      print('❌ FTP dosya yükleme hatası: $e');
      print('Stack trace: $stackTrace');

      if (e.toString().toLowerCase().contains('authentication') ||
          e.toString().toLowerCase().contains('login') ||
          e.toString().toLowerCase().contains('credential')) {
        await _showCredentialsDialog();
      } else {
        setState(() {
          _lastError = 'FTP dosya listesi alınamadı: ${e.toString()}';
          _ftpFilesFuture = null;
          _isLoading = false;
        });
      }
    }
  }

  // Folder navigation metodları - DÜZELTME: Türkçe karakter destekli
  void _navigateToDirectory(FtpFile directory) {
    if (!directory.isDirectory) return;

    print('🔄 Klasöre navigasyon: "${directory.name}"');
    print('   Orijinal path: "${directory.path}"');

    setState(() {
      _currentDirectory = directory.path;
      if (!_directoryHistory.contains(directory.path)) {
        _directoryHistory.add(directory.path);
      }
    });

    print('   Yeni mevcut directory: "$_currentDirectory"');
    print('   Directory history: $_directoryHistory');

    _checkConnectionAndList();
  }

  void _goBack() {
    print('🔙 Geri gitme işlemi başlıyor');
    print('   Mevcut directory: "$_currentDirectory"');
    print('   Directory history: $_directoryHistory');

    if (_currentDirectory != '/' && _directoryHistory.length > 1) {
      _directoryHistory.removeLast();
      setState(() {
        _currentDirectory = _directoryHistory.last;
      });
      print('   History\'den geri gidildi: "$_currentDirectory"');
    } else if (_currentDirectory != '/') {
      // Fallback: parent directory'ye git - Türkçe karakter desteği ile
      String parentDir = _getParentDirectory(_currentDirectory);
      setState(() {
        _currentDirectory = parentDir;
        _directoryHistory = ['/'];
        if (parentDir != '/') _directoryHistory.add(parentDir);
      });
      print('   Parent directory\'ye gidildi: "$_currentDirectory"');
    }

    _checkConnectionAndList();
  }

  // Yeni yardımcı metod: Parent directory hesaplama
  String _getParentDirectory(String currentPath) {
    if (currentPath == '/' || currentPath.isEmpty) {
      return '/';
    }

    // Son slash'i kaldır
    String cleanPath = currentPath.endsWith('/')
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;

    // Son klasör adını kaldır
    int lastSlashIndex = cleanPath.lastIndexOf('/');

    if (lastSlashIndex <= 0) {
      return '/'; // Root'a dön
    }

    String parentPath = cleanPath.substring(0, lastSlashIndex);

    if (parentPath.isEmpty) {
      return '/';
    }

    return parentPath;
  }

  // DÜZELTME: Breadcrumb navigation widget
  // ftp_browser_screen.dart içindeki _buildBreadcrumbNavigation metodunun düzeltilmiş versiyonu

  Widget _buildBreadcrumbNavigation() {
    print("🍞 Breadcrumb için current directory: $_currentDirectory");

    List<String> pathParts =
        _currentDirectory.split('/').where((s) => s.isNotEmpty).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Root directory butonu
          GestureDetector(
            onTap: () {
              print('🏠 Root\'a dönülüyor');
              setState(() {
                _currentDirectory = '/';
                _directoryHistory = ['/'];
              });
              _checkConnectionAndList();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text("FTP",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // Path parts - HER PART İÇİN DECODE İŞLEMİ
          ...pathParts.asMap().entries.map((entry) {
            int index = entry.key;
            String part = entry.value;

            // ✅ ÖNEMLİ DÜZELTME: Her path part'ını decode et
            String displayPart = TurkishCharacterDecoder.decodeFileName(part);

            print(
                '🔗 Breadcrumb part [$index]: "$part" -> decoded: "$displayPart"');

            return Row(
              children: [
                // Separator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 16,
                  ),
                ),

                // Folder name - DECODE EDİLMİŞ ADI GÖSTER
                GestureDetector(
                  onTap: () {
                    // ✅ DÜZELTME: Orijinal encoded path'i kullan, decode edilmiş değil
                    String targetPath =
                        '/' + pathParts.sublist(0, index + 1).join('/');

                    print(
                        '🔗 Breadcrumb tıklandı: decoded="$displayPart", target="$targetPath"');

                    setState(() {
                      _currentDirectory = targetPath;
                      // History'yi yeniden oluştur
                      _directoryHistory = ['/'];

                      // Her seviye için path ekle (orijinal encoded formda)
                      String buildingPath = '';
                      for (int i = 0; i <= index; i++) {
                        buildingPath = buildingPath.isEmpty
                            ? '/' + pathParts[i]
                            : buildingPath + '/' + pathParts[i];

                        if (!_directoryHistory.contains(buildingPath)) {
                          _directoryHistory.add(buildingPath);
                        }
                      }
                    });
                    _checkConnectionAndList();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayPart, // ✅ DECODE EDİLMİŞ ADI GÖSTER
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Dosyaları tarihe göre sırala (klasörler önce)
  List<FtpFile> _sortFilesByDate(List<FtpFile> files) {
    final sortedFiles = List<FtpFile>.from(files);

    sortedFiles.sort((a, b) {
      // Klasörler önce
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      // Aynı tipte ise tarihe göre sırala
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
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          // Eğer sayfa yükleniyorsa geri gidilemez
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    'Lütfen işlemin tamamlanmasını bekleyin...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
          return false;
        }

        if (_currentDirectory != '/') {
          _goBack();
          return false;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => PdfSourceSelectionScreen()),
          (Route<dynamic> route) => false,
        );
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildBreadcrumbNavigation(),
          iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: Color(0xFF112b66),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _checkConnectionAndList,
              tooltip: 'Yenile',
            ),
            // Credentials edit butonu
            IconButton(
              icon: Icon(Icons.account_circle, color: Colors.white),
              onPressed: _isLoading ? null : _showCredentialsDialog,
              tooltip: 'Bağlantı Bilgileri',
            ),
          ],
          leading: _isLoading
              ? SizedBox()
              : _currentDirectory == '/'
                  ? IconButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PdfSourceSelectionScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      icon: Icon(Icons.arrow_back_ios_new))
                  : IconButton(
                      onPressed: _goBack,
                      icon: Icon(Icons.arrow_back_ios_new),
                    ),
        ),
        body: Column(
          children: [
            _buildConnectionInfo(),
            Expanded(
              child: _buildFileList(), // DÜZELTME: Doğru metod adı
            ),
          ],
        ),
      ),
    );
  }

// ftp_browser_screen.dart içindeki _buildConnectionInfo metodunun düzeltilmiş versiyonu

  Widget _buildConnectionInfo() {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);
    final credentials = ref.watch(activeFtpCredentialsProvider);

    // ✅ Güncel username'i göster
    final displayUsername = credentials?['username'] ?? 'Belirtilmemiş';

    // ✅ YENİ: Current directory'yi decode ederek göster
    String displayDirectory = _currentDirectory;
    if (_currentDirectory != '/') {
      // Path'i parçalara böl ve her parçayı decode et
      List<String> pathParts =
          _currentDirectory.split('/').where((s) => s.isNotEmpty).toList();
      List<String> decodedParts = pathParts
          .map((part) => TurkishCharacterDecoder.decodeFileName(part))
          .toList();
      displayDirectory = '/' + decodedParts.join('/');
    }

    return Container(
      color: Color(0xFF112b66).withOpacity(0.1),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Kullanıcı: $displayUsername',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.folder, size: 20, color: Color(0xFF112b66)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Dizin: $displayDirectory', // ✅ DECODE EDİLMİŞ DIRECTORY
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF112b66),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // DÜZELTME: Ana dosya listesi widget'ı
  Widget _buildFileList() {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);

    if (!_hasInternetConnection) {
      return _buildConnectionError();
    }

    if (_isLoading) {
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

    if (_ftpFilesFuture == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('FTP bağlantısı hazırlanıyor...'),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkConnectionAndList,
              icon: Icon(Icons.refresh),
              label: Text('Bağlan'),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<FtpFile>>(
      future: _ftpFilesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF112b66)),
                SizedBox(height: 16),
                Text('FTP sunucudan içerik alınıyor...'),
                SizedBox(height: 8),
                Text(
                  'Sunucu: ${selectedFtpConnection?.host}:${selectedFtpConnection?.port}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ FTP Future hatası: ${snapshot.error}');
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
                Text('Bu klasör boş'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkConnectionAndList,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
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
              return _buildFileListCard(
                  file, index); // Her dosya için card oluştur
            },
          ),
        );
      },
    );
  }

  // DÜZELTME: Dosya kartını oluşturan metod
  Widget _buildFileListCard(FtpFile file, int index) {
    return GestureDetector(
      onTap: file.isDirectory
          ? () {
              print('🗂️ Klasöre tıklandı: "${file.name}"');
              print('   Klasör path: "${file.path}"');
              _navigateToDirectory(file);
            }
          : (file.name.toLowerCase().endsWith('.pdf')
              ? () {
                  print('📄 PDF\'e tıklandı: "${file.name}"');
                  print('   PDF path: "${file.path}"');
                  _downloadAndOpenPdf(file);
                }
              : null),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Color(0xFF112b66)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            ListTile(
              leading: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  file.isDirectory ? Icons.folder : Icons.picture_as_pdf,
                  color: file.isDirectory ? Colors.amber : Color(0xFF112b66),
                  size: 36,
                ),
              ),
              title: Text(
                file.name, // Decode edilmiş ad gösteriliyor
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.isDirectory
                        ? 'Klasör'
                        : 'Boyut: ${file.sizeFormatted}',
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
              isThreeLine: file.modifyTime != null,
            ),
            if (!file.isDirectory && file.name.toLowerCase().endsWith('.pdf'))
              _buildSignatureBoxes(file),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
            icon: Icon(Icons.refresh, color: Colors.white),
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
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF112b66),
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCredentialsDialog,
                icon: const Icon(Icons.account_circle, color: Colors.white),
                label: const Text('Bağlantı Bilgileri'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenPdf(FtpFile file) async {
    final selectedFtpConnection = ref.watch(selectedFtpConnectionProvider);
    final credentials = ref.watch(activeFtpCredentialsProvider); // ✅ YENİ

    bool internetVar = await hasInternet();

    if (internetVar == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('İnternet bağlantınızı kontrol ediniz'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
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
      ),
    );

    try {
      // ✅ YENİ: activeFtpCredentialsProvider'dan al
      final username = credentials?['username'] ?? '';
      final password = credentials?['password'] ?? '';

      if (username.isEmpty || password.isEmpty) {
        Navigator.pop(context);
        await _showCredentialsDialog();
        return;
      }

      final loader = FtpPdfLoaderService(
        host: selectedFtpConnection?.host ?? "",
        username: username, // ✅ Güncel credentials
        password: password, // ✅ Güncel credentials
        filePath: file.path,
        port: selectedFtpConnection?.port ?? 21,
      );

      await ref.read(pdfProvider.notifier).loadPdf(
            loader,
            fileName: file.name,
          );

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PdfSignScreen(fileDirectory: _currentDirectory),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
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

        if (e.toString().toLowerCase().contains('authentication') ||
            e.toString().toLowerCase().contains('login') ||
            e.toString().toLowerCase().contains('credential')) {
          await _showCredentialsDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
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
}
