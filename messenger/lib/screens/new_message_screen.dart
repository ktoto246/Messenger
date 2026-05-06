import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart'; 
import 'package:hive_flutter/hive_flutter.dart';

class NewMessageScreen extends StatefulWidget {
  final int currentUserId; 

  const NewMessageScreen({super.key, required this.currentUserId});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  List<dynamic> _users = [];
  Timer? _debounce; 
  
  late Box _contactsBox;
  bool _isBoxLoaded = false;

  @override
  void initState() {
    super.initState();
    _initHive();
    _searchUsers(''); 
  }

  Future<void> _initHive() async {
    _contactsBox = Hive.isBoxOpen('contacts_box') ? Hive.box('contacts_box') : await Hive.openBox('contacts_box');
    if (mounted) setState(() => _isBoxLoaded = true);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final users = await _chatService.searchUsers(query);
    if (mounted) {
      setState(() {
        _users = users.where((u) => u['userID'] != widget.currentUserId).toList();
      });
    }
  }

  void _onUserTap(dynamic user) async {
    try {
      final chatId = await _chatService.createPrivateChat(
        widget.currentUserId, 
        user['userID'] ?? user['userId']
      );

      if (chatId != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              chatName: user['displayName'] ?? 'Chat',
              currentUserId: widget.currentUserId,
              otherUserId: user['userID'] ?? user['userId'],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка создания чата")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color headerBg = isDark ? Colors.grey[900]! : const Color(0xFFF9F8F9);
    Color dividerColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, elevation: 0, leadingWidth: 80,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(fontSize: 17, color: textColor))),
        title: Text('New message', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: headerBg,
            child: Row(
              children: [
                Text('To: ', style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
                Expanded(
                  child: TextField(
                    controller: _searchController, onChanged: _onSearchChanged, style: TextStyle(fontSize: 16, color: textColor),
                    decoration: InputDecoration(hintText: "Search", hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 5)),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF2F2F2), radius: 20, child: Icon(Icons.people, color: textColor)),
            title: Text('Create a New Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor)),
            trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.grey),
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => CreateGroupScreen(currentUserId: widget.currentUserId))); },
          ),
          Container(
            width: double.infinity, padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
            child: Text('PEOPLE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (context, index) => Divider(indent: 70, height: 1, color: dividerColor),
              itemBuilder: (context, index) {
                final user = _users[index];
                final userId = user['userID'] ?? user['userId'];
                final name = user['displayName'] ?? 'Unknown';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                // 🛡️ ЛОГИКА ПРИВАТНОСТИ 🛡️
                final privacy = user['privacyMessages'] ?? user['PrivacyMessages'] ?? 0;
                final isContact = _isBoxLoaded && _contactsBox.containsKey(userId.toString());
                final canWrite = privacy == 0 || (privacy == 1 && isContact);

                return Opacity(
                  opacity: canWrite ? 1.0 : 0.4, // 🛡️ ОБЕРНУЛИ В ВИДЖЕТ OPACTIY
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onTap: () {
                      if (!canWrite) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь ограничил сообщения 🔒')));
                        return;
                      }
                      _onUserTap(user);
                    },
                    leading: CircleAvatar(
                      radius: 24, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                      backgroundImage: user['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                      child: user['avatarUrl'] == null ? Text(initial, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)) : null,
                    ),
                    title: Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor)),
                    // Вешаем замочек, если доступ закрыт
                    trailing: canWrite ? null : Icon(Icons.lock_outline, color: isDark ? Colors.white54 : Colors.grey), 
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}