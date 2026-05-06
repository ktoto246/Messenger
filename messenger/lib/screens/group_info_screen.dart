import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'foreign_profile_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final int chatId;
  final String groupName;
  final int currentUserId;

  const GroupInfoScreen({super.key, required this.chatId, required this.groupName, required this.currentUserId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  late String _groupName;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final data = await _chatService.getChatMembers(widget.chatId);
    if (mounted) {
      setState(() {
        _members = data;
        _isLoading = false;
        // Проверяем, является ли текущий пользователь админом
        _isAdmin = _members.any((m) => (m['userId'] ?? m['UserID']) == widget.currentUserId && (m['isAdmin'] ?? m['IsAdmin'] == true));
      });
    }
  }

  void _editGroupName() async {
    final controller = TextEditingController(text: _groupName);
    String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Изменить название"),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "Введите название группы")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("Сохранить")),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _groupName) {
      await _chatService.updateGroupInfo(widget.chatId, name: newName);
      setState(() => _groupName = newName);
    }
  }

  void _addMember() async {
    // Для простоты используем поиск пользователей
    // В реальном приложении тут был бы выбор из контактов
    String? query;
    List<dynamic> searchResults = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Добавить участника"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: "Поиск по имени/username"),
                  onChanged: (val) async {
                    if (val.length > 2) {
                      final results = await _chatService.searchUsers(val);
                      setDialogState(() => searchResults = results);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      final name = user['displayName'] ?? 'User';
                      final uId = user['userId'] ?? user['userID'];
                      
                      // Проверяем, не в группе ли уже
                      bool alreadyIn = _members.any((m) => (m['userId'] ?? m['UserID']) == uId);

                      return ListTile(
                        title: Text(name),
                        trailing: alreadyIn ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.add),
                        onTap: alreadyIn ? null : () async {
                          await _chatService.addGroupMembers(widget.chatId, [uId]);
                          if (context.mounted) Navigator.pop(context);
                          _loadMembers();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _kickMember(int userId, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Исключить $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Исключить", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.kickMember(widget.chatId, userId);
      _loadMembers();
    }
  }

  void _leaveGroup() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Покинуть группу?"),
        content: const Text("Вы больше не будете получать сообщения из этого чата."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Выйти", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.deleteChat(widget.chatId, widget.currentUserId);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : const Color(0xFFF2F2F6);
    Color blockColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.blue), onPressed: () => Navigator.pop(context)),
        title: Text("Информация", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          if (_isAdmin)
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: _editGroupName),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50, backgroundColor: Colors.orangeAccent,
                      child: const Icon(Icons.people, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(_groupName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text("${_members.length} участников", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (_isAdmin)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const Icon(Icons.person_add, color: Colors.blue),
                      title: const Text("Добавить участника", style: TextStyle(color: Colors.blue)),
                      onTap: _addMember,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Text("УЧАСТНИКИ", style: TextStyle(color: Colors.grey, fontSize: 13))),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _members.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 56, color: Colors.grey),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final String name = member['displayName'] ?? member['DisplayName'] ?? 'User';
                    final int memberId = member['userId'] ?? member['UserId'];
                    final bool isMe = memberId == widget.currentUserId;
                    final bool memberIsAdmin = member['isAdmin'] ?? member['IsAdmin'] ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark ? Colors.grey[700] : Colors.blueAccent,
                        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(isMe ? "$name (Вы)" : name, style: TextStyle(color: textColor, fontWeight: isMe ? FontWeight.bold : FontWeight.normal))),
                          if (memberIsAdmin)
                            const Text("админ", style: TextStyle(color: Colors.blue, fontSize: 12)),
                        ],
                      ),
                      trailing: isMe 
                        ? null 
                        : (_isAdmin ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _kickMember(memberId, name)) : const Icon(Icons.chevron_right, color: Colors.grey)),
                      onTap: () {
                        if (!isMe && !_isAdmin) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ForeignProfileScreen(userId: memberId, initialName: name)));
                        }
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: const Center(child: Text("Покинуть группу", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500))),
                  onTap: _leaveGroup,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }
}
}