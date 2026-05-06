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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          _controller.setVolume(0.0); // Глушим звук для фона
          _controller.setLooping(true); // Зацикливаем (как гифку)
          _controller.play(); // Запускаем сразу
          setState(() {});
        }
      }).catchError((e) => print("Ошибка инлайн видео: $e"));
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
        // При тапе открываем на весь экран со звуком
        Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenVideoScreen(
          videoUrl: widget.url, senderName: widget.senderName, date: widget.date,
        )));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          height: 250, // Прямоугольный формат
          color: Colors.black,
          child: _controller.value.isInitialized
              ? VideoPlayer(_controller)
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}