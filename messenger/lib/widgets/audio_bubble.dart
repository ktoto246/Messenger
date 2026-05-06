import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // <--- НОВЫЙ ИМПОРТ

class AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;

  const AudioBubble({super.key, required this.url, required this.isMe});

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false; // Показываем загрузку, пока качается файл
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<double> _waveformHeights = [];

  @override
  void initState() {
    super.initState();
    _generateWaveform();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  void _generateWaveform() {
    final random = Random(widget.url.hashCode);
    _waveformHeights = List.generate(35, (index) => random.nextDouble() * 20 + 4);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, 
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            // Если грузится - показываем крутилку, иначе кнопку Play/Pause
            icon: _isLoading 
                ? SizedBox(
                    width: 24, height: 24, 
                    child: CircularProgressIndicator(color: widget.isMe ? Colors.white : Colors.blue, strokeWidth: 2)
                  )
                : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            color: widget.isMe ? Colors.white : Colors.blue,
            iconSize: 36,
            onPressed: () async {
              if (_isLoading) return; // Защита от двойного клика

              if (_isPlaying) {
                await _audioPlayer.pause();
                return;
              }

              if (mounted) setState(() => _isLoading = true);

              try {
                // 🪄 МАГИЯ ОФЛАЙНА: Пытаемся достать файл из кэша. Если нет - качаем и сохраняем!
                var file = await DefaultCacheManager().getSingleFile(widget.url);
                
                if (mounted) {
                  setState(() => _isLoading = false);
                  // Играем локальный файл прямо из памяти телефона (DeviceFileSource)
                  await _audioPlayer.play(DeviceFileSource(file.path));
                }
              } catch (e) {
                // Если файла нет в кэше и мы без интернета
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _isPlaying = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Нет сети. Голосовое сообщение еще не загружено 🌐"),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque, 
                  onTapDown: (details) async {
                    if (_duration.inMilliseconds == 0) return;
                    final double percent = details.localPosition.dx / constraints.maxWidth;
                    try {
                      await _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * percent).toInt()));
                    } catch (e) {
                      // Игнорируем ошибку перемотки
                    }
                  },
                  child: Container(
                    height: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(35, (index) {
                        double progress = _duration.inMilliseconds > 0 
                            ? _position.inMilliseconds / _duration.inMilliseconds 
                            : 0.0;
                        bool isPlayed = (index / 35) <= progress;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 3,
                          height: _waveformHeights[index],
                          decoration: BoxDecoration(
                            color: isPlayed 
                                ? (widget.isMe ? Colors.white : Colors.blue) 
                                : (widget.isMe ? Colors.white38 : Colors.black12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}