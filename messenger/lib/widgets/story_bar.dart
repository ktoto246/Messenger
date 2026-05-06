import 'package:flutter/material.dart';
import '../services/story_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryBar extends StatefulWidget {
  const StoryBar({super.key});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  final StoryService _storyService = StoryService();
  List<dynamic> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  void _loadStories() async {
    final stories = await _storyService.getStories();
    if (mounted) setState(() => _stories = stories);
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStory(isDark);
          }
          final story = _stories[index - 1];
          return _buildStoryItem(story, isDark);
        },
      ),
    );
  }

  Widget _buildAddStory(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(radius: 30, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300], child: const Icon(Icons.person, size: 35)),
              Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 18))),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Мой пульс", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(dynamic story, bool isDark) {
    final user = story['user'];
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2)),
            child: CircleAvatar(
              radius: 27,
              backgroundImage: user['avatarUrl'] != null ? CachedNetworkImageProvider(user['avatarUrl']) : null,
              child: user['avatarUrl'] == null ? const Icon(Icons.person) : null,
            ),
          ),
          const SizedBox(height: 5),
          Text(user['displayName'] ?? "User", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
