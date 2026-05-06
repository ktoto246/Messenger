import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/story_service.dart';
import '../config/app_config.dart';

/// Экран просмотра историй — Telegram/Instagram стиль
/// [stories] — список историй одного пользователя (или всех)
/// [initialIndex] — с какой истории начинать
class StoryViewScreen extends StatefulWidget {
  /// Плоский список всех историй (сгруппированных или нет)
  final List<dynamic> stories;
  final int initialIndex;

  const StoryViewScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  final StoryService _storyService = StoryService();

  late int _currentIndex;
  late AnimationController _progressController;

  // Для видео-историй
  VideoPlayerController? _videoController;
  bool _isVideoStory = false;

  // Длительность истории
  static const Duration _imageDuration = Duration(seconds: 5);

  // Контроллер текстового ответа
  final TextEditingController _replyController = TextEditingController();
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(vsync: this);
    _loadStory(_currentIndex);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadStory(int index) async {
    _progressController.stop();
    _progressController.reset();

    // Освобождаем старый видео контроллер
    await _videoController?.dispose();
    _videoController = null;
    _isVideoStory = false;

    if (!mounted) return;

    final story = widget.stories[index];
    final storyId = story['storyID'] ?? story['storyId'] ?? story['id'];
    final rawUrl = story['mediaUrl'] ?? story['MediaUrl'] ?? '';
    final mediaUrl = rawUrl.startsWith('http')
        ? rawUrl
        : '${AppConfig.baseUrl.replaceAll('/api', '')}$rawUrl';
    final mediaType = (story['mediaType'] ?? story['MediaType'] ?? 'image').toString().toLowerCase();

    // Отмечаем как просмотренную
    if (storyId != null) {
      _storyService.markStoryViewed(storyId is int ? storyId : int.tryParse(storyId.toString()) ?? 0);
    }

    if (mediaType == 'video' || mediaUrl.contains(RegExp(r'\.(mp4|webm|mov)', caseSensitive: false))) {
      _isVideoStory = true;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      await _videoController!.initialize();
      if (!mounted) return;
      _videoController!.play();
      setState(() {});
      // Прогресс = длительность видео
      _progressController.duration = _videoController!.value.duration;
      _progressController.forward();
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          _nextStory();
        }
      });
    } else {
      // Изображение
      if (!mounted) return;
      setState(() {});
      _progressController.duration = _imageDuration;
      _progressController.forward();
    }

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory(_currentIndex);
    } else {
      // Все истории просмотрены
      if (mounted) Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStory(_currentIndex);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _pauseResume(bool pause) {
    if (pause) {
      _progressController.stop();
      _videoController?.pause();
    } else {
      _progressController.forward();
      _videoController?.play();
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.endsWith('Z') ? dateStr : '${dateStr}Z').toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 24) return '${diff.inHours} ч назад';
      return '${diff.inDays} д назад';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final story = widget.stories[_currentIndex];
    final user = story['user'] ?? story['User'];
    final userName = user?['displayName'] ?? user?['DisplayName'] ?? 'Пользователь';
    final avatarUrl = user?['avatarUrl'] ?? user?['AvatarUrl'];
    final caption = story['caption'] ?? story['Caption'] ?? '';
    final createdAt = story['createdAt'] ?? story['CreatedAt'];
    final rawUrl = story['mediaUrl'] ?? story['MediaUrl'] ?? '';
    final mediaUrl = rawUrl.startsWith('http')
        ? rawUrl
        : '${AppConfig.baseUrl.replaceAll('/api', '')}$rawUrl';

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onLongPressStart: (_) => _pauseResume(true),
        onLongPressEnd: (_) => _pauseResume(false),
        onTapDown: (details) {
          final halfWidth = MediaQuery.of(context).size.width / 2;
          if (details.globalPosition.dx < halfWidth) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // ── Медиаконтент ──
            Positioned.fill(child: _buildMedia(mediaUrl)),

            // ── Затемнение сверху для текста ──
            Positioned(
              top: 0, left: 0, right: 0, height: 120,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Затемнение снизу для подписи ──
            Positioned(
              bottom: 0, left: 0, right: 0, height: 160,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Прогресс-бары ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8, right: 8,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          double progress = i < _currentIndex
                              ? 1.0
                              : i == _currentIndex
                                  ? _progressController.value
                                  : 0.0;
                          return LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 2.5,
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Шапка: аватар + имя + время + закрыть ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12, right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withValues(alpha: 0.5),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            _timeAgo(createdAt.toString()),
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Подпись ──
            if (caption.isNotEmpty)
              Positioned(
                bottom: _isReplying ? 80 : 80,
                left: 16, right: 16,
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Поле ответа снизу ──
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 12, right: 12,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isReplying = true);
                    _pauseResume(true);
                  },
                  child: _isReplying
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                onSubmitted: (_) {
                                  setState(() => _isReplying = false);
                                  _replyController.clear();
                                  _pauseResume(false);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Ответить ${userName.split(' ').first}...',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white12,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                // TODO: отправить ответ в личку
                                setState(() => _isReplying = false);
                                _replyController.clear();
                                _pauseResume(false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ответ отправлен ✅')),
                                );
                              },
                              child: const CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.send, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            'Ответить ${userName.split(' ').first}...',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(String url) {
    if (_isVideoStory && _videoController != null && _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    if (url.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 60));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (context, url, err) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 60),
      ),
    );
  }
}
