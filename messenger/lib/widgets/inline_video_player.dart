import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../screens/fullscreen_video_screen.dart';

class InlineVideoPlayer extends StatefulWidget {
  final String url;
  final String senderName;
  final String date;

  const InlineVideoPlayer({super.key, required this.url, required this.senderName, required this.date});

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      }).catchError((e) {
        debugPrint("Ошибка инлайн видео: $e");
        return null;
      });
    _controller.addListener(() {
      if (mounted) {
        final playing = _controller.value.isPlaying;
        if (playing != _isPlaying) setState(() => _isPlaying = playing);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_isInitialized) return;
        if (_isPlaying) {
          _controller.pause();
        } else {
          // Открываем на весь экран со звуком
          _controller.pause();
          Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenVideoScreen(
            videoUrl: widget.url, senderName: widget.senderName, date: widget.date,
          )));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          height: 250,
          color: Colors.black,
          child: _isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    // Показываем иконку Play поверх превью
                    if (!_isPlaying)
                      Container(
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                      ),
                  ],
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}