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
  bool _isLoading = false; 
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<double> _waveformHeights = [];
  double _playbackSpeed = 1.0;

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

  void _toggleSpeed() async {
    setState(() {
      if (_playbackSpeed == 1.0) _playbackSpeed = 1.5;
      else if (_playbackSpeed == 1.5) _playbackSpeed = 2.0;
      else _playbackSpeed = 1.0;
    });
    await _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _generateWaveform() {
    final random = Random(widget.url.hashCode);
    _waveformHeights = List.generate(25, (index) => random.nextDouble() * 20 + 4);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260, 
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            color: widget.isMe ? Colors.white : Colors.blue,
            iconSize: 36,
            onPressed: () async {
              if (_isLoading) return;
              if (_isPlaying) { await _audioPlayer.pause(); return; }
              if (mounted) setState(() => _isLoading = true);
              try {
                var file = await DefaultCacheManager().getSingleFile(widget.url);
                if (mounted) {
                  setState(() => _isLoading = false);
                  await _audioPlayer.play(DeviceFileSource(file.path));
                  await _audioPlayer.setPlaybackRate(_playbackSpeed);
                }
              } catch (e) { if (mounted) setState(() => _isLoading = false); }
            },
          ),
          const SizedBox(width: 8),
          
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque, 
                  onTapDown: (details) async {
                    if (_duration.inMilliseconds == 0) return;
                    final double percent = details.localPosition.dx / constraints.maxWidth;
                    await _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * percent).toInt()));
                  },
                  child: Container(
                    height: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(25, (index) {
                        double progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
                        bool isPlayed = (index / 25) <= progress;
                        return Container(
                          width: 3, height: _waveformHeights[index],
                          decoration: BoxDecoration(color: isPlayed ? (widget.isMe ? Colors.white : Colors.blue) : (widget.isMe ? Colors.white38 : Colors.black12), borderRadius: BorderRadius.circular(2)),
                        );
                      }),
                    ),
                  ),
                );
              }
            ),
          ),
          
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: (widget.isMe ? Colors.white24 : Colors.black12), borderRadius: BorderRadius.circular(10)),
              child: Text("${_playbackSpeed.toStringAsFixed(1)}x", style: TextStyle(color: widget.isMe ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}