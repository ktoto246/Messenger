import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'chat_detail_screen.dart';  
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:marquee/marquee.dart';
import '../config/app_config.dart';

class ForeignProfileScreen extends StatefulWidget {
  final int userId;
  final String? initialName;
  final String? initialAvatar;

  const ForeignProfileScreen({super.key, required this.userId, this.initialName, this.initialAvatar});

  @override
  State<ForeignProfileScreen> createState() => _ForeignProfileScreenState();
}

class _ForeignProfileScreenState extends State<ForeignProfileScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  bool _isMuted = false;
  bool _isSending = false; 
  bool _isMyContact = false;
  bool _isPlayingMusic = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkContactStatus();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlayingMusic = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _chatService.getUserProfile(widget.userId);
    if (mounted) setState(() { userProfile = profile; _isLoading = false; });
  }

  Future<void> _checkContactStatus() async {
    var box = Hive.isBoxOpen('contacts_box') ? Hive.box('contacts_box') : await Hive.openBox('contacts_box');
    if (mounted) setState(() => _isMyContact = box.containsKey(widget.userId.toString()));
  }

  Future<void> _toggleContact() async {
    var box = Hive.isBoxOpen('contacts_box') ? Hive.box('contacts_box') : await Hive.openBox('contacts_box');
    if (_isMyContact) {
      await box.delete(widget.userId.toString()); 
    } else {
      await box.put(widget.userId.toString(), {
        'userId': widget.userId,
        'displayName': userProfile?['displayName'] ?? widget.initialName,
        'avatarUrl': userProfile?['avatarUrl'] ?? widget.initialAvatar,
      });
    }
    if (mounted) {
      setState(() => _isMyContact = !_isMyContact); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isMyContact ? "Добавлен в контакты 📇" : "Удален из контактов 🗑️"), backgroundColor: _isMyContact ? Colors.green : Colors.redAccent));
    }
  }

  Future<void> _startChatAndGreet() async {
    if (_isSending) return; 
    setState(() => _isSending = true);
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) { if (mounted) setState(() => _isSending = false); return; }
      final chatId = await _chatService.createPrivateChat(currentUserId, widget.userId);
      if (mounted) setState(() => _isSending = false);
      if (chatId != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(
            chatId: chatId, currentUserId: currentUserId, chatName: userProfile?['displayName'] ?? widget.initialName ?? 'Chat', otherUserId: widget.userId,
        )));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка создания чата: $e")));
      }
    }
  }

  Widget _buildMusicPlayer() {
    String? musicUrl = userProfile?['musicUrl'] ?? userProfile?['MusicUrl'];
    bool hasMusic = musicUrl != null && musicUrl.isNotEmpty;
    if (!hasMusic) return const SizedBox.shrink(); 
    String trackName = "Вайб пользователя";
    try { trackName = Uri.parse(musicUrl).queryParameters['name'] ?? "Вайб пользователя"; } catch (e) {}
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlayingMusic) { await _audioPlayer.pause(); } else {
                try {
                  String cleanUrl = musicUrl.split('?').first;
                  if (!cleanUrl.startsWith('http')) {
                    cleanUrl = cleanUrl.startsWith('/') ? cleanUrl.substring(1) : cleanUrl;
                    final base = AppConfig.baseUrl.replaceAll('/api', '');
                    cleanUrl = "$base/$cleanUrl"; 
                  }
                  await _audioPlayer.play(UrlSource(cleanUrl));
                } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка воспроизведения 🚫"), backgroundColor: Colors.red)); }
              }
            },
            child: CircleAvatar(radius: 24, backgroundColor: Colors.blueAccent, child: Icon(_isPlayingMusic ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20, child: Marquee(text: trackName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.start, blankSpace: 30.0, velocity: 35.0, pauseAfterRound: const Duration(seconds: 2))),
                const Padding(padding: EdgeInsets.only(top: 4.0), child: Text("Слушать", style: TextStyle(color: Colors.white70, fontSize: 13))),
              ],
            ),
          ),
        ],
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    // 🌙 Адаптация темы
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color btnBgColor = isDark ? Colors.grey[800]! : const Color(0xFFF2F2F2);

    final displayName = userProfile?['displayName'] ?? widget.initialName ?? 'User';
    String? avatarUrl = userProfile?['avatarUrl'] ?? widget.initialAvatar;
    final username = userProfile?['username'] ?? '...';
    String phone = userProfile?['phoneNumber'] ?? 'Нет номера';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final int privacyPhone = userProfile?['privacyPhone'] ?? 0;
    final int privacyAvatar = userProfile?['privacyAvatar'] ?? 0;
    final int privacyMessages = userProfile?['privacyMessages'] ?? 0;

    bool canSeePhone = privacyPhone == 0 || (privacyPhone == 1 && _isMyContact);
    if (!canSeePhone) phone = "Скрыто настройками";
    bool canSeeAvatar = privacyAvatar == 0 || (privacyAvatar == 1 && _isMyContact);
    if (!canSeeAvatar) avatarUrl = null;
    bool canWrite = privacyMessages == 0 || (privacyMessages == 1 && _isMyContact);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 50, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Text(initial, style: TextStyle(fontSize: 40, color: textColor)) : null,
            ),
            const SizedBox(height: 16),
            Text(displayName, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 30),
            _buildMusicPlayer(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: !canWrite ? Icons.lock_outline : (_isSending ? Icons.hourglass_empty : Icons.chat_bubble_outline),
                  label: !canWrite ? "Закрыто" : (_isSending ? "Загрузка..." : "Чат"),
                  color: !canWrite ? Colors.grey : textColor, btnBgColor: btnBgColor,
                  onTap: () {
                    if (!canWrite) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Пользователь ограничил возможность писать ему сообщения 🔒"))); return; }
                    _startChatAndGreet(); 
                  },
                ),
                const SizedBox(width: 25),
                _buildActionButton(
                  icon: _isMuted ? Icons.notifications_off_outlined : Icons.notifications_none,
                  label: "Звук", color: textColor, btnBgColor: btnBgColor,
                  onTap: () {
                    setState(() => _isMuted = !_isMuted);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isMuted ? "Уведомления выключены" : "Уведомления включены")));
                  },
                ),
                const SizedBox(width: 25),
                _buildActionButton(
                  icon: _isMyContact ? Icons.person_remove : Icons.person_add,
                  label: _isMyContact ? "Удалить" : "В контакты",
                  color: _isMyContact ? Colors.red : textColor, btnBgColor: btnBgColor,
                  onTap: _toggleContact,
                ),
              ],
            ),
            const SizedBox(height: 40),
            Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
            _isLoading 
              ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoTile("Мобильный", phone, canSeePhone ? textColor : Colors.grey),
                    Padding(padding: const EdgeInsets.only(left: 16.0), child: Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE))),
                    _buildInfoTile("Имя пользователя", "@$username", textColor),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required Color btnBgColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: btnBgColor, shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: valueColor)), 
        ],
      ),
    );
  }
}