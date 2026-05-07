import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CreateGroupScreen extends StatefulWidget {
  final int currentUserId;

  const CreateGroupScreen({super.key, required this.currentUserId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  List<dynamic> _users = [];
  final Set<int> _selectedUserIds = {}; 
  bool _isLoading = false;

  late Box _contactsBox;
  bool _isBoxLoaded = false;
  bool _isChannel = false;

  @override
  void initState() {
    super.initState();
    _initHive();
    _loadUsers();
  }

  Future<void> _initHive() async {
    _contactsBox = Hive.isBoxOpen('contacts_box') ? Hive.box('contacts_box') : await Hive.openBox('contacts_box');
    if (mounted) setState(() => _isBoxLoaded = true);
  }

  Future<void> _loadUsers() async {
    final users = await _chatService.searchUsers('');
    if (mounted) {
      setState(() {
        _users = users.where((u) => u['userID'] != widget.currentUserId).toList();
      });
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty || _selectedUserIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final chatId = await _chatService.createGroupChat(
        widget.currentUserId,
        _groupNameController.text,
        _selectedUserIds.toList(),
        isChannel: _isChannel,
      );

      if (chatId != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              chatName: _groupNameController.text,
              currentUserId: widget.currentUserId,
            ),
          ),
          (route) => route.isFirst, 
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка создания группы на сервере")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color headerBg = isDark ? Colors.grey[900]! : const Color(0xFFF9F9F9);
    Color dividerColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final canCreate = _groupNameController.text.isNotEmpty && _selectedUserIds.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, elevation: 0, leadingWidth: 80,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: Text("Отмена", style: TextStyle(color: textColor, fontSize: 16))),
        title: Text(_isChannel ? "Новый канал" : "Новая группа", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), centerTitle: true,
        actions: [
          TextButton(
            onPressed: canCreate && !_isLoading ? _createGroup : null,
            child: Text("Создать", style: TextStyle(color: canCreate ? const Color(0xFF007AFF) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(radius: 30, backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF2F2F2), child: Icon(Icons.camera_alt, color: isDark ? Colors.white54 : Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _groupNameController, textAlign: TextAlign.center, onChanged: (_) => setState(() {}), 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(hintText: _isChannel ? "Имя канала" : "Имя группы", hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey), border: InputBorder.none),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          SwitchListTile(
            title: Text("Это канал", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("В канале могут писать только администраторы", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
            value: _isChannel,
            activeThumbColor: Colors.blue,
            onChanged: (val) => setState(() => _isChannel = val),
          ),
          Divider(height: 1, color: dividerColor),
          Container(width: double.infinity, padding: const EdgeInsets.all(16), color: headerBg, child: Text("УЧАСТНИКИ", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (context, index) => Divider(indent: 70, height: 1, color: dividerColor),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final userId = user['userId'] ?? user['userID']; 
                    final name = user['displayName'] ?? user['DisplayName'] ?? 'Unknown';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    final isSelected = _selectedUserIds.contains(userId);

                    // 🛡️ ЛОГИКА ПРИВАТНОСТИ 🛡️
                    final privacy = user['privacyMessages'] ?? user['PrivacyMessages'] ?? 0;
                    final isContact = _isBoxLoaded && _contactsBox.containsKey(userId.toString());
                    final canWrite = privacy == 0 || (privacy == 1 && isContact);

                    return Opacity(
                      opacity: canWrite ? 1.0 : 0.4, // 🛡️ ОБЕРНУЛИ В ВИДЖЕТ OPACTIY
                      child: ListTile(
                        onTap: () {
                          if (!canWrite) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь запретил добавлять себя в группы 🔒')));
                             return;
                          }
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(userId);
                            } else {
                              _selectedUserIds.add(userId);
                            }
                          });
                        },
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 22, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                              backgroundImage: user['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                              child: user['avatarUrl'] == null ? Text(initial, style: TextStyle(color: textColor)) : null,
                            ),
                            if (isSelected) const Positioned(right: 0, bottom: 0, child: Icon(Icons.check_circle, color: Color(0xFF007AFF), size: 20))
                          ],
                        ),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                        // Если нельзя писать - показываем замочек вместо галочки
                        trailing: !canWrite 
                            ? Icon(Icons.lock_outline, color: isDark ? Colors.white54 : Colors.grey)
                            : (isSelected ? const Icon(Icons.check_circle, color: Color(0xFF007AFF)) : Icon(Icons.circle_outlined, color: isDark ? Colors.white54 : Colors.grey)),
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