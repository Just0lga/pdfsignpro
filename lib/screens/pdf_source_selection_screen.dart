import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfsignpro/provider/auth_provider.dart';
import 'package:pdfsignpro/provider/ftp_provider.dart';
import 'package:pdfsignpro/provider/pdf_provider.dart';
import 'package:pdfsignpro/screens/ftp_browser_screen.dart';
import 'package:pdfsignpro/services/local_pdf_loader.dart';
import 'package:pdfsignpro/services/asset_pdf_loader.dart';
import '../models/backend_models/perm.dart';

class PdfSourceSelectionScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<PdfSourceSelectionScreen> createState() =>
      _PdfSourceSelectionScreenState();
}

class _PdfSourceSelectionScreenState
    extends ConsumerState<PdfSourceSelectionScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Sayfa her açıldığında API kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performApiCheck();
    });
  }

  /// 🆕 Sayfa açıldığında otomatik API kontrolü
  Future<void> _performApiCheck() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔄 PDF Kaynak seçim sayfası - API kontrolü başlıyor...');

      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.forceFullRefresh();

      if (success) {
        print('✅ API başarılı - server listesi güncellendi');

        // Güncel server sayısını göster
        final currentState = ref.read(authProvider);
        if (currentState.fullResponse != null) {
          final ftpCount = currentState.fullResponse!.perList
              .where((p) => p.permtype == 'ftp' && p.ap == 1)
              .length;
          final localCount = currentState.fullResponse!.perList
              .where((p) => p.type == 'local' && p.ap == 1)
              .length;
          final assetCount = currentState.fullResponse!.perList
              .where((p) => p.type == 'asset' && p.ap == 1)
              .length;

          print(
              '📊 Güncel server sayıları: $ftpCount FTP, $localCount Local, $assetCount Asset');

          _showApiMessage(
              'Server listesi güncellendi\n$ftpCount FTP, $localCount Local, $assetCount Asset server',
              Colors.green,
              Icons.cloud_done);
        }
      } else {
        print('❌ API başarısız - cache\'deki veriler korundu');
        _showApiMessage('Offline mod - Kaydedilmiş server listesi gösteriliyor',
            Colors.orange, Icons.cloud_off);
      }
    } catch (e) {
      print('❌ API kontrol hatası: $e');
      _showApiMessage('Bağlantı hatası - Kaydedilmiş veriler gösteriliyor',
          Colors.red, Icons.error_outline);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showApiMessage(String message, Color color, IconData icon) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.fullResponse == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('İzin bilgisi bulunamadı'),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: Icon(Icons.logout),
              label: Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final allFtpPermissions = ref.watch(allFtpPermissionsProvider);
    final localPermissions = ref.watch(localPermissionsProvider);
    final assetPermissions = ref.watch(assetPermissionsProvider);

    return RefreshIndicator(
      color: Color(0xFF112b66),
      onRefresh: _performApiCheck, // Pull-to-refresh ile de API kontrolü
      child: SingleChildScrollView(
        physics:
            AlwaysScrollableScrollPhysics(), // RefreshIndicator için gerekli
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🆕 API durum göstergesi
            if (_isRefreshing) ...[
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF112b66).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF112b66).withOpacity(0.3)),
                ),
                child: Row(
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
                      'Server listesi kontrol ediliyor...',
                      style: TextStyle(
                        color: Color(0xFF112b66),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // FTP Sunucuları Bölümü
            if (allFtpPermissions.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.dns,
                title: 'Serverlar',
                count: allFtpPermissions.length,
              ),
              SizedBox(height: 12),
              ...allFtpPermissions
                  .map((ftpPerm) => _buildFtpServerCard(context, ref, ftpPerm))
                  .toList(),
              SizedBox(height: 24),
            ],

            // Lokal Dosyalar Bölümü
            if (localPermissions.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.folder,
                title: 'Lokal Dosyalar',
                count: localPermissions.length,
              ),
              SizedBox(height: 12),
              ...localPermissions
                  .map((localPerm) => _buildLocalCard(context, ref, localPerm))
                  .toList(),
              SizedBox(height: 24),
            ],

            // Asset Dosyalar Bölümü
            if (assetPermissions.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.folder_special,
                title: 'Asset Dosyalar',
                count: assetPermissions.length,
              ),
              SizedBox(height: 12),
              ...assetPermissions
                  .map((assetPerm) => _buildAssetCard(context, ref, assetPerm))
                  .toList(),
            ],

            // Hiç izin yoksa
            if (allFtpPermissions.isEmpty &&
                localPermissions.isEmpty &&
                assetPermissions.isEmpty) ...[
              SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.block, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Hiç PDF kaynağı izni bulunamadı',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _logout(context, ref),
                      icon: Icon(Icons.logout),
                      label: Text('Çıkış Yap'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Alt boşluk (RefreshIndicator için)
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF112b66).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Color(0xFF112b66), size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF112b66),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFF112b66),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Spacer(),
        // 🆕 Yenileme butonu
        if (!_isRefreshing)
          IconButton(
            onPressed: _performApiCheck,
            icon: Icon(Icons.refresh, color: Color(0xFF112b66)),
            tooltip: 'Server listesini yenile',
          ),
      ],
    );
  }

  Widget _buildFtpServerCard(
      BuildContext context, WidgetRef ref, Perm ftpPerm) {
    final bool isConfigured =
        ftpPerm.host != null && ftpPerm.uname != null && ftpPerm.pass != null;

    final bool isAccessible = isConfigured;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isAccessible ? Color(0xFF112b66) : Colors.grey,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap:
            isAccessible ? () => _selectFtpServer(context, ref, ftpPerm) : null,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAccessible
                          ? Color(0xFF112b66).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.dns,
                      color: isAccessible ? Color(0xFF112b66) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ftpPerm.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAccessible ? Colors.black : Colors.grey,
                          ),
                        ),
                        Text(
                          'FTP Server - PDF dosyalarını görüntüle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusIcon(isAccessible),
                ],
              ),
              if (!isAccessible) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sunucu bilgileri eksik - Erişim sağlanamıyor',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalCard(BuildContext context, WidgetRef ref, Perm localPerm) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.green, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectLocalSource(context, ref, localPerm),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder, color: Colors.green, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localPerm.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Cihazınızdan dosya seçin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, WidgetRef ref, Perm assetPerm) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.purple, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectAssetSource(context, ref, assetPerm),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.folder_special, color: Colors.purple, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assetPerm.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Uygulama içi örnek dosya',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    )
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.purple, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isAccessible) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isAccessible ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        isAccessible ? Icons.check : Icons.close,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  void _selectFtpServer(BuildContext context, WidgetRef ref, Perm ftpPerm) {
    ref.read(selectedFtpConnectionProvider.notifier).state = ftpPerm;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FtpBrowserScreen(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.dns, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('${ftpPerm.name} FTP sunucusu seçildi'),
            ),
          ],
        ),
        backgroundColor: Color(0xFF112b66),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _selectLocalSource(BuildContext context, WidgetRef ref, Perm localPerm) {
    final notifier = ref.read(pdfProvider.notifier);

    print('🔄 Local PDF loading başlatılıyor...');

    // PDF loading'i başlat
    notifier.loadPdf(LocalPdfLoader()).then((_) {
      print('✅ Local PDF loading tamamlandı');

      // Success mesajı göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.folder, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${localPerm.name} kaynağından PDF yüklendi'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }).catchError((error) {
      print('❌ Local PDF loading hatası: $error');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF yükleme hatası: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _selectAssetSource(BuildContext context, WidgetRef ref, Perm assetPerm) {
    final notifier = ref.read(pdfProvider.notifier);

    print('🔄 Asset PDF loading başlatılıyor...');

    // PDF loading'i başlat
    notifier.loadPdf(AssetPdfLoader('assets/sample.pdf')).then((_) {
      print('✅ Asset PDF loading tamamlandı');

      // Success mesajı göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.folder_special, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${assetPerm.name} kaynağından PDF yüklendi'),
                ),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }).catchError((error) {
      print('❌ Asset PDF loading hatası: $error');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF yükleme hatası: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Çıkış Yap'),
        content: Text('Uygulamadan çıkmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              // Auth state'i temizle
              ref.read(authProvider.notifier).logout();
              // PDF state'i temizle
              ref.read(pdfProvider.notifier).reset();
              // FTP seçimini temizle
              ref.read(selectedFtpConnectionProvider.notifier).state = null;

              Navigator.pop(context); // Dialog'u kapat

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Başarıyla çıkış yapıldı'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(
              'Çıkış Yap',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
