import 'package:flutter/material.dart';
import '../services/story_service.dart';
import '../screens/story_view_screen.dart';
import '../screens/story_create_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryBar extends StatefulWidget {
  const StoryBar({super.key});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  final StoryService _storyService = StoryService();
  List<dynamic> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final stories = await _storyService.getStories();
    if (mounted) setState(() { _stories = stories; _isLoading = false; });
  }

  /// Открыть экран создания истории
  Future<void> _openCreateStory() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryCreateScreen()),
    );
    // Если история была опубликована — обновляем ленту
    if (result == true && mounted) {
      _loadStories();
    }
  }

  /// Открыть просмотр историй с нужным индексом
  void _openStoryView(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StoryViewScreen(
          stories: _stories,
          initialIndex: index,
        ),
        // Плавный переход, как в Telegram
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: _isLoading
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildAddStory(isDark);
                final story = _stories[index - 1];
                return _buildStoryItem(story, index - 1, isDark);
              },
            ),
    );
  }

  /// Кнопка «Мой пульс» → открывает создание истории
  Widget _buildAddStory(bool isDark) {
    return GestureDetector(
      onTap: _openCreateStory,
      child: Padding(
        padding: const EdgeInsets.only(right: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  child: Icon(Icons.person, size: 35, color: isDark ? Colors.white70 : Colors.black54),
                ),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Мой пульс',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка чужой истории
  Widget _buildStoryItem(dynamic story, int index, bool isDark) {
    // Защита от null
    final user = story['user'] ?? story['User'];
    if (user == null) return const SizedBox.shrink();

    final String name = user['displayName'] ?? user['DisplayName'] ?? 'User';
    final String? avatarUrl = user['avatarUrl'] ?? user['AvatarUrl'];
    final bool isViewed = story['isViewed'] ?? story['IsViewed'] ?? false;

    return GestureDetector(
      onTap: () => _openStoryView(index),
      child: Padding(
        padding: const EdgeInsets.only(right: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кольцо (синее — непросмотрено, серое — просмотрено)
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isViewed
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: isViewed
                    ? Border.all(color: Colors.grey, width: 2)
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.black : Colors.white,
                ),
                child: CircleAvatar(
                  radius: 27,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 64,
              child: Text(
                name,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
