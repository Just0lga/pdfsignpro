import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/services/ftp_pdf_loader_service.dart';
import 'dart:io';

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
  ConsumerState<UserPassRequestDialog> createState() =>
      _UserPassRequestDialogState();
}

class _UserPassRequestDialogState extends ConsumerState<UserPassRequestDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.initialUsername ?? '');
    _passwordController =
        TextEditingController(text: widget.initialPassword ?? '');
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.dns, color: Color(0xFF112b66)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'FTP Bağlantı Bilgileri',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF112b66),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Server bilgileri
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF112b66).withOpacity(0.1),
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
              const SizedBox(height: 16),

              // Kullanıcı adı
              TextField(
                controller: _usernameController,
                enabled: !_isConnecting,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF112b66)),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Şifre
              TextField(
                controller: _passwordController,
                enabled: !_isConnecting,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
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
                    borderSide: const BorderSide(color: Color(0xFF112b66)),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),

              if (_isConnecting) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF112b66),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
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
        ),
        actions: [
          TextButton(
            onPressed:
                _isConnecting ? null : () => Navigator.pop(context, null),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isConnecting ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : testConnectionAndSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF112b66),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            icon: Icon(_isConnecting ? Icons.hourglass_empty : Icons.check),
            label: Text(
              _isConnecting ? 'Test Ediliyor...' : 'Bağlan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> testFtpConnection(String username, String password) async {
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

      print(
          '✅ FTP test bağlantısı başarılı - ${testFiles.length} item bulundu');
    } catch (e) {
      print('❌ FTP test bağlantısı başarısız: $e');
      throw Exception(
          'FTP sunucuya bağlanılamıyor. Kullanıcı adı ve şifrenizi kontrol edin.');
    }
  }

  Future<void> testConnectionAndSave() async {
    // Bu fonksiyon kullanıcı adı ve şifreyi alıp test ediyor ve kaydediyor
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı ve şifre boş olamaz')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await testFtpConnection(username, password);

      // Başarılı ise navigator ile dön
      if (context.mounted)
        Navigator.pop(context, {'username': username, 'password': password});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
}
