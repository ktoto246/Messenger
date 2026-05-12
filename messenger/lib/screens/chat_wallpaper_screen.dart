import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import '../services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Экран выбора обоев для чата
class ChatWallpaperScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final String? partnerAvatarUrl;

  const ChatWallpaperScreen({super.key, required this.chatId, required this.chatName, this.partnerAvatarUrl});

  @override
  State<ChatWallpaperScreen> createState() => _ChatWallpaperScreenState();
}

class _ChatWallpaperScreenState extends State<ChatWallpaperScreen> {
  String? _currentWallpaper;
  bool _isLoading = false;
  double _blur = 0;
  double _dim = 0.3;

  // Встроенные градиентные темы
  final List<Map<String, dynamic>> _presets = [
    {'name': 'Без обоев', 'gradient': null, 'color': Colors.transparent},
    {'name': 'Закат', 'gradient': const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Океан', 'gradient': const LinearGradient(colors: [Color(0xFF0575E6), Color(0xFF021B79)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Лес', 'gradient': const LinearGradient(colors: [Color(0xFF134E5E), Color(0xFF71B280)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Розовый', 'gradient': const LinearGradient(colors: [Color(0xFFf953c6), Color(0xFFb91d73)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Ночь', 'gradient': const LinearGradient(colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243e)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Мята', 'gradient': const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF96C93D)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
    {'name': 'Пепел', 'gradient': const LinearGradient(colors: [Color(0xFF485563), Color(0xFF29323c)], begin: Alignment.topLeft, end: Alignment.bottomRight)},
  ];

  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    NotificationService.getChatWallpaper(widget.chatId).then((w) {
      if (mounted) setState(() => _currentWallpaper = w);
    });
    NotificationService.getChatWallpaperSettings(widget.chatId).then((s) {
      if (mounted) setState(() { _blur = s['blur']!; _dim = s['dim']!; });
    });
  }

  Future<void> _saveSettings() async {
    await NotificationService.setChatWallpaperSettings(widget.chatId, blur: _blur, dim: _dim);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() { _isLoading = true; });
    await NotificationService.setChatWallpaper(widget.chatId, file.path);
    if (mounted) setState(() { _currentWallpaper = file.path; _selectedPreset = null; _isLoading = false; });
  }

  Future<void> _setPreset(String name) async {
    setState(() => _selectedPreset = name);
    if (name == 'Без обоев') {
      await NotificationService.setChatWallpaper(widget.chatId, null);
      setState(() { _currentWallpaper = null; });
    } else {
      await NotificationService.setChatWallpaper(widget.chatId, 'preset:$name');
      setState(() { _currentWallpaper = 'preset:$name'; });
    }
  }

  Future<void> _setPartnerAvatar() async {
    if (widget.partnerAvatarUrl == null) return;
    await NotificationService.setChatWallpaper(widget.chatId, 'url:${widget.partnerAvatarUrl}');
    setState(() { _currentWallpaper = 'url:${widget.partnerAvatarUrl}'; _blur = 15; }); // По умолчанию размываем аватар
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Обои чата', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Превью чата
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                // Фон
                Positioned.fill(
                  child: _currentWallpaper == null
                      ? Container(color: isDark ? const Color(0xFF0D1117) : const Color(0xFFEFEFEF))
                      : _currentWallpaper!.startsWith('preset:')
                          ? _buildPresetBackground(_currentWallpaper!.replaceFirst('preset:', ''))
                          : _currentWallpaper!.startsWith('url:')
                              ? CachedNetworkImage(imageUrl: _currentWallpaper!.replaceFirst('url:', ''), fit: BoxFit.cover)
                              : Image.file(File(_currentWallpaper!), fit: BoxFit.cover),
                ),
                // Размытие и затемнение
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                    child: Container(color: Colors.black.withValues(alpha: _dim)),
                  ),
                ),
                // Примерные сообщения-превью
                Positioned(
                  bottom: 16, left: 0, right: 0,
                  child: Column(
                    children: [
                      _previewBubble("Привет! Как дела?", false, isDark),
                      const SizedBox(height: 8),
                      _previewBubble("Всё отлично, спасибо! 😊", true, isDark),
                    ],
                  ),
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Галерея'),
                    onPressed: _pickFromGallery,
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                if (widget.partnerAvatarUrl != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Аватар'),
                      onPressed: _setPartnerAvatar,
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Слайдеры размытия и яркости
          if (_currentWallpaper != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.blur_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text("Размытие", style: TextStyle(fontSize: 12)),
                      Expanded(child: Slider(value: _blur, min: 0, max: 30, onChanged: (v) { setState(() => _blur = v); _saveSettings(); })),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.opacity, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text("Затемнение", style: TextStyle(fontSize: 12)),
                      Expanded(child: Slider(value: _dim, min: 0, max: 0.8, onChanged: (v) { setState(() => _dim = v); _saveSettings(); })),
                    ],
                  ),
                ],
              ),
            ),

          // Пресеты
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1,
              ),
              itemCount: _presets.length,
              itemBuilder: (ctx, i) {
                final preset = _presets[i];
                final name = preset['name'] as String;
                final gradient = preset['gradient'] as LinearGradient?;
                final isSelected = _selectedPreset == name ||
                    (_currentWallpaper == 'preset:$name') ||
                    (name == 'Без обоев' && _currentWallpaper == null);

                return GestureDetector(
                  onTap: () => _setPreset(name),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: gradient,
                          color: gradient == null ? (isDark ? Colors.grey[800] : Colors.grey[200]) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                        ),
                        child: gradient == null
                            ? Center(child: Icon(Icons.block, color: isDark ? Colors.white54 : Colors.black38))
                            : null,
                      ),
                      if (isSelected)
                        const Positioned(
                          bottom: 4, right: 4,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                      Positioned(
                        bottom: 4, left: 4,
                        child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPresetBackground(String name) {
    final preset = _presets.firstWhere((p) => p['name'] == name, orElse: () => _presets[0]);
    final gradient = preset['gradient'] as LinearGradient?;
    if (gradient == null) return Container(color: Colors.grey[200]);
    return Container(decoration: BoxDecoration(gradient: gradient));
  }

  Widget _previewBubble(String text, bool isMe, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(left: isMe ? 60 : 16, right: isMe ? 16 : 60),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
          ),
          child: Text(text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 13)),
        ),
      ),
    );
  }
}
