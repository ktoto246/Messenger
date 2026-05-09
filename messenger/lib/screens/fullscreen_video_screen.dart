import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoScreen extends StatefulWidget {
  final String videoUrl;
  final String senderName;
  final String date;

  const FullscreenVideoScreen({super.key, required this.videoUrl, required this.senderName, required this.date});

  @override
  State<FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<FullscreenVideoScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _controller.play(); // Автоплей при открытии
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.senderName, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(widget.date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls), // Тап скрывает/показывает управление
        child: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(_controller),
                      if (_showControls)
                        Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _isPlaying ? _controller.pause() : _controller.play();
                                    _isPlaying = !_isPlaying;
                                  });
                                },
                              ),
                              Expanded(
                                child: VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true, 
                                  colors: const VideoProgressColors(playedColor: Colors.blue, backgroundColor: Colors.white24),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}