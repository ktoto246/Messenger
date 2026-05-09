import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  double _cacheSizeMB = 0;
  double _hiveSizeMB = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateSizes();
  }

  Future<void> _calculateSizes() async {
    setState(() => _isLoading = true);
    
    // 1. Расчет размера Hive
    double hiveSize = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File && (file.path.endsWith('.hive') || file.path.endsWith('.lock'))) {
          hiveSize += await file.length();
        }
      }
    } catch (_) {}

    // 2. Расчет размера кэша медиа (через CacheManager)
    // В FlutterCacheManager нет прямого метода размера, 
    // поэтому мы просто смотрим размер папки кэша
    double mediaSize = 0;
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) mediaSize += await file.length();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _hiveSizeMB = hiveSize / (1024 * 1024);
        _cacheSizeMB = mediaSize / (1024 * 1024);
        _isLoading = false;
      });
    }
  }

  Future<void> _clearMediaCache() async {
    await DefaultCacheManager().emptyCache();
    _calculateSizes();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Кэш медиа очищен 🧹")));
  }

  Future<void> _clearDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Очистить базу данных?"),
        content: const Text("Все чаты и сообщения будут удалены из памяти телефона. Потребуется синхронизация с сервером."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отмена")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Очистить", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Hive.box('chats_box').clear();
      await Hive.box('messages_box').clear();
      _calculateSizes();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : const Color(0xFFF2F2F6);
    Color blockColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text("Данные и память", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader("ИСПОЛЬЗОВАНИЕ ПАМЯТИ"),
          _buildSizeBlock(blockColor, textColor),
          
          const SizedBox(height: 30),
          _buildSectionHeader("ДЕЙСТВИЯ"),
          _buildActionBlock(blockColor, textColor),
          
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Очистка кэша не удалит ваши сообщения из облака, только временные файлы с этого устройства.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }

  Widget _buildSizeBlock(Color blockColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildInfoRow("Кэш медиа (фото, видео)", _cacheSizeMB, textColor),
          const Divider(height: 1, indent: 16),
          _buildInfoRow("База данных (чаты)", _hiveSizeMB, textColor),
          const Divider(height: 1, indent: 16),
          _buildInfoRow("Всего", _cacheSizeMB + _hiveSizeMB, textColor, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, double sizeMB, Color textColor, {bool isTotal = false}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: textColor, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      trailing: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text("${sizeMB.toStringAsFixed(2)} MB", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionBlock(Color blockColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: Text("Очистить кэш медиа", style: TextStyle(color: textColor)),
            onTap: _clearMediaCache,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text("Очистить базу данных", style: TextStyle(color: Colors.red)),
            onTap: _clearDatabase,
          ),
        ],
      ),
    );
  }
}
