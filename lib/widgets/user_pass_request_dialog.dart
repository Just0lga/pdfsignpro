import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/services/ftp_pdf_loader_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserPassRequestDialog extends ConsumerStatefulWidget {
  final String? initialUsername;
  final String? initialPassword;
  final String serverName;
  final String host;
  final int port;

  const UserPassRequestDialog({
    Key? key,
    this.initialUsername,
    this.initialPassword,
    required this.serverName,
    required this.host,
    required this.port,
  }) : super(key: key);

  @override
  ConsumerState<UserPassRequestDialog> createState() => _UserPassRequestDialogState();
}

class _UserPassRequestDialogState extends ConsumerState<UserPassRequestDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername ?? '');
    _passwordController = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isConnecting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.dns, color: Color(0xFF112b66)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'FTP Bağlantı Bilgileri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF112b66),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Server bilgileri
            Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF112b66).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Server: ${widget.serverName}'),
                  Text('Host: ${widget.host}'),
                  Text('Port: ${widget.port}'),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            // Kullanıcı adı
            TextField(
              controller: _usernameController,
              enabled: !_isConnecting,
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF112b66)),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 12),
            
            // Şifre
            TextField(
              controller: _passwordController,
              enabled: !_isConnecting,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF112b66)),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            
            if (_isConnecting) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF112b66),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Bağlantı test ediliyor...',
                    style: TextStyle(
                      color: Color(0xFF112b66),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isConnecting ? null : () => Navigator.pop(context, null),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isConnecting ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : _testConnectionAndSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF112b66),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            icon: Icon(_isConnecting ? Icons.hourglass_empty : Icons.check),
            label: Text(
              _isConnecting ? 'Test Ediliyor...' : 'Bağlan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnectionAndSave() async {
    setState(() {
      _isConnecting = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // FTP bağlantısını test et
      await _testFtpConnection(username, password);


      // Başarılı ise bilgileri döndür
      if (mounted) {
            final connectionDetails = ref.read(ftpConnectionDetailsProvider);

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString("${connectionDetails}username", username);
  await prefs.setString("${connectionDetails}pass", password);
  print("shared preferences: ${connectionDetails}pass");
  print("shared preferences: ${connectionDetails}pass");


        Navigator.pop(context, {
          'username': username,
          'password': password,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bağlantı başarısız: ${e.toString()}',
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Kapat',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _testFtpConnection(String username, String password) async {
    try {
      final socket = await Socket.connect(
        widget.host,
        widget.port,
        timeout: Duration(seconds: 10),
      );
      await socket.close();

      // Basit FTP test bağlantısı
      final testFiles = await FtpPdfLoaderService.listAllFiles(
        host: widget.host,
        username: username,
        password: password,
        directory: '/',
        port: widget.port,
      );

      print('✅ FTP test bağlantısı başarılı - ${testFiles.length} item bulundu');
    } catch (e) {
      print('❌ FTP test bağlantısı başarısız: $e');
      throw Exception('FTP sunucuya bağlanılamıyor. Kullanıcı adı ve şifrenizi kontrol edin.');
    }
  }
}