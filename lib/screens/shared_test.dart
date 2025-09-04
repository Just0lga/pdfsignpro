// shared_preferences_debug_screen.dart - Test/Debug sayfası

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesDebugScreen extends StatefulWidget {
  @override
  _SharedPreferencesDebugScreenState createState() =>
      _SharedPreferencesDebugScreenState();
}

class _SharedPreferencesDebugScreenState
    extends State<SharedPreferencesDebugScreen> {
  Map<String, dynamic> _allPreferences = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllPreferences();
  }

  Future<void> _loadAllPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, dynamic> preferences = {};

      for (String key in keys) {
        final value = prefs.get(key);
        preferences[key] = value;
      }

      setState(() {
        _allPreferences = preferences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteKey(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Silme Onayı'),
        content:
            Text('Bu kaydı silmek istediğinizden emin misiniz?\n\nKey: $key'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await _loadAllPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt silindi: $key'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ DİKKAT', style: TextStyle(color: Colors.red)),
        content: Text(
          'TÜM SharedPreferences kayıtlarını silmek üzeresiniz!\n\n'
          'Bu işlem geri alınamaz ve tüm uygulama ayarlarını sıfırlar.\n\n'
          'Devam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('HEPSİNİ SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _loadAllPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tüm kayıtlar silindi'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _clearFtpCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final ftpKeys = keys
        .where((key) =>
            key.toLowerCase().contains('ftp') ||
            key.toLowerCase().contains('credential') ||
            key.contains('username') ||
            key.contains('password'))
        .toList();

    if (ftpKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FTP ile ilgili kayıt bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('FTP Kayıtlarını Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Silinecek kayıtlar (${ftpKeys.length} adet):'),
            SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ftpKeys.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '• ${ftpKeys[index]}',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (String key in ftpKeys) {
        await prefs.remove(key);
      }
      await _loadAllPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ftpKeys.length} FTP kaydı silindi'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _copyToClipboard(String key, dynamic value) {
    final text = '$key: $value';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kopyalandı: $key'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  List<MapEntry<String, dynamic>> get _filteredPreferences {
    if (_searchQuery.isEmpty) {
      return _allPreferences.entries.toList();
    }

    return _allPreferences.entries.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.value
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Color _getTypeColor(dynamic value) {
    if (value is String) return Colors.green;
    if (value is int) return Colors.blue;
    if (value is double) return Colors.indigo;
    if (value is bool) return Colors.orange;
    if (value is List) return Colors.purple;
    return Colors.grey;
  }

  String _getTypeLabel(dynamic value) {
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'List<String>';
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredPreferences;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SharedPreferences Debug',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF112b66),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllPreferences,
            tooltip: 'Yenile',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_ftp') {
                _clearFtpCredentials();
              } else if (value == 'clear_all') {
                _clearAll();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_ftp',
                child: Row(
                  children: [
                    Icon(Icons.dns, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('FTP Kayıtlarını Sil'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('TÜM Kayıtları Sil'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Özet bilgi kartı
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Color(0xFF112b66).withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_allPreferences.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF112b66),
                            ),
                          ),
                          Text(
                            'Toplam Kayıt',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_allPreferences.entries.where((e) => e.value is String).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'String',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_allPreferences.entries.where((e) => e.value is bool).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Boolean',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_allPreferences.entries.where((e) => e.value is int || e.value is double).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'Sayı',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arama kutusu
                Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Ara (key veya value)...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),

                // Kayıt listesi
                Expanded(
                  child: _allPreferences.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storage, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'SharedPreferences boş',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : filteredEntries.isEmpty
                          ? Center(
                              child: Text(
                                'Arama sonucu bulunamadı',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredEntries.length,
                              padding: EdgeInsets.only(bottom: 16),
                              itemBuilder: (context, index) {
                                final entry = filteredEntries[index];
                                final key = entry.key;
                                final value = entry.value;
                                final typeColor = _getTypeColor(value);
                                final typeLabel = _getTypeLabel(value);

                                return Card(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          typeLabel[0].toUpperCase(),
                                          style: TextStyle(
                                            color: typeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      key,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: typeColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            typeLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: typeColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          value.toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.copy, size: 20),
                                          onPressed: () =>
                                              _copyToClipboard(key, value),
                                          tooltip: 'Kopyala',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              size: 20, color: Colors.red),
                                          onPressed: () => _deleteKey(key),
                                          tooltip: 'Sil',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
