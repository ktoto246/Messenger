import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'qr_profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:marquee/marquee.dart';
import '../config/app_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  bool _isPlayingMusic = false;
  String? _musicUrl;
  bool _isUploadingMusic = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlayingMusic = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = await _authService.getCurrentUserId();
    if (userId != null) {
      final profile = await _chatService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          userProfile = profile;
          _musicUrl = profile?['musicUrl'];
          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await _authService.updateOnlineStatus(false);
    debugPrint("⚫ Статус изменен на Офлайн перед выходом");

    await _authService.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String originalName = result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), ''); 

        setState(() => _isUploadingMusic = true);

        String? uploadedUrl = await _chatService.uploadMedia(file);

        if (uploadedUrl != null) {
          String finalUrl = "$uploadedUrl?name=${Uri.encodeComponent(originalName)}";
          int? userId = userProfile?['userID'] ?? userProfile?['userId'];
          if (userId != null) {
            await _chatService.updateProfile(userId, {'MusicUrl': finalUrl});
            if (mounted) {
              setState(() {
                _musicUrl = finalUrl;
                _isUploadingMusic = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Трек успешно загружен! 🎧"), backgroundColor: Colors.green));
            }
          }
        } else {
          setState(() => _isUploadingMusic = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingMusic = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка загрузки: $e")));
      }
    }
  }

  Widget _buildMusicPlayer() {
    bool hasMusic = _musicUrl != null && _musicUrl!.isNotEmpty;
    String trackName = "Добавить трек";
    if (hasMusic) {
      try {
        trackName = Uri.parse(_musicUrl!).queryParameters['name'] ?? "Любимый трек";
      } catch (e) {
        trackName = "Любимый трек";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasMusic ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploadingMusic ? null : (hasMusic ? () async {
              if (_isPlayingMusic) {
                await _audioPlayer.pause();
              } else {
                try {
                  String cleanUrl = _musicUrl!.split('?').first;
                  if (!cleanUrl.startsWith('http')) {
                    cleanUrl = cleanUrl.startsWith('/') ? cleanUrl.substring(1) : cleanUrl;
                    cleanUrl = "${AppConfig.baseUrl.replaceAll('/api', '')}/$cleanUrl";
                  }
                  await _audioPlayer.play(UrlSource(cleanUrl));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка воспроизведения 🚫"), backgroundColor: Colors.red));
                  }
                }
              }
            } : _pickAndUploadMusic),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: hasMusic ? Colors.blueAccent : Colors.grey[300],
              child: _isUploadingMusic 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(hasMusic ? (_isPlayingMusic ? Icons.pause : Icons.play_arrow) : Icons.add_rounded, color: hasMusic ? Colors.white : Colors.black54, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 20, 
                  child: (!hasMusic || _isUploadingMusic) 
                      ? Text(_isUploadingMusic ? "Загружаем трек..." : trackName, style: TextStyle(color: hasMusic ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))
                      : Marquee(text: trackName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.start, blankSpace: 30.0, velocity: 35.0, pauseAfterRound: const Duration(seconds: 2)),
                ),
                if (hasMusic && !_isUploadingMusic) const Padding(padding: EdgeInsets.only(top: 4.0), child: Text("Играет сейчас...", style: TextStyle(color: Colors.white70, fontSize: 13))),
              ],
            ),
          ),
          if (hasMusic && !_isUploadingMusic) IconButton(icon: const Icon(Icons.edit, color: Colors.white54), onPressed: _pickAndUploadMusic),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Узнаем текущую тему (светлая/темная)
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black; // Адаптивный текст
    Color bgColor = Theme.of(context).scaffoldBackgroundColor; // Адаптивный фон

    final displayName = userProfile?['displayName'] ?? 'User';
    final username = userProfile?['username'] ?? 'username';
    final avatarUrl = userProfile?['avatarUrl'];
    final phone = userProfile?['phoneNumber'] ?? '+1 202 555 0147'; 

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'QR-код',
            onPressed: () {
              if (userProfile == null) return;
              final userId = userProfile!['userID'] ?? userProfile!['UserId'] ?? 0;
              Navigator.push(context, MaterialPageRoute(builder: (_) => QrProfileScreen(
                userId: userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
                displayName: userProfile!['displayName'] ?? 'User',
                username: userProfile!['username'] ?? 'user',
                avatarUrl: userProfile!['avatarUrl'],
              )));
            },
          ),
          TextButton(
            onPressed: _logout,
            child: Text(
              "Done",
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
     body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            CircleAvatar(
              radius: 60,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: TextStyle(fontSize: 50, color: textColor))
                  : null,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.33, fontFamily: 'SF Pro Display', color: textColor),
            ),
            
            const SizedBox(height: 24),

            _buildMusicPlayer(),
            
            const SizedBox(height: 24),

            _buildDivider(isDark),

            _buildListTile(
              icon: Icons.alternate_email, iconBgColor: const Color(0xFFFF2D55), 
              title: "Username", trailingText: "m.me/$username", showArrow: true, textColor: textColor, isDark: isDark
            ),

            _buildDivider(isDark),

            _buildListTile(
              icon: Icons.phone, iconBgColor: const Color(0xFF007AFF), 
              title: "Phone", trailingText: phone, showArrow: true, textColor: textColor, isDark: isDark
            ),
            
            _buildDivider(isDark),

            _buildListTile(
              icon: Icons.settings, iconColor: Colors.white, iconBgColor: Colors.grey[700]!, 
              title: "Настройки", showArrow: true, textColor: textColor, isDark: isDark,
              onTap: () async { 
                if (userProfile != null) {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (context) => SettingsScreen(currentUserId: userProfile!['userID'], userProfile: userProfile!),
                  ));
                  _loadProfile(); 
                }
              },
            ),

            _buildDivider(isDark),
          ],
        ),
      )
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 68), 
      // Ночью полоска темнее, чтобы не резала глаза
      child: Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE5E5EA)),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    Color iconColor = Colors.white,
    Color iconBgColor = Colors.black, 
    required String title,
    String? trailingText,
    Widget? trailing,
    bool showArrow = false,
    VoidCallback? onTap,
    required Color textColor, // Передаем цвет текста
    required bool isDark,
  }) {
    return InkWell( 
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: textColor)), // Адаптивный цвет
            const Spacer(),
            if (trailingText != null)
              Text(trailingText, style: TextStyle(fontSize: 17, color: textColor.withValues(alpha: 0.4))), // Адаптивный цвет
            if (showArrow)
               Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3))),
            ?trailing,
          ],
        ),
      ),
    );
  }
}