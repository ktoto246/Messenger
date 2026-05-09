import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/story_service.dart';

/// Экран создания и публикации истории
class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final StoryService _storyService = StoryService();
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
  bool _isVideo = false;
  bool _isLoading = false;
  bool _isPosting = false;
  bool _isPinned = false; // 📌 Highlight: сохраняется навсегда

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery({required bool video}) async {
    try {
      setState(() => _isLoading = true);
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null && mounted) {
        setState(() {
          _selectedFile = File(file.path);
          _isVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора файла: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromCamera({required bool video}) async {
    try {
      setState(() => _isLoading = true);
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null && mounted) {
        setState(() {
          _selectedFile = File(file.path);
          _isVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка камеры: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _sheetTile(Icons.photo_library, 'Фото из галереи', () { Navigator.pop(ctx); _pickFromGallery(video: false); }),
              _sheetTile(Icons.videocam, 'Видео из галереи', () { Navigator.pop(ctx); _pickFromGallery(video: true); }),
              _sheetTile(Icons.camera_alt, 'Сделать фото', () { Navigator.pop(ctx); _pickFromCamera(video: false); }),
              _sheetTile(Icons.camera, 'Записать видео', () { Navigator.pop(ctx); _pickFromCamera(video: true); }),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _sheetTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Future<void> _publishStory() async {
    if (_selectedFile == null) return;
    setState(() => _isPosting = true);

    final caption = _captionController.text.trim();
    final success = await _storyService.uploadAndPostStory(_selectedFile!, caption: caption.isNotEmpty ? caption : null, isPinned: _isPinned);

    if (!mounted) return;
    setState(() => _isPosting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isPinned ? 'История сохранена в актуальное 📌' : 'История опубликована ✅'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // true = нужно обновить StoryBar
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка публикации 😔'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFile = _selectedFile != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Новая история', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (hasFile)
            TextButton(
              onPressed: _isPosting ? null : _publishStory,
              child: Text(
                'Опубликовать',
                style: TextStyle(
                  color: _isPosting ? Colors.grey : Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: _isPosting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text('Публикуем историю...', style: TextStyle(color: Colors.white60)),
                ],
              ),
            )
          : Column(
              children: [
                // ── Превью медиа ──
                Expanded(
                  child: hasFile
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            // Превью (изображение)
                            if (!_isVideo)
                              Positioned.fill(
                                child: Image.file(_selectedFile!, fit: BoxFit.cover),
                              ),
                            // Для видео — иконка (в реальном проекте можно добавить video_player превью)
                            if (_isVideo)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam, color: Colors.white, size: 80),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedFile!.path.split('/').last,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            // Кнопка смены медиа
                            Positioned(
                              top: 12, right: 12,
                              child: GestureDetector(
                                onTap: _showPickerSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                                      SizedBox(width: 4),
                                      Text('Сменить', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      // Нет файла — кнопка выбора
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                          : GestureDetector(
                              onTap: _showPickerSheet,
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C1E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, color: Colors.blue, size: 64),
                                      SizedBox(height: 16),
                                      Text(
                                        'Нажмите чтобы выбрать\nфото или видео',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white60, fontSize: 16),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'История будет видна 24 часа',
                                        style: TextStyle(color: Colors.white38, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),

                // ── Подпись ──
                if (hasFile)
                  Container(
                    color: const Color(0xFF1C1C1E),
                    padding: EdgeInsets.only(
                      left: 16, right: 16, top: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_outlined, color: Colors.white38, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _captionController,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: 'Добавить подпись...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.push_pin, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Сохранить в Актуальном', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const Text('Не исчезнет через 24 часа', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: _isPinned,
                              activeThumbColor: Colors.orange,
                              onChanged: (v) => setState(() => _isPinned = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
