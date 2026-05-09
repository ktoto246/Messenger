import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:math';

class VideoCircle extends StatefulWidget {
  final String url;
  const VideoCircle({super.key, required this.url});

  @override
  State<VideoCircle> createState() => _VideoCircleState();
}

class _VideoCircleState extends State<VideoCircle> {
  VideoPlayerController? _controller; 
  bool _isExpanded = false;
  bool _isPlaying = true;
  double? _dragProgress;
  
  // ДОБАВИЛИ ФЛАГ: Скачиваем ли мы видео прямо сейчас?
  bool _isDownloading = false; 

  @override
  void initState() {
    super.initState();
    _initializeAndCacheVideo();
  }

  Future<void> _initializeAndCacheVideo() async {
    try {
      // 1. Спрашиваем у кэша: "Брат, у тебя уже есть этот файл?"
      var fileInfo = await DefaultCacheManager().getFileFromCache(widget.url);
      File file;

      if (fileInfo != null) {
        // Файл УЖЕ на телефоне! Берем его мгновенно, спиннер НЕ включаем.
        file = fileInfo.file;
      } else {
        // Файла нет. Включаем спиннер загрузки и качаем из интернета.
        if (mounted) setState(() => _isDownloading = true);
        file = await DefaultCacheManager().getSingleFile(widget.url);
        if (mounted) setState(() => _isDownloading = false);
      }

      if (!mounted) return;

      // 2. Запускаем локальный файл
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            _controller!.setVolume(0.0);
            _controller!.setLooping(true);
            _controller!.play();
            setState(() {});
          }
        });

      _controller!.addListener(() {
        if (mounted && _dragProgress == null) {
          setState(() {}); 
        }
      });
    } catch (e) {
      debugPrint("Ошибка загрузки video: $e");
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_controller == null) return; 
    setState(() {
      if (!_isExpanded) {
        _isExpanded = true;
        _controller!.setVolume(1.0);
        _controller!.seekTo(Duration.zero);
        _controller!.play();
        _isPlaying = true;
      } else {
        _isPlaying ? _controller!.pause() : _controller!.play();
        _isPlaying = !_isPlaying;
      }
    });
  }

  void _closeExpanded() {
    if (_controller == null) return;
    setState(() {
      _isExpanded = false;
      _controller!.setVolume(0.0);
      _controller!.play();
      _isPlaying = true;
      _dragProgress = null;
    });
  }

  void _handleDrag(Offset localPosition, BoxConstraints constraints) {
    if (_controller == null || !_isExpanded || _isPlaying || !_controller!.value.isInitialized) return;
    
    Offset center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    double angle = atan2(localPosition.dy - center.dy, localPosition.dx - center.dx);
    double adjustedAngle = angle + pi / 2;
    if (adjustedAngle < 0) adjustedAngle += 2 * pi;
    
    double percent = adjustedAngle / (2 * pi);
    setState(() => _dragProgress = percent);
    _controller!.seekTo(Duration(milliseconds: (_controller!.value.duration.inMilliseconds * percent).toInt()));
  }

  void _endDrag() {
    if (mounted) setState(() => _dragProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    double progress = 0.0;
    bool isInitialized = _controller != null && _controller!.value.isInitialized;

    if (isInitialized && _controller!.value.duration.inMilliseconds > 0) {
      progress = _dragProgress ?? (_controller!.value.position.inMilliseconds / _controller!.value.duration.inMilliseconds);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: _isExpanded ? 280 : 200, 
      height: _isExpanded ? 280 : 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool canDrag = _isExpanded && !_isPlaying;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onHorizontalDragStart: canDrag ? (d) => _handleDrag(d.localPosition, constraints) : null,
            onHorizontalDragUpdate: canDrag ? (d) => _handleDrag(d.localPosition, constraints) : null,
            onHorizontalDragEnd: canDrag ? (d) => _endDrag() : null,
            onVerticalDragStart: canDrag ? (d) => _handleDrag(d.localPosition, constraints) : null,
            onVerticalDragUpdate: canDrag ? (d) => _handleDrag(d.localPosition, constraints) : null,
            onVerticalDragEnd: canDrag ? (d) => _endDrag() : null,
            
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: Container(
                    width: double.infinity, height: double.infinity,
                    color: Colors.grey[300], 
                    child: isInitialized
                        ? AspectRatio(aspectRatio: 1, child: VideoPlayer(_controller!))
                        : (_isDownloading 
                            ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const SizedBox()), 
                  ),
                ),

                if (isInitialized)
                  SizedBox(
                    width: double.infinity, height: double.infinity,
                    child: CustomPaint(
                      painter: CircularProgressWithThumbPainter(
                        progress: progress,
                        showThumb: canDrag, 
                        strokeWidth: _isExpanded ? 6 : 3,
                      ),
                    ),
                  ),

                if (_isExpanded && !_isPlaying)
                  Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                  ),

                if (_isExpanded)
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: _closeExpanded,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      ),
    );
  }
}

class CircularProgressWithThumbPainter extends CustomPainter {
  final double progress;
  final bool showThumb;
  final double strokeWidth;

  CircularProgressWithThumbPainter({required this.progress, required this.showThumb, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10; 
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paintFg = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = progress * 2 * pi;
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, paintFg);

    if (showThumb) {
      final thumbX = center.dx + radius * cos(-pi / 2 + sweepAngle);
      final thumbY = center.dy + radius * sin(-pi / 2 + sweepAngle);
      
      final thumbPaintBg = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(thumbX, thumbY), 8, thumbPaintBg);
      
      final thumbPaintFg = Paint()..color = Colors.blue;
      canvas.drawCircle(Offset(thumbX, thumbY), 3, thumbPaintFg);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}